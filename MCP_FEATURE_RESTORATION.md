# MCP Feature Restoration Matrix

Research date: 2026-07-17

This matrix governs restoration of capabilities removed from the bounded Fedora
MCP packages. A feature is not restored merely because upstream ships it. It
must have a released source closure, Fedora-compatible dependencies, an offline
test, and a security boundary that does not silently widen the base package.

Status meanings:

- `hold`: prior packaging evidence exists, but updated downstream-change policy
  prohibits rebuild or publication until the remediation backlog is resolved or
  explicit maintainer approval is recorded.
- `restored`: available only through a validated explicit optional package; the
  base package and its defaults remain unchanged.
- `blocked`: potentially packageable, but one or more source, dependency,
  offline-build, model, browser, or security gates remain.
- `rejected`: intentionally outside the package boundary; reconsider only after
  a new packaging and security review.
- `retained`: already present in the validated minimal package.

## Docling

| Capability | Exact source and dependency edge | Fedora 43/44 and RPM Fusion status | Missing reusable packages | System/native implications | Runtime network/model behavior | License/source closure | Smallest offline test | Outcome |
|---|---|---|---|---|---|---|---|---|
| Remote single-document conversion | `docling_mcp/tools/conversion.py:convert_document_into_docling_document`, ported without `tools/converters/factory.py`; `docling-slim[service-client]`, `pydantic-settings` | No Docling MCP or Serve duplicate; HTTPX, pydantic-settings, and WebSockets are available; RPM Fusion has no duplicate | No client-side package is missing; an administrator-operated Docling Serve is external | Pure-Python client; no local PDF parser, OCR, Torch, or model stack | Outbound only to explicit `DOCLING_SERVICE_URL`; polling only; upload requires an explicit `DOCLING_SERVICE_UPLOAD_ROOT` and is limited to non-symlink regular files beneath it; URL-source fetch is denied; input and artifact limits are 64 MiB | Exact MIT `docling-mcp 2.1.0` sdist and MIT `docling-slim 2.113.0` source are recorded and checksummed | Fake loopback Serve plus stdio MCP initialize/list/call/cache smoke; prove root/traversal/size rejection, base exclusion, and no local-converter imports | **hold**: historical F43/F44 validation passed, but the downstream adapter adds source files and is under substantive-rework review; do not rebuild or publish without upstream support or explicit approval |
| Local document conversion | `tools/converters/local.py`, `docling.document_converter`, docling-slim standard/local extras | No exact Docling parser/model providers; no standalone Fedora `libpdfium.so`; RPM Fusion has no match | `docling-parse`, compatible pypdfium2/PDFium resources, `docling-ibm-models`, immutable model packages, and OCR/model dependencies | C++ PDF parser, PDFium, Torch/Transformers/OCR, and architecture-specific model/runtime work | Local inference may acquire models unless every weight is packaged and downloads are disabled | Application source is known; parser, native, model-weight, and per-model license closure is incomplete | Convert one packaged PDF entirely offline with network denied and immutable local weights | **blocked** |
| Directory conversion | `tools/conversion.py:convert_directory_files_into_docling_document` and converter factory | Same provider state as remote/local conversion | Requires a safe bulk-upload policy in addition to the selected client stack | Traverses and uploads multiple host files | Materially widens filesystem disclosure, file-count, and aggregate-size exposure | Upstream source is known; security policy is not closed | Explicit allowed-root fixture with symlink, count, size, and traversal rejection tests | **rejected** from the current wave |
| HTML-table creation | `tools/generation.py:add_table_in_html_format_to_docling_document` lazily imports the local converter | Blocked with local conversion | Same local conversion providers | Pulls the excluded parser/converter branch | Local processing may activate parser/model paths | Source known; dependency closure incomplete | List tools and prove the helper remains absent | **blocked** with local conversion |
| Milvus/LlamaIndex RAG | `tools/llama_index/milvus_rag.py`; LlamaIndex, Milvus, embedding providers | Exact application providers not found in Fedora/RPM Fusion | LlamaIndex/Milvus integration packages and deterministic embedding/model packages | Vector database and embedding stack | External database and likely model/API traffic | Model and transitive source/license closure incomplete | Fake vector store with packaged deterministic local embedding fixture | **blocked** |
| Llama Stack RAG and extraction | `tools/llama_stack/{rag.py,structured_output.py}`; `llama-stack-client`, tokenizer/inference providers | Exact providers not found | Llama Stack client plus local tokenizer/model or reviewed remote API closure | Tokenizer/model runtime | Vector DB and inference endpoint traffic; upstream path may call `from_pretrained` | Model/API/source closure incomplete | Fake endpoint plus preseeded tokenizer and fixed JSON response | **blocked** |
| HTTP, SSE, and streamable-HTTP MCP transports | `servers/mcp_server.py:TransportType` and FastMCP listener/session surfaces | Python MCP exists, but its network/session advisories are outside the accepted stdio review | None | Opens network listeners and session state | Remotely reachable MCP transport | Upstream source known; package security boundary would change | Bind/auth/origin/session/advisory review with network tests | **rejected**; package remains stdio-only |
| Smolagents and Mellea extras | `pyproject.toml` optional dependencies; no registered 2.1.0 tool group | Exact stacks not established | Torch/Transformers/Accelerate/Ollama or Mellea closure | Large model/inference surface | Local or remote model execution | Not part of the released MCP tool surface being packaged | No applicable MCP tool smoke | **rejected** |
| Upstream Docling CLI wrappers | `docling/cli/{main.py,tools.py,remote.py}` in docling-slim | Common CLI dependencies exist, but wrappers import the excluded pypdfium2 path | Local conversion closure | CLI help itself reaches local-conversion imports | Remote CLI can contact Serve; local wrappers may activate model/parser paths | Source known; executable boundary is not cleanly separable upstream | Installed `--help` with import tracing and no local converter | **rejected** from base; a purpose-built remote launcher is used instead |

## Headroom

| Capability | Exact source and dependency edge | Fedora 43/44 and RPM Fusion status | Missing reusable packages | System/native implications | Runtime network/model behavior | License/source closure | Smallest offline test | Outcome |
|---|---|---|---|---|---|---|---|---|
| Compression, retrieval, and statistics | Downstream `mcp-minimal` surface in `python-headroom-ai 0.31.0`; system SQLite and `rust-unidiff0.4` | Historical local providers exist; no exact Fedora/RPM Fusion Headroom duplicate | Upstream's released native graph still requires unavailable FastEmbed/Magika/model-related closure | Source-built native extension; prior draft dynamically linked system SQLite | Prior package was local stdio only | Historical source receipts exist, but aggregate SPDX accounting for the statically linked Rust closure is incomplete | Existing three-tool stdio round trip | **hold**: released upstream has no feature flag for the reduced graph, and the custom feature design is under substantive-rework review |
| Rust exact tokenization | `tiktoken-rs = 0.11` is unconditional upstream but was made optional by the held feature redesign | No exact Fedora/RPM Fusion provider found; Fedora's `fancy-regex` branch is older than required 0.17 | Drafts `rust-fancy-regex0.17` and `rust-tiktoken-rs0.11` | Pure Rust tokenizer implementation | Local only; fixed encodings require no model download | Released MIT sources and asset hashes are recorded | Fixed text/token fixture compared with the released reference implementation | **blocked** as dependent-scope evidence; no builds until an upstream-supported Headroom surface confirms these packages remain required |
| Native embeddings and Magika | Removed `fastembed`, `magika`, and `native-ml` paths | Fedora ONNX Runtime exists: F43 1.20.1, F44 1.22.2; exact Rust stacks absent | Rust ORT provider closure, fastembed, Magika, and immutable model packages | ONNX Runtime and architecture/model compatibility | Model initialization/inference; runtime acquisition is forbidden | Crate and model-weight source/license closure incomplete | Offline inference with checksummed packaged models and no cache/network writes | **blocked** |
| Proxy and model providers | Removed LiteLLM/direct/proxy command paths | LiteLLM exact provider not found | LiteLLM/provider stack | Potential HTTP listener and provider clients | Authenticated outbound provider traffic | Provider source/license and operational policy incomplete | Loopback-only fake provider with auth/egress denial tests | **blocked**; never implicit in base |
| Redis backend | Removed Rust Redis edge | Fedora provider status varies and is not closed for this package | Exact reusable Rust Redis branch and tested server contract | Networked shared storage backend | Redis connection traffic | Source closure not recorded | Loopback Redis protocol fixture and backend parity smoke | **blocked** |
| Optional MCP file reading | Removed and hard-disabled `HEADROOM_MCP_READ` path | No provider issue | None | Expands host filesystem access | Local filesystem disclosure rather than network/model behavior | Source known | Set the environment variable and prove the tool remains absent | **rejected** |
| Update checks and Hugging Face acquisition | Removed updater and `hf-hub`/`from_pretrained` network paths | No provider closure recorded | Model and hub clients/artifacts | Background updater/model cache behavior | External release/model traffic | Immutable model/source closure absent | Network-denied CLI startup and explicit fail-closed `from_pretrained` test | **rejected** |
| Bundled SQLite | Upstream `rusqlite` bundled feature replaced by Fedora system SQLite | Fedora system SQLite is the accepted provider | None | Dynamic system linkage is already correct | Local only | Bundled C source is intentionally excluded | ELF linkage and no-RPATH check | **rejected**; system SQLite remains retained |

## Serena

| Capability | Exact source and dependency edge | Fedora 43/44 and RPM Fusion status | Missing reusable packages | System/native implications | Runtime network/model behavior | License/source closure | Smallest offline test | Outcome |
|---|---|---|---|---|---|---|---|---|
| Headless stdio and system LSP commands | Current patched `python-serena-agent 1.6.0` surface | MCP/LSP Python stack and several system language servers are available; no exact Serena duplicate | Language servers not already in Fedora must be packaged independently | Executes explicit administrator-provided system commands | No managed downloads; stdio MCP only | MIT source closure recorded | Existing initialize/list and download-denial smoke | **hold**: both security-surface patches require substantive rework or explicit approval before rebuild/publication |
| Cross-project query | Removed `query_project_tools` registration and `modes/query-projects.yml` | No additional provider need established | None identified, but registration/mode closure must be restored coherently | Broadens project/filesystem scope; upstream symbolic queries require the rejected Flask project server | No necessary model behavior, but symbolic queries add loopback HTTP and LSP startup | Source known; upstream dispatch accepts every tool not marked editing, including configuration mutation | Two isolated fixture projects proving explicit scope, a fixed query-safe tool allowlist, denial outside roots, and no server/LSP creation | **blocked**; a safe replacement is materially larger than restoring the import and mode file |
| Dashboard and project server | `serena.project_server.ProjectServer`, `SerenaDashboardViewer`; Flask/Werkzeug | Flask/Werkzeug available in F43/F44; RPM Fusion has no duplicate | Remaining dashboard dependencies and reviewed server integration | Local HTTP server; optional GUI/browser launch paths must stay absent | Listener exposure; no model required | Core source known; auth/origin/CSRF review incomplete | Loopback-only bind, no auto-browser, origin/CSRF/auth and shutdown tests | **blocked** as an optional subpackage |
| GUI/tray/webview | Lazy `webview`, tray manager, pywebview/pystray dependencies | pystray exists; pywebview/provider closure is unknown | pywebview and native GUI closure | Desktop GUI/tray native stack | Local GUI control surface | Dependency/license closure incomplete | Headless import plus explicit GUI launch in isolated desktop test | **blocked** |
| JetBrains backend/plugin | `determine_language_backend`, IDE contexts, external plugin | No Fedora/RPM Fusion provider found | External plugin/backend and licensing/access closure | IDE process/plugin integration | IDE communication | Closure and redistribution status unresolved | Explicit backend handshake without downloads | **rejected** until independently packageable |
| Managed LSP downloads | `dependency_provider.py`, `RuntimeDependencyCollection.install`, archive/npm/uvx/JAR paths | Some system LSPs exist; others are unknown | Package missing language servers individually | Downloads and executes external tools | Runtime supply-chain network traffic | Downloaded source/binary closure absent | Existing fail-closed download test | **rejected**; retain system-command configuration only |
| Telemetry and API token estimators | `_send_usage_info`, Anthropic/tiktoken estimators | Providers incomplete or external API based | API client/tokenizer closure and credentials | Background reporting or tokenizer initialization | External telemetry/API/model-download behavior | Operational and model/API closure incomplete | Network-denying mock proves no calls; enum remains character-count only | **rejected** |

## Playwright MCP

Packaging boundary correction: `playwright` and `playwright-core` are reusable
public npm modules. One blocked `nodejs-playwright` source package now owns the
single monorepo build and will emit `nodejs-playwright` plus
`nodejs-playwright-core`; `playwright-mcp` owns only `@playwright/mcp 0.0.78`
and requires both exact `1.62.0~alpha.1783623505000` RPM capabilities. The
original npm manifests retain `1.62.0-alpha-1783623505000`; manual normalized
metadata is required because Fedora's provider generator emits that raw alpha
as invalid RPM syntax and its requirement generator discards the prerelease.

| Capability | Exact source and dependency edge | Fedora 43/44 and RPM Fusion status | Missing reusable packages | System/native implications | Runtime network/model behavior | License/source closure | Smallest offline test | Outcome |
|---|---|---|---|---|---|---|---|---|
| Full `@playwright/mcp 0.0.78` | npm wrapper plus `playwright`/`playwright-core 1.62.0-alpha-1783623505000`; generated esbuild/Vite runtime | No exact Fedora/RPM Fusion MCP or Playwright provider; metadata requests Chromium 151, but the exact wrapper passed an stdio 24-tool navigation/evaluation smoke with Fedora 44 Chromium 150. Of 679 locked registry entries, 624 across 572 names are Fedora Linux/x86_64 eligible; Fedora 43/44 provide zero exact locked versions and RPM Fusion provides no reusable npm capability. Fedora source-builds esbuild 0.24.2/0.27.2, not the pinned 0.28.1; Rolldown 1.1.3 and Lightning CSS 1.32.0 are absent. | The 624-entry active root closure, exact source-built esbuild/Rolldown/Lightning CSS providers, source-license verification, and immutable hosting. The unskippable stable-test-runner install is separately bounded to three Linux packages with exact source provenance. | Browser process, sandbox, broad generated Node runtime, N-API build tools, and copied `xdg-open` | Browser automation; browser workspace scripts honor `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`; Playwright-managed downloads remain forbidden | All seven wrapper files match the release tag and five bundle-license sidecars map to exact lock versions. The three Linux native build tools are source-buildable. Actual Linux roots require 239 Rolldown and 92 Lightning CSS registry crates; semver/feature-aware Fedora comparison leaves 80-81 and 20 unresolved edges respectively. Immutable repository or canonical texts resolve 59 of 62 active crate archives without local license text; exhaustive history/release checks confirm that the MIT notices for `base-encode`, `json-escape-simd`, and `parcel_sourcemap` remain unavailable. The stable-test-runner lock has four entries, only three active on Linux, no install/browser-download script, and npm SLSA provenance to commit `e9a2065`. Playwright exposes no MCP-only target, and the generated payload is not reproduced offline. | Complete offline monorepo source build, then repeat the packaged stdio navigation/evaluation smoke using Fedora `chromium-headless` in both target chroots | **blocked** on monorepo and native-tool source/build/license closure, not Chromium or an inherent prebuilt-binary requirement; do not hand-write a reduced runtime |

Additional Playwright distribution gate: ten browser-logo packages in the active root lock have no npm license metadata or tarball notice. Their exact source repository excludes logos and trademarks from its MIT grant, and all ten assets are present in the published Playwright Core dashboard, so packaging requires explicit redistribution/trademark review or an upstream-supported omission.

Dashboard scope correction: those logo packages are used only by `packages/dashboard`. Default MCP tools do not enable `devtools`; only the opt-in `browser_annotate` path requires the generated dashboard. A default-surface binary can omit that output, but the normal upstream build has no dashboard-exclusion flag and still requires the logo source inputs.

Generated-JavaScript correction: Playwright's Node-executed esbuild outputs are bundled/transpiled CJS with minification disabled by default and retain readable source markers. Minified outputs are browser-targeted Vite assets, so local Node JavaScript minification is not a blocker; browser generated-source and license gates remain.

System-integration correction: the copied `open@11.0.0` `xdg-open` script is upstream xdg-utils 1.2.1, while the generated bundle selects the system `xdg-open` command. Fedora 43/44 provide matching xdg-utils 1.2.1, and default headless MCP does not reach report/trace/dashboard reveal paths, so the dead copied file can be omitted from that binary surface.

Installed-payload correction: an enforced package-file denylist smoke reduced the default headless CLI surface from 173 published files and 17,962,355 bytes to 11 files and 6,798,642 bytes. The required runtime is MCP `cli.js` plus its manifest, Playwright Core `coreBundle.js`, `utilsBundle.js`, both manifests, `browsers.json`, and applicable legal files; removing either Core metadata file prevents startup. The reduced surface still lists 24 tools and passes Fedora Chromium navigation/evaluation, while the entire `playwright` package and generated UI/tooling trees are omitted. This narrows the binary and its license inventory but not Playwright's unconditional normal source build. It is a CLI application payload, so the provisional full npm-module Provide must be regenerated or omitted.

Selected-binary license correction: the 11-file candidate retains one generated sidecar with 91 unique, lock-matched package/version entries and full notice text (76 MIT, 9 ISC, 4 BSD-3-Clause, 1 BSD-2-Clause, 1 Fedora-allowed BlueOak-1.0.0). Reconciliation of all 400 `coreBundle.js` source markers adds CC0-1.0, giving the provisional expression `Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BlueOak-1.0.0 AND CC0-1.0 AND ISC AND MIT`. Upstream emits sidecars only for inlined npm packages; the draft spec now generates a 434-line verbatim notice for the stripped pixelmatch, extractZip, lockfile, stackTrace, minimist, eventEmitter, clock, and BiDi/Puppeteer notices from the exact pinned source archive, SHA-256 `c6bd7798e8e2d789797bfd574dbf574477cc76e5af2a301cf0f10e6031804f9a`. Packaging verification remains behind the fail-closed build gate.

Command-surface correction: upstream defaults to stdio and supports the selected explicit Chromium/headless/isolated/system-executable profile, but the same CLI exposes `--port` HTTP/SSE, remote/CDP/extension browser modes, optional capabilities, unrestricted filesystem and proxy controls, config/environment overrides, and an `install-browser` managed-download alias. No upstream switch enforces the selected profile. Keep the package blocked rather than add an unauthorized downstream security wrapper or protocol adapter.

Default-tool correction: the exact upstream test and executable expose 24 default tools. `browser_run_code_unsafe` is an unconditional `core` tool and is explicitly described upstream as arbitrary JavaScript in the server process and RCE-equivalent. `browser_press_sequentially` is `skillOnly` and therefore does not create a 25th default tool; browser installation is a CLI alias, not an MCP tool. Upstream has no per-tool denylist, so the selected surface remains blocked pending an upstream exclusion mechanism, explicit approval for a downstream filter, or an approved process sandbox.

Runtime-isolation correction: an exact-runtime MCP smoke reproduced the unsafe tool's host impact. Code in its Node `vm` context reached the host `process` through the live Playwright `page` object, loaded built-in `fs`, and wrote a verified marker outside MCP filename validation; the marker was then removed. The content SHA-256 was `d74568fdd4ec92e9d21cf2c2c8d407690f747bfa5fc06575e4561e0aecde2933`. Publication therefore requires a real per-tool exclusion or independently approved process sandbox, not documentation alone.

## Historical Docling Validation

The Docling remote-conversion package passed the following historical gates.
Updated policy separately places its downstream implementation under a
substantive-rework hold, so this evidence is not permission to rebuild or
publish it:

1. Base `docling-mcp-server` defaults and tool list remain unchanged.
2. The optional launcher is stdio-only and exposes only generation,
   manipulation, and single-document remote conversion.
3. No local converter, directory conversion, parser/model dependency, URL-source
   fetch, upload outside the explicit root, HTTP MCP transport, or runtime
   download is reachable.
4. The fake loopback Serve test covers initialization, tool listing, bounded
   file upload, API-key handling, polling, inline result decoding, and cache hit.
5. Source and patches apply with zero fuzz and the RPM build remains offline.
6. Clean serialized Fedora 43 and Fedora 44 Mock builds pass with at most four
   jobs, followed by packaged MCP smokes and zero `rpmlint` errors.
7. Specs, patches, SRPMs, RPMs, tests, and receipts are hashed in package
   manifests; documentation and wiki records are updated.

## Headroom Audit Hold

No Headroom build wave is selected under the updated policy. The current draft
remains blocked because:

1. Released Headroom 0.31.0 provides no upstream feature flag that excludes its
   unconditional FastEmbed, Magika, Hugging Face, and bundled-SQLite native graph.
2. The downstream `mcp-minimal` graph spans multiple functional concerns and is
   explicitly listed for substantive rework.
3. The binary's aggregate SPDX expression for statically linked Rust code has
   not been completed.
4. The two tokenizer compatibility drafts are under dependent-scope review and
   must not be built merely because their standalone source closure is known.
