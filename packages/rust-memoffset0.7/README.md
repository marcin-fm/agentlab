# rust-memoffset0.7

Rawhide-only compatibility package for the published `memoffset 0.7.1` crate
required by the `nix 0.26` `socket` feature. Fedora Rawhide provides
`memoffset 0.9` but no compatible `0.7` provider, and RPM Fusion provides no
replacement.

Generated with rust2rpm 28. The package exposes the empty default feature used
by `nix 0.26` and the crate's released `unstable_const` feature interface.
A clean Rawhide x86_64 Mock build passed, followed by the complete local chain
through `ast-grep`. Rawhide aarch64 and remote COPR results remain pending.
