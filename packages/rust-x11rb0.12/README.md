# rust-x11rb0.12

Compatibility package for the exact published `x11rb 0.12.0` release locked by
`x11-clipboard 0.8.1`. The generated metadata patch removes only Windows
dependencies, and the spec exposes the default plus XFixes-related features
needed by this chain. Clean Fedora 43 and Fedora 44 x86_64 mock builds passed,
and the package is enabled.
