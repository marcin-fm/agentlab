# rust-lzma-rust2_0.16

This versioned compatibility package exists only for Rawhide. Kreuzberg's
`sevenz-rust2 0.20.2` dependency requires `lzma-rust2 >= 0.16, < 0.17`, while
Rawhide has advanced to the incompatible 0.17 branch. Fedora 43 and Fedora 44
already provide `lzma-rust2 0.16.5` and are intentionally omitted.

Release `2.1` preserves Fedora's `0.16.5-2` base release and metadata patch from
commit `3309ae290a9d488a729276d467b1b20f89093572`. The canonical crates.io archive
is pinned by SHA-256. Tests remain disabled for the same Fedora-documented
reason: the published crate omits required test data, including precompiled
inputs whose provenance and licensing have not been reviewed.
