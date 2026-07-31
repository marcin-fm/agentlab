# python-mcp

Fedora source package for released `mcp 1.28.1`, selected by the
`python-headroom-ai 0.33.0` MCP extra. Fedora 43 and Fedora 44 provide `1.26.0`,
and Rawhide provides `1.27.1`; all are below the consumer's declared
`mcp >= 1.28.1, < 2` floor.

The package adapts Fedora's existing `python-mcp` source package and preserves
its authorship. Two narrow Fedora build/test patches remain: Fedora 43 alone
uses `hatch-vcs` with a release-bound `fallback_version = "1.28.1"` because
`uv-dynamic-versioning` is unavailable there. An exact patched sdist produced
`mcp-1.28.1-py3-none-any.whl` without Git metadata through that fallback.
Fedora 44 and Rawhide retain upstream's backend; a test subprocess receives the
buildroot `PYTHONPATH` on every target. Upstream's intentional pytest xdist
configuration is retained by adding the Fedora provider. The former PyJWT-floor
relaxation is not retained; Fedora 43 instead receives the selected source-built
`python-jwt 2.13.0` compatibility package.

RPM Fusion Free and Nonfree release/update metadata for Fedora 43, Fedora 44,
and Rawhide on x86_64/aarch64 was checked on 2026-07-30; no MCP SDK package or
`python3dist(mcp)` provider is present there.

## MCP 2.0.0 boundary

The released `mcp 2.0.0` candidate is intentionally not selected. Headroom
`0.33.0` from `chopratejas/headroom` declares `mcp >=1.28.1, <2.0.0`, and its
upstream guard reports a startup failure because MCP 2 removed the low-level `Server`
`list_tools()` and `call_tool()` decorators. Headroom uses those decorators in
both its compression and memory MCP servers and also depends on legacy request
context. Its existing `StreamableHTTPSessionManager(app=server.server)`
construction is not removed by MCP 2, but a handler migration still requires
session-lifecycle and HTTP regression validation.

MCP 2 additionally changes the protocol handshake and removes server-initiated
requests. Server-to-client notifications and Streamable HTTP streaming remain.
It also removes WebSocket transport, replaces `httpx`/`httpx-sse` with
`httpx2`, and splits the wire models into the exact-version `mcp-types`
distribution. Both MCP distributions remain MIT, but `mcp-types` would require
separate Fedora source and license accounting. A coherent upgrade therefore
requires an upstream Headroom migration rather than a downstream
dependency-bound edit.

`mcp-2.0.0-compatibility.yml` binds the exact released sources, API call sites,
dependency delta, protocol boundary, license result, and fail-closed decision.
Dependency-provider availability was not evaluated after the released consumer
API and declared `<2` boundary had already rejected the migration.
