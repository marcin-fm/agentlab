# rust-napi-derive-backend5

The package retains the pinned supplemental MIT license from exact release commit `2785de583a97e49adea8194090fca2ee12f067c8` with SHA-256 `3f1ce66533302df3a32edbfdfc0b78f0dd34659e4c1f5817162e5ea3c2297215`.

## Finalization status

The package is enabled for Fedora 43, Fedora 44, and Rawhide on x86_64 and aarch64. Its direct static registry source avoids the crates.io API endpoint failure in isolated COPR source builders.

The package exposes all upstream public feature interfaces except the private implicit `semver` alias removed by the metadata repair. Both patches applied with fuzz 0 in a fresh Fedora 44 x86_64 release `0.5` Mock build, all 11 tests passed, and all seven source/binary RPMs passed digest verification and `rpmlint` with zero errors or warnings.

Its private semver metadata repair and retained ctor 0.6 compatibility patch are both registered in the spec with adjacent downstream rationale.
