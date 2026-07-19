# rust-ort2

The package remains offline, feature-pruned, and dynamically linked to system ONNX Runtime; crate `2.0.0-rc.12` maps to RPM `2.0.0~rc.12`.

Release `0.4` uses Fedora's `%cargo_generate_buildrequires`, `%cargo_build`, `%cargo_install`, and `%cargo_test` macros with the same no-default `api-18,load-dynamic,ndarray,std` feature surface throughout. The macros own Cargo's offline configuration, RPM profile, build flags, parallelism, and supported `avoid-dev-deps` handling. Tests remain library-only and skip only `operator::tests::test_custom_ops`, which requires functionality outside the selected system-library surface.

## Finalization status

The exact static crates.io source and both Fedora compatibility patches pass a
fresh Fedora 44 x86_64 Mock build against the published `rust-ort-sys`
provider. Generated dependencies preserve the prerelease
`crate(ort-sys) = 2.0.0~rc.12` edge, all artifact digests verify, and artifact
`rpmlint` reports zero errors or warnings. The package is selected for Fedora
43, Fedora 44, and Rawhide on both architectures.
