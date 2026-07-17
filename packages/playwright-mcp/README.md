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
tarballs. `fsevents@2.3.2` is an optional Darwin-only dependency.

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

The pinned esbuild `0.28.1` tool is source-buildable without its prebuilt
`@esbuild/linux-x64` payload. The exact tag builds the Go binary with
`CGO_ENABLED=0`, generates the neutral npm JavaScript module, and supports an
external exact-version binary. Fedora already uses this source-built binary plus
JavaScript/platform-module layout for esbuild `0.24.2` on Fedora 43 and `0.27.2`
on Fedora 44. An exact `0.28.1` compatibility provider is still missing, but the
prebuilt binary is no longer an architectural blocker.

The published payloads contain 7 MCP files, 62 Playwright files, and 104
Playwright Core files. Five generated `.LICENSE` sidecars map 213 bundled
package entries to exact root-lock versions, but aggregate SPDX accounting and
the full immutable source/build/test closure remain incomplete.

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
