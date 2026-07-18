# rust-phf_macros0.14

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. Its relationship to the blocked Kreuzberg package is dependency
context, not a package-specific publication blocker. The canonical crates.io
archive is pinned by SHA-256 and fetched directly from the immutable static
registry endpoint.

Fedora 43 provides `phf_macros` 0.11 and 0.13, while Fedora 44 and Rawhide
provide 0.13. None satisfies Kreuzberg's exact `crate(phf_macros) = 0.14.0`
requirement, and matching RPM Fusion repositories provide no compatible
package. Configured publication therefore targets Fedora 43, Fedora 44, and
Rawhide on x86_64 and aarch64.

The crate requires `phf_generator` 0.14.0 and `phf_shared` 0.14. Their exact
providers succeeded in all six configured chroots as builds `10740368` and
`10740364`, respectively. Exact-current six-cell build and artifact-lint
results for this package are retained in the project playbook after configured
SCM publication.
