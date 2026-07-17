# python-sensai-utils

Fedora source package for `sensai-utils 1.5.0`, a reusable dependency of the
Serena MCP server.

The published sdist omits the `requirements.txt` read by `setup.py`. Its
immutable `PKG-INFO` records exactly one runtime requirement,
`typing-extensions>=4.6`; the package patch substitutes that value directly and
does not add or vendor dependencies.

Clean Fedora 43 and Fedora 44 Mock builds passed all 16 published import cases.
The source and binary RPMs pass `rpmlint` with zero errors and zero warnings.
The package is enabled for the complete configured COPR target matrix.
