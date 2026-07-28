# Kreuzberg Validation Summary

Paths under `/srv/tmp` below are transient evidence references only and are not
distributable source locations.

## Retained 0.0.5 COPR Application Proof

The retained `4.10.2-0.0.5` application builds succeeded in the transient COPR
project `marcin/agentlab-aarch64-proof-20260717-v1`:

- F43 x86_64: build `10739044`; builder-log SHA-256 `22f84e1d32ae14cdd3b28e5a69ee598517f83017f0c33959505f37f7296728d0`.
- F43 aarch64: build `10739044`; builder-log SHA-256 `97e8134998c1b71fe83c6719bc3dac615bfd0dc2c5bf4b174e3d120777ff9937`.
- F44 x86_64: build `10739040`; builder-log SHA-256 `aa8defd188e54630dab9c48d5e17e5d567b8e528b3db3dd34561564af67c6cb8`.
- F44 aarch64: build `10739040`; builder-log SHA-256 `46595d2203d97e82cdc96db1484e5bade24d6b3b417fe5326301143f5846241a`.

Every native `%check` ran the CLI binary suite with 39 passes, the selected
config/environment/contract/log suites with 2, 16, and 1 passes, the Node crate
suite, CLI MIME/text/PDF smokes, and a real Node N-API extraction smoke. The
text and PDF assertions found `Hamburgers are delicious` and `Simple document`.
No complete package-level rpmlint evidence set was retained.

## Extracted RPM Proof

No RPM was installed. The selected non-debug artifacts were queried and
extracted under
`/srv/tmp/agentlab-kreuzberg/final-proof-10739040-10739044`:

- F44 x86_64 CLI RPM SHA-256 `4fb9b249b4ce2269c1775caae570fd9533e250fd77358be8b33a8354befbd121`; Node RPM SHA-256 `c965607624282278f94aba415b6652e28b72eb5aef7806a79f6ba3ae8be23851`.
- F43 aarch64 CLI RPM SHA-256 `4a9f4846a436c13ee82bc8dff5f13ed35310b2367c2e46dc727ad2e12ebf5ff5`; Node RPM SHA-256 `43c4764a20a75698fc80db7af7c945ca7de3807b83a5936859176ad90be63a71`.
- F44 x86_64 CLI/addon SHA-256 values are `70ff0d7fe38e069a88b0b4da8785afe4094aa0b39a3551e232d94cf7236d0eaf` and `38c7a88ae5363656eb58e0ce1ae8151b58e88039806053cf973a5d9860470dab`.
- F43 aarch64 CLI/addon SHA-256 values are `f713590ca62e19bd807e9fc7e75d1a47dfe7d883f9ee57778b2974962190911d` and `74627d3efad5bbe94420807644454e45bac8ce0029e6aac1482bbf5aec9f9106`.
- `file` and `readelf` identify the selected payloads as ELF64 x86-64 and
  AArch64 respectively. Neither CLI nor addon has an RPATH or RUNPATH.
- The F43 inventory is identical across the inspected x86_64 and aarch64
  payloads, has 394 nonblank rows, and hashes to
  `cf0995a3d08bc32f73b286547804d4a6b4046aefc09b9a170b1347f55799f047`.
  The F44 x86_64 inventory also has 394 rows and hashes to
  `3fb493c67dcf335d0a7cc6a49ad390b5d9597893e3b46dc053677e542185f18f`.

Host Node `v22.22.2` loaded the extracted x86_64 addon through
`NAPI_RS_NATIVE_LIBRARY_PATH`. The host lacked `libpolyclipping.so.22`, so an
already extracted exact F44 proof library was supplied with `LD_PRELOAD`; no
package was installed. The API smoke returned version `4.10.2`, detected and
extracted `text/plain`, and found the fixture text. A read-only Bubblewrap
namespace overlaid the extracted CLI at `/usr/bin/kreuzberg`; the shipped
hardcoded wrapper reported `kreuzberg 4.10.2` and extracted the same fixture.
Local aarch64 execution was not attempted on the x86_64 host; both aarch64 COPR
builder logs provide native CLI and Node N-API execution evidence.

## Final Gates

The custom full-text collector and `THIRD-PARTY-LICENSES` payload were removed
under the current Fedora-standard accounting policy. The spec retains the
aggregate SPDX expression, upstream project license, and generated
`LICENSE.dependencies` inventory. The former nine-patch application stack is
split into 20 single-concern patches with adjacent purpose/upstream-status
comments; every patch is below 200 changed lines, and the ordered series applies
with zero fuzz and reproduces the former applied source tree.

The retained `0.0.5` draft defines the Fedora check bcond, generates selected
package build requirements, uses Fedora Cargo build/test and workspace license
macros, preserves Fedora Rust flags, installs the N-API package through the
native Node path and filter, and removes RPATH/RUNPATH from both native outputs.
Exact native target builds generated and verified the final inventories.
The hf-hub and calamine patch headers record the exact later upstream commits
and Na'aman Hirschfeld's authorship without claiming exact backports. Source
review proves that the hf-hub adaptation retains hard errors for required model
and tokenizer files, optional metadata fallbacks, and user-cache environment
handling. The retained XLSX/date smoke proves the calamine compatibility path.

The 63 imported package records were finalized, all 40 dependency patch files
byte-match their retained successful SRPM members, and all 252 retained
package/chroot pairs succeeded before the application builds. PDFium build
`10751847` and the corrected 293-parser tree-sitter build `10768304` now provide
the complete dependency surface. Exact upstream commit `228f684` supplies the
generated Node loader. The current `0.0.8` six-cell build, binary payload
inspection, and package-level rpmlint evidence are the remaining empirical
completion checks.

## Local 0.0.7 Evidence

A Fedora 44 x86_64 Mock build of `4.10.2-0.0.7` completed before the later
license-payload-only correction. It passed the Rust suites, CLI MIME/text/PDF/
XLSX/date smokes, CommonJS and ESM Node extraction, and generated CLI execution.
Extracted artifacts had no RPATH or RUNPATH and `rpmlint` reported zero errors
and one missing-man-page warning. The subsequent spec correction installs the
same nonempty generated `LICENSE.dependencies` inventory into both runtime
packages; static expansion verifies both payload declarations, but no current
binary package is claimed from that correction.

The attempted Fedora 43 x86_64 verification stopped during dependency
resolution because the retained local repository contains no provider for
`pkgconfig(pdfium) >= 5.0`. Compilation did not start, so this is retained as an
evidence-repository gap rather than a Kreuzberg build result.

## Local 0.0.8 Source Proof

The configured-SCM-equivalent source path downloaded the four immutable remote
inputs, verified their SHA-256 values, and produced
`/srv/tmp/agentlab-kreuzberg-srpm-proof/kreuzberg-4.10.2-0.0.8.fc44.src.rpm`
at SHA-256 `907dc5333fa5a01bff15c222f33523de6bc810e9b3d8e0bebfc01ba23f371c0b`.
Its 25 members include the exact upstream `index.js`, tagged source, Node type
archives, local fixture, spec, and all 20 patches. Source-package `rpmlint`
reports zero errors and zero warnings.

## Parser Accounting

The corrected provider contains 293 archive records with 13 excluded records
and is published by build `10768304` in all six default chroots. Upstream
Kreuzberg documentation describes 248 programming languages, which is a
separate language count and is not replaced by parser archive accounting.
