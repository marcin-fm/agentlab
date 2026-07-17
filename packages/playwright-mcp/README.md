# playwright-mcp

Blocked Fedora package draft for the released `@playwright/mcp` `0.0.78`
application. The package source is Apache-2.0 and the npm provenance
attestation identifies upstream tag `v0.0.78` at commit
`5f8fc00210b27b4407c375b59cda4838045d429c`.

Independent correspondence review is complete. All seven published npm files
byte-match the release tag. The release tag archive SHA-256 is
`9f4b1c550c24aaf202b422c568c105a6c29e4c3d10735cc317c56aa650cda3d7`.
The exact Playwright source commit archive SHA-256 is
`446cdbeb45255cc6e26fdf2ae604cd04fe77f4402b60fc0bd4b6edd302bcff46`.

## Immutable Runtime Inputs

| npm package | Version | SHA-256 |
| --- | --- | --- |
| `@playwright/mcp` | `0.0.78` | `cfff0fd8eae3ac3bcb39827861298cb6b483a8d72e3c558e7991658ed3d22562` |
| `playwright` | `1.62.0-alpha-1783623505000` | `738aa4e5602f023b68dbad49cf6bd93e8f2aa14277831109458de1262fad557a` |
| `playwright-core` | `1.62.0-alpha-1783623505000` | `a5412aee4ac779f1c662272f77fd5fe716218cf555c222a301f089447f49b24c` |

Those are the three top-level published runtime packages. Their generated
Playwright bundles are not a three-package source closure: the exact monorepo
lock has 719 non-root entries, including 679 integrity-pinned registry
tarballs. Platform metadata excludes 55 optional non-Linux or non-x86_64
payloads, leaving 624 Fedora Linux/x86_64 registry entries across 572 package
names. Fedora 43 and 44 provide no exact locked `npm(...)` version; only four
names exist at different versions, and RPM Fusion provides none.
`fsevents@2.3.2` is an optional Darwin-only dependency.

## Source Build Audit

The MCP package's `build` script is only `echo OK`; `roll.js` is a networked
release-maintenance script. The actual runtime comes from the exact Playwright
commit and imports `tools.createConnection` from generated
`playwright-core/lib/coreBundle`.

Playwright's normal build is monorepo-wide. It unconditionally installs a
separate stable-test-runner lock, compiles and bundles with esbuild, runs Vite
builds, generates types and browser metadata, and copies `xdg-open`. It exposes
no package or MCP-only build target. Its `--disable-install` option only disables
browser installation in watch mode; it does not skip the stable-test-runner
`npm ci` in a normal build.

The stable-test-runner lock is now bounded rather than an unknown secondary
closure. It contains four entries: `@playwright/test`, `playwright`, and
`playwright-core` `1.62.0-alpha-2026-07-06`, plus optional Darwin-only
`fsevents`. The three Linux packages have no install scripts or browser-download
edge, carry npm SLSA provenance to Playwright commit
`e9a206539527957abd177749dd893939d3c6c85c`, and have exact staged tarball and
source-archive hashes. The remaining issue is the upstream build's unskippable
`npm ci`, not an additional native or provenance gap.

The pinned esbuild `0.28.1` tool is source-buildable without its prebuilt
`@esbuild/linux-x64` payload. The exact tag builds the Go binary with
`CGO_ENABLED=0`, generates the neutral npm JavaScript module, and supports an
external exact-version binary. Fedora already uses this source-built binary plus
JavaScript/platform-module layout for esbuild `0.24.2` on Fedora 43 and `0.27.2`
on Fedora 44. An exact `0.28.1` compatibility provider is still missing, but the
prebuilt binary is no longer an architectural blocker.

The remaining Linux native build edges are Vite's required Rolldown `1.1.3`
and Lightning CSS `1.32.0` bindings. Both have exact released source tags and
N-API source-build paths, but Fedora 43/44 provide neither. Target-filtered
release graphs are smaller than the complete locks but still substantial:
Rolldown requires 239 registry crates and 45 workspace crates. Semver- and
feature-aware comparison leaves 80 unresolved provider edges on Fedora 43 and
81 on Fedora 44: 71/72 absent names, seven incompatible versions, and two
missing `valuable` feature providers. Lightning CSS requires 92 registry crates
and 7 workspace crates; 47 compatible Fedora versions reduce its unresolved
set to 20 on both releases, comprising ten absent names and ten incompatible
versions with no missing feature provider. The
optional DuckDB binding is referenced only by test/result-database utilities
and is not part of the normal generated-runtime build. Darwin-only `fsevents`
is excluded, and Playwright's browser-package install scripts honor
`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`.

Cargo metadata gives a bounded license starting point for those release
graphs. Rolldown's 284 active packages have no missing license field and reduce
to the provisional aggregate `Apache-2.0 AND BSD-2-Clause AND BSL-1.0 AND
CC0-1.0 AND ISC AND MIT AND Unicode-3.0 AND Zlib`. Lightning CSS's 99 active
packages reduce to `Apache-2.0 AND MIT AND MPL-2.0 AND Unicode-3.0`; its
publish-disabled `lightningcss_node` workspace crate omits a manifest license
field, while the tagged source carries the MPL-2.0 project license. These are
candidate binary-RPM expressions, not a substitute for verifying every source
license text and retaining the required notices.

The source-text audit is also bounded. The active Rolldown graph has local
license or notice files in 192 of 239 registry crates; the Lightning CSS graph
has them in 77 of 92. Immutable repository or canonical texts resolve 59 of the
resulting 62 omissions. The remaining MIT-only `base-encode`,
`json-escape-simd`, and `parcel_sourcemap` declarations do not identify the
required copyright and permission notice. Exhaustive checks of their Git
histories and every published crate release found no upstream notice, so those
three remain genuine blockers under project policy.

The published payloads contain 7 MCP files, 62 Playwright files, and 104
Playwright Core files. Five generated `.LICENSE` sidecars map 213 bundled
package entries to exact root-lock versions, but aggregate SPDX accounting and
the full immutable source/build/test closure remain incomplete.

The Linux/x86_64 root lock has license metadata for 614 of 624 active entries.
The ten exceptions are the Chrome, Chrome Beta, Chrome Canary, Chrome Dev,
Chromium, Edge, Firefox, Firefox Beta, Firefox Nightly, and Safari logo
packages used by the dashboard. Their npm tarballs contain no license or
notice, and their exact source repository states that all logos and trademarks
belong to their respective owners while only everything else is MIT-licensed.
All ten assets ship in the published dashboard: six are Vite-inlined SVG data
URIs and four are standalone SVG files. Packaging therefore requires explicit
redistribution/trademark review or an upstream-supported build that omits the
dashboard/logo payload; the repository MIT text does not clear the marks.
The logo packages are used only by `packages/dashboard`. The default MCP
surface does not enable `devtools`; the dashboard is required by the opt-in
`browser_annotate` path under `--caps=devtools`. A Fedora binary selecting the
default surface can therefore omit generated dashboard files, but Playwright's
normal build still compiles the dashboard unconditionally and still needs the
logo source inputs. Binary omission narrows runtime payload, not source closure.

The local-JavaScript minification gate is resolved. Playwright's common esbuild
step emits Node/CJS with source maps disabled in release mode and does not set
`minify`, so `coreBundle.js`, `utilsBundle.js`, `serverRegistry.js`, and the
Playwright Node bundles are bundled/transpiled but not minified. The exact
published files retain multiline formatting, named helpers, and source-path
comments. Production Vite output for dashboard/reporter/recorder/trace assets
is minified browser-targeted content and remains subject to generated-source and
license review. The copied `xdg-open` payload is a licensed POSIX shell script,
not JavaScript.

## Intentional Failure

`playwright-mcp.spec` exits in `%prep` before unpacking or building. It must
remain fail-closed until the records in `package.yml`, `dependencies.yml`, and
`reproducibility.yml` are all satisfied. In particular, no npm install,
lifecycle script, or Playwright browser download is permitted in an RPM build.

The remaining source gate is the generated Playwright runtime: compiled JS,
bundled modules, Vite/esbuild assets, generated browser metadata, and copied
`xdg-open` must be reproduced from Playwright commit
`9fb36027c64c8edcf08bf06f618b3ca97a7b0d97` with a complete offline build
closure, source-built tooling, and license evidence.

The intended browser is Fedora `chromium-headless` through
`/usr/lib64/chromium-browser/headless_shell`. Although the runtime metadata
requests Chromium `151.0.7922.10`, the exact MCP wrapper and Playwright alpha
successfully ran over stdio with Fedora 44 Chromium `150.0.7871.114`. The smoke
listed 24 tools, navigated to a local `data:` page, and evaluated its title, DOM,
and user agent without a browser download. This removes a hard
version-compatibility blocker; an RPM-packaged smoke must still be repeated in
both target chroots after the source-build closure is complete.

## References

- https://github.com/microsoft/playwright-mcp/releases/tag/v0.0.78
- https://registry.npmjs.org/-/npm/v1/attestations/@playwright%2fmcp@0.0.78
