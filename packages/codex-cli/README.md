# Codex CLI Packaging Status

Codex CLI `0.144.5` is a blocked Fedora source-package draft. The selected
published release is tag `rust-v0.144.5` at commit
`87db9bc18ba5bc82c1cb4e4381b44f693ee35623`. Its immutable commit archive has
SHA-256
`b3472ef0b53e9b6191e19f51f491f818749671b9cb1b8dbe51466dc2702abcd9`.

Fedora and RPM Fusion 43/44 provide neither an exact Codex CLI package nor a
`/usr/bin/codex` provider. The globally installed `@openai/codex` npm package
is not used: it selects platform-specific prebuilt binaries instead of
building the Rust application from source.

## Source-Only Probe

The Fedora 44 probe verified and extracted the release archive, ran
`%cargo_prep`, and generated a dynamic BuildRequires RPM without compiling
Codex. The result is
`codex-cli-0.144.5-0.1.fc44.buildreqs.nosrc.rpm`, SHA-256
`3e17eb2bb95d0b85bc2b57158a1ca926b940b1e46e3f15dcadde4532d621e42f`.

That artifact is not the production Linux closure. Fedora's `cargo2rpm 0.3.3`
recognizes `codex-rs/cli/Cargo.toml` as part of the parent workspace, unions all
128 workspace members, and does not filter dependency target expressions. Its
400 requirements include 53 Windows-related capabilities, test helpers, and
V8. Workspace resolution also reaches the separate WebRTC Git source. These
entries must not be represented as Codex CLI production requirements until a
target-aware selected-member graph proves them.

## Remaining Gates

1. Generate the production and build graph for only `codex-cli` and its Linux
   path dependencies, with dev and non-Linux edges excluded.
2. Convert every selected Git dependency to an immutable, checksummed source
   input or use an acceptable Fedora provider.
3. Replace or document the Linux sandbox's build of vendored Bubblewrap 0.11.2
   under Fedora's system-library and bundling rules.
4. Disable or redirect npm/GitHub self-update checks and npm/brew update
   recommendations for the Fedora package.
5. Complete the linked-license review and clean offline Fedora 43 and Fedora 44
   builds, tests, lint, and extracted-payload validation.

## Intentional Failure

`codex-cli.spec` verifies the immutable release archive and then exits during
`%prep`. It must remain fail-closed until the gates above are satisfied. No
generated RPM was installed and COPR was not mutated during this probe.

## References

- https://github.com/openai/codex/releases/tag/rust-v0.144.5
- https://github.com/openai/codex/tree/87db9bc18ba5bc82c1cb4e4381b44f693ee35623
