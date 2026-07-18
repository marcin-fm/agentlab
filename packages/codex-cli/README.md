# Codex CLI Packaging Status

Codex CLI `0.144.5` is a blocked Fedora source-package draft. The selected
published release is tag `rust-v0.144.5` at commit
`87db9bc18ba5bc82c1cb4e4381b44f693ee35623`. Its immutable commit archive has
SHA-256
`b3472ef0b53e9b6191e19f51f491f818749671b9cb1b8dbe51466dc2702abcd9`.

Fedora and RPM Fusion 43/44 provide neither an exact Codex CLI package nor a
`/usr/bin/codex` provider. The globally installed `@openai/codex` npm package
is not used: it selects platform-specific prebuilt binaries instead of
building the Rust application from source.

## Source-Only Probe

The Fedora 44 probe verified and extracted the release archive, ran
`%cargo_prep`, and generated a dynamic BuildRequires RPM without compiling
Codex. The result is
`codex-cli-0.144.5-0.1.fc44.buildreqs.nosrc.rpm`, SHA-256
`3e17eb2bb95d0b85bc2b57158a1ca926b940b1e46e3f15dcadde4532d621e42f`.

That artifact is not the production Linux closure. Fedora's `cargo2rpm 0.3.3`
recognizes `codex-rs/cli/Cargo.toml` as part of the parent workspace, unions all
128 workspace members, and does not filter dependency target expressions. Its
400 requirements include 53 Windows-related capabilities, test helpers, and
the separate WebRTC Git source.

## Selected Linux Closure

`scripts/audit-codex-cargo-closure` now records the package-scoped Cargo graph
for `codex-cli`, target `x86_64-unknown-linux-gnu`, with normal and build edges
and no development edges. The deterministic receipt is
`codex-cli-0.144.5-selected-cargo-closure.json`, SHA-256
`a2f284d34455370a6bf846c5308369a188f86cab4c25e684e490eba62bb2834c`.
An offline byte-for-byte `--check` passed with Cargo 1.96.1.

The graph contains 1,004 packages: 984 on normal paths, 20 build-only, 119
workspace/path packages, 879 registry packages, and six packages from five Git
repositories. The selected Git repositories are the pinned crossterm, ratatui,
tokio-tungstenite, tungstenite, and nucleo forks. `rules_rust` is development
only, and rust-sdks/libwebrtc belongs to the non-selected realtime WebRTC
member.

The target-aware result corrects two earlier assumptions. V8, Wiremock,
`codex-windows-sandbox`, and registry crate `windows` are selected because the
upstream manifests contain unconditional normal dependencies. `codex-bwrap`
and its vendored Bubblewrap sources are not selected by the CLI graph, so
Bubblewrap is not a blocker for this RPM.

The released `Cargo.lock` is not accepted by Cargo 1.96.1 under `--locked`.
Exactly 132 source-less local package records carry version `0.0.0`; changing
only those versions to the released workspace version `0.144.5` makes the lock
current without changing dependencies, sources, checksums, or package
membership. The source lock SHA-256 is
`175793a40a3147db1fee08fd9db0acc59312c344b3513dd7ee316f5446d8119e`; the
controlled normalized lock SHA-256 is
`2a5c38ba7ec277dba77477db379950530ca32dad01f34ad4bc6e3bac5636b9d9`.

The spec performs that release-specific normalization directly in `%prep`. It
first verifies the complete original lock hash, requires exactly 132 matching
version lines, applies one anchored `sed` substitution, and verifies the
complete normalized lock hash. This is smaller and at least as constrained as
the generated 398-line patch it replaced. Upstream main intentionally retains
workspace version `0.0.0`, and no upstream lock repair exists for this
release-stamping defect.

## Selected Source Materialization

The audit script now materializes the exact 885 selected external Cargo sources:
879 checked registry archives and six Cargo-normalized packages from five
verified Git repositories. It generates Cargo checksums, a sorted vendor
manifest, a prospective source-replacement configuration, a deterministic tree
receipt, and a normalized archive without copying transient dependency trees.

Two independent output roots produced byte-identical receipts and these hashes:

- vendor tree: `f330af77ea7a1ca2eab30b88bf67680730c1f7943b8f6495136625cb226aeb8a`
- vendor manifest: `5c8008b21c127176beac9a7bc86dc70743335b65c98ce98cd8150e280e6f022c`
- Cargo configuration: `7a0d321c6a8b7b18c5d5e8f008c13e486ffa598a5985b58f9cbafdf6b9b12bf2`
- archive: `06060af22d4cf5d66342cc482ff75c5b056f2c6488636bd3cb478d510326e5d9`
- receipt: `57857f050b55d9b596995e3de3842894a77d16d53b4a2ca23f9ceb83b5c2b5ef`

This remains selected-source evidence, not a complete Cargo directory source.
Cargo resolves non-development metadata outside the checked Linux graph; the
first concrete blocker was `chrono` requesting `js-sys`. Those identities are
not folded into the authoritative selected closure and are instead recorded by
the separate resolver supplement below.

## Resolver-Only Source Supplement

The audit now computes the directory-resolution fixed point without development
dependencies. It starts from the authoritative 1,004 identities, uses Cargo's
workspace dependency kinds for path packages, follows every external package's
locked normal/build dependencies regardless of target predicate or optional
activation, and uses `RUSTC_BOOTSTRAP=1 cargo -Z avoid-dev-deps` to match Fedora
Cargo macro behavior. The result contains 239 resolver-only registry crates, no
resolver-only Git or path package, and no `rules_rust` or `rust-sdks` source.

The 239 sources split into 157 packages active in Cargo's all-target graph and
82 inactive optional metadata packages, including `quinn`. Each record in
`codex-cli-0.144.5-cargo-resolver-supplement.json` retains the immutable lockfile
source, checksum, normalized manifest license metadata, immediate lock
reference, and deterministic dependency path. The receipt SHA-256 is
`a9a5612e905e4bf1f1b4fd2214291cddc24af688b031a64809749651358e40ff`.

Two independent combined materializations produced byte-identical receipts and
1,124 vendor directories: 885 authoritative selected sources and 239
resolver-only sources. Both the 1,004-package selected target and the
1,161-package active all-target graph resolved offline from an empty Cargo home.

- vendor tree: `c50f41d4d6e582ef86f51cffcff086985975711f9e1c2b08d08778d05a472ebe`
- vendor manifest: `5e2b14b7cdf832907408ad83cbd8838c6220dbd7c7a91c9bb11e4bf208013ac8`
- Cargo configuration: `5d5df5008cf7389f8da7b690846f72eecda85b6cac6570506b3cd479dc5ffa27`
- archive: `7f9b7661dd4a6021e57e1e3e827bf785db0186e79bfcea2581b97b0d1a4c5d9b`
- archive size: `231,939,492` bytes
- receipt: `fe302ea41ef17b47432921f19361eda93576b51b2ddfdde31dcde66693db4d1b`

This proves the source model, not its final packaging integration. The archive
is not immutably hosted, the resolver-only license metadata has not been
approved as part of the RPM source inventory, and `%cargo_vendor_manifest`,
complete `bundled(crate(...))` metadata, final aggregate linked-license
approval, license texts, and the no-crate-devel application layout remain later
gates. The spec remains fail-closed.

## Selected Cargo License Accounting

The separate deterministic license audit links back to the unchanged selected
closure and resolver supplement. It applies the same package and feature
selection while distinguishing the product's Linux graph from Fedora's
`cargo-rpm-macros` license witness. The earlier 984 normal-path count is not the
linked-license count because proc-macro dependencies and their subgraphs remain
compile-time inputs even when reached through normal edges.

For `x86_64-unknown-linux-gnu`, excluding build, development, and proc-macro
edges leaves 873 Cargo packages in the linked graph. The remaining 131 selected
packages are compile-time only: 20 have the existing build role and 111 are in
the normal-path proc-macro subgraph. Fedora's `--target=all` license witness
contains 1,019 packages: 874 selected identities and 145 resolver-only
identities. Resolver-only records remain separate from the authoritative Linux
source and linked-license closure.

The audit records Cargo manifest license metadata for all 1,004 selected and
239 resolver-only packages. It normalizes 62 selected and 18 resolver-only
legacy slash-separated alternatives to SPDX `OR`, matching cargo2rpm, and
records 35 unique Linux-linked and 39 unique all-target expression candidates.
Every selected license is compared with source metadata before it is accepted:
879 registry manifests come from checksum-verified archives, six Git manifests
come directly from exact commit objects after URL and tracked-checkout
verification, and 119 workspace licenses come from the exact release metadata.
The receipt SHA-256 is
`530c134e176348436bb05e102b433d7ede1fcf59767964038e12fdaf5b2d27b8`.

This is not the final RPM license closure. Fedora-allowed SPDX review, package
license texts, and the recursive Rusty V8/Chromium native static inventory are
still incomplete. The audit therefore leaves final binary license completeness
and production `License:` approval false; the spec retains only the upstream
project `Apache-2.0` tag while `%prep` aborts.

## V8 Source Gate

Selected crate `v8 149.2.0` defaults to downloading a target-specific prebuilt
`librusty_v8.a` from GitHub. That is forbidden for this source build. Codex has
no compile-time feature that removes V8, and Fedora 44 has no `crate(v8)`
provider. Fedora's `v8-devel` is V8 `13.6.233.17`, which is incompatible with
the crate's V8 `14.9.207.2` and does not provide its static Rust binding.
The other current Fedora `v8-devel` branches are also Node-derived. Patching a
Fedora Node package would require a major V8 ABI/source upgrade and is not a
narrow or suitable Rusty V8 integration.

The upstream `V8_FROM_SOURCE` path can use system GN, Ninja, and clang, but still
invokes a downloader for the Chromium-pinned Rust toolchain. Chromium GN already
has configuration for a custom Rust sysroot, version, and bindgen root, but
Rusty V8 does not expose a no-download system-toolchain mode. The download was
introduced when upstream restored V8 Temporal support in commit
`1bc16604555847e020945abe39b8d4b2fec5dd9e`, tracked by Rusty V8 issue 1839.

A local exact-tag prototype now proves that the selected Temporal-enabled V8 can
be built with Fedora's stable Rust instead of that binary toolchain. The complete
recursive `v149.2.0` source was configured with Fedora Rust 1.96.1, GCC 16.1.1,
LLD 22.1.8, GN 2437, Ninja 1.13.2, system libstdc++, and four jobs. The Temporal
Rust target compiled, `mksnapshot` linked, and the final 160,316,016-byte
`librusty_v8.a` has SHA-256
`07a7c6458d88253cd89b59a4c9b325e28cae72dda112f1bd7c5b932484d48719`.
An offline path consumer linked that archive with the published 149.2.0 binding
file and executed JavaScript, printing `Fedora Rusty V8`.

That prototype is evidence, not a package-ready provider. Its exact source,
consumer contract, and two zero-fuzz patch groups now live in the separate
blocked `packages/rust-v8` draft. The `rust-v8-static` package provides
`rusty-v8-static(abi) = 149.2.0` and installs
`/usr/lib64/rust-v8/149.2.0/librusty_v8.a`; Codex keeps the published crate
binding and selects the archive through `RUSTY_V8_ARCHIVE`.

Codex's selected Cargo graph enables `v8` features `default,use_custom_libcxx`,
while the Fedora archive uses system libstdc++. `%build` therefore also exports
`GN_ARGS=use_custom_libcxx=false`, which makes the crate build script emit the
matching dynamic libstdc++ link flag. An offline smoke with that exact feature
and environment tuple prints `Fedora Rusty V8`.

The separate package boundary is now selected because the crate already accepts
an external exact-version archive and the Chromium/V8 build concern is reusable.
It does not remove Codex's final static-link license obligations. The provider
remains blocked until all 20 submodules are immutable RPM inputs, the patches
are accepted or fully reviewed downstream, the recursive license closure is
complete, and network-isolated Fedora 43, Fedora 44, and Rawhide builds pass.
openSUSE's nearby `rusty_v8 149.4.0` package demonstrates the scale of the
source build but still supplies a prohibited 274,625,900-byte prebuilt Chromium
Rust toolchain.

## Fedora Update Policy

The Fedora draft now installs `/etc/codex/config.toml` with
`check_for_update_on_startup = false`. A focused generic patch makes `codex
doctor` honor that setting by retaining local cache and install-target details
without performing a latest-version network probe.

Two Fedora-specific patches use the build-only
`CODEX_DISTRIBUTION_CHANNEL=fedora` marker to identify the RPM binary. They
suppress TUI update notices, direct `codex update` to `dnf upgrade codex-cli`,
avoid npm/Homebrew/standalone recommendations, and reject the app-server
daemon's standalone installer and hourly updater loop. Unmarked npm, Bun, pnpm,
Homebrew, standalone, and test builds retain their upstream defaults. No
upstream issue or pull request has been submitted.

## Remaining Gates

1. Review the separate resolver-only source model and selected-aware Cargo
   license evidence without obscuring the exact Linux build closure.
2. Publish immutable, checksummed RPM inputs for the accepted registry, Git, and
   resolver-only sources, then integrate Fedora vendoring metadata.
3. Upstream or review the V8 system-toolchain changes, materialize every
   recursive source and license input immutably, and reproduce the build without
   networking in Fedora 43, Fedora 44, and Rawhide buildroots.
4. Complete license-text and native static-link review, then run clean offline
   Fedora 43, Fedora 44, and Rawhide builds, tests, lint, and extracted-payload validation.

## Intentional Failure

`codex-cli.spec` verifies the immutable release archive, closure, selected and
resolver source evidence, and selected-aware Cargo license audit, extracts the
source, verifies the original lock and exact mutation count, performs the
anchored normalization, verifies the normalized lock, and then exits during
`%prep`. It must remain fail-closed until the gates above are satisfied. No
generated RPM was installed and COPR was not mutated during this probe.

## References

- https://github.com/openai/codex/releases/tag/rust-v0.144.5
- https://github.com/openai/codex/tree/87db9bc18ba5bc82c1cb4e4381b44f693ee35623
- https://github.com/denoland/rusty_v8/issues/1839
