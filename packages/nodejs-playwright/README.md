# nodejs-playwright

Blocked Fedora reusable-module draft for published `playwright` and
`playwright-core` `1.62.0-alpha-1783623505000`. One source package will build
the Playwright monorepo once and emit `nodejs-playwright` plus
`nodejs-playwright-core`.

The npm releases correspond to Playwright commit
`9fb36027c64c8edcf08bf06f618b3ca97a7b0d97`. The immutable commit archive has
SHA-256
`446cdbeb45255cc6e26fdf2ae604cd04fe77f4402b60fc0bd4b6edd302bcff46`.

## Release Inputs

| npm package | npm version | SHA-256 |
| --- | --- | --- |
| `playwright` | `1.62.0-alpha-1783623505000` | `738aa4e5602f023b68dbad49cf6bd93e8f2aa14277831109458de1262fad557a` |
| `playwright-core` | `1.62.0-alpha-1783623505000` | `a5412aee4ac779f1c662272f77fd5fe716218cf555c222a301f089447f49b24c` |

The RPM version is `1.62.0~alpha.1783623505000`, which sorts before the future
stable `1.62.0` release. The installed npm manifests retain the published
hyphenated semver.

## Metadata Boundary

Fedora's current Node provider generator emits the npm version literally. RPM
rejects `npm(playwright) = 1.62.0-alpha-1783623505000` because the capability
version has two hyphen separators. The requirement generator independently
discards the prerelease and turns the exact Core dependency into the widened
range `>= 1.62.0` and `< 1.62.1`.

The spec therefore suppresses automatic Node metadata for both installed root
manifests and declares exact normalized `npm(playwright)` and
`npm(playwright-core)` capabilities manually. It does not rewrite package.json
to a non-npm version.

## Source Build Boundary

The patched root lock contains 669 integrity-pinned registry tarballs. The
retained `nodejs-playwright-1.62.0-alpha-1783623505000-lock-closure.json`
receipt has SHA-256
`db12ef26e9b7ca91621418148f5b3f62c8992bed948b17167468089e53565fab` and
selects 611 records across 561 unique npm names for each Fedora glibc
target, x64 and arm64. The targets share 607 records and differ by the exact
DuckDB, esbuild, Rolldown, and Lightning CSS architecture bindings. The prior
614-record count incorrectly retained three musl-only packages.

This is a broad root-lock source inventory, not an authoritative role split.
Fedora 43 and 44 provide no exact locked npm versions. Playwright exposes no
package-only build target. Patch1 removes the test-only stable runner's
unconditional `npm ci` from the normal release-module build. The separately
bounded three-package Linux runner closure remains an input for a future
`%check` and must be materialized independently without package-manager
execution.

Exact source-built esbuild `0.28.1-0.2` is available from configured-SCM build
`10751965` across Fedora 43, Fedora 44, and Rawhide on both supported
architectures, and this draft now requires its `nodejs-esbuild` provider.
Rolldown `1.1.3` and Lightning CSS `1.32.0` remain unavailable. Rolldown's
public binding uses 239 registry plus 45 workspace crates and still leaves
approximately 75, 75, and 76 unresolved edges after current Agentlab providers
on Fedora 43, Fedora 44, and Rawhide. It therefore requires one reviewed
application-style vendored Cargo closure rather than dozens of compatibility
packages. Lightning CSS retains its separate bounded compatibility chain. RPM
phases may not run npm or another package manager, so all reviewed production,
build, and test sources must be materialized beforehand as immutable closure
inputs.

## License Boundary

The five published bundle sidecars contain 175 unique package/version
identities and reconcile to the pinned lock: 153 MIT, 14 ISC, 4 BSD-3-Clause,
1 BSD-2-Clause, 1 Apache-2.0, 1 BlueOak-1.0.0, and 1 CC-BY-4.0. In-tree Core
source adds CC0-1.0. The provisional complete-module expression is therefore
`Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BlueOak-1.0.0 AND
CC-BY-4.0 AND CC0-1.0 AND ISC AND MIT`.

The spec reproduces the existing 434-line Core in-tree notice with SHA-256
`c6bd7798e8e2d789797bfd574dbf574477cc76e5af2a301cf0f10e6031804f9a`.
The package remains blocked because the exact `base-encode 0.3.1` and
`parcel_sourcemap 2.1.1` crate and source revisions contain no required MIT
text or component notice. `json-escape-simd 3.0.2` also contains no MIT text or
attribution, and its source states that the implementation is borrowed from
Apache-2.0 `sonic-rs 0.5.5`; an MIT-only generated notice would therefore be
incomplete.

The lock receipt records source URLs, npm integrity values, declared license
fields, platform exclusions, workspaces, and the separate stable-runner lock.
It does not claim that archives, license texts, native/WASM sources, generated
outputs, binary inclusion, or the final production/build/test split are
verified.

Upstream's generated Core dashboard originally consumed ten exact
`@browser-logos/*` inputs whose marks are outside the source repository's MIT
grant. `playwright-dashboard-neutral-browser-icons.patch` removes those ten
dependencies and always uses the dashboard's existing neutral browser-family
initial fallback. The generated dashboard, public Core APIs, and exact
browser/channel tooltip remain intact, while the patched source closure contains
no browser-logo input requiring redistribution review.

## Intentional Failure

`nodejs-playwright.spec` verifies the two released npm tarballs and corresponding
source archive, reproduces the known Core notice, and exits in `%prep`. It must
remain fail-closed until the complete offline source build, module load tests,
upstream tests, license review, immutable hosting, and Fedora 43/44 validation
are complete.

## References

- https://registry.npmjs.org/playwright/-/playwright-1.62.0-alpha-1783623505000.tgz
- https://registry.npmjs.org/playwright-core/-/playwright-core-1.62.0-alpha-1783623505000.tgz
- https://github.com/microsoft/playwright/tree/9fb36027c64c8edcf08bf06f618b3ca97a7b0d97
- https://github.com/napi-rs/json-escape-simd/blob/a7eb4e70c5dc007ec618c53914e3301a0c159af7/src/lib.rs
- https://github.com/cloudwego/sonic-rs/blob/41ae6e8a5962da26eab34432d1412f35ea6d199e/LICENSE
- https://github.com/alrra/browser-logos/blob/7173185f6715f5f1e9be8b6654d8f3e3815f669b/README.md#legal
