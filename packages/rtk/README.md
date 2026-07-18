# RTK Packaging Status

RTK `0.43.0` is a useful early proof package because the current `cx` container downloads its unsigned upstream RPM directly. Agentlab will instead build the tagged Apache-2.0 source release.

The spec removes `rusqlite`'s bundled SQLite feature and uses Fedora Rust macros. Fedora 43 satisfies its generated crate requirements. Fedora 44 uses source-built compatibility packages for the released `dirs` `5.0.1` and `dirs-sys` `0.4.1` crates, while retaining Fedora's versioned `rusqlite`, `libsqlite3-sys`, and system SQLite packages.

Historical Fedora 43 and Fedora 44 x86_64 clean Mock builds of `0.43.0-0.2` passed 2,287 tests with eight ignored and produced the same 114-record linked dependency inventory. The live `0.43.0-0.5` spec defines the Fedora check bcond, requests test dependencies when checks are enabled, and guards the test and SQLite runtime smokes consistently.

The runtime RPM retains the upstream Apache-2.0 `LICENSE`, the aggregate SPDX expression, and Fedora's macro-generated `LICENSE.dependencies` inventory. The former collector, copied system-provider license tree, and provider-NEVRA payload are removed; historical provider receipts remain repository-side audit evidence only.

Fedora Rust packaging intentionally resolves against packaged semver-compatible crates rather than preserving upstream `Cargo.lock` byte-for-byte. The successful builds used the offline local Cargo registry configured by `%cargo_prep`; no registry network access occurred during the RPM build.

The extracted historical F43 and F44 binaries report RTK `0.43.0`, dynamically require `libsqlite3.so.0`, and create the expected `commands` and `parse_failures` tables through `RTK_DB_PATH`. The upstream RPM recipe and binary are not used as build inputs. See `license-review.md` and `reproducibility.yml` for retained historical receipts. The current project target matrix covers `x86_64` and `aarch64` for stable Fedora and Rawhide; completion is determined from COPR results.
