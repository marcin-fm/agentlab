# rust-cfb0.14

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT license file.

No exact `cfb 0.14.0` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. Fedora provides its required `fnv`, `uuid`,
and `web-time` dependencies in all selected chroots. The retained patch removes
benchmark-only Criterion metadata and guards a debug-only panic test from
optimized builds; it does not alter runtime library behavior.
