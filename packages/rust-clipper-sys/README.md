# rust-clipper-sys

## Finalization status

The package is enabled for the Fedora 43, Fedora 44, and Rawhide target matrix.

The exact crates.io `clipper-sys 0.8.0` source is ISC-licensed. Its bundled
Clipper 6.4.2 implementation is not compiled or installed; the package builds
the wrapper against Fedora's matching BSL-1.0 `polyclipping` shared library and
removes the bundled implementation, header, and license from the crate payload.

The retained test-only patch keeps backing arrays alive while upstream's FFI
tests read their raw pointers. It does not change the public crate or runtime
behavior.
