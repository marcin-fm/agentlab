# Disabled by package.yml. This draft proves the private, release-pinned Zig
# source bootstrap and builds the pinned WebKit/JSC source before stopping at
# the still-incomplete Bun build stages.
%global source_sha256 112a5915992807f04b183854d360c2bf87ac7c1587fb5da3c560bdbb75b8c92e
%global bun_commit 0d9b296af33f2b851fcbf4df3e9ec89751734ba4
%global zig_commit 04e7f6ac1e009525bc00934f20199c68f04e0a24
%global zig_sha256 b094c5f806d053896de897023b6c8ccb56903fb994c6f86dd44d848e760fe44d
%global webkit_commit 5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b
%global webkit_sha256 38253c470959d729a196a543d6fce9e8aacc378ffc492790ded2b69598d7213d

Name:           bun
Version:        1.3.14
Release:        0.0.14%{?dist}
Summary:        JavaScript runtime, bundler, test runner, and package manager

# Provisional only. Complete the bundled-source license audit before enabling.
License:        MIT AND LGPL-2.0-only AND LGPL-2.1-only AND Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND Zlib AND Unicode-DFS-2016
URL:            https://bun.com
Source0:        https://github.com/oven-sh/bun/archive/refs/tags/bun-v%{version}.tar.gz
Source1:        https://codeload.github.com/oven-sh/zig/tar.gz/%{zig_commit}#/%{name}-%{version}-zig-%{zig_commit}.tar.gz
# GitHub codeload returns HTTP 422 for this repository. Generate the checked
# dual-architecture JSC-only source subset from the complete pinned archive with
# scripts/package-bun-webkit-source. The package receipt binds both identities.
# Replace this local draft source with an immutable HTTPS URL before enablement.
Source2:        WebKit-%{webkit_commit}-jsc.tar.gz
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

BuildRequires:  bison
BuildRequires:  clang20
BuildRequires:  clang20-devel
BuildRequires:  clang20-libs
BuildRequires:  clang21
BuildRequires:  cmake
BuildRequires:  flex
BuildRequires:  gcc-c++
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
The RPM draft stops before dependency-source integration and the Bun build.
Separate local proofs cover the first and seed-free offline self-builds, but
immutable source delivery and relink-kit source integration remain blocked.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{zig_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{webkit_sha256}  %{SOURCE2}" | sha256sum -c -
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

%build
export HOME="$PWD/.build-home"
export XDG_CACHE_HOME="$PWD/.build-cache"
export GIT_SHA=%{bun_commit}
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
