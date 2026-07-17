# Kreuzberg

This package targets the published Kreuzberg LTS `4.10.2` release. One source
package is intended to produce the source-built `kreuzberg` CLI and the public
`nodejs-kreuzberg` N-API binding used by the canonical cx container image.

The tagged GitHub archive contains the Rust and TypeScript source. The matching
published npm artifact is used only for the generated JavaScript loader,
declarations, and source maps; upstream platform `.node` packages are never
used. The native addon and CLI must be compiled with Fedora's Rust toolchain.

The completed local validation builds PDFium and the selected Rust closure from
source. F44 application validation passed with the 371-record closure; F43
reached the final Node executable correction. The linked license aggregate was
audited and the tree-sitter parser subset is static. No generated RPMs were
installed and no COPR state changed.

The package remains blocked. Remaining gates are immutable public hosting for
the generated PDFium/Rust closure, parser subset, and fixture sources; final
serialized F43/F44 validation after the collector and Node BuildRequires
corrections; release-boundary approval; and aarch64 proof. Fedora's
`deepin-pdfium` remains incompatible with Kreuzberg's FPDF API.

The 63 imported Rust dependency records are finalized in
`dependency-finalization.yml`. All 40 declared patch files byte-match their
retained successful SRPM members, including the preserved F43 `comrak` and
`hayro-jbig2` corrections. This is static and retained-artifact evidence only:
the corrected exact specs were not rebuilt and package-level `rpmlint` evidence
is not retained.

Compact receipts and audit notes are in `dependency-finalization.yml`,
`reproducibility.yml`, `validation-summary.md`, `license-review.md`, and
`license-fixes.yml`.

Kreuzberg is globally installed by the canonical container definition but is
not currently referenced by `/srv/cx` source. It remains in scope because the
maintainer requested packaging of every eligible non-Fedora component in the
canonical cx environment.
