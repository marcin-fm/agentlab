# rust-napi-derive3

The package retains the pinned supplemental MIT license from exact `napi-derive-v3.5.9` release commit `2785de583a97e49adea8194090fca2ee12f067c8` with SHA-256 `3f1ce66533302df3a32edbfdfc0b78f0dd34659e4c1f5817162e5ea3c2297215`.

## Finalization status

The package is enabled for Fedora 43, Fedora 44, and Rawhide on x86_64 and aarch64. It builds and tests the `strict` and `type-def` surface used by the selected N-API chain.

A fresh Fedora 44 x86_64 Mock build completed with no runnable unit tests and two upstream-ignored doctests. All 10 source/binary RPMs passed digest verification and `rpmlint` with zero errors or warnings, and a separate offline Mock consumer compiled emitted module registration tokens with Fedora ctor 0.6.3.

The Fedora patch changes only ctor dependency metadata and generated registration syntax for ctor 0.6.3. The published crate omits its license file; the spec installs the pinned immutable upstream copy.
