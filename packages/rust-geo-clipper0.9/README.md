# rust-geo-clipper0.9

## Finalization status

The package is enabled for the Fedora 43, Fedora 44, and Rawhide target matrix.

The package uses the exact ISC-licensed crates.io `geo-clipper 0.9.0` source.
It depends on Agentlab's published `clipper-sys 0.8.0` crate, which links the
matching Fedora `polyclipping 6.4.2` system library instead of compiling the
bundled Clipper implementation.
