# Parser Subset Audit

- Input: exact pinned parser commits from `direct-v3-language-pack`.
- Included parsers: 295.
- Excluded parsers: 11 from the conservative licensed subset.
- Aggregate detected SPDX set: Apache-2.0, BSD-2-Clause, BSD-3-Clause, CC0-1.0, ISC, MIT, Unlicense, WTFPL.
- Closure archive: `parser-sources-1.12.5-licensed-subset.tar.zst`.
- Closure archive SHA-256: `ebf1abc89cc4bef5a8d9c07e896796ddaa7aff68cb56143485bab94c47af846a`.
- Closure manifest SHA-256: `f9d44f6c7f7f128da45c512c83d9aade30a2cd65b8fdd7dc877250159fadc0f2`.
- Generation source: `prepare_subset.py`, using pinned `sources/language_definitions.json`, `sources/license_cache.json`, and the parser license inventories in the staging workspace.
- Source-only rule: all `.o` files are excluded; parser C/C++ sources are compiled at package build time.
- Final validation status: the conservative subset includes 295 parsers and excludes 11; the F44 build passed.
- Remaining package blockers: immutable public hosting for the generated closure archive and final repository validation.
