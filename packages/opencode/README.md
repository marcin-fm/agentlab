# OpenCode Packaging Status

OpenCode `1.18.3` is not enabled for COPR. The released GitHub tag is valid source, but the project builds with Bun and has a large CLI source closure that is not present in the release archive. Fedora's Node.js application guidance permits this private application closure to remain bundled; it does not require one RPM per ordinary npm dependency. The last detailed closure audit covered `1.17.20`, so the current release must be regenerated and reviewed before enablement.

The immutable `v1.18.3` tag resolves to commit
`127bdb30784d508cc556c71a0f32b508a3061517`, and its source archive has
SHA-256 `494041aedd7407079f91fd694de355f4ff022ba6bf876e09ff30983bbdc70ae1`.
The root lock contains 37 workspace records and 3,215 package records. Those
are lockfile-wide inventory counts, not the standalone Linux binary closure
and not valid `bundled(nodejs-...)` input.

The npm `opencode-ai` package and existing binary-oriented COPR/AUR/Homebrew recipes are intentionally not used. They select or install upstream platform executables instead of rebuilding from source.

The draft spec becomes eligible only after:

1. Bun 1.3.14 is source-built in Fedora without bootstrap binaries.
2. The exact npm source closure is acquired, checksummed, and license-audited.
3. Native modules and generated assets are rebuilt from source.
4. Manual `bundled(nodejs-...)` metadata is generated for code embedded in the standalone binary.
5. System-library decisions and required upstream contacts are recorded.
6. The build and checks pass without network access.

Technical dependency facts are tracked in [`dependencies.yml`](dependencies.yml).
