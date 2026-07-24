# python-click

Fedora 43 compatibility provider for Click `8.3.3`, selected by
`python-headroom-ai 0.32.0`.

Headroom's released Python metadata requires `click >= 8.3.3`. Fedora 43
provides only Click `8.1.7`, while Fedora 44 and Rawhide already provide the
exact `8.3.3` branch. This package therefore targets only Fedora 43 on
`x86_64` and `aarch64`; it is omitted everywhere the distribution provider is
compatible.

The spec is adapted from Fedora dist-git commit
`e7bf4b0df3e26b09d5f9f25ec263a0058cf155c4`, preserves base release `1`, and
uses Agentlab revision `1.1`. It verifies the immutable upstream archive at
SHA-256 `d3757817029a666ecd2191b0f571b140177cb62f6588248fc6e97610f3356152`,
builds the noarch wheel with Fedora pyproject macros, runs the published
non-stress pytest suite, and ships the upstream BSD-3-Clause license text.

A clean Fedora 43 x86_64 Mock build with the exact Agentlab repository passed
the complete selected test suite. The resulting source and noarch binary RPMs
have zero `rpmlint` errors and zero warnings.
