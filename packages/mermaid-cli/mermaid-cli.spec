# Disabled by package.yml until the generated npm source closure is audited,
# immutably hosted, and proven in both configured Fedora buildroots.
%global source_sha256 c95d8b32a604e8393d9cfea9ee54060752b1cf4ff291be80a0b749e96a42c0c2
%global closure_sha256 4a181bf1d043a892bff09f81a7aafcc6345bd93b46b1a9761b152b66f7a3eabe
%global manifest_sha256 65c2ae8e1099d2530f73b54d985e7e7b086eb87f7f9dd68e8675772951d2e9ee
%global license_inventory_sha256 6e31371d7f26d7f935de9479bf734a5185d215177f3ed9236ecc439f65a713cd
%global native_manifest_sha256 eb99b57bf8df386041a02b1eb0fa0726e0f9cd19fb860f505e3e956cd36d1468
%global notices_sha256 41be30cd3c63b27d747d64fc642b524060befc9d43faab922274f8bd4f2e8bbf
%global receipt_sha256 0e94937cfd9739a947c8cbba9599fe555e78782ca96384dca134b7bc21dca5d2
%global mermaid_source_sha256 50692a34f9827708ddbbf761a9be2723cf778a53f2c136237ef38b15ddd0efb7
%global tidy_tree_source_sha256 1ad1bf3d5f21cb4cbecb29ae6dde34cafad6575b6d162f01742fbce822ad947e
%global mermaid_zenuml_source_sha256 52ef9f2c9103ff0f9c639b5a94ee5b7cb2a1a77f25f2da05dc61bdfb0401e304
%global elkjs_source_sha256 850418c89dd35dbd94ea0100a7becbc09d320c153fda4c4ea4a88c67e12121a9
%global zenuml_core_source_sha256 2ab4a18682e098dfce156b46fb81ea9deb8dc49010b182062f04695688e405f8
%global font_awesome_source_sha256 ec864e5ebabce10c8e7a190584780539a45221ba2f688b46c7c017089d4967d5
%global font_awesome_web_sha256 218d19fdec1bd898d1c78683f3c72e71bcc9e5f9bb3e065f99a5c3cdc48e0d66
%global puppeteer_license_sha256 a27ca07269b3518550b2e83aed13eadd7d14d924b5864e14889b40cf227530ca
%global antlr_license_sha256 3db1fb3ee79a4b4f9918fc4d0f6133bf18a3cf787f126cd22f8aa9b862281c0c
%global dlv_metadata_sha256 d0355a98f75d3547e341ff1cbade270c5d5e9b109dd2b03163178c58b8d525d2
%global mit_license_sha256 b05785f9f18e6716bab63424b11454513b9943a222595b70411009202fc592b5
%global zlib_readme_sha256 53a466b504371dcdda1504c90d8121d4823921f03554c3526995fb2bae7159f9
%global katex_mhchem_sha256 2e59e02033d60c110e5ba70a42f9259c8597bb19dbd03c542e2e5860394376fd

Name:           mermaid-cli
Version:        11.16.0
Release:        0.2%{?dist}
Summary:        Command-line tool for rendering Mermaid diagrams

License:        MIT AND Apache-2.0 AND ISC AND BSD-3-Clause AND 0BSD AND CC-BY-4.0 AND OFL-1.1 AND EPL-2.0 AND (MPL-2.0 OR Apache-2.0) AND Zlib AND Unlicense
URL:            https://github.com/mermaid-js/mermaid-cli
Source0:        https://github.com/mermaid-js/mermaid-cli/archive/refs/tags/%{version}.tar.gz
Source1:        %{name}-%{version}-node-closure.tar.zst
Source2:        %{name}-%{version}-closure.json
Source3:        %{name}-%{version}-bundled-licenses.txt
Source4:        %{name}-%{version}-native.json
Source5:        %{name}-%{version}-third-party-notices.txt
Source6:        %{name}-%{version}-closure-receipt.json
Source7:        https://codeload.github.com/mermaid-js/mermaid/tar.gz/7c0cafcf42e76bfaf79d0cbbd12edb986612f014#/mermaid-7c0cafcf42e76bfaf79d0cbbd12edb986612f014.tar.gz
Source8:        https://codeload.github.com/mermaid-js/mermaid/tar.gz/f4bf04b5db8bed603e40ed3d5ce5228d6b07754e#/mermaid-f4bf04b5db8bed603e40ed3d5ce5228d6b07754e.tar.gz
Source9:        https://codeload.github.com/mermaid-js/mermaid/tar.gz/41646dfd43ac83f001b03c70605feb036afae46d#/mermaid-41646dfd43ac83f001b03c70605feb036afae46d.tar.gz
Source10:       https://codeload.github.com/kieler/elkjs/tar.gz/a8304cf79fde75bc2ab1a89d28320f53f8637436#/elkjs-a8304cf79fde75bc2ab1a89d28320f53f8637436.tar.gz
Source11:       https://codeload.github.com/mermaid-js/zenuml-core/tar.gz/d00800a1a5f3d18bdd78f69dc01600a75bf1d4c0#/zenuml-core-d00800a1a5f3d18bdd78f69dc01600a75bf1d4c0.tar.gz
Source12:       https://codeload.github.com/FortAwesome/Font-Awesome/tar.gz/337dd2045d5621ce0f8567c33c256f3dedeed55d#/font-awesome-337dd2045d5621ce0f8567c33c256f3dedeed55d.tar.gz
Source13:       https://github.com/FortAwesome/Font-Awesome/releases/download/7.2.0/fontawesome-free-7.2.0-web.zip
Source14:       https://raw.githubusercontent.com/puppeteer/puppeteer/4a56c699e50f0cd5ff87dd10e43f7defaf3d95a0/LICENSE#/puppeteer-LICENSE
Source15:       https://raw.githubusercontent.com/antlr/antlr4/67f63fa7f03326305cb0b0175784b08304787831/LICENSE.txt#/antlr4-LICENSE.txt
Source16:       https://raw.githubusercontent.com/developit/dlv/e636db817a96e4ca4710b407163fb992748b3b80d/package.json#/dlv-package.json
Source17:       https://raw.githubusercontent.com/spdx/license-list-data/v3.27.0/text/MIT.txt
Source18:       https://raw.githubusercontent.com/madler/zlib/v1.2.8/README#/zlib-1.2.8-README
Source19:       https://raw.githubusercontent.com/KaTeX/KaTeX/90de97946bb60aa82108d6dbb217cf10602d8709/contrib/mhchem/mhchem.js#/katex-mhchem.js
# Pin the audited Puppeteer release into Fedora's private runtime closure.
# Fedora-specific; upstream intentionally uses a peer dependency in commit 9cf8b75.
Patch0:         mermaid-cli-runtime-puppeteer.patch
# Discover Fedora Chromium and root-container flags when explicit configuration is absent.
# Fedora-specific; upstream supports explicit browser configuration in https://github.com/mermaid-js/mermaid-cli/pull/390.
Patch1:         mermaid-cli-fedora-chromium.patch

BuildArch:      noarch
ExclusiveArch:  %{nodejs_arches} noarch
BuildRequires:  chromium-headless
BuildRequires:  hardlink
BuildRequires:  nodejs >= 22.12
BuildRequires:  nodejs-devel
BuildRequires:  nodejs-packaging
BuildRequires:  python3
BuildRequires:  tar
BuildRequires:  unzip
BuildRequires:  zstd
Requires:       chromium-headless
Requires:       nodejs >= 22.12

Provides:       npm(@mermaid-js/mermaid-cli) = %{version}
# The scoped install path does not trigger Fedora's automatic Node file
# attribute. Generate this block from Source2.
# BEGIN GENERATED BUNDLED NODE PROVIDES
Provides:       bundled(nodejs-@alloc/quick-lru) = 5.2.0
Provides:       bundled(nodejs-@antfu/install-pkg) = 1.1.0
Provides:       bundled(nodejs-@antfu/utils) = 9.2.1
Provides:       bundled(nodejs-@babel/code-frame) = 7.27.1
Provides:       bundled(nodejs-@babel/compat-data) = 7.28.4
Provides:       bundled(nodejs-@babel/core) = 7.28.4
Provides:       bundled(nodejs-@babel/generator) = 7.28.3
Provides:       bundled(nodejs-@babel/helper-compilation-targets) = 7.27.2
Provides:       bundled(nodejs-@babel/helper-globals) = 7.28.0
Provides:       bundled(nodejs-@babel/helper-module-imports) = 7.27.1
Provides:       bundled(nodejs-@babel/helper-module-transforms) = 7.28.3
Provides:       bundled(nodejs-@babel/helper-string-parser) = 7.27.1
Provides:       bundled(nodejs-@babel/helper-validator-identifier) = 7.27.1
Provides:       bundled(nodejs-@babel/helper-validator-option) = 7.27.1
Provides:       bundled(nodejs-@babel/helpers) = 7.28.4
Provides:       bundled(nodejs-@babel/parser) = 7.28.4
Provides:       bundled(nodejs-@babel/template) = 7.27.2
Provides:       bundled(nodejs-@babel/traverse) = 7.28.4
Provides:       bundled(nodejs-@babel/types) = 7.28.4
Provides:       bundled(nodejs-@braintree/sanitize-url) = 7.1.2
Provides:       bundled(nodejs-@chevrotain/types) = 11.1.2
Provides:       bundled(nodejs-@floating-ui/core) = 1.7.5
Provides:       bundled(nodejs-@floating-ui/dom) = 1.7.6
Provides:       bundled(nodejs-@floating-ui/react) = 0.26.28
Provides:       bundled(nodejs-@floating-ui/react) = 0.27.19
Provides:       bundled(nodejs-@floating-ui/react-dom) = 2.1.8
Provides:       bundled(nodejs-@floating-ui/utils) = 0.2.11
Provides:       bundled(nodejs-@fortawesome/fontawesome-free) = 7.2.0
Provides:       bundled(nodejs-@headlessui/react) = 2.2.10
Provides:       bundled(nodejs-@headlessui/tailwindcss) = 0.2.2
Provides:       bundled(nodejs-@iconify/types) = 2.0.0
Provides:       bundled(nodejs-@iconify/utils) = 3.0.2
Provides:       bundled(nodejs-@internationalized/date) = 3.12.1
Provides:       bundled(nodejs-@internationalized/number) = 3.6.6
Provides:       bundled(nodejs-@internationalized/string) = 3.2.8
Provides:       bundled(nodejs-@jridgewell/gen-mapping) = 0.3.12
Provides:       bundled(nodejs-@jridgewell/remapping) = 2.3.5
Provides:       bundled(nodejs-@jridgewell/resolve-uri) = 3.1.2
Provides:       bundled(nodejs-@jridgewell/sourcemap-codec) = 1.5.4
Provides:       bundled(nodejs-@jridgewell/trace-mapping) = 0.3.29
Provides:       bundled(nodejs-@mermaid-js/layout-elk) = 0.2.2
Provides:       bundled(nodejs-@mermaid-js/layout-tidy-tree) = 0.2.2
Provides:       bundled(nodejs-@mermaid-js/mermaid-zenuml) = 0.2.3
Provides:       bundled(nodejs-@mermaid-js/parser) = 1.2.0
Provides:       bundled(nodejs-@nodelib/fs.scandir) = 2.1.5
Provides:       bundled(nodejs-@nodelib/fs.stat) = 2.0.5
Provides:       bundled(nodejs-@nodelib/fs.walk) = 1.2.8
Provides:       bundled(nodejs-@puppeteer/browsers) = 3.0.5
Provides:       bundled(nodejs-@react-aria/focus) = 3.22.0
Provides:       bundled(nodejs-@react-aria/interactions) = 3.28.0
Provides:       bundled(nodejs-@react-types/shared) = 3.34.0
Provides:       bundled(nodejs-@swc/helpers) = 0.5.21
Provides:       bundled(nodejs-@tanstack/react-virtual) = 3.13.24
Provides:       bundled(nodejs-@tanstack/virtual-core) = 3.14.0
Provides:       bundled(nodejs-@types/d3) = 7.4.3
Provides:       bundled(nodejs-@types/d3-array) = 3.2.1
Provides:       bundled(nodejs-@types/d3-axis) = 3.0.6
Provides:       bundled(nodejs-@types/d3-brush) = 3.0.6
Provides:       bundled(nodejs-@types/d3-chord) = 3.0.6
Provides:       bundled(nodejs-@types/d3-color) = 3.1.3
Provides:       bundled(nodejs-@types/d3-contour) = 3.0.6
Provides:       bundled(nodejs-@types/d3-delaunay) = 6.0.4
Provides:       bundled(nodejs-@types/d3-dispatch) = 3.0.6
Provides:       bundled(nodejs-@types/d3-drag) = 3.0.7
Provides:       bundled(nodejs-@types/d3-dsv) = 3.0.7
Provides:       bundled(nodejs-@types/d3-ease) = 3.0.2
Provides:       bundled(nodejs-@types/d3-fetch) = 3.0.7
Provides:       bundled(nodejs-@types/d3-force) = 3.0.10
Provides:       bundled(nodejs-@types/d3-format) = 3.0.4
Provides:       bundled(nodejs-@types/d3-geo) = 3.1.0
Provides:       bundled(nodejs-@types/d3-hierarchy) = 3.1.7
Provides:       bundled(nodejs-@types/d3-interpolate) = 3.0.4
Provides:       bundled(nodejs-@types/d3-path) = 3.1.0
Provides:       bundled(nodejs-@types/d3-polygon) = 3.0.2
Provides:       bundled(nodejs-@types/d3-quadtree) = 3.0.6
Provides:       bundled(nodejs-@types/d3-random) = 3.0.3
Provides:       bundled(nodejs-@types/d3-scale) = 4.0.8
Provides:       bundled(nodejs-@types/d3-scale-chromatic) = 3.0.3
Provides:       bundled(nodejs-@types/d3-selection) = 3.0.11
Provides:       bundled(nodejs-@types/d3-shape) = 3.1.6
Provides:       bundled(nodejs-@types/d3-time) = 3.0.3
Provides:       bundled(nodejs-@types/d3-time-format) = 4.0.3
Provides:       bundled(nodejs-@types/d3-timer) = 3.0.2
Provides:       bundled(nodejs-@types/d3-transition) = 3.0.9
Provides:       bundled(nodejs-@types/d3-zoom) = 3.0.8
Provides:       bundled(nodejs-@types/geojson) = 7946.0.14
Provides:       bundled(nodejs-@types/trusted-types) = 2.0.7
Provides:       bundled(nodejs-@upsetjs/venn.js) = 2.0.0
Provides:       bundled(nodejs-@zenuml/core) = 3.47.2
Provides:       bundled(nodejs-abort-controller) = 3.0.0
Provides:       bundled(nodejs-acorn) = 8.16.0
Provides:       bundled(nodejs-ansi-regex) = 6.2.2
Provides:       bundled(nodejs-ansi-styles) = 6.2.3
Provides:       bundled(nodejs-antlr4) = 4.11.0
Provides:       bundled(nodejs-any-promise) = 1.3.0
Provides:       bundled(nodejs-anymatch) = 3.1.3
Provides:       bundled(nodejs-arg) = 5.0.2
Provides:       bundled(nodejs-aria-hidden) = 1.2.6
Provides:       bundled(nodejs-atomic-sleep) = 1.0.0
Provides:       bundled(nodejs-base64-js) = 1.5.1
Provides:       bundled(nodejs-baseline-browser-mapping) = 2.8.9
Provides:       bundled(nodejs-binary-extensions) = 2.3.0
Provides:       bundled(nodejs-braces) = 3.0.3
Provides:       bundled(nodejs-browserslist) = 4.26.2
Provides:       bundled(nodejs-buffer) = 6.0.3
Provides:       bundled(nodejs-camelcase-css) = 2.0.1
Provides:       bundled(nodejs-caniuse-lite) = 1.0.30001745
Provides:       bundled(nodejs-chalk) = 5.6.2
Provides:       bundled(nodejs-chokidar) = 3.6.0
Provides:       bundled(nodejs-chromium-bidi) = 16.0.1
Provides:       bundled(nodejs-class-variance-authority) = 0.7.1
Provides:       bundled(nodejs-cliui) = 9.0.1
Provides:       bundled(nodejs-clsx) = 2.1.1
Provides:       bundled(nodejs-color-name) = 2.1.0
Provides:       bundled(nodejs-color-string) = 2.1.4
Provides:       bundled(nodejs-commander) = 13.1.0
Provides:       bundled(nodejs-commander) = 4.1.1
Provides:       bundled(nodejs-commander) = 7.2.0
Provides:       bundled(nodejs-commander) = 8.3.0
Provides:       bundled(nodejs-confbox) = 0.1.8
Provides:       bundled(nodejs-confbox) = 0.2.2
Provides:       bundled(nodejs-convert-source-map) = 2.0.0
Provides:       bundled(nodejs-cose-base) = 1.0.3
Provides:       bundled(nodejs-cose-base) = 2.2.0
Provides:       bundled(nodejs-cssesc) = 3.0.0
Provides:       bundled(nodejs-cytoscape) = 3.34.0
Provides:       bundled(nodejs-cytoscape-cose-bilkent) = 4.1.0
Provides:       bundled(nodejs-cytoscape-fcose) = 2.2.0
Provides:       bundled(nodejs-d3) = 7.9.0
Provides:       bundled(nodejs-d3-array) = 2.12.1
Provides:       bundled(nodejs-d3-array) = 3.0.4
Provides:       bundled(nodejs-d3-array) = 3.2.1
Provides:       bundled(nodejs-d3-axis) = 3.0.0
Provides:       bundled(nodejs-d3-brush) = 3.0.0
Provides:       bundled(nodejs-d3-chord) = 3.0.1
Provides:       bundled(nodejs-d3-color) = 3.1.0
Provides:       bundled(nodejs-d3-contour) = 4.0.0
Provides:       bundled(nodejs-d3-delaunay) = 6.0.2
Provides:       bundled(nodejs-d3-dispatch) = 3.0.1
Provides:       bundled(nodejs-d3-drag) = 3.0.0
Provides:       bundled(nodejs-d3-dsv) = 3.0.1
Provides:       bundled(nodejs-d3-ease) = 3.0.1
Provides:       bundled(nodejs-d3-fetch) = 3.0.1
Provides:       bundled(nodejs-d3-force) = 3.0.0
Provides:       bundled(nodejs-d3-format) = 3.0.1
Provides:       bundled(nodejs-d3-geo) = 3.0.1
Provides:       bundled(nodejs-d3-hierarchy) = 3.0.1
Provides:       bundled(nodejs-d3-interpolate) = 3.0.1
Provides:       bundled(nodejs-d3-path) = 1.0.9
Provides:       bundled(nodejs-d3-path) = 3.0.1
Provides:       bundled(nodejs-d3-polygon) = 3.0.1
Provides:       bundled(nodejs-d3-quadtree) = 3.0.1
Provides:       bundled(nodejs-d3-random) = 3.0.1
Provides:       bundled(nodejs-d3-sankey) = 0.12.3
Provides:       bundled(nodejs-d3-scale) = 4.0.2
Provides:       bundled(nodejs-d3-scale-chromatic) = 3.0.0
Provides:       bundled(nodejs-d3-selection) = 3.0.0
Provides:       bundled(nodejs-d3-shape) = 1.3.7
Provides:       bundled(nodejs-d3-shape) = 3.0.1
Provides:       bundled(nodejs-d3-time) = 3.0.0
Provides:       bundled(nodejs-d3-time-format) = 4.0.0
Provides:       bundled(nodejs-d3-timer) = 3.0.1
Provides:       bundled(nodejs-d3-transition) = 3.0.1
Provides:       bundled(nodejs-d3-zoom) = 3.0.0
Provides:       bundled(nodejs-dagre-d3-es) = 7.0.14
Provides:       bundled(nodejs-dayjs) = 1.11.20
Provides:       bundled(nodejs-debug) = 4.4.3
Provides:       bundled(nodejs-delaunator) = 5.0.0
Provides:       bundled(nodejs-devtools-protocol) = 0.0.1638949
Provides:       bundled(nodejs-didyoumean) = 1.2.2
Provides:       bundled(nodejs-dlv) = 1.1.3
Provides:       bundled(nodejs-dompurify) = 3.4.11
Provides:       bundled(nodejs-electron-to-chromium) = 1.5.227
Provides:       bundled(nodejs-elkjs) = 0.9.3
Provides:       bundled(nodejs-emoji-regex) = 10.6.0
Provides:       bundled(nodejs-es-toolkit) = 1.46.1
Provides:       bundled(nodejs-escalade) = 3.2.0
Provides:       bundled(nodejs-event-target-shim) = 5.0.1
Provides:       bundled(nodejs-events) = 3.3.0
Provides:       bundled(nodejs-exsolve) = 1.0.7
Provides:       bundled(nodejs-fast-glob) = 3.3.3
Provides:       bundled(nodejs-fast-redact) = 3.5.0
Provides:       bundled(nodejs-fastq) = 1.15.0
Provides:       bundled(nodejs-fdir) = 6.5.0
Provides:       bundled(nodejs-fill-range) = 7.1.1
Provides:       bundled(nodejs-function-bind) = 1.1.2
Provides:       bundled(nodejs-gensync) = 1.0.0-beta.2
Provides:       bundled(nodejs-get-caller-file) = 2.0.5
Provides:       bundled(nodejs-get-east-asian-width) = 1.6.0
Provides:       bundled(nodejs-glob-parent) = 5.1.2
Provides:       bundled(nodejs-glob-parent) = 6.0.2
Provides:       bundled(nodejs-globals) = 15.15.0
Provides:       bundled(nodejs-hachure-fill) = 0.5.2
Provides:       bundled(nodejs-hasown) = 2.0.2
Provides:       bundled(nodejs-highlight.js) = 10.7.3
Provides:       bundled(nodejs-html-to-image) = 1.11.13
Provides:       bundled(nodejs-iconv-lite) = 0.6.3
Provides:       bundled(nodejs-ieee754) = 1.2.1
Provides:       bundled(nodejs-immer) = 10.2.0
Provides:       bundled(nodejs-import-meta-resolve) = 4.2.0
Provides:       bundled(nodejs-internmap) = 1.0.1
Provides:       bundled(nodejs-internmap) = 2.0.3
Provides:       bundled(nodejs-is-binary-path) = 2.1.0
Provides:       bundled(nodejs-is-core-module) = 2.16.1
Provides:       bundled(nodejs-is-extglob) = 2.1.1
Provides:       bundled(nodejs-is-glob) = 4.0.3
Provides:       bundled(nodejs-is-number) = 7.0.0
Provides:       bundled(nodejs-jiti) = 1.21.7
Provides:       bundled(nodejs-jotai) = 2.19.1
Provides:       bundled(nodejs-js-tokens) = 4.0.0
Provides:       bundled(nodejs-jsesc) = 3.1.0
Provides:       bundled(nodejs-json5) = 2.2.3
Provides:       bundled(nodejs-katex) = 0.16.45
Provides:       bundled(nodejs-khroma) = 2.1.0
Provides:       bundled(nodejs-kolorist) = 1.8.0
Provides:       bundled(nodejs-layout-base) = 1.0.2
Provides:       bundled(nodejs-layout-base) = 2.0.1
Provides:       bundled(nodejs-lilconfig) = 3.1.3
Provides:       bundled(nodejs-lines-and-columns) = 1.2.4
Provides:       bundled(nodejs-local-pkg) = 1.1.2
Provides:       bundled(nodejs-lodash) = 4.18.1
Provides:       bundled(nodejs-lodash-es) = 4.18.1
Provides:       bundled(nodejs-lru-cache) = 5.1.1
Provides:       bundled(nodejs-marked) = 16.3.0
Provides:       bundled(nodejs-marked) = 4.3.0
Provides:       bundled(nodejs-merge2) = 1.4.1
Provides:       bundled(nodejs-mermaid) = 11.16.0
Provides:       bundled(nodejs-micromatch) = 4.0.8
Provides:       bundled(nodejs-mitt) = 3.0.1
Provides:       bundled(nodejs-mlly) = 1.8.0
Provides:       bundled(nodejs-modern-tar) = 0.7.6
Provides:       bundled(nodejs-ms) = 2.1.3
Provides:       bundled(nodejs-mz) = 2.7.0
Provides:       bundled(nodejs-nanoid) = 3.3.11
Provides:       bundled(nodejs-node-releases) = 2.0.21
Provides:       bundled(nodejs-normalize-path) = 3.0.0
Provides:       bundled(nodejs-object-assign) = 4.1.1
Provides:       bundled(nodejs-object-hash) = 3.0.0
Provides:       bundled(nodejs-on-exit-leak-free) = 2.1.2
Provides:       bundled(nodejs-p-limit) = 6.2.0
Provides:       bundled(nodejs-package-manager-detector) = 1.3.0
Provides:       bundled(nodejs-pako) = 2.1.0
Provides:       bundled(nodejs-path-data-parser) = 0.1.0
Provides:       bundled(nodejs-path-parse) = 1.0.7
Provides:       bundled(nodejs-pathe) = 2.0.3
Provides:       bundled(nodejs-picocolors) = 1.1.1
Provides:       bundled(nodejs-picomatch) = 2.3.2
Provides:       bundled(nodejs-picomatch) = 4.0.4
Provides:       bundled(nodejs-pify) = 2.3.0
Provides:       bundled(nodejs-pino) = 8.21.0
Provides:       bundled(nodejs-pino-abstract-transport) = 1.2.0
Provides:       bundled(nodejs-pino-std-serializers) = 6.2.2
Provides:       bundled(nodejs-pirates) = 4.0.7
Provides:       bundled(nodejs-pkg-types) = 1.3.1
Provides:       bundled(nodejs-pkg-types) = 2.3.0
Provides:       bundled(nodejs-points-on-curve) = 0.2.0
Provides:       bundled(nodejs-points-on-path) = 0.2.1
Provides:       bundled(nodejs-postcss) = 8.5.12
Provides:       bundled(nodejs-postcss-import) = 15.1.0
Provides:       bundled(nodejs-postcss-js) = 4.1.0
Provides:       bundled(nodejs-postcss-load-config) = 6.0.1
Provides:       bundled(nodejs-postcss-nested) = 6.2.0
Provides:       bundled(nodejs-postcss-selector-parser) = 6.1.2
Provides:       bundled(nodejs-postcss-value-parser) = 4.2.0
Provides:       bundled(nodejs-process) = 0.11.10
Provides:       bundled(nodejs-process-warning) = 3.0.0
Provides:       bundled(nodejs-puppeteer) = 25.2.1
Provides:       bundled(nodejs-puppeteer-core) = 25.2.1
Provides:       bundled(nodejs-quansync) = 0.2.11
Provides:       bundled(nodejs-queue-microtask) = 1.2.3
Provides:       bundled(nodejs-quick-format-unescaped) = 4.0.4
Provides:       bundled(nodejs-react) = 19.2.5
Provides:       bundled(nodejs-react-aria) = 3.48.0
Provides:       bundled(nodejs-react-dom) = 19.2.5
Provides:       bundled(nodejs-react-stately) = 3.46.0
Provides:       bundled(nodejs-read-cache) = 1.0.0
Provides:       bundled(nodejs-readable-stream) = 4.7.0
Provides:       bundled(nodejs-readdirp) = 3.6.0
Provides:       bundled(nodejs-real-require) = 0.2.0
Provides:       bundled(nodejs-resolve) = 1.22.10
Provides:       bundled(nodejs-reusify) = 1.0.4
Provides:       bundled(nodejs-robust-predicates) = 3.0.1
Provides:       bundled(nodejs-roughjs) = 4.6.6
Provides:       bundled(nodejs-run-parallel) = 1.2.0
Provides:       bundled(nodejs-rw) = 1.3.3
Provides:       bundled(nodejs-safe-buffer) = 5.2.1
Provides:       bundled(nodejs-safe-stable-stringify) = 2.5.0
Provides:       bundled(nodejs-safer-buffer) = 2.1.2
Provides:       bundled(nodejs-scheduler) = 0.27.0
Provides:       bundled(nodejs-semver) = 6.3.1
Provides:       bundled(nodejs-sonic-boom) = 3.8.1
Provides:       bundled(nodejs-source-map-js) = 1.2.1
Provides:       bundled(nodejs-split2) = 4.2.0
Provides:       bundled(nodejs-string-width) = 7.2.0
Provides:       bundled(nodejs-string_decoder) = 1.3.0
Provides:       bundled(nodejs-strip-ansi) = 7.2.0
Provides:       bundled(nodejs-stylis) = 4.3.6
Provides:       bundled(nodejs-sucrase) = 3.35.1
Provides:       bundled(nodejs-supports-preserve-symlinks-flag) = 1.0.0
Provides:       bundled(nodejs-tabbable) = 6.4.0
Provides:       bundled(nodejs-tailwind-merge) = 3.5.0
Provides:       bundled(nodejs-tailwindcss) = 3.4.19
Provides:       bundled(nodejs-thenify) = 3.3.1
Provides:       bundled(nodejs-thenify-all) = 1.6.0
Provides:       bundled(nodejs-thread-stream) = 2.7.0
Provides:       bundled(nodejs-tinyexec) = 1.0.1
Provides:       bundled(nodejs-tinyglobby) = 0.2.16
Provides:       bundled(nodejs-to-regex-range) = 5.0.1
Provides:       bundled(nodejs-ts-dedent) = 2.2.0
Provides:       bundled(nodejs-ts-interface-checker) = 0.1.13
Provides:       bundled(nodejs-tslib) = 2.8.1
Provides:       bundled(nodejs-typed-query-selector) = 2.12.2
Provides:       bundled(nodejs-ufo) = 1.6.1
Provides:       bundled(nodejs-update-browserslist-db) = 1.1.3
Provides:       bundled(nodejs-use-sync-external-store) = 1.6.0
Provides:       bundled(nodejs-util-deprecate) = 1.0.2
Provides:       bundled(nodejs-uuid) = 11.1.0
Provides:       bundled(nodejs-webdriver-bidi-protocol) = 0.4.2
Provides:       bundled(nodejs-wrap-ansi) = 9.0.2
Provides:       bundled(nodejs-ws) = 8.21.0
Provides:       bundled(nodejs-y18n) = 5.0.8
Provides:       bundled(nodejs-yallist) = 3.1.1
Provides:       bundled(nodejs-yargs) = 18.0.0
Provides:       bundled(nodejs-yargs-parser) = 22.0.0
Provides:       bundled(nodejs-yocto-queue) = 1.2.2
Provides:       bundled(nodejs-zod) = 3.25.76
# END GENERATED BUNDLED NODE PROVIDES

%description
Mermaid CLI renders Mermaid diagram definitions to SVG, PNG, or PDF by driving
a headless Chromium browser with Puppeteer.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{closure_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{manifest_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{license_inventory_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{native_manifest_sha256}  %{SOURCE4}" | sha256sum -c -
echo "%{notices_sha256}  %{SOURCE5}" | sha256sum -c -
echo "%{receipt_sha256}  %{SOURCE6}" | sha256sum -c -
echo "%{mermaid_source_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{tidy_tree_source_sha256}  %{SOURCE8}" | sha256sum -c -
echo "%{mermaid_zenuml_source_sha256}  %{SOURCE9}" | sha256sum -c -
echo "%{elkjs_source_sha256}  %{SOURCE10}" | sha256sum -c -
echo "%{zenuml_core_source_sha256}  %{SOURCE11}" | sha256sum -c -
echo "%{font_awesome_source_sha256}  %{SOURCE12}" | sha256sum -c -
echo "%{font_awesome_web_sha256}  %{SOURCE13}" | sha256sum -c -
echo "%{puppeteer_license_sha256}  %{SOURCE14}" | sha256sum -c -
echo "%{antlr_license_sha256}  %{SOURCE15}" | sha256sum -c -
echo "%{dlv_metadata_sha256}  %{SOURCE16}" | sha256sum -c -
echo "%{mit_license_sha256}  %{SOURCE17}" | sha256sum -c -
echo "%{zlib_readme_sha256}  %{SOURCE18}" | sha256sum -c -
echo "%{katex_mhchem_sha256}  %{SOURCE19}" | sha256sum -c -
%autosetup -p1 -n mermaid-cli-%{version}

python3 - %{SOURCE2} %{SOURCE4} %{SOURCE6} <<'PY'
import json
import sys

closure = json.load(open(sys.argv[1], encoding="utf-8"))
native = json.load(open(sys.argv[2], encoding="utf-8"))
receipt = json.load(open(sys.argv[3], encoding="utf-8"))

assert closure["package"] == native["package"] == receipt["package"] == "mermaid-cli"
assert closure["version"] == native["version"] == receipt["version"] == "%{version}"
assert len(closure["packages"]) == receipt["package_count"] == native["checked_paths"]
assert len(closure["source_archives"]) == receipt["source_archive_count"]
assert len(closure["supplemental_notices"]) == receipt["supplemental_notice_count"] == 5
assert len(closure["preferred_sources"]) == receipt["preferred_source_count"] == 7
assert closure["lockfile"]["published_sha256"] == receipt["published_lock_sha256"]
assert closure["lockfile"]["runtime_sha256"] == receipt["runtime_lock_sha256"]
assert native["native_payloads"] == []
assert receipt["native_payloads_absent"] is True
assert receipt["source_tarballs_scanned"] is True
assert receipt["materialized_tree_scanned"] is True
assert receipt["archive_paths_scanned"] is True
assert receipt["browser_downloads"] is False
assert receipt["lifecycle_scripts_executed"] is False
PY
tar --extract --zstd --file %{SOURCE1}
test -d node_modules
echo "7d0322e923419bbe61611de3cde87711fdb95b83409564cda5b7a8cb367fccf9  runtime-package-lock.json" | sha256sum -c -

mkdir fontawesome-release
unzip -q %{SOURCE13} -d fontawesome-release
for font in fa-solid-900.woff2 fa-regular-400.woff2 fa-brands-400.woff2; do
  cmp \
    "fontawesome-release/fontawesome-free-7.2.0-web/webfonts/$font" \
    "node_modules/@fortawesome/fontawesome-free/webfonts/$font"
done

%build
# Vite only copies this source document into dist for the CLI runtime. Avoid
# importing the development-only Vite/Rollup/esbuild closure.
install -Dpm0644 index.html dist/index.html

# npm application archives often include tests, benchmarks, source maps, build
# scripts, and repository metadata. They remain in Source1 and its original
# tarballs for auditability, but are not required by the installed renderer.
python3 - <<'PY'
import os
import shutil
from pathlib import Path

root = Path("node_modules")
pruned_directories = {
    ".agents", ".claude", ".devcontainer", ".github", ".husky", ".idea",
    ".kiro", ".specify", ".storybook", "benchmark", "benchmarks", "coverage",
    "demo", "demos", "docs", "example", "examples", "test", "tests", "__tests__",
}

for current, directories, files in os.walk(root, topdown=True):
    current_path = Path(current)
    for directory in list(directories):
        if directory == ".bin" or directory in pruned_directories:
            shutil.rmtree(current_path / directory)
            directories.remove(directory)

    for filename in files:
        path = current_path / filename
        lower = filename.lower()
        if filename.startswith("."):
            path.unlink()
            continue
        if lower.endswith((".d.ts", ".d.cts", ".map", ".ts", ".tsx")):
            path.unlink()
            continue
        if lower.endswith((".md", ".markdown")) or lower.startswith(("license", "copying", "notice", "copyright")):
            path.unlink()
            continue

        data = path.read_bytes()
        if data.startswith(b"#!"):
            path.unlink()
            continue
        if not data:
            if lower.endswith((".js", ".mjs", ".cjs")):
                path.write_text("\n", encoding="utf-8")
            else:
                path.unlink()
                continue
        path.chmod(0o644)

Path("src/cli.js").chmod(0o755)
PY

# Mermaid CLI imports only the solid, regular, and brands Font Awesome CSS.
rm -f node_modules/@fortawesome/fontawesome-free/webfonts/fa-v4compatibility.woff2
hardlink -c node_modules

%check
checkroot="$PWD/.check-root"
install -d "$checkroot%{nodejs_sitelib}/@mermaid-js/mermaid-cli" "$checkroot%{_bindir}"
cp -a src dist node_modules package.json LICENSE README.md \
  "$checkroot%{nodejs_sitelib}/@mermaid-js/mermaid-cli/"
ln -s ../lib/node_modules/@mermaid-js/mermaid-cli/src/cli.js \
  "$checkroot%{_bindir}/mmdc"
mkdir -p .check
cat > .check/diagram.mmd <<EOF
flowchart TD
  A["fas:fa-camera-retro Source"] --> B["far:fa-address-card Mermaid CLI"]
  B --> C["fab:fa-github Fedora"]
EOF

export PUPPETEER_SKIP_DOWNLOAD=true
export PUPPETEER_CACHE_DIR="$PWD/.check/empty-puppeteer-cache"
"$checkroot%{_bindir}/mmdc" --version | grep -Fx '%{version}'
"$checkroot%{_bindir}/mmdc" -i .check/diagram.mmd -o .check/diagram.svg
"$checkroot%{_bindir}/mmdc" -i .check/diagram.mmd -o .check/diagram.png
"$checkroot%{_bindir}/mmdc" -i .check/diagram.mmd -o .check/diagram.pdf
python3 - <<'PY'
from pathlib import Path

assert b"<svg" in Path(".check/diagram.svg").read_bytes()[:1024]
assert Path(".check/diagram.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
assert Path(".check/diagram.pdf").read_bytes().startswith(b"%PDF-")
PY

%install
install -d %{buildroot}%{nodejs_sitelib}/@mermaid-js/mermaid-cli
cp -a src dist node_modules package.json \
  %{buildroot}%{nodejs_sitelib}/@mermaid-js/mermaid-cli/
rm -rf %{buildroot}%{nodejs_sitelib}/@mermaid-js/mermaid-cli/node_modules/.bin
install -d %{buildroot}%{_bindir}
ln -s ../lib/node_modules/@mermaid-js/mermaid-cli/src/cli.js \
  %{buildroot}%{_bindir}/mmdc
install -Dpm0644 %{SOURCE3} \
  %{buildroot}%{_licensedir}/%{name}/bundled-licenses.txt
install -Dpm0644 %{SOURCE5} \
  %{buildroot}%{_licensedir}/%{name}/THIRD-PARTY-NOTICES
install -Dpm0644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE
install -Dpm0644 README.md %{buildroot}%{_docdir}/%{name}/README.md

%files
%license %{_licensedir}/%{name}/LICENSE
%license %{_licensedir}/%{name}/bundled-licenses.txt
%license %{_licensedir}/%{name}/THIRD-PARTY-NOTICES
%doc %{_docdir}/%{name}/README.md
%{_bindir}/mmdc
%{nodejs_sitelib}/@mermaid-js/mermaid-cli/

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 11.16.0-0.2
- Add Fedora Node build mechanics and document downstream patch status.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 11.16.0-0.1
- Build the audited production closure with Fedora Chromium and corresponding sources.
