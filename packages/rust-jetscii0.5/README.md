# rust-jetscii0.5

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT and Apache-2.0 license files.

No exact `jetscii 0.5.3` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. The library has no runtime dependencies. Its
Fedora-only metadata patches substitute the maintained `memmap2 0.7.1` crate for
the unmaintained dev-only `memmap` dependency and omits the unselected
nightly-only `benchmarks` and `pattern` feature interfaces without changing
library sources.
