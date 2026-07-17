# Disabled by package.yml. This spec deliberately aborts before unpacking or
# building until the source and offline-closure gates are independently proven.
%global source_sha256 cfff0fd8eae3ac3bcb39827861298cb6b483a8d72e3c558e7991658ed3d22562
%global playwright_rpm_version 1.62.0~alpha.1783623505000

Name:           playwright-mcp
Version:        0.0.78
Release:        0.14%{?dist}
Summary:        Model Context Protocol server for Playwright

License:        Apache-2.0
URL:            https://github.com/microsoft/playwright-mcp
Source0:        https://registry.npmjs.org/@playwright/mcp/-/mcp-%{version}.tgz

BuildArch:      noarch
ExclusiveArch:  %{nodejs_arches} noarch
BuildRequires:  chromium-headless
BuildRequires:  nodejs-devel
BuildRequires:  nodejs >= 20
Requires:       chromium-headless
Requires:       nodejs >= 20
Requires:       npm(playwright) = %{playwright_rpm_version}
Requires:       npm(playwright-core) = %{playwright_rpm_version}

# Fedora's current Node file attribute does not match scoped installed roots.
Provides:       npm(@playwright/mcp) = %{version}

%description
Playwright MCP exposes Playwright browser automation through the Model Context
Protocol.

This draft is intentionally blocked. It must not produce an RPM until the
separate nodejs-playwright provider, MCP integration tests, and packaged Fedora
operation are all proven.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo 'playwright-mcp is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.14
- Record the test-runner separation in the reusable Playwright provider.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.13
- Record the neutral dashboard icon provider closure.
- Accept the documented same-user code-execution risk and require isolated service deployment.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.12
- Split reusable Playwright modules into the nodejs-playwright source package.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.11
- Record the exact unsafe-tool VM escape and host-write proof.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.10
- Record the unfilterable unsafe tool in the default MCP surface.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.9
- Record the upstream command-surface boundary for the selected profile.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.8
- Generate the Core in-tree notice payload from the pinned source archive.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.7
- Pin the exact Playwright source archive and record Core bundle notices.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.6
- Record the selected headless payload's bounded license inventory.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.5
- Record the audited default headless MCP runtime payload boundary.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.4
- Record the system xdg-open integration for the headless MCP surface.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.3
- Record that the Node-executed generated runtime is not minified.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.2
- Record audited source-closure gates and the default MCP dashboard boundary.

* Thu Jul 16 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.0.1
- Add a fail-closed draft for the released Playwright MCP server.
