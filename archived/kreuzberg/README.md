# Kreuzberg

This package targets the published Kreuzberg LTS `4.10.2` release. One source
package is intended to produce the source-built `kreuzberg` CLI and the public
`nodejs-kreuzberg` N-API binding used by the canonical cx container image.

The tagged GitHub archive contains the Rust and TypeScript source. Fedora's
TypeScript and esbuild packages generate the JavaScript, declarations, and
source maps offline; upstream platform `.node` packages are never used. The
exact upstream-generated NAPI-RS loader from commit `228f684` selects the
adjacent Fedora-built addon. The native addon and CLI are compiled with
Fedora's Rust toolchain.

Retained `0.0.5` dependency proof succeeded for all 252 package/chroot pairs in
Fedora 43 and 44 on x86_64 and aarch64. The retained application builds
`10739044` and `10739040` then succeeded in all four native chroots with CLI,
text, PDF, and real Node N-API checks. Representative x86_64 and aarch64 RPM
pairs were downloaded and extracted without installation; both inspected CLIs
and addons have the expected ELF architecture and no RPATH or RUNPATH.

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

The source, license, provider, architecture, and runtime-integration gates are
closed. PDFium build `10751847` and tree-sitter language-pack build `10768304`
provide the complete six-cell dependency surface. The hf-hub compatibility
patch preserves required-file failures, optional metadata fallbacks, and
user-cache environment handling. Release `0.0.8` is enabled for the current
six-cell application build; exact-current binary payload and package-level
rpmlint inspection remain the empirical completion check. Fedora's
`deepin-pdfium` remains incompatible with Kreuzberg's FPDF API.

The 63 imported Rust dependency records are finalized in
`dependency-finalization.yml`. All 40 declared patch files byte-match their
retained successful SRPM members, including the preserved F43 `comrak` and
`hayro-jbig2` corrections. The retained `0.0.5` source-package and binary build
receipts cover both stable releases and both architectures.

Compact receipts and audit notes are in `dependency-finalization.yml`,
`reproducibility.yml`, `validation-summary.md`, `license-review.md`, and
`license-fixes.yml`.

Kreuzberg is globally installed by the canonical container definition but is
not currently referenced by `/srv/cx` source. It remains in scope because the
maintainer requested packaging of every eligible non-Fedora component in the
canonical cx environment.
