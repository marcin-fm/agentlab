# rust-ort-sys

## Finalization status

The package is enabled for the Fedora 43, Fedora 44, and Rawhide target matrix.

The exact static crates.io `ort-sys 2.0.0-rc.12` source maps to RPM
`2.0.0~rc.12`. The package selects only `api-18,std`, disables Cargo
networking and upstream runtime downloads, and links against Fedora's system
`libonnxruntime` from `/usr/lib64`.

A clean Fedora 44 x86_64 Mock build linked with `-l onnxruntime`, completed
the crate tests and doctests, and produced six digest-valid artifacts.
Artifact `rpmlint` reports zero errors and only the non-fatal source-crate
`no-documentation` warning.
