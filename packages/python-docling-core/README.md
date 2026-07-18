# python-docling-core

Fedora source package record for `docling-core 2.87.1`, the MIT-licensed
document model, serializer, schema, and command-line foundation used by
Docling applications.

The exact PyPI sdist SHA-256 is
`a2c19e63519e49f993d93103481934b772db701c80c683900476f898dfac841a`.
The base package is pure Python and contains no model weights or native code.
Optional chunking, transformer, tokenizer, and example extras are excluded.

`docling-core-setuptools-backend.patch` declares the standard build backend
omitted from the published metadata. `docling-core-add-requests.patch` adds the
missing runtime declaration for `requests`; the installed `docling-view` path
imports the file resolver that uses it unconditionally. All other base runtime
dependencies are declared by upstream. `docling-core-typer-0.26.patch` widens
only the Typer upper bound to accept Fedora Rawhide's 0.26 branch; the CLI code
is unchanged. The two previously missing direct
providers, `python-doclang` and `python-latex2mathml`, are source-built package
records with clean Fedora 43 and Fedora 44 validation.

The sdist includes 31 test modules but omits the `test/data` fixture tree. The
package runs six complete self-contained test files: 29 tests passed in each
clean Fedora 43 and Fedora 44 build. Installed document creation, JSON
roundtrip, DocLang serialization, and both CLI help smokes also passed.
The same selected tests and installed smokes passed in a clean Rawhide x86_64
build with Fedora Typer 0.26.8, followed by successful docling-slim and
docling-mcp builds in the local dependency chain. Rawhide aarch64 and remote
COPR results remain pending.
`rpmlint` reports zero errors and only the two expected no-manpage warnings per
chroot. The package record is enabled; generated RPMs were not installed and
COPR was not mutated.
