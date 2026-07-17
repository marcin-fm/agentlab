# Headroom AI Packaging Status

`python-headroom-ai` packages the latest released source-verifiable Headroom
version, `0.31.0`, from the Apache-2.0 PyPI sdist with SHA-256
`a13f9764be168e4d075fd80ff6ee5d47a9febe0152b82ad28bab0e949fcd9bd3`.
The configured local `0.32.0` installation came from `file:///tmp/headroom` and
has no release artifact, so it is intentionally not used.

The prior validated `0.31.0-0.1` package built the Rust/PyO3 `headroom._core`
extension through a downstream `mcp-minimal` feature graph and exposed the
stdio tools `headroom_compress`, `headroom_retrieve`, and `headroom_stats`.
Updated project policy classifies that custom feature graph and its companion
patches as substantive downstream product work. Release `0.31.0-0.3` is
therefore an unbuilt, blocked draft: it must not be rebuilt, enabled, or
published until an upstream-supported feature selection replaces the custom
surface or the maintainer explicitly approves it.

Historical Fedora 43 and Fedora 44 `0.31.0-0.1` builds passed 836 library tests,
seven CCR backend tests, two reduced tokenizer property tests, the packaged
three-tool stdio smoke, and `rpmlint` with zero errors. Those receipts do not
validate the `0.3` draft. Exact Rust tokenization and the compatibility drafts
`rust-fancy-regex0.17` and `rust-tiktoken-rs0.11` remain dependent-scope audit
evidence only. A future binary also needs aggregate SPDX accounting for its
statically linked Rust closure.

The Fedora MCP 1.26 dependency is accepted only through the reviewed stdio,
no-task, no-WebSocket boundary recorded in `mcp-1.26-stdio-security-review.md`.
The separately installed `headroom-opencode` plugin remains unreleased and is
not part of this package. No produced RPM was installed and COPR was not mutated.
