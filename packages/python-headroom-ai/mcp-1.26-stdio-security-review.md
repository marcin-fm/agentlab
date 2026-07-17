# MCP 1.26 Stdio Security Review

The Fedora 43 and Fedora 44 package uses `python-mcp 1.26.0` only through the
patched `headroom mcp serve` entry point. That entry point creates a local
`HeadroomMCPServer` with proxy checks disabled and runs MCP over standard input
and standard output. The packaged CLI registers no HTTP, SSE, WebSocket, proxy,
provider, update, or model command.

The reviewed MCP advisories are outside this enforced boundary:

- CVE-2026-52869 affects stateful SSE and streamable-HTTP session ownership.
  The packaged Headroom command exposes neither transport nor an authenticated
  multi-client session manager.
- CVE-2026-52870 requires opt-in low-level task handlers installed through
  `server.experimental.enable_tasks()`. Headroom does not enable them.
- CVE-2026-59950 affects the deprecated ASGI WebSocket server. The packaged
  command creates no WebSocket or network listener.

The package patch also removes update checks, disables proxy fallback for
compression, retrieval, and statistics, hard-disables `headroom_read`, and
removes native model/download branches. `%check` launches the packaged command,
initializes an MCP client, requires an exact three-tool list, and exercises local
compression, byte-identical retrieval, local missing-hash handling, and
statistics. Any future transport, task, proxy, or tool expansion requires a new
security review.
