# python-jwt

Fedora 43 compatibility package for released `PyJWT 2.13.0`. It is selected
only because `python-mcp 1.28.1` requires `PyJWT[crypto] >= 2.10.1`, while the
Fedora 43 provider is `2.8.0`. Fedora 44 and Rawhide already provide satisfying
versions, so this package intentionally targets only Fedora 43 on both
architectures.

The package follows Fedora Rawhide's current source-built noarch package shape,
uses the immutable PyPI sdist, verifies SHA-256 in `%prep`, creates the standard
`python3-jwt` package and `crypto` extras metapackage, and retains Fedora's
current test selection. No upstream binary artifact is used.

RPM Fusion Free and Nonfree release/update metadata for Fedora 43, Fedora 44,
and Rawhide on x86_64/aarch64 was checked on 2026-07-30; no PyJWT package or
`python3dist(pyjwt)` provider is present there.
