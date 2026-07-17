# rust-ls-types0.0.6

Compatibility package for the published `ls-types 0.0.6` release selected by
the ast-grep 0.44.1 source graph. This semver-zero branch adds the
`InitializeResult.offset_encoding` field used by ast-grep's LSP implementation.
Release `0.2` is the single selected `ls-types` branch after the patched
tower-lsp-server 0.23.0 package moved to this API and retired its obsolete
`ls-types 0.0.2` compatibility chain.

Generated with rust2rpm 28. Clean Fedora 43 and Fedora 44 x86_64 mock builds
passed, and the package is enabled.
