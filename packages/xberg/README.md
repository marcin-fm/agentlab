# Xberg

This is a blocked source-package draft for upstream Xberg 1.0.3, tag commit
`37b9fee5762450351e9303243a00e51184a1f24b`. The official tag archive is Source0
with SHA-256 `238b8087a398b7753562b341abf082c8305a0359786424976909dc59b251058e`.

## Corrected Cargo Contract

The selected Fedora workspace has six members: `xberg`, `xberg-cli`,
`xberg-libheif`, `xberg-libwpd`, `xberg-paddle-ocr`, and `xberg-tesseract`.
The checked Fedora lock contains 1,034 registry identities, 597 selected
identities, and 437 resolver-only identities. The normal and
normal/build/dev graphs contain 603 and 622 packages, respectively, with no
Git dependencies. Intel MKL source identities are absent.

The five source patches apply in this order: system ORT feature, Fedora ORT
lib64 discovery, dynamic Tesseract, selected workspace/Candle pruning, and
Fedora-managed tessdata enforcement.
The Cargo vendor tree contains 51,213 files, 9,444 directories, no symlinks,
and 1,099,639,051 bytes. Its tree SHA-256 is
`fb5abc63d34135752002719a3910f4ecacb049c5292b5e0f5776d7350eea2917`.

## Provider Boundary

The provider proof records Fedora ONNX Runtime, libheif, Tesseract,
Leptonica, and English tessdata records for Fedora 43, Fedora 44, and Rawhide.
Tesseract and ORT use dynamic system providers. Mutable tessdata downloads are
disabled; missing languages require Fedora `tesseract-langpack-*` packages or
an explicit local path. Tree-sitter is omitted from the initial RPM and remains
a prominent return TODO pending exact parser source, license, and offline
x86_64/aarch64 review. Immutable checksum-verified model downloads may be
opted into outside the RPM payload, but their provenance, offline behavior,
runtime smoke, final linked-license completeness, enablement, matrix proof,
and COPR publication remain incomplete.

## Native Source Boundary

The checked native-source contract binds the exact embedded librevenge 0.0.6,
libwpd 0.10.3, and Boost-subset archives used by `xberg-libwpd`, plus its 201
selected C++ translation units and expected `libxberg_libwpd.a` output. It also
binds `libz-sys` 1.1.29 and the selected stock zlib 1.3.2 sources for the
expected static `libz.a` path. This is source and build-intent evidence only:
compilation, archive production, `LIBZ_SYS_STATIC` observation, final ELF/link
evidence, RPM payload, native license payload, and final linked-license proof
remain false. The source contract now binds the canonical BSL-1.0 text shipped
by Fedora's Boost packages, but no RPM license payload is claimed.

## License Boundary

The tracked source-license receipt covers Source0 and the 1,034-source vendor
tree. It records 75 missing license-text gaps: 22 selected-normal and 53
resolver-only, with 74 distribution texts required. The source package
expression is source-payload coverage only; final binary linked-license proof
is not complete.

The source filter removes only the checked unsafe developer-machine link. The
Cargo auditor preserves deterministic safe extraction, the checked lock, the
full resolver vendor tree, and offline directory-source metadata/tree proof.
The proof auditor can regenerate both receipts from a prepared sanitized,
patched, lock-replaced source and extracted vendor tree without transient
research files. The checked Cargo license writer selects package `xberg-cli`
with no default features and the explicit `formats`, `analysis`, `core-cli`,
`embeddings`, `html`, `url-ingestion`, `liter-llm`, `ocr`, `paddle-ocr`,
`layout-detection`, and `chunking-tokenizers` tuple. It mirrors Fedora
cargo2rpm's normalized summary/breakdown format and conservative `--target=all`
scope while retaining the checked lock and offline vendor configuration. That
inventory is not final Linux linked-license or RPM payload evidence.

All `1.0.1` configured-SCM results and receipts are historical evidence only.
Release `1.0.3-0.5` retains the exact default-minus-tree-sitter source,
lock, vendor, provider, and license contracts; disables mutable tessdata
downloads; retains only explicit opt-in immutable model downloads; and adds
the deterministic native-source contract and its Boost license text without
claiming link or license-payload proof. Build
`10791299` exposed upstream's incomplete dynamic-Tesseract API gating before
linking; `0.3` extends that existing feature path without enabling source
downloads. No successful `1.0.3` compile proof exists yet. Xberg remains
blocked and COPR-disabled pending that proof plus native, model, runtime,
final-license, payload, and target-matrix evidence.
