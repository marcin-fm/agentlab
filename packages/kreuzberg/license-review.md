# Kreuzberg License Review

The final linked Rust and generated Node closure was audited from
`/srv/tmp/agentlab-kreuzberg/final-license-audit`.

All `/srv/tmp` paths in this file are transient evidence references, not
distributable source locations.

- Aggregate SPDX: `Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CC0-1.0 AND CDLA-Permissive-2.0 AND ISC AND LicenseRef-Fedora-Public-Domain AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib AND bzip2-1.0.6`.
- All observed identifiers are Fedora-allowed; 481 inventory lines and 394 unique package/license records were reviewed.
- Inventory JSON: `/srv/tmp/agentlab-kreuzberg/final-license-audit/inventory.json`, SHA-256 `ac03413603127cd136dad2a08db2d931041a5942ad4b88400f65e92e4eec4a73`.
- Shipped inventory SHA-256: `c447ec6454c45c6e0f0b2ae093b6fddcce539d3df65c7f69c3f6e5c0d969e965`.
- Audit script: `/srv/tmp/agentlab-kreuzberg/final-license-audit/audit_inventory.py`, SHA-256 `9f81527b1c144c02d862a42e19823d301222f82fcebc9a204b0739971e2c1177`.

The review remains a publication blocker because full third-party license text
evidence was not shipped in the audited payload, and the external audit host
could not replay the Cargo tree without Fedora registry sources. Dynamic PDFium
and the static parser subset are recorded at the package boundary, not included
in this aggregate.

The current repository collector now queries every RPM owner independently and
is intended to ship the collected full-text evidence. Its SHA-256 is
`c6b273d9a9961ab6ffa3bf0b4936f23c89b60ca782ca10949ab6fecc1dc1fb5a`,
but no new full application build was run, so the historical audited payload is
not upgraded by this static correction alone. The published `napi`, `napi-sys`,
and `napi-derive-backend` crates omit license files; their current specs pin the
same immutable upstream MIT text at commit
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

Source hosting and release-boundary decisions remain external blockers.
