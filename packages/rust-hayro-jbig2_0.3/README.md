# rust-hayro-jbig2_0.3

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256 and includes
the declared MIT and Apache-2.0 license files.

No exact `hayro-jbig2 0.3.0` provider exists in Fedora 43, Fedora 44, Rawhide,
or matching RPM Fusion repositories. Agentlab supplies `hayro-ccitt 0.3`, and
Fedora supplies `image 0.25` plus the selected test dependencies. The
Fedora-only patches omit benchmark/progress metadata and unavailable
`fearless_simd` acceleration while retaining the scalar `std`/`image` default
decoder used by Kreuzberg.
