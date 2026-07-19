# rust-nix0.26

Rawhide-only compatibility package for the published `nix 0.26.4` crate
required by `x11rb 0.12`. Fedora Rawhide provides newer incompatible branches
but no `0.26` provider, and RPM Fusion provides no replacement. Fedora 43 and
Fedora 44 already provide compatible `rust-nix0.26-devel` 0.26.4 packages, so
this package intentionally omits stable chroots.

Generated with rust2rpm 28. The package exposes the `fs`, `poll`, `socket`, and
`uio` interfaces selected by the existing X11 clipboard chain, plus the
`memoffset` feature required by `socket`. Its metadata patch removes only the
FreeBSD-only `sysctl` test dependency from Fedora's Linux build graph.

The package retains upstream tests while excluding the hardware-dependent
AF_ALG cipher test and two flaky socket assertions that Fedora also excludes,
plus the kernel-module and process-accounting tests that require facilities or
privileges unavailable inside Mock.
A clean Rawhide x86_64 Mock build passed that focused suite, followed by the
complete local chain through `ast-grep`. COPR build `10739331` passed x86_64;
its aarch64 cell compiled successfully and failed only the AF_ALG test before
the Fedora-aligned exclusion was added for the `0.2` rebuild. Build `10739336`
then passed aarch64 and failed x86_64 only in the Fedora-classified flaky
`test_recvmm2` ancillary-data timing assertion before its `0.3` exclusion.
