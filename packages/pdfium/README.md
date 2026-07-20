# PDFium

This blocked package targets the PDFium source revision used by Chromium
`146.0.7678.0` and required by Kreuzberg LTS `4.10.2`. PDFium does not publish
a matching standalone release tag, so the RPM version identifies the published
Chromium release while the exact subordinate PDFium commit is recorded
separately as provenance.

GitHub Actions downloads Chromium's official `146.0.7678.0` lite archive,
verifies its published SHA-256, and generates one compact Source0 from the exact
PDFium, Chromium build/buildtools, Abseil, fast_float, and ICU trees. It removes
Chromium-provided GN and clang-format binaries, omits unbuilt test-font sources,
and verifies both the generated archive bytes and its exact safe tree. A staged
workflow attests every asset and byte-verifies a draft release; a separate
publish request rechecks the draft target, checksums, sizes, and attestations
before requiring GitHub release immutability. The RPM build consumes that
immutable Source0 without generation or network access and must not invoke
`gclient`, CIPD, GCS downloads, remote execution, or Chromium-provided binary
toolchains.

The draft builds versioned `libpdfium.so.146` plus private, collision-free
Abseil and ICU component libraries on native `x86_64` and `aarch64` targets.
The Fedora Clang patch selects each architecture's `redhat-linux-gnu` target and
compiler-rt directory. V8, XFA, Skia, Rust PNG, Fontations, PartitionAlloc,
tests, and corpora are disabled. Fedora provides GN, Ninja, Clang, and the
selected system image/font libraries. The Chromium release build files contain
two flags supported only by its newer bundled Clang; the Fedora toolchain patch
removes those flags while retaining array-bounds instrumentation and traps.
Local and clean Fedora 43 and 44 x86_64 builds passed with FPDF export, C API,
pkg-config, and extracted-payload consumer tests. Exact-current transient COPR
build `10737741` passed natively on Fedora 43 and 44 aarch64 with the same
checks, including the architecture-specific Clang target and compiler-rt path.

ICU data is embedded in the private ICU component rather than shipped as an
unlocated `icudtl.dat` file. The RPM installs PDFium, ICU, AGG, and consolidated
third-party license notices. The final embedded-data revision passed clean
Fedora 43 and 44 builds and extracted-payload validation. On July 20, 2026, the
maintainer accepted the private component names, versioned SONAMEs, and embedded
ICU-data ownership for the current package. The package remains blocked only
for approval of the subordinate source boundary pinned by the Chromium release.
The next source-hosting validation is an explicitly authorized configured-SCM
build in the primary `marcin/agentlab` COPR instead of another local Mock run.
