# Parser Source And License Contract

## Immutable Evidence Closure

- The closure is `parser-source-license-evidence/`, produced from exact pinned
  commits in `sources/language_definitions.json` using Git protocol v2 with a
  blob-filtered fetch, then exact license-blob retrieval.
- The retained evidence archive has SHA-256
  `ad560fc6ebbe2a7b5e24ad07caebc4ccc044d4d9bef0333bfd47efe45be2daa7`.
  Its `MANIFEST.sha256` has SHA-256
  `b27bf70afdb6abf7c622f973c4dc553489399e502ada0b7494e5662f4b570fe0`
  and covers 589 tree-path and primary-license evidence files.
- `parser-source-license-inventory.json` maps all 306 parser paths to their
  repository URL, exact revision, source-tree hash, primary-license hashes,
  and detected SPDX evidence.
- 294 parser records have primary license files at their exact pins. The
  detected set is
  `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `CC0-1.0`, `ISC`, `MIT`, and
  `Unlicense`; no primary-evidence record remains ambiguous.

## Historical Evidence Audit

All exact repository commits were fetched and their tree paths are preserved.
The conservative final subset includes 293 parsers and excludes 13 according to
the reviewed inventory. `LICENCE*` is treated as a primary license filename;
this resolves the pinned WTFPL evidence for `gitcommit` and `twig`.

- `CodeAnt-AI/tree-sitter-vb-dotnet`
- `Decodetalkers/tree-sitter-groovy`
- `FacilityApi/tree-sitter-facility`
- `Freed-Wu/tree-sitter-tmux`
- `addcninblue/tree-sitter-cooklang`
- `ajdelcimmuto/tree-sitter-brightscript`
- `connorlay/tree-sitter-eex`
- `glapa-grossklag/tree-sitter-elsa`
- `jakestanger/tree-sitter-corn`
- `rolandwalker/tree-sitter-pgn`
- `tree-sitter-grammars/tree-sitter-move`
- `uyha/tree-sitter-eds`
- `winston0410/tree-sitter-hjson`

`vb` is excluded because upstream issue 7 states that the code is unlicensed.
`pgn` is excluded because the current pin lacks the BSD-2-Clause text. The
remaining unresolved records are also excluded, so no declaration-only or
historical-text-only parser enters the package.

## Rebuilt Parser Input

- Removed `parsers/bitbake/src/parser.o`, `parsers/bitbake/src/scanner.o`,
  `parsers/clarity/src/parser.o`, and `parsers/vhs/src/parser.o`.
- `parser-sources-1.12.5.no-prebuilt-objects.tar.zst` is a normalized source
  archive that excludes every `.o` file. SHA-256:
  `97fa45a88ba7230ee5509c75eb3e8febec06f1db79c237034a6deba50636eb94`.
- The existing Fedora patch selects the parser source root through
  `TSLP_PARSER_SOURCE_DIR`; `build.rs` compiles `parser.c` and scanner sources
  with the C/C++ toolchain rather than consuming source-tree object files.
- The configured-SCM path starts from upstream's immutable full parser bundle
  at SHA-256
  `a4bc35714f8f5e0749beacfe00f7271f1af47339bf56712f670c23f2463ae6dc`,
  verifies every evidence file, and requires the final tracked manifest and
  subset archive SHA-256 to match before SRPM creation.
