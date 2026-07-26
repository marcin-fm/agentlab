# Disabled by package.yml. This spec deliberately aborts before unpacking or
# building until the selected web closure and OpenCode runtime are proven.
%global source_sha256 54a1724c872de6ba64955ca98fc8eeef73bc2e49739be1b27ba89deb10c5b115

Name:           openchamber
Version:        1.16.3
Release:        0.17%{?dist}
Summary:        Web interface and server for OpenCode

# MIT covers OpenChamber itself. Final metadata must include the audited
# package-local Node runtime closure.
License:        MIT
URL:            https://github.com/openchamber/openchamber
Source0:        https://github.com/openchamber/openchamber/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  bun = 1.3.14
BuildRequires:  nodejs24
BuildRequires:  nodejs24-devel
BuildRequires:  python3
BuildRequires:  tar
BuildRequires:  zstd
Requires:       nodejs24
Requires:       opencode

# Add the final private application closure only after its generated sources
# and checksums exist. Generate this block from the audited closure manifest.
# BEGIN GENERATED BUNDLED NODE PROVIDES
# END GENERATED BUNDLED NODE PROVIDES

%description
OpenChamber provides a browser and Progressive Web App interface for the
OpenCode coding agent, together with a local server and command-line launcher.

This draft intentionally selects the web CLI rather than the Electron desktop
shell. It must not produce an RPM until every source, native, generated-asset,
license, runtime-provider, and offline-build gate recorded in the package
metadata is complete.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo 'openchamber is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.17
- Classify exceptional source licenses and record the Fedora Remix Icon hold.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.16
- Inventory declared licenses and package-local license texts for selected sources

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.15
- Map the selected sherpa-onnx Linux payload to exact source

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.14
- Map Lightning CSS to exact source while retaining its legal hold

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.13
- Rebuild the selected Ghostty terminal WASM from exact subordinate source

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.12
- Record the exact subordinate source for the selected Shiki WASM

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.11
- Record the exact subordinate source for the selected source-map WASM

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.10
- Rebuild the selected Tailwind Oxide addon from released source

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.9
- Prove a reproducible Rollup 4.59.0 native companion build from exact source.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.8
- Prove a reproducible esbuild 0.27.3 companion build from exact upstream source.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.7
- Prove a reproducible node-pty rebuild from the selected source archive.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.6
- Prove a reproducible better-sqlite3 rebuild against Fedora system SQLite.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.5
- Classify native, WASM, and executable payloads while retaining fail-closed rebuild gates.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.4
- Materialize deterministic production/build and test-capable source bundles.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.3
- Acquire and inspect the complete selected immutable registry-source closure.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.2
- Derive the authoritative package-identity closure from fail-closed browser source reachability.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.16.3-0.1
- Refresh exact release and deterministic lock evidence while retaining all fail-closed build gates.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.16.1-0.2
- Add a deterministic Node-target lock selection while retaining fail-closed provenance and source-reachability gates.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.16.1-0.1
- Add a fail-closed draft for the released OpenChamber web CLI and PWA server.
