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
`b5be10ceca68a9185c5ae9b9369415bac2040dfd059059636757b759773708c3`.
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

- vendor tree: `7ddf7b80397d2b177532cf6ac8fae193544a148eb387a6ee5a9cd1ba8c072e1c`
- vendor manifest: `0caa78c29e67e1cc8757e64f992fc690d60f174ea855e3295aff1a3189fdf5eb`
- Cargo configuration: `7a0d321c6a8b7b18c5d5e8f008c13e486ffa598a5985b58f9cbafdf6b9b12bf2`
- archive: `4aee6efe0f209f38942a6ef6e56e8c3d766a6f62906b9ac20b9cee4966553d61`
- receipt: `047d9e62f570c6887696a579bf40617c70c800ae8d810328d9e15bed401c0b0e`

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
`51eab69c077b119435029d2e225d9839ff332b0e471d5270282e418b815e1876`.

Two independent combined materializations produced byte-identical receipts and
1,124 vendor directories: 885 authoritative selected sources and 239
resolver-only sources. Both the 1,004-package selected target and the
1,161-package active all-target graph resolved offline from an empty Cargo home.

- vendor tree: `5712aa3f9d33f5d514e78f36a31313b537c568b293a0181f79c7ae217e21b80c`
- vendor manifest: `4ef2a6daa61a24f800e9737fdae8570f05623055b77c58f862b2d3c12b7e93b4`
- Cargo configuration: `921057f81bbc67d9db85e4cfbb6f1395ba2f214519c7c291557216e46ef51a89`
- archive: `e0912374c17464e436d9daac6d71f08cbf66d1cfa1eaa07a0122d41b36f2b72b`
- archive size: `231,939,492` bytes
- receipt: `9d20d17d7e649f822413033e417e4fb6060598cb86bd76649ce1e2a137480355`

The source model is now integrated through the repository-backed COPR SCM path.
`scripts/prepare-codex-cargo-srpm-sources` populates only the selected and
resolver-supplement identities, reuses the checked audit materializer, and adds
the generated archive, manifest, and Cargo configuration to the SRPM. `%prep`
rechecks the safe single-root archive, exact directory set, every Cargo
checksum, the complete vendor-tree identity, and selected/all-target offline
resolution before running `%cargo_prep -N`. Fedora's `%cargo_vendor_manifest`
cannot represent this package-scoped source plan because Cargo2RPM expands the
complete 128-member workspace with all features and development edges, which
immediately requests the deliberately excluded `rules_rust` source. The spec
instead passes the exact checked 1,124-entry manifest through
`cargo2rpm parse-vendor-manifest`, requires 1,124 unique bundled Provides, and
installs that manifest as `cargo-vendor.txt` under the RPM license directory so
Fedora's Cargo file attributes emit the Provides automatically.

Generated gzip bytes and the source builder's exact Cargo version are not part
of the normative contract. The semantic tree SHA-256 remains
`5712aa3f9d33f5d514e78f36a31313b537c568b293a0181f79c7ae217e21b80c`;
any Cargo normalization change that alters that tree fails closed. The package
still stops before compilation because final aggregate linked-license approval,
required license texts, and Fedora build proof remain later gates. The exact
package-scoped build, binary install, and network-free smoke flow are retained
below that stop so they can be reviewed before the provider gate is lifted.

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
`b13315e6e6442605b05b921c2832b1a990869c56f4381abd9b91b121f69b2426`.

The resolver source now also has a package-local legal-file inventory. Of 1,124
vendored directories, 1,020 contain at least one nonempty recursively discovered
license, copying, unlicense, or `LICENSES/` candidate and 104 do not; 51 of those
gaps are in the 873-package Linux-linked graph. A stricter package-root view has
1,016 directories with a top-level candidate and 108 without one, including 54
Linux-linked directories. Notice, copyright, credits, authors, and patents files
are recorded separately and are not treated as full license texts. The receipt
preserves graph roles and exact file hashes rather than treating all vendored
source as linked. A nested candidate does not prove package-level legal closure,
and a missing candidate does not prove that no usable upstream text exists. The
supplemental receipt now maps every linked directory without package-local text;
final Fedora SPDX and aggregate review remain separate.

The checked v6 supplemental-source receipt resolves 50 Linux-linked crates and
supplies 25 deduplicated installable texts. It distinguishes Cargo VCS evidence,
release-history manifest evidence, a checked SPDX canonical-standard source for
`fxhash`, and the later upstream `bech32 0.11.0` crate text bound to merged PR
88. The five remaining published-crate omissions use the same pinned canonical
MIT and Apache-2.0 sources after their upstream requests were filed. Release
manifests and ICU data remain comparison-only. No linked Cargo text mapping is
unresolved. The exact selected
`notify 8.2.0` crate and `LICENSE-CC0` bytes match Fedora 44's
`rust-notify-8.2.0-2.fc44`, so its CC0 classification and payload treatment are
resolved through that distribution precedent.

This is not the final RPM license closure. Fedora-allowed SPDX and aggregate
review plus exact Rusty V8/Chromium static-consumer differences remain open,
using Fedora Node.js and Chromium as accepted precedent for overlapping source
and license treatment. The audit therefore leaves final binary license
completeness and production `License:` approval false; the spec retains only the
upstream project `Apache-2.0` tag while the build remains proof-only.

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

That prototype has since become the separate blocked `packages/rust-v8`
provider. Release `149.2.0-0.24` completed source-bound COPR builds on Fedora
43, Fedora 44, and Rawhide for both `x86_64` and `aarch64` in build `10757049`,
satisfying Codex's exact `rusty-v8-static(abi) = 149.2.0` provider and
architecture requirements. Fedora Node.js and Chromium are accepted precedent for
overlapping source, toolchain, SPDX, and payload treatment; only exact selected
graph and consumer differences remain Codex gates. The provider installs
`/usr/lib64/rust-v8/149.2.0/librusty_v8.a`; Codex keeps the published crate
binding and selects the archive through `RUSTY_V8_ARCHIVE`.

Codex's selected Cargo graph enables `v8` features `default,use_custom_libcxx`,
while the Fedora archive uses system libstdc++. `%build` therefore also exports
`GN_ARGS=use_custom_libcxx=false`, which makes the crate build script emit the
matching dynamic libstdc++ link flag. An offline smoke with that exact feature
and environment tuple prints `Fedora Rusty V8`.

The separate package boundary is selected because the crate already accepts an
external exact-version archive and the Chromium/V8 build concern is reusable.
The successful `x86_64` provider cells do not remove Codex's final static-link
license obligations. Rusty V8 still requires final static-license and consumer
closure, while Codex still requires its own linked-license, build, test, and
payload proof.
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

1. Complete configured-SCM Fedora 43, Fedora 44, and Rawhide `x86_64` builds
   through COPR with the released OpenSSL 4-compatible lock update and a build
   timeout above five hours; do not resume the resource-heavy local full build.
2. Capture the final Codex linker inputs, selected Rusty V8 archive members, and
   separate Rust libraries, then generate the exact aggregate `License:` and a
   deduplicated native-static `%license` payload.
3. Run the smoke checks, artifact lint, and extracted-payload validation without
   installing the generated RPMs.

## Build Proof State

`codex-cli.spec` verifies the immutable release archive, complete resolver source,
all 50 supplemental mappings, 25 deduplicated texts, patches, lock normalization,
and 1,124 bundled Provides before compilation. Release `0.17` reached offline
Cargo compilation and exposed the missing system OpenSSL development metadata;
release `0.18` adds `pkgconfig(openssl)`. The local retry was stopped at maintainer
request because the full build is too expensive for the local machine, so the
production proof continues through configured-SCM COPR. Build `10756814` then
stopped during fresh SRPM generation because later-release `bech32` archive
evidence was incorrectly passed through GitHub raw VCS reconstruction; release
`0.19` limits that reconstruction to VCS and release-history mappings. Build
`10756823` then showed that the tracked later-release source had lost its
immutable crates.io transport hash; release `0.20` restores and verifies the
reviewed bech32 archive SHA-256. No RPM was installed.

Build `10756860` imported the exact `0.20` SRPM and reached real compilation in
all three x86_64 targets. Fedora 43 and Fedora 44 were still compiling when COPR
terminated them at five hours. Rawhide failed earlier because its OpenSSL 4.0.1
is rejected by `openssl-sys 0.9.111`. Release `0.21` updates only `openssl`
`0.10.75` to `0.10.78` and `openssl-sys` `0.9.111` to `0.9.114`, the first
released pair containing upstream PR `sfackler/rust-openssl#2591`. The source
builder and `%prep` now fail closed across the original, dependency-updated, and
workspace-normalized Cargo.lock identities.

The local `0.21` source proof reproduces all 885 selected and 1,124
resolver-complete vendor directories offline with unchanged graph and license
counts. Source RPM `codex-cli-0.144.5-0.21.fc44.src.rpm` is SHA-256
`3ba0ed91063e1a46a38bcf4c73ae107a9aa37ca9eab1edda72aa04dfebc64a90`,
contains all 22 expected members, and has zero `rpmlint` errors with only the
two expected warnings for repository-generated local sources. Its spec,
OpenSSL lock patch, and selected closure are byte-identical to the repository.
No RPM was installed and no local full compilation was started.

## References

- https://github.com/openai/codex/releases/tag/rust-v0.144.5
- https://github.com/openai/codex/tree/87db9bc18ba5bc82c1cb4e4381b44f693ee35623
- https://github.com/denoland/rusty_v8/issues/1839
