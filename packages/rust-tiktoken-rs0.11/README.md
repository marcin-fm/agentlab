# rust-tiktoken-rs0.11

Compatibility package for the released MIT `tiktoken-rs 0.11.0` crate required
by Headroom 0.32.0. The published crate contains the fixed tokenizer assets but
omits its project license file; the package restores the exact tag license and
the MIT license for its vendored OpenAI tokenizer code. Optional API-client and
heap-profiler features remain unbuilt. The package is enabled for Fedora 43,
Fedora 44, and Rawhide on `x86_64` and `aarch64`. The default-feature build
retains all unit tests and skips only the README example requiring the optional
`async-openai` feature. Live build and artifact results are retained in the
project playbook.
