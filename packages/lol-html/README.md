# lol-html Packaging

This package provides Cloudflare `lol-html 3.0.0` as a shared C API library for Bun. The C API crate is version `1.4.0` and requires Rust `1.89`.

Fedora `cargo-c` installs `liblolhtml.so.1.4.0` with SONAME `liblolhtml.so.1`, the `liblolhtml.so` and `liblolhtml.so.1` symlinks, `lol_html.h`, and `lol-html.pc`. The runtime package owns the versioned library; `lol-html-devel` owns the header, pkg-config metadata, and linker symlink. The static archive is intentionally omitted.

Release `3.0.0-0.9` builds the C API against Fedora's offline system Cargo registry. Fedora supplies the complete production closure except for the published Agentlab compatibility providers `rust-cssparser0.36` and `rust-selectors0.37`. Root production BuildRequires and C API BuildRequires are generated separately because the C API's local path dependency is not recursively expanded by `cargo2rpm`; the root Rust test and benchmark dependencies remain unselected.

The one-line downstream patch records the root BSD-3-Clause license in the unpublished C API Cargo manifest so Fedora's linked-license inventory has no local declaration gap. The Fedora-resolved 29-entry `LICENSE.dependencies` inventory has SHA-256 `4e32b2460074c0364c17f7f2e4eeb12a52f81bd581d4b7e04f111cd22826f541`; the package retains the reviewed aggregate SPDX expression without copying system-provider license corpora. Fedora and RPM Fusion package queries for Fedora 43, Fedora 44, and Rawhide found no existing `lol-html` or `pkgconfig(lol-html)` provider.

The fresh Fedora 44 x86_64 Mock build passes all eight upstream C suites against the staged shared library in addition to the focused C smoke, SONAME, pkg-config, 97-symbol, `ldd -r`, digest, and payload checks. All five source, runtime, devel, debugsource, and debuginfo artifacts pass digest verification and `rpmlint` with zero errors or warnings. Configured Git-SCM COPR build `10749257` succeeds at release `0.9` in Fedora 43, Fedora 44, and Rawhide on both `x86_64` and `aarch64`. No RPM was installed.

Bun's final dynamic-link and HTMLRewriter runtime proof remains consumer integration work and does not block this provider package.
