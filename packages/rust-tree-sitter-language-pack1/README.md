# rust-tree-sitter-language-pack1

The reviewed subset retains exactly 293 parser records with license text from
their exact pinned source commits and excludes 13 records. Its normalized
subset SHA-256 is
`84835d8fd1ced163b65bbf560c9fe9b3bd4d0753d1c1c96d85d8e5dd77f7a55b`.

## Finalization status

The package is enabled for the default COPR matrix. Configured-SCM source
creation downloads upstream's immutable parser bundle, verifies its published
SHA-256, combines it with the retained exact-commit license evidence closure,
and reproduces the tracked subset manifest and archive before creating the
SRPM. Target RPM builds remain offline.

Final package inputs for `tree-sitter-language-pack 1.12.5`, with the Fedora
patches and the reviewed 293-parser source-subset audit metadata. The generated
subset archive is intentionally omitted from Git and reconstructed by
`.copr/Makefile`; the compact exact-commit evidence archive is retained under
`sources/`.

`vb` is excluded because upstream issue
`CodeAnt-AI/tree-sitter-vb-dotnet#7` confirms that the pinned code is
unlicensed despite MIT package metadata. `pgn` is excluded because the pinned
tree deliberately omits the BSD-2-Clause text; omitting that optional parser is
smaller than carrying historical supplemental text without a current upstream
request. British-spelled `LICENCE` files are recognized, so `gitcommit` and
`twig` retain their exact pinned WTFPL texts as primary evidence.
