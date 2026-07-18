# rust-napi-sys3

The package retains the pinned supplemental MIT license from the exact `napi-sys-v3.2.2` release commit `dea608eae7481a47d64aab563a2ab5cdd8eda03c` with SHA-256 `3f1ce66533302df3a32edbfdfc0b78f0dd34659e4c1f5817162e5ea3c2297215`.

## Finalization status

The package is enabled for Fedora 43, Fedora 44, and Rawhide on x86_64 and aarch64. Its direct static registry source avoids the crates.io API endpoint failure in isolated COPR source builders.

A fresh Fedora 44 x86_64 Mock build of release `0.4` passed dynamic dependency generation, build, install, and tests. All 15 source/binary RPMs passed digest verification and `rpmlint` with zero errors or warnings.

Configured SCM build `10740891` produced `3.2.2-0.4` successfully in all six Fedora 43, Fedora 44, and Rawhide x86_64/aarch64 cells. All 45 downloaded x86_64 source/binary RPMs passed digest verification and artifact `rpmlint` with zero errors or warnings, and RPM metadata marks `LICENSE-MIT` as `%license`.

The published archive lacks a license file because its Cargo manifest explicitly includes only `src/**/*` and `Cargo.toml`; the spec verifies and installs the immutable upstream copy.
