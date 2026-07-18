# rust-phf_generator0.14

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. Its relationship to the blocked Kreuzberg package is dependency
context, not a package-specific publication blocker. The canonical crates.io
archive is pinned by SHA-256 and fetched directly from the immutable static
registry endpoint.

Fedora 43 provides `phf_generator` 0.11 and 0.13, while Fedora 44 and Rawhide
provide 0.13. None satisfies Kreuzberg's exact `crate(phf_generator) = 0.14.0`
requirement, and matching RPM Fusion repositories provide no compatible
package. Configured publication therefore targets Fedora 43, Fedora 44, and
Rawhide on x86_64 and aarch64.

The retained Fedora patch removes only the benchmark target and its
Criterion-only development dependency; the crate remains production-required.
Exact-current six-cell build and artifact-lint results are retained in the
project playbook after configured SCM publication.
