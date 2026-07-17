# Disabled by package.yml. This spec deliberately aborts before unpacking or
# building until the source and offline-closure gates are independently proven.
%global source_sha256 cfff0fd8eae3ac3bcb39827861298cb6b483a8d72e3c558e7991658ed3d22562
%global playwright_source_sha256 738aa4e5602f023b68dbad49cf6bd93e8f2aa14277831109458de1262fad557a
%global playwright_core_source_sha256 a5412aee4ac779f1c662272f77fd5fe716218cf555c222a301f089447f49b24c
%global playwright_version 1.62.0-alpha-1783623505000
%global playwright_commit 9fb36027c64c8edcf08bf06f618b3ca97a7b0d97
%global playwright_commit_archive_sha256 446cdbeb45255cc6e26fdf2ae604cd04fe77f4402b60fc0bd4b6edd302bcff46
%global core_notices_sha256 c6bd7798e8e2d789797bfd574dbf574477cc76e5af2a301cf0f10e6031804f9a

Name:           playwright-mcp
Version:        0.0.78
Release:        0.10%{?dist}
Summary:        Model Context Protocol server for Playwright

License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BlueOak-1.0.0 AND CC0-1.0 AND ISC AND MIT
URL:            https://github.com/microsoft/playwright-mcp
Source0:        https://registry.npmjs.org/@playwright/mcp/-/mcp-%{version}.tgz
Source1:        https://registry.npmjs.org/playwright/-/playwright-%{playwright_version}.tgz
Source2:        https://registry.npmjs.org/playwright-core/-/playwright-core-%{playwright_version}.tgz
Source3:        https://codeload.github.com/microsoft/playwright/tar.gz/%{playwright_commit}#/playwright-%{playwright_commit}.tar.gz

BuildArch:      noarch
BuildRequires:  chromium-headless
BuildRequires:  nodejs >= 20
Requires:       chromium-headless
Requires:       nodejs >= 20

# Provisional scoped-root metadata. Regenerate this from the final installed
# tree; omit it if the selected CLI payload does not install the public module.
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
echo "%{playwright_commit_archive_sha256}  %{SOURCE3}" | sha256sum -c -
%setup -q -T -b 3 -n playwright-%{playwright_commit}
node <<'EOF'
const fs = require('fs');

const headers = [
  'packages/utils/third_party/pixelmatch.js',
  'packages/utils/third_party/extractZip.ts',
  'packages/utils/third_party/lockfile.ts',
  'packages/utils/stackTrace.ts',
  'packages/playwright-core/src/tools/cli-client/minimist.ts',
  'packages/playwright-core/src/client/eventEmitter.ts',
  'packages/injected/src/clock.ts',
  'packages/playwright-core/src/server/bidi/third_party/bidiProtocolCore.ts',
  'packages/playwright-core/src/server/bidi/third_party/bidiProtocolPermissions.ts',
  'packages/playwright-core/src/server/bidi/third_party/bidiProtocol.ts',
  'packages/playwright-core/src/server/bidi/third_party/bidiSerializer.ts',
  'packages/playwright-core/src/server/bidi/third_party/bidiKeyboard.ts',
  'packages/playwright-core/src/server/bidi/third_party/firefoxPrefs.ts',
];
const sections = [
  'Playwright Core in-tree third-party notices',
  'Generated from Playwright commit %{playwright_commit}.',
  'Each section below is reproduced verbatim from the named source path.',
  '',
];
const license = 'packages/playwright-core/src/server/bidi/third_party/LICENSE';
sections.push(`===== ${license} =====`, fs.readFileSync(license, 'utf8').trimEnd(), '');
for (const source of headers) {
  const match = fs.readFileSync(source, 'utf8').match(/^\/\*\*[\s\S]*?\*\//);
  if (!match)
    throw new Error(`missing initial notice: ${source}`);
  sections.push(`===== ${source} =====`, match[0], '');
}
fs.writeFileSync('PLAYWRIGHT-CORE-IN-TREE-NOTICES.txt', `${sections.join('\n')}\n`);
EOF
echo "%{core_notices_sha256}  PLAYWRIGHT-CORE-IN-TREE-NOTICES.txt" | sha256sum -c -
echo 'playwright-mcp is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
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
