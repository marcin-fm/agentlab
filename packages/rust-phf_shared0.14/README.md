# rust-phf_shared0.14

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. It is the immediate production dependency required by
`rust-phf_generator0.14`; build `10740346` produced that package's exact SRPM
in all six targets before dynamic BuildRequires failed on the absent
`crate(phf_shared) = 0.14.0` provider.

The canonical crates.io archive is pinned by SHA-256 and fetched directly from
the immutable static registry endpoint. Fedora 43 provides `phf_shared` 0.11
and 0.13, while Fedora 44 and Rawhide provide 0.13. None satisfies the exact
0.14 requirement, and matching RPM Fusion repositories provide no compatible
package. Configured publication therefore targets Fedora 43, Fedora 44, and
Rawhide on x86_64 and aarch64.

Exact-current six-cell build and artifact-lint results are retained in the
project playbook after configured SCM publication.
