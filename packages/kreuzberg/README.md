# Kreuzberg

This package targets the published Kreuzberg LTS `4.10.2` release. One source
package is intended to produce the source-built `kreuzberg` CLI and the public
`nodejs-kreuzberg` N-API binding used by the canonical cx container image.

The tagged GitHub archive contains the Rust and TypeScript source. The matching
published npm artifact is used only for the generated JavaScript loader,
declarations, and source maps; upstream platform `.node` packages are never
used. The native addon and CLI must be compiled with Fedora's Rust toolchain.

Exact-current dependency proof succeeded for all 252 package/chroot pairs in
Fedora 43 and 44 on x86_64 and aarch64. Application builds `10739044` and
`10739040` then succeeded in all four native chroots with CLI, text, PDF, and
real Node N-API checks. Representative x86_64 and aarch64 RPM pairs were
downloaded and extracted without installation; both inspected CLIs and addons
have the expected ELF architecture and no RPATH or RUNPATH.

The mechanical patch split, Fedora macro conversion, and license-payload rework
are complete in the `0.0.5` draft. The former nine-patch stack is split into 20
single-concern Fedora integration and compatibility patches with adjacent
purpose and upstream-status comments. The hf-hub and calamine adaptations now
record the exact later upstream commits and original author whose work they
incorporate or reverse; they are not represented as exact backports. The ordered
series applies with zero fuzz and reproduces the former applied `v4.10.2` source
tree. The custom provider-license collector and `THIRD-PARTY-LICENSES` payload
were removed; the aggregate SPDX expression, project license, and Fedora Cargo
`LICENSE.dependencies` inventory remain. Exact built inventories contain 394
dependency rows, including the previously unavailable `ahash` record.

The package remains blocked. Remaining gates are reproducible generation of the
published Node loader and declarations from the tagged TypeScript source (or
omission of that subpackage); immutable public hosting for the generated
PDFium/Rust closure, parser subset, and fixture sources; full third-party
license-text evidence; final ONNX
Runtime/PDFium ABI and runtime review; hf-hub model-download and calamine date
behavior review; release-boundary approval; and complete retained package-level
rpmlint evidence. Fedora's `deepin-pdfium` remains incompatible with
Kreuzberg's FPDF API.

The 63 imported Rust dependency records are finalized in
`dependency-finalization.yml`. All 40 declared patch files byte-match their
retained successful SRPM members, including the preserved F43 `comrak` and
`hayro-jbig2` corrections. The exact-current source-package and binary build
receipts now cover both stable releases and both architectures.

Compact receipts and audit notes are in `dependency-finalization.yml`,
`reproducibility.yml`, `validation-summary.md`, `license-review.md`, and
`license-fixes.yml`.

Kreuzberg is globally installed by the canonical container definition but is
not currently referenced by `/srv/cx` source. It remains in scope because the
maintainer requested packaging of every eligible non-Fedora component in the
canonical cx environment.
