# rust-nalgebra0.35

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256 and includes
the declared Apache-2.0 license file.

No exact `nalgebra 0.35.0` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. Fedora supplies the selected numeric
dependencies, and Agentlab supplies `simba 0.10` in all six chroots. The
Fedora-only patch retains the default/`std` surface required by `imageproc` and
omits unselected optional compatibility branches. The crate's Rust 1.89 MSRV is
below every selected Fedora toolchain.
