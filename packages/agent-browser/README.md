# agent-browser Packaging Status

`agent-browser` `0.33.1` is an enabled Fedora source package for the native Rust
browser automation CLI from `vercel-labs/agent-browser`.

The immutable `v0.33.1` tag resolves to commit
`6dcea79b4b567a5671f1e1164807204f69542a5c`. The official archive SHA-256 is
`313e7706485c246b818a2138dabc6f8784f91bfa25cae7db445e6ca14c730022`; the
Cargo lockfile SHA-256 is
`afa68d9dc97647e34be8ae1b62ae2a977dae0e09266e7780fd08ff17a4b74ffb`.

The checked Cargo closure has 331 crates.io records: 256 Linux x86_64
normal/build candidates and 76 resolver-only records. The tracked closure,
vendor receipt, license audit, vendor manifest, and auditor are source inputs;
the generated vendor archive remains untracked. The static Fedora contract binds
the final linked SPDX expression and deterministic 264-record
`LICENSE.dependencies` inventory. Its inventory SHA-256 is
`b232a66a487cfb5c45519501e9e7e7c5cc7dfbc879b181c8a0f2fc5e3a2e0e06`.

Every enabled release requires a configured-SCM proof on Fedora 43, Fedora 44,
and Rawhide for x86_64 and aarch64. The proof must cover Cargo tests, payload and
ELF checks, and target-native headless Chromium navigation, snapshot, runtime
evaluation, URL retrieval, and close-session behavior. Current NVRs, build IDs,
browser versions, and outcomes remain in COPR and the canonical Agentlab wiki.

The layout keeps the native executable, `skills/`, and `skill-data/` below
`%{_libexecdir}/agent-browser`, with a public `%{_bindir}/agent-browser` wrapper.
The wrapper defaults to Fedora `chromium-headless` at
`/usr/lib64/chromium-browser/headless_shell`, preserves explicit browser/CDP/
provider/external-engine routing, and uses optional full `chromium` only for
`--headed` mode.

The package builds only from source. It never uses npm postinstall binaries,
Chrome for Testing downloads, `agent-browser install`, or package-manager
mutation during RPM phases.

Fedora and RPM Fusion free/nonfree duplicate audits are required for
`agent-browser`, `/usr/bin/agent-browser`, and
`/usr/libexec/agent-browser/bin/agent-browser` across every target family.
Current audit results and retained evidence remain in the canonical wiki.

Release `0.16` removes dynamic COPR IDs, result NVRs, and log hashes from package
inputs. The spec retains deterministic source, license, payload, ELF, wrapper,
and runtime checks, while current matrix identities remain in COPR and the
canonical wiki.
