# Mermaid CLI

This package targets the published `@mermaid-js/mermaid-cli` 11.16.0 release
and installs the `mmdc` command from source with a private, audited Node
application closure.

The release imports Puppeteer at runtime but declares it only as a peer and
development dependency. Packaging promotes the lockfile's Puppeteer 25.2.1
release into the production closure and disables its browser download. Fedora's
`chromium-headless` package supplies the browser.

The CLI's Vite output is only `dist/index.html`, equivalent to the release
source `index.html`; the RPM copies that source file instead of carrying the
Vite, Rollup, and esbuild development closure.

The deterministic closure contains 327 installed package paths backed by 326
original npm source archives. It executes no lifecycle scripts, downloads no
browser, and contains no native or WASM payload. Generated-heavy Mermaid, ELK,
ZenUML, and Font Awesome content has matching corresponding source or official
release data. The RPM carries the reviewed aggregate SPDX expression, exact
bundled Node Provides, a dependency license inventory, and consolidated notices.

The Node-executed `mmdc` entry point is readable and unminified. It injects the
readable, source-marked Mermaid, ELK, tidy-tree, and ZenUML ESM release bundles
into Chromium. Some browser-only release output remains minified, including the
ELK worker and frontend distributions retained by transitive packages. Rebuilding
all of those outputs would require the development-only Vite, Rollup, esbuild,
Gradle, Babel, Browserify, Bun, Tailwind, KaTeX, and Font Awesome toolchains.
The exact npm source archives and the preferred Mermaid, ELK, ZenUML, and Font
Awesome sources remain available for correspondence, so this is the documented
Fedora browser-asset hardship rather than locally executed minified JavaScript.

Upstream issue [#830](https://github.com/mermaid-js/mermaid-cli/issues/830)
records a Nix distribution-packaging request for externally supplied Puppeteer.
Upstream retains Puppeteer as a peer plus development dependency and recommends
normal package-manager or shrinkwrap materialization. Fedora records that public
contact, carries the exact bundled dependency metadata, and uses system Chromium.

`mermaid-cli-11.16.0-1` clean-built on Fedora 43 and Fedora 44 x86_64. Both
builds exercised the staged installed `mmdc` command against Fedora
`chromium-headless`, rendering SVG, PNG, and PDF with Font Awesome solid,
regular, and brand icons. Final artifacts have zero `rpmlint` errors. No
produced RPM was installed on the host.

Configured-SCM builds reconstruct `Source1`-`Source6` during `make_srpm` from
the immutable audited inputs. The source builder uses Fedora's npm 10.9.7,
executes no lifecycle scripts, and rejects any runtime lock or generated file
whose digest differs from the retained contract. Target RPM builds remain
offline and consume only the generated SRPM sources.
