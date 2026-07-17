# MCP 1.26 Stdio Security Review

`python-docling-mcp 2.1.0-0.2` uses Fedora's `python-mcp 1.26.0` only through
patched local stdio servers. The base launcher defaults to generation and
manipulation. The separately installed remote-conversion launcher adds one
bounded conversion tool, but still cannot select HTTP, SSE, WebSocket, RAG, or
experimental task-handler surfaces.

## Reviewed Advisories

- CVE-2026-52869 / GHSA-jpw9-pfvf-9f58 affects authenticated stateful SSE and
  streamable-HTTP session ownership. Stdio and stateless/no-auth servers are
  outside the advisory's affected mechanism. This RPM creates no HTTP session
  manager or listener.
- CVE-2026-52870 / GHSA-hvrp-rf83-w775 affects opt-in low-level task handlers
  installed by `server.experimental.enable_tasks()`. Docling MCP does not call
  that API, and the package exposes one local stdio client connection.
- CVE-2026-59950 / GHSA-vj7q-gjh5-988w affects the deprecated explicitly wired
  ASGI WebSocket server, which accepted connections before Host/Origin checks.
  The patched FastMCP server runs through stdin/stdout and opens no socket.

## Enforced Boundary

The base patch restricts the transport enum and startup path to stdio, keeps the
default generation/manipulation groups, removes upstream conversion/RAG prompts
and transports, and unregisters the HTML-table helper that imports the local
converter. The optional launcher explicitly adds a new remote-only tool module;
it does not restore the upstream converter factory, local fallback, directory
conversion, prompts, URL-source submission, or model/parser branches.

Remote conversion requires an explicit service URL and upload root. It accepts
only non-symlink regular files beneath that root, reads the validated descriptor
into bounded memory before network submission, caps input and artifact payloads
at 64 MiB, uses polling without WebSocket fallback, and confines the API key to
the configured service client. The administrator-operated service and its own
parser, models, redirect handling, and egress policy remain outside this RPM's
security and source closure.

`%check` initializes both packaged stdio launchers. It verifies the base tool
list and generation call, then exercises remote health, upload, polling, inline
result, cache, API-key, failure, malformed-result, configuration, path, and size
behavior against an in-process loopback service.

The Fedora MCP provider still contains the advisory-affected modules for other
applications. This review accepts only their non-reachability through this
RPM's enforced entry points. Any future HTTP, SSE, WebSocket, task, plugin,
additional conversion source, or broader filesystem surface invalidates this
conclusion and must block publication until reviewed again.
