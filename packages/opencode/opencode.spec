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

Name:           opencode
Version:        1.18.3
Release:        0.6%{?dist}
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
BuildRequires:  file
BuildRequires:  libxml2-devel
BuildRequires:  libzstd-devel
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
echo "%{bun_pty_source_sha256}  %{SOURCE6}" | sha256sum -c -
echo "%{bun_pty_vendor_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{bun_pty_vendor_manifest_sha256}  %{SOURCE8}" | sha256sum -c -
python3 -m json.tool %{SOURCE3} >/dev/null
python3 -m json.tool %{SOURCE5} >/dev/null
cp -p %{SOURCE4} .
tar --extract --zstd --file %{SOURCE1}

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
packages/opencode/dist/opencode-linux-x64/bin/opencode --version

%install
install -Dpm0755 \
  packages/opencode/dist/opencode-linux-x64/bin/opencode \
  %{buildroot}%{_bindir}/opencode

%files
%license LICENSE %{name}-%{version}-bundled-licenses.txt
%license bun-pty-LICENSE.dependencies bun-pty-cargo-vendor.txt
%license opentui-LICENSE opentui-uucode-LICENSE.md opentui-yoga-LICENSE
%doc README.md
%{_bindir}/opencode

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.6
- Rebuild OpenTUI from exact source with the Bun-pinned Zig toolchain.
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
