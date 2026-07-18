# RTK License Review

RTK `0.43.0-0.2` was clean-built on Fedora 43 and Fedora 44. Both historical
builds produced the same 114-record linked dependency inventory. The retained
repository-side provider receipt contains 370 rows: one RTK workspace row and
369 owning Fedora binary-package rows. Those rows resolve to 117 source RPMs on
Fedora 43 and 116 on Fedora 44; Fedora 44 uses the local `dirs` `5.0.1` and
`dirs-sys` `0.4.1` compatibility packages.

The recorded aggregate expression is:

`Apache-2.0 AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib`

All selected identifiers are Fedora-allowed. The historical
`LICENSE.dependencies` has SHA-256
`efe3c0966d0d745513ed61c0699a0240ac14b19287e6d99b9e18f6b337c8646b`.
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

The `dirs` and `dirs-sys` compatibility source packages ship their own MIT and
Apache-2.0 texts. Their licenses remain represented in RTK's aggregate linked
closure when those compatibility packages are selected by Fedora 44. The
historical chroot builds passed 2,287 tests with eight ignored and zero
`rpmlint` errors; current matrix results are recorded separately after rebuild.
