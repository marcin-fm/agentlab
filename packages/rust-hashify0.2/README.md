# rust-hashify0.2

## Publication status

The package is independently eligible and enabled for configured SCM COPR
publication. The canonical crates.io archive is pinned by SHA-256, fetched
directly from the immutable static registry endpoint, and includes both
declared project license texts.

The direct static endpoint is required because crates.io's API download route
returned HTTP 403 in COPR's isolated source builder before SRPM creation.

No exact `hashify 0.2.9` provider exists in Fedora 43, Fedora 44, Rawhide, or
matching RPM Fusion repositories. Fedora supplies every retained build and test
dependency. The metadata-only patch removes the benchmark target and its
Criterion dependency while retaining the full library and integration tests.
