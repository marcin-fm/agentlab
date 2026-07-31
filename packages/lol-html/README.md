# lol-html Packaging

This package provides Cloudflare `lol-html 3.0.1` as a shared C API library for Bun. The C API crate remains version `1.4.0`, requires Rust `1.89`, and retains the byte-identical public header from `3.0.0`.

Fedora `cargo-c` installs `liblolhtml.so.1.4.0` with SONAME `liblolhtml.so.1`, the `liblolhtml.so` and `liblolhtml.so.1` symlinks, `lol_html.h`, and `lol-html.pc`. The runtime package owns the versioned library; `lol-html-devel` owns the header, pkg-config metadata, and linker symlink. The static archive is intentionally omitted.

Release `3.0.1-0.4` defines the C API build against Fedora's offline system Cargo registry. Fedora supplies the complete production closure except for the published Agentlab compatibility providers `rust-cssparser0.36` and `rust-selectors0.37`. Root production BuildRequires and C API BuildRequires are generated separately because the C API's local path dependency is not recursively expanded by `cargo2rpm`; the root Rust test and benchmark dependencies remain unselected. The `3.0.1` C API lock differs from `3.0.0` only in the local `lol_html` package version.

The one-line downstream patch records the root BSD-3-Clause license in the unpublished C API Cargo manifest so Fedora's linked-license inventory has no local declaration gap. `%patch -F 0` applies it without fuzz. The Fedora-resolved 29-entry `LICENSE.dependencies` inventory has SHA-256 `4e32b2460074c0364c17f7f2e4eeb12a52f81bd581d4b7e04f111cd22826f541`; the package retains the reviewed aggregate SPDX expression without copying system-provider license corpora. Fedora and RPM Fusion package queries for Fedora 43, Fedora 44, and Rawhide found no existing `lol-html` or `pkgconfig(lol-html)` provider.

The retained `lol-html-3.0.0-package.yml` preserves byte-for-byte the 3,945-byte historical manifest input recorded by Bun's final-license receipt, including SHA-256 `c8bab9f03901bf2378b64aead63cee5217c733fcb46e23876d53c075507dd2e2`. It is not relabeled as current `3.0.1` build evidence. Current validation is defined only by the static source, Cargo, C API, license, runtime, output, and six-target contract in `package.yml`; target results remain canonical wiki and COPR evidence.

Bun's final dynamic-link and HTMLRewriter runtime proof remains consumer integration work and does not block this provider package.
