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

## Package Split

The reusable runtime is now owned by one `nodejs-playwright` source package,
which will build the Playwright monorepo once and emit `nodejs-playwright` plus
`nodejs-playwright-core`. This package owns only the released
`@playwright/mcp` public module and requires both exact normalized capabilities:
`1.62.0~alpha.1783623505000`.

The original npm manifests retain
`1.62.0-alpha-1783623505000`. Fedora's automatic Node provider emits that raw
prerelease as invalid RPM syntax and its requirement generator discards the
prerelease, so `nodejs-playwright` suppresses those automatic root records and
declares exact RPM-normalized metadata manually.

## Provider Release Inputs

| npm package | Version | SHA-256 |
| --- | --- | --- |
| `@playwright/mcp` | `0.0.78` | `cfff0fd8eae3ac3bcb39827861298cb6b483a8d72e3c558e7991658ed3d22562` |
| `playwright` | `1.62.0-alpha-1783623505000` | `738aa4e5602f023b68dbad49cf6bd93e8f2aa14277831109458de1262fad557a` |
| `playwright-core` | `1.62.0-alpha-1783623505000` | `a5412aee4ac779f1c662272f77fd5fe716218cf555c222a301f089447f49b24c` |

The MCP tarball is this package's only source. The two Playwright tarballs are
canonical inputs of `nodejs-playwright` and are retained here as exact provider
evidence. Their generated
Playwright bundles are not a three-package source closure: the exact monorepo
lock has 719 non-root entries, including 679 integrity-pinned registry
tarballs. Platform metadata excludes 55 optional non-Linux or non-x86_64
payloads, leaving 624 Fedora Linux/x86_64 registry entries across 572 package
names. Fedora 43 and 44 provide no exact locked `npm(...)` version; only four
names exist at different versions, and RPM Fusion provides none.
`fsevents@2.3.2` is an optional Darwin-only dependency.

## Provider Source Build Audit

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

The selected default headless CLI surface has a much smaller installed-payload
boundary. An enforced package-file denylist smoke needed only 11 files totaling
`6,798,642` bytes, or 37.85% of the three published payloads: MCP `cli.js`, its
manifest and license; Playwright Core `coreBundle.js`, `utilsBundle.js`,
`utilsBundle.js.LICENSE`, `package.json`, `browsers.json`, and its three legal
files. Removing either Core manifest or `browsers.json` failed before MCP
startup; with those restored, the reduced boundary listed 24 tools and passed
local navigation/evaluation through Fedora Chromium without downloads. It does
not install the `playwright` package, the programmatic MCP entry, server
registry, Vite assets, copied executables, or optional UI/tooling trees. This is
a CLI application payload, not the complete public npm module, so the draft
root `npm(@playwright/mcp)` Provide remains provisional and must be regenerated
or omitted from the exact installed tree.

That selected binary retains only `utilsBundle.js.LICENSE` from the five
published bundle sidecars. Its 91 unique package/version entries all match the
root lock and carry full embedded notice text: 76 MIT, 9 ISC, 4 BSD-3-Clause,
1 BSD-2-Clause, and 1 BlueOak-1.0.0. Fedora marks BlueOak-1.0.0 allowed. Direct
reconciliation of all 400 `coreBundle.js` source markers adds CC0-1.0 and gives
the provisional selected-binary expression `Apache-2.0 AND BSD-2-Clause AND
BSD-3-Clause AND BlueOak-1.0.0 AND CC0-1.0 AND ISC AND MIT`. This is 91 of the
published five-sidecar set's 213 entries, a 57.28% reduction.

Upstream generates `.js.LICENSE` sidecars only for inlined npm packages, so it
does not preserve the source headers stripped from `coreBundle.js`. A future
build must generate one packaging notice directly from the pinned Playwright
source archive, carrying the exact headers for Mapbox `pixelmatch` (ISC), Max
Ogden `extractZip` (BSD-2-Clause), Made With MOXY/Microsoft `lockfile` (MIT),
Isaac Schlueter/James Talmage/Microsoft `stackTrace` (MIT), James Halliday's
`minimist` (MIT), Joyent/Microsoft `eventEmitter` (MIT), Christian
Johansen/Microsoft `clock` (BSD-3-Clause), and the Chromium BiDi/Puppeteer
Apache-2.0 attributions. The CC0 tokenizer states that reproduction is not
required. The draft spec now generates the 434-line notice directly from the
checksummed source archive and verifies SHA-256
`c6bd7798e8e2d789797bfd574dbf574477cc76e5af2a301cf0f10e6031804f9a`.
It remains uninstalled because the package is fail-closed before `%build`.

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

The copied `xdg-open` gate is also resolved for the selected headless surface.
Playwright copies the MIT-licensed `open@11.0.0` script, upstream xdg-utils
`1.2.1`, into `playwright-core/lib`, but the generated bundled code detects its
bundle context and executes the system command `xdg-open` instead of that local
copy. Fedora 43 and 44 both provide xdg-utils `1.2.1`. Default headless MCP
stdio does not open reports, traces, or dashboard file locations, so the dead
copied file can be omitted from the binary. A future headed/report/dashboard
surface would require the Fedora `xdg-utils` runtime dependency.

## Command Surface

Upstream defaults to stdio when no port is configured, and the selected
canonical invocation is source-supported:

```text
playwright-mcp --browser chromium --headless --isolated \
  --executable-path /usr/lib64/chromium-browser/headless_shell \
  --image-responses omit
```

That profile omits additional capabilities and uses the 24 default core tools,
but the released executable cannot enforce it. The same command accepts
`--port`/`--host` for Streamable HTTP and legacy SSE, remote/CDP/extension
browser connections, optional capabilities, proxy and origin controls,
unrestricted filesystem access, and JSON/INI or `PLAYWRIGHT_MCP_*` overrides.
Its `install-browser` alias also invokes Playwright's managed browser installer.
No upstream option disables those alternate modes. Under the current selected
surface policy, the package remains blocked until upstream supplies a bounded
entry point or the maintainer explicitly accepts the broader direct CLI; a
downstream security wrapper or protocol adapter is not authorized.

The default 24-tool set has a separate mandatory hold. Upstream's own capability
test includes `browser_run_code_unsafe`, whose source marks it as `core` and
describes it as arbitrary JavaScript in the Playwright server process and
RCE-equivalent. Default filtering includes every capability beginning with
`core`; no per-tool exclude or denylist exists. The nearby
`browser_press_sequentially` helper is `skillOnly` and is correctly excluded,
so the published and executable default count remains exactly 24. Managed
browser installation is not one of those MCP tools; it remains the separate
`install-browser` CLI alias. The package cannot expose a policy-bounded default
tool set without an upstream exclusion mechanism, explicit maintainer approval
for a downstream filter, or a separately approved process sandbox.

This is an observed host boundary failure, not only an upstream warning. An
exact-runtime MCP smoke called `browser_run_code_unsafe` through the published
CLI and Fedora Chromium. Code running in the tool's `vm` context reached the
host `process` through the live Playwright `page` object, loaded Node's built-in
`fs` module, and wrote a marker under the audit root. The marker content had
SHA-256 `d74568fdd4ec92e9d21cf2c2c8d407690f747bfa5fc06575e4561e0aecde2933`
and was removed after verification. The same smoke confirmed the exact 24-tool
list and used no browser download. A real per-tool exclusion or independently
approved process sandbox is therefore mandatory before publication.

## Intentional Failure

`playwright-mcp.spec` verifies only the released MCP npm tarball and exits in
`%prep`. It must remain fail-closed until the exact `nodejs-playwright`
providers are complete, the packaged Fedora 43/44 integration passes, and the
command/tool policy is resolved. No npm install, lifecycle script, or Playwright
browser download is permitted in an RPM build.

The generated Playwright runtime, its Core notice, native build tools, complete
module license inventory, and immutable closure are now canonical
`nodejs-playwright` responsibilities. The detailed evidence above remains here
to preserve the MCP dependency audit.

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
