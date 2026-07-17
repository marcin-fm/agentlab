# python-doclang

Fedora source package record for `doclang 0.7.3`, the Apache-2.0 reference
toolkit for the DocLang XML document format.

Source0 is the exact PyPI sdist:

`https://files.pythonhosted.org/packages/f5/3a/005e4856ad8e9b9879414a4df4dbc56dc3663b96f9d8c920ef210e8931cf/doclang-0.7.3.tar.gz`

Its SHA-256 is
`ca50615357e46ebf9597bb9065b9112367103ec24bd539f8ae12649224cf50b0`.
The source includes `LICENSE`, `doclang.xsd`, and `doclang.sch`; the spec ships
the `doclang` console script and package data through the pyproject macros.

The package is enabled for COPR automation. Fedora 43 and Fedora 44 provide
the direct runtime dependencies `lxml >= 4.8` and `typer >= 0.15.1`. Clean
Mock builds passed in both chroots, including installed-payload import, schema
presence, CLI help, and XSD-only XML validation smokes. Final `rpmlint` found
zero errors and only the expected missing-manpage warning in each chroot. The
optional Saxon-based processor extra is intentionally not packaged because it
is not required by docling-core or the default runtime.

Fedora 43 provides setuptools 78.1.1 rather than the upstream metadata floor
of 80. `doclang-fedora-setuptools.patch` lowers only that build-system floor;
DocLang uses standard PEP 621/setuptools functionality supported by the Fedora
version.

The sdist has no upstream tests. Package validation therefore covers
importability from the installed buildroot, bundled schema presence,
`doclang --help`, and a small offline XSD-only validation smoke. The missing
upstream test suite remains a known validation limitation.

Duplicate checks are recorded as absent for Fedora 43/44 and RPM Fusion 43/44.
No generated RPM was installed on the host and COPR was not mutated.
