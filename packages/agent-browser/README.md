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
the generated vendor archive remains untracked. The final linked SPDX expression
and 264-record `LICENSE.dependencies` inventory are bound to the schema-v2
Fedora proof. Its SHA-256 is
`b232a66a487cfb5c45519501e9e7e7c5cc7dfbc879b181c8a0f2fc5e3a2e0e06`.

COPR builds `10785628` and `10785764` prove `agent-browser-0.33.1-0.14.src.rpm`
on Fedora 43, Fedora 44, and Rawhide for x86_64 and aarch64. Every cell passes
1,028 main tests and two doctor tests, retains 96 ignored tests, produces binary,
debuginfo, and debugsource RPMs, and confirms PIE, no RPATH/RUNPATH, and no
unresolved dependencies. The headless CDP checks cover navigation, snapshot,
runtime evaluation, and URL retrieval. Fedora 44 x86_64 uses chromium-headless
`150.0.7871.181`; the other five cells use `150.0.7871.186`, each matching its
reported `HeadlessChrome` user agent.

The layout keeps the native executable, `skills/`, and `skill-data/` below
`%{_libexecdir}/agent-browser`, with a public `%{_bindir}/agent-browser` wrapper.
The wrapper defaults to Fedora `chromium-headless` at
`/usr/lib64/chromium-browser/headless_shell`, preserves explicit browser/CDP/
provider/external-engine routing, and uses optional full `chromium` only for
`--headed` mode.

The package builds only from source. It never uses npm postinstall binaries,
Chrome for Testing downloads, `agent-browser install`, or package-manager
mutation during RPM phases.

The 2026-07-29 Fedora and RPM Fusion free/nonfree duplicate audit found zero
matches for `agent-browser`, `/usr/bin/agent-browser`, and
`/usr/libexec/agent-browser/bin/agent-browser` on all six targets. The retained
audit summary is
`/srv/tmp/agentlab-agent-browser-rpmfusion-20260729-v3-audit-summary.txt`.

The spec is now `0.15` solely because this final enablement changes the checked
proof hash. A new complete target-matrix rebuild is required after publication.
