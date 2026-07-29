# Xberg

This is a blocked source-package draft for upstream Xberg 1.0.1, tag commit
`60557740a675908ea8d27145841dafd4f6a06917`. The official tag archive is Source0
with SHA-256 `a2e3ac73c051476625ec3f540c523553be2086282d3808c3f32979067a070ee6`.

## Corrected Cargo Contract

The selected Fedora workspace has six members: `xberg`, `xberg-cli`,
`xberg-libheif`, `xberg-libwpd`, `xberg-paddle-ocr`, and `xberg-tesseract`.
The checked Fedora lock contains 1,040 registry identities, 604 selected
identities, and 436 resolver-only identities. The normal and
normal/build/dev graphs contain 610 and 629 packages, respectively, with no
Git dependencies. Intel MKL source identities are absent.

The four source patches apply in this order: system ORT feature, Fedora ORT
lib64 discovery, dynamic Tesseract, and selected workspace/Candle pruning.
The Cargo vendor tree contains 51,400 files, 9,488 directories, no symlinks,
and 1,101,005,097 bytes. Its tree SHA-256 is
`e3418b1feee8a7824b243e91552e3f550066410e6028c4c5484757d340dc9672`.

## Provider Boundary

The provider proof records Fedora ONNX Runtime, libheif, Tesseract,
Leptonica, and English tessdata records for Fedora 43, Fedora 44, and
Rawhide. Tesseract and ORT use dynamic system providers. Tree-sitter's
selected feature is `download`; build-time parser downloads are disabled when
static languages are unset, while runtime parser-pack download remains
unapproved. Build downloads, runtime model downloads, compilation, runtime
smoke, final linked-license completeness, enablement, matrix proof, and COPR
publication remain false.

## License Boundary

The tracked source-license receipt covers Source0 and the 1,040-source vendor
tree. It records 77 missing license-text gaps: 23 selected-normal and 54
resolver-only, with 76 distribution texts required. The source package
expression is source-payload coverage only; final binary linked-license proof
is not complete.

The source filter removes only the checked unsafe developer-machine link. The
Cargo auditor preserves deterministic safe extraction, the checked lock, the
full resolver vendor tree, and offline directory-source metadata/tree proof.
The proof auditor can regenerate both receipts from a prepared sanitized,
patched, lock-replaced source and extracted vendor tree without transient
research files.

Historical configured-SCM proofs `10786324` and `10786342` used the superseded
1,133-source contract and are not current evidence. No compile or binary RPM
proof exists. Xberg remains blocked and COPR-disabled pending provider,
native, model, runtime, final-license, and target-matrix proof.
