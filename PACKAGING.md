# Packaging Model

## Package States

Each `packages/<name>/package.yml` declares one of these states:

- `enabled`: eligible, validated, and allowed to create/build in COPR.
- `blocked`: retained as a reviewable source-build draft with explicit unresolved gates.

Changing a package to `enabled` requires all blockers to be removed, an offline SRPM/build proof, a license audit, and fresh Fedora/RPM Fusion duplicate checks.

Removed MCP capabilities are evaluated in
[`MCP_FEATURE_RESTORATION.md`](MCP_FEATURE_RESTORATION.md). Optional feature
work must keep the affected package blocked and COPR-disabled until the new
subpackage passes the same source, offline-build, security, and clean-build
gates as a new package.

## Source Rules

- `Source0` must be a stable archive for a published release.
- Every recorded SHA-256 must match the release source.
- Additional language dependency sources must retain original URLs, integrity values, licenses, and reconstruction metadata.
- `%build` and `%check` may not fetch from GitHub, npm, crates.io, PyPI, or other networks.
- Generated/minified code and native modules require corresponding source and a documented build path.

## Release Sequence

All specs remain below release `1` until the maintainer explicitly changes this policy. The normal pre-publication sequence is `0.x%{?dist}`; increment `x` for each packaging revision and keep the current changelog NEVRA synchronized. Preserve legacy fractional steps as `0.0.x` so older history remains ordered beneath the normal sequence. Do not use `%autorelease` or a release greater than or equal to `1`.

## JavaScript Source Closures

Fedora's Node.js application guidance says applications should bundle the Node libraries they need. OpenCode's private Bun/npm graph therefore belongs in an audited package-local source closure rather than thousands of initial `nodejs-*` RPMs. Reusable public Node libraries still follow separate `nodejs-<name>` packaging.

General bundling rules remain applicable. A Fedora system library must be used and the bundled copy removed when upstream supports that mechanism. When upstream has no system-library mechanism, record the bundled component plus the required public upstream-contact outcome.

Keep production/build and test sources in separate archives. Do not run `npm install` in the RPM build. The closure consists of original registry source tarballs plus canonical manifests:

```text
closure.json       exact name/version/source/integrity entries
licenses.json      reviewed SPDX expressions and license files
native.json        native code, lifecycle scripts, and build requirements
files.json         deterministic source archive membership
```

Each registry entry used for bundled metadata has this minimum shape:

```json
{
  "npm_name": "@scope/name",
  "version": "1.2.3",
  "origin": "registry",
  "role": "runtime",
  "included_in_binary": true,
  "source_url": "https://registry.npmjs.org/...tgz",
  "integrity": "sha512-...",
  "sha256": "...",
  "license": "MIT",
  "source_verified": true
}
```

Workspace code is part of OpenCode itself, while `role: build` and `role: test` registry entries are source inputs but do not receive runtime bundled Provides. Scoped package names are preserved exactly, matching Fedora 44's generator behavior.

Fedora 44's automatic Node generator emits `bundled(nodejs-<npm-name>) = <version>` only when installed package manifests are under `%{nodejs_sitelib}`. OpenCode installs a standalone Bun executable instead, so `scripts/generate-node-bundled-provides` must generate the manual versioned `Provides:` block from closure entries marked `included_in_binary: true`. Do not use `bundled(npm(...))`, and do not add `npm(opencode)` for the private application.

The eventual spec must reject prebuilt executables/native objects, disable package lifecycle scripts by default, explicitly build reviewed native dependencies, enumerate all bundled licenses, and unpack test-only dependencies only in `%check`.

Generated closure archives also need immutable, checksummed hosting that COPR SCM builds can access. Local-only or untracked archives are not an enablement path; the final transport must preserve every original source URL and member checksum without introducing build-time dependency resolution.

## Bun Bootstrap Stages

Bun is packaged as a published Bun release. Tool sources pinned by that release are subordinate, checksummed source inputs; they are not published as falsely versioned standalone packages.

The Bun `1.3.14` build plan is staged:

1. Source-bootstrap the release-pinned `oven-sh/zig` fork privately with Fedora LLVM, Clang, and LLD 20.
2. Acquire and build the pinned WebKit/JavaScriptCore fork recursively from source and retain LGPL relink materials.
3. Materialize all npm, Cargo, Node-header, GitHub, and native build inputs offline.
4. Use a separately declared temporary Bun seed only for the first source build. The seed is bootstrap-only and cannot enter the final payload.
5. Immediately rebuild the identical Bun release offline with the first source-built Bun.
6. Verify the final RPM has no seed payload or runtime dependency, complete the license/duplicate review, then enable COPR.

The first stage is verified locally on Fedora 44 x86_64. The in-tree Zig stage-one WASM is part of the pinned source bootstrap; no external Zig executable is used. `scripts/prove-bun-zig-bootstrap` reproduces that proof below `/srv/tmp` and writes a source, patch, toolchain, and output receipt. The pinned WebKit commit has no gitlinks or submodules, and the exact Bun release seed is checksummed and marked bootstrap-only; neither has yet passed its build stage. This is not an offline Bun build or Fedora approval. Fedora-main use of a temporary prebuilt Bun seed still requires the applicable FPC bootstrap approval; a COPR proof does not grant that approval.

## COPR Workflow

COPR package definitions use SCM source with:

- clone URL `https://github.com/marcin-fm/agentlab.git`
- branch `master`
- package subdirectory `packages/<name>`
- spec `<name>.spec`
- source method `make_srpm`
- webhook rebuild disabled

Release updates are submitted from the reviewed local spec with `copr-cli build`; this avoids pretending uncommitted changes already exist on GitHub. After the changes are committed and pushed, `copr-cli build-package` may rebuild the SCM definition explicitly.

Authenticated automation uses the explicit identity-scoped path in `COPR_CONFIG`, not an ambient `HOME`. Before any project or package mutation, the scripts call COPR's authenticated, read-only `/api_3/auth-check` endpoint and require the server-returned account to match the configured owner `marcin` exactly. Config-only `copr-cli whoami` output is not accepted as proof that a token is valid.

Packages may set `copr.chroots` to a subset of the project chroots. Direct build submission honors that restriction. The `rust-dirs5`, `rust-dirs-sys0.4`, and `rust-atty0.2` compatibility crates target only Fedora 44 because Fedora 43 already provides those branches. `rust-tungstenite0.28` targets only Fedora 43 because Fedora 44 already provides that branch.

## Fedora References

- <https://docs.fedoraproject.org/en-US/packaging-guidelines/>
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/What_Can_Be_Packaged/>
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/SourceURL/>
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/Bundled_Libraries/>
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/Licensing/>
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/Node.js/>
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/Rust/>
