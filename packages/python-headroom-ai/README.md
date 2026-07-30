# Headroom AI Packaging Status

`python-headroom-ai` tracks released Headroom `0.33.0` from the complete
published PyPI sdist. The 2,462,330-byte archive has SHA-256
`97d817e5923903d72bed24f75e0424e9cb7f86b3ddde0fc1acec4f3f85deeb5a`
and contains the selected Rust workspace, Python package, Rust tests, license,
notice, and release metadata.

Upstream places ONNX, FastEmbed, and Magika behind the default-on Rust
`ml` feature. The draft selects the non-ML application surface through one
packaging patch: it disables that dependency default and removes the unselected
ML and Redis dependency declarations so offline Cargo metadata does not require
their source closures. A separate compatibility patch selects Fedora's
system-SQLite `rusqlite 0.31` branch. The `0.33.0` sdist already limits the root
Cargo workspace to `headroom-core` and `headroom-py`, so the former downstream
workspace patch is removed. The package also replaces the PyPI-only ast-grep
binary wheel with Agentlab's source-built `ast-grep` package while preserving
the same `/usr/bin/ast-grep` command surface. The old custom feature graph, CLI
pruning, proxy suppression, tokenizer download changes, and companion test
patches remain removed.

Upstream excludes the compromised PyPI `ast-grep-cli 0.44.1` wheel. Agentlab
does not consume that wheel: its system `ast-grep` executable is built from the
reviewed upstream source tag. The Fedora substitution patch removes the Python
binary-wheel dependency without weakening the executable requirement.

The package selects upstream's full released base project plus its `mcp` extra
without restoring the former downstream MCP-only product fork. The installed
CLI, stdio and streamable-HTTP MCP transports, proxy/update/file-read paths, and
unconditional tokenizer `hf-hub` capability are documented runtime behavior;
RPM build phases remain offline. The selected extra now uses Agentlab's released
`python-mcp 1.28.1` provider because every current Fedora family remains below
Headroom's declared floor; Fedora 43 additionally uses the scoped
`python-jwt 2.13.0` compatibility provider. The native `ml` feature remains
disabled.

The `0.33.0` patches apply sequentially with zero fuzz. They retain the
non-ML upstream surface, system SQLite, complete Cargo tests, and installed
Python smokes while rebasing the ast-grep metadata substitution. The checks
fail unless the Rust CCR test binary links Fedora's system SQLite, the installed
Python SQLite backend opens a database, the extension has no RPATH/RUNPATH, the
package imports successfully, and the installed CLI help path runs. Fedora's
FastAPI package remains explicit because upstream CLI registration imports the
proxy request-scope module even when only the `mcp` extra is selected.

The selected `0.33.0` Cargo graph resolves 307 packages and contains 217 unique
package/version records across 391 target-all normal tree entries. It adds
ICU4X segmentation, the exact tree-sitter language grammars, crypto hashes,
dashmap, aho-corasick, and HTTP types while retaining the disabled ML/Redis
boundary. Cargo's metadata reports
`regex-syntax 0.8.11` as only `MIT OR Apache-2.0`, but the exact crate still
bundles generated Unicode tables and explicitly includes
`src/unicode_tables/LICENSE-UNICODE`. The selected aggregate therefore remains
`Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC
AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016`. The checked
`headroom-0.33.0-selected-cargo-license-audit.json` records all 217 selected
package/version/license tuples plus that Unicode supplement at SHA-256
`3f8a0af6f859a553b6619b531c000dc805a4a8ba785e60768d1343faad2b2d71`.
The spec checks that receipt as `Source1`, compares all 217 normalized records
with target-generated `LICENSE.dependencies` after stripping cargo2rpm's one
sibling-workspace build path, and installs the verified regex-syntax Unicode
text separately.

The current `0.33.0-0.1` release still requires the complete configured-SCM
six-cell build and non-installing runtime artifact proof. Target builds must
regenerate `LICENSE.dependencies`, run the Cargo and installed Python smokes,
and prove system SQLite plus extension ELF behavior. Historical `0.32.x`
results remain evidence only and are not active package inputs.

Historical Fedora 43 and Fedora 44 receipts remain evidence only; they do not
validate `0.33.0-0.1`. Released non-ML Headroom still requires
`tiktoken-rs 0.11`, its `fancy-regex 0.17` edge, and `unidiff 0.4`, so those
three compatibility records remain selected for the package. No produced RPM
was installed.
