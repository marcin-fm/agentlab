# Rusty V8 Fedora Package Draft

This directory contains a fail-closed source package for Rusty V8 `149.2.0`,
which binds V8 `14.9.207.2`. It is the selected native V8 provider for the
blocked `codex-cli 0.144.5` package.

## Why A Separate Package

The `v8 149.2.0` crate already accepts an exact external archive through
`RUSTY_V8_ARCHIVE`. Codex can therefore keep the published crate source and its
generated binding while consuming a separately built
`/usr/lib64/rust-v8/149.2.0/librusty_v8.a`.

This boundary is preferable to building V8 inside `codex-cli` because the V8
producer owns a 21-component recursive Git submodule tree, Chromium GN integration,
stable-system-Rust changes, architecture proof, and a large native/static
license closure. Those concerns are independently reusable and should not be
duplicated in each Rust application that selects the same crate version.

The source package intentionally uses the Fedora crate namespace `rust-v8`
because it owns the source-bound native output for the exact crates.io `v8`
version. A future system crate-devel interface must come from this same source
package rather than splitting crate and native archive ownership.

Separation does not remove static-link obligations. Every consumer must still
include the complete Rusty V8 license expression and applicable license texts
in its final binary package.

## Consumer Contract

The planned binary package is `rust-v8-static`. It provides the version-only
capability `rusty-v8-static(abi) = 149.2.0` and installs the exact-version
archive:

```text
/usr/lib64/rust-v8/149.2.0/librusty_v8.a
```

A Cargo consumer sets:

```text
RUSTY_V8_ARCHIVE=/usr/lib64/rust-v8/149.2.0/librusty_v8.a
GN_ARGS=use_custom_libcxx=false
```

Codex selects crate features `default,use_custom_libcxx`, while the Fedora
archive uses system libstdc++ and was built with `use_custom_libcxx=false`.
The `GN_ARGS` value makes the crate build script emit the matching dynamic
libstdc++ link flag even when it consumes an external archive. An offline smoke
with that exact feature and environment tuple printed `Fedora Rusty V8`. No
runtime dependency on `rust-v8-static` is needed after the archive is linked.

## Source Evidence

The root tag `v149.2.0` resolves to commit
`5d0e31ea6bf67f4559faa759b91e22bc3f1cd696`. Its 340,819-byte codeload archive
has SHA-256
`8f63ff709b52b7a2de0453e37ba8f661c21d0a398e4ecf5298b273ab8018747a`.

The root archive does not contain the required submodule contents. The spec adds
all 20 exact commit-addressed GitHub codeload or Chromium Gitiles archives as
direct RPM inputs. The 153,497,693 bytes of checked archives reconstruct
60,914 file, mode, and symlink records and match the clean recursive Git tree at
SHA-256
`4de1088a4c1262fb07c8aa050261ea5adb4ea2f6f2da7bfe10908db5188f3b07`.

`rust-v8-149.2.0-source-closure.json` records every URL, filename, byte count,
archive hash, component-tree hash, and RPM source number. Its SHA-256 is
`bc0a06c17002afa555daf5ed5349afd23575aac0661daa02c9fffd7e97d326de`.
No generated aggregate archive or separate hosting service is required.

This receipt proves the exact `.gitmodules` closure, not a full `gclient sync`.
V8's `DEPS` also names test, benchmark, and tooling sources that the direct
`//:rusty_v8` build does not materialize. Those declarations are inventoried
separately and are not silently promoted into RPM sources.

## Fedora Toolchain Patches

`rust-v8-system-rust-toolchain.patch` guards Chromium's nightly-only Rust flags
and bundled-toolchain inputs, supports Fedora's libclang layout, and adds the
stable allocator shims needed by the Temporal Rust graph.

`rust-v8-gcc-portability.patch` keeps Clang warning behavior while making two
preprocessor conditions valid under GCC and adding one direct include required
by the Wasm build.

Both patches pass zero-fuzz dry-runs against a fresh exact-tag recursive tree.
The spec now reconstructs that tree from the checked RPM sources and applies the
patches before reaching its deliberate remaining-gates stop. Neither patch has
been submitted upstream. The new allocator shim is original downstream
BSD-3-Clause code by Marcin FM.

The known draft source-package license expression is therefore
`MIT AND BSD-3-Clause`. It remains provisional until the recursive Chromium,
V8, third-party, and vendored Rust declarations and texts are normalized,
reviewed for Fedora, and converted into the final aggregate expression.

`rust-v8-149.2.0-license-audit.json` currently hashes 415 candidate legal texts
and 231 `README.chromium` records. Chromium's Rust vendor tree contains 268
entries: 216 real source packages and 52 generated empty placeholders. Every
real vendored source package has a manifest license declaration and at least one
candidate text. The audit resolves 228 of 229 paths explicitly declared by
`README.chromium`. The sole unresolved path,
`v8/third_party/googletest/src/LICENSE`, belongs to a `Shipped: no` test-only
DEPS source that is intentionally not materialized. Exact evidence now
semantically normalizes the three comma-separated declarations and the bare
`BSD` label. In particular, clang-format is
`(Apache-2.0 WITH LLVM-exception) AND NCSA`, not the earlier incomplete
`Apache-2.0 AND NCSA` proposal. The encoding_rs, unicode-ident, and googletest
expressions are also reviewed, and three materialized declared texts are
semantically verified. All eight vendored Cargo slash alternatives remain
mechanically normalized to `MIT OR Apache-2.0`. The audit also records the exact Chromium parent text and
file-level header evidence for `tools/clang` and `tools/win`, without applying
that text to whole components or their embedded third-party assets. Remaining
semantic text review, aggregate SPDX normalization, Fedora allowability,
system-library, and final linked-archive decisions remain open.

`rust-v8-149.2.0-fedora-license-evidence.json` queries Fedora 44 `fedora` and
`updates` crate-devel metadata for those exact 216 source packages. It records
136 exact-version providers, 26 version-different providers, and 54 absent
providers. Exact matches reuse Fedora's reviewed SPDX metadata and source-RPM
identity, but do not establish that a crate is linked into `librusty_v8.a` or
complete the final aggregate expression. Its SHA-256 is
`b63ee251799012a6492526d85dab76a64bb93d813b4526c64a0a1266fd22acc3`.
The regenerated license-audit receipt binds that evidence at SHA-256
`19157d53ed1b8e4427897bb6ea639ba45c5294a97e17a8ec4fe63d88bf4878ef`.

## Prototype Result

The local Fedora 44 x86_64 proof used stable Rust `1.96.1`, GCC `16.1.1`, LLD
`22.1.8`, GN `2437`, Ninja `1.13.2`, system libstdc++, and no Chromium Rust
binary toolchain. It built the Temporal Rust target and a 160,316,016-byte
`librusty_v8.a` with SHA-256
`07a7c6458d88253cd89b59a4c9b325e28cae72dda112f1bd7c5b932484d48719`.
An offline Cargo consumer linked the archive and printed `Fedora Rusty V8`.

`rust-v8-149.2.0-archive-graph.json` now preserves a canonical retained witness for
that retained prototype. The `//:rusty_v8` Ninja query contains 1,796 selected
object inputs, and the archive contains the same 1,796 member-basename multiset.
The graph also has 31 implicit Rust `.rlib` dependencies which are explicitly
classified as not embedded in `librusty_v8.a`; the exact Cargo `v8` fingerprint
records its separate `temporal_capi` dependency. No googletest input appears in
the selected graph. The witness SHA-256 is
`fbf59c5066a74274a801542ea74fc0944d7be0298626dd987a2fdde4123ab561`.
Transient artifact roots are normalized, but this is not a reproducible-build
claim. It does not claim production provenance, object-to-member content
equality, network isolation, final archive-member extraction, or final consumer
link closure.

## Remaining Gates

1. Complete semantic review of Fedora-absent and materially version-different declarations, scoped parent-text cases, and embedded third-party assets.
2. Review every required text, SPDX expression, and system-library decision for Fedora.
3. Establish the final source-package and linked-static-archive license expressions.
4. Run clean Fedora 43, Fedora 44, and Rawhide x86_64 builds and installed consumer smokes.
5. Prove aarch64 or retain an explicitly reviewed architecture restriction.
6. Submit or otherwise resolve the downstream system-toolchain and portability patches.

The spec verifies every source through the checked receipt, reconstructs the
recursive tree, applies both patches, then aborts before compilation while the
remaining legal and build gates are open. The package is disabled in COPR.
