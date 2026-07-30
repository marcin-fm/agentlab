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
