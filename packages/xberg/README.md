# Xberg

This is a blocked source-package draft for upstream Xberg `1.0.1`, tag commit
`60557740a675908ea8d27145841dafd4f6a06917` and source tree
`19705db11615dd4d1722dec9224c3b752cd369af`.

The official tag archive is Source0 with SHA-256
`a2e3ac73c051476625ec3f540c523553be2086282d3808c3f32979067a070ee6`. Upstream
defines the Rust `xberg` library and `xberg-cli` workspace members, and the
Node binding is `@xberg-io/xberg`; these are not equivalent to the former
Kreuzberg 4.10.2 package surface.

The spec exits in `%prep` after source verification. No old Kreuzberg patches,
dependency closure, generated receipts, or build results are presented as
Xberg evidence. A complete literal copy of the former package is retained at
`historical/kreuzberg-4.10.2/` for historical purposes only.

The exact dependency overlap, version comparison, and any retirement of former
Kreuzberg-only dependency packages are a separate follow-up audit.

## Source Link Filter

`xberg-1.0.1-source-filter.json` is Source9 and records the complete reviewed
unsafe-link set from the exact release tag: 51 symlinks and no hardlinks, with
one mode-`120000` absolute symlink,
`xberg-1.0.1/e2e/test_documents`. The generic extractor and `%prep` sanitizer
compare every unsafe archive/tree link to this receipt before omitting only an
exact match. The omitted developer-machine e2e fixture is outside the selected
default `xberg-cli` build/runtime source surface; ordinary in-root e2e links are
retained. Unknown, missing, or changed unsafe links fail closed.

## Source Audit Receipt

`xberg-1.0.1-source-audit.json` is a checked `Source1` receipt (SHA-256
`cb49f4c4a035795e87f0eedf0fee219bfde506347b085cbb7dfb6b6a0b97e12a`). It records
the selected Rust CLI workspace and default feature surface, excludes the Node
binding and `xberg-gliner`, and keeps all closure, provider, native, license,
build, matrix, enablement, publication, and retirement gates false. The prior
offline metadata attempt stopped on missing `auto_enums 0.8.10`; this receipt is
source-side scope evidence, not a completed Cargo closure or build result.
The 45 reusable and 17 retirement-candidate values are unrevalidated prior-audit
counts. Its 63-row/42-pair root-lock cross-check proves lock presence only, not
selected Xberg consumption, and authorizes no retirement.

## System ONNX Runtime Source Audit

`xberg-1.0.1-system-ort-audit.json` is a checked `Source2` receipt (SHA-256
`a68aa83911e275096845d17ad526277440ce04b9bc97bf6f918d226f5e882460`). Its two
separate zero-fuzz patches preserve all default `xberg-cli` features while
switching the three default-reachable ORT feature edges to upstream
`ort-dynamic`, then add Fedora `/usr/lib64/libonnxruntime.so` discovery. The
locked/offline proof retains 610 normal-edge packages before and after the
patch; its normal/build/dev union drops only the downloader-only
`hmac-sha256 1.1.14` and `lzma-rust2 0.15.8` packages, from 631 to 629.

This is source-only integration evidence. Vendor delivery, Fedora provider
matrix, compilation, ORT runtime smoke, model/license and aggregate-license
review, enablement, COPR, and retirements remain blocked.

## Cargo Source Contract

The configured-SCM materializer checks the patched default `xberg-cli` Linux
`x86_64` Cargo closure and writes only the ignored transport archive. Its four
tracked receipts bind 604 selected registry identities, 529 resolver-only
identities, the complete 1,133-record root-lock registry source, a 610 normal /
629 normal-build-dev graph, no Git dependencies, the `-2` ORT downloader delta,
and the canonical 57,079-file vendor tree SHA-256
`b0d603d84a23e6f58590660220edf82bfc5152269419abb7084fd831bb4762f2`.
The v2 closure hashes each selected graph as sorted unique UTF-8
`name\tversion\n` identity lines, rather than environment-sensitive raw Cargo
tree traversal text.

The source-level text inventory finds texts in 1,043 vendor directories and no
recognized text in 90. This is not final linked-license completeness; all 90
gaps remain publication blockers. Fedora's workspace-wide
`%cargo_vendor_manifest` has different feature semantics, so `%prep` checks the
root-lock manifest through the auditor rather than making a false comparison.

The generic archive reader validates GNU long-name/link and POSIX PAX per-entry/global
records before applying path, link, duplicate, root, and source-filter checks.
Malformed, dangling, or conflicting extension records fail closed; no crate-specific
extraction exception is used.

Configured-SCM COPR proof build `10786324` generated the 13-member
`xberg-1.0.1-0.15.src.rpm`, 195,601,069 bytes at SHA-256
`9da0f4b96a2c125cdc2ac83031b3776d26108c92e69e1e43e9361cc293168971`.
Fedora 44 x86_64 `%prep` verified every source hash, the checked unsafe-link
filter, both system-ORT patches, the complete vendor tree, and Cargo's offline
directory-source configuration before reaching the intentional blocker. This is
source-delivery proof only; no Cargo compilation or binary RPM was produced or
installed. The temporary blocked proof package definition was deleted afterward.

## Duplicate Checks

Read-only DNF5 queries found no Fedora package named `xberg` and no provider for
`/usr/bin/xberg` in Fedora 43, Fedora 44, or Rawhide. The complete query output
is retained under `/srv/tmp/agentlab-xberg-fedora*-query.txt`.

RPM Fusion could not be queried: no RPM Fusion repository or repository package
is configured in this environment. The package remains blocked until that
duplicate check is available and complete.
