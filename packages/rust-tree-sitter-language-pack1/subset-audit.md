# Parser Subset Audit

- Input: exact pinned parser commits from `direct-v3-language-pack`.
- Included parsers: 293.
- Excluded parsers: 13 from the conservative licensed subset.
- Aggregate detected SPDX set: Apache-2.0, BSD-2-Clause, BSD-3-Clause, CC0-1.0, ISC, MIT, Unlicense, WTFPL.
- Closure archive: `parser-sources-1.12.5-licensed-subset.tar.zst`.
- Closure archive SHA-256: `84835d8fd1ced163b65bbf560c9fe9b3bd4d0753d1c1c96d85d8e5dd77f7a55b`.
- Closure manifest SHA-256: `f0cc17db7f4349f06beb4043ee655a8141bae31c7368cc88c5a75f5d77965e69`.
- Generation source: `prepare_subset.py`, using upstream's immutable full parser bundle, pinned `sources/language_definitions.json`, `sources/license_cache.json`, and the retained exact-commit evidence archive.
- Source-only rule: all `.o` files are excluded; parser C/C++ sources are compiled at package build time.
- License correction: `vb` and `pgn` are omitted; `gitcommit` and `twig` use exact pinned `LICENCE` texts detected as WTFPL.
- Delivery status: configured-SCM `make_srpm` reconstructs and verifies the subset; target builds remain offline.
