# MCP 1.28.1 API Audit

Serena 1.6.0 uses internal FastMCP APIs, so the security-fixed MCP floor was
checked directly against the published `mcp 1.28.1` source distribution.

- Source: `https://files.pythonhosted.org/packages/6e/77/9450b8f251a13affb6281997d0523c4615f8a8b35d0b21ff30db3a5aac9d/mcp-1.28.1.tar.gz`
- SHA-256: `d51e36a5f5644faea4f85ea649bfffa6bc6c26770d42798ad6a3de3d2ba69683`
- Result: Serena's current adapter is structurally compatible with MCP 1.28.1.

The audited MCP source retains:

- `mcp.server.fastmcp.server.FastMCP`, `Context`, and `Settings`.
- `FastMCP._tool_manager`, initialized as `ToolManager`.
- `ToolManager._tools` as `dict[str, Tool]`.
- The `Tool` model fields and `run(arguments, context, convert_result)` method
  used by `SerenaFastMCPTool`.
- `ServerSessionT`, `LifespanContextT`, `RequestT`, and `ToolAnnotations` at the
  import paths used by Serena.

This is a static source-interface audit, not a runtime or build claim. The
package remains blocked until Fedora provides a security-fixed MCP provider and
the reduced Serena package passes an offline stdio initialize/tools-list smoke.
