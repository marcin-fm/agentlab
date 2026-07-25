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
3. `better-sqlite3`, `node-pty`, `sherpa-onnx-node`, and every other
   native or platform payload are classified and rebuilt from source.
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
