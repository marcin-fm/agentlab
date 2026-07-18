# Kreuzberg Validation Summary

Paths under `/srv/tmp` below are transient evidence references only and are not
distributable source locations.

## Current COPR Application Proof

The exact `4.10.2-0.0.5` application builds succeeded in the transient COPR
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

The current `0.0.5` draft defines the Fedora check bcond, generates selected
package build requirements, uses Fedora Cargo build/test and workspace license
macros, preserves Fedora Rust flags, installs the N-API package through the
native Node path and filter, and removes RPATH/RUNPATH from both native outputs.
Exact native target builds generated and verified the final inventories.
The hf-hub and calamine patch headers now record the exact later upstream commits
and Na'aman Hirschfeld's authorship without claiming exact backports; behavioral
review beyond the retained test and smoke coverage remains pending.

The 63 imported package records were finalized, all 40 dependency patch files
byte-match their retained successful SRPM members, and all 252 exact current
package/chroot pairs succeeded before the application builds. Immutable
fixture/parser and PDFium/Rust closure hosting, full third-party license-text
evidence, supplemental N-API license publication, ONNX Runtime/PDFium ABI and
runtime review, PDFium release-boundary approval, and complete retained
package-level rpmlint evidence remain blockers.

## Parser Accounting

The generated parser work record contains 295 archive records with 11 excluded
records. The archive itself is omitted; the static F44 closure is retained only
as exact RPM hashes in `license-review.md`. Upstream Kreuzberg documentation
describes 248 programming languages, which is a separate language count and is
not replaced by the 295-record archive accounting.
