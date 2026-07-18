# Disabled by package.yml until Bun and the audited npm source closure are
# available. Do not replace these inputs with upstream platform binaries.
%global source_sha256 494041aedd7407079f91fd694de355f4ff022ba6bf876e09ff30983bbdc70ae1
%global bun_pty_commit 41dd5b887f3f47d7c307fd93f828a75dbee97d5a
%global bun_pty_source_sha256 d4731314a00c46d3810fa08b94ee0bcddb7a5026e47dbca88c83449d351bff9e
%global bun_pty_vendor_sha256 5c22d4bd79109a3460f3a3d3840d2541da9a6c4c91513c39065a1f4611b7ec5e
%global bun_pty_vendor_manifest_sha256 d57a66c2a1e90516e0b103b3074001f96cefcb4adb4ecc8c3a5532a2c884e500
%global opentui_version 0.4.3
%global opentui_source_sha256 3a72427d6cc6c7dc1086d44037d4f4c499ebc38c2e3e67ecf998695e65c8337a
%global opentui_published_sha256 6a0ea52ab0408a7909f35565d4e204f2a6fd884e33ff6ec570fa9357126ead49
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

Name:           opencode
Version:        1.18.3
Release:        0.7%{?dist}
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
Source11:       https://codeload.github.com/facebook/yoga/tar.gz/%{yoga_commit}#/%{name}-%{version}-yoga-%{yoga_commit}.tar.gz
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

ExclusiveArch:  x86_64

BuildRequires:  bun = 1.3.14
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
# END GENERATED BUNDLED NODE PROVIDES

%description
OpenCode is an open-source coding agent with a terminal user interface, local
server, and provider integrations.

This draft is intentionally excluded from COPR until every source-build and
license gate recorded in package.yml is complete.

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
%autosetup -n opencode-%{version} -N
patch -p1 < %{PATCH0}

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
echo "%{bun_pty_source_sha256}  %{SOURCE6}" | sha256sum -c -
echo "%{bun_pty_vendor_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{bun_pty_vendor_manifest_sha256}  %{SOURCE8}" | sha256sum -c -
python3 -m json.tool %{SOURCE3} >/dev/null
python3 -m json.tool %{SOURCE5} >/dev/null
cp -p %{SOURCE4} .
tar --extract --zstd --file %{SOURCE1}

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
bun run packages/opencode/script/build.ts --single --skip-install --skip-embed-web-ui

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
%doc README.md
%{_bindir}/opencode

%changelog
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
