# Docling MCP Packaging Status

`docling-mcp` `2.1.0-0.4` is retained as a blocked source-package draft from the
published MIT-licensed PyPI sdist. Tag `v2.1.0` is commit
`59f793b1288e8e359778ab9a1230e86a7ffc10ec`; Source0 has SHA-256
`46ea64354ae6b7e5956e5f93da62b4329906766cf1f130314ace8eefb4c058c7`.

The former generation-only stdio patch changed upstream dependencies, tool
groups, prompts, transports, and registration behavior. The former remote
conversion patch added a new server, launcher, settings model, and conversion
tool. Both were removed because they were downstream product and security
profiles rather than Fedora packaging adaptations.

Upstream supports `--transport stdio` and explicit `generation manipulation`
arguments, but the installed application still defaults to conversion plus
streamable HTTP and retains the broader released transport and tool surface.
No released or pending upstream replacement provides the selected bounded
package profile.

The spec therefore verifies the exact source and fails closed before unpacking
or building. Re-enable only after an upstream-supported selected surface and its
complete Fedora dependency and transport graph are proven, or after explicit
maintainer approval of a downstream product profile.
