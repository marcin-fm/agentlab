# rust-text-splitter0.32

## Finalization status

The package is enabled for Fedora 43, Fedora 44, and Rawhide on `x86_64` and
`aarch64` as a selected Kreuzberg compatibility dependency.

The exact crates.io archive is the complete immutable package source and
supplies its MIT license text. Upstream intentionally excludes integration
fixtures from the published crate, so Fedora retains the fixture-free library
tests and omits five unit tests that require excluded tokenizer data or
network-fetched Hugging Face models. The selected Kreuzberg feature surface is
`code,markdown,tokenizers` in every Cargo phase.

A fresh Fedora 44 x86_64 Mock build passed all 101 selected tests. Its source
and six noarch RPMs have valid digests, and artifact `rpmlint` reports zero
errors or warnings. Final configured COPR matrix results remain repository
publication evidence rather than a package-local build input.
