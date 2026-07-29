# agent-browser Packaging Status

`agent-browser` `0.33.1` is a blocked Fedora source-package draft for the
native Rust browser automation CLI from `vercel-labs/agent-browser`.

The immutable `v0.33.1` tag resolves to commit
`6dcea79b4b567a5671f1e1164807204f69542a5c`. The official GitHub tag archive
has SHA-256
`313e7706485c246b818a2138dabc6f8784f91bfa25cae7db445e6ca14c730022` and its
top-level directory is `agent-browser-0.33.1/`.

The upstream Cargo package is `agent-browser` version `0.33.1` and produces
the `agent-browser` executable. Its Cargo lockfile SHA-256 is
`afa68d9dc97647e34be8ae1b62ae2a977dae0e09266e7780fd08ff17a4b74ffb`.
The checked source closure has 331 crates.io registry records. Offline locked
Cargo metadata selects 256 normal/build candidates for Linux x86_64 (247 normal
link candidates and 9 build-only candidates); 76 resolver-only records remain
in the vendor source because Cargo requires them for offline locked resolution.
The deterministic vendor archive is generated at configured-SCM/SRPM time and
is deliberately untracked. The checked closure, vendor receipt, license audit,
and `cargo-vendor.txt` are tracked inputs; no Fedora provider mapping is claimed.
The final aggregate SPDX expression is bound to the checked Fedora witness.
Fedora 44 x86_64 COPR
build `10785021` is a checked release-0.12 witness for production compilation,
install layout, 1,028 main tests, two doctor tests, ELF structure, and Chromium
`about:blank`. It does not prove a successful current 0.13 RPM or the remaining
target matrix.

The intended Fedora layout is a private package root at
`%{_libexecdir}/agent-browser`, containing `bin/agent-browser`, `skills/`,
and `skill-data/`, with `%{_bindir}/agent-browser` as the public command.
This preserves upstream executable-relative skill discovery without putting
private runtime data directly in `/usr/bin`.

The package must build the Rust binary from source. It must not use the npm
postinstall script or any upstream platform binary download, must not run
`agent-browser install` to download Chrome for Testing, and must not run
`agent-browser install --with-deps` or otherwise mutate packages during RPM
phases.

Fedora metadata for Fedora 43, Fedora 44, and Rawhide provides
`chromium-headless` with `/usr/lib64/chromium-browser/headless_shell` on both
architectures. The package wrapper selects that executable only when the user
has not supplied another browser, CDP endpoint, provider, or non-Chromium engine.
Full `chromium` remains an optional dependency selected automatically for
`--headed` when installed; an explicit path still overrides either default.
The target matrix must prove navigation, snapshot,
JavaScript evaluation, and URL retrieval against Fedora's differing Chromium
versions rather than pinning one browser build.

The upstream project is Apache-2.0. Embedded axe-core is MPL-2.0 with retained
MIT/ISC third-party notices, and embedded React DevTools has an MIT notice.
The exact applicable source texts are
`cli/src/native/a11y/LICENSE-axe-core.txt` and
`cli/src/native/a11y/LICENSE-axe-core-THIRD-PARTY.txt`, plus
`cli/src/native/react/installHook.js`. The source candidate expression is kept
in the generated license audit. The aggregate expression is checked, but the
installed-payload witness predates the new public wrapper. The corrected payload,
headless-default runtime, and remaining target matrix are still pending.

Fedora exact-name and `/usr/bin/agent-browser` capability queries found no
provider for Fedora 43, Fedora 44, or Rawhide. RPM Fusion repositories were
not configured in the research environment, so the RPM Fusion result is
unavailable rather than an asserted absence.

The still-blocked spec verifies the immutable source, lock, closure receipt,
license audit, vendor manifest, and source auditor before using Fedora Cargo
macros with the generated directory source. It installs only the application,
skills, skill data, and executable-relative public command, never a crate-devel
interface. The remaining gates are the headless-default runtime proof, Chromium
version compatibility across the configured matrix, and RPM Fusion availability.
