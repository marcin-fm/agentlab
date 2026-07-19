# rust-selectors0.37

Compatibility package for the released MPL-2.0 `selectors 0.37.0` crate
required by the selected system-registry build of `lol-html 3.0.0`.

Fedora 43, Fedora 44, and Rawhide provide only the incompatible `selectors
0.31` branch. The exact crates.io archive has SHA-256
`2cfaaa6035167f0e604e42723c7650d59ee269ef220d7bbe0565602c8a0173b9`.
The selected consumer uses the empty default feature set and does not require
the optional `to_shmem` surface. Upstream supplies no standalone license file;
the installed Rust source carries MPL-2.0 notices.

A Fedora 44 x86_64 Mock chain builds `rust-cssparser0.36` first and then proves
that this package resolves `crate(cssparser/default) = 0.36.0`. All 12 unit
tests pass; the one documentation example is ignored upstream. The package is
selected for the full Fedora 43, Fedora 44, and Rawhide matrix on both
architectures after `rust-cssparser0.36`.
