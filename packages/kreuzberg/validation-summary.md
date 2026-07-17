# Kreuzberg Validation Summary

Paths under `/srv/tmp` below are transient evidence references only and are not
distributable source locations.

## Fedora 44

- Local PDFium and the 371-record Rust compatibility repository were used.
- The current source patches applied with zero fuzz.
- CLI unit, environment, contract, log, MIME, text, PDF, and N-API extraction checks passed.
- The five produced artifacts had zero technical `rpmlint` errors and one expected no-upstream-manpage warning.
- The historically validated v19 source RPM had SHA-256 `e4b62e0e01598695cd53b69c7fd3a5546fea269986a16ae606cf14f1a62a6e6e`. The file currently at `/srv/tmp/agentlab-kreuzberg/final-validation/f44/SRPMS/kreuzberg-4.10.2-0.1.fc44.src.rpm` is a different, unvalidated candidate with SHA-256 `c6f1dade2e1cd5b4af23996ca97e133e4cfb3473a3b22d061e1447cb9b11cc8c`; it must not be treated as the v19 receipt.
- F44 manifest evidence: `/srv/tmp/agentlab-kreuzberg/final-f44/manifest.tsv`, 371 records, SHA-256 `57875ef73b20eee11166dab63a3db6d768c08a81c6703b73338fce109fb0986a`.

## Fedora 43

- The local repository contains 379 RPM records and the final recursive closure includes the F43 `comrak` and `hayro-jbig2` corrections plus released `fearless_simd` and `hayro-jpeg2000` sources.
- The retained F43 SRPM passed source patching, optimized compilation, CLI tests, CLI MIME/text/PDF smokes, and N-API test compilation.
- Historical application validation stopped because that retained SRPM required `nodejs-devel` but not `nodejs`; F43 `nodejs-devel` does not install the `node` executable. No final F43 RPM, runtime smoke, or post-build lint result is claimed.
- The repository now declares both `BuildRequires: nodejs >= 22` and `BuildRequires: nodejs-devel >= 22`, but that correction has not received a new full application rebuild.
- F43 repository evidence: `/srv/tmp/agentlab-kreuzberg/final-f43/repo-manifest.tsv`, 379 records, SHA-256 `9f058637d8362435a37d95ba8d79ae670ce8d003feec4960d3068dfebd33b13a`; not distributable.

## Final Gates

The current repository collector SHA-256 is
`c6b273d9a9961ab6ffa3bf0b4936f23c89b60ca782ca10949ab6fecc1dc1fb5a`.
It handles newline-separated RPM owners individually without weakening
fail-closed missing-evidence behavior, but still needs a later serialized full
application rebuild. The 63 imported package records were statically finalized;
all 40 declared patch files byte-match their retained successful SRPM members.
Package-level `rpmlint` evidence is not retained, current corrected specs were
not rebuilt in this pass, and aarch64 remains unproven. Immutable fixture/parser
and PDFium/Rust closure hosting plus PDFium release-boundary approval remain
external publication blockers.

## Parser Accounting

The generated parser work record contains 295 archive records with 11 excluded
records. The archive itself is omitted; the static F44 closure is retained only
as exact RPM hashes in `license-review.md`. Upstream Kreuzberg documentation
describes 248 programming languages, which is a separate language count and is
not replaced by the 295-record archive accounting.

## Later Serialized Rebuild Commands

Run these only after fresh current-spec F43/F44 SRPMs have been staged in the
shell variables and result directories have been approved. They were not run in
this finalization pass.

```bash
nice -n 10 rtk mock -r /srv/tmp/agentlab-kreuzberg/final-f43/fedora-43-kreuzberg.cfg --clean \
  --addrepo file:///srv/tmp/agentlab-kreuzberg/final-f43/repo \
  --addrepo file:///srv/tmp/agentlab-kreuzberg/repos/f43 \
  --rebuild "$F43_SRPM" --resultdir "$F43_RESULTDIR"

nice -n 10 rtk mock -r fedora-44-x86_64.cfg --clean \
  --addrepo file:///srv/tmp/agentlab-kreuzberg/final-f44/repo \
  --addrepo file:///srv/tmp/agentlab-kreuzberg/repos/f44 \
  --rebuild "$F44_SRPM" --resultdir "$F44_RESULTDIR"
```
