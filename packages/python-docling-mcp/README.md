# Docling MCP Packaging Status

`docling-mcp` `2.1.0-2` is packaged from the published MIT-licensed PyPI sdist,
not a Git snapshot or wheel. Source0 has SHA-256
`46ea64354ae6b7e5956e5f93da62b4329906766cf1f130314ace8eefb4c058c7`.

The reusable stack is complete: `python-docling-core 2.87.1`, the API-only
`python-docling-slim 2.113.0` provider, DocLang, and latex2mathml all have clean
Fedora 43 and Fedora 44 builds. The slim package does not activate
`docling-parse`, `docling-ibm-models`, pypdfium2, local models, or the upstream
CLI wrappers.

The base `python-docling-mcp` RPM remains a stdio-only generation/manipulation
server. Its default launcher and tool list are unchanged, and conversion, RAG,
HTML-table conversion, local models, HTTP, SSE, WebSocket, and experimental task
handlers remain absent.

`python3-docling-mcp-remote-conversion` is an explicit optional package with a
separate `docling-mcp-remote-conversion` stdio launcher. It ports only
single-document conversion to the exact docling-slim 2.113.0 service-client
contract. It requires an administrator-configured `DOCLING_SERVICE_URL` and
`DOCLING_SERVICE_UPLOAD_ROOT`, uses polling without WebSocket fallback, rejects
URL sources, symlinks, directories, noncanonical or out-of-root paths, and caps
both input and downloaded artifacts at 64 MiB. It does not import the upstream
converter factory or local converter and does not provide directory conversion.

Clean Fedora 43 and Fedora 44 Mock builds passed with build networking disabled
and four-job limits. `%check` proved the unchanged base defaults, then exercised
the optional launcher against an in-process fake Docling Serve: health check,
presigned-target fallback, bounded file upload, polling, inline result decoding,
cache hit, API-key confinement, failed-task handling, malformed-result handling,
configuration validation, and all path/size denials. `rpmlint` reported zero
errors in both chroots; the remaining warnings are the two missing manpages and
the optional package's lack of separate documentation payload.

The configured remote service is outside this RPM's source/model closure and is
responsible for its own parser, model, authentication, redirect, and egress
policy. Fedora's `python-mcp 1.26.0` advisories remain unreachable because both
launchers use stdio and do not enable HTTP sessions, WebSockets, or experimental
tasks. No produced RPM was installed on the host and COPR was not mutated.

Sources:

- https://pypi.org/project/docling-mcp/2.1.0/
- https://github.com/docling-project/docling-mcp/tree/v2.1.0
- https://docling-project.github.io/docling/usage/advanced_options/
