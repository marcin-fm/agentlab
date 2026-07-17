#!/usr/bin/python3
"""Collect license evidence for the Rust crates linked into Kreuzberg."""

import argparse
import hashlib
import re
import shutil
import subprocess
from pathlib import Path


LICENSE_PREFIXES = ("copying", "copyright", "licence", "license", "notice", "unlicense")
PACKAGE_RE = re.compile(r":\s+([A-Za-z0-9_.-]+) v([^\s]+)(?:\s+\(.*\))?$")


def copy_file(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def rpm_license_files(manifest: Path) -> list[Path]:
    owners = subprocess.run(
        ["rpm", "-qf", "--qf", "%{NAME}\n", str(manifest)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()

    license_files = set()
    for owner in sorted(set(filter(None, owners))):
        files = subprocess.run(
            ["rpm", "-ql", owner],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        license_files.update(
            Path(path)
            for path in files
            if path.startswith("/usr/share/licenses/") and Path(path).is_file()
        )
    return sorted(license_files)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--registry", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    packages = set()
    for line in args.inventory.read_text(encoding="utf-8").splitlines():
        match = PACKAGE_RE.search(line)
        if not match:
            raise SystemExit(f"cannot parse license inventory line: {line}")
        packages.add(match.groups())

    args.output.mkdir(parents=True, exist_ok=True)
    missing = []
    workspace = []
    for name, version in sorted(packages):
        crate_dir = args.registry / f"{name}-{version}"
        if not crate_dir.is_dir():
            if name.startswith("kreuzberg"):
                workspace.append(f"{name}\t{version}")
                continue
            missing.append(f"{name} {version}: Cargo source directory not found")
            continue

        destination = args.output / f"{name}-{version}"
        copied = set()
        for source in crate_dir.rglob("*"):
            if source.is_file() and source.name.lower().startswith(LICENSE_PREFIXES):
                relative = Path("crate") / source.relative_to(crate_dir)
                copy_file(source, destination / relative)
                copied.add(relative)

        manifest = crate_dir / "Cargo.toml"
        for source in rpm_license_files(manifest):
            relative = Path("rpm") / source.relative_to("/usr/share/licenses")
            copy_file(source, destination / relative)
            copied.add(relative)

        if not copied:
            missing.append(f"{name} {version}: no license evidence found")

    if workspace:
        (args.output / "WORKSPACE-COVERED.tsv").write_text("\n".join(workspace) + "\n", encoding="utf-8")
    if missing:
        raise SystemExit("missing linked-crate license evidence:\n" + "\n".join(missing))

    manifest_lines = []
    for path in sorted(args.output.rglob("*")):
        if path.is_file() and path.name != "MANIFEST.sha256":
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            manifest_lines.append(f"{digest}  {path.relative_to(args.output)}")
    (args.output / "MANIFEST.sha256").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
