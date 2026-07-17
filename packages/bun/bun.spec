# Disabled by package.yml. This draft proves the private, release-pinned Zig
# source bootstrap before stopping at the still-incomplete Bun build stages.
%global source_sha256 112a5915992807f04b183854d360c2bf87ac7c1587fb5da3c560bdbb75b8c92e
%global zig_commit 04e7f6ac1e009525bc00934f20199c68f04e0a24
%global zig_sha256 b094c5f806d053896de897023b6c8ccb56903fb994c6f86dd44d848e760fe44d
%global webkit_commit 5488984d20e0dbfe4be2c3ba8fb18eb81a5e0e8b

Name:           bun
Version:        1.3.14
Release:        0.0.3%{?dist}
Summary:        JavaScript runtime, bundler, test runner, and package manager

# Provisional only. Complete the bundled-source license audit before enabling.
License:        MIT AND LGPL-2.0-only AND LGPL-2.1-only AND Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND Zlib AND Unicode-DFS-2016
URL:            https://bun.com
Source0:        https://github.com/oven-sh/bun/archive/refs/tags/bun-v%{version}.tar.gz
Source1:        https://codeload.github.com/oven-sh/zig/tar.gz/%{zig_commit}#/%{name}-%{version}-zig-%{zig_commit}.tar.gz
# Resolve shared LLVM support libraries to Fedora's multilib paths for Bun's private Zig bootstrap.
# Fedora-specific; not submitted upstream because it adapts the Bun-pinned fork to Fedora's shared LLVM layout.
Patch0:         zig-fedora-lib64.patch

ExclusiveArch:  x86_64

BuildRequires:  clang20
BuildRequires:  clang20-devel
BuildRequires:  clang20-libs
BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  libxml2-devel
BuildRequires:  libzstd-devel
BuildRequires:  lld20-devel
BuildRequires:  lld20-libs
BuildRequires:  llvm20-devel
BuildRequires:  llvm20-libs
BuildRequires:  ncurses-devel
BuildRequires:  ninja-build
BuildRequires:  patch
BuildRequires:  pkgconfig
BuildRequires:  zlib-ng-compat-devel

%description
Bun is an all-in-one JavaScript runtime and development toolkit.

This draft is intentionally excluded from COPR. It source-bootstraps the
Bun-pinned Zig fork without an external Zig executable, then stops before the
unresolved WebKit, dependency-closure, Bun-seed, and self-rebuild stages.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{zig_sha256}  %{SOURCE1}" | sha256sum -c -
%autosetup -n bun-bun-v%{version} -N

mkdir -p .build-tools
tar -xf %{SOURCE1} -C .build-tools
mv .build-tools/zig-%{zig_commit} .build-tools/zig
patch -d .build-tools/zig -p1 < %{PATCH0}

%build
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
  --parallel %{?_smp_build_ncpus}

install -Dpm0755 \
  .build-tools/zig-build/stage3/bin/zig \
  .build-tools/bun-zig/zig
cp -a .build-tools/zig-build/stage3/lib/zig .build-tools/bun-zig/lib

test -x .build-tools/bun-zig/zig
test -f .build-tools/bun-zig/lib/std/std.zig
test "$(.build-tools/bun-zig/zig version)" = "0.15.2"
.build-tools/bun-zig/zig env

%check
cat > .build-tools/zig-proof.zig <<'EOF'
const std = @import("std");

pub fn main() void {
    std.debug.print("zig-bun-proof\n", .{});
}
EOF

.build-tools/bun-zig/zig run .build-tools/zig-proof.zig

echo "Remaining Bun source-build stages are incomplete; see package.yml" >&2
exit 1

%install
echo "Refusing to create a Bun RPM before the final self-rebuild gate passes" >&2
exit 1

%files
%license LICENSE.md

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.3
- Document the Fedora Zig bootstrap patch purpose and upstream status.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.2
- Source-bootstrap the release-pinned Zig fork as a private Bun build stage.

* Tue Jul 14 2026 Marcin FM <marcin@lgic.pl> - 1.3.14-0.0.1
- Add a disabled source-bootstrap draft and enumerate missing toolchain packages.
