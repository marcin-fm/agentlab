# rust-lopdf0.44

## Finalization status

The package is enabled for Fedora 43, Fedora 44, and Rawhide on `x86_64` and
`aarch64` as a selected Kreuzberg dependency.

The exact crates.io `0.44.0` release supplies the library and MIT text. Kreuzberg
selects only `chrono,rayon`; the package validates the full upstream default
tuple `chrono,jiff,rayon,time`, omits the excluded upstream asset tree and its
duplicate PDF, and runs eleven asset-free integration targets. The public
`time` feature uses the exact upstream fix plus a three-line Fedora
format-description compatibility adjustment. A fresh Fedora 44 `x86_64` Mock
build passed all 79 selected tests; all 14 artifacts passed digest verification
and `rpmlint` without package-content findings.
