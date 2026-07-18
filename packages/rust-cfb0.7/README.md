# rust-cfb0.7

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT license file.

Fedora 43 already provides exact `crate(cfb) = 0.7.3`, so publication excludes
that release. Fedora 44, Rawhide, and matching RPM Fusion repositories provide
no exact package; configured publication therefore targets those two releases
on x86_64 and aarch64. Fedora provides the required `byteorder`, `fnv`, and
`uuid` dependencies in every selected chroot. This package must publish before
`rust-infer0.19` on Fedora 44 and Rawhide.
