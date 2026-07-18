# rust-oem_cp1

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. Its relationship to the blocked Kreuzberg package is dependency
context, not a package-specific publication blocker. The canonical crates.io
archive is pinned by SHA-256 and fetched directly from the immutable static
registry endpoint.

Fedora 43, Fedora 44, Rawhide, and matching RPM Fusion repositories provide no
`crate(oem_cp)` package. Configured publication therefore targets Fedora 43,
Fedora 44, and Rawhide on x86_64 and aarch64.

The retained Fedora patch removes only Windows-target development dependencies
from the non-Windows crate graph. Exact-current six-cell build and artifact-lint
results are retained in the project playbook after configured SCM publication.
