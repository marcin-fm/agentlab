# python-docling-core

Fedora source package record for `docling-core 2.88.0`, the MIT-licensed
document model, serializer, schema, and command-line foundation used by
Docling applications.

The exact PyPI sdist SHA-256 is
`ffc67cb863f6f93a875dfcc3dd3ac109fff68abcadcb4c951036fae777d82796`.
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

The sdist omits the complete fixture tree, so the package runs six complete
self-contained test files plus installed document creation, JSON roundtrip,
DocLang serialization, and both CLI help smokes. Current Fedora 43, Fedora 44,
and Rawhide results on both architectures are required for this release and
are tracked in COPR and the Agentlab wiki rather than embedded as package
inputs. The package record is enabled; generated RPMs are never installed on
the host.
