# RTK Packaging Status

RTK `0.43.0` is a useful early proof package because the current `cx` container downloads its unsigned upstream RPM directly. Agentlab will instead build the tagged Apache-2.0 source release.

The spec removes `rusqlite`'s bundled SQLite feature and uses Fedora Rust macros. Release `0.6` carries a separate Fedora dependency patch from upstream's `dirs` `5` declaration to Fedora's common `dirs` `6.0.0` and `dirs-sys` `0.5.0` branches. The complete configured COPR matrix is required before retiring the existing compatibility packages.

The fresh Fedora 44 x86_64 Mock build of `0.43.0-0.6` resolves Fedora's `dirs 6.0.0` and `dirs-sys 0.5.0`, passes 2,245 tests with eight ignored, and produces a 114-record linked dependency inventory. The spec defines the Fedora check bcond, requests test dependencies when checks are enabled, and guards the test and SQLite runtime smokes consistently. The extracted RPM also passes a global Codex initialization dry-run under an isolated home directory.

The runtime RPM retains the upstream Apache-2.0 `LICENSE`, the aggregate SPDX expression, and Fedora's macro-generated `LICENSE.dependencies` inventory. The former collector, copied system-provider license tree, and provider-NEVRA payload are removed; historical provider receipts remain repository-side audit evidence only.

Fedora Rust packaging intentionally resolves against packaged semver-compatible crates rather than preserving upstream `Cargo.lock` byte-for-byte. The successful builds used the offline local Cargo registry configured by `%cargo_prep`; no registry network access occurred during the RPM build.

The extracted historical F43 and F44 binaries report RTK `0.43.0`, dynamically require `libsqlite3.so.0`, and create the expected `commands` and `parse_failures` tables through `RTK_DB_PATH`. The upstream RPM recipe and binary are not used as build inputs. See `license-review.md` and `reproducibility.yml` for retained historical receipts. The current project target matrix covers `x86_64` and `aarch64` for stable Fedora and Rawhide; completion is determined from COPR results.
