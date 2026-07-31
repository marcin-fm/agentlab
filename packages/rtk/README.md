# RTK Packaging Status

RTK `0.44.1` is built from the tagged Apache-2.0 source archive with SHA-256
`735623ee670483216bc5fe7ca0885f1f1358d8f9facf22782a6ea8e8a44f3b3a`.
The source declares Rust `1.91` and retains Cargo manifests, lockfile, tests,
README, CHANGELOG, and license text.

The checked `rtk-0.44.1-source-contract.json` binds tag `v0.44.1`, commit
`36591fb00d650bf987b57483c0b3a395a35a8dc1`, the byte-identical archive and
Git tree manifest, upstream lock, Rust `1.91` floor, both Fedora patches, and
current target providers. The spec hash-checks the contract and both patches,
then applies the patches sequentially with zero fuzz.

The patches disable rusqlite's bundled SQLite feature and select Fedora's dirs
6 branch. Upstream PR #2404 is unreleased and keeps bundled SQLite as default;
no upstream dirs6 change was found. The pre-patch Cargo.lock remains source
identity only. Fedora's target registry determines the final linked graph.

Configured-SCM target builds must regenerate `LICENSE.dependencies`, confirm
the candidate aggregate, run the complete Cargo suite, prove dynamic
`libsqlite3.so.0` linkage, query the exact SQLite schema, exercise an RTK proxy
path with telemetry disabled, and complete Fedora 43, Fedora 44, and Rawhide on
both architectures. All current target flags remain false until that proof.

Historical `0.43.0-0.6` F43/F44 binaries reported RTK `0.43.0`, dynamically
required `libsqlite3.so.0`, and passed the database and isolated-home smokes.
Those results remain evidence only and are not active `0.44.1` package inputs.
