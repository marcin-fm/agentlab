# ast-grep

This package builds the `ast-grep` structural search and rewrite CLI from the
published `0.45.0` source release.

The package is enabled. The prior `0.44.1` release passed clean Fedora 43 and
Fedora 44 x86_64 builds, all tests, CLI smokes, and its aggregate linked-license
audit. A clean Fedora 44 x86_64 `0.45.0` chain build passed 189 tests with one
ignored test, both CLI smokes, the refreshed linked-license report, and package
lint. The six-cell configured build remains pending.

The source archive contains prebuilt dynamic-language test fixtures. The spec
removes them during `%prep`; the native Rust CLI build does not need them.

Only `/usr/bin/ast-grep` will be installed. Upstream also builds an `sg` alias,
but Fedora's `shadow-utils` package already owns `/usr/bin/sg` for an unrelated
command.

Generated shell completions are installed. The expected `rpmlint` warning about
the absence of a manpage remains; ast-grep does not ship one.
