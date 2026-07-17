# python-latex2mathml

Fedora source package record for `latex2mathml 3.81.0`, a pure Python LaTeX
math expression to MathML converter and reusable dependency of docling-core.

The exact PyPI sdist SHA-256 is
`4b959cdc3cac8686bc0e3e5aece8127dfb1b81ca1241bed8e00ef31b82bb4022`.
The sdist omits both the project license and upstream tests. The package uses
the MIT license from exact release commit
`605e02726eca5a77bb07395631fde9e0acacdbab`, SHA-256
`4ac1e1da07f6b343d54191c5e1716840534e08591b3f9eaec90d6800cdc47543`.

The required `unimathsymbols.txt` runtime mapping is separately licensed under
LPPL version 1.3 or later. The package selects LPPL 1.3c and ships its canonical
license text, so the aggregate expression is `MIT AND LPPL-1.3c`.

Upstream builds with `uv_build >= 0.10.11, < 0.11.0`. Fedora 43 has no provider
in that range. `latex2mathml-use-hatchling.patch` substitutes hatchling for the
standard root-package wheel without changing runtime source or payload.

The hatchling substitution clean-built on Fedora 43 and Fedora 44. Installed
payload checks passed library conversion, the LPPL data notice, version output,
and conversion through the `l2m` symlink. Final `rpmlint` found zero errors and
only the two expected missing-manpage warnings per chroot. The package is
enabled for COPR automation; no generated RPM was installed and COPR was not
mutated. The sdist has no upstream tests, which remains a validation limit.
