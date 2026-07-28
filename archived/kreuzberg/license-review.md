# Kreuzberg License Review

The final linked Rust and generated Node closure was audited from
`/srv/tmp/agentlab-kreuzberg/final-license-audit` and verified against selected
`4.10.2-0.0.5` COPR artifacts under
`/srv/tmp/agentlab-kreuzberg/final-proof-10739040-10739044`.

All `/srv/tmp` paths in this file are transient evidence references, not
distributable source locations.

- Aggregate SPDX: `Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CC0-1.0 AND CDLA-Permissive-2.0 AND ISC AND LicenseRef-Fedora-Public-Domain AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Unlicense AND WTFPL AND Zlib AND bzip2-1.0.6`.
- All observed identifiers are Fedora-allowed; 481 inventory lines and 394 unique package/license records were reviewed.
- Inventory JSON: `/srv/tmp/agentlab-kreuzberg/final-license-audit/inventory.json`, SHA-256 `ac03413603127cd136dad2a08db2d931041a5942ad4b88400f65e92e4eec4a73`.
- Shipped inventory SHA-256: `c447ec6454c45c6e0f0b2ae093b6fddcce539d3df65c7f69c3f6e5c0d969e965`.
- Audit script: `/srv/tmp/agentlab-kreuzberg/final-license-audit/audit_inventory.py`, SHA-256 `9f81527b1c144c02d862a42e19823d301222f82fcebc9a204b0739971e2c1177`.
- F43 x86_64 and aarch64 built inventories are byte-identical, contain 394
  nonblank dependency rows including `ahash v0.8.12`, and have SHA-256
  `cf0995a3d08bc32f73b286547804d4a6b4046aefc09b9a170b1347f55799f047`.
- The inspected F44 x86_64 built inventory also contains 394 nonblank rows and
  `ahash v0.8.12`; its SHA-256 is
  `3fb493c67dcf335d0a7cc6a49ad390b5d9597893e3b46dc053677e542185f18f`.
  Its only observed row difference from F43 is `tree-sitter-language v0.1.7`
  instead of `v0.1.5`.

The earlier plan to copy every crate-local and provider-RPM license file into a
runtime forensic corpus was superseded by project policy. The `0.0.5` spec uses
Fedora's standard workspace license macros and ships their dependency inventory
under `LICENSE.dependencies`; the aggregate expression is kept in the RPM
metadata. The exact F43/F44 builds regenerated nonempty inventories in all four
native chroots, and the inspected F43/F44 payloads contain `ahash`. Dynamic
PDFium and other system libraries remain package-boundary dependencies rather
than bundled components.

The published `napi`, `napi-sys`, and `napi-derive-backend` crates omit license
files; their source-package specs pin the same immutable upstream MIT text at commit
`dea608eae7481a47d64aab563a2ab5cdd8eda03c`, SHA-256
`3f1ce66533302df3a32edbfdfc0b78f0dd34659e4c1f5817162e5ea3c2297215`.

The parser subset is static and was present in the F44 closure as
`rust-tree-sitter-language-pack1-1.12.5-1.fc44` with these observed payload
hashes:

- base: `bb8faae752257cbc1ad042567104572f3e6acf717b07e9801f4507dd52e773fb`
- default: `8ec12a631e37fa91f76adfe571d36ed91190ff9774bc752cd62ed7115325ff84`
- serde: `a17619222a2a983e01b82fc49530b2e9c48577f27242f28548a86534deff992f`
- config: `9a732fc8c6f1b30eb4f318226e99ddd7a8df1fa3b32ade1f36c1c9b3c7ff070e`
- dynamic-loading: `646f954b8f05748d8e4da43b2a6dcdd764447f8746d2d9143a149b94b4ba00ff`
- download: `b18c709d7a6fb8fefaa07867949fee846612dacd9460c8377a7d262e6c6f5872`
- test-internals: `1e3390f7d407c58960527b31ba174c5ca132eeb3ca6e3da1efe17ea70b011aea`

The aggregate-expression and generated-inventory gate is resolved for the exact
application build. Full third-party license-text evidence, immutable source
hosting, supplemental N-API license publication, and PDFium release-boundary
decisions remain external blockers. Complete package-level rpmlint evidence was
not retained and is not inferred from successful builds.
