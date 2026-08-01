# Bun Packaging Status

Bun `1.3.14` is a required OpenCode build dependency but is not enabled for COPR.

Release `0.0.39` preserves the peechy supplemental MIT text and adds checked Fedora 44 aarch64 evidence for the first source build, two source-built npm handoffs, two seed-free self-rebuilds, and wrapper-free relink. The signed peechy npm archive declares MIT and names the same repository but omits a license file; its registry `gitHead` is unavailable and upstream issues are disabled, so exact release-source correspondence remains false. Six WebKit fork-file terms, final aggregate SPDX and RPM payload accounting, immutable relink delivery, aarch64 RPM integration and acceptance, FPC bootstrap approval, and COPR remain unresolved.

The pinned `oven-sh/zig` source is now proven to bootstrap on Fedora 44 from its in-tree stage-one WASM using Fedora LLVM, Clang, and LLD 20. The package compiles that subordinate source privately and materializes the `zig` plus `lib` root expected by Bun; it does not publish a misleading `zig-bun` package or consume an external Zig executable.

The draft now continues through proven local and isolated WebKit source builds. WebKit commit `5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b` has no gitlinks or active submodules; its four embedded `.gitmodules` files are ordinary vendored files. The disabled spec consumes the immutable attested dual-architecture JSC-only source release: 95,923,474 bytes at SHA-256 `38253c470959d729a196a543d6fce9e8aacc378ffc492790ded2b69598d7213d`, with retained tree SHA-256 `dcf7d67f6bced499d961d20c29a1dc12cead88650c7d9f79a830082969e744d8`. Release `0.0.21` switches Fedora glibc builds to the separately packaged `lol-html 3.0.0` shared C API, release `0.0.22` regenerates the active source/license graph, release `0.0.23` proves the current x86_64 source-built npm, seed-free self-rebuild, HTMLRewriter, and wrapper-free LGPL relink chain, release `0.0.24` regenerates the current SRPM and dependency-staging evidence, release `0.0.25` maps every direct final-link input, release `0.0.26` selects 15 native source subsets, release `0.0.27` selects the exact linked JPEG and WebP subsets, release `0.0.28` completes all 18 native source-subset selections, release `0.0.29` maps every linked WebKit archive member to its exact direct, generated, or unified constituent sources, release `0.0.30` binds all 5,098 WebKit-local transitive dependencies plus the exact six-file fork-license hold, release `0.0.31` maps the 38 npm package manifests declared by code-generation installs plus the 30 generated outputs consumed by direct final-link objects, release `0.0.32` binds the nine undeclared generated headers to their exact grouped upstream producers, and release `0.0.33` binds constants-browserify's complete package-local MIT notice to the exact registry release and upstream tag. FPC initial-bootstrap approval, immutable relink delivery and final RPM integration, explicit terms for six WebKit fork files, exact MIT text correspondence for peechy, aggregate SPDX and required-text review, aarch64 RPM integration and acceptance, and COPR acceptance remain required. Clean-cache Zig byte differences remain diagnostic evidence rather than a Fedora package blocker.

The Linux x86_64 glibc `release-local` source audit parses Bun's 23 dependency definitions from pristine `Source0` instead of maintaining a separate pin list. It excludes Windows-only libuv and the externally provided lol-html source, acquires and safely inspects 18 selected native GitHub archives plus Node.js `24.3.0` headers, verifies Node ABI 137, and records every selected Bun patch or overlay. Those direct dependency archives total 107,775,490 bytes. Together with 236 npm archives, the canonical v3 receipt covers 255 checked inputs and has SHA-256 `f3ba1c9145a46aaf76a79e6fb676982610024f5d9ee3b2d312500dc3bc8ca080`.

The same receipt inventories all three frozen npm install roots: 310 lock package records reduce to 251 Linux x64 glibc references after excluding 57 target-incompatible records. Deduplication produces 236 archives: 235 npm registry tarballs verified against their lockfile SHA-512 integrities and the full `oven-sh/bun.report` commit verified by package identity and recorded SHA-256. They total 30,079,735 bytes and 3,854 files. No private lol-html Cargo source is part of the active Bun closure; the provider package owns that source and linked-license accounting.

Bun's former private lol-html proof remains recorded by `lolhtml-offline-build-proof.json` and `lolhtml-rpm-cargo-proof.json`, including the 43-crate offline source closure and 97-symbol static C API. Those receipts describe the pre-`0.0.21` graph only. `bun-system-lolhtml.patch` now omits that dependency from Bun's glibc build graph, links `-llolhtml`, reports dependency version `3.0.0`, and updates the handwritten Zig `lol_html_memory_settings_t` layout. The new boolean field is initialized to `false`, preserving lol-html's traditional fail-fast memory-limit behavior, and the stale variadic declaration of `lol_html_take_last_error` is corrected to the fixed zero-argument C prototype. Non-glibc targets retain Bun's upstream bundled v2.7.2 path and version identity.

Source22 is a deterministic 239-archive union of the checked x64 and arm64 npm closures: 41,222,363 bytes at SHA-256 `c8f251509523fe27a648e496df9d5a7ee564c07a8afc5d67c712489df2fee7b4`. The configured-SCM-equivalent `0.0.39` source-delivery proof regenerates both 255-input closures byte-identically, records their 258-input union, and verifies the 329,438,552-byte, 41-member source RPM at SHA-256 `5ec122a3d497e0c73c7f02306d57d134dafd1d274d796fb88ea229e1cfa08326`. Two network-isolated `%prep` runs reproduce the existing 236-entry npm cache and the updated source-license inventory including Source32, preserving the 4,613-entry, 121,972,064-byte cache tree at SHA-256 `50e66a5b8361735b2598a6be5d7d78f973db05104cbdf9b9addb01e9a113d214`. `%prep` remains explicitly x64-only; Source31 is source-delivery evidence only and makes no arm64 `%prep`, build, payload, or COPR claim.

The repository-backed source builder creates `bun-1.3.14-0.0.36.fc44.src.rpm` as 318,185,293 bytes at SHA-256 `63b3ae1c42baf1a9fcd3f7e3dcaa21945f189d48213023fcd2570cc4dc5d58ce`. All 39 extracted members are byte-identical to the source-builder inputs, the retired private lol-html archive and Cargo vendor bundle are absent, and RPM digest verification passes.

The separate arm64 closure is SHA-256 `d62881f573199d9e98cf0a5599c12d8bb54cbea79d3b20fe841fe35f993b3f5a`: 233 source archives are common with x64 and exactly three platform packages change to arm64. Fedora 44 aarch64 Mock under `qemu-aarch64-static` runs the exact upstream `1.3.14` seed, private source-built Zig, minimized WebKit/JSC, and staged `lol-html 3.0.0`. The first build is followed by two source-built npm handoffs and two seed-free self-rebuilds; the final stripped Bun is 69,799,264 bytes at SHA-256 `ea292e417542dc3019015e80ac74ed072716e6b91dfae3372d8a3e8b6a28daea`. The 320,906,229-byte relink kit is SHA-256 `90d57e1277c5ba8eb29196ec923321040c9114e8790767122a35310b57a92c34`; its wrapper-free direct command reproduces profile SHA-256 `9185ea59ec930545420893dd91374299a22f79d31541f0dd45b1eaa4dcda542c` and linker-map SHA-256 `24fd5d09144afd3d4be4dfe299406b379c759add59aec46e16ccd7e90a3b88c8`, passes HTMLRewriter through `liblolhtml.so.1`, and rejects seed payload/runtime contamination. This proves the aarch64 source-build and relink chain, not immutable kit delivery, final license accounting, RPM integration, architecture enablement, or COPR acceptance.

`bun-1.3.14-source-license-inventory.json` records the provisional source-license boundary without claiming the final linked payload. The 236 npm sources declare 11 expression values; recursive discovery plus the separately checked peechy Source32 supplies texts for 223 entries, while 13 still have no such text, and the two missing modern `license` fields both retain supplied MIT evidence. The peechy npm archive remains textless and exact release-source correspondence remains false. The exact constants-browserify `1.0.0` README is counted because it contains the complete MIT notice and is bound to registry `gitHead` plus tag commit `e0ee990c75f3a0b3275e6bb2e3ff4d5d169d1b9d`; the later standalone `LICENSE.md` is retained only as normalized-text equivalence evidence. Picohttpparser explicitly selects the complete embedded MIT terms instead of its Perl alternative. The inventory hashes the license candidates for all 18 active native sources and 35 retained WebKit files, excludes a current Cargo payload, and preserves exact pre-split proof hashes under an explicit historical namespace. The separately packaged `lol-html` record owns current provider licensing. The standalone generator is carried as Source26 and reruns in network-isolated `%prep` against the actual staged tree. Final Fedora SPDX review, linked-component selection, package-wide required `%license` texts, aggregate `License:`, bundled Provides, and RPM payload validation remain false.

`bun-1.3.14-final-linked-license-closure.json` binds the final self-rebuild, relink audit, relink kit, current source-license inventory, and reviewed lol-html package metadata. It assigns all 1,162 direct objects to Bun or the 18 checked native source identities, records the ten system link flags, and rejects unknown inputs. All 18 native source-subset selections are verified, including libarchive's exact `BSD-2-Clause AND BSD-3-Clause AND CC0-1.0` linked expression. The Bun-authored JPEG stub remains under Bun's MIT component, 62 upstream JPEG objects select `IJG AND BSD-3-Clause`, and 123 WebP objects select `BSD-3-Clause WITH Google-Patent-WebM`. The receipt cross-checks the three exact WebKit archives against `build.ninja`, `compile_commands.json`, unified-source includes, and Ninja's retained dependency database: 531 archive objects resolve to 5,098 unique WebKit-local dependencies, including 4,196 source and 902 generated paths. Three headerless subordinate/generated records are resolved under exact MIT evidence; six Bun-authored fork additions remain without explicit terms and retain their introducing commits as an upstream clarification hold. WebKit semantic selection, npm/codegen final-payload provenance, required texts, aggregate SPDX, and RPM payload verification remain explicitly unresolved; the shared lol-html provider is excluded from Bun's bundled aggregate.

`bun-1.3.14-npm-code-generation-closure.json` maps the current code-generation install boundary to 38 exact package manifests and maps Ninja's retained dependencies from all 1,162 direct link objects to 30 generated outputs consumed by 37 objects. Thirty-seven selected packages carry package-local license texts. `constants-browserify 1.0.0` supplies its complete MIT notice in the exact release README; `peechy 0.4.34` uses the separately checked Source32 canonical MIT text while its unavailable registry `gitHead` keeps exact release-source correspondence false. Nine generated headers are consumed by the final link without distinct Ninja producer edges; the v2 receipt binds them to the exact upstream orchestrator, grouped bindgen or bindgenv2 edge, generator, helper, semantic definition files, and retained output bytes. Producer provenance is verified, but distinct Ninja output edges, a clean generator re-execution, and the final npm/codegen closure remain false rather than inferred.

The current first build runs the complete Linux x86_64 glibc graph under `unshare --net` with one `nice` four-job Ninja process and matching nested caps. It produces a 332,727,688-byte `bun-profile` and a 66,969,072-byte stripped `bun`, resolves Fedora's staged `liblolhtml.so.1`, and passes JavaScript plus exact HTMLRewriter transformation smokes. `first-source-build-proof.json` is SHA-256 `adfb08798c9e49d862648b27d69839704de5f71a303a1599e71a53f2ef2bf8a8`; the seed is absent from the output and runtime graph.

The first source-built Bun and its first self-rebuild each regenerate all 236 cache entries and the three frozen no-script npm installs without acquiring or executing the bootstrap seed. Two consecutive source-built self-rebuilds retain identical normalized Ninja/configure graphs and pass the version, JavaScript, HTMLRewriter, seed-absence, and system-lol-html checks. Their binaries remain non-identical, consistent with the retained clean-cache Zig nondeterminism evidence; `source_rebuild_fixed_point_verified` remains false. The final `self-rebuild-proof.json` is SHA-256 `d028cff814121da1c585b74851976b4eaa9c1d46e17591c3eb7185421f15712c`.

The current relink audit records 1,162 direct objects, three WebKit archives, two linker scripts, and all 2,294 generated WebKit headers. The 317,961,444-byte path-preserving kit is SHA-256 `92b324d836f0be42e4a4c403cb351259cbf3006de9e6c9855ab550acf46aac95`. Its wrapper-free direct command reproduces the retained 332,874,240-byte `bun-profile` and 68,508,199-byte linker map exactly under network isolation, resolves Fedora shared C++ runtimes plus `liblolhtml.so.1`, and passes the HTMLRewriter smoke. Immutable delivery, final RPM inclusion, and legal payload review remain open.

Run the reusable Zig proof outside RPM builds with:

```bash
scripts/prove-bun-zig-bootstrap
```

The proof writes only below `/srv/tmp`, does not install its output, and verifies the Bun-compatible tool layout. It is a source-bootstrap-stage proof, not an offline Bun build, seed-isolation proof, complete RPM build, or Fedora approval. A machine-readable receipt records the checked source, patch, toolchain, and output digest.

For a Fedora aarch64 Mock running through QEMU linux-user, pass `--proof-platform fedora-44-aarch64 --qemu-stack-size 67108864`. The helper propagates and records QEMU's guest-stack size; a host shell `ulimit` does not replace this setting.

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

scripts/acquire-bun-release-local-sources \
  --source-dir /srv/tmp/oven-sh-bun-bun-v1.3.14 \
  --target-cpu arm64 \
  --jobs 4
```

The helper downloads only outside RPM builds, writes only to its marked `/srv/tmp` cache and the target-specific package receipt, rejects unsafe archive paths and links, verifies npm lockfile digests and package identities, and caps concurrent downloads at four. The default remains x64; `--target-cpu arm64` selects the separate checked arm64 closure. It does not run Bun, npm, or a build, prove offline installer behavior, or claim that the cached archives are suitable for final COPR SCM use.

Reproduce the historical private lol-html proof with:

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
