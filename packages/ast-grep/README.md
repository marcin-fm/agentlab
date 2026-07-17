# ast-grep

This package builds the `ast-grep` structural search and rewrite CLI from the
published `0.44.1` source release.

The package is enabled. Clean Fedora 43 and Fedora 44 x86_64 mock builds
passed, all tests and CLI smoke checks passed, and the aggregate linked
dependency license audit passed.

The source archive contains prebuilt dynamic-language test fixtures. The spec
removes them during `%prep`; the native Rust CLI build does not need them.

Only `/usr/bin/ast-grep` will be installed. Upstream also builds an `sg` alias,
but Fedora's `shadow-utils` package already owns `/usr/bin/sg` for an unrelated
command.

Generated shell completions are installed. The expected `rpmlint` warning about
the absence of a manpage remains; ast-grep does not ship one.
