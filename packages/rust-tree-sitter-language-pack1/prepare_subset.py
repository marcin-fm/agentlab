#!/usr/bin/env python3
"""Create the source-only parser subset used by Fedora packaging."""

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
EVIDENCE_PREFIX = Path("parser-source-license-evidence")

EXCLUSIONS = {
    "brightscript": "misidentified Cargo metadata names a different repository",
    "cooklang": "NOASSERTION: exact Cargo MIT and package ISC declarations conflict",
    "corn": "MIT declaration only: no pinned primary text",
    "eds": "MIT declaration only: no pinned primary text",
    "eex": "misidentified Cargo metadata names a different grammar repository",
    "elsa": "MIT declaration only: no pinned primary text",
    "facility": "MIT declaration only: no primary text or release linkage",
    "groovy": "NOASSERTION: no governing declaration or license text at the pin",
    "hjson": "source/package identity mismatch: hjson repository declares tree-sitter-jsonc",
    "move": "MIT declaration only: no pinned primary text",
    "pgn": "BSD-2-Clause text is absent at the pin; omit instead of carrying historical supplemental text",
    "tmux": "MIT declarations only: published release points to a different commit",
    "vb": "upstream issue 7 confirms the pinned code is unlicensed despite MIT package metadata",
}


def digest(path):
    sha = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def copy_verified(source, destination, expected_sha256):
    actual = digest(source)
    if actual != expected_sha256:
        raise RuntimeError(
            f"SHA-256 mismatch for {source}: expected {expected_sha256}, got {actual}"
        )
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def verify_evidence_closure(inventory, evidence_root):
    manifest = evidence_root / "MANIFEST.sha256"
    expected_manifest_sha256 = inventory["source_evidence_closure"]["manifest_sha256"]
    actual_manifest_sha256 = digest(manifest)
    if actual_manifest_sha256 != expected_manifest_sha256:
        raise RuntimeError(
            "license evidence manifest mismatch: "
            f"expected {expected_manifest_sha256}, got {actual_manifest_sha256}"
        )

    entries = 0
    for line in manifest.read_text().splitlines():
        expected_sha256, relative = line.split(maxsplit=1)
        relative_path = Path(relative)
        if relative_path.parts[0] != EVIDENCE_PREFIX.name:
            raise RuntimeError(f"unexpected evidence manifest path: {relative}")
        source = evidence_root / relative_path.relative_to(EVIDENCE_PREFIX)
        actual_sha256 = digest(source)
        if actual_sha256 != expected_sha256:
            raise RuntimeError(
                f"license evidence mismatch for {relative}: "
                f"expected {expected_sha256}, got {actual_sha256}"
            )
        entries += 1

    expected_entries = inventory["source_evidence_closure"]["manifest_entry_count"]
    if entries != expected_entries:
        raise RuntimeError(
            f"license evidence entry count mismatch: expected {expected_entries}, got {entries}"
        )


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--inventory-output", type=Path)
    parser.add_argument("--update-contract", action="store_true")
    parser.add_argument("--verify-tracked-contract", action="store_true")
    return parser.parse_args()


def main():
    args = parse_args()
    source_root = args.source_root.resolve()
    evidence_root = args.evidence_root.resolve()
    output = args.output_dir.resolve()
    archive = args.archive.resolve()

    inventory_path = ROOT / "parser-source-license-inventory.json"
    inventory = json.loads(inventory_path.read_text())
    definitions_path = source_root / "sources/language_definitions.json"
    cache_path = source_root / "sources/license_cache.json"
    definitions = json.loads(definitions_path.read_text())
    cache = json.loads(cache_path.read_text())

    for source, tracked in (
        (definitions_path, ROOT / "sources/language_definitions.json"),
        (cache_path, ROOT / "sources/license_cache.json"),
    ):
        if digest(source) != digest(tracked):
            raise RuntimeError(f"source bundle metadata differs from tracked {tracked.name}")

    verify_evidence_closure(inventory, evidence_root)

    if output.exists():
        shutil.rmtree(output)
    (output / "parsers").mkdir(parents=True)
    (output / "sources").mkdir()
    (output / "LICENSES").mkdir()

    records = {record["language"]: record for record in inventory["parsers"]}
    included = []
    excluded = []
    licenses = []
    for language in sorted(definitions):
        record = records[language]
        if language in EXCLUSIONS:
            excluded.append(
                {
                    "language": language,
                    "repository": record["repository"],
                    "revision": record["revision"],
                    "reason": EXCLUSIONS[language],
                }
            )
            continue
        if record["license_status"] != "primary-license-evidence-collected":
            raise RuntimeError(
                f"included parser {language} lacks exact primary license evidence"
            )

        parser_source = source_root / record["parser_directory"]
        if not parser_source.is_dir():
            raise RuntimeError(f"missing parser source directory: {parser_source}")
        shutil.copytree(
            parser_source,
            output / "parsers" / language,
            ignore=shutil.ignore_patterns("*.o"),
        )
        included.append(language)
        licenses.append(
            {
                "language": language,
                "repository": record["repository"],
                "revision": record["revision"],
                "license_evidence": record["license_files"],
                "detected_spdx": record["detected_spdx"],
            }
        )
        for evidence in record["license_files"]:
            evidence_path = Path(evidence["evidence_path"])
            if evidence_path.parts[0] != EVIDENCE_PREFIX.name:
                raise RuntimeError(
                    f"unexpected license evidence path for {language}: {evidence_path}"
                )
            source = evidence_root / evidence_path.relative_to(EVIDENCE_PREFIX)
            destination = output / "LICENSES" / language / evidence["path"]
            copy_verified(source, destination, evidence["sha256"])

    filtered = {language: definitions[language] for language in included}
    for definition in filtered.values():
        definition["ambiguous"] = {
            extension: [
                alternative for alternative in alternatives if alternative in filtered
            ]
            for extension, alternatives in definition.get("ambiguous", {}).items()
        }
    (output / "sources/language_definitions.json").write_text(
        json.dumps(filtered, indent=2, sort_keys=True) + "\n"
    )
    (output / "sources/license_cache.json").write_text(
        json.dumps(
            {
                key: value
                for key, value in cache.items()
                if any(key in record["repository"] for record in licenses)
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )

    report = {
        "schema_version": 2,
        "inclusion_rule": (
            "Only parsers with license text collected from the exact pinned source "
            "commit are included. Declaration-only, historical-text-only, conflicting, "
            "misidentified, and NOASSERTION records are excluded."
        ),
        "included_count": len(included),
        "excluded_count": len(excluded),
        "included_languages": included,
        "excluded_parsers": excluded,
        "aggregate_spdx": " AND ".join(
            sorted({spdx for entry in licenses for spdx in entry["detected_spdx"]})
        ),
        "licenses": licenses,
        "capability_impact": {
            "removed_language_names": [entry["language"] for entry in excluded],
            "runtime_downloads": (
                "blocked by Fedora patch; download APIs may use reviewed local cache only "
                "and otherwise return Error::Download"
            ),
            "dynamic_loading": "available for included languages only",
            "source_build": (
                "all included parser C/C++ sources compile at build time; .o files are excluded"
            ),
        },
    }
    (output / "LICENSES/INVENTORY.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )

    manifest_lines = []
    for path in sorted(output.rglob("*")):
        if path.is_file():
            manifest_lines.append(
                f"{digest(path)}  {path.relative_to(output).as_posix()}"
            )
    (output / "SHA256SUMS").write_text("\n".join(manifest_lines) + "\n")
    archive.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "tar",
            "--zstd",
            "--sort=name",
            "--mtime=@0",
            "--owner=0",
            "--group=0",
            "--numeric-owner",
            "-cf",
            str(archive),
            "-C",
            str(output),
            "parsers",
            "sources",
            "LICENSES",
            "SHA256SUMS",
        ],
        check=True,
    )
    report["closure_archive"] = archive.name
    report["closure_archive_sha256"] = digest(archive)
    report["closure_manifest_sha256"] = digest(output / "SHA256SUMS")

    if args.verify_tracked_contract:
        tracked_report = json.loads(
            (ROOT / "licensed-parser-subset-inventory.json").read_text()
        )
        if (output / "SHA256SUMS").read_bytes() != (ROOT / "SHA256SUMS").read_bytes():
            raise RuntimeError("generated subset manifest differs from tracked SHA256SUMS")
        expected_archive_sha256 = tracked_report["closure_archive_sha256"]
        if report["closure_archive_sha256"] != expected_archive_sha256:
            raise RuntimeError(
                "generated subset archive mismatch: "
                f"expected {expected_archive_sha256}, "
                f"got {report['closure_archive_sha256']}"
            )

    if args.inventory_output:
        args.inventory_output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    if args.update_contract:
        shutil.copy2(output / "SHA256SUMS", ROOT / "SHA256SUMS")
        (ROOT / "licensed-parser-subset-inventory.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n"
        )
        inventory["conservative_licensed_subset"] = {
            "included_count": len(included),
            "excluded_count": len(excluded),
            "aggregate_spdx": report["aggregate_spdx"],
            "classification": {
                language: ("included" if language in included else "excluded")
                for language in sorted(definitions)
            },
            "excluded_parsers": excluded,
            "closure": {
                "archive": report["closure_archive"],
                "archive_sha256": report["closure_archive_sha256"],
                "manifest_sha256": report["closure_manifest_sha256"],
            },
        }
        inventory_path.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n")

    print(
        f"Generated {len(included)} parser sources with {len(excluded)} exclusions: "
        f"{report['closure_archive_sha256']}"
    )


if __name__ == "__main__":
    main()
