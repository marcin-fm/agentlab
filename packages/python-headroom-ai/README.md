# Headroom AI Packaging Status

`python-headroom-ai` tracks released Headroom `v0.32.0`, tag commit
`4381388d56f49af3ae9b1dece7489a12fa64a1a1`. PyPI publishes four wheels and no
sdist for this release, so the blocked draft uses the exact released commit
archive with SHA-256
`6bb138a038d9a74c3a9b51bcc593d996054cf9eca95fc39df9e0e80c3944ddce`.

Upstream `v0.32.0` places ONNX, FastEmbed, and Magika behind the default-on Rust
`ml` feature. The draft selects the non-ML application surface through one
packaging patch: it disables that dependency default and removes the unselected
ML and Redis dependency declarations so offline Cargo metadata does not require
their source closures. A separate compatibility patch selects Fedora's
system-SQLite `rusqlite 0.31` branch. A third packaging-only patch limits the
Cargo workspace to `headroom-core` and `headroom-py`, because Fedora cargo2rpm
0.3.3 otherwise inventories unrelated proxy, simulator, parity, ML, AWS, and
HTTP workspace members. The package also replaces the PyPI-only ast-grep binary
wheel with Agentlab's source-built `ast-grep` package while preserving the same
`/usr/bin/ast-grep` command surface. The old custom feature graph, CLI pruning, proxy
suppression, tokenizer download changes, and companion test patches are removed.

The package selects upstream's full released base project plus its `mcp` extra
without restoring the former downstream MCP-only product fork. The installed
CLI, stdio and streamable-HTTP MCP transports, proxy/update/file-read paths, and
unconditional tokenizer `hf-hub` capability are documented runtime behavior;
RPM build phases remain offline. The native `ml` feature remains disabled.

Release `0.9` succeeded in the complete configured Fedora 43, Fedora 44, and
Rawhide matrix on both architectures. Release `0.8` proved that maturin's
offline metadata pass still resolved unselected FastEmbed, so `0.9` narrows the
manifest to the selected closure. It also omits only the unavailable Criterion
dependency used by three benchmark targets; actual Cargo tests and installed
Python smokes remain enabled. Dynamic Python metadata uses the system ast-grep
dependency rather than a binary wheel. Its checks fail unless the Rust CCR test
binary links Fedora's system SQLite, the installed Python SQLite backend opens
a database, the extension has no RPATH/RUNPATH, the package imports
successfully, and the installed CLI help path runs. Fedora's FastAPI package is
required explicitly because upstream CLI registration imports the proxy
request-scope module even when only the `mcp` extra is selected.

The generated dependency inventory from build `10770364` exposed an aggregate
license omission: `regex-syntax 0.8.11` requires
`(MIT OR Apache-2.0) AND Unicode-DFS-2016`. Release `0.10` makes only that
metadata correction. The selected aggregate expression is
`Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC
AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016`. Target builds
regenerate the dependency inventory through standard Cargo license accounting.

The release `0.9` Fedora 44 x86_64 Mock proof passes the complete build, 936
Cargo tests and doctests, system-SQLite and installed Python smokes, and
artifact checks. Its configured-SCM build passed all six cells; the runtime RPM
`rpmlint` has no errors and only the missing-manpage warning. The local `0.10`
source RPM is SHA-256
`9b371be9f5172a0caed93bce621b6ade958765019d31030a5c0f511870a2d389` and
passes source-member, aggregate-license, and `rpmlint` checks. Release `0.10`
still requires the same six-cell rebuild and non-installing runtime artifact
proof for the corrected metadata.

Historical Fedora 43 and Fedora 44 `0.31.0-0.1` receipts remain evidence only;
they do not validate `0.32.0-0.10`. Released non-ML Headroom still requires
`tiktoken-rs 0.11`, its `fancy-regex 0.17` edge, and `unidiff 0.4`, so those
three compatibility records remain selected for the package. No produced RPM
was installed.
