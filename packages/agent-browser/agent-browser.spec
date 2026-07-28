# This source-build draft is intentionally blocked before unpacking or building.
%global source_sha256 313e7706485c246b818a2138dabc6f8784f91bfa25cae7db445e6ca14c730022

Name:           agent-browser
Version:        0.33.1
Release:        0.1%{?dist}
Summary:        Browser automation CLI for AI agents

# The final binary expression must add the reviewed linked Cargo closure and
# embedded axe-core notice boundary before this package can be enabled.
License:        Apache-2.0
URL:            https://github.com/vercel-labs/agent-browser
Source0:        https://github.com/vercel-labs/agent-browser/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  cargo-rpm-macros >= 24
Requires:       chromium

%description
Native Rust browser automation CLI for AI agents.

This package is a blocked source-build draft. It is intended to install the
source-built binary below %{_libexecdir}/agent-browser, the upstream skills/
and skill-data/ directories, and a public %{_bindir}/agent-browser command.
It must not use npm postinstall prebuilt downloads, Chrome for Testing
downloads, or package-manager mutation during RPM phases.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo 'agent-browser is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.1
- Add a fail-closed Fedora source-build draft for agent-browser 0.33.1.
