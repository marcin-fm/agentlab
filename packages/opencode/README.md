# OpenCode Packaging Status

OpenCode `1.18.5` is not enabled for COPR. The released GitHub tag is valid source, but the project builds with Bun and has a large CLI source closure that is not present in the release archive. Fedora's Node.js application guidance permits this private application closure to remain bundled; it does not require one RPM per ordinary npm dependency. The current selected-lock and source-acquisition audits cover `1.18.5`; final binary inclusion, generated bundled Provides, aggregate licensing, the remaining native and WASM rebuilds, and a complete offline build remain unverified.

The immutable `v1.18.5` tag resolves to commit
`e5cc278dec9294a627a7b05f47ce6a564408c1a2`, and its source archive has
SHA-256 `eb3daee12da937a36c3276efda2ce1253d3c8fbe2828ebd581a39a2c2d3efdab`.
The root lock contains 37 workspace records and 3,221 package records. Those
are lockfile-wide inventory counts, not the standalone Linux binary closure
and not valid `bundled(nodejs-...)` input.

## Selected Lock Audit

`scripts/audit-opencode-lock-closure` now performs a source-only traversal of
the released Bun lock for the Linux x86_64 glibc terminal CLI. The selected
feature surface uses upstream's `--skip-embed-web-ui` build flag, excluding the
app/Vite/Sentry path without patching product code. It selects 14 workspaces and
1,018 runtime package records, all from the npm registry, while 36 non-target
platform records are excluded.

The deterministic receipt is
[`opencode-1.18.5-selected-lock-audit.json`](opencode-1.18.5-selected-lock-audit.json),
SHA-256 `8ab964282c73a34d104ed625eb7bf94930cf28dac343117fd1bb95c4a9d3b2d1`.
It intentionally does not claim source archive verification, license review,
binary inclusion, or final bundled Provides. Regenerate or verify it with:

```bash
scripts/audit-opencode-lock-closure \
  --source-dir /srv/tmp/agentlab-opencode/source/opencode-1.18.5
scripts/audit-opencode-lock-closure \
  --source-dir /srv/tmp/agentlab-opencode/source/opencode-1.18.5 --check
```

The standalone build fetches `https://models.dev/api.json` unless
`MODELS_DEV_API_JSON` supplies a local file. OpenCode's release flake pins
nixpkgs commit `9dd5558b06dbdacbf635a3dd36dce1b1a7ee3a89`, whose Models.dev derivation
selects commit `1eb0b8c8e17ffddd89f53b2a3e426777dc560542`. The RPM rebuilds that snapshot
twice byte-identically from the exact source plus `zod 3.24.2` and injects the
1,731,900-byte SHA-256 `8b78d7b16423318fb59e61c22118638952b76fc892b315c002dc3854c8618287`
JSON through the supported override. Final standalone-binary inclusion remains
a separate build-time gate.

## Source Acquisition Audit

`scripts/acquire-opencode-sources` deduplicates the selected package paths to
828 unique npm registry sources. Every archive passed its released SHA-512
integrity check, every retained archive has a SHA-256 receipt, and archive
path/type validation passed. The resumable cache is under
`/srv/tmp/agentlab-opencode/source-acquisition-1.18.5`.

The deterministic receipt is
[`opencode-1.18.5-source-audit.json`](opencode-1.18.5-source-audit.json),
SHA-256 `619dbebafaeb817fa1a346ef26d7e85d95202d515b572d898c88715e01e11dbc`.
It records these unresolved gates:

- 3 raw source archives without declared license metadata; all three are
  resolved from authoritative upstream evidence in
  [`license-review.yml`](license-review.yml). Another 28 do not include
  package-local license files; their texts are conditional on final source or
  binary inclusion rather than automatic payload copies.
- 73 lifecycle-script sources, including 5 install or postinstall scripts.
- 8 sources containing 22 prebuilt native payloads.
- 7 sources containing 14 WASM payloads; the three selected Tree-sitter package identities now have source-build replacements for their required WASMs.
- Only 7 source archives with directly visible native source files.

No lifecycle script was executed. The lifecycle review now requires dependency
reconstruction by direct extraction of the reviewed registry archives and
forbids all dependency hooks. The 68 prepare hooks are publish/development
steps whose released outputs are already present, without waiving separate
generated-output review. Parcel's install hook is replaced by the explicit
watcher source build; msgpackr's optional native hook is omitted; protobufjs's
postinstall only emits a version-scheme warning; and the tree-sitter Bash and
PowerShell native hooks are skipped while their required WASMs are rebuilt explicitly.

Native payloads include platform packages for
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
The bun-pty npm wrapper byte-matches its release commit but omits Rust source.
The draft replaces only its prebuilt `rust-pty` directory with the exact Git
source, builds against a deterministic 43-crate Cargo vendor archive through
Fedora macros, and preserves the release path expected by Bun's static import.
Empty-cache vendored builds were byte-identical; public vendor hosting, final
Bun embedding, F43/F44 macro builds, and aggregate license closure remain open.

OpenTUI `0.4.5` retains the same Bun-pinned Zig 0.15.2 fork and exact uucode and
Yoga source pins used by the prior native recipe. Two network-isolated current
builds produced valid stripped libraries at SHA-256
`e24478d37ba1ed3aa3c93ce5265d3bbfc396297c6a1e838f4a42341562ae04e3` and
`02b53e7539b785366cd3f01d11f04eedcd9f866c224d8cfd39b759be7fe70a6a`.
Both expose the required FFI surface, load with `ctypes`, resolve only the
expected system libraries, and retain a `GLIBC_2.17` floor. Their differing
bytes are recorded honestly; final Bun embedding and clean Fedora 43/44 package
builds remain unverified.

Functional WASM remains fail-closed as a whole. Exact corresponding sources are now
mapped for OpenTUI's five grammars, Shiki's Oniguruma asset, and Undici's llhttp
assets, including immutable source archives and byte-level asset correspondence.
OpenTUI's five grammars now rebuild twice byte-identically with Fedora
tree-sitter CLI `0.26.9`, Clang 20, and the Bun Zig WASI headers; JavaScript,
TypeScript, Markdown, Markdown-inline, and Zig parse smokes pass through
web-tree-sitter `0.25.10`. Shiki's pinned vscode-oniguruma and Oniguruma sources
now rebuild twice byte-identically with the package's Emscripten `4.0.4`,
Binaryen `121`, and Clang 20 toolchain; the exact wrapper scan passes after the
published WASM is replaced. Undici remains unproven because its historical
Undici's scalar and SIMD llhttp modules also rebuild twice byte-identically from
the exact generated llhttp `8.1.0` C release with the same Emscripten/Binaryen
toolchain; both instantiate with the expected callbacks and allocator/parser
exports. Photon is the
only unresolved WASM source mapping: its authenticated npm 0.3.4 tarball differs
from both the registry `gitHead` and the nearest generated `compiled-wasm`
commit in WASM bytes, JavaScript, declarations, package identity, version, and
filenames. No exact generated package exists in the checked immutable refs, so
the prebuilt payload remains unusable.

Tree-sitter Bash, PowerShell, and web-tree-sitter now have a complete offline
replacement recipe. The spec removes the published WASMs and Bash Node
prebuilds before the application build, builds the runtime with Emscripten
`4.0.4`, Binaryen `121`, and esbuild `0.24.2` from pinned sources, and compiles
both grammar WASMs with Fedora `tree-sitter-cli` and the Bun-pinned Zig WASI
headers. The rebuilt runtime parsed representative Bash and PowerShell inputs
without errors. Repeated grammar builds were not byte-identical, so
reproducibility remains honestly false and non-blocking; clean F43/F44 package
builds and final Bun embedding are still unverified.

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
