# Disabled by package.yml. This draft proves the private, release-pinned Zig
# source bootstrap and builds the pinned WebKit/JSC source before stopping at
# the still-incomplete Bun build stages.
%global source_sha256 112a5915992807f04b183854d360c2bf87ac7c1587fb5da3c560bdbb75b8c92e
%global bun_commit 0d9b296af33f2b851fcbf4df3e9ec89751734ba4
%global zig_commit 04e7f6ac1e009525bc00934f20199c68f04e0a24
%global zig_sha256 b094c5f806d053896de897023b6c8ccb56903fb994c6f86dd44d848e760fe44d
%global webkit_commit 5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b
%global webkit_source_tag bun-sources-%{version}-webkit-5488984d20e0
%global webkit_sha256 38253c470959d729a196a543d6fce9e8aacc378ffc492790ded2b69598d7213d
%global boringssl_sha256 a414b1d105fef105697b7428c0be5f7fc67489849eaa276931ae8344d78a99b8
%global brotli_sha256 e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff
%global cares_sha256 8c94116cb366ae4a44e487da4d9f7e736287d329efa6f88fdf077cd2d0a2e4b8
%global hdrhistogram_sha256 811c5e5ae5303a75ade50688880af6aad5d2f951ec5785f68186bd18635cdfc9
%global highway_sha256 741d705781e0b3e406beda8f1f994fbae01321237ce8023a1ad90fbaf7940c25
%global libarchive_sha256 042f0efe7147063ff9ba10f1a38ed080e949bcbd04bdbf3592b8846dd11b1da2
%global libdeflate_sha256 1e5cc06bdbf3e1245d8b89c9e3588f507e3c8bc53fe8b8229770a9e8661dea81
%global libjpeg_turbo_sha256 440f3a94390c78eab88f74b92944d2f6b248e592e984412e389885dfb5796bf0
%global libspng_sha256 d656813290d70a750b69e768323ff3b3875adf8c2e8c2fdb4e57ca1467abf86a
%global libwebp_sha256 76fb89b4454ff2161bb0cca2cf832e19b8b4001b0ef42fbcc2b4a437c945b2b6
%global lolhtml_sha256 2c53161edf633fa99acfc4eafddbafd5d9b8199f0918a1cc9152cb6c2c9bf379
%global lshpack_sha256 07d8bf901bb1b15543f38eabd23938519e1210eebadb52f3d651d6ef130ef973
%global lsqpack_sha256 e9d8abe5b7c1e35b9908a9521e2acd7c1d17547babc01d73c7297e02aebbcc2d
%global lsquic_sha256 f8cb90fb327eb91597c23163bf596c0d1882560be35b661d9ba84891cc461735
%global mimalloc_sha256 d98b7f315f16b82cd43b7e36a7e1f73ceae9422f8bba8ebb99899c78a54277fc
%global picohttpparser_sha256 637ff2ab6f5c7f7e05a5b5dc393d5cf2fea8d4754fcaceaaf935ffff5c1323ee
%global tinycc_sha256 6b50485fcbbfa90a99c56e8e2b6a92014dcd34377d5edb23e1938dc9ec96f0aa
%global zlib_sha256 a0d2a5d122c84b56a793a1553a9c3327fb2eb7469bf7a86b79e3c7be5d92e8d6
%global zstd_sha256 4b0bd1f0cfb25e61b9103c35f27395530ff5b4c0d2513a00fd745849e85ea52c
%global node_headers_sha256 045e9bf477cd5db0ec67f8c1a63ba7f784dedfe2c581e3d0ed09b88e9115dd07
%global npm_sources_sha256 38abcf51050008cb80a3b543d56aea0dd65e454b2bca25f85e782f5fe751d95f
%global cargo_vendor_sha256 299c363484cca82f6c6c0469aafac1e8b3dd925706b425347f64d6047dadce57
%global cargo_vendor_manifest_sha256 37dc9f2bef863d9b87e3e289ea9a783b6955bd961586be34ad0c37766522d187
%global lolhtml_manifest_sha256 feebef6f9b726f63b58bfad3bbc0a8a81667fbaf4e4111dc1a4e8f79b83e9f03
%global lolhtml_lockfile_sha256 02d28352293be00f05be457e59e60d5b9d7e84a4cdc43bd40236a12bf8d1e53d
%global lolhtml_source_identity 712928b3736f4aad
%global release_local_closure_sha256 ee3ed17e495779441326d10cd8d7f07a21b856285abc0f41ef9e5be6f99abbe0
%global source_staging_helper_sha256 73f25a3a5e3640d749a69fa530d8fb0d2fcad93e1c8aa01460b829616a63aaaf
%global npm_cache_tree_sha256 50e66a5b8361735b2598a6be5d7d78f973db05104cbdf9b9addb01e9a113d214
%global npm_cache_entries 4613
%global npm_cache_files 3855
%global npm_cache_directories 758
%global npm_cache_file_bytes 121972064

Name:           bun
Version:        1.3.14
Release:        0.0.19%{?dist}
Summary:        JavaScript runtime, bundler, test runner, and package manager

# Provisional only. Complete the bundled-source license audit before enabling.
License:        MIT AND LGPL-2.0-only AND LGPL-2.1-only AND Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND Zlib AND Unicode-DFS-2016
URL:            https://bun.com
Source0:        https://github.com/oven-sh/bun/archive/refs/tags/bun-v%{version}.tar.gz
Source1:        https://codeload.github.com/oven-sh/zig/tar.gz/%{zig_commit}#/%{name}-%{version}-zig-%{zig_commit}.tar.gz
# GitHub codeload returns HTTP 422 for this repository. This immutable release
# asset is generated from the complete pinned archive by
# scripts/package-bun-webkit-source. The package receipt binds both identities.
Source2:        https://github.com/marcin-fm/agentlab/releases/download/%{webkit_source_tag}/WebKit-%{webkit_commit}-jsc.tar.gz
Source3:        https://github.com/oven-sh/boringssl/archive/0c5fce43b7ed5eb6001487ee48ac65766f5ddcd1.tar.gz#/boringssl-5e15ff9594809574.tar.gz
Source4:        https://github.com/google/brotli/archive/v1.1.0.tar.gz#/brotli-723494d4c3a9902a.tar.gz
Source5:        https://github.com/c-ares/c-ares/archive/3ac47ee46edd8ea40370222f91613fc16c434853.tar.gz#/cares-4e43539b43c0f4ae.tar.gz
Source6:        https://github.com/HdrHistogram/HdrHistogram_c/archive/be60a9987ee48d0abf0d7b6a175bad8d6c1585d1.tar.gz#/hdrhistogram-97084f213075a65e.tar.gz
Source7:        https://github.com/google/highway/archive/2607d3b5b0113992fe84d3848859eae13b3b52c1.tar.gz#/highway-b2dcc6002e95cc47.tar.gz
Source8:        https://github.com/libarchive/libarchive/archive/ded82291ab41d5e355831b96b0e1ff49e24d8939.tar.gz#/libarchive-4296b191210d6b1b.tar.gz
Source9:        https://github.com/ebiggers/libdeflate/archive/c8c56a20f8f621e6a966b716b31f1dedab6a41e3.tar.gz#/libdeflate-ce0e2d9805b30dcc.tar.gz
Source10:       https://github.com/libjpeg-turbo/libjpeg-turbo/archive/e352b02f794f701407b39af08576035ba3360d60.tar.gz#/libjpeg-turbo-297099166a01f75e.tar.gz
Source11:       https://github.com/randy408/libspng/archive/fb768002d4288590083a476af628e51c3f1d47cd.tar.gz#/libspng-e6aca86c593b51ad.tar.gz
Source12:       https://github.com/webmproject/libwebp/archive/b7e29b9d75bd31422b00c2a446d49d7af06c328d.tar.gz#/libwebp-2ced709f169b40bd.tar.gz
Source13:       https://github.com/cloudflare/lol-html/archive/77127cd2b8545998756e8d64e36ee2313c4bb312.tar.gz#/lolhtml-929339b1d898e66b.tar.gz
Source14:       https://github.com/litespeedtech/ls-hpack/archive/8905c024b6d052f083a3d11d0a169b3c2735c8a1.tar.gz#/lshpack-73e0c55d12ea4fc2.tar.gz
Source15:       https://github.com/litespeedtech/ls-qpack/archive/1e9c5b8e59f8161c54f168a570c8bfdc59ded0c3.tar.gz#/lsqpack-ceeb8e315778b938.tar.gz
Source16:       https://github.com/litespeedtech/lsquic/archive/3181911301b1aa4f54c1ed690901abc674ee08fb.tar.gz#/lsquic-d3ef6cf1fbedd7f9.tar.gz
Source17:       https://github.com/oven-sh/mimalloc/archive/f15aecb94fc8096008bf87b90c53ed682026914a.tar.gz#/mimalloc-4a1c4f1f45e31b88.tar.gz
Source18:       https://github.com/h2o/picohttpparser/archive/066d2b1e9ab820703db0837a7255d92d30f0c9f5.tar.gz#/picohttpparser-fad59b16ad4752cc.tar.gz
Source19:       https://github.com/oven-sh/tinycc/archive/12882eee073cfe5c7621bcfadf679e1372d4537b.tar.gz#/tinycc-2f1f629056328c7b.tar.gz
Source20:       https://github.com/zlib-ng/zlib-ng/archive/12731092979c6d07f42da27da673a9f6c7b13586.tar.gz#/zlib-655c6ecdb6fc9cd5.tar.gz
Source21:       https://github.com/facebook/zstd/archive/f8745da6ff1ad1e7bab384bd1f9d742439278e99.tar.gz#/zstd-e010993a24072468.tar.gz
Source22:       https://nodejs.org/dist/v24.3.0/node-v24.3.0-headers.tar.gz#/nodejs-d79d5920ee9b0fc1.tar.gz
# Generated during repository-backed SRPM construction from the checked Bun lock closure.
Source23:       bun-%{version}-npm-sources.tar.gz
# Generated during repository-backed SRPM construction from the checked lol-html Cargo lock closure.
Source24:       bun-%{version}-lolhtml-cargo-vendor.tar.gz
# Checked machine-readable contract for the direct and bundled dependency sources.
Source25:       bun-%{version}-release-local-source-closure.json
# Fedora packaging helper that reconstructs Bun's offline source/cache layout.
Source26:       bun-stage-release-local-sources
# Resolve shared LLVM support libraries to Fedora's multilib paths for Bun's private Zig bootstrap.
# Fedora-specific; not submitted upstream because it adapts the Bun-pinned fork to Fedora's shared LLVM layout.
Patch0:         zig-fedora-lib64.patch
# Arch Linux fix for JSC typed-array conversion UB tracked in Bun issue 28607.
# Provenance: archlinux/packaging/packages/bun commit e6f882caed2016f0aadfe1d2af821c42b74d5840.
Patch1:         bun-webkit-typed-array-int32-conversion.patch
# Fedora native Linux uses stable Rust for lol-html and keeps the existing panic=abort path.
# Upstream later removed this standalone C API build in commit 86d32c8bb66d503ccbcc1d2e40d25b11679eeede.
Patch2:         bun-lolhtml-fedora-stable-rust.patch
# Bun 1.3.14 does not parse libc selectors from its text lockfile. Disable the
# incompatible musl Lightning CSS prebuilt package with a supported OS value.
Patch3:         bun-lightningcss-fedora-glibc-lock.patch
# Ninja runs from the out-of-tree build directory, so bind Bun's Zig build and
# semantic-check subprocesses to the release source root through stream.ts.
Patch4:         bun-zig-build-cwd.patch
# Use Fedora's shared C++ runtime instead of requiring unavailable static
# libstdc++ and libgcc archives in the final Bun link.
Patch5:         bun-fedora-shared-cxx-runtime.patch

ExclusiveArch:  x86_64

BuildRequires:  binutils
BuildRequires:  bison
BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  clang20
BuildRequires:  clang20-devel
BuildRequires:  clang20-libs
BuildRequires:  clang21
BuildRequires:  cmake
BuildRequires:  flex
BuildRequires:  gcc-c++
BuildRequires:  git-core
BuildRequires:  gperf
BuildRequires:  libicu-devel
BuildRequires:  libxml2-devel
BuildRequires:  libzstd-devel
BuildRequires:  lld20-devel
BuildRequires:  lld20-libs
BuildRequires:  lld21
BuildRequires:  llvm20-devel
BuildRequires:  llvm20-libs
BuildRequires:  llvm21-devel
BuildRequires:  ncurses-devel
BuildRequires:  ninja-build
BuildRequires:  patch
BuildRequires:  perl-English
BuildRequires:  perl-FindBin
BuildRequires:  perl-JSON-PP
BuildRequires:  perl-bignum
BuildRequires:  perl-interpreter
BuildRequires:  pkgconfig
BuildRequires:  python3
BuildRequires:  ruby
BuildRequires:  ruby-bundled-gems
BuildRequires:  zlib-ng-compat-devel

%description
Bun is an all-in-one JavaScript runtime and development toolkit.

This draft is intentionally excluded from COPR. It source-bootstraps the
Bun-pinned Zig fork without an external Zig executable, verifies and patches
the checked minimized WebKit/JSC source, builds its static libraries with LLVM 21,
and carries the verified Fedora-stable Rust and glibc-only npm lock paths. The
three frozen npm installs are proven separately with networking unavailable.
The RPM draft carries the complete checked dependency-source closure, stages
the native dependency trees, Node.js headers, npm install cache, and vendored
lol-html Cargo graph at Bun's production paths, and verifies the Cargo static
library through Fedora macros. The source-built npm installs, final Bun build
graph, and relink payload integration remain blocked.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{zig_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{webkit_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{boringssl_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{brotli_sha256}  %{SOURCE4}" | sha256sum -c -
echo "%{cares_sha256}  %{SOURCE5}" | sha256sum -c -
echo "%{hdrhistogram_sha256}  %{SOURCE6}" | sha256sum -c -
echo "%{highway_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{libarchive_sha256}  %{SOURCE8}" | sha256sum -c -
echo "%{libdeflate_sha256}  %{SOURCE9}" | sha256sum -c -
echo "%{libjpeg_turbo_sha256}  %{SOURCE10}" | sha256sum -c -
echo "%{libspng_sha256}  %{SOURCE11}" | sha256sum -c -
echo "%{libwebp_sha256}  %{SOURCE12}" | sha256sum -c -
echo "%{lolhtml_sha256}  %{SOURCE13}" | sha256sum -c -
echo "%{lshpack_sha256}  %{SOURCE14}" | sha256sum -c -
echo "%{lsqpack_sha256}  %{SOURCE15}" | sha256sum -c -
echo "%{lsquic_sha256}  %{SOURCE16}" | sha256sum -c -
echo "%{mimalloc_sha256}  %{SOURCE17}" | sha256sum -c -
echo "%{picohttpparser_sha256}  %{SOURCE18}" | sha256sum -c -
echo "%{tinycc_sha256}  %{SOURCE19}" | sha256sum -c -
echo "%{zlib_sha256}  %{SOURCE20}" | sha256sum -c -
echo "%{zstd_sha256}  %{SOURCE21}" | sha256sum -c -
echo "%{node_headers_sha256}  %{SOURCE22}" | sha256sum -c -
echo "%{npm_sources_sha256}  %{SOURCE23}" | sha256sum -c -
echo "%{cargo_vendor_sha256}  %{SOURCE24}" | sha256sum -c -
echo "%{release_local_closure_sha256}  %{SOURCE25}" | sha256sum -c -
echo "%{source_staging_helper_sha256}  %{SOURCE26}" | sha256sum -c -
%autosetup -n bun-bun-v%{version} -N
patch -p1 < %{PATCH2}
patch -p1 < %{PATCH3}
patch -p1 < %{PATCH4}
patch -p1 < %{PATCH5}

mkdir -p .build-tools
tar -xf %{SOURCE1} -C .build-tools
mv .build-tools/zig-%{zig_commit} .build-tools/zig
patch -d .build-tools/zig -p1 < %{PATCH0}

mkdir -p vendor
tar -xf %{SOURCE2} -C vendor
mv vendor/WebKit-%{webkit_commit} vendor/WebKit
patch -d vendor/WebKit -p1 < %{PATCH1}

mkdir -p vendor/lolhtml
tar --extract --gzip --file %{SOURCE13} --strip-components=1 --directory vendor/lolhtml
echo "%{lolhtml_manifest_sha256}  vendor/lolhtml/c-api/Cargo.toml" | sha256sum -c -
echo "%{lolhtml_lockfile_sha256}  vendor/lolhtml/c-api/Cargo.lock" | sha256sum -c -
printf '%s\n' '%{lolhtml_source_identity}' > vendor/lolhtml/.ref

tar --extract --gzip --file %{SOURCE24} --directory vendor/lolhtml/c-api
pushd vendor/lolhtml/c-api >/dev/null
%cargo_prep -v cargo-vendor
test "$(find cargo-vendor -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 43
popd >/dev/null

mkdir -p .build-tools
ruby %{SOURCE26} \
  --source-root "$PWD" \
  --closure "%{SOURCE25}" \
  --npm-bundle "%{SOURCE23}" \
  --npm-cache "$PWD/.build-tools/bun-install-cache" \
  --prefetch-dir "$PWD/.build-tools/prefetch/by-url" \
  --receipt "$PWD/.build-tools/release-local-source-staging.json" \
  --npm-manifest "$PWD/.build-tools/npm-cache-manifest.jsonl" \
  --expected-npm-tree-sha256 "%{npm_cache_tree_sha256}" \
  --expected-npm-entries "%{npm_cache_entries}" \
  --expected-npm-files "%{npm_cache_files}" \
  --expected-npm-directories "%{npm_cache_directories}" \
  --expected-npm-file-bytes "%{npm_cache_file_bytes}"
test -s .build-tools/release-local-source-staging.json
test -s .build-tools/npm-cache-manifest.jsonl

%build
export HOME="$PWD/.build-home"
export XDG_CACHE_HOME="$PWD/.build-cache"
export GIT_SHA=%{bun_commit}
mkdir -p "$HOME" "$XDG_CACHE_HOME"

# This standalone check proves the staged vendored graph with Fedora's Cargo
# profile. Bun's final build later rebuilds the same C API with its own
# reviewed release flags into build/release/deps/lolhtml.
pushd vendor/lolhtml/c-api >/dev/null
%cargo_build
%cargo_vendor_manifest
ruby -e 'path = ARGV.fetch(0); text = File.read(path); changed = text.sub!(/^lol_html v2\.7\.2 \([^\n]+\)$/, "lol_html v2.7.2"); abort "missing local lol_html vendor record" unless changed; File.write(path, text)' cargo-vendor.txt
echo "%{lolhtml_lockfile_sha256}  Cargo.lock" | sha256sum -c -
echo "%{cargo_vendor_manifest_sha256}  cargo-vendor.txt" | sha256sum -c -
test "$(wc -l < cargo-vendor.txt)" -eq 41
test -s target/release/liblolhtml.a
nm -g --defined-only target/release/liblolhtml.a | grep 'lol_html_' | LC_ALL=C sort -u > lolhtml-exported-symbols.txt
test "$(wc -l < lolhtml-exported-symbols.txt)" -eq 97
popd >/dev/null

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

test -x .build-tools/bun-zig/zig
test -f .build-tools/bun-zig/lib/std/std.zig
test "$(.build-tools/bun-zig/zig version)" = "0.15.2"
.build-tools/bun-zig/zig env

cmake -S vendor/WebKit -B .build-tools/webkit-build -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER=/usr/bin/clang-21 \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++-21 \
  -DCMAKE_AR=/usr/bin/llvm-ar-21 \
  -DCMAKE_RANLIB=/usr/bin/llvm-ranlib-21 \
  -DCMAKE_EXE_LINKER_FLAGS=--ld-path=/usr/bin/ld.lld-21 \
  -DCMAKE_SHARED_LINKER_FLAGS=--ld-path=/usr/bin/ld.lld-21 \
  -DCMAKE_C_FLAGS=-march=haswell \
  -DCMAKE_CXX_FLAGS=-march=haswell \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DPORT=JSCOnly \
  -DENABLE_STATIC_JSC=ON \
  -DUSE_THIN_ARCHIVES=OFF \
  -DENABLE_FTL_JIT=ON \
  -DUSE_BUN_JSC_ADDITIONS=ON \
  -DUSE_BUN_EVENT_LOOP=ON \
  -DENABLE_BUN_SKIP_FAILING_ASSERTIONS=ON \
  -DALLOW_LINE_AND_COLUMN_NUMBER_IN_BUILTINS=ON \
  -DENABLE_REMOTE_INSPECTOR=ON \
  -DENABLE_MEDIA_SOURCE=OFF \
  -DENABLE_MEDIA_STREAM=OFF \
  -DENABLE_WEB_RTC=OFF

cmake --build .build-tools/webkit-build \
  --target jsc \
  --parallel 4

%check
cat > .build-tools/zig-proof.zig <<'EOF'
const std = @import("std");

pub fn main() void {
    std.debug.print("zig-bun-proof\n", .{});
}
EOF

.build-tools/bun-zig/zig run .build-tools/zig-proof.zig

grep -Fq 'const canBuildStdImmediateAbort = cfg.darwin || cfg.freebsd;' \
  scripts/build/deps/lolhtml.ts
grep -Fq '"-Cpanic=abort"' scripts/build/deps/lolhtml.ts
! grep -Fq 'cfg.linux && cfg.release' scripts/build/deps/lolhtml.ts

grep -Fq 'const cwd = `--cwd=${q(cfg.cwd)}`;' scripts/build/zig.ts
test "$(grep -Fc '${stream} ${cwd}' scripts/build/zig.ts)" = 2
grep -Fq 'flag: ["-lstdc++", "-lgcc_s"]' scripts/build/flags.ts
! grep -Fq 'flag: ["-static-libstdc++", "-static-libgcc"]' scripts/build/flags.ts

grep -Fq '"lightningcss-linux-x64-gnu": ["lightningcss-linux-x64-gnu@1.30.2", "", { "os": "linux", "cpu": "x64" }' \
  bun.lock
grep -Fq '"lightningcss-linux-x64-musl": ["lightningcss-linux-x64-musl@1.30.2", "", { "os": "none", "cpu": "x64" }' \
  bun.lock
! grep -Fq '"lightningcss-linux-x64-musl": ["lightningcss-linux-x64-musl@1.30.2", "", { "os": "linux", "cpu": "x64" }' \
  bun.lock

grep -Fq 'return static_cast<Type>(toInt32(value));' \
  vendor/WebKit/Source/JavaScriptCore/runtime/TypedArrayAdaptors.h
! grep -Fq 'int32_t result = truncateDoubleToInt32(value);' \
  vendor/WebKit/Source/JavaScriptCore/runtime/TypedArrayAdaptors.h

test -s .build-tools/webkit-build/lib/libWTF.a
test -s .build-tools/webkit-build/lib/libJavaScriptCore.a
test -s .build-tools/webkit-build/lib/libbmalloc.a
test -s .build-tools/webkit-build/CMakeCache.txt
test -s .build-tools/webkit-build/compile_commands.json
test -f .build-tools/webkit-build/JavaScriptCore/Headers/JavaScriptCore/JavaScript.h
test -f .build-tools/webkit-build/JavaScriptCore/PrivateHeaders/JavaScriptCore/TypedArrayAdaptors.h
test -f .build-tools/webkit-build/WTF/Headers/wtf/Assertions.h
test -f .build-tools/webkit-build/bmalloc/Headers/bmalloc/bmalloc.h
test "$(.build-tools/webkit-build/bin/jsc -e "print('agentlab-webkit-proof')")" = \
  "agentlab-webkit-proof"

echo "Remaining Bun source-build stages are incomplete; see package.yml" >&2
exit 1

%install
echo "No Bun payload is staged before the final self-rebuild gate passes"
mkdir -p %{buildroot}

%files
%license LICENSE.md

%changelog
* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.19
- Stage the native, Node.js, and npm dependency sources for the offline build graph.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.18
- Stage and verify the vendored lol-html Cargo build with Fedora macros.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.17
- Integrate the direct native and Node sources plus generated npm and Cargo sources.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.16
- Select the Fedora-aligned direct, npm-bundle, Cargo-vendor, and relink source layout.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.15
- Consume the immutable attested WebKit source release asset.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.14
- Retain Capstone in the deterministic WebKit source prepared for release hosting.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.13
- Bind the deterministic minimized WebKit/JSC source and its checked build proof.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.12
- Audit the retained final-link inputs and record the incomplete LGPL relink kit.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.11
- Prove the seed-free offline self-rebuild and record the clean-cache Zig reproducibility blocker.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.10
- Prove the first isolated source build with source-root Zig and Fedora's shared C++ runtime.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.9
- Cap the private Zig bootstrap at the four-job local build limit.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.8
- Prove the Fedora glibc-only frozen npm install path without network access.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.7
- Use Fedora stable Rust for the pinned lol-html Linux source path.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.6
- Move the fail-closed draft stop after the isolated source-build checks.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.5
- Build the pinned static WebKit/JSC source stage with Fedora LLVM 21.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.4
- Verify and stage the pinned WebKit source with the Arch JSC correctness patch.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.3
- Document the Fedora Zig bootstrap patch purpose and upstream status.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.2
- Source-bootstrap the release-pinned Zig fork as a private Bun build stage.

* Tue Jul 14 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.1
- Add a disabled source-bootstrap draft and enumerate missing toolchain packages.
