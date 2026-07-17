#!/usr/bin/env python3
"""Create the licensed, source-only parser subset used by Fedora packaging."""

import hashlib
import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
STAGING = ROOT.parent / "tree-sitter-language-pack-1.12.5"
OUT = ROOT / "licensed-parser-subset"
ARCHIVE = ROOT / "parser-sources-1.12.5-licensed-subset.tar.zst"

# These records have license text at their exact pins through the main closure.
# The four additions below are independently documented in the supplemental files.
INCLUDE_SUPPLEMENTAL = {
    "vb": ("MIT", "exact package declaration plus npm release with matching gitHead"),
    "gitcommit": ("WTFPL", "exact pinned LICENCE text and matching manifests"),
    "twig": ("WTFPL", "exact pinned LICENCE text and matching Cargo manifest"),
    "pgn": ("BSD-2-Clause", "pinned manifest plus preceding historical LICENSE text"),
}

EXCLUSIONS = {
    "groovy": "NOASSERTION: no governing declaration or license text at the pin",
    "facility": "MIT declaration only: no primary text or release linkage",
    "tmux": "MIT declarations only: published release points to a different commit",
    "cooklang": "NOASSERTION: exact Cargo MIT and package ISC declarations conflict",
    "brightscript": "misidentified Cargo metadata names a different repository",
    "eex": "misidentified Cargo metadata names a different grammar repository",
    "elsa": "MIT declaration only: no pinned primary text",
    "corn": "MIT declaration only: no pinned primary text",
    "move": "MIT declaration only: no pinned primary text",
    "eds": "MIT declaration only: no pinned primary text",
    "hjson": "source/package identity mismatch: hjson repository declares tree-sitter-jsonc",
}


def digest(path):
    sha = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def copy(path, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, destination)


def main():
    inventory = json.loads((ROOT / "parser-source-license-inventory.json").read_text())
    definitions = json.loads((ROOT / "sources/language_definitions.json").read_text())
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "parsers").mkdir(parents=True)
    (OUT / "sources").mkdir()
    (OUT / "LICENSES").mkdir()
    closure = OUT / "license-evidence"
    closure.mkdir()

    records = {record["language"]: record for record in inventory["parsers"]}
    included = []
    excluded = []
    licenses = []
    for language in sorted(definitions):
        record = records[language]
        primary = record["license_status"] == "primary-license-evidence-collected"
        supplemental = language in INCLUDE_SUPPLEMENTAL
        if language in EXCLUSIONS:
            excluded.append({"language": language, "repository": record["repository"], "revision": record["revision"], "reason": EXCLUSIONS[language]})
            continue
        if not (primary or supplemental):
            raise RuntimeError(f"unclassified parser {language}")
        shutil.copytree(ROOT / record["parser_directory"], OUT / "parsers" / language, ignore=shutil.ignore_patterns("*.o"))
        included.append(language)
        entry = {
            "language": language,
            "repository": record["repository"],
            "revision": record["revision"],
            "license_evidence": record["license_files"],
            "detected_spdx": record["detected_spdx"],
        }
        if supplemental:
            spdx, rationale = INCLUDE_SUPPLEMENTAL[language]
            entry["supplemental_spdx"] = spdx
            entry["supplemental_rationale"] = rationale
            entry["detected_spdx"] = [spdx]
        licenses.append(entry)
        for evidence in record["license_files"]:
            source = ROOT / evidence["evidence_path"]
            copy(source, closure / language / source.name)
            copy(source, OUT / "LICENSES" / f"{language}-{source.name}")

    # Preserve the checked supplemental materials rather than inventing upstream text.
    supplemental_files = {
        "vb": [
            ROOT / "unresolved-evidence-a/CodeAnt-AI/tree-sitter-vb-dotnet/cfca210ce8fdcb5245bd9cd5c47ce0a21a8488d5/package.json",
            ROOT / "unresolved-evidence-a/CodeAnt-AI/tree-sitter-vb-dotnet/cfca210ce8fdcb5245bd9cd5c47ce0a21a8488d5/npm-0.1.7.json",
        ],
        "gitcommit": [ROOT / "unresolved-evidence-a/gbprod/tree-sitter-gitcommit/49715a9e6f19ce3d33b875aacdd6ad8ddaee0ffe/tree-sitter-gitcommit-49715a9e6f19ce3d33b875aacdd6ad8ddaee0ffe/LICENCE"],
        "twig": [ROOT / "unresolved-evidence-b/gbprod-tree-sitter-twig-0afd9a6/LICENCE"],
        "pgn": [ROOT / "unresolved-evidence-b/rolandwalker-tree-sitter-pgn-be9cd4d/LICENSE-at-4f4954b"],
    }
    for language, paths in supplemental_files.items():
        for source in paths:
            copy(source, closure / language / source.name)
            copy(source, OUT / "LICENSES" / f"{language}-{source.name}")

    filtered = {language: definitions[language] for language in included}
    for definition in filtered.values():
        definition["ambiguous"] = {
            extension: [alternative for alternative in alternatives if alternative in filtered]
            for extension, alternatives in definition.get("ambiguous", {}).items()
        }
    (OUT / "sources/language_definitions.json").write_text(json.dumps(filtered, indent=2, sort_keys=True) + "\n")
    (OUT / "sources/license_cache.json").write_text(json.dumps({key: value for key, value in json.loads((ROOT / "sources/license_cache.json").read_text()).items() if any(key in record["repository"] for record in licenses)}, indent=2, sort_keys=True) + "\n")
    report = {
        "schema_version": 1,
        "inclusion_rule": "Pinned primary license text, or specifically recorded exact supplemental evidence with matching source identity. Declaration-only, conflicting, misidentified, and NOASSERTION records are excluded.",
        "included_count": len(included),
        "excluded_count": len(excluded),
        "included_languages": included,
        "excluded_parsers": excluded,
        "aggregate_spdx": " AND ".join(sorted({spdx for entry in licenses for spdx in entry["detected_spdx"]})),
        "licenses": licenses,
        "capability_impact": {
            "removed_language_names": [entry["language"] for entry in excluded],
            "runtime_downloads": "blocked by Fedora patch; download APIs may use reviewed local cache only and otherwise return Error::Download",
            "dynamic_loading": "available for included languages only",
            "source_build": "all included parser C/C++ sources compile at build time; .o files are excluded",
        },
    }
    (OUT / "LICENSES/INVENTORY.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    (ROOT / "licensed-parser-subset-inventory.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    manifest_lines = []
    for path in sorted(OUT.rglob("*")):
        if path.is_file():
            manifest_lines.append(f"{digest(path)}  {path.relative_to(OUT).as_posix()}")
    (OUT / "SHA256SUMS").write_text("\n".join(manifest_lines) + "\n")
    subprocess.run(["tar", "--zstd", "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner", "-cf", str(ARCHIVE), "-C", str(OUT), "parsers", "sources", "LICENSES", "license-evidence", "SHA256SUMS"], check=True)
    shutil.copy2(ARCHIVE, STAGING / ARCHIVE.name)
    for patch in (
        "tree-sitter-language-pack-fedora-offline.patch",
        "tree-sitter-language-pack-relax-insta.patch",
        "tree-sitter-language-pack-fedora-static-subset.patch",
    ):
        shutil.copy2(ROOT / patch, STAGING / patch)
    report["closure_archive"] = ARCHIVE.name
    report["closure_archive_sha256"] = digest(ARCHIVE)
    report["closure_manifest_sha256"] = digest(OUT / "SHA256SUMS")
    (ROOT / "licensed-parser-subset-inventory.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
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
    (ROOT / "parser-source-license-inventory.json").write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
