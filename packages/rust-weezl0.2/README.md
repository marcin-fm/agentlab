# rust-weezl0.2

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes the declared
MIT and Apache-2.0 license files.

No exact `weezl 0.2.1` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. The default library has no external
dependency; Fedora provides the optional async and test branches. Separate
Fedora-only patches remove benchmark-only dependencies, replace the LZW test
fixture omitted from the published archive, and replace a `Cargo.lock` test
input that Fedora's `%cargo_prep` deliberately removes. Production source is
unchanged.
