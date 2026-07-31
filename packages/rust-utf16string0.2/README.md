# rust-utf16string0.2

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. Its relationship to the blocked Kreuzberg PDFium-render path is
dependency context, not a package-specific publication blocker. The canonical
crates.io archive is pinned by SHA-256, and Fedora 43, Fedora 44, Rawhide, and
matching RPM Fusion repositories provide no `crate(utf16string)` package.
Configured SCM publication targets Fedora 43, Fedora 44, and Rawhide on x86_64
and aarch64, matching Kreuzberg's intended publication scope.

Release `0.6` binds a static validation contract instead of embedding transient
COPR result identities. The contract requires the immutable `static.crates.io`
source with its pinned SHA-256, the standard Fedora Cargo build/install/test
flow, both upstream license texts, zero `rpmlint` errors or warnings, and the
full Fedora 43, Fedora 44, and Rawhide matrix on x86_64 and aarch64. Live and
historical build results remain in the project playbook and COPR rather than
active package inputs.
