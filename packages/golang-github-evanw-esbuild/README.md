# golang-github-evanw-esbuild

This package adapts Fedora's existing esbuild source package to exact upstream
`0.28.1`, required by the selected Playwright build graph.

The Go executable is compiled from the pinned `v0.28.1` source. That executable
then generates the public `esbuild` JavaScript module. The installed
`@esbuild/<linux-architecture>` package contains metadata and a link to the
RPM-built executable, never an upstream prebuilt platform binary.

A fresh Fedora 44 x86_64 Mock build verifies the RPM artifacts, Go test suite,
and offline Node API behavior. Playwright remains independently blocked and
COPR-disabled after this provider is complete.
