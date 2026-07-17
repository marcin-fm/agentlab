# Disabled by package.yml pending immutable source hosting, release-boundary
# approval, and successful native aarch64 proof builds.
%global source_sha256 1880e1d7d4659f589e63a319d8967cf5e584085e1e817667d51356ad6ad1b7ef
%global source_closure_sha256 27749bcd3fab8c6dc5f621882823d6c43ca8c437193a56998a0c46b6be71a140
%global source_manifest_sha256 3751903dfbd79d53a969f96f05eed44200c0737a7a9a1c16d71ca501121cca45
%global source_policy_sha256 bceac435331b957027ef4f86bbd43a38d9941488aaee24f246243fcd4eeedc77
%global source_receipt_sha256 bd6b304cabeab431ab504bcf39477bc759593f974e0290a8b56d4d2d6d462991
%global agg_license_sha256 7c9a090bc2f7a49601bfb39e5504850feb7edc5ac2eba980610f6148a5538b43
%global third_party_notices_sha256 caa7153703e3bf5e968b6f22a1c8b94d6732a0bd9f10bb6a5b3a9da5ff97f34e
# Chromium already adds .gdb_index sections when linking with LLD.
%undefine _include_gdb_index
# Chromium deliberately emits relative DWARF paths with a dot compilation
# directory, so find-debuginfo cannot construct a non-empty source file list.
%undefine _debugsource_packages
%if 0%{?fedora} == 43
%global clang_major 21
%else
%global clang_major 22
%endif
%ifarch x86_64
%global gn_target_cpu x64
%global fedora_clang_target x86_64-redhat-linux-gnu
%global expected_elf_machine X86-64
%else
%global gn_target_cpu arm64
%global fedora_clang_target aarch64-redhat-linux-gnu
%global expected_elf_machine AArch64
%endif

Name:           pdfium
Version:        146.0.7678.0
Release:        0.0.4%{?dist}
Summary:        PDF rendering library used by Chromium

License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND MIT AND NAIST-2003 AND Unicode-3.0 AND LicenseRef-Fedora-Public-Domain
URL:            https://pdfium.googlesource.com/pdfium/
Source0:        pdfium-%{version}.tar.gz
Source1:        pdfium-%{version}-source-closure.tar.zst
Source2:        pdfium-%{version}-source-closure.json
Source3:        source-closure.yml
Source4:        pdfium-%{version}-closure-receipt.json
Source5:        AGG-LICENSE.txt
Source6:        THIRD-PARTY-NOTICES.txt
# Drop simdutf from an embedder-test target omitted by Fedora's reduced build.
# Fedora-specific; not submitted because Fedora does not build that test surface.
Patch0:         pdfium-drop-simdutf-test-dependency.patch
# Select Fedora's native x86_64 and aarch64 Clang target and compiler-rt layouts.
# Fedora-specific; not submitted because it follows Fedora's toolchain layout.
Patch1:         pdfium-fedora-clang-target.patch
# Give private Abseil and ICU components collision-free PDFium library names.
# Fedora-specific boundary; upstream does not install these components system-wide.
Patch2:         pdfium-private-component-names.patch
# Use SHA-1 linker build IDs so RPM can create its build-id link hierarchy.
# Fedora-specific; not submitted because RPM requires the longer build ID.
Patch3:         pdfium-fedora-build-id.patch
# Give PDFium and private components versioned SONAMEs for system installation.
# Fedora-specific ABI boundary; upstream does not ship a system-library ABI.
Patch4:         pdfium-versioned-sonames.patch
# Embed ICU data in the private component instead of shipping unlocated icudtl.dat.
# Fedora-specific runtime boundary; upstream controls data placement in its embedder.
Patch5:         pdfium-embed-icu-data.patch

ExclusiveArch:  x86_64 aarch64

BuildRequires:  clang
BuildRequires:  clang-devel
BuildRequires:  compiler-rt
BuildRequires:  fontconfig-devel
BuildRequires:  freetype-devel
BuildRequires:  gn
BuildRequires:  lcms2-devel
BuildRequires:  libicu-devel
BuildRequires:  libatomic
BuildRequires:  libjpeg-turbo-devel
BuildRequires:  libpng-devel
BuildRequires:  libtiff-devel
BuildRequires:  lld
BuildRequires:  llvm
BuildRequires:  ninja-build
BuildRequires:  openjpeg2-devel
BuildRequires:  pkgconf-pkg-config
BuildRequires:  python3
BuildRequires:  python3-jinja2
BuildRequires:  zlib-ng-compat-devel

%description
PDFium is the PDF library used by Chromium. This package builds the source
revision pinned by Chromium release %{version} as a shared library for native
Fedora consumers such as Kreuzberg.

%package devel
Summary:        Development files for PDFium
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description devel
Public FPDF headers and pkg-config metadata for PDFium.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{source_closure_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{source_manifest_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{source_policy_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{source_receipt_sha256}  %{SOURCE4}" | sha256sum -c -
echo "%{agg_license_sha256}  %{SOURCE5}" | sha256sum -c -
echo "%{third_party_notices_sha256}  %{SOURCE6}" | sha256sum -c -
%setup -q -n pdfium-%{version}
patch --batch --fuzz=0 -p1 < %{PATCH0}

python3 - "%{SOURCE2}" "%{SOURCE4}" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
receipt = json.load(open(sys.argv[2], encoding="utf-8"))
expected = {
    "pdfium": "efbbd0fc95825e049ad790911356e0b689418899",
    "chromium-build": "06d247cb917bb5fac3103b1b7dccb75368a553ce",
    "chromium-buildtools": "6a18683f555b4ac8b05ac8395c29c84483ac9588",
    "abseil": "675d3d37ecbec78fd51378c6774c45715b1e4382",
    "fast-float": "cb1d42aaa1e14b09e1452cfdef373d051b8c02a4",
    "icu": "a86a32e67b8d1384b33f8fa48c83a6079b86f8cd",
    "test-fonts": "7f51783942943e965cd56facf786544ccfc07713",
}

assert manifest["schema"] == 1
assert manifest["package"] == "pdfium"
assert manifest["version"] == "%{version}"
assert manifest["consumer"] == {"name": "kreuzberg", "version": "4.10.2"}
assert manifest["target"] == {"os": "linux", "architectures": ["x86_64", "aarch64"]}
assert all(value == "forbidden" for value in manifest["build_policy"].values() if isinstance(value, str))
assert {patch["file"]: patch["sha256"] for patch in manifest["fedora_patches"]} == {
    "pdfium-drop-simdutf-test-dependency.patch": "849a32a628d4ac5bb87d2eb8cac5395e938551e50aaf44b3ef6060c00557b5df",
    "pdfium-fedora-clang-target.patch": "09f3badac7487cb01f7d7d90c414173230bfca3a155684f12cd23c930ac9a99c",
    "pdfium-private-component-names.patch": "7244edaa8d2164c5fb1b18b424777f86856af757f87dd7e0aff70d4b869a9945",
    "pdfium-fedora-build-id.patch": "773e5b8e0cbca0b9888d9616466df8f53f6bf05787b22cc5c4143e7780cefb2b",
    "pdfium-versioned-sonames.patch": "b1d76926fc311801dd0b19ef37f22e0773c7dcb1a66aa85f146de64a4ccf0e47",
    "pdfium-embed-icu-data.patch": "6d9eab4ba09b001431495f90ade4366c0a628fd10917eb27d77718e3e3b58e6c",
}
sources = {source["id"]: source for source in manifest["sources"]}
assert set(sources) == set(expected)
for source_id, revision in expected.items():
    assert sources[source_id]["revision"] == revision
    assert sources[source_id]["resolved_commit"] == revision
    assert len(sources[source_id]["archive_sha256"]) == 64

assert receipt == {
    "schema": 1,
    "package": "pdfium",
    "version": "%{version}",
    "source_count": 7,
    "source_sha256": "%{source_sha256}",
    "closure_sha256": "%{source_closure_sha256}",
    "manifest_sha256": "%{source_manifest_sha256}",
    "source_policy_sha256": "%{source_policy_sha256}",
}
PY

tar --zstd -xf %{SOURCE1} -C .
patch --batch --fuzz=0 -p1 < %{PATCH1}
patch --batch --fuzz=0 -p1 < %{PATCH2}
patch --batch --fuzz=0 -p1 < %{PATCH3}
patch --batch --fuzz=0 -p1 < %{PATCH4}
patch --batch --fuzz=0 -p1 < %{PATCH5}

cat > build/config/gclient_args.gni <<'EOF'
build_with_chromium = false
checkout_android = false
checkout_skia = false
EOF

%build
mkdir -p out/Release
cat > out/Release/args.gn <<'EOF'
is_component_build = true
is_debug = false
symbol_level = 2
target_cpu = "%{gn_target_cpu}"
use_debug_fission = false
is_clang = true
clang_base_path = "/usr"
clang_version = "%{clang_major}"
use_sysroot = false
use_remoteexec = false
use_siso = false
use_custom_libcxx = false
clang_use_chrome_plugins = false
pdf_enable_v8 = false
pdf_enable_xfa = false
pdf_use_skia = false
pdf_enable_fontations = false
pdf_enable_rust_png = false
pdf_use_partition_alloc = false
pdf_is_standalone = false
pdf_is_complete_lib = false
pdf_bundle_freetype = false
use_system_freetype = true
use_system_libjpeg = true
use_system_libopenjpeg2 = true
use_system_lcms2 = true
use_system_libpng = true
use_system_libtiff = true
use_system_zlib = true
EOF

gn gen out/Release
ninja -C out/Release pdfium

%check
test -f out/Release/libpdfium.so.146
test -f out/Release/libpdfium_absl.so.146
test -f out/Release/libpdfium_icuuc.so.146
readelf -h out/Release/libpdfium.so.146 | grep -Eq 'Machine:.*%{expected_elf_machine}'
grep -Fq -- '--target=%{fedora_clang_target}' out/Release/obj/pdfium.ninja
grep -Fq '/usr/lib/clang/%{clang_major}/lib/%{fedora_clang_target}/libclang_rt.builtins.a' \
  out/Release/obj/pdfium.ninja
nm -D --defined-only out/Release/libpdfium.so.146 | grep -q ' FPDF_InitLibrary'
nm -D --defined-only out/Release/libpdfium.so.146 | grep -q ' FPDF_DestroyLibrary'
readelf -d out/Release/libpdfium.so.146 | grep -q 'Library soname: \[libpdfium.so.146\]'
readelf -d out/Release/libpdfium.so.146 | grep -q 'Shared library: \[libpdfium_absl.so.146\]'
readelf -d out/Release/libpdfium.so.146 | grep -q 'Shared library: \[libpdfium_icuuc.so.146\]'
test ! -e out/Release/icudtl.dat
# ICU's generated data symbol has no ELF size, but its defined symbol proves
# that the data object was linked into the private component library.
nm --defined-only out/Release/libpdfium_icuuc.so.146 | grep -Eq '^[0-9a-fA-F]+ [RrDd] icudt[0-9]+_dat$'

cat > out/Release/pdfium-smoke.c <<'EOF'
#include <fpdfview.h>

int main(void) {
  FPDF_InitLibrary();
  FPDF_DestroyLibrary();
  return 0;
}
EOF

%{__cc} -Ipublic out/Release/pdfium-smoke.c \
  out/Release/libpdfium.so.146 -Wl,-rpath,"$PWD/out/Release" \
  -o out/Release/pdfium-smoke
out/Release/pdfium-smoke

%install
install -Dpm0755 out/Release/libpdfium.so.146 \
  %{buildroot}%{_libdir}/libpdfium.so.146
install -Dpm0755 out/Release/libpdfium_absl.so.146 \
  %{buildroot}%{_libdir}/libpdfium_absl.so.146
install -Dpm0755 out/Release/libpdfium_icuuc.so.146 \
  %{buildroot}%{_libdir}/libpdfium_icuuc.so.146
ln -s libpdfium.so.146 %{buildroot}%{_libdir}/libpdfium.so
install -d %{buildroot}%{_includedir}/pdfium
cp -a public/*.h %{buildroot}%{_includedir}/pdfium/

install -d %{buildroot}%{_licensedir}/%{name}
install -Dpm0644 LICENSE \
  %{buildroot}%{_licensedir}/%{name}/LICENSE.pdfium
install -Dpm0644 third_party/icu/LICENSE \
  %{buildroot}%{_licensedir}/%{name}/LICENSE.icu
install -Dpm0644 %{SOURCE5} \
  %{buildroot}%{_licensedir}/%{name}/AGG-LICENSE.txt
install -Dpm0644 %{SOURCE6} \
  %{buildroot}%{_licensedir}/%{name}/THIRD-PARTY-NOTICES.txt

install -d %{buildroot}%{_libdir}/pkgconfig
cat > %{buildroot}%{_libdir}/pkgconfig/pdfium.pc <<EOF
prefix=%{_prefix}
exec_prefix=\${prefix}
libdir=%{_libdir}
includedir=%{_includedir}/pdfium

Name: pdfium
Description: Chromium PDFium PDF library
Version: %{version}
Libs: -L\${libdir} -lpdfium
Cflags: -I\${includedir}
EOF

%files
%license %{_licensedir}/%{name}/LICENSE.pdfium
%license %{_licensedir}/%{name}/LICENSE.icu
%license %{_licensedir}/%{name}/AGG-LICENSE.txt
%license %{_licensedir}/%{name}/THIRD-PARTY-NOTICES.txt
%doc README.md
%{_libdir}/libpdfium.so.146
%{_libdir}/libpdfium_absl.so.146
%{_libdir}/libpdfium_icuuc.so.146

%files devel
%{_includedir}/pdfium/
%{_libdir}/libpdfium.so
%{_libdir}/pkgconfig/pdfium.pc

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 146.0.7678.0-0.0.4
- Record successful Fedora 43 and 44 aarch64 COPR proof in the source policy.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 146.0.7678.0-0.0.3
- Add native aarch64 target and compiler-rt handling for the COPR proof draft.
- Verify the generated target triple, compiler-rt path, and ELF architecture.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 146.0.7678.0-0.0.2
- Document downstream patch status and the private library boundary.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 146.0.7678.0-0.0.1
- Add a blocked deterministic source-closure draft for the Chromium-pinned PDFium revision.
- Drop an unused simdutf dependency from the unbuilt embedder-test target.
- Use Fedora's x86_64 Clang target triple and compiler-rt layout.
- Give bundled Abseil and ICU component libraries collision-free PDFium names.
- Use SHA-1 build IDs compatible with RPM build-id links.
- Give PDFium and its private components versioned Fedora SONAMEs.
- Embed ICU data in the private ICU component and install complete notices.
