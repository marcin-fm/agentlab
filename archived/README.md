# Archived Packages

This directory retains package history that is no longer active in Agentlab.
Archived package trees are excluded from active package validation, updates,
builds, and COPR reconciliation. Repository checks still validate each archive's
manifest identity and retirement record.

Retire a package with `scripts/retire-package`; mutation requires `--apply`.
The applied command removes its COPR package definition, moves the complete
directory from `packages/<name>` to `archived/<name>`, and records
`retirement.yml` with the reason and configured chroots at retirement.

Do not copy an active package here or leave duplicate active and archived
directories. Restore an archived package only after a new Fedora/RPM Fusion
availability and dependency review establishes that Agentlab must maintain it
again.
