# RTK License Review

RTK `0.44.1` has an exact expected cargo2rpm target-summary contract. The first
target attempt emitted the same 17 sorted raw declarations on Fedora 43,
Fedora 44, and Rawhide for both architectures, but failed because the spec
incorrectly compared that framed summary with a simplified aggregate.

## Current 0.44.1 Contract

The checked raw declarations are:

```text
(MIT OR Apache-2.0) AND Unicode-DFS-2016
0BSD OR MIT OR Apache-2.0
Apache 2.0
Apache-2.0 AND ISC AND (MIT OR Apache-2.0)
Apache-2.0 OR ISC OR MIT
Apache-2.0 OR MIT
Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT
BSD-3-Clause
CDLA-Permissive-2.0
ISC
MIT
MIT OR Apache-2.0
MIT OR Zlib OR Apache-2.0
MPL-2.0
Unicode-3.0
Unlicense OR MIT
Zlib
```

Normalize the exact raw `Apache 2.0` declaration to `Apache-2.0`, preserve
every `OR` choice, parenthesize each compound expression, and join all selected
expressions with `AND`. The resulting RPM expression is:

`((MIT OR Apache-2.0) AND Unicode-DFS-2016) AND (0BSD OR MIT OR Apache-2.0) AND Apache-2.0 AND (Apache-2.0 AND ISC AND (MIT OR Apache-2.0)) AND (Apache-2.0 OR ISC OR MIT) AND (Apache-2.0 OR MIT) AND (Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT) AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND (MIT OR Apache-2.0) AND (MIT OR Zlib OR Apache-2.0) AND MPL-2.0 AND Unicode-3.0 AND (Unlicense OR MIT) AND Zlib`

All identifiers are Fedora-allowed. The summary is expected output, not final
payload proof: a successful target build must still reproduce it, generate and
install `LICENSE.dependencies`, and pass the complete package/runtime matrix.

## Historical 0.43.0 Evidence

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

Release `0.43.0-0.5` removed the custom collector, `CARGO-PROVIDERS.tsv`, and
`THIRD-PARTY-LICENSES` from the runtime payload. No selected linked license was
identified as requiring a package-specific copy of a system provider's license
directory. The package retains the upstream `LICENSE`, the aggregate SPDX
expression, and Fedora's standard macro-generated `LICENSE.dependencies`.

Fedora's `dirs 6` and `dirs-sys 0.5` packages provide the same MIT and
Apache-2.0 license classes already represented by RTK's aggregate expression.
The historical Fedora 44 build passed 2,245 tests with eight ignored. Artifact
`rpmlint` reports zero errors and only the expected missing-man-page warning;
the extracted binary retains system SQLite linkage and passes the runtime and
isolated-home directory API smokes. Full configured-matrix results remain the
publication and compatibility-package retirement gate for the current release.
