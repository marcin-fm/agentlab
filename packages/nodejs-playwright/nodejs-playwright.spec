# Disabled by package.yml. This spec deliberately aborts before building until
# the complete Playwright monorepo closure is source-proven and hosted.
%global source_sha256 738aa4e5602f023b68dbad49cf6bd93e8f2aa14277831109458de1262fad557a
%global core_source_sha256 a5412aee4ac779f1c662272f77fd5fe716218cf555c222a301f089447f49b24c
%global npm_version 1.62.0-alpha-1783623505000
%global playwright_commit 9fb36027c64c8edcf08bf06f618b3ca97a7b0d97
%global playwright_commit_archive_sha256 446cdbeb45255cc6e26fdf2ae604cd04fe77f4402b60fc0bd4b6edd302bcff46
%global core_notices_sha256 c6bd7798e8e2d789797bfd574dbf574477cc76e5af2a301cf0f10e6031804f9a

# Fedora's current Node generators emit the raw npm prerelease as an invalid
# RPM version and discard it from generated requirements. Preserve the npm
# manifests and provide the normalized capabilities explicitly below.
%global __provides_exclude_from ^%{nodejs_sitelib}/playwright
%global __requires_exclude_from ^%{nodejs_sitelib}/playwright
%global __suggests_exclude_from ^%{nodejs_sitelib}/playwright

Name:           nodejs-playwright
Version:        1.62.0~alpha.1783623505000
Release:        0.1%{?dist}
Summary:        High-level browser automation API for Node.js

License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BlueOak-1.0.0 AND CC-BY-4.0 AND CC0-1.0 AND ISC AND MIT
URL:            https://playwright.dev
Source0:        https://registry.npmjs.org/playwright/-/playwright-%{npm_version}.tgz
Source1:        https://registry.npmjs.org/playwright-core/-/playwright-core-%{npm_version}.tgz
Source2:        https://codeload.github.com/microsoft/playwright/tar.gz/%{playwright_commit}#/playwright-%{playwright_commit}.tar.gz

BuildArch:      noarch
ExclusiveArch:  %{nodejs_arches} noarch
BuildRequires:  nodejs-devel
Requires:       nodejs >= 20
Requires:       nodejs-playwright-core = %{version}-%{release}

Provides:       npm(playwright) = %{version}

%description
Playwright is a high-level Node.js API for browser automation. This source
package builds the public playwright and playwright-core modules from one
monorepo source tree.

This draft is intentionally blocked. It must not produce RPMs until the exact
offline build and test closures, generated assets, native build tools, complete
license inventory, and immutable source hosting are proven.

%package core
Summary:        Core browser automation library for Playwright
Requires:       nodejs >= 20
Provides:       npm(playwright-core) = %{version}

%description core
Playwright Core provides the browser automation protocol and runtime used by
the higher-level Playwright module and downstream applications.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{core_source_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{playwright_commit_archive_sha256}  %{SOURCE2}" | sha256sum -c -
%setup -q -T -b 2 -n playwright-%{playwright_commit}
%{__nodejs} <<'EOF'
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
echo 'nodejs-playwright is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.62.0~alpha.1783623505000-0.1
- Add a fail-closed reusable-module split for Playwright and Playwright Core.
