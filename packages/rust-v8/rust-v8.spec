# Disabled by package.yml. This spec deliberately aborts before unpacking until
# every recursive source, license, and offline build gate is complete.
%bcond check 1
%global source_commit 5d0e31ea6bf67f4559faa759b91e22bc3f1cd696
%global source_sha256 8f63ff709b52b7a2de0453e37ba8f661c21d0a398e4ecf5298b273ab8018747a
%global closure_sha256 fd5c2a46665b5686799a7505158e4f0bb047e087750acb455c50dfb90e3484b1
%global system_rust_patch_sha256 3b7fd4b8b962d1003b284b503390140c696d7c5e91579774455628cba11d5976
%global gcc_patch_sha256 6277a9deab29c02a1ce0b5d29e940eed40835c8a17ef45311a0c34205818d5f2

Name:           rust-v8
Version:        149.2.0
Release:        0.1%{?dist}
Summary:        Source-built Rusty V8 static archive

# MIT covers Rusty V8 and BSD-3-Clause covers the original downstream allocator
# shim. The recursive Chromium, V8, third-party, and vendored Rust aggregate
# remains a fail-closed license gate.
License:        MIT AND BSD-3-Clause
URL:            https://github.com/denoland/rusty_v8
Source0:        https://codeload.github.com/denoland/rusty_v8/tar.gz/%{source_commit}#/%{name}-%{version}.tar.gz
Source1:        %{name}-%{version}-source-closure.json
Source2:        %{name}-system-rust-toolchain.patch
Source3:        %{name}-gcc-portability.patch

# The checked system-Rust and GCC portability patches remain package evidence,
# but are intentionally not declared until the recursive source is an RPM input
# and the preparation phase can apply them. Both are retained in the source RPM
# and recorded by hash in dependencies.yml.

ExclusiveArch:  x86_64

BuildRequires:  bindgen-cli >= 0.72
BuildRequires:  clang-libs >= 19
BuildRequires:  gcc-c++
BuildRequires:  gn
BuildRequires:  lld
BuildRequires:  ninja-build
BuildRequires:  python3
BuildRequires:  rust >= 1.91
BuildRequires:  rustfmt

%description
Rusty V8 provides Rust bindings to Google's V8 JavaScript engine. This source
package builds the exact static archive consumed by the `v8 149.2.0` crate.

This draft is intentionally blocked. The root archive and exact recursive Git
identities are recorded, and the Fedora stable-toolchain patches reproduce the
local source-build proof, but immutable recursive source archives, complete
license accounting, network-isolated Fedora builds, and architecture proof are
not complete.

%package static
Summary:        Exact-version Rusty V8 static archive
Provides:       rusty-v8-static(abi) = %{version}

%description static
This package contains `librusty_v8.a` for the exact `v8 149.2.0` crate. Cargo
consumers select it with `RUSTY_V8_ARCHIVE` during their own source builds.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{closure_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{system_rust_patch_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{gcc_patch_sha256}  %{SOURCE3}" | sha256sum -c -
echo 'rust-v8 is blocked: see package.yml and dependencies.yml' >&2
exit 1

%build

%install
install -Dpm0644 out/fedora/obj/librusty_v8.a \
  %{buildroot}%{_libdir}/rust-v8/%{version}/librusty_v8.a

%files static
%license LICENSE
%{_libdir}/rust-v8/%{version}/librusty_v8.a

%changelog
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.1
- Add a fail-closed exact-version Rusty V8 static provider draft.
- Record the 21-component recursive source identity and Fedora stable-Rust patches.
