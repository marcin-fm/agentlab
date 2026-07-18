# rust-lru0.18

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT license file.

Fedora provides only incompatible `lru 0.16.4`, not the selected `0.18.1`
branch, and matching RPM Fusion repositories provide no exact crate. Fedora
provides default `hashbrown 0.17` plus the test-only `scoped_threadpool 0.1` and
`stats_alloc 0.1` dependencies in every selected chroot.
