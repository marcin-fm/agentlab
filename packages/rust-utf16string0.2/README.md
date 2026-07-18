# rust-utf16string0.2

## Finalization status

The package remains `blocked` with COPR disabled only because it belongs to the
blocked Kreuzberg PDFium-render dependency group. The canonical crates.io
archive is pinned by SHA-256, and Fedora 43, Fedora 44, Rawhide, and matching
RPM Fusion repositories provide no `crate(utf16string)` package.

Exact `0.2.0-0.1` transient builds `10737893` and `10737927` succeeded on
Fedora 43 and Fedora 44 for both x86_64 and aarch64. Downloaded SRPM specs were
byte-identical to the pre-evidence-bump repository spec, their source archives
matched SHA-256 `0b62a1e85e12d5d712bf47a85f426b73d303e2d00a90de5f3004df3596e9d216`,
and fresh artifact `rpmlint` checks reported zero errors and zero warnings after
filtering only the transient COPR signing key absent from the host keyring. RPM
digests verified independently. Release `0.2` changes only the release,
changelog, and retained evidence; package build behavior is unchanged.
