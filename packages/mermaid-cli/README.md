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

`mermaid-cli-11.16.0-1` clean-built on Fedora 43 and Fedora 44 x86_64. Both
builds exercised the staged installed `mmdc` command against Fedora
`chromium-headless`, rendering SVG, PNG, and PDF with Font Awesome solid,
regular, and brand icons. Final artifacts have zero `rpmlint` errors. No
produced RPM was installed on the host.

The package remains blocked and COPR-disabled only until all generated
`Source1`-`Source6` artifacts, including the 145 MB closure, are hosted at
immutable checksummed URLs and the required public upstream request for a
system-library or externally supplied dependency mechanism is recorded.
