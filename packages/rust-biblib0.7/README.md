# rust-biblib0.7

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT and Apache-2.0 license files.

No exact `biblib 0.7.2` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. Fedora provides every selected default and
test dependency. Separate Fedora-only metadata patches omit the unselected
`diagnostics` feature, whose `ariadne 0.6` dependency is unavailable, and align
the test-only `rstest` dependency with Fedora's 0.26 branch. Package preparation
also normalizes mixed CRLF line endings in the upstream README and changelog.
