# MCP 1.26 Stdio Security Review

`python-serena-agent 1.6.0-1` uses Fedora's `python-mcp 1.26.0` only through a
patched local stdio server. The packaged command rejects SSE and streamable
HTTP, rejects the Flask project server and dashboard viewer, and does not
enable MCP experimental task handlers.

## Reviewed Advisories

- CVE-2026-52869 / GHSA-jpw9-pfvf-9f58 affects authenticated stateful SSE and
  streamable-HTTP session ownership. Stdio and stateless/no-auth servers are
  outside the advisory's affected mechanism. This package creates no HTTP
  session manager or listener.
- CVE-2026-52870 / GHSA-hvrp-rf83-w775 affects opt-in low-level task handlers
  installed by `server.experimental.enable_tasks()`. Serena does not call that
  API, and this package exposes one local stdio client connection.
- CVE-2026-59950 / GHSA-vj7q-gjh5-988w affects the deprecated explicitly wired
  ASGI WebSocket server. Serena's patched command has no WebSocket transport
  and opens no network listener.

## Enforced Boundary

The Fedora patches restrict both the CLI and `SerenaMCPFactory` to stdio,
disable dashboard, GUI, JetBrains, telemetry, and project-server paths, remove
the dashboard and cross-project query tools, reject project-level JetBrains
overrides, and fail before managed language-server downloads or package-manager
execution. Explicit system `ls_path` and `ls_base_cmd` values remain supported.

`%check` launches the packaged executable through MCP's stdio client,
initializes a session, lists tools, verifies `get_current_config` is present,
and verifies `open_dashboard` and `query_project` are absent. It also checks the
download-denial, project-backend, and explicit-system-language-server
boundaries.

The Fedora MCP provider still contains the advisory-affected modules for other
applications. This review accepts only their non-reachability through this
RPM's enforced entry point. Any future HTTP, SSE, WebSocket, experimental task,
dashboard, project-server, or plugin surface invalidates this conclusion.
