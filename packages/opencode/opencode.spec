# Disabled by package.yml until Bun and the audited npm source closure are
# available. Do not replace these inputs with upstream platform binaries.
%global debug_package %{nil}
%global __strip /bin/true
%global source_sha256 eb3daee12da937a36c3276efda2ce1253d3c8fbe2828ebd581a39a2c2d3efdab
%global bun_pty_commit 41dd5b887f3f47d7c307fd93f828a75dbee97d5a
%global bun_pty_source_sha256 d4731314a00c46d3810fa08b94ee0bcddb7a5026e47dbca88c83449d351bff9e
%global bun_pty_vendor_sha256 5c22d4bd79109a3460f3a3d3840d2541da9a6c4c91513c39065a1f4611b7ec5e
%global bun_pty_vendor_manifest_sha256 d57a66c2a1e90516e0b103b3074001f96cefcb4adb4ecc8c3a5532a2c884e500
%global opentui_version 0.4.5
%global opentui_source_sha256 a87acc1af6d5f62ee48905176965514b06c7b6e8f9c1fe869604e5933825ca50
%global opentui_published_sha256 ce73133a58d35e35610ef53353ddeeeb93fb29505dde0cf1854ce25facee241d
%global uucode_commit 84ceda8561a17ba4a9b96ac5c583f779660bbd4e
%global uucode_source_sha256 4a7f194ad1f583ffae00bf625986527df89ddd55309ff30314d2d17539a7b011
%global uucode_zig_hash uucode-0.1.0-ZZjBPtA_TQCWp5PIKmfm5tu1WOkKWFmBGFEMxircPfkA
%global yoga_commit 042f5013152eb81c1552dec945b88f7b95ca350f
%global yoga_source_sha256 86b399ac31fd820d8ffa823c3fae31bb690b6fc45301b2a8a966c09b5a088b55
%global yoga_zig_hash N-V-__8AAOYl0gAU76B1VRPFD9AWvy2VkOef2jN0B3sISTeO
%global zig_commit 04e7f6ac1e009525bc00934f20199c68f04e0a24
%global zig_source_sha256 b094c5f806d053896de897023b6c8ccb56903fb994c6f86dd44d848e760fe44d
%global tree_sitter_version 0.25.10
%global tree_sitter_source_sha256 ad5040537537012b16ef6e1210a572b927c7cdc2b99d1ee88d44a7dcdc3ff44c
%global emscripten_version 4.0.4
%global emscripten_source_sha256 02214fec16769fd5761585baf0038d08c3c1f33d2b7b179953c6fb7e4e04470e
%global binaryen_version 121
%global binaryen_source_sha256 93f3b3d62def4aee6d09b11e6de75b955d29bc37878117e4ed30c3057a2ca4b4
%global esbuild_version 0.24.2
%global esbuild_source_sha256 171e1b0cd4c64222a1953203f6b3dab3c7a3f95b8939a72b4ebbd024302513b4
%global x_sys_version v0.0.0-20220715151400-c0bba94af5f8
%global x_sys_source_sha256 3b180937216e93559f16b6076d09baf54a5707378f11b867b6eb914c56b09b91
%global acorn_source_sha256 04c1f5545e4e9140e288bb56b4cbbc4ffd730213e6331330e2bcefc649462104
%global esbuild_npm_source_sha256 873e6170dc7f8bdd0e7a84daf2dfcec4744831271929bca044d6b7216ff86b47
%global tree_sitter_runtime_helper_sha256 2e143b7c1a115e2effef7d6fc3f282023b8e25fda8fe2a0cd947ffe14e5c952a
%global tree_sitter_validator_sha256 57a6b7e6c3b2e2322baf037369fb38012a76c47d3f251187678b13da05eccefc
%global bash_published_wasm_sha256 364f0a2cd385c792239423026ef442dbd073d34c396b7bc9e5932426b8e4aa5d
%global powershell_published_wasm_sha256 1d30b5a21866354aa2eb94845556f1e19126ff00e3335048719a0e6435b1c154
%global web_tree_sitter_published_wasm_sha256 f38dcc4b43b818f9a0785bc1c6d5611a75ac4cdd428ff3f02757c34ca4e46d7f
%global web_tree_sitter_published_aux_wasm_sha256 2b8b96e0f0f4624c4f885d40d76e25a25d9c58d40fe8ff4ab9563ee0297eed5e
%global opentui_javascript_source_sha256 a13fa28148e41bb939b2c2b8cd73c4b4295273b70cbac55a7a589020f52b9611
%global opentui_typescript_source_sha256 4de2e82e557810eecb93cb3b31fbb3bd28ba4c91ba9a6c6164bcaa074125b7b5
%global opentui_markdown_source_sha256 74138adf4535291593560d401bf0a6f0b3cc8a0c43d0912f462e5590f7e8fbb9
%global opentui_zig_grammar_source_sha256 c7af5b1a992fcaffdf50a11a9974fbf8f09d20c4d9ef42245ac90c152dd3a85a
%global shiki_vscode_oniguruma_source_sha256 7b3616492af2d012bdb8904e35c6a5584f8d4326bfe013ebbda079330cf3c1ed
%global shiki_oniguruma_source_sha256 197bdc01b6e71245ca95e652827fe53c4b1532a4175870f62157b5f909fa0e6f
%global shiki_published_wasm_sha256 fd885c2d12e5951e59d761ebd4a006e06254b1491fd6f530c92b69fb4d8d77d9
%global shiki_rebuilt_wasm_sha256 1ef5a51b6e7d2d2b9caeb0563368a8e8807699aab50f3ff9bc0fa480564212d0
%global undici_llhttp_source_sha256 ca8b68d982b1c2a7aa28599fe46596738f17fffd05d2ad27d7ffc3e7fca43591
%global undici_published_wasm_sha256 ee82b848a5ca8e9f99fda109e59bbc20193d049a7f6bff93f4130cba5b68261c
%global undici_published_simd_wasm_sha256 cd48aefa974e9fc21adec14ef0c73f0ad501b598078b12568ed129c320318154
%global undici_rebuilt_wasm_sha256 58fe510f2f5dbb5f79bc2ab0d108ebe7d0ee49f2938bc82d737e82809cab3dcb
%global undici_rebuilt_simd_wasm_sha256 276a49065fdce6e19c2083fb0dea3b53c390f382c0e6dd3370dbc7fa19f48a57
%global models_dev_source_sha256 d620cc51536d56d8d8d1a84f1de444d91f7afd116fe5e3e0c08e1a13011df905
%global models_dev_zod_sha256 f365a049bd1fcc3079e91d9cbcf968b7adce705662bfb3ca1ab3930c03b2ede3
%global models_dev_snapshot_sha256 8b78d7b16423318fb59e61c22118638952b76fc892b315c002dc3854c8618287
%global models_dev_proof_sha256 3b54b21170b3901f3614284ad301ceb1706e310cda027849a55f234bcc6ca1aa
%global source_license_set_proof_sha256 62fc352dd22085a2375c06a3cd6a996ac01534fd27132ab49464d47c540854ef
%global source_materialization_sha256 518e0b781a8e1ed5a1683fcf7095be1b22360e8d6a7ef101a131d64cbdc13719
%global source_audit_sha256 59f91dcb3be45a1b3b95a1428dd7a9ef656548e0acacd4e74b7e4ccd65b734f5
%global node_modules_materializer_sha256 d49cdf57f7c2b86103e63d829f00eebbb3d72c5ec985b12186b54ed188d55668
%global binary_embedding_auditor_sha256 9f77823c4ef29d38bb1a09f0a322d337765de9b3e284e5b6d370fea3d0ff8451
%global binary_embedding_receipt_sha256 496be59e95b845de847bced424c0e48a340969568eacea7f01fa0b12ae2a0f14
%global final_license_auditor_sha256 8e8f8033df0e0770263112fa0a8feb563a67f0cf3c05a7b009ad28d3508d9c9f
%global final_license_receipt_sha256 30c59bfaeff906cd00f2413621acd033706937362f20c13d1ee4c4cc56d79f96
%global bundle_metafile_patch_sha256 1bc11636ab26929ce0dfaa9d1ae93f35f3f4aecabd8f7b72a3b2ed3fe52932b4
%global license_review_sha256 4248cf9d4e78236ad4b30f403137ff33f8b300b9fbd9cbf7f55a9599cc149848
%global aws_sdk_license_sha256 edea91454b811f127fbdea3d86f378f6719bd372ed440abf82b232f6fca06c3d
%global sigstore_verify_license_sha256 364a130d2ca340bd56eb1e6d045fc6929bb0f9d0aa018f2c1949b29517e1cdd0
%global drizzle_orm_license_sha256 c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4
%global poe_platform_license_sha256 0f5d2ae231c0461da14b21ac8594071bb51be33e6a3dcc2b105813c69e7f4a13
%global remeda_license_sha256 acf30083045d768ce20640237313ee31a45d548d66ef76df5bb5fb0745479535
%global spdx_exceptions_readme_sha256 554b19eee11d2964e9f7b244e47944c08d52ca75539260a04f3227e6c0144513
%global photon_source_version 0.3.3
%global photon_source_sha256 06e9b6d764d6656aba14f5ae43fbf48ce98ff1b1a6beb4d2e801eb0729f88773
%global photon_cargo_lock_sha256 aa3e9c86b0380b8cd5cb768985f7e270aab01a5b35c24cbfa8533fa74343318f
%global photon_vendor_sha256 d0199923d17ae664abecc7f9e8edab1e25f42467ac33c616079e72e14072f00a
%global photon_vendor_manifest_sha256 f2eb6e04b6ef90b192bbbac4f7555c3cfb7803391a04256f48c09f111cf82159
%global photon_vendor_source_date_epoch 1746901403
%global photon_published_wasm_sha256 10468181565c56004c867f3a4af96f89a0ef5a63a72f2b5fb12c1f1992a3615c
%global photon_raw_wasm_sha256 d4fd63da1fbfdb7d88f0800547efaba1a01173b59df080fc6b0383074da7418d
%global photon_rebuilt_wasm_sha256 be53f0a699e3e5d9fd59b7108dc888fe95e4b85839c2e91c3af3a199e5a0e783
%global photon_license_sha256 c984c291167af70cc5fb7c7f4cec9b4560565110b766a718b3e12aba650327a7
%global wasm_bindgen_cli_source_version 0.2.95
%global wasm_bindgen_cli_source_sha256 9380d84c4d0563c54a8177ad3fe14b12f673beb699e50c01fb4703fca68c7cd4
%global wasm_bindgen_cli_cargo_lock_sha256 ac1c77d9c5db87f99edf1373891e5d937819578f493e81b3de095434dcb0534e
%global wasm_bindgen_cli_vendor_sha256 338fa52c864c963db1d283a6082203029418541d1b3ff10bef38a3356c85c2f3
%global wasm_bindgen_cli_vendor_manifest_sha256 d274e859ec2dd094ad7fa8090e3b66852323c9e8eb2c5d8de84093ff038956be
%global wasm_bindgen_cli_vendor_source_date_epoch 1728598471

Name:           opencode
Version:        1.18.5
Release:        0.16%{?dist}
Summary:        Open-source AI coding agent

# MIT covers OpenCode itself. Final license metadata must reflect OpenCode and
# the audited package-local source closure.
License:        MIT
URL:            https://github.com/anomalyco/opencode
Source0:        https://github.com/anomalyco/opencode/archive/refs/tags/v%{version}.tar.gz
Source1:        %{name}-%{version}-nm-prod-build.tar.zst
Source2:        %{name}-%{version}-nm-dev-test.tar.zst
Source3:        %{name}-%{version}-closure.json
Source4:        %{name}-%{version}-bundled-licenses.txt
Source5:        %{name}-%{version}-native.json
Source6:        https://github.com/sursaone/bun-pty/archive/%{bun_pty_commit}/bun-pty-%{bun_pty_commit}.tar.gz
Source7:        %{name}-%{version}-bun-pty-cargo-vendor.tar.zst
Source8:        %{name}-%{version}-bun-pty-cargo-vendor.txt
Source9:        https://github.com/anomalyco/opentui/archive/refs/tags/v%{opentui_version}.tar.gz#/%{name}-%{version}-opentui-%{opentui_version}.tar.gz
Source10:       https://github.com/jacobsandlund/uucode/archive/%{uucode_commit}.tar.gz#/%{name}-%{version}-uucode-%{uucode_commit}.tar.gz
Source11:       https://github.com/facebook/yoga/archive/refs/tags/v3.2.1.tar.gz#/%{name}-%{version}-yoga-%{yoga_commit}.tar.gz
Source12:       https://codeload.github.com/oven-sh/zig/tar.gz/%{zig_commit}#/%{name}-%{version}-zig-%{zig_commit}.tar.gz
Source13:       https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v%{tree_sitter_version}.tar.gz#/%{name}-%{version}-tree-sitter-%{tree_sitter_version}.tar.gz
Source14:       https://github.com/emscripten-core/emscripten/archive/refs/tags/%{emscripten_version}.tar.gz#/%{name}-%{version}-emscripten-%{emscripten_version}.tar.gz
Source15:       https://github.com/WebAssembly/binaryen/archive/refs/tags/version_%{binaryen_version}.tar.gz#/%{name}-%{version}-binaryen-%{binaryen_version}.tar.gz
Source16:       https://github.com/evanw/esbuild/archive/refs/tags/v%{esbuild_version}.tar.gz#/%{name}-%{version}-esbuild-%{esbuild_version}.tar.gz
Source17:       https://proxy.golang.org/golang.org/x/sys/@v/%{x_sys_version}.zip#/%{name}-%{version}-x-sys-%{x_sys_version}.zip
Source18:       https://registry.npmjs.org/acorn/-/acorn-8.14.0.tgz#/%{name}-%{version}-acorn-8.14.0.tgz
Source19:       https://registry.npmjs.org/esbuild/-/esbuild-%{esbuild_version}.tgz#/%{name}-%{version}-esbuild-npm-%{esbuild_version}.tgz
Source20:       opencode-build-web-tree-sitter-runtime.py
Source21:       opencode-validate-tree-sitter.mjs
Source22:       https://codeload.github.com/tree-sitter/tree-sitter-javascript/tar.gz/44c892e0be055ac465d5eeddae6d3e194424e7de#/%{name}-%{version}-tree-sitter-javascript-0.25.0.tar.gz
Source23:       https://codeload.github.com/tree-sitter/tree-sitter-typescript/tar.gz/f975a621f4e7f532fe322e13c4f79495e0a7b2e7#/%{name}-%{version}-tree-sitter-typescript-0.23.2.tar.gz
Source24:       https://codeload.github.com/tree-sitter-grammars/tree-sitter-markdown/tar.gz/2dfd57f547f06ca5631a80f601e129d73fc8e9f0#/%{name}-%{version}-tree-sitter-markdown-0.5.1.tar.gz
Source25:       https://codeload.github.com/tree-sitter-grammars/tree-sitter-zig/tar.gz/b670c8df85a1568f498aa5c8cae42f51a90473c0#/%{name}-%{version}-tree-sitter-zig-1.1.2.tar.gz
Source26:       https://codeload.github.com/microsoft/vscode-oniguruma/tar.gz/716aeaa229e4ae2e3b0057377b55743e9a3e995b#/%{name}-%{version}-vscode-oniguruma-1.7.0.tar.gz
Source27:       https://codeload.github.com/kkos/oniguruma/tar.gz/08d36110c5670c815ad6d6f969e578049d209080#/%{name}-%{version}-oniguruma-08d36110.tar.gz
Source28:       https://codeload.github.com/nodejs/llhttp/tar.gz/a294239338eff8bffd4c709265ab8f5a11e57e41#/%{name}-%{version}-llhttp-release-8.1.0.tar.gz
Source29:       https://codeload.github.com/anomalyco/models.dev/tar.gz/1eb0b8c8e17ffddd89f53b2a3e426777dc560542#/%{name}-%{version}-models-dev-1eb0b8c8.tar.gz
Source30:       https://registry.npmjs.org/zod/-/zod-3.24.2.tgz#/%{name}-%{version}-zod-3.24.2.tgz
Source31:       models-snapshot-proof.json
Source32:       source-license-set-proof.json
Source33:       opencode-1.18.5-source-materialization.json
Source34:       opencode-1.18.5-source-audit.json
Source35:       materialize-opencode-node-modules
Source36:       audit-opencode-binary-embedding
Source37:       opencode-1.18.5-binary-embedding.json
Source38:       license-review.yml
Source39:       https://raw.githubusercontent.com/aws/aws-sdk-js-v3/4b035429227c5be4093e5b3898a4eb5dc70824b0/LICENSE#/%{name}-%{version}-aws-sdk-js-v3-LICENSE
Source40:       https://raw.githubusercontent.com/sigstore/sigstore-js/c1dc7d4778a450787fc72b083f2490ad02b714c6/LICENSE#/%{name}-%{version}-sigstore-verify-LICENSE
Source41:       https://raw.githubusercontent.com/drizzle-team/drizzle-orm/eec7260841c468ab4c2f2dc9d8ebb69105da0c34/LICENSE#/%{name}-%{version}-drizzle-orm-LICENSE
Source42:       https://raw.githubusercontent.com/poe-platform/poe-code/0a8922656d075ddcd43ae9abb6de8aaf28fdf73a/packages/poe-oauth/LICENSE#/%{name}-%{version}-poe-platform-LICENSE
Source43:       https://raw.githubusercontent.com/remeda/remeda/0fde627fc4ca8a19ab93f000fe931f22d4472338/LICENSE#/%{name}-%{version}-remeda-LICENSE
Source44:       https://raw.githubusercontent.com/kemitchell/spdx-exceptions.json/3aa64bec339abc6a3eca00c3436aaa7e154b8799/README.md#/%{name}-%{version}-spdx-exceptions-README.md
Source45:       https://static.crates.io/crates/photon-rs/photon-rs-%{photon_source_version}.crate
Source46:       %{name}-%{version}-photon-cargo-vendor.tar.zst
Source47:       %{name}-%{version}-photon-cargo-vendor.txt
Source48:       https://static.crates.io/crates/wasm-bindgen-cli/wasm-bindgen-cli-%{wasm_bindgen_cli_source_version}.crate
Source49:       %{name}-%{version}-wasm-bindgen-cli-cargo-vendor.tar.zst
Source50:       %{name}-%{version}-wasm-bindgen-cli-cargo-vendor.txt
# Repository-side preflight binds this package's compiler/native evidence to
# Bun's current final-linked-license closure without duplicating it in the SRPM.
Source51:       audit-opencode-final-licenses
Source52:       %{name}-%{version}-final-license-closure.json

# Fedora omits the optional prebuilt FFF accelerator and selects OpenCode's
# existing system-ripgrep fallback instead.
# Upstream status: Fedora-specific; https://github.com/anomalyco/opencode/pull/31566
# added the fallback, and commit e4300e9b7433e068c3d57ac41fcb39bc5de3d32e
# supports disabling FFF.
Patch0:         opencode-disable-fff.patch
# Resolve shared LLVM support libraries to Fedora's multilib paths for the
# private Bun-pinned Zig bootstrap used only to build OpenTUI.
# Fedora-specific; not submitted upstream because it adapts the release-pinned
# fork to Fedora's shared LLVM layout.
Patch1:         opencode-zig-fedora-lib64.patch
# Record Bun's normalized compiler input graph without changing the selected
# application behavior or emitted payload.
# Fedora-specific; not submitted upstream because this opt-in output is package
# audit evidence and upstream issue/PR review found no existing equivalent.
Patch2:         opencode-record-bundle-metafile.patch

ExclusiveArch:  x86_64

BuildRequires:  bun = 1.3.14
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  binutils
BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  clang20
BuildRequires:  clang20-devel
BuildRequires:  clang20-libs
BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  golang
BuildRequires:  file
BuildRequires:  libxml2-devel
BuildRequires:  libzstd-devel
BuildRequires:  lld20
BuildRequires:  lld20-devel
BuildRequires:  lld20-libs
BuildRequires:  libtool
BuildRequires:  llvm20-devel
BuildRequires:  llvm20-libs
BuildRequires:  make
BuildRequires:  ncurses-devel
BuildRequires:  ninja-build
BuildRequires:  nodejs24-devel
BuildRequires:  nodejs24-npm
BuildRequires:  patch
BuildRequires:  pkgconfig
BuildRequires:  python3
BuildRequires:  ruby
BuildRequires:  rust-std-static-wasm32-unknown-unknown
BuildRequires:  coreutils
BuildRequires:  tar
BuildRequires:  tree-sitter-cli >= 0.26.9
BuildRequires:  zlib-ng-compat-devel
BuildRequires:  zstd
Requires:       ripgrep

# The final executable embeds these modules but installs no Node module tree,
# so Fedora's automatic Node generator cannot run. This block is generated
# from Source3 by scripts/generate-node-bundled-provides.
# BEGIN GENERATED BUNDLED NODE PROVIDES
Provides:       bundled(nodejs-@actions/core) = 1.11.1
Provides:       bundled(nodejs-@actions/exec) = 1.1.1
Provides:       bundled(nodejs-@actions/github) = 6.0.1
Provides:       bundled(nodejs-@actions/http-client) = 2.2.3
Provides:       bundled(nodejs-@actions/io) = 1.1.3
Provides:       bundled(nodejs-@agentclientprotocol/sdk) = 0.21.0
Provides:       bundled(nodejs-@ai-sdk/alibaba) = 1.0.17
Provides:       bundled(nodejs-@ai-sdk/amazon-bedrock) = 4.0.112
Provides:       bundled(nodejs-@ai-sdk/anthropic) = 3.0.77
Provides:       bundled(nodejs-@ai-sdk/anthropic) = 3.0.81
Provides:       bundled(nodejs-@ai-sdk/anthropic) = 3.0.82
Provides:       bundled(nodejs-@ai-sdk/azure) = 3.0.88
Provides:       bundled(nodejs-@ai-sdk/cerebras) = 2.0.41
Provides:       bundled(nodejs-@ai-sdk/cohere) = 3.0.27
Provides:       bundled(nodejs-@ai-sdk/deepinfra) = 2.0.41
Provides:       bundled(nodejs-@ai-sdk/deepseek) = 2.0.47
Provides:       bundled(nodejs-@ai-sdk/gateway) = 3.0.104
Provides:       bundled(nodejs-@ai-sdk/google) = 3.0.73
Provides:       bundled(nodejs-@ai-sdk/google-vertex) = 4.0.128
Provides:       bundled(nodejs-@ai-sdk/groq) = 3.0.31
Provides:       bundled(nodejs-@ai-sdk/mistral) = 3.0.51
Provides:       bundled(nodejs-@ai-sdk/openai) = 3.0.48
Provides:       bundled(nodejs-@ai-sdk/openai) = 3.0.67
Provides:       bundled(nodejs-@ai-sdk/openai) = 3.0.84
Provides:       bundled(nodejs-@ai-sdk/openai-compatible) = 2.0.37
Provides:       bundled(nodejs-@ai-sdk/openai-compatible) = 2.0.41
Provides:       bundled(nodejs-@ai-sdk/openai-compatible) = 2.0.53
Provides:       bundled(nodejs-@ai-sdk/perplexity) = 3.0.26
Provides:       bundled(nodejs-@ai-sdk/provider) = 3.0.10
Provides:       bundled(nodejs-@ai-sdk/provider) = 3.0.12
Provides:       bundled(nodejs-@ai-sdk/provider) = 3.0.13
Provides:       bundled(nodejs-@ai-sdk/provider) = 3.0.14
Provides:       bundled(nodejs-@ai-sdk/provider) = 3.0.8
Provides:       bundled(nodejs-@ai-sdk/provider-utils) = 4.0.21
Provides:       bundled(nodejs-@ai-sdk/provider-utils) = 4.0.23
Provides:       bundled(nodejs-@ai-sdk/provider-utils) = 4.0.27
Provides:       bundled(nodejs-@ai-sdk/provider-utils) = 4.0.32
Provides:       bundled(nodejs-@ai-sdk/provider-utils) = 4.0.35
Provides:       bundled(nodejs-@ai-sdk/provider-utils) = 4.0.38
Provides:       bundled(nodejs-@ai-sdk/provider-utils) = 4.0.40
Provides:       bundled(nodejs-@ai-sdk/togetherai) = 2.0.41
Provides:       bundled(nodejs-@ai-sdk/vercel) = 2.0.39
Provides:       bundled(nodejs-@ai-sdk/xai) = 3.0.102
Provides:       bundled(nodejs-@ampproject/remapping) = 2.3.0
Provides:       bundled(nodejs-@anthropic-ai/sdk) = 0.71.2
Provides:       bundled(nodejs-@aws-crypto/crc32) = 5.2.0
Provides:       bundled(nodejs-@aws-crypto/util) = 5.2.0
Provides:       bundled(nodejs-@aws-sdk/core) = 3.974.15
Provides:       bundled(nodejs-@aws-sdk/credential-provider-cognito-identity) = 3.972.38
Provides:       bundled(nodejs-@aws-sdk/credential-provider-env) = 3.972.41
Provides:       bundled(nodejs-@aws-sdk/credential-provider-http) = 3.972.43
Provides:       bundled(nodejs-@aws-sdk/credential-provider-ini) = 3.972.46
Provides:       bundled(nodejs-@aws-sdk/credential-provider-login) = 3.972.45
Provides:       bundled(nodejs-@aws-sdk/credential-provider-node) = 3.972.47
Provides:       bundled(nodejs-@aws-sdk/credential-provider-process) = 3.972.41
Provides:       bundled(nodejs-@aws-sdk/credential-provider-sso) = 3.972.45
Provides:       bundled(nodejs-@aws-sdk/credential-provider-web-identity) = 3.972.45
Provides:       bundled(nodejs-@aws-sdk/credential-providers) = 3.1057.0
Provides:       bundled(nodejs-@aws-sdk/nested-clients) = 3.997.13
Provides:       bundled(nodejs-@aws-sdk/signature-v4-multi-region) = 3.996.30
Provides:       bundled(nodejs-@aws-sdk/token-providers) = 3.1056.0
Provides:       bundled(nodejs-@aws-sdk/xml-builder) = 3.972.26
Provides:       bundled(nodejs-@aws/lambda-invoke-store) = 0.2.4
Provides:       bundled(nodejs-@babel/code-frame) = 7.29.7
Provides:       bundled(nodejs-@babel/compat-data) = 7.29.7
Provides:       bundled(nodejs-@babel/core) = 7.28.0
Provides:       bundled(nodejs-@babel/core) = 7.28.4
Provides:       bundled(nodejs-@babel/generator) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-annotate-as-pure) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-compilation-targets) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-create-class-features-plugin) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-globals) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-member-expression-to-functions) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-module-imports) = 7.18.6
Provides:       bundled(nodejs-@babel/helper-module-imports) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-module-transforms) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-optimise-call-expression) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-plugin-utils) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-replace-supers) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-skip-transparent-expression-wrappers) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-string-parser) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-validator-identifier) = 7.29.7
Provides:       bundled(nodejs-@babel/helper-validator-option) = 7.29.7
Provides:       bundled(nodejs-@babel/helpers) = 7.29.7
Provides:       bundled(nodejs-@babel/parser) = 7.29.7
Provides:       bundled(nodejs-@babel/plugin-syntax-jsx) = 7.29.7
Provides:       bundled(nodejs-@babel/plugin-syntax-typescript) = 7.29.7
Provides:       bundled(nodejs-@babel/plugin-transform-modules-commonjs) = 7.29.7
Provides:       bundled(nodejs-@babel/plugin-transform-typescript) = 7.29.7
Provides:       bundled(nodejs-@babel/preset-typescript) = 7.27.1
Provides:       bundled(nodejs-@babel/template) = 7.29.7
Provides:       bundled(nodejs-@babel/traverse) = 7.29.7
Provides:       bundled(nodejs-@babel/types) = 7.29.7
Provides:       bundled(nodejs-@clack/core) = 1.0.0~alpha.1
Provides:       bundled(nodejs-@clack/prompts) = 1.0.0~alpha.1
Provides:       bundled(nodejs-@effect/opentelemetry) = 4.0.0~beta.83
Provides:       bundled(nodejs-@effect/platform-node) = 4.0.0~beta.83
Provides:       bundled(nodejs-@effect/platform-node-shared) = 4.0.0~beta.83
Provides:       bundled(nodejs-@fastify/ajv-compiler) = 4.0.5
Provides:       bundled(nodejs-@fastify/error) = 4.2.0
Provides:       bundled(nodejs-@fastify/fast-json-stringify-compiler) = 5.0.3
Provides:       bundled(nodejs-@fastify/forwarded) = 3.0.1
Provides:       bundled(nodejs-@fastify/merge-json-schemas) = 0.2.1
Provides:       bundled(nodejs-@fastify/proxy-addr) = 5.1.0
Provides:       bundled(nodejs-@fastify/rate-limit) = 10.3.0
Provides:       bundled(nodejs-@gar/promise-retry) = 1.0.3
Provides:       bundled(nodejs-@isaacs/string-locale-compare) = 1.1.0
Provides:       bundled(nodejs-@jridgewell/gen-mapping) = 0.3.13
Provides:       bundled(nodejs-@jridgewell/remapping) = 2.3.5
Provides:       bundled(nodejs-@jridgewell/resolve-uri) = 3.1.2
Provides:       bundled(nodejs-@jridgewell/sourcemap-codec) = 1.5.5
Provides:       bundled(nodejs-@jridgewell/trace-mapping) = 0.3.31
Provides:       bundled(nodejs-@leichtgewicht/ip-codec) = 2.0.5
Provides:       bundled(nodejs-@lukeed/ms) = 2.0.2
Provides:       bundled(nodejs-@mixmark-io/domino) = 2.2.0
Provides:       bundled(nodejs-@modelcontextprotocol/sdk) = 1.29.0
Provides:       bundled(nodejs-@npmcli/agent) = 4.0.2
Provides:       bundled(nodejs-@npmcli/arborist) = 9.4.0
Provides:       bundled(nodejs-@npmcli/config) = 10.8.1
Provides:       bundled(nodejs-@npmcli/fs) = 5.0.0
Provides:       bundled(nodejs-@npmcli/git) = 7.0.2
Provides:       bundled(nodejs-@npmcli/installed-package-contents) = 4.0.0
Provides:       bundled(nodejs-@npmcli/map-workspaces) = 5.0.3
Provides:       bundled(nodejs-@npmcli/metavuln-calculator) = 9.0.3
Provides:       bundled(nodejs-@npmcli/name-from-folder) = 4.0.0
Provides:       bundled(nodejs-@npmcli/node-gyp) = 5.0.0
Provides:       bundled(nodejs-@npmcli/package-json) = 7.0.5
Provides:       bundled(nodejs-@npmcli/promise-spawn) = 9.0.1
Provides:       bundled(nodejs-@npmcli/query) = 5.0.0
Provides:       bundled(nodejs-@npmcli/redact) = 4.0.0
Provides:       bundled(nodejs-@npmcli/run-script) = 10.0.4
Provides:       bundled(nodejs-@octokit/auth-token) = 4.0.0
Provides:       bundled(nodejs-@octokit/auth-token) = 6.0.0
Provides:       bundled(nodejs-@octokit/core) = 5.2.2
Provides:       bundled(nodejs-@octokit/core) = 7.0.6
Provides:       bundled(nodejs-@octokit/endpoint) = 11.0.3
Provides:       bundled(nodejs-@octokit/endpoint) = 9.0.6
Provides:       bundled(nodejs-@octokit/graphql) = 7.1.1
Provides:       bundled(nodejs-@octokit/graphql) = 9.0.2
Provides:       bundled(nodejs-@octokit/graphql) = 9.0.3
Provides:       bundled(nodejs-@octokit/plugin-paginate-rest) = 13.2.1
Provides:       bundled(nodejs-@octokit/plugin-paginate-rest) = 9.2.2
Provides:       bundled(nodejs-@octokit/plugin-request-log) = 6.0.0
Provides:       bundled(nodejs-@octokit/plugin-rest-endpoint-methods) = 10.4.1
Provides:       bundled(nodejs-@octokit/plugin-rest-endpoint-methods) = 16.1.1
Provides:       bundled(nodejs-@octokit/request) = 10.0.10
Provides:       bundled(nodejs-@octokit/request) = 8.4.1
Provides:       bundled(nodejs-@octokit/request-error) = 5.1.1
Provides:       bundled(nodejs-@octokit/request-error) = 7.1.0
Provides:       bundled(nodejs-@octokit/rest) = 22.0.0
Provides:       bundled(nodejs-@openrouter/ai-sdk-provider) = 2.9.0
Provides:       bundled(nodejs-@opentelemetry/api) = 1.9.0
Provides:       bundled(nodejs-@opentelemetry/api-logs) = 0.214.0
Provides:       bundled(nodejs-@opentelemetry/context-async-hooks) = 2.6.1
Provides:       bundled(nodejs-@opentelemetry/core) = 2.6.1
Provides:       bundled(nodejs-@opentelemetry/exporter-trace-otlp-http) = 0.214.0
Provides:       bundled(nodejs-@opentelemetry/otlp-exporter-base) = 0.214.0
Provides:       bundled(nodejs-@opentelemetry/otlp-transformer) = 0.214.0
Provides:       bundled(nodejs-@opentelemetry/resources) = 2.6.1
Provides:       bundled(nodejs-@opentelemetry/sdk-logs) = 0.214.0
Provides:       bundled(nodejs-@opentelemetry/sdk-metrics) = 2.6.1
Provides:       bundled(nodejs-@opentelemetry/sdk-trace-base) = 2.6.1
Provides:       bundled(nodejs-@opentelemetry/sdk-trace-node) = 2.6.1
Provides:       bundled(nodejs-@opentelemetry/semantic-conventions) = 1.41.1
Provides:       bundled(nodejs-@opentui/core) = 0.4.5
Provides:       bundled(nodejs-@opentui/core-linux-x64) = 0.4.5
Provides:       bundled(nodejs-@opentui/keymap) = 0.4.5
Provides:       bundled(nodejs-@opentui/solid) = 0.4.5
Provides:       bundled(nodejs-@parcel/watcher) = 2.5.1
Provides:       bundled(nodejs-@parcel/watcher-linux-x64-glibc) = 2.5.1
Provides:       bundled(nodejs-@pinojs/redact) = 0.4.0
Provides:       bundled(nodejs-@sigstore/bundle) = 4.0.0
Provides:       bundled(nodejs-@sigstore/core) = 3.2.1
Provides:       bundled(nodejs-@sigstore/protobuf-specs) = 0.5.1
Provides:       bundled(nodejs-@sigstore/sign) = 4.1.1
Provides:       bundled(nodejs-@sigstore/tuf) = 4.0.2
Provides:       bundled(nodejs-@sigstore/verify) = 3.1.1
Provides:       bundled(nodejs-@silvia-odwyer/photon-node) = 0.3.4
Provides:       bundled(nodejs-@smithy/core) = 3.24.5
Provides:       bundled(nodejs-@smithy/credential-provider-imds) = 4.3.6
Provides:       bundled(nodejs-@smithy/eventstream-codec) = 4.2.14
Provides:       bundled(nodejs-@smithy/eventstream-codec) = 4.2.7
Provides:       bundled(nodejs-@smithy/is-array-buffer) = 2.2.0
Provides:       bundled(nodejs-@smithy/node-http-handler) = 4.7.5
Provides:       bundled(nodejs-@smithy/signature-v4) = 5.4.5
Provides:       bundled(nodejs-@smithy/types) = 4.14.2
Provides:       bundled(nodejs-@smithy/util-buffer-from) = 2.2.0
Provides:       bundled(nodejs-@smithy/util-buffer-from) = 4.3.5
Provides:       bundled(nodejs-@smithy/util-hex-encoding) = 4.3.5
Provides:       bundled(nodejs-@smithy/util-utf8) = 2.3.0
Provides:       bundled(nodejs-@smithy/util-utf8) = 4.2.0
Provides:       bundled(nodejs-@smithy/util-utf8) = 4.2.2
Provides:       bundled(nodejs-@tufjs/canonical-json) = 2.0.0
Provides:       bundled(nodejs-@tufjs/models) = 4.1.0
Provides:       bundled(nodejs-@vercel/oidc) = 3.2.0
Provides:       bundled(nodejs-abbrev) = 4.0.0
Provides:       bundled(nodejs-abstract-logging) = 2.0.1
Provides:       bundled(nodejs-acorn) = 8.15.0
Provides:       bundled(nodejs-agent-base) = 7.1.4
Provides:       bundled(nodejs-ai) = 6.0.168
Provides:       bundled(nodejs-ai-gateway-provider) = 3.1.2
Provides:       bundled(nodejs-ajv) = 8.20.0
Provides:       bundled(nodejs-ajv-formats) = 3.0.1
Provides:       bundled(nodejs-ansi-regex) = 6.2.2
Provides:       bundled(nodejs-ansi-styles) = 6.2.3
Provides:       bundled(nodejs-atomic-sleep) = 1.0.0
Provides:       bundled(nodejs-avvio) = 9.2.0
Provides:       bundled(nodejs-aws4fetch) = 1.0.20
Provides:       bundled(nodejs-babel-plugin-jsx-dom-expressions) = 0.40.7
Provides:       bundled(nodejs-babel-plugin-module-resolver) = 5.0.2
Provides:       bundled(nodejs-babel-preset-solid) = 1.9.12
Provides:       bundled(nodejs-balanced-match) = 1.0.2
Provides:       bundled(nodejs-balanced-match) = 4.0.4
Provides:       bundled(nodejs-base64-js) = 1.5.1
Provides:       bundled(nodejs-baseline-browser-mapping) = 2.10.33
Provides:       bundled(nodejs-before-after-hook) = 2.2.3
Provides:       bundled(nodejs-before-after-hook) = 4.0.0
Provides:       bundled(nodejs-bignumber.js) = 9.3.1
Provides:       bundled(nodejs-bin-links) = 6.0.2
Provides:       bundled(nodejs-bonjour-service) = 1.3.0
Provides:       bundled(nodejs-bowser) = 2.14.1
Provides:       bundled(nodejs-brace-expansion) = 2.1.1
Provides:       bundled(nodejs-brace-expansion) = 5.0.6
Provides:       bundled(nodejs-braces) = 3.0.3
Provides:       bundled(nodejs-browserslist) = 4.28.2
Provides:       bundled(nodejs-buffer-equal-constant-time) = 1.0.1
Provides:       bundled(nodejs-bun-pty) = 0.4.8
Provides:       bundled(nodejs-bundle-name) = 4.1.0
Provides:       bundled(nodejs-cacache) = 20.0.4
Provides:       bundled(nodejs-caniuse-lite) = 1.0.30001793
Provides:       bundled(nodejs-ci-info) = 4.4.0
Provides:       bundled(nodejs-cli-spinners) = 3.4.0
Provides:       bundled(nodejs-clipboardy) = 4.0.0
Provides:       bundled(nodejs-cliui) = 9.0.1
Provides:       bundled(nodejs-cmd-shim) = 8.0.0
Provides:       bundled(nodejs-common-ancestor-path) = 2.0.0
Provides:       bundled(nodejs-content-type) = 2.0.0
Provides:       bundled(nodejs-convert-source-map) = 2.0.0
Provides:       bundled(nodejs-cookie) = 1.1.1
Provides:       bundled(nodejs-cross-spawn) = 7.0.6
Provides:       bundled(nodejs-cssesc) = 3.0.0
Provides:       bundled(nodejs-debug) = 4.4.3
Provides:       bundled(nodejs-decimal.js) = 10.5.0
Provides:       bundled(nodejs-default-browser) = 5.5.0
Provides:       bundled(nodejs-default-browser-id) = 5.0.1
Provides:       bundled(nodejs-define-lazy-prop) = 3.0.0
Provides:       bundled(nodejs-deprecation) = 2.3.1
Provides:       bundled(nodejs-dequal) = 2.0.3
Provides:       bundled(nodejs-diff) = 8.0.2
Provides:       bundled(nodejs-dns-packet) = 5.6.1
Provides:       bundled(nodejs-drizzle-orm) = 1.0.0~rc.2
Provides:       bundled(nodejs-ecdsa-sig-formatter) = 1.0.11
Provides:       bundled(nodejs-effect) = 4.0.0~beta.83
Provides:       bundled(nodejs-electron-to-chromium) = 1.5.364
Provides:       bundled(nodejs-emoji-regex) = 10.6.0
Provides:       bundled(nodejs-entities) = 4.5.0
Provides:       bundled(nodejs-entities) = 6.0.1
Provides:       bundled(nodejs-entities) = 7.0.1
Provides:       bundled(nodejs-es-errors) = 1.3.0
Provides:       bundled(nodejs-escalade) = 3.2.0
Provides:       bundled(nodejs-eventsource) = 3.0.7
Provides:       bundled(nodejs-eventsource-parser) = 3.1.0
Provides:       bundled(nodejs-execa) = 8.0.1
Provides:       bundled(nodejs-extend) = 3.0.2
Provides:       bundled(nodejs-extend-shallow) = 2.0.1
Provides:       bundled(nodejs-fast-check) = 4.8.0
Provides:       bundled(nodejs-fast-decode-uri-component) = 1.0.1
Provides:       bundled(nodejs-fast-deep-equal) = 3.1.3
Provides:       bundled(nodejs-fast-json-stringify) = 6.4.0
Provides:       bundled(nodejs-fast-querystring) = 1.1.2
Provides:       bundled(nodejs-fast-uri) = 3.1.2
Provides:       bundled(nodejs-fast-xml-parser) = 5.7.3
Provides:       bundled(nodejs-fastify) = 5.8.5
Provides:       bundled(nodejs-fastify-plugin) = 5.1.0
Provides:       bundled(nodejs-fastq) = 1.20.1
Provides:       bundled(nodejs-fill-range) = 7.1.1
Provides:       bundled(nodejs-find-babel-config) = 2.1.2
Provides:       bundled(nodejs-find-my-way) = 9.6.0
Provides:       bundled(nodejs-find-my-way-ts) = 0.1.6
Provides:       bundled(nodejs-find-up) = 3.0.0
Provides:       bundled(nodejs-fs-minipass) = 3.0.3
Provides:       bundled(nodejs-function-bind) = 1.1.2
Provides:       bundled(nodejs-fuzzysort) = 3.1.0
Provides:       bundled(nodejs-gaxios) = 7.1.4
Provides:       bundled(nodejs-gcp-metadata) = 8.1.2
Provides:       bundled(nodejs-gensync) = 1.0.0~beta.2
Provides:       bundled(nodejs-get-caller-file) = 2.0.5
Provides:       bundled(nodejs-get-east-asian-width) = 1.6.0
Provides:       bundled(nodejs-get-stream) = 8.0.1
Provides:       bundled(nodejs-gitlab-ai-provider) = 6.11.1
Provides:       bundled(nodejs-glob) = 13.0.5
Provides:       bundled(nodejs-glob) = 9.3.5
Provides:       bundled(nodejs-google-auth-library) = 10.5.0
Provides:       bundled(nodejs-google-logging-utils) = 1.1.3
Provides:       bundled(nodejs-gray-matter) = 4.0.3
Provides:       bundled(nodejs-gtoken) = 8.0.0
Provides:       bundled(nodejs-hasown) = 2.0.4
Provides:       bundled(nodejs-hosted-git-info) = 9.0.3
Provides:       bundled(nodejs-html-entities) = 2.3.3
Provides:       bundled(nodejs-htmlparser2) = 8.0.2
Provides:       bundled(nodejs-http-cache-semantics) = 4.2.0
Provides:       bundled(nodejs-http-proxy-agent) = 7.0.2
Provides:       bundled(nodejs-https-proxy-agent) = 7.0.6
Provides:       bundled(nodejs-human-signals) = 5.0.0
Provides:       bundled(nodejs-iconv-lite) = 0.7.2
Provides:       bundled(nodejs-ignore) = 7.0.5
Provides:       bundled(nodejs-ignore-walk) = 8.0.0
Provides:       bundled(nodejs-immer) = 11.1.4
Provides:       bundled(nodejs-ini) = 6.0.0
Provides:       bundled(nodejs-ip-address) = 10.2.0
Provides:       bundled(nodejs-ipaddr.js) = 2.4.0
Provides:       bundled(nodejs-is-core-module) = 2.16.2
Provides:       bundled(nodejs-is-docker) = 3.0.0
Provides:       bundled(nodejs-is-extendable) = 0.1.1
Provides:       bundled(nodejs-is-extglob) = 2.1.1
Provides:       bundled(nodejs-is-glob) = 4.0.3
Provides:       bundled(nodejs-is-inside-container) = 1.0.0
Provides:       bundled(nodejs-is-number) = 7.0.0
Provides:       bundled(nodejs-is-stream) = 3.0.0
Provides:       bundled(nodejs-is-wsl) = 3.1.1
Provides:       bundled(nodejs-is64bit) = 2.0.0
Provides:       bundled(nodejs-isexe) = 2.0.0
Provides:       bundled(nodejs-isexe) = 4.0.0
Provides:       bundled(nodejs-js-tokens) = 4.0.0
Provides:       bundled(nodejs-js-yaml) = 3.14.2
Provides:       bundled(nodejs-jsesc) = 3.1.0
Provides:       bundled(nodejs-json-bigint) = 1.0.0
Provides:       bundled(nodejs-json-parse-even-better-errors) = 5.0.0
Provides:       bundled(nodejs-json-schema-ref-resolver) = 3.0.0
Provides:       bundled(nodejs-json-schema-traverse) = 1.0.0
Provides:       bundled(nodejs-json-stringify-nice) = 1.1.4
Provides:       bundled(nodejs-json-with-bigint) = 3.5.8
Provides:       bundled(nodejs-json5) = 2.2.3
Provides:       bundled(nodejs-jsonc-parser) = 3.3.1
Provides:       bundled(nodejs-jsonparse) = 1.3.1
Provides:       bundled(nodejs-just-diff) = 6.0.2
Provides:       bundled(nodejs-just-diff-apply) = 5.5.0
Provides:       bundled(nodejs-jwa) = 2.0.1
Provides:       bundled(nodejs-jws) = 4.0.1
Provides:       bundled(nodejs-kind-of) = 6.0.3
Provides:       bundled(nodejs-light-my-request) = 6.6.0
Provides:       bundled(nodejs-locate-path) = 3.0.0
Provides:       bundled(nodejs-lru-cache) = 10.4.3
Provides:       bundled(nodejs-lru-cache) = 11.5.1
Provides:       bundled(nodejs-lru-cache) = 5.1.1
Provides:       bundled(nodejs-make-fetch-happen) = 15.0.6
Provides:       bundled(nodejs-merge-stream) = 2.0.0
Provides:       bundled(nodejs-micromatch) = 4.0.8
Provides:       bundled(nodejs-mime) = 4.1.0
Provides:       bundled(nodejs-mime-db) = 1.54.0
Provides:       bundled(nodejs-mime-types) = 3.0.2
Provides:       bundled(nodejs-mimic-fn) = 4.0.0
Provides:       bundled(nodejs-minimatch) = 10.2.5
Provides:       bundled(nodejs-minimatch) = 8.0.7
Provides:       bundled(nodejs-minipass) = 3.3.6
Provides:       bundled(nodejs-minipass) = 4.2.8
Provides:       bundled(nodejs-minipass) = 7.1.3
Provides:       bundled(nodejs-minipass-collect) = 2.0.1
Provides:       bundled(nodejs-minipass-fetch) = 5.0.2
Provides:       bundled(nodejs-minipass-flush) = 1.0.7
Provides:       bundled(nodejs-minipass-pipeline) = 1.2.4
Provides:       bundled(nodejs-minipass-sized) = 2.0.0
Provides:       bundled(nodejs-minizlib) = 3.1.0
Provides:       bundled(nodejs-ms) = 2.1.3
Provides:       bundled(nodejs-multicast-dns) = 7.2.5
Provides:       bundled(nodejs-multipasta) = 0.2.7
Provides:       bundled(nodejs-negotiator) = 1.0.0
Provides:       bundled(nodejs-node-releases) = 2.0.46
Provides:       bundled(nodejs-nopt) = 9.0.0
Provides:       bundled(nodejs-npm-bundled) = 5.0.0
Provides:       bundled(nodejs-npm-install-checks) = 8.0.0
Provides:       bundled(nodejs-npm-normalize-package-bin) = 5.0.0
Provides:       bundled(nodejs-npm-package-arg) = 13.0.2
Provides:       bundled(nodejs-npm-packlist) = 10.0.4
Provides:       bundled(nodejs-npm-pick-manifest) = 11.0.3
Provides:       bundled(nodejs-npm-registry-fetch) = 19.1.1
Provides:       bundled(nodejs-npm-run-path) = 5.3.0
Provides:       bundled(nodejs-on-exit-leak-free) = 2.1.2
Provides:       bundled(nodejs-once) = 1.4.0
Provides:       bundled(nodejs-onetime) = 6.0.0
Provides:       bundled(nodejs-open) = 10.1.2
Provides:       bundled(nodejs-open) = 10.2.0
Provides:       bundled(nodejs-openai) = 6.39.1
Provides:       bundled(nodejs-opencode-gitlab-auth) = 2.1.0
Provides:       bundled(nodejs-opencode-poe-auth) = 0.0.1
Provides:       bundled(nodejs-opentui-spinner) = 0.0.7
Provides:       bundled(nodejs-p-limit) = 2.3.0
Provides:       bundled(nodejs-p-locate) = 3.0.0
Provides:       bundled(nodejs-p-map) = 7.0.4
Provides:       bundled(nodejs-p-try) = 2.2.0
Provides:       bundled(nodejs-pacote) = 21.5.0
Provides:       bundled(nodejs-parse-conflict-json) = 5.0.1
Provides:       bundled(nodejs-parse5) = 7.3.0
Provides:       bundled(nodejs-path-exists) = 3.0.0
Provides:       bundled(nodejs-path-key) = 3.1.1
Provides:       bundled(nodejs-path-key) = 4.0.0
Provides:       bundled(nodejs-path-parse) = 1.0.7
Provides:       bundled(nodejs-path-scurry) = 1.11.1
Provides:       bundled(nodejs-picocolors) = 1.1.1
Provides:       bundled(nodejs-picomatch) = 2.3.2
Provides:       bundled(nodejs-pino) = 10.3.1
Provides:       bundled(nodejs-pino-std-serializers) = 7.1.0
Provides:       bundled(nodejs-pkce-challenge) = 5.0.1
Provides:       bundled(nodejs-pkg-up) = 3.1.0
Provides:       bundled(nodejs-poe-oauth) = 0.0.8
Provides:       bundled(nodejs-postcss-selector-parser) = 7.1.1
Provides:       bundled(nodejs-prettier) = 3.6.2
Provides:       bundled(nodejs-proc-log) = 6.1.0
Provides:       bundled(nodejs-process-warning) = 4.0.1
Provides:       bundled(nodejs-process-warning) = 5.0.0
Provides:       bundled(nodejs-proggy) = 4.0.0
Provides:       bundled(nodejs-promise-all-reject-late) = 1.0.1
Provides:       bundled(nodejs-promise-call-limit) = 3.0.2
Provides:       bundled(nodejs-pure-rand) = 8.4.0
Provides:       bundled(nodejs-quick-format-unescaped) = 4.0.4
Provides:       bundled(nodejs-react) = 18.2.0
Provides:       bundled(nodejs-read-cmd-shim) = 6.0.0
Provides:       bundled(nodejs-remeda) = 2.26.0
Provides:       bundled(nodejs-reselect) = 4.1.8
Provides:       bundled(nodejs-resolve) = 1.22.12
Provides:       bundled(nodejs-ret) = 0.5.0
Provides:       bundled(nodejs-reusify) = 1.1.0
Provides:       bundled(nodejs-rfdc) = 1.4.1
Provides:       bundled(nodejs-run-applescript) = 7.1.0
Provides:       bundled(nodejs-safe-buffer) = 5.2.1
Provides:       bundled(nodejs-safe-regex2) = 5.1.1
Provides:       bundled(nodejs-safe-stable-stringify) = 2.5.0
Provides:       bundled(nodejs-safer-buffer) = 2.1.2
Provides:       bundled(nodejs-section-matter) = 1.0.0
Provides:       bundled(nodejs-secure-json-parse) = 4.1.0
Provides:       bundled(nodejs-semver) = 6.3.1
Provides:       bundled(nodejs-semver) = 7.8.1
Provides:       bundled(nodejs-seroval) = 1.3.2
Provides:       bundled(nodejs-seroval-plugins) = 1.3.3
Provides:       bundled(nodejs-set-cookie-parser) = 2.7.2
Provides:       bundled(nodejs-shebang-command) = 2.0.0
Provides:       bundled(nodejs-shebang-regex) = 3.0.0
Provides:       bundled(nodejs-signal-exit) = 4.1.0
Provides:       bundled(nodejs-sigstore) = 4.1.1
Provides:       bundled(nodejs-sisteransi) = 1.0.5
Provides:       bundled(nodejs-smart-buffer) = 4.2.0
Provides:       bundled(nodejs-socks) = 2.8.9
Provides:       bundled(nodejs-socks-proxy-agent) = 8.0.5
Provides:       bundled(nodejs-solid-js) = 1.9.10
Provides:       bundled(nodejs-sonic-boom) = 4.2.1
Provides:       bundled(nodejs-spdx-exceptions) = 2.5.0
Provides:       bundled(nodejs-spdx-expression-parse) = 4.0.0
Provides:       bundled(nodejs-spdx-license-ids) = 3.0.23
Provides:       bundled(nodejs-ssri) = 13.0.1
Provides:       bundled(nodejs-string-width) = 7.2.0
Provides:       bundled(nodejs-strip-ansi) = 7.1.2
Provides:       bundled(nodejs-strip-bom-string) = 1.0.0
Provides:       bundled(nodejs-strip-final-newline) = 3.0.0
Provides:       bundled(nodejs-system-architecture) = 0.1.0
Provides:       bundled(nodejs-tar) = 7.5.15
Provides:       bundled(nodejs-thread-stream) = 4.2.0
Provides:       bundled(nodejs-thunky) = 1.1.0
Provides:       bundled(nodejs-to-regex-range) = 5.0.1
Provides:       bundled(nodejs-toad-cache) = 3.7.1
Provides:       bundled(nodejs-tree-sitter-bash) = 0.25.0
Provides:       bundled(nodejs-tree-sitter-powershell) = 0.25.10
Provides:       bundled(nodejs-treeverse) = 3.0.0
Provides:       bundled(nodejs-tslib) = 2.8.1
Provides:       bundled(nodejs-tuf-js) = 4.1.0
Provides:       bundled(nodejs-tunnel) = 0.0.6
Provides:       bundled(nodejs-turndown) = 7.2.0
Provides:       bundled(nodejs-typescript) = 5.8.2
Provides:       bundled(nodejs-ulid) = 3.0.1
Provides:       bundled(nodejs-universal-user-agent) = 6.0.1
Provides:       bundled(nodejs-universal-user-agent) = 7.0.3
Provides:       bundled(nodejs-util-deprecate) = 1.0.2
Provides:       bundled(nodejs-validate-npm-package-name) = 7.0.2
Provides:       bundled(nodejs-venice-ai-sdk-provider) = 2.1.1
Provides:       bundled(nodejs-vscode-jsonrpc) = 8.2.1
Provides:       bundled(nodejs-walk-up-path) = 4.0.0
Provides:       bundled(nodejs-web-tree-sitter) = 0.25.10
Provides:       bundled(nodejs-which) = 2.0.2
Provides:       bundled(nodejs-which) = 6.0.1
Provides:       bundled(nodejs-wrap-ansi) = 9.0.2
Provides:       bundled(nodejs-wrappy) = 1.0.2
Provides:       bundled(nodejs-write-file-atomic) = 7.0.1
Provides:       bundled(nodejs-wsl-utils) = 0.1.0
Provides:       bundled(nodejs-xdg-basedir) = 5.1.0
Provides:       bundled(nodejs-y18n) = 5.0.8
Provides:       bundled(nodejs-yallist) = 3.1.1
Provides:       bundled(nodejs-yargs) = 18.0.0
Provides:       bundled(nodejs-yargs-parser) = 22.0.0
Provides:       bundled(nodejs-zod) = 3.25.76
Provides:       bundled(nodejs-zod) = 4.1.8
Provides:       bundled(nodejs-zod) = 4.4.3
Provides:       bundled(nodejs-zod-to-json-schema) = 3.25.2
# END GENERATED BUNDLED NODE PROVIDES

%description
OpenCode is an open-source coding agent with a terminal user interface, local
server, and provider support.

This draft is intentionally excluded from COPR until every source-build and
license gate recorded in the package metadata is complete.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{opentui_source_sha256}  %{SOURCE9}" | sha256sum -c -
echo "%{uucode_source_sha256}  %{SOURCE10}" | sha256sum -c -
echo "%{yoga_source_sha256}  %{SOURCE11}" | sha256sum -c -
echo "%{zig_source_sha256}  %{SOURCE12}" | sha256sum -c -
echo "%{tree_sitter_source_sha256}  %{SOURCE13}" | sha256sum -c -
echo "%{emscripten_source_sha256}  %{SOURCE14}" | sha256sum -c -
echo "%{binaryen_source_sha256}  %{SOURCE15}" | sha256sum -c -
echo "%{esbuild_source_sha256}  %{SOURCE16}" | sha256sum -c -
echo "%{x_sys_source_sha256}  %{SOURCE17}" | sha256sum -c -
echo "%{acorn_source_sha256}  %{SOURCE18}" | sha256sum -c -
echo "%{esbuild_npm_source_sha256}  %{SOURCE19}" | sha256sum -c -
echo "%{tree_sitter_runtime_helper_sha256}  %{SOURCE20}" | sha256sum -c -
echo "%{tree_sitter_validator_sha256}  %{SOURCE21}" | sha256sum -c -
echo "%{opentui_javascript_source_sha256}  %{SOURCE22}" | sha256sum -c -
echo "%{opentui_typescript_source_sha256}  %{SOURCE23}" | sha256sum -c -
echo "%{opentui_markdown_source_sha256}  %{SOURCE24}" | sha256sum -c -
echo "%{opentui_zig_grammar_source_sha256}  %{SOURCE25}" | sha256sum -c -
echo "%{shiki_vscode_oniguruma_source_sha256}  %{SOURCE26}" | sha256sum -c -
echo "%{shiki_oniguruma_source_sha256}  %{SOURCE27}" | sha256sum -c -
echo "%{undici_llhttp_source_sha256}  %{SOURCE28}" | sha256sum -c -
echo "%{models_dev_source_sha256}  %{SOURCE29}" | sha256sum -c -
echo "%{models_dev_zod_sha256}  %{SOURCE30}" | sha256sum -c -
echo "%{models_dev_proof_sha256}  %{SOURCE31}" | sha256sum -c -
echo "%{source_license_set_proof_sha256}  %{SOURCE32}" | sha256sum -c -
echo "%{source_materialization_sha256}  %{SOURCE33}" | sha256sum -c -
echo "%{source_audit_sha256}  %{SOURCE34}" | sha256sum -c -
echo "%{node_modules_materializer_sha256}  %{SOURCE35}" | sha256sum -c -
echo "%{binary_embedding_auditor_sha256}  %{SOURCE36}" | sha256sum -c -
echo "%{binary_embedding_receipt_sha256}  %{SOURCE37}" | sha256sum -c -
echo "%{license_review_sha256}  %{SOURCE38}" | sha256sum -c -
echo "%{aws_sdk_license_sha256}  %{SOURCE39}" | sha256sum -c -
echo "%{sigstore_verify_license_sha256}  %{SOURCE40}" | sha256sum -c -
echo "%{drizzle_orm_license_sha256}  %{SOURCE41}" | sha256sum -c -
echo "%{poe_platform_license_sha256}  %{SOURCE42}" | sha256sum -c -
echo "%{remeda_license_sha256}  %{SOURCE43}" | sha256sum -c -
echo "%{spdx_exceptions_readme_sha256}  %{SOURCE44}" | sha256sum -c -
echo "%{photon_source_sha256}  %{SOURCE45}" | sha256sum -c -
echo "%{photon_vendor_sha256}  %{SOURCE46}" | sha256sum -c -
echo "%{photon_vendor_manifest_sha256}  %{SOURCE47}" | sha256sum -c -
echo "%{wasm_bindgen_cli_source_sha256}  %{SOURCE48}" | sha256sum -c -
echo "%{wasm_bindgen_cli_vendor_sha256}  %{SOURCE49}" | sha256sum -c -
echo "%{wasm_bindgen_cli_vendor_manifest_sha256}  %{SOURCE50}" | sha256sum -c -
echo "%{final_license_auditor_sha256}  %{SOURCE51}" | sha256sum -c -
echo "%{final_license_receipt_sha256}  %{SOURCE52}" | sha256sum -c -
echo "%{bundle_metafile_patch_sha256}  %{PATCH2}" | sha256sum -c -
%autosetup -n opencode-%{version} -N
patch -p1 < %{PATCH0}
patch -p1 < %{PATCH2}

test -f %{SOURCE1}
test -f %{SOURCE3}
test -f %{SOURCE4}
test -f %{SOURCE5}
test -f %{SOURCE6}
test -f %{SOURCE7}
test -f %{SOURCE8}
test -f %{SOURCE9}
test -f %{SOURCE10}
test -f %{SOURCE11}
test -f %{SOURCE12}
test -f %{SOURCE13}
test -f %{SOURCE14}
test -f %{SOURCE15}
test -f %{SOURCE16}
test -f %{SOURCE17}
test -f %{SOURCE18}
test -f %{SOURCE19}
test -f %{SOURCE20}
test -f %{SOURCE21}
test -f %{SOURCE36}
test -f %{SOURCE37}
test -f %{SOURCE38}
test -f %{SOURCE39}
test -f %{SOURCE40}
test -f %{SOURCE41}
test -f %{SOURCE42}
test -f %{SOURCE43}
test -f %{SOURCE44}
test -f %{SOURCE45}
test -f %{SOURCE46}
test -f %{SOURCE47}
test -f %{SOURCE48}
test -f %{SOURCE49}
test -f %{SOURCE50}
test -f %{SOURCE51}
test -f %{SOURCE52}
echo "%{bun_pty_source_sha256}  %{SOURCE6}" | sha256sum -c -
echo "%{bun_pty_vendor_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{bun_pty_vendor_manifest_sha256}  %{SOURCE8}" | sha256sum -c -
python3 -m json.tool %{SOURCE3} >/dev/null
python3 -m json.tool %{SOURCE5} >/dev/null
cp -p %{SOURCE4} .
cp -p %{SOURCE37} .
cp -p %{SOURCE39} %{SOURCE40} %{SOURCE41} %{SOURCE42} %{SOURCE43} %{SOURCE44} .
tar --extract --zstd --file %{SOURCE1}
mkdir -p .build-tools
ruby %{SOURCE35} \
  --source-audit %{SOURCE34} \
  --closure %{SOURCE3} \
  --bundle-root "$PWD/opencode-%{version}-nm-prod-build/npm" \
  --source-root "$PWD" \
  --receipt "$PWD/.build-tools/node-modules-materialization.json"

# Materialize only corresponding source and the two minimal registry build
# inputs. No package-manager resolution or dependency lifecycle script runs.
mkdir -p \
  .build-tools/tree-sitter \
  .build-tools/emscripten \
  .build-tools/binaryen \
  .build-tools/esbuild \
  .build-tools/x-sys \
  .build-tools/emscripten/node_modules/acorn \
  .build-tools/tree-sitter/lib/binding_web/node_modules/esbuild
tar --extract --gzip --file %{SOURCE13} --strip-components=1 --directory .build-tools/tree-sitter
tar --extract --gzip --file %{SOURCE14} --strip-components=1 --directory .build-tools/emscripten
tar --extract --gzip --file %{SOURCE15} --strip-components=1 --directory .build-tools/binaryen
tar --extract --gzip --file %{SOURCE16} --strip-components=1 --directory .build-tools/esbuild
python3 -m zipfile -e %{SOURCE17} .build-tools/x-sys
tar --extract --gzip --file %{SOURCE18} --strip-components=1 --directory .build-tools/emscripten/node_modules/acorn
tar --extract --gzip --file %{SOURCE19} --strip-components=1 --directory .build-tools/tree-sitter/lib/binding_web/node_modules/esbuild
mkdir -p .build-tools/esbuild/vendor/golang.org/x
cp -a \
  .build-tools/x-sys/golang.org/x/sys@%{x_sys_version} \
  .build-tools/esbuild/vendor/golang.org/x/sys
cat > .build-tools/esbuild/vendor/modules.txt <<'EOF'
# golang.org/x/sys v0.0.0-20220715151400-c0bba94af5f8
golang.org/x/sys/internal/unsafeheader
golang.org/x/sys/unix
EOF

pushd packages/opencode >/dev/null
bash_parser="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("tree-sitter-bash/package.json")))')"
powershell_parser="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("tree-sitter-powershell/package.json")))')"
web_tree_sitter="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(fileURLToPath(import.meta.resolve("web-tree-sitter"))))')"
popd >/dev/null
printf '%s\n' "$web_tree_sitter" > .build-tools/web-tree-sitter-root
echo "%{bash_published_wasm_sha256}  $bash_parser/tree-sitter-bash.wasm" | sha256sum -c -
echo "%{powershell_published_wasm_sha256}  $powershell_parser/tree-sitter-powershell.wasm" | sha256sum -c -
echo "%{web_tree_sitter_published_wasm_sha256}  $web_tree_sitter/tree-sitter.wasm" | sha256sum -c -
echo "%{web_tree_sitter_published_aux_wasm_sha256}  $web_tree_sitter/lib/tree-sitter.wasm" | sha256sum -c -
echo "%{web_tree_sitter_published_aux_wasm_sha256}  $web_tree_sitter/debug/tree-sitter.wasm" | sha256sum -c -
test "$(find "$bash_parser/prebuilds" -type f -name '*.node' | wc -l)" -eq 6
rm -rf "$bash_parser/prebuilds"
rm -f "$bash_parser/tree-sitter-bash.wasm" "$powershell_parser/tree-sitter-powershell.wasm"
rm -f \
  "$web_tree_sitter/tree-sitter.js" \
  "$web_tree_sitter/tree-sitter.js.map" \
  "$web_tree_sitter/tree-sitter.cjs" \
  "$web_tree_sitter/tree-sitter.cjs.map" \
  "$web_tree_sitter/tree-sitter.wasm" \
  "$web_tree_sitter/tree-sitter.wasm.map" \
  "$web_tree_sitter/lib/tree-sitter.cjs" \
  "$web_tree_sitter/lib/tree-sitter.wasm" \
  "$web_tree_sitter/lib/tree-sitter.wasm.map"
rm -rf "$web_tree_sitter/debug"

# Materialize the exact OpenTUI source and its two Zig package dependencies.
# The package cache is complete before the build phase, so Zig cannot resolve them from
# the network in the disabled-network buildroot.
mkdir -p .opentui-source .opentui-uucode .opentui-yoga
tar --extract --gzip --file %{SOURCE9} --strip-components=1 --directory .opentui-source
tar --extract --gzip --file %{SOURCE10} --strip-components=1 --directory .opentui-uucode
tar --extract --gzip --file %{SOURCE11} --strip-components=1 --directory .opentui-yoga
for grammar in javascript typescript markdown zig; do mkdir -p ".opentui-grammar-$grammar"; done
mkdir -p .shiki-vscode-oniguruma/deps/oniguruma
mkdir -p .undici-llhttp
mkdir -p .models-dev/node_modules/zod
tar --extract --gzip --file %{SOURCE22} --strip-components=1 --directory .opentui-grammar-javascript
tar --extract --gzip --file %{SOURCE23} --strip-components=1 --directory .opentui-grammar-typescript
tar --extract --gzip --file %{SOURCE24} --strip-components=1 --directory .opentui-grammar-markdown
tar --extract --gzip --file %{SOURCE25} --strip-components=1 --directory .opentui-grammar-zig
tar --extract --gzip --file %{SOURCE26} --strip-components=1 --directory .shiki-vscode-oniguruma
tar --extract --gzip --file %{SOURCE27} --strip-components=1 --directory .shiki-vscode-oniguruma/deps/oniguruma
tar --extract --gzip --file %{SOURCE28} --strip-components=1 --directory .undici-llhttp
tar --extract --gzip --file %{SOURCE29} --strip-components=1 --directory .models-dev
tar --extract --gzip --file %{SOURCE30} --strip-components=1 --directory .models-dev/node_modules/zod
mkdir -p .photon-source .wasm-bindgen-cli-source
tar --extract --file %{SOURCE45} --strip-components=1 --directory .photon-source
tar --extract --zstd --file %{SOURCE46} --directory .photon-source
tar --extract --file %{SOURCE48} --strip-components=1 --directory .wasm-bindgen-cli-source
tar --extract --zstd --file %{SOURCE49} --directory .wasm-bindgen-cli-source
echo "%{photon_cargo_lock_sha256}  .photon-source/Cargo.lock" | sha256sum -c -
echo "%{wasm_bindgen_cli_cargo_lock_sha256}  .wasm-bindgen-cli-source/Cargo.lock" | sha256sum -c -
pushd .photon-source >/dev/null
%cargo_prep -v cargo-vendor
%cargo_vendor_manifest
cmp cargo-vendor.txt %{SOURCE47}
popd >/dev/null
pushd .wasm-bindgen-cli-source >/dev/null
%cargo_prep -v cargo-vendor
%cargo_vendor_manifest
cmp cargo-vendor.txt %{SOURCE50}
popd >/dev/null
test ! -e .opentui-source/packages/core/src/zig/lib/x86_64-linux/libopentui.so

mkdir -p \
  .opentui-zig-global-cache/p/%{uucode_zig_hash} \
  .opentui-zig-global-cache/p/%{yoga_zig_hash}
cp -a \
  .opentui-uucode/LICENSE.md \
  .opentui-uucode/README.md \
  .opentui-uucode/build.zig \
  .opentui-uucode/build.zig.zon \
  .opentui-uucode/src \
  .opentui-uucode/ucd \
  .opentui-zig-global-cache/p/%{uucode_zig_hash}/
cp -a .opentui-yoga/. .opentui-zig-global-cache/p/%{yoga_zig_hash}/

# Bootstrap the exact Zig 0.15.2 fork pinned by Bun. Fedora's current Zig is a
# newer incompatible language release, and this private build is not installed.
mkdir -p .build-tools/zig
tar --extract --gzip --file %{SOURCE12} --strip-components=1 --directory .build-tools/zig
patch -d .build-tools/zig -p1 < %{PATCH1}

# Remove the npm platform library before any application build can embed it.
pushd packages/opencode >/dev/null
opentui_platform="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(fileURLToPath(import.meta.resolve("@opentui/core-linux-x64"))))')"
popd >/dev/null
echo "%{opentui_published_sha256}  $opentui_platform/libopentui.so" | sha256sum -c -
rm -f "$opentui_platform/libopentui.so"
pushd packages/opencode >/dev/null
photon_root="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("@silvia-odwyer/photon-node/package.json")))')"
popd >/dev/null
echo "%{photon_published_wasm_sha256}  $photon_root/photon_rs_bg.wasm" | sha256sum -c -
printf '%s\n' "$photon_root" > .build-tools/photon-root
rm -f "$photon_root/photon_rs_bg.wasm"
pushd packages/opencode >/dev/null
shiki_root="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(dirname(fileURLToPath(import.meta.resolve("shiki")))))')"
popd >/dev/null
echo "%{shiki_published_wasm_sha256}  $shiki_root/dist/onig.wasm" | sha256sum -c -
rm -f "$shiki_root/dist/onig.wasm"
find node_modules -path '*/undici/package.json' -print0 | while IFS= read -r -d '' manifest; do
  test "$(node-24 -p 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).version' "$manifest")" = "5.29.0" || continue
  root="$(dirname "$manifest")"
  echo "%{undici_published_wasm_sha256}  $root/lib/llhttp/llhttp.wasm" | sha256sum -c -
  echo "%{undici_published_simd_wasm_sha256}  $root/lib/llhttp/llhttp_simd.wasm" | sha256sum -c -
  printf '%s\n' "$root" >> .build-tools/undici-5.29-roots
  rm -f "$root/lib/llhttp/llhttp.wasm" "$root/lib/llhttp/llhttp_simd.wasm" "$root/lib/llhttp/llhttp-wasm.js" "$root/lib/llhttp/llhttp_simd-wasm.js"
done
test "$(wc -l < .build-tools/undici-5.29-roots)" -eq 2

# The npm package carries the released JS wrapper but only prebuilt Rust
# libraries. Replace that directory with the exact Git source and vendor input.
pushd packages/opencode >/dev/null
bun_pty="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("bun-pty/package.json")))')"
popd >/dev/null
rm -rf "$bun_pty/rust-pty"
mkdir -p .bun-pty-source
tar --extract --gzip --file %{SOURCE6} --strip-components=1 --directory .bun-pty-source
test ! -e .bun-pty-source/rust-pty/target
cp -a .bun-pty-source/rust-pty "$bun_pty/rust-pty"
tar --extract --zstd --file %{SOURCE7} --directory "$bun_pty/rust-pty"
pushd "$bun_pty/rust-pty" >/dev/null
%cargo_prep -v cargo-vendor
popd >/dev/null

%build
export CI=1
export OPENCODE_DISABLE_AUTOUPDATE=1
export OPENCODE_VERSION="%{version}"
export OPENCODE_CHANNEL=prod
export BUN_INSTALL_CACHE_DIR="$PWD/.bun-cache"
export HOME="$PWD/.build-home"
export XDG_CACHE_HOME="$PWD/.build-cache"
mkdir -p "$HOME" "$XDG_CACHE_HOME"

# Build exact esbuild from Go source and the pinned x/sys module. The npm
# package contributes only the JavaScript API and cannot select a platform
# binary because ESBUILD_BINARY_PATH is set below.
export GOCACHE="$PWD/.build-cache/go"
mkdir -p "$GOCACHE"
pushd .build-tools/esbuild >/dev/null
CGO_ENABLED=0 GOPROXY=off GOSUMDB=off \
  go build -mod=vendor -trimpath -ldflags='-s -w' \
  -o "$OLDPWD/.build-tools/esbuild-bin" ./cmd/esbuild
popd >/dev/null
test "$(.build-tools/esbuild-bin --version)" = "%{esbuild_version}"

# Build the exact wasm-bindgen CLI release from its vendored source. It is a
# private build tool and is not installed in the resulting RPM.
pushd .wasm-bindgen-cli-source >/dev/null
CARGO_HOME=.cargo RUSTC_BOOTSTRAP=1 RUSTFLAGS='%{build_rustflags}' \
  cargo build -j4 -Z avoid-dev-deps --profile rpm --frozen --bin wasm-bindgen
popd >/dev/null

# Rebuild Photon's functional WASM from the crates.io source published from the
# npm package's exact gitHead. Keep the readable upstream JavaScript glue, whose
# historical generation is source-proven, and replace only the opaque payload.
(
  unset RUSTFLAGS CARGO_ENCODED_RUSTFLAGS
  pushd .photon-source >/dev/null
  CARGO_HOME=.cargo CARGO_NET_OFFLINE=true \
    RUSTFLAGS="--remap-path-prefix=$PWD=/usr/src/debug/%{name}-%{version}/.photon-source" \
    cargo build -j4 --release --frozen --target wasm32-unknown-unknown --lib
  echo "%{photon_raw_wasm_sha256}  target/wasm32-unknown-unknown/release/photon_rs.wasm" | sha256sum -c -
  popd >/dev/null
)
mkdir -p .build-tools/photon
.wasm-bindgen-cli-source/target/release/wasm-bindgen \
  --target nodejs \
  --out-dir .build-tools/photon \
  --out-name photon_rs \
  .photon-source/target/wasm32-unknown-unknown/release/photon_rs.wasm
echo "%{photon_rebuilt_wasm_sha256}  .build-tools/photon/photon_rs_bg.wasm" | sha256sum -c -
photon_root="$(cat .build-tools/photon-root)"
install -pm0644 .build-tools/photon/photon_rs_bg.wasm "$photon_root/photon_rs_bg.wasm"
echo "%{photon_license_sha256}  .photon-source/LICENSE.md" | sha256sum -c -
cp -p .photon-source/LICENSE.md photon-rs-LICENSE.md

# Emscripten 4.0.4 requires Binaryen 121. Build the exact release privately
# with Fedora clang and expose only the installed tools to Emscripten.
cmake -S .build-tools/binaryen -B .build-tools/binaryen-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/usr/bin/clang-20 \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++-20 \
  -DCMAKE_INSTALL_PREFIX="$PWD/.build-tools/binaryen-install" \
  -DBUILD_EMSCRIPTEN_TOOLS_ONLY=ON \
  -DBUILD_STATIC_LIB=ON \
  -DBUILD_TESTS=OFF \
  -DENABLE_WERROR=OFF
cmake --build .build-tools/binaryen-build --parallel 4
cmake --install .build-tools/binaryen-build

cat > .build-tools/emscripten-config.py <<EOF
LLVM_ROOT = '/usr/lib64/llvm20/bin'
BINARYEN_ROOT = '$PWD/.build-tools/binaryen-install'
NODE_JS = '/usr/bin/node-24'
CACHE = '$PWD/.build-tools/emscripten-cache'
EOF
EM_CONFIG="$PWD/.build-tools/emscripten-config.py" \
  python3 %{SOURCE20} \
  --emcc "$PWD/.build-tools/emscripten/emcc" \
  --source "$PWD/.build-tools/tree-sitter"

# Rebuild Shiki's Oniguruma WASM from the exact vscode-oniguruma and Oniguruma
# sources using the same private Emscripten/Binaryen toolchain. Keep Fedora's
# native compiler flags out of the wasm-only configure and compiler commands.
export PATH="$PWD/.build-tools/emscripten:$PATH"
export EM_CONFIG="$PWD/.build-tools/emscripten-config.py"
(
  unset CFLAGS CXXFLAGS FFLAGS FCFLAGS CPPFLAGS LDFLAGS
  pushd .shiki-vscode-oniguruma/deps/oniguruma >/dev/null
  autoreconf -vfi
  emconfigure ./configure
  make clean
  emmake make -j4
  popd >/dev/null
  pushd .shiki-vscode-oniguruma >/dev/null
  bash scripts/build.sh
  popd >/dev/null
)
pushd packages/opencode >/dev/null
shiki_root="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(dirname(fileURLToPath(import.meta.resolve("shiki")))))')"
popd >/dev/null
echo "%{shiki_rebuilt_wasm_sha256}  .shiki-vscode-oniguruma/out/onig.wasm" | sha256sum -c -
install -pm0644 .shiki-vscode-oniguruma/out/onig.wasm "$shiki_root/dist/onig.wasm"
cp -p .shiki-vscode-oniguruma/LICENSE.txt vscode-oniguruma-LICENSE.txt
cp -p .shiki-vscode-oniguruma/deps/oniguruma/COPYING oniguruma-COPYING

# Rebuild both Undici 5.29 llhttp modules from the exact generated release C
# source, replacing the historical Alpine-built scalar and SIMD payloads.
undici_emcc="$PWD/.build-tools/emscripten/emcc"
common_undici_flags=(-O3 -ffast-math -fno-exceptions -fvisibility=hidden -s STANDALONE_WASM=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s "EXPORTED_FUNCTIONS=['_malloc','_free']" -Wl,--export-dynamic -Wl,--export-table -Wl,--no-entry)
"$undici_emcc" "${common_undici_flags[@]}" .undici-llhttp/src/llhttp.c .undici-llhttp/src/http.c .undici-llhttp/src/api.c -I.undici-llhttp/include -o .build-tools/llhttp.wasm
"$undici_emcc" "${common_undici_flags[@]}" -msimd128 .undici-llhttp/src/llhttp.c .undici-llhttp/src/http.c .undici-llhttp/src/api.c -I.undici-llhttp/include -o .build-tools/llhttp_simd.wasm
echo "%{undici_rebuilt_wasm_sha256}  .build-tools/llhttp.wasm" | sha256sum -c -
echo "%{undici_rebuilt_simd_wasm_sha256}  .build-tools/llhttp_simd.wasm" | sha256sum -c -
while IFS= read -r root; do
  install -pm0644 .build-tools/llhttp.wasm "$root/lib/llhttp/llhttp.wasm"
  install -pm0644 .build-tools/llhttp_simd.wasm "$root/lib/llhttp/llhttp_simd.wasm"
  node-24 - "$root/lib/llhttp/llhttp.wasm" "$root/lib/llhttp/llhttp-wasm.js" <<'JS'
const fs = require("node:fs")
fs.writeFileSync(process.argv[3], `module.exports = '${fs.readFileSync(process.argv[2]).toString("base64")}'\n`)
JS
  node-24 - "$root/lib/llhttp/llhttp_simd.wasm" "$root/lib/llhttp/llhttp_simd-wasm.js" <<'JS'
const fs = require("node:fs")
fs.writeFileSync(process.argv[3], `module.exports = '${fs.readFileSync(process.argv[2]).toString("base64")}'\n`)
JS
done < .build-tools/undici-5.29-roots
cp -p .undici-llhttp/LICENSE-MIT llhttp-LICENSE-MIT

# Generate the exact Models.dev snapshot selected by OpenCode's release flake.
# The release's supported local-file override prevents any live API fetch.
cat > .build-tools/generate-models-snapshot.ts <<EOF
import { generate } from "$PWD/.models-dev/packages/core/src/generate.ts"
const providers = await generate("$PWD/.models-dev/providers")
await Bun.write(process.argv[2], JSON.stringify(providers))
EOF
bun .build-tools/generate-models-snapshot.ts .build-tools/models-dev-api.json
echo "%{models_dev_snapshot_sha256}  .build-tools/models-dev-api.json" | sha256sum -c -
export MODELS_DEV_API_JSON="$PWD/.build-tools/models-dev-api.json"

tree_sitter_source="$PWD/.build-tools/tree-sitter"
esbuild_binary="$PWD/.build-tools/esbuild-bin"
pushd "$tree_sitter_source/lib/binding_web" >/dev/null
ESBUILD_BINARY_PATH="$esbuild_binary" node-24 script/build.js
popd >/dev/null
web_tree_sitter="$(cat .build-tools/web-tree-sitter-root)"
install -pm0644 "$tree_sitter_source/lib/binding_web/tree-sitter.js" "$web_tree_sitter/tree-sitter.js"
install -pm0644 "$tree_sitter_source/lib/binding_web/tree-sitter.js.map" "$web_tree_sitter/tree-sitter.js.map"
install -pm0644 "$tree_sitter_source/lib/binding_web/tree-sitter.wasm" "$web_tree_sitter/tree-sitter.wasm"
install -pm0644 "$tree_sitter_source/lib/binding_web/tree-sitter.wasm.map" "$web_tree_sitter/tree-sitter.wasm.map"
cp -p "$tree_sitter_source/LICENSE" web-tree-sitter-LICENSE

cmake -S .build-tools/zig -B .build-tools/zig-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/usr/bin/clang-20 \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++-20 \
  -DCMAKE_PREFIX_PATH=/usr/lib64/llvm20 \
  -DCMAKE_INSTALL_PREFIX="$PWD/.build-tools/zig-build/stage3" \
  -DZIG_VERSION=0.15.2 \
  -DZIG_TARGET_TRIPLE=native \
  -DZIG_TARGET_MCPU=baseline \
  -DZIG_STATIC=OFF \
  -DZIG_USE_LLVM_CONFIG=ON \
  -DZIG_SHARED_LLVM=ON \
  -DZIG_STATIC_LLVM=OFF \
  -DZIG_STATIC_ZLIB=OFF \
  -DZIG_STATIC_ZSTD=OFF \
  -DZIG_NO_LIB=OFF
cmake --build .build-tools/zig-build \
  --target stage3 \
  --parallel 4
install -Dpm0755 \
  .build-tools/zig-build/stage3/bin/zig \
  .build-tools/bun-zig/zig
cp -a .build-tools/zig-build/stage3/lib/zig .build-tools/bun-zig/lib
test "$(.build-tools/bun-zig/zig version)" = "0.15.2"

# Fedora tree-sitter-cli compiles the reviewed npm parser/scanner sources. The
# private WASI SDK wrapper supplies the complete Bun-Zig WASI header stack.
wasi_sdk="$PWD/.build-tools/tree-sitter-wasi-sdk"
mkdir -p "$wasi_sdk/bin"
cat > "$wasi_sdk/bin/clang" <<EOF
#!/bin/sh
exec /usr/bin/clang-20 \
  -isystem "$PWD/.build-tools/bun-zig/lib/include" \
  -isystem "$PWD/.build-tools/bun-zig/lib/libc/include/wasm-wasi-musl" \
  -isystem "$PWD/.build-tools/bun-zig/lib/libc/include/generic-musl" \
  -isystem "$PWD/.build-tools/bun-zig/lib/libc/include/wasm32-wasi-any" \
  -isystem "$PWD/.build-tools/bun-zig/lib/libc/include/any-wasi-any" \
  "\$@"
EOF
chmod 0755 "$wasi_sdk/bin/clang"
pushd packages/opencode >/dev/null
bash_parser="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("tree-sitter-bash/package.json")))')"
powershell_parser="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("tree-sitter-powershell/package.json")))')"
popd >/dev/null
TREE_SITTER_WASI_SDK_PATH="$wasi_sdk" tree-sitter build --wasm \
  --output "$PWD/.build-tools/tree-sitter-bash.wasm" "$bash_parser"
TREE_SITTER_WASI_SDK_PATH="$wasi_sdk" tree-sitter build --wasm \
  --output "$PWD/.build-tools/tree-sitter-powershell.wasm" "$powershell_parser"
install -pm0644 .build-tools/tree-sitter-bash.wasm "$bash_parser/tree-sitter-bash.wasm"
install -pm0644 .build-tools/tree-sitter-powershell.wasm "$powershell_parser/tree-sitter-powershell.wasm"
mkdir -p .build-tools/opentui-wasm
TREE_SITTER_WASI_SDK_PATH="$wasi_sdk" tree-sitter build --wasm --output .build-tools/opentui-wasm/tree-sitter-javascript.wasm .opentui-grammar-javascript
TREE_SITTER_WASI_SDK_PATH="$wasi_sdk" tree-sitter build --wasm --output .build-tools/opentui-wasm/tree-sitter-typescript.wasm .opentui-grammar-typescript/typescript
TREE_SITTER_WASI_SDK_PATH="$wasi_sdk" tree-sitter build --wasm --output .build-tools/opentui-wasm/tree-sitter-markdown.wasm .opentui-grammar-markdown/tree-sitter-markdown
TREE_SITTER_WASI_SDK_PATH="$wasi_sdk" tree-sitter build --wasm --output .build-tools/opentui-wasm/tree-sitter-markdown_inline.wasm .opentui-grammar-markdown/tree-sitter-markdown-inline
TREE_SITTER_WASI_SDK_PATH="$wasi_sdk" tree-sitter build --wasm --output .build-tools/opentui-wasm/tree-sitter-zig.wasm .opentui-grammar-zig
pushd packages/opencode >/dev/null
opentui_core="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(fileURLToPath(import.meta.resolve("@opentui/core"))))')"
popd >/dev/null
for grammar in javascript typescript markdown markdown_inline zig; do install -pm0644 ".build-tools/opentui-wasm/tree-sitter-$grammar.wasm" "$opentui_core/assets/$grammar/tree-sitter-$grammar.wasm"; done
cp -p "$bash_parser/LICENSE" tree-sitter-bash-LICENSE
cp -p "$powershell_parser/LICENSE" tree-sitter-powershell-LICENSE

# Build the required OpenTUI library from its release source and exact package
# cache, strip non-runtime metadata, and replace the removed npm payload.
export ZIG_GLOBAL_CACHE_DIR="$PWD/.opentui-zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="$PWD/.opentui-zig-local-cache"
mkdir -p "$ZIG_LOCAL_CACHE_DIR"
opentui_source="$PWD/.opentui-source"
opentui_zig="$PWD/.build-tools/bun-zig/zig"
opentui_lib="$opentui_source/packages/core/src/zig/lib/x86_64-linux/libopentui.so"
pushd "$opentui_source/packages/core/src/zig" >/dev/null
"$opentui_zig" build \
  --seed 0 \
  --build-id=sha1 \
  -fno-incremental \
  -Dtarget=x86_64-linux-gnu.2.17 \
  -Doptimize=ReleaseFast \
  -j1
popd >/dev/null
strip --strip-unneeded "$opentui_lib"
test "$(sha256sum "$opentui_lib" | cut -d' ' -f1)" != "%{opentui_published_sha256}"
pushd packages/opencode >/dev/null
opentui_platform="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(fileURLToPath(import.meta.resolve("@opentui/core-linux-x64"))))')"
popd >/dev/null
install -pm0755 "$opentui_lib" "$opentui_platform/libopentui.so"
cp -p "$opentui_source/LICENSE" opentui-LICENSE
cp -p .opentui-uucode/LICENSE.md opentui-uucode-LICENSE.md
cp -p .opentui-yoga/LICENSE opentui-yoga-LICENSE

# Build bun-pty with Fedora's offline Cargo profile. The prep macro preserves
# the target/release symlink expected by bun-pty's static Bun import.
pushd packages/opencode >/dev/null
bun_pty="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("bun-pty/package.json")))')"
popd >/dev/null
pushd "$bun_pty/rust-pty" >/dev/null
%cargo_build
%{cargo_license_summary}
%{cargo_license} > LICENSE.dependencies
%cargo_vendor_manifest
test "$(wc -l < cargo-vendor.txt)" -eq 43
cmp cargo-vendor.txt %{SOURCE8}
popd >/dev/null
cp -p "$bun_pty/rust-pty/LICENSE.dependencies" bun-pty-LICENSE.dependencies
cp -p "$bun_pty/rust-pty/cargo-vendor.txt" bun-pty-cargo-vendor.txt

# Rebuild the required Parcel watcher from the authenticated main-package
# sources and replace the published platform payload before Bun embeds it.
pushd packages/opencode >/dev/null
parcel_source="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("@parcel/watcher/package.json")))')"
parcel_platform="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("@parcel/watcher-linux-x64-glibc/package.json")))')"
popd >/dev/null
pushd "$parcel_source" >/dev/null
node-24 /usr/lib/node_modules_24/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --nodedir=/usr
popd >/dev/null
install -pm0755 "$parcel_source/build/Release/watcher.node" "$parcel_platform/watcher.node"

# The source closure is reconstructed before this point. Network-backed
# package resolution and lifecycle scripts are not permitted here.
export OPENCODE_BUILD_METAFILE="$PWD/.build-tools/opencode-bundle-metafile.json"
bun run packages/opencode/script/build.ts --single --skip-install --skip-embed-web-ui
ruby %{SOURCE36} \
  --source-root "$PWD" \
  --metafile "$OPENCODE_BUILD_METAFILE" \
  --closure %{SOURCE3} \
  --source-audit %{SOURCE34} \
  --source-license-set %{SOURCE32} \
  --license-review %{SOURCE38} \
  --license-text-dir "$PWD" \
  --materialization "$PWD/.build-tools/node-modules-materialization.json" \
  --build-patch %{PATCH2} \
  --models-snapshot "$PWD/.build-tools/models-dev-api.json" \
  --parser-worker "$PWD/node_modules/@opentui/core/parser.worker.js" \
  --binary "$PWD/packages/opencode/dist/opencode-linux-x64/bin/opencode" \
  --expected-version "%{version}" \
  --output "$PWD/.build-tools/opencode-binary-embedding.json"
cmp "$PWD/.build-tools/opencode-binary-embedding.json" %{SOURCE37}

%check
test -f %{SOURCE2}
mkdir -p .test-dependencies
tar --extract --zstd --directory .test-dependencies --file %{SOURCE2}
pushd packages/opencode >/dev/null
bun_pty="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("bun-pty/package.json")))')"
popd >/dev/null
test -f "$bun_pty/rust-pty/target/release/librust_pty.so"
test "$(sha256sum "$bun_pty/rust-pty/target/release/librust_pty.so" | cut -d' ' -f1)" != a135c3d9f41d09a555e3e4609e0c80fa0ba035736c56791b9df3b55e6376438d
pushd packages/opencode >/dev/null
opentui_platform="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(fileURLToPath(import.meta.resolve("@opentui/core-linux-x64"))))')"
popd >/dev/null
opentui_lib="$opentui_platform/libopentui.so"
test -f "$opentui_lib"
test "$(sha256sum "$opentui_lib" | cut -d' ' -f1)" != "%{opentui_published_sha256}"
file "$opentui_lib" | grep -q 'ELF 64-bit LSB shared object.*x86-64.*stripped'
ldd -r "$opentui_lib"
for symbol in createRenderer destroyRenderer render bufferDrawBox yogaNodeCreate; do
  nm -D --defined-only "$opentui_lib" | grep -q " $symbol$"
done
python3 - "$opentui_lib" <<'PY'
import re
import subprocess
import sys

output = subprocess.check_output(["readelf", "--version-info", sys.argv[1]], text=True)
versions = [tuple(map(int, value.split("."))) for value in re.findall(r"GLIBC_([0-9.]+)", output)]
if not versions or max(versions) > (2, 17):
    raise SystemExit(f"unexpected GLIBC requirement: {max(versions, default=None)}")
PY
pushd packages/opencode >/dev/null
bun -e '
  import { resolveRenderLib } from "@opentui/core"
  const lib = resolveRenderLib()
  const renderer = lib.createRenderer(4, 3, { bufferedOutput: "memory" })
  if (!renderer) throw new Error("OpenTUI renderer allocation failed")
  lib.destroyRenderer(renderer)
'
popd >/dev/null
pushd packages/opencode >/dev/null
bash_parser="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("tree-sitter-bash/package.json")))')"
powershell_parser="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("tree-sitter-powershell/package.json")))')"
popd >/dev/null
photon_root="$(cat .build-tools/photon-root)"
test -f "$photon_root/photon_rs_bg.wasm"
echo "%{photon_rebuilt_wasm_sha256}  $photon_root/photon_rs_bg.wasm" | sha256sum -c -
node-24 - "$photon_root" <<'JS'
const crypto = require("node:crypto")
const path = require("node:path")
const photon = require(path.join(process.argv[2], "photon_rs.js"))
const raw = Uint8Array.from([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255])
const source = new photon.PhotonImage(raw, 2, 2)
const png = Buffer.from(source.get_bytes())
const decoded = photon.PhotonImage.new_from_byteslice(png)
const resized = photon.resize(decoded, 1, 1, photon.SamplingFilter.Lanczos3)
const jpeg = Buffer.from(resized.get_bytes_jpeg(80))
const digest = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex")
if (source.get_width() !== 2 || source.get_height() !== 2) throw new Error("Photon source dimensions mismatch")
if (decoded.get_width() !== 2 || decoded.get_height() !== 2) throw new Error("Photon decode dimensions mismatch")
if (resized.get_width() !== 1 || resized.get_height() !== 1) throw new Error("Photon resize dimensions mismatch")
if (digest(png) !== "4d01524111816b3318a093b852f8da4b823b092462d290cc15e0ad401573cd9e") throw new Error("Photon PNG smoke mismatch")
if (digest(jpeg) !== "e1327581cb0c70b6658d6ce024165f880bfc484f68473b8d97f5adf6d4488108") throw new Error("Photon JPEG smoke mismatch")
resized.free()
decoded.free()
source.free()
JS
web_tree_sitter="$(cat .build-tools/web-tree-sitter-root)"
test ! -e "$bash_parser/prebuilds"
test -f "$bash_parser/tree-sitter-bash.wasm"
test -f "$powershell_parser/tree-sitter-powershell.wasm"
test -f "$web_tree_sitter/tree-sitter.js"
test -f "$web_tree_sitter/tree-sitter.wasm"
test "$(sha256sum "$bash_parser/tree-sitter-bash.wasm" | cut -d' ' -f1)" != "%{bash_published_wasm_sha256}"
test "$(sha256sum "$powershell_parser/tree-sitter-powershell.wasm" | cut -d' ' -f1)" != "%{powershell_published_wasm_sha256}"
test "$(sha256sum "$web_tree_sitter/tree-sitter.wasm" | cut -d' ' -f1)" != "%{web_tree_sitter_published_wasm_sha256}"
node-24 %{SOURCE21} \
  "$web_tree_sitter" \
  "$bash_parser/tree-sitter-bash.wasm" \
  "$powershell_parser/tree-sitter-powershell.wasm"
pushd packages/opencode >/dev/null
shiki_root="$(node-24 --input-type=module -e 'import { dirname } from "node:path"; import { fileURLToPath } from "node:url"; process.stdout.write(dirname(dirname(fileURLToPath(import.meta.resolve("shiki")))))')"
popd >/dev/null
echo "%{shiki_rebuilt_wasm_sha256}  $shiki_root/dist/onig.wasm" | sha256sum -c -
pushd packages/opencode >/dev/null
node-24 --input-type=module <<'JS'
import { codeToTokens } from "shiki"
const source = "const agentlab = 1"
const result = await codeToTokens(source, { lang: "javascript", theme: "nord" })
const text = result.tokens.flat().map((token) => token.content).join("")
if (text !== source) throw new Error(`Shiki token smoke mismatch: ${JSON.stringify(text)}`)
JS
popd >/dev/null
while IFS= read -r root; do
  echo "%{undici_rebuilt_wasm_sha256}  $root/lib/llhttp/llhttp.wasm" | sha256sum -c -
  echo "%{undici_rebuilt_simd_wasm_sha256}  $root/lib/llhttp/llhttp_simd.wasm" | sha256sum -c -
  node-24 - "$root/lib/llhttp/llhttp.wasm" "$root/lib/llhttp/llhttp_simd.wasm" <<'JS'
const fs = require("node:fs")
for (const path of process.argv.slice(2)) {
  const module = new WebAssembly.Module(fs.readFileSync(path))
  const env = Object.fromEntries(WebAssembly.Module.imports(module).filter((entry) => entry.module === "env").map((entry) => [entry.name, () => 0]))
  const instance = new WebAssembly.Instance(module, { env })
  for (const name of ["malloc", "free", "llhttp_init", "llhttp_execute"]) if (typeof instance.exports[name] !== "function") throw new Error(`${path}: missing ${name}`)
}
JS
done < .build-tools/undici-5.29-roots
packages/opencode/dist/opencode-linux-x64/bin/opencode --version

%install
install -Dpm0755 \
  packages/opencode/dist/opencode-linux-x64/bin/opencode \
  %{buildroot}%{_bindir}/opencode

%files
%license LICENSE %{name}-%{version}-bundled-licenses.txt
%license bun-pty-LICENSE.dependencies bun-pty-cargo-vendor.txt
%license opentui-LICENSE opentui-uucode-LICENSE.md opentui-yoga-LICENSE
%license web-tree-sitter-LICENSE tree-sitter-bash-LICENSE tree-sitter-powershell-LICENSE
%license photon-rs-LICENSE.md
%license %{name}-%{version}-aws-sdk-js-v3-LICENSE %{name}-%{version}-sigstore-verify-LICENSE
%license %{name}-%{version}-drizzle-orm-LICENSE %{name}-%{version}-poe-platform-LICENSE
%license %{name}-%{version}-remeda-LICENSE %{name}-%{version}-spdx-exceptions-README.md
%doc README.md %{name}-%{version}-binary-embedding.json %{name}-%{version}-final-license-closure.json
%{_bindir}/opencode

%changelog
* Mon Jul 27 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.16
- Refresh the final-license preflight for Bun's generated-header provenance.

* Mon Jul 27 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.15
- Add a fail-closed final-license preflight across OpenCode and Bun evidence.
- Preserve all unresolved notice, aggregate-license, payload, and target-build gates.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.14
- Rebuild Photon WASM from the authenticated Rust source and vendored Cargo inputs.
- Verify the source-built payload through OpenCode's decode, resize, and encode operations.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.13
- Add exact upstream license texts for ten embedded npm package identities.
- Preserve the three unresolved package notices as explicit publication blockers.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.12
- Record the normalized Bun compiler input graph for the standalone executable.
- Generate exact manual bundled Node Provides from 491 embedded public package identities.
- Reduce package-local license-text review to the 13 gaps present in the shipped npm graph.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.11
- Isolate Emscripten builds from Fedora's native compiler and linker flags.
- Materialize the selected source workspaces without package-manager execution.
- Supply upstream's deterministic production release identity during the build.
- Exercise the rebuilt Shiki WASM through the selected runtime API.
- Disable empty debug packages for the standalone binary without debug sections.
- Preserve Bun's embedded standalone payload from automatic RPM stripping.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.10
- Materialize the checked npm dependency tree without package-manager execution.
- Correct the OpenTUI published-payload checksum exposed by full materialization.
- Align Undici cleanup with the audited dependency layout and manifest paths.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.9
- Integrate the checked npm and bun-pty sources into the source RPM.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.8
- Materialize the checked npm source bundles deterministically.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.7
- Classify the complete selected npm source-license set.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.6
- Pin and source-build the Models.dev snapshot selected by upstream Nix packaging.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.5
- Rebuild Undici's scalar and SIMD llhttp WASMs from source.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.4
- Rebuild Shiki's Oniguruma WASM from corresponding source.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.3
- Rebuild OpenTUI's five grammar WASMs from pinned sources.

* Sun Jul 26 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.2
- Rebuild the current OpenTUI native library from exact sources.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.18.5-0.1
- Refresh exact release and selected-source evidence.
- Update OpenTUI identities while retaining fail-closed build gates.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.7
- Rebuild the selected Tree-sitter runtime and shell grammars from source.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.6
- Rebuild OpenTUI from exact source with the Bun-pinned Zig toolchain.
- Record fail-closed lifecycle-script dispositions for the selected closure.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.5
- Reconcile the current selected-source audit records.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.4
- Rebuild bun-pty from exact Git and vendored Cargo sources.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.3
- Rebuild the Parcel watcher from source before compiling the selected CLI.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.2
- Omit the FFF native accelerator and use the system-ripgrep fallback.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.1
- Refresh the blocked source-build draft to released version 1.18.3.
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.18.1-0.0.2
- Correct the Node application bundling model and reserve manual bundled(nodejs-...) metadata.
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.18.1-0.0.1
- Update the blocked draft to released version 1.18.1.
* Tue Jul 14 2026 Marcin FM <marcin@lgic.pl> - 1.17.20-0.0.1
- Add a disabled source-build draft and record the missing dependency gates.
