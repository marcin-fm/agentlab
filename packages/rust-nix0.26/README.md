# rust-nix0.26

Rawhide-only compatibility package for the published `nix 0.26.4` crate
required by `x11rb 0.12`. Fedora Rawhide provides newer incompatible branches
but no `0.26` provider, and RPM Fusion provides no replacement.

Generated with rust2rpm 28. The package exposes the `fs`, `poll`, `socket`, and
`uio` interfaces selected by the existing X11 clipboard chain, plus the
`memoffset` feature required by `socket`. Its metadata patch removes only the
FreeBSD-only `sysctl` test dependency from Fedora's Linux build graph.

The package retains upstream tests while excluding one socket queue assertion
that Fedora also treats as flaky and the kernel-module and process-accounting
tests that require facilities or privileges unavailable inside Mock.
A clean Rawhide x86_64 Mock build passed that focused suite, followed by the
complete local chain through `ast-grep`. Rawhide aarch64 and remote COPR results
remain pending.
