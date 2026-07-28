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
No Cargo closure, Fedora provider mapping, bundled Provides, build receipt,
or final aggregate SPDX expression is recorded here.

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

The upstream project is Apache-2.0. The binary also contains axe-core under
MPL-2.0 and its retained third-party MIT/ISC notice boundary. The applicable
texts are present in the release source at
`cli/src/native/a11y/LICENSE-axe-core.txt` and
`cli/src/native/a11y/LICENSE-axe-core-THIRD-PARTY.txt`. Final linked Cargo
license accounting is intentionally pending.

Fedora exact-name and `/usr/bin/agent-browser` capability queries found no
provider for Fedora 43, Fedora 44, or Rawhide. RPM Fusion repositories were
not configured in the research environment, so the RPM Fusion result is
unavailable rather than an asserted absence.

The spec verifies the immutable source checksum and exits before unpacking
or building until the Cargo closure, licensing, installed skill layout, and
Chromium runtime checks are complete.
