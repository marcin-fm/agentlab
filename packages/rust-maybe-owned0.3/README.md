# rust-maybe-owned0.3

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. Its relationship to the blocked Kreuzberg PDFium-render path is
dependency context, not a package-specific publication blocker. The canonical
crates.io archive is pinned by SHA-256, and Fedora 43, Fedora 44, Rawhide, and
matching RPM Fusion repositories provide no `crate(maybe-owned)` package.
Configured SCM publication targets Fedora 43 and Fedora 44 on x86_64 and
aarch64, matching the selected Kreuzberg dependency scope. Rawhide is omitted
because no current selected consumer target requires this compatibility crate.

Exact `0.3.4-0.1` transient builds `10737880` and `10737914` succeeded on
Fedora 43 and Fedora 44 for both x86_64 and aarch64. Downloaded SRPM specs were
byte-identical to the pre-evidence-bump repository spec, their source archives
matched SHA-256 `4facc753ae494aeb6e3c22f839b158aebd4f9270f55cd3c79906c45476c47ab4`,
and fresh artifact `rpmlint` checks reported zero errors and zero warnings after
filtering only the transient COPR signing key absent from the host keyring. RPM
digests verified independently. Releases `0.2` and `0.3` change only retained
evidence, publication status, release, and changelog; package build behavior is
unchanged. Current live build results are retained in the project playbook.

The first live SCM attempt, build `10740215`, stopped before SRPM creation when
the source builder received HTTP 403 from the crates.io API redirect generated
by `%{crates_source}`. Release `0.4` uses the immutable `static.crates.io`
archive directly with the same pinned source hash; crate build behavior is
unchanged.
