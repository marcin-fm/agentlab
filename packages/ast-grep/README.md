# ast-grep

This package builds the `ast-grep` structural search and rewrite CLI from the
published `0.45.0` source release.

The package is enabled. Configured-SCM build `10771811` produced
`0.45.0-0.1` successfully in Fedora 43, Fedora 44, and Rawhide on both
`x86_64` and `aarch64`. It passed 189 tests with one ignored test, both CLI
smokes, the refreshed linked-license report, signature verification, and
package lint. Release `0.2` records that completed evidence without changing
the selected source, patch, dependency graph, or build behavior.

The source archive contains prebuilt dynamic-language test fixtures. The spec
removes them during `%prep`; the native Rust CLI build does not need them.

Only `/usr/bin/ast-grep` will be installed. Upstream also builds an `sg` alias,
but Fedora's `shadow-utils` package already owns `/usr/bin/sg` for an unrelated
command.

Generated shell completions are installed. The expected `rpmlint` warning about
the absence of a manpage remains; ast-grep does not ship one.
