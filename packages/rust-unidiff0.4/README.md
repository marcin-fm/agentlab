# rust-unidiff0.4

This package provides the released `unidiff` 0.4 Rust crate required by the
Headroom 0.31.0 native MCP build. The published crate includes its MIT license,
all integration-test fixtures, and no native code or runtime download path.

Clean Fedora 43 and Fedora 44 Mock builds passed. In each chroot, 19 published
tests passed and one doctest remained ignored; `rpmlint` reported zero errors
and zero warnings. Fedora and RPM Fusion 43/44 contain no matching package or
crate provider. The package therefore targets Fedora 43 and Fedora 44 on both
architectures. Rawhide is omitted because Fedora provides
`rust-unidiff-devel-0.4.0-1.fc45`, including exact
`crate(unidiff) = 0.4.0`. The generated RPMs were not installed on the host.
