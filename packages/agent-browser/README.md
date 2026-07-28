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
and `cargo-vendor.txt` are tracked inputs; no bundled Provides, Fedora provider
mapping, compilation receipt, or final aggregate SPDX expression is claimed.

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

Fedora metadata for Fedora 43, Fedora 44, and Rawhide provides the `chromium`
package with `/usr/bin/chromium-browser`; `chromium-headless` provides
`/usr/lib64/chromium-browser/headless_shell`. The intended normal dependency
is `chromium` because upstream autodetects `chromium-browser`; the headless
path remains an explicit-path alternative. Runtime browser smokes remain
unverified.

The upstream project is Apache-2.0. Embedded axe-core is MPL-2.0 with retained
MIT/ISC third-party notices, and embedded React DevTools has an MIT notice.
The exact applicable source texts are
`cli/src/native/a11y/LICENSE-axe-core.txt` and
`cli/src/native/a11y/LICENSE-axe-core-THIRD-PARTY.txt`, plus
`cli/src/native/react/installHook.js`. The source candidate expression is kept
in the generated license audit. Final linked Cargo and installed-payload license
flags remain false until a compilation proof exists.

Fedora exact-name and `/usr/bin/agent-browser` capability queries found no
provider for Fedora 43, Fedora 44, or Rawhide. RPM Fusion repositories were
not configured in the research environment, so the RPM Fusion result is
unavailable rather than an asserted absence.

The still-blocked spec verifies the immutable source, lock, closure receipt,
license audit, vendor manifest, and source auditor before using Fedora Cargo
macros with the generated directory source. It installs only the application,
skills, skill data, and executable-relative public command, never a crate-devel
interface. The remaining gates are a Fedora/COPR compilation proof, final link
and payload accounting, installed skill-layout proof, and Chromium runtime smoke.
