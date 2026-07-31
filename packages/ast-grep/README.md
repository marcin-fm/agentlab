# ast-grep

This package builds the `ast-grep` structural search and rewrite CLI from the
published `0.45.0` source release.

The package is enabled. Its validation contract requires configured-SCM builds
in Fedora 43, Fedora 44, and Rawhide on both `x86_64` and `aarch64`, 189 passing
tests with one ignored test, both CLI smokes, the expected linked-license
report, no RPATH or RUNPATH, and clean package lint. Release `0.3` removes
transient build-result identities from active package inputs without changing
the selected source, patch, dependency graph, or build behavior.

The source archive contains prebuilt dynamic-language test fixtures. The spec
removes them during `%prep`; the native Rust CLI build does not need them.

Only `/usr/bin/ast-grep` will be installed. Upstream also builds an `sg` alias,
but Fedora's `shadow-utils` package already owns `/usr/bin/sg` for an unrelated
command.

Generated shell completions are installed. The expected `rpmlint` warning about
the absence of a manpage remains; ast-grep does not ship one.
