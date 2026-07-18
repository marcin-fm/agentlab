# rust-infer0.19

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT license file.

No exact `infer 0.19.0` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. The default `std` feature enables `cfb 0.7`:
Fedora 43 supplies exact `cfb 0.7.3`, while `rust-cfb0.7` supplies Fedora 44 and
Rawhide. Publication is therefore serialized after the four-cell
`rust-cfb0.7` build. The retained patch only ignores doctests that reference
fixtures omitted from the published crate archive.
