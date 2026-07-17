# rust-tungstenite0.28

This compatibility package provides the published `tungstenite` `0.28.0`
crate required by `async-tungstenite` `0.32` on Fedora 43. Fedora 44 already
provides this crate branch.

The package exposes only the default handshake closure and the `url` feature
used by the ast-grep dependency chain. A clean Fedora 43 x86_64 mock build
passed, and the package is enabled only for Fedora 43 because Fedora 44
provides this crate branch.

The repository patch removes only the `criterion` benchmark dependency; the
library test suite remains enabled.
