# PDFium

This blocked package targets the PDFium source revision used by Chromium
`146.0.7678.0` and required by Kreuzberg LTS `4.10.2`. PDFium does not publish
a matching standalone release tag, so the RPM version identifies the published
Chromium release while the exact subordinate PDFium commit is recorded
separately as provenance.

The source closure is generated with deterministic `git archive` output. This
is required because repeated downloads from Gitiles `+archive` produce
different gzip bytes for the same commit. The RPM build must not invoke
`gclient`, CIPD, GCS downloads, remote execution, or Chromium-provided binary
toolchains.

The x86_64 proof builds versioned `libpdfium.so.146` plus private, collision-free
Abseil and ICU component libraries. V8, XFA, Skia, Rust PNG, Fontations,
PartitionAlloc, tests, and corpora are disabled. Fedora provides GN, Ninja,
Clang, and the selected system image/font libraries. Local and clean Fedora 43
and 44 builds passed with FPDF export, C API, pkg-config, and extracted-payload
consumer tests.

ICU data is embedded in the private ICU component rather than shipped as an
unlocated `icudtl.dat` file. The RPM installs PDFium, ICU, AGG, and consolidated
third-party license notices. The final embedded-data revision passed clean
Fedora 43 and 44 builds and extracted-payload validation. The private component
names, versioned SONAMEs, and embedded ICU-data ownership form a Fedora-specific
package, ABI, and runtime boundary that still requires explicit approval. The
package remains blocked for that review, immutable public source hosting,
approval of the subordinate source boundary pinned by the Chromium release,
and future aarch64 proof.
