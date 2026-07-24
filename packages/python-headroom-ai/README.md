# Headroom AI Packaging Status

`python-headroom-ai` tracks released Headroom `v0.32.0`, tag commit
`4381388d56f49af3ae9b1dece7489a12fa64a1a1`. PyPI publishes four wheels and no
sdist for this release, so the blocked draft uses the exact released commit
archive with SHA-256
`6bb138a038d9a74c3a9b51bcc593d996054cf9eca95fc39df9e0e80c3944ddce`.

Upstream `v0.32.0` places ONNX, FastEmbed, and Magika behind the default-on Rust
`ml` feature. The draft disables that dependency default through one narrow
`headroom-py` patch and selects Fedora's system-SQLite `rusqlite 0.31` branch
through a separate compatibility patch. A third packaging-only patch limits the
Cargo workspace to `headroom-core` and `headroom-py`, because Fedora cargo2rpm
0.3.3 otherwise inventories unrelated proxy, simulator, parity, ML, AWS, and
HTTP workspace members. The old custom feature graph, CLI pruning, proxy
suppression, tokenizer download changes, and companion test patches are removed.

The package selects upstream's full released base project plus its `mcp` extra
without restoring the former downstream MCP-only product fork. The installed
CLI, stdio and streamable-HTTP MCP transports, proxy/update/file-read paths, and
unconditional tokenizer `hf-hub` capability are documented runtime behavior;
RPM build phases remain offline. The native `ml` feature remains disabled.

Release `0.8` is enabled for the exact configured target proof. It removes only
the unavailable Criterion dependency used by three benchmark targets; actual
Cargo tests and installed Python smokes remain enabled. Its checks fail
unless the extension links Fedora's system SQLite without RPATH/RUNPATH, imports
successfully from the installed buildroot, and runs the installed CLI help path.
A scoped source probe found 240 target-all package/version records and 207
license-breakdown entries, producing the selected aggregate expression
`Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC
AND MIT AND MPL-2.0 AND Unicode-3.0`. Target builds regenerate the dependency
inventory through standard Cargo license accounting.

Historical Fedora 43 and Fedora 44 `0.31.0-0.1` receipts remain evidence only;
they do not validate `0.32.0-0.8`. Released non-ML Headroom still requires
`tiktoken-rs 0.11`, its `fancy-regex 0.17` edge, and `unidiff 0.4`, so those
three compatibility records remain selected for the package. No
produced RPM was installed.
