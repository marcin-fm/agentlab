# lol-html Packaging

This package provides Cloudflare `lol-html 3.0.0` as a shared C API library for Bun. The C API crate is version `1.4.0` and requires Rust `1.89`.

`cargo-c 0.10.21` installs `liblolhtml.so.1.4.0` with SONAME `liblolhtml.so.1`, the `liblolhtml.so` and `liblolhtml.so.1` symlinks, `lol_html.h`, and `lol-html.pc`. The runtime package owns the versioned library; `lol-html-devel` owns the header, pkg-config metadata, and linker symlink. The static archive is intentionally omitted.

The repository-backed SRPM source job runs `scripts/prepare-lol-html-srpm-sources` against the released tag archive and exact `c-api/Cargo.lock`. It vendors 43 registry crates into a deterministic 4,110,371-byte archive at SHA-256 `55da2f37159c90797e8ddeb81535c31067a1b1f884f0de2779dd17467279639f`. The build installs the normalized 41-entry `cargo-vendor.txt` as `%license`, which enables Fedora's automatic `bundled(crate(...))` Provides.

The one-line downstream patch records the root BSD-3-Clause license in the unpublished C API Cargo manifest so Fedora's linked-license inventory has no local declaration gap. The checked 29-entry linked closure installs 28 unique license texts for 44 crate-to-text mappings, with the `selectors 0.37.0` source-embedded MPL-2.0 notices handled consistently with Fedora's package precedent. Fedora and RPM Fusion package queries for Fedora 43, Fedora 44, and Rawhide found no existing `lol-html` or `pkgconfig(lol-html)` provider.

Release `3.0.0-0.7` passes Fedora 43, Fedora 44, and Rawhide Mock builds on both `x86_64` and `aarch64`. The package runs all eight upstream C suites against the staged shared library in addition to the focused C smoke, SONAME, pkg-config, symbol, `ldd -r`, digest, and payload checks. Matrix artifact `rpmlint` reports zero errors and only the expected generated `Source1` URL warning in each chroot. No RPM was installed.

Bun's final dynamic-link and HTMLRewriter runtime proof remains consumer integration work and does not block this provider package.
