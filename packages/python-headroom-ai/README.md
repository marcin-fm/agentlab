# Headroom AI Packaging Status

`python-headroom-ai` tracks released Headroom `0.32.1` from the complete
published PyPI sdist. The 2,277,688-byte archive has SHA-256
`329dda3328f0fb45ec7128353f7fc9108f08e9676c9dc1873b4841c5c00c94bd`
and contains the selected Rust workspace, Python package, Rust tests, license,
notice, and release metadata.

Upstream places ONNX, FastEmbed, and Magika behind the default-on Rust
`ml` feature. The draft selects the non-ML application surface through one
packaging patch: it disables that dependency default and removes the unselected
ML and Redis dependency declarations so offline Cargo metadata does not require
their source closures. A separate compatibility patch selects Fedora's
system-SQLite `rusqlite 0.31` branch. The `0.32.1` sdist already limits the root
Cargo workspace to `headroom-core` and `headroom-py`, so the former downstream
workspace patch is removed. The package also replaces the PyPI-only ast-grep
binary wheel with Agentlab's source-built `ast-grep` package while preserving
the same `/usr/bin/ast-grep` command surface. The old custom feature graph, CLI
pruning, proxy suppression, tokenizer download changes, and companion test
patches remain removed.

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

The selected `0.32.1` Cargo graph resolves 296 packages, with 272 packages in
the target-all normal dependency closure. Cargo's metadata reports
`regex-syntax 0.8.11` as only `MIT OR Apache-2.0`, but the exact crate still
bundles generated Unicode tables and explicitly includes
`src/unicode_tables/LICENSE-UNICODE`. The selected aggregate therefore remains
`Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC
AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016`. Target builds
regenerate the dependency inventory through standard Cargo license accounting.

The prior `0.32.0-0.10` configured-SCM build `10770459` passed Fedora 43,
Fedora 44, and Rawhide on both architectures. Its Fedora 44 x86_64 runtime RPM
has SHA-256 `db2c6905c6179f4b3f799f27e251714a7e9fd0d1ced18bfa52ed63612f128b66`,
and its generated `LICENSE.dependencies` has SHA-256
`b76c43d8881c07cfca9dfca078d6eb3599d45241c40f46f7e23c56cae97e7770`.
The local `0.32.1-0.1` source RPM has SHA-256
`2d608c7ac37dec579ad6340dec474622082d7893cb8e0ce5dadb9d3635549dc8`,
contains exactly the sdist, four patches, and spec, and has zero `rpmlint`
errors or warnings. The new release still requires the complete configured-SCM
six-cell build and non-installing runtime artifact proof.

Historical Fedora 43 and Fedora 44 receipts remain evidence only; they do not
validate `0.32.1-0.1`. Released non-ML Headroom still requires
`tiktoken-rs 0.11`, its `fancy-regex 0.17` edge, and `unidiff 0.4`, so those
three compatibility records remain selected for the package. No produced RPM
was installed.
