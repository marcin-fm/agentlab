# rust-tiktoken-rs0.11

Compatibility package for the released MIT `tiktoken-rs 0.11.0` crate required
by Headroom 0.31.0. The published crate contains the fixed tokenizer assets but
omits its project license file; the package restores the exact tag license and
the MIT license for its vendored OpenAI tokenizer code. Optional API-client and
heap-profiler features remain unbuilt. The draft remains blocked pending clean
offline Fedora 43/44 builds, token tests, rpmlint, and artifact receipts.
