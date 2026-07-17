# Serena Agent Packaging Status

`serena-agent` `1.6.0` is packaged as Serena's headless stdio MCP server. It
uses the released PyPI sdist, verified by the SHA-256 recorded in the spec and
manifest; it does not package the moving Git source used by the current
OpenCode MCP configuration.

The current configuration launches Serena through the unpinned source
`uvx --from git+https://github.com/oraios/serena serena start-mcp-server`. That
command is not reproducible: both its Git revision and resolved Python closure
can change between invocations.

The package has a completed, zero-fuzz reduction patch for the actual
headless stdio MCP/LSP surface: requests, overrides, MCP, sensai-utils,
Pydantic, YAML support, templates, path matching, process support, MCP
docstrings, text helpers, progress output, HTML parsing, and command parsing.
`python-sensai-utils`, `python-overrides`, `python-mslex`, and `python-oslex`
are now separately packaged and clean-built on Fedora 43 and 44. GUI/tray/
webview, AI and tiktoken token estimators, MSL's pygls/lsprotocol
implementation, type stubs, redundant dotenv, Windows pythonnet, and direct
transitive security pins are removed.

Serena's private FastMCP adapter was checked against the exact published MCP
1.28.1 source. `FastMCP._tool_manager`, `ToolManager._tools`, the custom `Tool`
construction surface, and all imported context/type symbols remain present.
See `mcp-1.28.1-api-audit.md`.

Fedora's `mcp` 1.26.0 is accepted only through the package's enforced local
stdio/no-task boundary. The HTTP-session, opt-in task, and deprecated WebSocket
advisories are not reachable through this entry point; see
`mcp-1.26-stdio-security-review.md`. The provider remains affected for other
applications, and any expansion of Serena's transport surface invalidates this
decision.

Clean Fedora 43 and 44 Mock builds passed. The packaged executable completed
MCP `initialize` and `tools/list` over stdio in both chroots; dashboard and
cross-project query tools were absent. `rpmlint` reported zero errors and only
the three expected no-manual-page warnings for the installed commands.

This package is forcibly headless: its MCP path rejects dashboard, GUI log
window, and JetBrains requests, even when an existing configuration enables
them, and forces the LSP backend. `--open-web-dashboard False` remains
accepted. Usage telemetry is disabled. Serena-managed language-server archive,
npm, `uvx`/`uv`, and direct urllib acquisition fails before network or
subprocess use; explicit local `ls_path` and `ls_base_cmd` remain supported.

`%check` compiles the patched Python, asserts the default MCP configuration is
headless/LSP, verifies managed downloads fail before side effects, verifies an
explicit `ls_path` remains accepted, then launches the packaged executable and
performs MCP `initialize` and `tools/list` over stdio.

The generated RPMs were not installed on the host and COPR was not mutated.
