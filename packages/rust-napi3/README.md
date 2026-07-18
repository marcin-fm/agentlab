# rust-napi3

The package retains the pinned supplemental MIT license from exact `napi-v3.10.3` release commit `1ac467e06e71f78b983630926c7908894d08e496` with SHA-256 `3f1ce66533302df3a32edbfdfc0b78f0dd34659e4c1f5817162e5ea3c2297215`.

## Finalization status

The package is enabled for Fedora 43, Fedora 44, and Rawhide on x86_64 and aarch64. It builds and tests Kreuzberg's selected `napi8`, `async`, and `serde-json` feature surface without default features.

A fresh Fedora 44 x86_64 Mock build passed its selected feature build and one test. All 50 source/binary RPMs passed digest verification and `rpmlint` with zero errors or warnings, and a separate offline Mock consumer compiled the selected `napi` and `napi-derive` macro surface.

Configured SCM build `10740937` produced `3.10.3-0.3` successfully in all six Fedora 43, Fedora 44, and Rawhide x86_64/aarch64 cells. All 150 downloaded x86_64 source/binary RPMs passed digest verification and artifact `rpmlint` with zero errors or warnings, and RPM metadata marks `LICENSE-MIT` as `%license`.

The Fedora patches independently select ctor 0.6.3 and omit only the WASM-specific Tokio dependency. The published crate omits its license file; the spec installs the pinned immutable upstream copy.
