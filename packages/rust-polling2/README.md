# rust-polling2

Rawhide-only compatibility package for the published `polling 2.7.0` crate
required by the `x11rb 0.12` test graph. Fedora Rawhide provides `polling 3`
but no compatible `2.x` provider, and RPM Fusion provides no replacement.

Generated with rust2rpm 28. The major-version package suffix follows current
rust2rpm output and provides the default and `std` feature interfaces selected
by downstream Cargo metadata. Its metadata patch removes only Windows target
dependencies from Fedora's Unix build graph.
A clean Rawhide x86_64 Mock build passed, followed by the complete local chain
through `ast-grep`. Rawhide aarch64 and remote COPR results remain pending.
