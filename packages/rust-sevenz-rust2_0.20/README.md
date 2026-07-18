# rust-sevenz-rust2_0.20

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256 and includes
the declared Apache-2.0 license file.

No exact `sevenz-rust2 0.20.2` provider exists in Fedora 43, Fedora 44, Rawhide,
or matching RPM Fusion repositories. Fedora supplies the complete native
default dependency closure plus the retained Brotli, deflate, and Zstandard
optional surfaces. The Fedora-only patch omits unavailable WASM, LZ4, and
NT-time interfaces and their stale documentation while preserving native
default compression and extraction behavior. Package tests reuse the root
project license instead of installing a byte-identical duplicate fixture.
