# Agentlab Fedora Packages

Agentlab is Marcin FM's source-first Fedora COPR packaging repository for open-source tools used by the local `cx` environment.

- Maintainer: Marcin FM `<marcin@lgic.pl>`
- GitHub: `marcin-fm/agentlab`
- COPR: `marcin/agentlab`
- Default branch: `master`

## Policy

- Build published releases from source; never derive package versions from Git snapshots.
- Do not duplicate packages already in Fedora or RPM Fusion.
- Do not repackage upstream application binaries.
- Keep RPM builds offline and declare every build dependency.
- Preserve authorship when adapting another packager's work.
- Do not install locally built RPMs in the development container.
- Keep spec releases below `1`: use the normal `0.x` sequence and preserve legacy fractional steps as `0.0.x`.

See [`PACKAGING.md`](PACKAGING.md) for the package gates and source-closure model.

## Repository Layout

```text
config/copr.yml                    COPR project policy
packages/<name>/<name>.spec       package spec
packages/<name>/package.yml       release and enablement metadata
scripts/check-packages            local manifest/spec validation
scripts/create-copr-packages      create or reconcile COPR definitions
scripts/generate-node-bundled-provides
                                    generate manual metadata for embedded npm code
scripts/prove-bun-zig-bootstrap    reproduce the private pinned-Zig source proof
scripts/update-and-build          update releases and submit changed builds
```

## Current Packages

| Package | Version | State | Reason |
|---|---:|---|---|
| OpenCode | 1.18.3 | blocked | Requires a source-built Bun and an audited npm source closure |
| Bun | 1.3.14 | blocked | Pinned Zig source bootstrap works; WebKit, source closures, seed build, and offline self-rebuild remain |
| RTK | 0.43.0 | enabled | Current F43/F44 builds passed 2,287 tests, full linked-license/provider receipts, system-SQLite smokes, and rpmlint |
| codex-cli | 0.144.5 | blocked | Immutable source is verified; selected Linux Cargo closure, Git sources, Bubblewrap treatment, and offline builds remain |
| rust-dirs5 | 5.0.1 | enabled | Fedora 44-only compatibility crate for RTK; clean mock build passed |
| rust-dirs-sys0.4 | 0.4.1 | enabled | Fedora 44-only compatibility crate for RTK; clean mock build passed |
| rubygem-ferrum | 0.17.2 | enabled | Pure-Ruby package; Fedora 43/44 clean builds and Chromium CDP smoke passed |
| ast-grep | 0.44.1 | enabled | Clean F43/F44 mock builds, tests, CLI smoke, and aggregate linked-license audit passed |
| mermaid-cli | 11.16.0 | blocked | F43/F44 builds pass; immutable generated-source hosting and upstream bundling record remain |
| kreuzberg | 4.10.2 | blocked | System PDFium provider, Rust/Node closures, license audit, and clean builds remain |
| pdfium | 146.0.7678.0 | blocked | Deterministic closure generated; Fedora GN/Ninja proof, license audit, and subordinate-source policy decision remain |
| python-docling-mcp | 2.1.0 | enabled | Base stdio generation/manipulation plus an explicit bounded remote-conversion package; clean F43/F44 MCP smokes and zero-error rpmlint passed |
| python-doclang | 0.7.3 | enabled | Reusable Docling prerequisite; clean F43/F44 builds and installed schema/CLI smokes passed |
| python-latex2mathml | 3.81.0 | enabled | Reusable Docling prerequisite; hatchling substitution and F43/F44 conversion smokes passed |
| python-docling-core | 2.87.1 | enabled | Base Docling model/serialization package; clean F43/F44 builds, 29 tests, and installed smokes passed |
| python-docling-slim | 2.113.0 | enabled | API-only base/service-client package; clean F43/F44 loopback health smokes passed without local parser/model branches |
| playwright-mcp | 0.0.78 | blocked | Wrapper correspondence is proven; generated Playwright source build, licenses, and Chromium 151-vs-150 proof remain |
| python-serena-agent | 1.6.0 | enabled | Headless stdio/LSP package; clean F43/F44 MCP smokes and download-denial checks passed |
| python-sensai-utils | 1.5.0 | enabled | Repaired published sdist metadata; clean F43/F44 builds and 16 tests passed |
| python-overrides | 7.7.0 | enabled | Clean F43/F44 builds and 67 tests passed |
| python-mslex | 1.3.0 | enabled | Clean F43/F44 builds and tests passed; expected missing-manpage warning only |
| python-oslex | 2.0.0 | enabled | Clean F43/F44 builds passed using the local mslex provider |
| rust-unidiff0.4 | 0.4.0 | enabled | Reusable Headroom Rust dependency; clean F43/F44 builds, tests, and rpmlint passed |
| python-headroom-ai | 0.31.0 | enabled | MCP-minimal native package; clean F43/F44 tests and local stdio compress/retrieve/stats smokes passed |

Blocked specs are reviewable drafts. Automation will not create a COPR package or submit a build until `package.yml` has both `status: enabled` and `copr.enabled: true`.

## Commands

Activate the Marcin FM identity for the current shell and all child agents, from any working directory:

```bash
source /srv/identities/marcin-fm/activate
```

The helper must be sourced. It discovers private keys with matching `.pub` files beside the activation script, rejects unsafe key and credential modes, and exports the Git author, committer, restricted SSH command, `GH_CONFIG_DIR`, and `COPR_CONFIG`. Git SSH trusts only GitHub's published Ed25519 host key from the identity directory. The identity applies regardless of working directory, so activate a different identity before working on another project. It does not change local/global Git configuration, configure a remote, load a shared SSH agent, or place credentials in this repository.

Validate repository metadata and parse every spec:

```bash
scripts/check-packages
ruby -Itest test/test_agentlab.rb
```

Preview COPR project/package reconciliation:

```bash
scripts/create-copr-packages
```

Apply the reconciliation after activating the identity. The script verifies that COPR reports owner `marcin` before mutation:

```bash
scripts/create-copr-packages --apply
```

Preview stable upstream release updates and builds:

```bash
scripts/update-and-build
```

Apply updates and submit builds for changed enabled packages:

```bash
scripts/update-and-build --apply
```

Blocked packages can be included in release checks without submitting builds:

```bash
scripts/update-and-build --include-blocked
```

Generate the OpenCode spec's bundled Node metadata from an audited closure:

```bash
scripts/generate-node-bundled-provides \
  --package opencode \
  --apply
```

The command resolves the versioned closure path from `dependencies.yml`. That file is generated during the source-acquisition audit and is intentionally absent while the package remains blocked.

Reproduce the Fedora 44 source bootstrap of Bun's pinned Zig build tool without installing it:

```bash
scripts/prove-bun-zig-bootstrap
```

The command downloads or accepts the exact checked source archive, verifies its SHA-256, applies the repository-authored Fedora library-path patch, builds stage3 with Fedora LLVM 20, and validates the `zig` plus `lib` root that Bun expects. All outputs and the machine-readable proof receipt remain below `/srv/tmp`. This is a local source-bootstrap-stage proof, not a complete offline Bun RPM build or Fedora approval.

The scripts never commit, tag, or push changes.

## COPR Authentication

Agentlab uses the explicit identity-scoped config selected by `COPR_CONFIG`; it never relies on `HOME` or `~/.config/copr`. Obtain the token from the COPR API page, keep `/srv/identities/marcin-fm/copr` at mode `0600`, and source the activation helper in the same shell call as authenticated COPR commands. No credentials belong in this repository.

## License

Repository-authored automation and documentation are available under the MIT License. Individual packaged projects retain their upstream licenses.
