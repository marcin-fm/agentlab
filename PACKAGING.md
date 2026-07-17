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

## Package Retirement

The active repository must contain only packages still required by an explicitly selected Agentlab package surface. Fedora/RPM Fusion duplicate checks are recurring maintenance checks, not one-time admission gates.

Retire a package when no active selected package requires the Agentlab build and a compatible Fedora or RPM Fusion package is available in every configured COPR target chroot. Availability only in Rawhide or one configured release is not sufficient while another target still depends on the COPR package.

Before retirement, verify the replacement package name, version, and capabilities in each configured chroot and remove or update active dependency references. Then preview and apply `scripts/retire-package --reason TEXT PACKAGE`. The command authenticates the configured COPR owner, deletes the COPR package definition when present, moves the complete tree from `packages/<name>` to `archived/<name>`, and writes `retirement.yml`.

A retirement is complete only when the package is absent from active package manifests and dependency records, absent from COPR, present under `archived/`, and documented with its reason. Archived trees preserve history but are excluded from active package validation, release updates, builds, and COPR reconciliation; repository checks still validate their retirement metadata.

## Source Rules

- `Source0` must be a stable archive for a published release.
- Every recorded SHA-256 must match the release source.
- Additional language dependency sources must retain original URLs, integrity values, licenses, and reconstruction metadata.
- `%build` and `%check` may not fetch from GitHub, npm, crates.io, PyPI, or other networks.
- Generated/minified code and native modules require corresponding source and a documented build path.

## Patch And Dependency Selection

- Before writing a downstream patch, inspect upstream release branches, commits, open and merged pull requests, and linked issues for an existing implementation. Prefer a released upstream fix; otherwise use `git format-patch` for an exact backport so its Git author, date, subject, commit ID, and canonical URL remain intact. Keep Fedora-only changes separate when practical and document unavoidable downstream edits.
- Clone or fetch the upstream repository to an exact known path under `/srv/tmp` for source and history cross-reference. Resolve the packaged release tag to its commit and search the relevant refs and paths locally. GitHub web pages, APIs, code search, and rendered diffs are not substitutes for local Git evidence; use them only to locate canonical references or an otherwise unavailable ref, and record that exception. The clone is research evidence, not the RPM release source: `Source0` must remain a stable published release archive.
- When Fedora has a newer dependency branch than the released application selects, test whether a narrow upstream-supported or upstreamable adaptation can use it before adding another compatibility package. Accept that adaptation only when it preserves behavior, avoids a major or API-incompatible port, is smaller to maintain, and passes the complete relevant build and test matrix.
- Do not replace a missing crate package with broad downstream porting. If the newer Fedora dependency requires substantial source changes or changes behavior, retain the versioned compatibility package or keep the parent blocked.

## Release Sequence

All specs remain below release `1` until the maintainer explicitly changes this policy. The normal pre-publication sequence is `0.x%{?dist}`; increment `x` for each packaging revision and keep the current changelog NEVRA synchronized. Preserve legacy fractional steps as `0.0.x` so older history remains ordered beneath the normal sequence. Do not use `%autorelease` or a release greater than or equal to `1`.

## Rust Packaging

Choose the RPM model from the installed product, not merely from the presence of `Cargo.toml`:

- A released crates.io library uses `rust-<crate>` naming, `%{crates_source}`, `rust2rpm`, and noarch crate-devel/feature subpackages.
- An application, workspace, command-line tool, shared library, or Python/Node extension uses normal Fedora naming and remains architecture-specific when it installs compiled target artifacts.
- A non-crate application must not install Cargo registry source or emit public `crate(...)` interfaces. Set the Cargo install controls accordingly or install only the intended binaries/libraries manually.

Every Cargo-using spec requires `BuildRequires: cargo-rpm-macros >= 24`. Regenerate crate specs with the current `rust2rpm` baseline on each update rather than preserving stale generated feature metadata by hand.

The standard system-registry flow is:

```spec
%bcond check 1

%prep
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires <feature selection>

%build
%cargo_build <same feature selection>

%check
%if %{with check}
%cargo_test <same feature selection>
%endif

%install
%cargo_install <same feature selection>
```

Use `%cargo_build_crate` and `%cargo_install_crate` where their wrapper behavior matches the package. `%cargo_build_crate` runs the standard build and, for a selected binary target, also produces the Cargo license summary and `LICENSE.dependencies`; a literal search for `%cargo_license` therefore does not establish a missing license inventory.

Crate packages define the Fedora check bcond. Agentlab applications should do the same; use `%cargo_generate_buildrequires -t` only for a documented non-crate package whose tests intentionally run unconditionally. Dynamic BuildRequires must see test dependencies whenever tests run. Pass the identical `-a`, `-n`, and `-f` selection to dependency generation, build, test, install, `%cargo_license_summary`, and `%cargo_license`. Do not hide unavailable selected dependencies with `-n`.

Raw `cargo`, direct `cargo2rpm`, cleared `RUSTFLAGS`, and spec-owned `RUSTC_BOOTSTRAP=1`/`-Z` command lines are not normal alternatives to the macros. Any exception must reproduce Fedora's offline registry configuration, `rpm` profile, `%{build_rustflags}`, linker flags, parallelism, test dependency generation, and feature selection, with the reason documented beside the command. The macros' internal use of `RUSTC_BOOTSTRAP` for `avoid-dev-deps` does not authorize nightly-only upstream behavior.

Binary applications, shared libraries, and language extensions need aggregate SPDX accounting for their statically linked crate closure. Run `%cargo_license_summary` and `%cargo_license` in `%build` after the actual build with the same features, or use a standard wrapper that does so. Ship `LICENSE.dependencies` with the applicable upstream license texts; do not copy full system-provider license trees or NEVRA/source-RPM evidence into the runtime package.

Avoid vendoring. If an application has a reviewed, unavoidable vendored Cargo closure, use `%cargo_prep` vendored mode, generate `cargo-vendor.txt` with `%cargo_vendor_manifest`, install it as `%license`, and let Fedora emit `bundled(crate(<name>)) = <version>` for every bundled crate. Do not run `%cargo_generate_buildrequires` for that vendored closure and do not expose vendored crate-devel interfaces.

Use Fedora system native libraries where supported and keep `build.rs`, bindgen, generated code, and architecture handling source-based. Prefer a narrow upstreamable port to Fedora's current crate branch when it preserves behavior and is smaller to maintain. Otherwise retain a versioned compatibility crate; do not force a broad downstream port merely to reduce the package count.

The detailed compliance audit is `/srv/wikis/agentlab/rust-packaging.md`. Dependency-graph reduction and retirement decisions remain in `/srv/wikis/agentlab/rust-reducibility.md`.

## Node.js And JavaScript Packaging

Classify the installed product before constructing its closure:

- A command-line application follows normal Fedora naming and should bundle the Node libraries it needs.
- A reusable public npm module is packaged as `nodejs-<name>`.
- A reusable browser library follows the Fedora JavaScript/Web Assets layout.
- A standalone Bun executable is an application, not a reason to create one RPM for every private npm dependency.

Any package that is a Node module, bundles or uses Node modules, or needs Node for building or testing requires `BuildRequires: nodejs-devel`. Use `%{nodejs_sitelib}` for pure JavaScript and `%{nodejs_sitearch}` for native modules. Pure JavaScript packages use `BuildArch: noarch` plus `ExclusiveArch: %{nodejs_arches} noarch`; native modules omit `noarch`, use the supported Node architecture set or a documented subset, and apply `%{?nodejs_default_filter}` when their `.node` files would otherwise create invalid ELF Provides.

For separately packaged modules, prefer the npm registry release tarball. For applications, retain the released application source and original immutable registry tarballs for the exact selected closure. General bundling rules remain applicable: remove bundled system libraries when upstream supports Fedora providers, or record the bundled component and public upstream-contact result.

Keep production/build and test sources in separate archives, and introduce test-only inputs only in `%check`. RPM phases must not run package-manager install or dependency-resolution commands such as `npm install`, `npm ci`, Yarn, pnpm, or Bun install. Lockfiles and Agentlab receipts constrain source selection, but do not authorize network resolution or lifecycle-script execution during the build. The closure consists of original registry source tarballs plus canonical manifests:

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

Workspace code is part of OpenCode itself, while `role: build` and `role: test` registry entries are source inputs but do not receive runtime bundled Provides. Preserve scoped package names exactly.

Fedora's automatic generator reads a public root `package.json`, emits `npm(<name>) = <version>`, and emits `bundled(nodejs-<name>) = <version>` for public packages beneath `node_modules` or `node_modules_prod`. Private or non-registry roots must set `private: true` and must not provide `npm(...)`. The current Fedora file attribute does not trigger for a scoped root such as `%{nodejs_sitelib}/@scope/name/package.json`, and it cannot inspect a standalone executable with no installed module tree. In those cases, document the limitation and generate manual root/bundled metadata from the exact installed or embedded runtime closure. Do not use `bundled(npm(...))`, do not add `npm(opencode)` for a private application, and do not generate runtime Provides from lockfile-wide or test/build-only records.

Every reusable Node module needs at least a `%{__nodejs} -e 'require("./")'` load test plus upstream tests where practical. Applications need a staged-installed command smoke covering the selected runtime behavior. Native addons must be built from source, installed under `%{nodejs_sitearch}`, and tested with the assembled JavaScript loader. Generated JavaScript and functional WASM require corresponding source and reproducible build evidence. Locally executed JavaScript must not be minified; browser-targeted pregenerated/minified assets require the Fedora-documented hardship rationale and corresponding unminified source when they are not rebuilt.

Recheck every bundled license on each update. The final binary RPM `License:` expression covers all shipped bundled content, and the package retains a component/version/license inventory plus applicable or legally required texts. `nodejs-packaging-bundler` is preferred where it faithfully models the selected closure, but it does not permit RPM-build dependency resolution.

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
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/JavaScript/>
- <https://docs.fedoraproject.org/en-US/packaging-guidelines/Rust/>
