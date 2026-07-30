# rust-tree-sitter0.25.2

This package provides released crate `tree-sitter 0.25.2` for Headroom `0.33.0`.
Fedora 43, Fedora 44, and Rawhide provide the selected grammar branches and
`tree-sitter-language 0.1`, but none provides exact
`crate(tree-sitter/default) = 0.25.2`.

The 187,841-byte crates.io archive has SHA-256
`5168a515fe492af54c5cc8800ff8c840be09fa5168de45838afaecd3e008bce4`.
The package is adapted from Fedora's `rust-tree-sitter0.25 0.25.10` compatibility
spec. A version-specific metadata patch preserves Fedora's aggregate bundled
tree-sitter/ICU license expression, removes the unselected wasm/wasmtime edge,
and updates bindgen to Fedora's `0.72.1` branch. Two retained Fedora patches
regenerate bindings unconditionally and use the crate's declared Rust `1.76`
floor without recursively invoking Cargo.

Only default/std feature subpackages are selected. Tests remain disabled because
the released crate archive omits the upstream test data and additional source
repositories. The package must complete the six-cell configured-SCM matrix
before Headroom `0.33.0-0.2` is submitted.

The devel package declares bundled tree-sitter C and ICU 65.1 provides, installs
both upstream and ICU/Unicode license texts, and emits explicit `default` and
`std` feature subpackages so Headroom's exact generated dependency can resolve.
An unconditional `%check` requires cargo2rpm to emit
`crate(tree-sitter/default) = 0.25.2` and `crate(tree-sitter/std) = 0.25.2` from
the patched source before the package can complete.
