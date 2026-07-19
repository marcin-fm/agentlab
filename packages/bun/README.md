# Bun Packaging Status

Bun `1.3.14` is a required OpenCode build dependency but is not enabled for COPR.

The pinned `oven-sh/zig` source is now proven to bootstrap on Fedora 44 from its in-tree stage-one WASM using Fedora LLVM, Clang, and LLD 20. The package compiles that subordinate source privately and materializes the `zig` plus `lib` root expected by Bun; it does not publish a misleading `zig-bun` package or consume an external Zig executable.

The draft now continues through proven local and isolated WebKit source builds. WebKit commit `5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b` has no gitlinks or active submodules; its four embedded `.gitmodules` files are ordinary vendored files. The complete deterministic `git archive | gzip -n` is retained as the provenance parent at SHA-256 `c48d419170205210dc40eb70c2c4bf91e5d50db91a2739d13030965c08d31d3c`. The disabled spec now consumes the immutable attested dual-architecture JSC-only source release: 95,923,474 bytes at SHA-256 `38253c470959d729a196a543d6fce9e8aacc378ffc492790ded2b69598d7213d`, with retained tree SHA-256 `dcf7d67f6bced499d961d20c29a1dc12cead88650c7d9f79a830082969e744d8`. It retains ARM Capstone, applies Arch Linux's checked JSC typed-array conversion fix for Bun issue 28607, and builds static JSC, WTF, and bmalloc with Fedora Clang/LLVM/LLD 21.1.8 using Bun's `JSCOnly` options. The checked x86_64 minimized-source build proof retains all 2,294 generated headers, `CMakeCache.txt`, and `compile_commands.json`, and its `jsc` runtime check passed. The receipt verifies Capstone and declares source scope for x86_64 and aarch64; an actual aarch64 build remains a separate acceptance gate. The remaining RPM source bundles, final license review, and RPM acceptance are still required. Clean-cache Zig byte differences remain diagnostic evidence but are not treated as a Fedora package blocker.

The Linux x86_64 `release-local` source audit parses Bun's 23 dependency definitions instead of maintaining a separate pin list. It excludes Windows-only libuv, acquires and safely inspects all 19 selected native GitHub archives plus Node.js `24.3.0` headers, verifies Node ABI 137, and records every selected Bun patch or overlay. Those 20 archives contain 20,205 files and total 108,330,283 bytes. The complete checked cache now holds 299 native, Node.js, npm, and Cargo archives totaling 142,382,337 bytes under marked `/srv/tmp/agentlab-bun/release-local-sources-1.3.14`. The canonical v2 receipt is `bun-1.3.14-release-local-source-closure.json`, 448,430 bytes with SHA-256 `ee3ed17e495779441326d10cd8d7f07a21b856285abc0f41ef9e5be6f99abbe0`.

The same receipt inventories all three frozen npm install roots: 310 lock package records reduce to 251 Linux x64 glibc references after excluding 57 target-incompatible records. Deduplication produces 236 archives: 235 npm registry tarballs verified against their lockfile SHA-512 integrities and the full `oven-sh/bun.report` commit verified by package identity and recorded SHA-256. They total 30,079,735 bytes and 3,854 files. The lol-html Cargo lock contains 45 packages, including 43 registry crates and no Git sources; all 43 crate archives pass their lockfile SHA-256 checks and package identities, totaling 3,972,319 bytes and 1,656 files.

Bun's release source pins `nightly-2025-12-10` and `rust-src` only because its Linux release branch rebuilds the standard library with `panic=immediate-abort` for roughly 180 KB of size reduction. `bun-lolhtml-fedora-stable-rust.patch` excludes native Linux from that optional branch and retains upstream's existing stable `panic=abort`, no-unwind-table, size-optimized path. Fedora Rust/Cargo `1.96.1` rebuilt `lol_html_c_api` from a deterministic 43-crate vendor tree with `--locked --offline` inside a network namespace. The 46,769,250-byte `liblolhtml.a` exports 97 checked C API symbols. `lolhtml-cargo-vendor.txt` records the exact closure; `lolhtml-offline-build-proof.json` has SHA-256 `05785f79c560ce5953500acc7c9dea283a53b18240e59b62c84f57ab02eb5cce`. Nightly Rust and `rust-src` are therefore not required for this native Linux dependency path. Local offline materialization is verified, but the vendor and other checked archives are not yet integrated as immutable RPM-consumable sources.

The 236 checked npm archives now also reconstruct Bun's exact cache version 1 outside RPM builds. Bun `1.3.14` does not parse lockfile libc selectors, so `bun-lightningcss-fedora-glibc-lock.patch` disables only the incompatible musl Lightning CSS prebuilt package with Bun's supported `os: none` value while preserving the GNU package. The checked bootstrap seed then completed all three serialized `--frozen-lockfile --ignore-scripts` installs under `unshare --net`: 230 root packages, Preact for `packages/bun-error`, and 121 `src/node-fallbacks` packages. The 121,972,064-byte materialized cache remained byte/content/mode identical, required esbuild, Lezer, workspace, bun.report, and React Refresh artifacts were present, and no seed path or binary entered the cache or node_modules trees. `npm-offline-install-proof.json` has SHA-256 `61779f38b08a0bdafd30c3684831f4c5c6586b1ee22c91e279b2f07e6687472f`. The npm source closure is still not an immutable RPM source.

The checked seed drove the first complete `release-local` build under `unshare --net`, with one `nice` four-job Ninja graph and matching nested CMake/Cargo caps. Two narrow Fedora corrections were required: `bun-zig-build-cwd.patch` runs out-of-tree Zig subprocesses from the source root, and `bun-fedora-shared-cxx-runtime.patch` links Fedora's shared `libstdc++` and `libgcc_s` instead of unavailable static runtime archives. The build produced a 336,047,704-byte `bun-profile`, a 67,721,320-byte debug-section-free `bun`, and a retained linker map. Revision, version, and JavaScript smokes passed; all 19 native sources, Node headers, stable lol-html Cargo, local WebKit, and three prevalidated npm roots plus their workspace-linked supplemental tree were consumed without network access. Resume mode revalidates those prepared inputs, and minimized-WebKit resumes now re-extract and recheck the receipt-bound source before reapplying the patch. Scans found no seed hash/path in source, cache, or build outputs, while `ldd` confirmed Fedora `libstdc++.so.6` and `libgcc_s.so.1` with no seed dependency. `first-source-build-proof.json` has SHA-256 `fda7910119f4c11a2b7b11f19dc1f04a2315d580c192e4a007d6e654f27804eb`. The deterministic 329,696,015-byte relink kit now contains the exact response file, wrapper-free link command, 1,162 objects, four archives, two linker scripts, and all 2,294 generated WebKit headers, and reproduces both retained output and linker map. It remains unhosted and is not yet an RPM source or final legal/RPM proof.

The source-built Bun then drove a separate fresh `release-local` build with networking unavailable and without extracting or consuming the bootstrap seed. The generated graph uses the source-built executable across the checked 16-rule driver scope, runtime smokes pass, the final ELF has no seed payload or runtime dependency, and cgroup OOM counters remain unchanged. The comparison deliberately does not report bootstrap output differences as success. Fresh source-built runs show that the aggregate of the 32 `bun-zig.*.o` outputs depends on Zig cache state: a serialized rebuild with retained caches reproduced aggregate `204feaefdfc2792e322b27a8137eeb4a3fef5812250c40ac62570835ab97b988`, while clearing only `build/release-local/cache/zig/local` and `cache/zig/global` changed it to `173d1e110081ce0802b51f656e5da2a13997b1f5bb08b28a8ae27894b6fd1d0b`. `self-rebuild-proof.json` has SHA-256 `9c5d742309e95516de508769b153d07c8ba5e7ba239861bd46fd85d1aeaa0da0`; `zig-reproducibility-proof.json` records the narrower diagnostic experiment. Bun remains blocked pending immutable source integration, complete LGPL relink materials, final license review, and the RPM.

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

Create the deterministic minimized dual-architecture WebKit/JSC source from the checked complete archive with:

```bash
scripts/package-bun-webkit-source --force
```

The helper writes the archive and identity receipt below `/srv/tmp`, rejects path aliases and symlinked-parent escapes, retains ARM Capstone, and verifies deterministic regeneration. Pass the resulting archive with `--source` and its receipt with `--source-receipt` to the WebKit proof, or with `--webkit-archive` and `--webkit-source-receipt` to the first-source-build proof. The source profile is architecture-neutral, but the checked build receipt remains a Fedora 44 x86_64 proof until an aarch64 build succeeds.

`.github/workflows/release-source.yml` recreated the complete archive from the pinned Git commit, regenerated the minimized source, checked it against package metadata and checked receipts, uploaded and re-downloaded every draft asset, attached GitHub provenance, then independently reverified the draft and published immutable release `bun-sources-1.3.14-webkit-5488984d20e0`. The package consumes the exact release asset URL and still verifies its SHA-256 in `%prep`.

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

Prove the first seed-driven source build with:

```bash
nice -n 10 rtk scripts/prove-bun-first-source-build --configure-only --jobs 4 --force
nice -n 10 rtk scripts/prove-bun-first-source-build --resume --jobs 4
```

The helper verifies every checked input, creates a marked disposable source/build tree, inspects the generated Ninja graph before compilation, and runs the full build with networking unavailable. It replaces only the generated Ninja `bun_install` command with validation of the three previously proven materialized npm trees. The canonical receipt records the source-built outputs, runtime smokes, retained link evidence, Fedora shared-runtime linkage, and first-build seed-absence scan. It does not perform the source-built self-rebuild, prove reproducibility or complete LGPL relink materials, integrate immutable RPM sources, install an RPM, or enable COPR.

The same helper accepts `--self-rebuild-from PATH` to use a checked source-built Bun as the build driver and `--driver-receipt PATH` when the driver is itself a self-rebuild proof. Self-rebuild mode creates no seed directory, requires the graph to omit every seed identity, performs a second generated-target stabilization pass, and records normalized artifact and graph comparisons. The current checked result proves the offline seed-free build but deliberately leaves the fixed-point flag false because clean-cache Zig objects are not reproducible.

Audit the retained first-build relink materials without rebuilding with:

```bash
nice -n 10 rtk scripts/audit-bun-relink-materials \
  --root /srv/tmp/agentlab-bun-first-source-build-proof \
  --date 2026-07-18 \
  --check \
  --receipt packages/bun/relink-materials-proof.json
```

The auditor reads the retained build only, rejects unsafe or missing link/header inputs, normalizes proof-root paths, and compares a deterministic receipt. It does not create a relink kit, replace the seed-driven link command, make a legal conclusion, install an RPM, or change any final acceptance flag.
