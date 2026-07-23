# rust-fearless_simd

Fedora 43 lacks the `fearless_simd 0.4` crate capabilities required by
`hayro-jpeg2000 0.3.5`. Fedora 44 and Rawhide already provide the exact 0.4.1
branch, so Agentlab builds this Fedora-derived compatibility package only for
Fedora 43 on x86_64 and aarch64.

The spec preserves Fedora commit
`ae60d4a5155027e05cc9125dc47fc609e31e5917`, including the metadata-only
license normalization and removal of unused or unpackaged test dependencies.
Fedora 43 already provides the remaining selected Hayro dependencies.
