# python-docling-slim

Fedora source package record for `docling-slim 2.113.0`, built from the exact
MIT-licensed PyPI sdist with SHA-256
`34135ce73e82cce494483133752f54d97391351d4faa49fbf66c6058eb18329d`.

This package deliberately represents the base framework plus the
`service-client` extra required by `docling-mcp 2.1.0`. That surface uses the
source-built `python-docling-core 2.87.1` provider and Fedora HTTP, WebSocket,
configuration, and CLI libraries. It does not activate `docling-parse`,
`docling-ibm-models`, pypdfium2, local model weights, OCR, VLM, or Hugging Face
model downloads.

The upstream `docling` and `docling-tools` wrappers are not shipped in this
package. They import the pypdfium2-backed local conversion module even for
`--help`, despite that dependency being outside `service-client`. The target
MCP application imports the Python service-client API directly and does not
need these wrappers.

The service-client extra is patched accordingly: it retains `httpx` and
`websockets`, while Typer, Rich, and python-dotenv remain attached to the
unpackaged CLI surface. This also avoids forcing Fedora 44's Typer 0.25 branch
against `docling-core`, whose tested metadata requires Typer below 0.25.

The service client performs network access only when a user explicitly points
it at a Docling service. Package validation uses a local HTTP health fixture;
no external service, model, or browser is contacted. The published sdist does
not include upstream tests, so planned validation consists of installed base
and client imports plus that local health call.

Clean Fedora 43 and Fedora 44 Mock builds passed those installed smokes. Final
`rpmlint` reported zero errors and zero warnings in both chroots. The package
provides `python3dist(docling-slim[service-client]) = 2.113.0`, owns no command
wrapper under `/usr/bin`, and does not require Typer, Rich, or python-dotenv.
Produced RPMs were not installed on the host and COPR was not mutated.

The record remains blocked until clean Fedora 43 and Fedora 44 builds and final
`rpmlint` validation pass. Generated RPMs must not be installed on the host and
COPR remains unchanged during local validation.
