# Disabled by package.yml. This spec deliberately aborts before unpacking or
# building until the selected web closure and OpenCode runtime are proven.
%global source_sha256 54a1724c872de6ba64955ca98fc8eeef73bc2e49739be1b27ba89deb10c5b115

Name:           openchamber
Version:        1.16.3
Release:        0.4%{?dist}
Summary:        Web interface and server for OpenCode

# MIT covers OpenChamber itself. Final metadata must include the audited
# package-local Node runtime closure.
License:        MIT
URL:            https://github.com/openchamber/openchamber
Source0:        https://github.com/openchamber/openchamber/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  bun = 1.3.14
BuildRequires:  nodejs >= 22
BuildRequires:  nodejs-devel
BuildRequires:  python3
BuildRequires:  tar
BuildRequires:  zstd
Requires:       nodejs >= 22
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
