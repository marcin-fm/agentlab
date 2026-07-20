# RTK License Review

RTK `0.43.0-0.6` was clean-built on Fedora 44 with Fedora's `dirs 6.0.0` and
`dirs-sys 0.5.0` providers. The build produced a 114-record linked dependency
inventory. The retained historical
repository-side provider receipt contains 370 rows: one RTK workspace row and
369 owning Fedora binary-package rows. Those rows resolve to 117 source RPMs on
Fedora 43 and 116 on Fedora 44; those receipts predate the `dirs 6` migration
and remain repository-side historical evidence only.

The recorded aggregate expression is:

`Apache-2.0 AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib`

All selected identifiers are Fedora-allowed. The historical
`LICENSE.dependencies` has SHA-256
`4a9661effe7b75e05207d312e9dd4c4b789037a580194b4b2b3bdbbbe221ccaf`.
The provider receipts have SHA-256
`f119ad6c076946bb224edf08d53095e318d08298f5a01233fe4b2c815b76b6be`
for Fedora 43 and
`3394d9f72b0d552a051dcf068cdbdf73073f55ce9083fe2c6fae875107e10c53`
for Fedora 44. Every inventory crate/version pair has a matching provider row.
These receipts remain audit evidence in the repository and are not installed in
the runtime RPM.

Release `0.43.0-0.5` removes the custom collector, `CARGO-PROVIDERS.tsv`, and
`THIRD-PARTY-LICENSES` from the runtime payload. No selected linked license was
identified as requiring a package-specific copy of a system provider's license
directory. The package retains the upstream `LICENSE`, the aggregate SPDX
expression, and Fedora's standard macro-generated `LICENSE.dependencies`.

Fedora's `dirs 6` and `dirs-sys 0.5` packages provide the same MIT and
Apache-2.0 license classes already represented by RTK's aggregate expression.
The current Fedora 44 build passed 2,245 tests with eight ignored. Artifact
`rpmlint` reports zero errors and only the expected missing-man-page warning;
the extracted binary retains system SQLite linkage and passes the runtime and
isolated-home directory API smokes. Full configured-matrix results remain the
publication and compatibility-package retirement gate.
