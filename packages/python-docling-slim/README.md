# python-docling-slim

Fedora source package record for `docling-slim 2.115.0`, built from the exact
MIT-licensed PyPI sdist with SHA-256
`4440eb2118e64e14df45eabf5f927a01eda2c37dcaa50435a708e31c19f8b7f3`.

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

Upstream commit `9b51f4f857176cdd95cef53e2ec7f5f32ffbc6a5` is backported
unchanged so the optional SciPy import remains inside the video scene-change
execution path. Base and service-client imports therefore do not activate the
excluded video extra.

The service client performs network access only when a user explicitly points
it at a Docling service. Package validation uses a local HTTP health fixture;
no external service, model, or browser is contacted. The published sdist does
not include upstream tests, so validation covers installed base and client
imports, the expanded batch-request API exports, and the local health call.

The package provides `python3dist(docling-slim[service-client]) = 2.115.0`,
owns no command wrapper under `/usr/bin`, and does not require Typer, Rich, or
python-dotenv. Current validation and COPR matrix results are recorded in
`package.yml` and the Agentlab playbook. Generated RPMs are never installed on
the host.
