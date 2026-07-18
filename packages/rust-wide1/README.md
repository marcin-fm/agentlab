# rust-wide1

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
Zlib license file.

No exact `wide 1.5.0` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. Fedora provides `bytemuck 1`, and Agentlab
provides `safe_arch 1.0` across all six selected chroots. The Fedora-only patch
omits unselected serde and benchmark surfaces while retaining the default `std`
and SIMD implementation required by `simba`.
