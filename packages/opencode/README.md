# OpenCode Packaging Status

OpenCode `1.18.3` is not enabled for COPR. The released GitHub tag is valid source, but the project builds with Bun and has a large CLI source closure that is not present in the release archive. Fedora's Node.js application guidance permits this private application closure to remain bundled; it does not require one RPM per ordinary npm dependency. The last detailed closure audit covered `1.17.20`, so the current release must be regenerated and reviewed before enablement.

The immutable `v1.18.3` tag resolves to commit
`127bdb30784d508cc556c71a0f32b508a3061517`, and its source archive has
SHA-256 `494041aedd7407079f91fd694de355f4ff022ba6bf876e09ff30983bbdc70ae1`.
The root lock contains 37 workspace records and 3,215 package records. Those
are lockfile-wide inventory counts, not the standalone Linux binary closure
and not valid `bundled(nodejs-...)` input.

## Selected Lock Audit

`scripts/audit-opencode-lock-closure` now performs a source-only traversal of
the released Bun lock for the Linux x86_64 glibc terminal CLI. The selected
feature surface uses upstream's `--skip-embed-web-ui` build flag, excluding the
app/Vite/Sentry path without patching product code. It selects 14 workspaces and
1,014 runtime package records, all from the npm registry, while 36 non-target
platform records are excluded.

The deterministic receipt is
[`opencode-1.18.3-selected-lock-audit.json`](opencode-1.18.3-selected-lock-audit.json),
SHA-256 `2edb9d0fb479330a5d5466a1ff1a1aa9d468b43352f1e20d9b2c95306238a0f0`.
It intentionally does not claim source archive verification, license review,
binary inclusion, or final bundled Provides. Regenerate or verify it with:

```bash
scripts/audit-opencode-lock-closure \
  --source-dir /srv/tmp/agentlab-opencode/source/opencode-1.18.3
scripts/audit-opencode-lock-closure \
  --source-dir /srv/tmp/agentlab-opencode/source/opencode-1.18.3 --check
```

The standalone build also fetches `https://models.dev/api.json` unless
`MODELS_DEV_API_JSON` supplies a local file. The release does not pin that
snapshot, so immutable source acquisition remains a separate blocker.

## Source Acquisition Audit

`scripts/acquire-opencode-sources` deduplicates the selected package paths to
826 unique npm registry sources. Every archive passed its released SHA-512
integrity check, every retained archive has a SHA-256 receipt, and archive
path/type validation passed. The resumable cache is under
`/srv/tmp/agentlab-opencode/source-acquisition-1.18.3`.

The deterministic receipt is
[`opencode-1.18.3-source-audit.json`](opencode-1.18.3-source-audit.json),
SHA-256 `0f067275e2513d5e2cb6658ba9b58fef42549f2fbeb650c3bd1c65fac1b8f179`.
It records these unresolved gates:

- 3 raw source archives without declared license metadata; all three are
  resolved from authoritative upstream evidence in
  [`license-review.yml`](license-review.yml). Another 28 do not include
  package-local license files; their texts are conditional on final source or
  binary inclusion rather than automatic payload copies.
- 73 lifecycle-script sources, including 5 install or postinstall scripts.
- 8 sources containing 22 prebuilt native payloads.
- 7 sources containing 14 WASM payloads.
- Only 7 source archives with directly visible native source files.

No lifecycle script was executed. Native payloads include platform packages for
OpenTUI, Parcel watcher, node-pty, msgpackr, tree-sitter, and fff-bun, plus
bundled fallback executables in `clipboardy` and compiled artifacts in
`bun-pty`. These require corresponding-source and rebuild decisions before the
closure is usable. The excluded embedded-web build path also removes the
FSL-licensed Sentry CLI from the selected source closure.

## Native And WASM Review

[`native-review.yml`](native-review.yml) classifies all 14 unique source
identities that contain the 22 native and 14 WASM payloads. It records exact npm
`gitHead` values, local Git tag objects and peeled commits, payload decisions,
and the remaining source-build gates. No published prebuilt payload is approved
for the RPM.

The selected runtime may omit the Node-only node-pty wrapper and msgpackr's
optional native acceleration. Clipboardy must use Fedora `xsel` instead of its
bundled executables, and tree-sitter-bash must omit all Node prebuilds while
rebuilding its functional WASM. OpenTUI and bun-pty require native source
builds. The Fedora patch binds FFF to OpenCode's existing no-FFF adapter, so the
required system ripgrep provides find, glob, and grep without `libfff_c.so`.
Parcel watcher cannot be disabled without losing Git branch-update events. The
draft recipe therefore rebuilds `watcher.node` from the authenticated main npm
package with Fedora Node 24 headers and replaces the published platform payload
before Bun compilation. Two local rebuilds were byte-identical and an inotify
smoke passed, but final Bun embedding and F43/F44 reproduction remain unproven.

All functional WASM remains fail-closed. Exact corresponding sources are now
mapped for OpenTUI's five grammars, Shiki's Oniguruma asset, and Undici's llhttp
assets, including immutable source archives and byte-level asset correspondence.
Their rebuilds remain unproven because upstream leaves the Tree-sitter release
workflow, Emscripten version, or Alpine build packages floating. Photon is the
only unresolved WASM source mapping: its authenticated npm 0.3.4 tarball differs
from both the registry `gitHead` and the nearest generated `compiled-wasm`
commit in WASM bytes, JavaScript, declarations, package identity, version, and
filenames. No exact generated package exists in the checked immutable refs, so
the prebuilt payload remains unusable. Tree-sitter Bash, PowerShell, and
web-tree-sitter also still need reproducible build evidence.

```bash
scripts/acquire-opencode-sources --plan
scripts/acquire-opencode-sources --jobs 4
scripts/acquire-opencode-sources --jobs 4 --check
```

The npm `opencode-ai` package and existing binary-oriented COPR/AUR/Homebrew recipes are intentionally not used. They select or install upstream platform executables instead of rebuilding from source.

The draft spec becomes eligible only after:

1. Bun 1.3.14 is source-built in Fedora without bootstrap binaries.
2. The exact npm source closure is acquired, checksummed, and license-audited.
3. Native modules and generated assets are rebuilt from source.
4. Manual `bundled(nodejs-...)` metadata is generated for code embedded in the standalone binary.
5. System-library decisions and required upstream contacts are recorded.
6. The build and checks pass without network access.

Technical dependency facts are tracked in [`dependencies.yml`](dependencies.yml).
