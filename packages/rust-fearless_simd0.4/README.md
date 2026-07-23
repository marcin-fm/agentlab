# rust-fearless_simd0.4

This package provides the current Linebender `fearless_simd 0.4.1` crate for
Fedora 43, where `hayro-jpeg2000 0.3.5` requires it and the distribution has no
provider.

Fedora's historical `rust-fearless_simd 0.4.1` package was generated from a
different crate source that used the same crates.io name and version. Its
authors, manifest, features, and source bytes do not match the immutable current
Linebender archive, so Agentlab does not adapt that package. Fedora 44 and
Rawhide do not select this compatibility package because their Hayro consumer is
already supplied by the distribution.
