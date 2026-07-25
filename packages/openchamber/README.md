# OpenChamber Packaging Status

OpenChamber `1.16.3` is not enabled for COPR. This draft packages the released
`@openchamber/web` CLI/PWA server, which is upstream's practical Linux path,
rather than the Electron desktop shell. Upstream disables the release's Linux
desktop build and publish jobs, and `v1.16.3` contains no Linux desktop asset.

The immutable `v1.16.3` tag resolves to commit
`8040d43b251a015eb06d96135a442abd4d2f2e27`. Its source archive has SHA-256
`54a1724c872de6ba64955ca98fc8eeef73bc2e49739be1b27ba89deb10c5b115`.
The project is MIT-licensed, uses Bun `1.3.14` for workspace management and
builds, and requires Node.js 22 or newer.

The selected package is `packages/web`. Its `openchamber` executable starts the
local web server under Node.js and locates an independently installed OpenCode
CLI on `PATH` or through `OPENCODE_BINARY`. The source build still requires the
pinned Bun toolchain and an exact offline dependency reconstruction.

OpenCode and OpenChamber both resolve `bun-pty 0.4.8`, but they do not share a
runtime package boundary. OpenCode rebuilds bun-pty as a package-local input to
its standalone Bun compilation. In OpenChamber,
`packages/web/server/lib/terminal/runtime.js:42-64` imports bun-pty only when
`globalThis.Bun` exists and otherwise loads `node-pty`. This draft selects Node,
so it excludes bun-pty by design rather than creating a one-consumer shared RPM;
the derived closure and installed-runtime smoke must still prove that result.

The draft remains blocked until:

1. Fedora-source-built Bun `1.3.14` is available.
2. The checked immutable sources are materialized without package-manager
   resolution or lifecycle scripts during RPM phases.
3. The classified native, WASM, and executable payloads are rebuilt from exact
   corresponding source or excluded through a supported target boundary.
4. Vite and PWA generated assets are rebuilt with corresponding-source proof.
5. The shipped closure's licenses and `bundled(nodejs-...)` metadata are
   generated from the actual runtime payload.
6. The separate Agentlab `opencode` provider is eligible.
7. Offline Fedora builds and installed CLI, server, and browser smokes pass on
   the selected architectures. A Node-only smoke must prove `node-pty` selection,
   bun-pty absence, and OpenCode discovery through both `PATH` and
   `OPENCODE_BINARY`.

`openchamber.spec` therefore verifies only `Source0` and aborts unconditionally
in `%prep`. Do not replace missing closure inputs with upstream AppImages,
Electron bundles, npm installs, or platform-native package binaries.

## Deterministic Lock Selection

`openchamber-1.16.3-selected-lock-audit.json` is generated directly from the
released `bun.lock` by `scripts/audit-openchamber-lock-closure`; it performs no
dependency resolution. For the Linux x86_64 glibc Node target it records 832
selected packages: 221 runtime, 564 build, and 47 test records. All selected
sources are registry records, 76 incompatible platform records are excluded,
and the checked `@tanstack/virtual-core@3.17.3` patch is linked to its selected
package record.

The receipt enforces the Node PTY boundary: `node-pty` is selected once and
`bun-pty` is present only as an explicit policy exclusion. It also verifies
that the root, `packages/web`, and `packages/ui` dependency maps in `bun.lock`
match their release manifests.

The package-identity closure is authoritative for the selected release surface.
The audit starts at the web, mobile, mini-chat, and PWA service-worker entries;
resolves the exact Vite aliases, relative/static imports, literal dynamic
imports, CSS imports, and Vite query suffixes; and expands the checked provider
logo `import.meta.glob`. It reaches 845 local files and 59 direct package roots,
then retains each selected root's complete transitive `bun.lock` closure.

The lock still omits the root importer version and reports `1.16.2` for both
`packages/web` and `packages/ui`, while all three manifests report `1.16.3`.
Those original bytes and values remain visible. The receipt records an explicit
package-identity normalization based only on exact dependency-map equality; it
does not claim that upstream corrected the importer versions. Immutable source
acquisition, native rebuilds, generated browser output, licenses, final binary
inclusion, bundled Provides, and offline builds remain fail-closed.

## Immutable Source Acquisition

`openchamber-1.16.3-source-audit.json` binds the selected-lock receipt to 818
unique npm registry archives for the 832 selected package records. The
resumable acquisition verifies every lockfile SHA-512, records each archive's
SHA-256 and size, rejects unsafe paths and special entries, and confirms the
matching package name and version without executing dependency resolution or
lifecycle scripts.

The archive inspection finds no missing license declarations, 27 packages
without package-local license files, 98 sources with 100 lifecycle scripts, six
sources containing 24 native payloads, three sources containing four WASM
payloads, five sources containing 10 non-source executable payloads, and five
sources containing native build inputs. These are inventory facts, not legal or
build approval: license, native-source, generated-output, final payload, and
offline materialization gates remain false.

## Deterministic Source Bundles

`openchamber-1.16.3-source-materialization.json` binds the acquisition receipt to two raw-source
bundles. The production/build archive contains 771 unique sources with runtime
or build roles and is 72,887,509 bytes at SHA-256
`2535235a626815e8db08b4f100d94b1b14527f6420d9fd019c3c295b9fde99f3`.
The complete test-capable superset contains all 818 sources and is 78,857,956
bytes at SHA-256
`41d6d5f4c8dc6fddca20b5c9003be98a5c25f2124c266bf14e4b46ca497c3b7f`.

Both archives preserve the checked registry tarballs unchanged below fixed
roots, normalize archive metadata, and reproduce byte-for-byte when generated
twice and during a cache-only check. This is source bundling, not a package
install: no network, node_modules generation, dependency resolution, patch
application, lifecycle script, native rebuild, package build, or RPM integration
occurs. Immutable delivery of the generated bundles and the later offline build
remain blocked.

## Native Payload Review

`openchamber-1.16.3-native-review.yml` classifies all 14 source identities that
contain native payloads, WASM, executable-bit files, or native build inputs. It
binds exact path-set digests to the immutable source audit rather than copying
prebuilt payloads into a prospective package.

The review excludes three mobile-only Capacitor source/mode findings from the
Linux target, records `better-sqlite3` and `node-pty` as same-archive rebuild
candidates, and retains `node-addon-api` only as build support. Three platform
companions still need exact source builds. Selected esbuild `0.27.3` now builds
twice byte-identically from exact tag source because Agentlab's `0.28.1` provider
cannot satisfy the wrapper's exact binary version contract. Three generated WASM
inputs still need exact subordinate source correspondence. No prebuilt payload is
approved, and six source mappings remain unresolved. `better-sqlite3 12.10.0`
now rebuilds twice
byte-identically for Node 24 ABI 137 against Fedora SQLite 3.51.2, with no
prebuild download or bundled SQLite linkage; every other native/WASM rebuild
and final OpenChamber inclusion claim remains false.

`node-pty 1.2.0-beta.12` also rebuilds twice byte-identically for Node 24 ABI
137 from the selected source and `node-addon-api 7.1.1`. Linux spawn, resize,
exit-code, and open-PTY smokes pass without lifecycle scripts or published
prebuilds; final OpenChamber inclusion remains unverified.

`@esbuild/linux-x64 0.27.3` is replaced by a four-job, network-isolated build
from upstream tag `v0.27.3` and its pinned `golang.org/x/sys` module. Two builds
produce the same executable at SHA-256
`9ef2af828dc9fb5a267d445f07933fa856a8602287abe5bca321ebe0c1f509b7`;
the upstream Go suite passes, and the selected npm wrapper reports `0.27.3` and
performs a TypeScript transform with that executable. Final offline bundle
inclusion remains unverified.

`@rollup/rollup-linux-x64-gnu 4.59.0` is rebuilt from exact upstream tag
`v4.59.0` and its checksum-locked 207-crate Cargo source closure. The immutable
tag archive matches all 13,216 tracked source entries. Two four-job,
network-isolated builds with `SOURCE_DATE_EPOCH` fixed to the release commit
produce the same N-API addon at SHA-256
`03346461e32aa501d7fc09f6d618f5b604d0979dab64fc78ce7eb9727f80b8d0`;
direct parse/hash calls and the exact Rollup `4.59.0` wrapper bundling API pass
under Node 24. Immutable Cargo-vendor delivery and final bundle inclusion remain
unverified.
