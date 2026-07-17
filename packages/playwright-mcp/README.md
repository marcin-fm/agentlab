# playwright-mcp

Blocked Fedora package draft for the released `@playwright/mcp` `0.0.78`
application. The package source is Apache-2.0 and the npm provenance
attestation identifies upstream tag `v0.0.78` at commit
`5f8fc00210b27b4407c375b59cda4838045d429c`.

Independent correspondence review is complete. Six of the npm package's seven
files byte-match the release tag; its Apache license differs only in formatting
and final line ending. The release tag archive SHA-256 is
`9f4b1c550c24aaf202b422c568c105a6c29e4c3d10735cc317c56aa650cda3d7`,
and the audit record SHA-256 is
`e35a16efe0a6fe753e1ee2142647069eaa310c3d2485c2576a7b4d06c50649f6`.

## Immutable Runtime Inputs

| npm package | Version | SHA-256 |
| --- | --- | --- |
| `@playwright/mcp` | `0.0.78` | `cfff0fd8eae3ac3bcb39827861298cb6b483a8d72e3c558e7991658ed3d22562` |
| `playwright` | `1.62.0-alpha-1783623505000` | `738aa4e5602f023b68dbad49cf6bd93e8f2aa14277831109458de1262fad557a` |
| `playwright-core` | `1.62.0-alpha-1783623505000` | `a5412aee4ac779f1c662272f77fd5fe716218cf555c222a301f089447f49b24c` |

The reference runtime package closure is limited to those three packages on Fedora;
`fsevents@2.3.2` is an optional Darwin-only dependency. The test closure is
separate and remains unstaged and unaudited.

## Intentional Failure

`playwright-mcp.spec` exits in `%prep` before unpacking or building. It must
remain fail-closed until the records in `package.yml`, `dependencies.yml`, and
`reproducibility.yml` are all satisfied. In particular, no npm install,
lifecycle script, or Playwright browser download is permitted in an RPM build.

The remaining source gate is the generated Playwright runtime: compiled JS,
bundled modules, Vite/esbuild assets, generated browser metadata, and copied
`xdg-open` must be reproduced from Playwright commit
`9fb36027c64c8edcf08bf06f618b3ca97a7b0d97` with a complete offline build
closure and license evidence.

The intended browser is Fedora `chromium-headless` through
`/usr/lib64/chromium-browser/headless_shell`, but this exact Playwright alpha
runtime requests Chromium `151.0.7922.10` while Fedora currently provides
Chromium `150.0.7871.114`; it has not passed an offline operation smoke.

## References

- https://github.com/microsoft/playwright-mcp/releases/tag/v0.0.78
- https://registry.npmjs.org/-/npm/v1/attestations/@playwright%2fmcp@0.0.78
