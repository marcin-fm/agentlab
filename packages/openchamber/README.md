# OpenChamber Packaging Status

OpenChamber `1.16.1` is not enabled for COPR. This draft packages the released
`@openchamber/web` CLI/PWA server, which is upstream's practical Linux path,
rather than the Electron desktop shell. Upstream disables the release's Linux
desktop build and publish jobs, and `v1.16.1` contains no Linux desktop asset.

The immutable `v1.16.1` tag resolves to commit
`ee10f85d9ca866387abf7285985b268c8e3fa601`. Its source archive has SHA-256
`9457c4fa86ba5bf236c14648d94403af65915235fa9089ca9947a09532482018`.
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
2. The exact production, build, and test closure is selected from `bun.lock`,
   acquired as immutable sources, and materialized without package-manager
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

`openchamber-1.16.1-selected-lock-audit.json` is generated directly from the
released `bun.lock` by `scripts/audit-openchamber-lock-closure`; it performs no
dependency resolution. For the Linux x86_64 glibc Node target it records 934
selected packages: 221 runtime, 666 build, and 47 test records. All selected
sources are registry records, 76 incompatible platform records are excluded,
and the checked `@tanstack/virtual-core@3.17.3` patch is linked to its selected
package record.

The receipt enforces the Node PTY boundary: `node-pty` is selected once and
`bun-pty` is present only as an explicit policy exclusion. It also verifies
that the root, `packages/web`, and `packages/ui` dependency maps in `bun.lock`
match their release manifests.

This is not yet the authoritative closure. The lock omits the root importer
version and reports `1.14.1` for both `packages/web` and `packages/ui`, while
all three manifests report `1.16.1`. The current build selection also includes
all `packages/ui` dependencies as a conservative source-alias boundary until
exact Vite entrypoint reachability is proven. The receipt records both gates
as false instead of normalizing or hiding them.
