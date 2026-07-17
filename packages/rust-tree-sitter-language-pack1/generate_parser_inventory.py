#!/usr/bin/env python3
"""Build an exact-commit license/source-evidence closure for parser sources."""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


LICENSE_NAMES = ("LICENSE", "COPYING", "NOTICE")
SPDX_PATTERN = re.compile(r"SPDX-License-Identifier:\s*([^\s*]+)", re.IGNORECASE)


def repo_key(url):
    return url.removeprefix("https://github.com/").removesuffix(".git")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run_git(*args, cwd):
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def is_license_name(path):
    return any(path.name.upper().startswith(name) for name in LICENSE_NAMES)


def source_root(definition):
    return Path(definition.get("directory") or ".")


def select_license_paths(tree_paths, definition):
    root = source_root(definition)
    direct = []
    for candidate in tree_paths:
        path = Path(candidate)
        try:
            relative = path.relative_to(root)
        except ValueError:
            continue
        if len(relative.parts) == 1 and is_license_name(relative):
            direct.append(candidate)
    if direct:
        return sorted(direct), "source-root"

    # Some grammars keep their own notice one level below the repository root.
    fallback = [path for path in tree_paths if is_license_name(Path(path))]
    return sorted(fallback), "repository-wide-fallback" if fallback else "none"


def detect_licenses(content):
    text = content.decode("utf-8", errors="replace")
    detected = sorted(set(SPDX_PATTERN.findall(text)))
    if detected:
        return detected, "spdx-header"

    lowered = " ".join(text.lower().split())
    if "redistribution and use in source and binary forms" in lowered:
        return ["BSD-3-Clause" if "neither the name" in lowered else "BSD-2-Clause"], "text-signature"
    signatures = (
        ("apache license", "Apache-2.0"),
        ("permission is hereby granted, free of charge", "MIT"),
        ("cc0 1.0 universal", "CC0-1.0"),
        ("isc license", "ISC"),
        ("permission to use, copy, modify, and/or distribute this software for any purpose with or without fee", "ISC"),
        ("mozilla public license, version 2.0", "MPL-2.0"),
        ("gnu lesser general public license", "LGPL"),
        ("gnu general public license", "GPL"),
        ("unlicense", "Unlicense"),
        ("creative commons zero", "CC0-1.0"),
    )
    return sorted({spdx for marker, spdx in signatures if marker in lowered}), "text-signature"


def collect_repository(root, evidence_root, repository, revision, definitions):
    key = repo_key(repository)
    destination = evidence_root / key / revision
    checkout = destination / ".git-metadata"
    destination.mkdir(parents=True, exist_ok=True)
    checkout.mkdir()
    run_git("init", "--quiet", cwd=checkout)
    run_git("remote", "add", "origin", f"https://github.com/{key}.git", cwd=checkout)
    try:
        run_git(
            "-c",
            "protocol.version=2",
            "fetch",
            "--quiet",
            "--depth=1",
            "--filter=blob:none",
            "origin",
            revision,
            cwd=checkout,
        )
        resolved = run_git("rev-parse", "FETCH_HEAD^{commit}", cwd=checkout).stdout.decode().strip()
        if resolved != revision:
            raise RuntimeError(f"resolved {resolved}, expected {revision}")
        tree = run_git("ls-tree", "-r", "--name-only", revision, cwd=checkout).stdout.decode().splitlines()
        tree = sorted(tree)
        (destination / "tree-paths.txt").write_text("\n".join(tree) + "\n")
        selected = {}
        for definition in definitions:
            paths, selection = select_license_paths(tree, definition)
            selected[definition["language"]] = {"paths": paths, "selection": selection}
        all_paths = sorted({path for record in selected.values() for path in record["paths"]})
        licenses = []
        for path in all_paths:
            content = run_git("show", f"{revision}:{path}", cwd=checkout).stdout
            target = destination / "license-files" / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            detected, method = detect_licenses(content)
            licenses.append(
                {
                    "path": path,
                    "sha256": hashlib.sha256(content).hexdigest(),
                    "size": len(content),
                    "detected_spdx": detected,
                    "detection_method": method,
                }
            )
        return {
            "repository": repository,
            "revision": revision,
            "resolved_revision": resolved,
            "tree_path_file": (destination / "tree-paths.txt").relative_to(root).as_posix(),
            "tree_path_file_sha256": sha256(destination / "tree-paths.txt"),
            "license_files": licenses,
            "language_selection": selected,
            "error": None,
        }
    except (subprocess.CalledProcessError, RuntimeError) as error:
        detail = error.stderr.decode(errors="replace").strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        return {
            "repository": repository,
            "revision": revision,
            "resolved_revision": None,
            "tree_path_file": None,
            "tree_path_file_sha256": None,
            "license_files": [],
            "language_selection": {},
            "error": detail,
        }
    finally:
        shutil.rmtree(checkout, ignore_errors=True)


def create_sanitized_archive(root, archive):
    command = [
        "tar",
        "--zstd",
        "--sort=name",
        "--mtime=@0",
        "--owner=0",
        "--group=0",
        "--numeric-owner",
        "--exclude=*.o",
        "-cf",
        str(archive),
        "parsers",
        "sources",
    ]
    subprocess.run(command, cwd=root, check=True)
    return sha256(archive)


def write_closure_manifest(root, evidence_root):
    manifest = evidence_root / "MANIFEST.sha256"
    entries = []
    for path in sorted(evidence_root.rglob("*")):
        if path.is_file() and path != manifest:
            entries.append(f"{sha256(path)}  {path.relative_to(root).as_posix()}")
    manifest.write_text("\n".join(entries) + "\n")
    return manifest.relative_to(root).as_posix(), sha256(manifest), len(entries)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()

    root = args.root.resolve()
    definitions_path = root / "sources" / "language_definitions.json"
    cache_path = root / "sources" / "license_cache.json"
    archive_path = root / "parser-sources-1.12.5.tar.zst"
    parsers_path = root / "parsers"
    evidence_root = root / "parser-source-license-evidence"
    sanitized_archive = root / "parser-sources-1.12.5.no-prebuilt-objects.tar.zst"
    definitions = json.loads(definitions_path.read_text())
    cache = json.loads(cache_path.read_text())

    if evidence_root.exists():
        shutil.rmtree(evidence_root)
    evidence_root.mkdir()
    grouped = {}
    for language, definition in definitions.items():
        grouped.setdefault((definition["repo"], definition["rev"]), []).append({"language": language, **definition})

    repository_evidence = {}
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {
            executor.submit(collect_repository, root, evidence_root, repository, revision, records): (repository, revision)
            for (repository, revision), records in grouped.items()
        }
        for future in as_completed(futures):
            repository, revision = futures[future]
            repository_evidence[(repository, revision)] = future.result()

    parser_records = []
    for language, definition in sorted(definitions.items()):
        repository = definition["repo"]
        revision = definition["rev"]
        evidence = repository_evidence[(repository, revision)]
        selection = evidence["language_selection"].get(language, {"paths": [], "selection": "unavailable"})
        parser_root = parsers_path / language
        objects = sorted(path.relative_to(root).as_posix() for path in parser_root.rglob("*.o"))
        license_files = [
            {**record, "evidence_path": (evidence_root / repo_key(repository) / revision / "license-files" / record["path"]).relative_to(root).as_posix()}
            for record in evidence["license_files"]
            if record["path"] in selection["paths"]
        ]
        detected = sorted({spdx for record in license_files for spdx in record["detected_spdx"]})
        if evidence["error"]:
            status = "repository-unresolved"
        elif not license_files:
            status = "no-primary-license-file-at-pinned-commit"
        elif not detected:
            status = "primary-license-file-needs-manual-spdx-review"
        elif any(spdx in {"GPL", "LGPL", "BSD"} for spdx in detected):
            status = "primary-license-file-needs-exact-spdx-review"
        else:
            status = "primary-license-evidence-collected"
        parser_records.append(
            {
                "language": language,
                "repository": repository,
                "revision": revision,
                "branch": definition.get("branch"),
                "subdirectory": definition.get("directory"),
                "parser_directory": parser_root.relative_to(root).as_posix(),
                "parser_source_paths": sorted(path.relative_to(root).as_posix() for path in (parser_root / "src").glob("parser.*")),
                "prebuilt_object_files": objects,
                "license_cache_claim": cache.get(repo_key(repository)),
                "repository_tree_path_file": evidence["tree_path_file"],
                "repository_tree_path_file_sha256": evidence["tree_path_file_sha256"],
                "license_selection": selection["selection"],
                "license_files": license_files,
                "detected_spdx": detected,
                "license_status": status,
                "repository_fetch_error": evidence["error"],
            }
        )

    unresolved_repositories = sorted(
        repo_key(record["repository"])
        for record in parser_records
        if record["license_status"] in {"repository-unresolved", "no-primary-license-file-at-pinned-commit"}
    )
    ambiguous_records = sorted(
        record["language"]
        for record in parser_records
        if "manual-spdx-review" in record["license_status"] or "exact-spdx-review" in record["license_status"]
    )
    object_files = [object_file for record in parser_records for object_file in record["prebuilt_object_files"]]
    sanitized_sha256 = create_sanitized_archive(root, sanitized_archive)
    manifest_path, manifest_sha256, manifest_entry_count = write_closure_manifest(root, evidence_root)
    inventory = {
        "schema_version": 2,
        "source_bundle": {
            "path": archive_path.name,
            "sha256": sha256(archive_path),
            "language_definitions": definitions_path.relative_to(root).as_posix(),
            "license_cache": cache_path.relative_to(root).as_posix(),
        },
        "source_evidence_closure": {
            "path": evidence_root.relative_to(root).as_posix(),
            "repository_count": len(grouped),
            "manifest": manifest_path,
            "manifest_sha256": manifest_sha256,
            "manifest_entry_count": manifest_entry_count,
            "archive_without_prebuilt_objects": sanitized_archive.name,
            "archive_without_prebuilt_objects_sha256": sanitized_sha256,
            "fetch_method": "git protocol v2, exact pinned commit, blob-filtered tree followed by exact license blobs",
        },
        "summary": {
            "language_count": len(parser_records),
            "unique_repository_count": len(grouped),
            "primary_license_evidence_count": sum(bool(record["license_files"]) for record in parser_records),
            "unresolved_repository_count": len(set(unresolved_repositories)),
            "ambiguous_license_record_count": len(ambiguous_records),
            "prebuilt_object_file_count": len(object_files),
        },
        "blockers": {
            "unresolved_repositories": sorted(set(unresolved_repositories)),
            "ambiguous_license_records": ambiguous_records,
            "prebuilt_object_files": object_files,
            "policy": "Only exact pinned commits are queried. A parser is unresolved only when that commit cannot be fetched or has no primary license/notice file at its grammar source root.",
        },
        "parsers": parser_records,
    }
    args.output.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
