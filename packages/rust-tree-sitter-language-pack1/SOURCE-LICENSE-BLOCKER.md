# Parser Source And License Status

## Immutable Evidence Closure

- The closure is `parser-source-license-evidence/`, produced from exact pinned
  commits in `sources/language_definitions.json` using Git protocol v2 with a
  blob-filtered fetch, then exact license-blob retrieval.
- `parser-source-license-evidence/MANIFEST.sha256` has SHA-256
  `3c9620ca622ec6662dd686f704089b7705f3fbeab51a7e3cf5f1485a6f0ac785` and
  covers 586 tree-path and primary-license evidence files.
- `parser-source-license-inventory.json` maps all 306 parser paths to their
  repository URL, exact revision, source-tree hash, primary-license hashes,
  and detected SPDX evidence.
- 291 parser records now have primary license evidence. The detected set is
  `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `CC0-1.0`, `ISC`, `MIT`, and
  `Unlicense`; no primary-evidence record remains ambiguous.

## Historical Evidence Audit

All exact repository commits were fetched and their tree paths are preserved.
The conservative final subset includes 295 parsers and excludes 11 according to
the reviewed inventory. The historical evidence audit below records pinned
repositories without a primary `LICENSE*`, `COPYING*`, or `NOTICE*` file at the
grammar source root; it is not the current package blocker:

- `CodeAnt-AI/tree-sitter-vb-dotnet`
- `Decodetalkers/tree-sitter-groovy`
- `FacilityApi/tree-sitter-facility`
- `Freed-Wu/tree-sitter-tmux`
- `addcninblue/tree-sitter-cooklang`
- `ajdelcimmuto/tree-sitter-brightscript`
- `connorlay/tree-sitter-eex`
- `gbprod/tree-sitter-gitcommit`
- `gbprod/tree-sitter-twig`
- `glapa-grossklag/tree-sitter-elsa`
- `jakestanger/tree-sitter-corn`
- `rolandwalker/tree-sitter-pgn`
- `tree-sitter-grammars/tree-sitter-move`
- `uyha/tree-sitter-eds`
- `winston0410/tree-sitter-hjson`

The final F44 package build passed. Current package blockers are immutable
public hosting for the generated closure archive and final repository
validation.

## Rebuilt Parser Input

- Removed `parsers/bitbake/src/parser.o`, `parsers/bitbake/src/scanner.o`,
  `parsers/clarity/src/parser.o`, and `parsers/vhs/src/parser.o`.
- `parser-sources-1.12.5.no-prebuilt-objects.tar.zst` is a normalized source
  archive that excludes every `.o` file. SHA-256:
  `97fa45a88ba7230ee5509c75eb3e8febec06f1db79c237034a6deba50636eb94`.
- The existing Fedora patch selects the parser source root through
  `TSLP_PARSER_SOURCE_DIR`; `build.rs` compiles `parser.c` and scanner sources
  with the C/C++ toolchain rather than consuming source-tree object files.
