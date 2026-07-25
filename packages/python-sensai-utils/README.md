# python-sensai-utils

Fedora source package for `sensai-utils 1.6.0`, a reusable dependency of the
Serena MCP server.

The published `1.6.0` sdist omits the `requirements.txt` read by `setup.py`. Its
immutable `PKG-INFO` records exactly one runtime requirement,
`typing-extensions>=4.6`; the package patch substitutes that value directly and
does not add or vendor dependencies.

Upstream `1.6.0` adds optional file-logging configuration and exception logging
without removing APIs or changing the dependency graph. The exact PyPI sdist is
SHA-256 `e50ae6bbd7c62a961f25b98e55b29029450efd66444678931b3b9c43e9bf9e95`.

A clean Fedora 44 x86_64 Mock build with the exact Agentlab repository passed
all 16 published import cases. Source RPM SHA-256 is
`93ef7586f9176a434cd38946f2a61a8dc07dea1c39e2f1e7829056a521755147`;
noarch RPM SHA-256 is
`e8f000a92c9a944e790bae1bbbefc92c9427347d2e195012c9c5117c4a3b0827`.
Both have zero `rpmlint` errors and warnings. The complete configured COPR
matrix remains pending for release `0.1`.
