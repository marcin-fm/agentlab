# RTK License Review

RTK `0.43.0-2` was clean-built from the current repository package on Fedora
43 and Fedora 44. Both builds produced the same 114-record linked dependency
inventory. The exact provider receipt contains 370 rows: one RTK workspace row
and 369 owning Fedora binary-package rows. Those rows resolve to 117 source
RPMs on Fedora 43 and 116 on Fedora 44; Fedora 44 uses the local `dirs` `5.0.1`
and `dirs-sys` `0.4.1` compatibility packages.

The recorded aggregate expression is:

`Apache-2.0 AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib`

All selected identifiers are Fedora-allowed. `LICENSE.dependencies` has SHA-256
`efe3c0966d0d745513ed61c0699a0240ac14b19287e6d99b9e18f6b337c8646b`.
The provider receipts have SHA-256
`f119ad6c076946bb224edf08d53095e318d08298f5a01233fe4b2c815b76b6be`
for Fedora 43 and
`3394d9f72b0d552a051dcf068cdbdf73073f55ce9083fe2c6fae875107e10c53`
for Fedora 44. Every inventory crate/version pair has a matching provider row.

`collect-cargo-licenses.py` fails closed when a linked registry crate lacks
crate-local or owning-RPM license evidence. The final payload contains 218
checksummed evidence entries. Both extracted payloads passed complete manifest
verification; `MANIFEST.sha256` has SHA-256
`60dd1535a4d25b4bc2352d5b43f13e00f7ff419b924648662a012dc111fe41b1`.
Byte-identical texts retain every per-crate path but use hard links: 146 paths
in 21 groups remove 754,181 duplicate bytes and pass `rpmlint`.

The `dirs` and `dirs-sys` compatibility source packages ship their own MIT and
Apache-2.0 texts. Their licenses are represented in RTK's linked closure when
those compatibility packages are selected by Fedora 44. Both final chroot
builds passed 2,287 tests with eight ignored and zero `rpmlint` errors.
