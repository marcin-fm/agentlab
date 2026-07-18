# rust-maybe-owned0.3

## Finalization status

The package remains `blocked` with COPR disabled only because it belongs to the
blocked Kreuzberg PDFium-render dependency group. The canonical crates.io
archive is pinned by SHA-256, and Fedora 43, Fedora 44, Rawhide, and matching
RPM Fusion repositories provide no `crate(maybe-owned)` package.

Exact `0.3.4-0.1` transient builds `10737880` and `10737914` succeeded on
Fedora 43 and Fedora 44 for both x86_64 and aarch64. Downloaded SRPM specs were
byte-identical to the pre-evidence-bump repository spec, their source archives
matched SHA-256 `4facc753ae494aeb6e3c22f839b158aebd4f9270f55cd3c79906c45476c47ab4`,
and fresh artifact `rpmlint` checks reported zero errors and zero warnings after
filtering only the transient COPR signing key absent from the host keyring. RPM
digests verified independently. Release `0.2` changes only the release,
changelog, and retained evidence; package build behavior is unchanged.
