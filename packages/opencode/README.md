# OpenCode Packaging Status

OpenCode `1.18.5` is not enabled for COPR. The released GitHub tag is valid source, but the project builds with Bun and has a large CLI source closure that is not present in the release archive. Fedora's Node.js application guidance permits this private application closure to remain bundled; it does not require one RPM per ordinary npm dependency. The current selected-lock and source-acquisition audits cover `1.18.5`; a local network-isolated Fedora 44 x86_64 build, exact compiler-input map, generated bundled Provides, complete functional-WASM source mappings, and a fail-closed final-license preflight now pass. Final aggregate licensing, clean Mock/COPR results, and target-matrix verification remain unverified.

The 829 integrity-checked registry archives now reproduce deterministic production/build and test-capable raw-source bundles. Both contain the same members because the selected set has 1,018 runtime packages, one build-only Prettier package, and no test-only packages. Configured-SCM preparation regenerates those bundles plus the exact bun-pty, Photon, and wasm-bindgen CLI Cargo vendor archives. Offline dependency-tree assembly and the local application build are verified.

The first complete repository-backed source job produces `opencode-1.18.5-0.9.fc44.src.rpm`, SHA-256 `476f5a0c12578694dc88bb3c3fc0a1bcce0410cb49a0910aca9522f8cf505992`, with all 38 declared source members and valid RPM digests. This proves source delivery only; no OpenCode binary was built or installed.

The exact source audit and closure now also drive direct dependency-tree assembly. All 829 checked archives materialize to 1,019 lock paths with target path-set SHA-256 `f6f13913497b2845a9eb23c0c21af014cc50c3ae868f5c9766e208896a9af602`; every extracted `package.json` matches the selected name/version. The 14 selected source workspaces are identity-checked and linked at deterministic root paths with link-set SHA-256 `be5f3c1b7dd0208eebee69a97ddd9ed330c74c5affc45e88e56fcd2edff6a2b8`. No package manager, dependency resolution, lifecycle hook, or network access runs.

The resulting `opencode-1.18.5-0.10.fc44.src.rpm` has 39 members at SHA-256 `091eaf8919b915ddfeb381d154a2c503b5b8f313020db24b7c42ff2764c5985f`, passes RPM digest checks, and completes `%prep` under network isolation. This is source-preparation evidence only; no OpenCode binary was built or installed.

Release `1.18.5-0.11` completes a local Fedora 44 x86_64 network-isolated `rpmbuild -bb`. The 39-member source RPM has SHA-256 `02b633badb43ba814133c9a5549e6625ed148621f8064df8dc37336bcfe2d96d`; the binary RPM has SHA-256 `d3b3b107e4e22450ffd527848c6704f512e656ea6e3bd55ca138b7b0e9991bc9`. Its preserved 127,035,136-byte standalone payload has SHA-256 `3b7b6622b2dc84d2579792569c3ebc8df12da062fdeafbf14d8a00f7a9dcd5b1` and reports `1.18.5` after extraction. All `%check` native/WASM/runtime smokes pass, RPM digests pass, and `rpmlint` reports zero errors with 14 expected generated-source, configure, standalone-strip, PIE, and missing-man-page warnings. No RPM was installed or submitted to COPR; clean Mock builds, final binary/license mapping, bundled Provides, and the target matrix remain open.

Release `1.18.5-0.12` adds an environment-gated Bun metafile patch and a fail-closed binary-embedding audit. The normalized compiler graph has 4,038 inputs, including 3,895 positive-contribution inputs that map completely to 531 materialized package paths, 491 public npm name/version identities, and 12 OpenCode workspaces. The resulting 617,625-byte receipt has SHA-256 `875a50872ca1bdc6ea139767f12a6006aa31f96b33b3259c57d01e4aabf37f70`; the spec generates exactly 491 versioned `bundled(nodejs-...)` capabilities from it, normalizes npm prereleases for RPM, and does not provide `npm(opencode)`. Raw metafile output hashes are intentionally excluded from the canonical receipt because Bun's standalone output records contain build-root-sensitive path data; the normalized input path sets reproduce byte-identically across distinct build roots.

The final `0.12` 43-member source RPM has SHA-256 `8310a97cf2f1cec3a84f7f4da5d6320bbe608e8d2b82b3c28bdedbdf52f72fc2`; the binary RPM has SHA-256 `4e12d67ee3057df0ee014b4321cfbea17ee561a3e9359b815044c7ffae5f1c43`. Its extracted 127,035,136-byte payload has SHA-256 `159ba070b44d55f730dd97c7b716677820e9b9cb3136e01b2e2e6c3e841c6f38` and reports `1.18.5` under network isolation. RPM digests pass, the packaged receipt is byte-identical to the tracked source, and `rpmlint` reports zero errors with the same 14 expected warnings. No RPM was installed or submitted to COPR. The compiler map narrows the source-set license-text review from 28 gaps to 13 embedded npm identities, but it does not close Photon source correspondence, the final Bun/native/WASM license map, aggregate SPDX, `%license` payload, or clean target builds.

Release `1.18.5-0.13` resolves ten of those embedded text gaps from exact upstream provenance. The three AWS packages share the license at release commit `4b035429227c5be4093e5b3898a4eb5dc70824b0`; Drizzle's npm SLSA attestation binds its exact release commit; Sigstore Verify and Remeda use exact `gitHead` texts; Poe's upstream clarification covers both selected packages; the SPDX exception attribution is installed; and CC0 requires no additional full-text payload. The regenerated 622,252-byte binary receipt has SHA-256 `63e40ebebba95d0e790b08808905a5acb73ff3e50563fdd1064716d2763674ec` and leaves only `@npmcli/agent@4.0.2`, `abstract-logging@2.0.1`, and `opentui-spinner@0.0.7` unresolved. Upstream issue creation for all three failed before mutation because the current GitHub token cannot create issues, so no notice was manufactured.

The final `0.13` 49-member source RPM has SHA-256 `b8fcc1a9e27dd3257c59554051d2955d28bf34451df36b42ec20175bb7c75355`; the binary RPM has SHA-256 `352bbe6d64c3c15de9ef67a26e0919cd390df140adb809033aca38e7324bb58c`. Its extracted 127,035,136-byte payload has SHA-256 `e2a6a3f12eb7a8c81e7e5b4dde01c6774438621d91a9c021a90b994cea9443db` and reports `1.18.5` under network isolation. The RPM installs all six resolved license/attribution payload files, preserves exactly 491 bundled Node capabilities with no `npm(opencode)`, passes digest checks, and has zero `rpmlint` errors with 14 expected warnings. No RPM was installed or submitted to COPR.

Release `1.18.5-0.14` replaces Photon's last opaque WASM. The npm `0.3.4` artifact and crates.io `photon-rs 0.3.3` source both bind commit `685f5b155b36c5611c08ca678bb78ddbab3edbac`; the crate supplies the exact Cargo lock omitted from Git. Historical reconstruction reproduces the published readable JavaScript and declarations byte-for-byte. Two path-distinct, network-isolated Fedora Rust `1.97.1` builds use a targeted source-path remap and source-built `wasm-bindgen-cli 0.2.95`; they produce the same 2,541,956-byte raw WASM at SHA-256 `d4fd63da1fbfdb7d88f0800547efaba1a01173b59df080fc6b0383074da7418d` and the same 1,861,027-byte Node payload at SHA-256 `be53f0a699e3e5d9fd59b7108dc888fe95e4b85839c2e91c3af3a199e5a0e783`. The published glue loads that replacement and produces byte-identical PNG and JPEG results through OpenCode's constructor, decode, Lanczos resize, and encode operations.

The final `0.14` 55-member source RPM has SHA-256 `fe1e85046718ed02d52cc901361781591cf675d64a7b11657b880de49d7f689f`; the binary RPM has SHA-256 `42b9961f164eeda11aa6928ec3e56e65eff41721ae40962793de26c8d6869423`. Its extracted 126,748,416-byte payload has SHA-256 `df7d2f0f551cb64e36a0b9bc4f76d22bc49cec5d47cb64e4515dd68c9491ea39` and reports `1.18.5` under network isolation. RPM digests pass, the installed Photon source license is SHA-256 `c984c291167af70cc5fb7c7f4cec9b4560565110b766a718b3e12aba650327a7`, and `rpmlint` reports zero errors with 20 expected warnings. No RPM was installed or submitted to COPR.

Release `1.18.5-0.18` refreshes `opencode-1.18.5-final-license-closure.json`, the compact deterministic preflight over the exact binary-embedding, source-license, npm notice, native/WASM, and Bun `1.3.14` final-link receipts. It verifies the 491 embedded npm identities, ten resolved OpenCode text cases, all 14 native/WASM source mappings, Bun's 1,165 mapped direct link inputs, and all 18 Bun native license selections. Bun `0.0.34` additionally records the verified arm64 source closure and network-isolated npm bootstrap proof while preserving the complete constants-browserify notice and the sole `peechy 0.4.34` npm text hold. Cargo `1.97.1` checksum comments remain normalized so configured-SCM reproduces the established bun-pty vendor archive. The resulting 57-member source RPM is 428,762,501 bytes at SHA-256 `1ec37fcf8d8f946d0d572712a38c2f9865bd6f3a2d02487b6b67c08dd38ead09` with all members byte-identical and valid header/payload digests. The preflight deliberately emits no final aggregate expression: the three OpenCode notice holds, six Bun WebKit fork files, sole Bun npm text gap, required-text payload, clean target matrix, and COPR gates remain explicit and false. No binary RPM was built or installed, and no COPR build was submitted.

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
app/Vite/Sentry path without patching product code. It selects 14 workspaces,
1,018 runtime package records, and the build-only Prettier `3.6.2` record, all
from the npm registry, while 36 non-target platform records are excluded.

The deterministic receipt is
[`opencode-1.18.5-selected-lock-audit.json`](opencode-1.18.5-selected-lock-audit.json),
SHA-256 `e89d4cee8dd4cd5145589679c2a0053352c53f44d5b8a72fdc26807e01e059f8`.
It intentionally does not claim source archive verification, license review,
binary inclusion, or final bundled Provides by itself. Those later claims are
bound separately by `opencode-1.18.5-binary-embedding.json`. Regenerate or verify it with:

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
JSON through the supported override. The `0.12` compiler map verifies that exact
snapshot as a supplemental standalone input.

## Source Acquisition Audit

`scripts/acquire-opencode-sources` deduplicates the selected package paths to
829 unique npm registry sources. Every archive passed its released SHA-512
integrity check, every retained archive has a SHA-256 receipt, and archive
path/type validation passed. The resumable cache is under
`/srv/tmp/agentlab-opencode/source-acquisition-1.18.5`.

The deterministic receipt is
[`opencode-1.18.5-source-audit.json`](opencode-1.18.5-source-audit.json),
SHA-256 `59f91dcb3be45a1b3b95a1428dd7a9ef656548e0acacd4e74b7e4ccd65b734f5`.
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

[`source-license-set-proof.json`](source-license-set-proof.json) classifies all
829 selected source archives. Every declaration resolves to a Fedora
allowed-software or allowed-content identifier, but this is not the final
binary expression: the compiler map narrows 28 package-local text gaps to 13
embedded identities. Release `0.13` resolves and installs applicable evidence
for ten of them, leaving three exact upstream notice holds and aggregate payload
accounting open. Photon correspondence is closed by release `0.14`.

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
before Bun compilation. Two local rebuilds were byte-identical, an inotify
smoke passed, and the exact compiler map includes the rebuilt addon; F43/F44
reproduction and aggregate licensing remain unproven.
The bun-pty npm wrapper byte-matches its release commit but omits Rust source.
The draft replaces only its prebuilt `rust-pty` directory with the exact Git
source, builds against a deterministic 43-crate Cargo vendor archive through
Fedora macros, and preserves the release path expected by Bun's static import.
Empty-cache vendored builds were byte-identical, configured-SCM regenerates the
vendor archive, and the exact compiler map includes the rebuilt library. F43/F44
macro builds and aggregate license closure remain open.

OpenTUI `0.4.5` retains the same Bun-pinned Zig 0.15.2 fork and exact uucode and
Yoga source pins used by the prior native recipe. Two network-isolated current
builds produced valid stripped libraries at SHA-256
`e24478d37ba1ed3aa3c93ce5265d3bbfc396297c6a1e838f4a42341562ae04e3` and
`02b53e7539b785366cd3f01d11f04eedcd9f866c224d8cfd39b759be7fe70a6a`.
Both expose the required FFI surface, load with `ctypes`, resolve only the
expected system libraries, and retain a `GLIBC_2.17` floor. Their differing
bytes are recorded honestly; exact local compiler-input inclusion now passes,
while clean Fedora 43/44 package builds and aggregate licensing remain unverified.

Functional WASM now has complete source mapping. Exact corresponding sources are
mapped for OpenTUI's five grammars, Shiki's Oniguruma asset, Undici's llhttp
assets, and Photon, including immutable source archives and source-build evidence.
OpenTUI's five grammars now rebuild twice byte-identically with Fedora
tree-sitter CLI `0.26.9`, Clang 20, and the Bun Zig WASI headers; JavaScript,
TypeScript, Markdown, Markdown-inline, and Zig parse smokes pass through
web-tree-sitter `0.25.10`. Shiki's pinned vscode-oniguruma and Oniguruma sources
now rebuild twice byte-identically with the package's Emscripten `4.0.4`,
Binaryen `121`, and Clang 20 toolchain; the exact wrapper scan passes after the
published WASM is replaced. Undici's scalar and SIMD llhttp modules also rebuild
twice byte-identically from
the exact generated llhttp `8.1.0` C release with the same Emscripten/Binaryen
toolchain; both instantiate with the expected callbacks and allocator/parser
exports. Photon's npm `0.3.4` payload remains byte-different from the historical
Git branch artifacts, but the crates.io `0.3.3` source was published from npm's
exact `gitHead` and includes the matching lock. The draft builds that source and
wasm-bindgen CLI from vendored Cargo inputs, discards the published WASM, retains
the source-proven readable glue, and verifies the replacement through the image
operations selected by OpenCode.

Tree-sitter Bash, PowerShell, and web-tree-sitter now have a complete offline
replacement recipe. The spec removes the published WASMs and Bash Node
prebuilds before the application build, builds the runtime with Emscripten
`4.0.4`, Binaryen `121`, and esbuild `0.24.2` from pinned sources, and compiles
both grammar WASMs with Fedora `tree-sitter-cli` and the Bun-pinned Zig WASI
headers. The rebuilt runtime parsed representative Bash and PowerShell inputs
without errors. Repeated grammar builds were not byte-identical, so
reproducibility remains honestly false and non-blocking; clean F43/F44 package
builds remain unverified, while exact local compiler-input inclusion passes.

```bash
scripts/acquire-opencode-sources --plan
scripts/acquire-opencode-sources --jobs 4
scripts/acquire-opencode-sources --jobs 4 --check
```

The npm `opencode-ai` package and existing binary-oriented COPR/AUR/Homebrew recipes are intentionally not used. They select or install upstream platform executables instead of rebuilding from source.

The draft remains blocked until the source-built Bun package is available to a
clean buildroot, the 3 remaining npm notice holds and complete Bun runtime and
native/WASM payload accounting produce a final aggregate SPDX
expression and `%license` payload, the blocked upstream requests can be sent, and
the configured Fedora 43, Fedora 44, and Rawhide matrix passes.

Technical dependency facts are tracked in [`dependencies.yml`](dependencies.yml).
