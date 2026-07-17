# rust-lazy-regex-proc_macros3

Compatibility package for the published `lazy-regex-proc_macros 3.4.1`
release required by `lazy-regex 3.4.1`. The proc-macro crate omits its workspace
license file, so this package restores the exact MIT text from the matching
published `lazy-regex 3.4.1` crate. Clean Fedora 43 and Fedora 44 x86_64 mock
builds passed, and the package is enabled.
The proc-macro's copied documentation examples depend on exports from the
parent `lazy-regex` crate, so `%check` runs its portable library tests only.
