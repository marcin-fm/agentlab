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

## Dynamic Library Decision

`rust-v8-149.2.0-dynamic-linking.json` records the exact-source feasibility
review. Rusty V8 declares only `static_library("rusty_v8")` with
`complete_static_lib = true`. Its Cargo build script copies
`RUSTY_V8_ARCHIVE` to `librusty_v8.a` and always emits
`cargo:rustc-link-lib=static=rusty_v8`.

V8 itself can produce component shared libraries, but those DSOs are not a
shared Rusty V8 consumer interface. The Rusty V8 bridge has no shared target,
SONAME, symbol-version policy, or exported bridge ABI, and its C++ side calls
consumer-provided Rust callbacks. Repacking the PIC objects into a `.so` would
therefore create a new downstream ABI without making existing `v8` crate
consumers use it.

The package retains only `rust-v8-static`. A dynamic package can be reconsidered
if upstream defines a shared target and build-script mode with a maintained
loader and ABI contract. The receipt SHA-256 is
`3747f0adeebe0c6eec9e8c1bebf27be5dd310f71e4da3246355eaf016d999704`.

## Source Evidence

The root tag `v149.2.0` resolves to commit
`5d0e31ea6bf67f4559faa759b91e22bc3f1cd696`. Its 340,819-byte codeload archive
has SHA-256
`8f63ff709b52b7a2de0453e37ba8f661c21d0a398e4ecf5298b273ab8018747a`.

The root archive does not contain the required submodule contents. The spec uses
19 direct commit-addressed submodule archives plus one V8 archive generated at
SRPM time from its exact upstream commit. These hosting services generate commit
tarballs dynamically, so compressed bytes are not the contract. Safe paths and
links, archive layout/root, exact component trees, and the reviewed exclusions
are verified in `%prep`. The V8 source filter removes only the unused CC0
SipHash license, header, and implementation while
`v8_use_siphash=false`; `rust-v8-disable-unused-siphash.patch` makes the existing
feature boundary explicit in GN. The 20 direct public inputs plus one generated
input reconstruct 60,911 file, mode, and symlink records. They match the exact
recursive Git tree except for those three reviewed exclusions, at SHA-256
`6c09e1a9ca0c3d1bfea49a40e0be5abcb12ca5a3c92983e667cec499f47bcc1d`.

`rust-v8-149.2.0-source-closure.json` records every URL, filename, byte count,
archive hash, component-tree hash, source-filter provenance, and RPM source
number. Its SHA-256 is
`a52f0d1cffe9d5b5884ba244b460ee0502eb38e68b9af809d9b0cf25b741cfd0`.
`rust-v8-149.2.0-source-filter.json` binds the exact upstream and filtered trees,
the three exclusions, and the checked generator script. Its SHA-256 is
`a611159b2626cb36600c1ebf332d4f7da093f9be310496a9145aec53d1d81ffa`.
No remote generated asset or separate hosting service is required.

This receipt proves the exact `.gitmodules` closure, not a full `gclient sync`.
V8's `DEPS` also names test, benchmark, and tooling sources that the direct
`//:rusty_v8` build does not materialize. Those declarations are inventoried
separately and are not silently promoted into RPM sources.

## Fedora Toolchain Patches

`rust-v8-system-rust-toolchain.patch` guards Chromium's nightly-only Rust flags,
including its minimal-symbol DWARF selection, and bundled-toolchain inputs,
supports Fedora's libclang layout, and adds the stable allocator shims needed by
the Temporal Rust graph.

`rust-v8-gcc-portability.patch` keeps Clang warning behavior while making two
preprocessor conditions valid under GCC, omits a Clang-only ARM64 assembly
marker from the Fedora Linux GCC build, and adds one direct include required by
the Wasm build.

`rust-v8-disable-unused-siphash.patch` moves the SipHash header and implementation
behind V8's existing `v8_use_siphash` feature. Agentlab keeps that feature false,
so omitting the three CC0 source files changes no selected runtime behavior.

All three patches pass zero-fuzz dry-runs against a fresh exact-tag recursive tree.
The spec now reconstructs that tree from the checked RPM sources and applies the
patches before reaching its deliberate remaining-gates stop. None of the three
patches has been submitted upstream. The new allocator shim is original
downstream BSD-3-Clause code by Marcin FM.

The retained Fedora 44 x86_64 static archive expression is:

```text
Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BSD-Protection AND LicenseRef-Fedora-Public-Domain AND LicenseRef-Fedora-UltraPermissive AND MIT AND NAIST-2003 AND Python-2.0.1 AND Unicode-3.0 AND Unicode-DFS-2016 AND Unlicense AND (Apache-2.0 OR BSL-1.0 OR MIT) AND (Apache-2.0 WITH LLVM-exception OR BSL-1.0)
```

`rust-v8-149.2.0-static-license.json` binds that expression to the exact 1,795
archive objects, 4,416 compile-dependency files, selected generated/data inputs,
17 reviewed component groups, and 24 exact license texts or file-level notices.
Every identifier is allowed by the installed Fedora license data. The receipt
also records that the 31 implicit Rust rlibs and system libraries are not
embedded in `librusty_v8.a`; they remain final-consumer obligations. Receipt
SHA-256 is
`cce81b7412fdb3f07eeeb71a65d48bb93e592474fdfc681a73046fbaebdb7a6c`.

`rust-v8-149.2.0-license-audit.json` currently hashes 414 candidate legal texts
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
that text to whole components or their embedded third-party assets. The broad
source audit remains acceptance evidence for every source input, but it is
intentionally separate from the selected binary expression. Source-only
build/test/tool material and nonembedded Rust rlibs are not promoted into the
`rust-v8-static` `License:` field.

`rust-v8-149.2.0-fedora-license-evidence.json` queries Fedora 44 `fedora` and
`updates` crate-devel metadata for those exact 216 source packages. It records
136 exact-version providers, 26 version-different providers, and 54 absent
providers. Exact matches reuse Fedora's reviewed SPDX metadata and source-RPM
identity, but do not establish that a crate is linked into `librusty_v8.a` or
complete the final aggregate expression. Its SHA-256 is
`b63ee251799012a6492526d85dab76a64bb93d813b4526c64a0a1266fd22acc3`.
The regenerated license-audit receipt binds that evidence at SHA-256
`6ea5d71b49ca32a4e76d47211fd64a852bb665364ccd32250740be827fe8ef93`.

## Prototype Result

The local Fedora 44 x86_64 proof used stable Rust `1.96.1`, GCC `16.1.1`, LLD
`22.1.8`, GN `2437`, Ninja `1.13.2`, system libstdc++, and no Chromium Rust
binary toolchain. It built the Temporal Rust target and, after the reviewed
SipHash exclusion, a 160,314,390-byte `librusty_v8.a` with SHA-256
`ea107f29106ef88a313b03bc6ff714fc4e1c1a5db822df646c8d5f0a82bca334`.
An offline Cargo consumer linked the archive and printed `Fedora Rusty V8`.

`rust-v8-149.2.0-archive-graph.json` now preserves a canonical retained witness for
that retained prototype. The `//:rusty_v8` Ninja query contains 1,795 selected
object inputs, and the archive contains the same 1,795 member-basename multiset.
The graph also has 31 implicit Rust `.rlib` dependencies which are explicitly
classified as not embedded in `librusty_v8.a`; the exact Cargo `v8` fingerprint
records its separate `temporal_capi` dependency. No googletest input appears in
the selected graph. The witness SHA-256 is
`a0f113e19ebe5043d66280904f21b82581fc5220ce612972e32df88b23f24a9f`.
Transient artifact roots are normalized, but this is not a reproducible-build
claim. It does not claim production provenance, object-to-member content
equality, network isolation, final archive-member extraction, or final consumer
link closure.

## Remaining Gates

1. Run source-bound, network-isolated Fedora 43, Fedora 44, and Rawhide x86_64 builds and installed consumer smokes, regenerating the selected-license receipt from each graph.
2. Prove aarch64 or retain an explicitly reviewed architecture restriction.
3. Complete the final consumer license closure for the 31 separately linked Rust rlibs.
4. Submit or otherwise resolve the three downstream system-toolchain, portability, and source-selection patches.

The spec verifies every source through the checked receipt, reconstructs the
reviewed filtered tree, applies all three patches, runs the exact retained
GN/Ninja graph, and checks the selected object/member structure. This local
production-build path does not close final consumer licensing, architecture, or
upstream-patch gates. The package remains disabled in COPR.
