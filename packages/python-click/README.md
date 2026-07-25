# python-click

Fedora 43 compatibility provider for Click `8.4.2`, selected by
`python-headroom-ai 0.32.1`.

Headroom's released Python metadata requires `click >= 8.3.3`. Fedora 43
provides only Click `8.1.7`, while Fedora 44 and Rawhide already provide the
compatible `8.3.3` branch. This package therefore targets only Fedora 43 on
`x86_64` and `aarch64`; it is omitted everywhere the distribution provider is
compatible.

The spec is adapted from Fedora dist-git commit
`e7bf4b0df3e26b09d5f9f25ec263a0058cf155c4` and advances to upstream `8.4.2`
as Agentlab release `0.1`. It verifies the immutable upstream archive at
SHA-256 `d5635f9b7999806a02bd323fc7a9f8c4b1cb5f600b2967d4e7e5dbb106b1c216`,
builds the noarch wheel with Fedora pyproject macros, runs the published
non-stress pytest suite, and ships the upstream BSD-3-Clause license text.

A clean Fedora 43 x86_64 Mock build with the exact Agentlab repository passes
all import checks and 1,661 selected tests. Source RPM SHA-256 is
`82f0860082a590937bac18ceb3d9cbb0a2f376712a234e676d8c32420bd062bb`;
noarch RPM SHA-256 is
`8579b91ccb3ae56917f24fbcebb043d7be6bb810aa428d76486dd90fc31ebfa3`.
Both have zero `rpmlint` errors and warnings. The two-cell configured-SCM proof
remains pending.
