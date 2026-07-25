# Serena Agent Packaging Status

`serena-agent` `1.6.1` is retained as a blocked source-package draft from the
released PyPI sdist. Tag `v1.6.1` is commit
`bcac0969fb8685783ea6d0f2642468fcc47e6395`.

The former `serena-headless-fedora.patch` and `serena-stdio-only-fedora.patch`
were removed because they changed upstream product and security behavior rather
than adapting Serena to Fedora. Upstream supports headless flags, stdio launch,
environment-disabled telemetry, and explicit local language-server commands,
but the installed application still exposes dashboard/GUI, JetBrains,
project-server/query, non-stdio transport, token-estimator, and managed
acquisition surfaces.

The spec therefore verifies the exact `1.6.1` source and fails closed before
unpacking or building. `serena-python-3.15.patch` remains only as narrow future
Rawhide compatibility evidence; upstream still declares Python `< 3.15`.

Re-enable the package only when an upstream-supported selected surface and its
complete Fedora dependency graph are proven, or after explicit maintainer
approval of a downstream product profile. The historical MCP audits describe
the removed `1.6.0` bounded profile and are not current publication evidence.
