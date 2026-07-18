# rust-ort2

The package remains offline, feature-pruned, and dynamically linked to system ONNX Runtime; crate `2.0.0-rc.12` maps to RPM `2.0.0~rc.12`.

Release `0.3` uses Fedora's `%cargo_generate_buildrequires`, `%cargo_build`, `%cargo_install`, and `%cargo_test` macros with the same no-default `api-18,load-dynamic,ndarray,std` feature surface throughout. The macros own Cargo's offline configuration, RPM profile, build flags, parallelism, and supported `avoid-dev-deps` handling. Tests remain library-only and skip only `operator::tests::test_custom_ops`, which requires functionality outside the selected system-library surface.

## Finalization status

The package remains `blocked` with COPR disabled. Retained F43/F44 x86_64 artifact evidence is summarized in `../kreuzberg/dependency-finalization.yml`. This macro-normalization pass provides static validation rather than a new clean build or `rpmlint` result.

Curated final direct-v3 package for `ort 2.0.0-rc.12`, built against Fedora's
system ONNX Runtime feature surface. The spec and patches are the finalized
inputs; direct-v3-ort contains the successful F44 result staging. Blocked
pending source hosting and dependency review.
