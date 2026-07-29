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

## Duplicate Checks

Read-only DNF5 queries found no Fedora package named `xberg` and no provider for
`/usr/bin/xberg` in Fedora 43, Fedora 44, or Rawhide. The complete query output
is retained under `/srv/tmp/agentlab-xberg-fedora*-query.txt`.

RPM Fusion could not be queried: no RPM Fusion repository or repository package
is configured in this environment. The package remains blocked until that
duplicate check is available and complete.
