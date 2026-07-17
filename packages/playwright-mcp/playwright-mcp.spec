# Disabled by package.yml. This spec deliberately aborts before unpacking or
# building until the source and offline-closure gates are independently proven.
%global source_sha256 cfff0fd8eae3ac3bcb39827861298cb6b483a8d72e3c558e7991658ed3d22562
%global playwright_source_sha256 738aa4e5602f023b68dbad49cf6bd93e8f2aa14277831109458de1262fad557a
%global playwright_core_source_sha256 a5412aee4ac779f1c662272f77fd5fe716218cf555c222a301f089447f49b24c
%global playwright_version 1.62.0-alpha-1783623505000

Name:           playwright-mcp
Version:        0.0.78
Release:        0.4%{?dist}
Summary:        Model Context Protocol server for Playwright

License:        Apache-2.0
URL:            https://github.com/microsoft/playwright-mcp
Source0:        https://registry.npmjs.org/@playwright/mcp/-/mcp-%{version}.tgz
Source1:        https://registry.npmjs.org/playwright/-/playwright-%{playwright_version}.tgz
Source2:        https://registry.npmjs.org/playwright-core/-/playwright-core-%{playwright_version}.tgz

BuildArch:      noarch
BuildRequires:  chromium-headless
BuildRequires:  nodejs >= 20
Requires:       chromium-headless
Requires:       nodejs >= 20

Provides:       npm(@playwright/mcp) = %{version}

%description
Playwright MCP exposes Playwright browser automation through the Model Context
Protocol.

This source-build draft is intentionally blocked. It must not produce an RPM
until the source correspondence, audited offline Node closure, generated asset
and license evidence, system Chromium operation, and immutable closure hosting
are all proven.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{playwright_source_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{playwright_core_source_sha256}  %{SOURCE2}" | sha256sum -c -
echo 'playwright-mcp is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.4
- Record the system xdg-open integration for the headless MCP surface.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.3
- Record that the Node-executed generated runtime is not minified.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.2
- Record audited source-closure gates and the default MCP dashboard boundary.

* Thu Jul 16 2026 Marcin FM <marcin@lgic.pl> - 0.0.78-0.0.1
- Add a fail-closed draft for the released Playwright MCP server.
