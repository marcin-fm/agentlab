# Headroom AI Packaging Status

`python-headroom-ai` packages the latest released source-verifiable Headroom
version, `0.31.0`, from the Apache-2.0 PyPI sdist with SHA-256
`a13f9764be168e4d075fd80ff6ee5d47a9febe0152b82ad28bab0e949fcd9bd3`.
The configured local `0.32.0` installation came from `file:///tmp/headroom` and
has no release artifact, so it is intentionally not used.

The Fedora package builds the upstream Rust/PyO3 `headroom._core` extension but
selects a bounded `mcp-minimal` feature surface. It retains native compression,
local tokenizer loading, and the stdio MCP tools `headroom_compress`,
`headroom_retrieve`, and `headroom_stats`. It disables proxy/provider commands,
update checks, the optional file-read tool, runtime Hugging Face acquisition,
fastembed, Magika, ORT, Redis, Rust tiktoken, and bundled SQLite. The Rust core
uses system SQLite and the separately packaged `rust-unidiff0.4` provider.

Clean Fedora 43 and Fedora 44 builds passed 836 library tests, seven CCR backend
tests, and two reduced tokenizer property tests per chroot; one upstream library
test remained ignored. A real packaged stdio MCP session initialized, listed
exactly the three bounded tools, compressed a repeated JSON payload, restored the
byte-identical original from local memory, returned a local miss for an unknown
hash, and reported statistics. `rpmlint` reported zero errors and one expected
no-manual-page warning per chroot.

The Fedora MCP 1.26 dependency is accepted only through the reviewed stdio,
no-task, no-WebSocket boundary recorded in `mcp-1.26-stdio-security-review.md`.
The separately installed `headroom-opencode` plugin remains unreleased and is
not part of this package. No produced RPM was installed and COPR was not mutated.
