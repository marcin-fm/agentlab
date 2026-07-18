# Bun Packaging Status

Bun `1.3.14` is a required OpenCode build dependency but is not enabled for COPR.

The pinned `oven-sh/zig` source is now proven to bootstrap on Fedora 44 from its in-tree stage-one WASM using Fedora LLVM, Clang, and LLD 20. The package compiles that subordinate source privately and materializes the `zig` plus `lib` root expected by Bun; it does not publish a misleading `zig-bun` package or consume an external Zig executable.

The draft now continues through proven local and isolated WebKit source builds. WebKit commit `5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b` has no gitlinks or active submodules; its four embedded `.gitmodules` files are ordinary vendored files. A deterministic `git archive | gzip -n` therefore contains the complete tree and has SHA-256 `c48d419170205210dc40eb70c2c4bf91e5d50db91a2739d13030965c08d31d3c`. The spec verifies and extracts that source, applies Arch Linux's checked JSC typed-array conversion fix for Bun issue 28607, and builds static JSC, WTF, and bmalloc with Fedora Clang/LLVM/LLD 21.1.8 using Bun's `JSCOnly` options. The host proof retained generated headers, `CMakeCache.txt`, and `compile_commands.json`, and its `jsc` runtime check passed. The same Zig and WebKit stages then passed in a clean Fedora 44 x86_64 Mock buildroot with rpmbuild networking disabled and four jobs; `%install` staged no payload, and `%check` passed the Zig source and `jsc` runtime probes before the deliberate fail-closed stop. GitHub codeload still returns HTTP 422, and the 1.98 GB generated archive needs immutable public hosting before COPR use. Complete LGPL relink materials for the final Bun executable also remain unresolved. The exact Bun `1.3.14` x86_64 seed archive is checked and recorded as bootstrap-only. It has driven only the network-isolated frozen npm install proof, not the first Bun source build. Selected native, Node.js header, npm, and Cargo crate archives are locally checked, while immutable hosting, complete build-graph integration, and an immediate self-rebuild whose final RPM contains no seed artifact or runtime dependency are still required.

The Linux x86_64 `release-local` source audit parses Bun's 23 dependency definitions instead of maintaining a separate pin list. It excludes Windows-only libuv, acquires and safely inspects all 19 selected native GitHub archives plus Node.js `24.3.0` headers, verifies Node ABI 137, and records every selected Bun patch or overlay. Those 20 archives contain 20,205 files and total 108,330,283 bytes. The complete checked cache now holds 299 native, Node.js, npm, and Cargo archives totaling 142,382,337 bytes under marked `/srv/tmp/agentlab-bun/release-local-sources-1.3.14`. The canonical v2 receipt is `bun-1.3.14-release-local-source-closure.json`, 448,430 bytes with SHA-256 `ee3ed17e495779441326d10cd8d7f07a21b856285abc0f41ef9e5be6f99abbe0`.

The same receipt inventories all three frozen npm install roots: 310 lock package records reduce to 251 Linux x64 glibc references after excluding 57 target-incompatible records. Deduplication produces 236 archives: 235 npm registry tarballs verified against their lockfile SHA-512 integrities and the full `oven-sh/bun.report` commit verified by package identity and recorded SHA-256. They total 30,079,735 bytes and 3,854 files. The lol-html Cargo lock contains 45 packages, including 43 registry crates and no Git sources; all 43 crate archives pass their lockfile SHA-256 checks and package identities, totaling 3,972,319 bytes and 1,656 files.

Bun's release source pins `nightly-2025-12-10` and `rust-src` only because its Linux release branch rebuilds the standard library with `panic=immediate-abort` for roughly 180 KB of size reduction. `bun-lolhtml-fedora-stable-rust.patch` excludes native Linux from that optional branch and retains upstream's existing stable `panic=abort`, no-unwind-table, size-optimized path. Fedora Rust/Cargo `1.96.1` rebuilt `lol_html_c_api` from a deterministic 43-crate vendor tree with `--locked --offline` inside a network namespace. The 46,769,250-byte `liblolhtml.a` exports 97 checked C API symbols. `lolhtml-cargo-vendor.txt` records the exact closure; `lolhtml-offline-build-proof.json` has SHA-256 `05785f79c560ce5953500acc7c9dea283a53b18240e59b62c84f57ab02eb5cce`. Nightly Rust and `rust-src` are therefore not required for this native Linux dependency path, but the vendor archive is not yet an immutable RPM source and complete Bun/npm/native offline materialization remains blocked.

The 236 checked npm archives now also reconstruct Bun's exact cache version 1 outside RPM builds. Bun `1.3.14` does not parse lockfile libc selectors, so `bun-lightningcss-fedora-glibc-lock.patch` disables only the incompatible musl Lightning CSS prebuilt package with Bun's supported `os: none` value while preserving the GNU package. The checked bootstrap seed then completed all three serialized `--frozen-lockfile --ignore-scripts` installs under `unshare --net`: 230 root packages, Preact for `packages/bun-error`, and 121 `src/node-fallbacks` packages. The 121,972,064-byte materialized cache remained byte/content/mode identical, required esbuild, Lezer, workspace, bun.report, and React Refresh artifacts were present, and no seed path or binary entered the cache or node_modules trees. `npm-offline-install-proof.json` has SHA-256 `61779f38b08a0bdafd30c3684831f4c5c6586b1ee22c91e279b2f07e6687472f`. This proves cache materialization and frozen installs only; the npm source closure is not yet an immutable RPM source and no Bun source build has started.

Run the reusable Zig proof outside RPM builds with:

```bash
scripts/prove-bun-zig-bootstrap
```

The proof writes only below `/srv/tmp`, does not install its output, and verifies the Bun-compatible tool layout. It is a source-bootstrap-stage proof, not an offline Bun build, seed-isolation proof, complete RPM build, or Fedora approval. A machine-readable receipt records the checked source, patch, toolchain, and output digest.

Run the reusable WebKit proof outside RPM builds with:

```bash
scripts/prove-bun-webkit-source-build
```

The proof uses at most four jobs and writes its source, build tree, static archives, generated headers, build metadata, `jsc`, and receipt below `/srv/tmp/agentlab-bun-webkit-proof`. Use `--resume` only for that marked directory after satisfying a missing build dependency. The checked receipt is a Fedora 44 x86_64 host proof, not an isolated buildroot result or proof that the complete final Bun LGPL relink set exists.

Run the isolated Fedora 44 Mock proof with:

```bash
nice -n 10 rtk scripts/prove-bun-webkit-mock-build --jobs 4 --force
```

The helper builds an exact SRPM from checked local inputs, rebuilds it with the required Agentlab COPR dependency repository and rpmbuild networking disabled, and installs no produced RPM. The draft intentionally fails in `%check`; the helper accepts that nonzero Mock result only after the no-payload `%install`, Zig source execution, static WebKit artifact checks, and `jsc` runtime probe all pass. Its checked receipt is `webkit-mock-build-proof.json`.

Acquire or verify the selected `release-local` dependency sources with:

```bash
scripts/acquire-bun-release-local-sources \
  --source-dir /srv/tmp/oven-sh-bun-bun-v1.3.14 \
  --jobs 4

scripts/acquire-bun-release-local-sources \
  --source-dir /srv/tmp/oven-sh-bun-bun-v1.3.14 \
  --jobs 4 \
  --check
```

The helper downloads only outside RPM builds, writes only to its marked `/srv/tmp` cache and the canonical package receipt, rejects unsafe archive paths and links, verifies npm/Cargo lockfile digests and package identities, and caps concurrent downloads at four. It does not run Bun, Cargo, npm, or a build, prove offline installer behavior, or claim that the cached archives are suitable for final COPR SCM use.

Prove the Fedora-stable offline lol-html build with:

```bash
nice -n 10 rtk scripts/prove-bun-lolhtml-offline-build --jobs 4 --force
nice -n 10 rtk scripts/prove-bun-lolhtml-offline-build --jobs 4 --check
```

The helper reconstructs the checked Cargo vendor tree and manifest, creates a deterministic vendor archive, and runs only the pinned `lol_html_c_api` build with Fedora stable Rust while networking is unavailable. It does not run Bun or npm, start the bootstrap seed, integrate the archive into the RPM graph, perform the final crate-license review, or prove complete Bun offline materialization.

Prove the three frozen npm installs with:

```bash
nice -n 10 rtk scripts/prove-bun-npm-offline-install --force
nice -n 10 rtk scripts/prove-bun-npm-offline-install --check
```

The helper reconstructs all 236 checked Bun cache entries, applies the Fedora glibc lock correction to a disposable exact Source0 tree, and runs the checked bootstrap seed only for the three serialized installs while networking is unavailable. It executes no lifecycle scripts, performs no dependency resolution or full Bun build, verifies the seed is absent from the cache and installed trees, and compares a canonical receipt on the no-download `--check` run.
