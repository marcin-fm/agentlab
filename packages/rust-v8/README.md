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
producer owns a 21-repository recursive source tree, Chromium GN integration,
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

The root archive does not contain the required submodule contents.
`rust-v8-149.2.0-source-closure.json` records the root plus all 20 recursive
submodules with exact URLs and commits. That receipt has SHA-256
`fd5c2a46665b5686799a7505158e4f0bb047e087750acb455c50dfb90e3484b1`.
It is identity evidence, not a production RPM source: immutable component
archives, their hashes, and a complete recursive source artifact remain open.

## Fedora Toolchain Patches

`rust-v8-system-rust-toolchain.patch` guards Chromium's nightly-only Rust flags
and bundled-toolchain inputs, supports Fedora's libclang layout, and adds the
stable allocator shims needed by the Temporal Rust graph.

`rust-v8-gcc-portability.patch` keeps Clang warning behavior while making two
preprocessor conditions valid under GCC and adding one direct include required
by the Wasm build.

Both patches pass zero-fuzz dry-runs against a fresh exact-tag recursive tree
and are retained as hashed source inputs in the draft SRPM. They are not yet
declared as RPM patches because the root archive lacks the files they modify.
Neither patch has been submitted upstream. The new allocator shim is original
downstream BSD-3-Clause code by Marcin FM.

The known draft source-package license expression is therefore
`MIT AND BSD-3-Clause`. It remains incomplete until the recursive Chromium,
V8, third-party, and vendored Rust inventory is finished.

## Prototype Result

The local Fedora 44 x86_64 proof used stable Rust `1.96.1`, GCC `16.1.1`, LLD
`22.1.8`, GN `2437`, Ninja `1.13.2`, system libstdc++, and no Chromium Rust
binary toolchain. It built the Temporal Rust target and a 160,316,016-byte
`librusty_v8.a` with SHA-256
`07a7c6458d88253cd89b59a4c9b325e28cae72dda112f1bd7c5b932484d48719`.
An offline Cargo consumer linked the archive and printed `Fedora Rusty V8`.

## Remaining Gates

1. Materialize every recursive component as an immutable checksummed RPM input.
2. Reproduce the patched source tree without network access.
3. Complete the native, third-party, and vendored Rust license-text inventory.
4. Review every SPDX expression and system-library decision for Fedora.
5. Run clean Fedora 43, Fedora 44, and Rawhide x86_64 builds and installed consumer smokes.
6. Prove aarch64 or retain an explicitly reviewed architecture restriction.
7. Submit or otherwise resolve the downstream system-toolchain and portability patches.

The spec verifies only checked root and receipt hashes, then aborts before
unpacking. The package is disabled in COPR.
