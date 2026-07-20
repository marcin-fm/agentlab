# Disabled by package.yml pending release-boundary approval. The private
# ABI/runtime boundary is accepted for the current package. Source0 is generated
# and attested by GitHub Actions from the official Chromium lite archive, then
# verified by bytes and exact tree here.
%global source_tag pdfium-sources-%{version}-pdfium-efbbd0fc9582
%global source_sha256 c7dc7e87a0ab457d9088e1215cdd54da3ebd941b9d77f38b1a7e9c8606cb2b75
%global source_size 70932985
%global source_receipt_sha256 3cb1431401f8beb33c138d5918a349376cc34d094c2360e46c3efe4ae4ef3573
%global source_policy_sha256 9ff235c6e1046ee586def0a3bcba89ef19ed7097053d1c451d7350bc4f7df5d7
%global source_preparer_sha256 d0ffbd3024ce88bdf902d4e47ef30c8a856952f10c6f9b54b17b11559116cb02
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
Release:        0.0.7%{?dist}
Summary:        PDF rendering library used by Chromium

License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND MIT AND NAIST-2003 AND Unicode-3.0 AND LicenseRef-Fedora-Public-Domain
URL:            https://pdfium.googlesource.com/pdfium/
Source0:        https://github.com/marcin-fm/agentlab/releases/download/%{source_tag}/pdfium-%{version}-source.tar.gz
Source1:        pdfium-%{version}-source-receipt.json
Source2:        source-closure.yml
Source3:        prepare-pdfium-srpm-sources
Source4:        AGG-LICENSE.txt
Source5:        THIRD-PARTY-NOTICES.txt
# Drop simdutf and test-font dependencies from targets omitted by Fedora's reduced build.
# Fedora-specific; not submitted because Fedora does not build those test surfaces.
Patch0:         pdfium-drop-simdutf-test-dependency.patch
# Select Fedora's Clang target/runtime layouts and omit two bundled-Clang-only flags.
# Fedora-specific; the feature-detection removal follows Fedora Chromium policy.
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
BuildRequires:  ruby
BuildRequires:  ruby-default-gems
BuildRequires:  rubygem-json
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
test "$(stat -c %%s %{SOURCE0})" = "%{source_size}"
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{source_receipt_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{source_policy_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{source_preparer_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{agg_license_sha256}  %{SOURCE4}" | sha256sum -c -
echo "%{third_party_notices_sha256}  %{SOURCE5}" | sha256sum -c -
TMPDIR=%{_tmppath} ruby %{SOURCE3} --output %{SOURCE0} --receipt %{SOURCE1} --check
%setup -q -n pdfium-%{version}
patch --batch --fuzz=0 -p1 < %{PATCH0}
patch --batch --fuzz=0 -p1 < %{PATCH1}
patch --batch --fuzz=0 -p1 < %{PATCH2}
patch --batch --fuzz=0 -p1 < %{PATCH3}
patch --batch --fuzz=0 -p1 < %{PATCH4}
patch --batch --fuzz=0 -p1 < %{PATCH5}

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
install -Dpm0644 %{SOURCE4} \
  %{buildroot}%{_licensedir}/%{name}/AGG-LICENSE.txt
install -Dpm0644 %{SOURCE5} \
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
* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 146.0.7678.0-0.0.7
- Record acceptance of the private PDFium ABI and embedded ICU runtime boundary.
- Validate the hosted source through an authorized primary COPR configured-SCM build.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 146.0.7678.0-0.0.6
- Consume the deterministic PDFium source closure from an immutable, attested GitHub release.
- Verify both Source0 transport identity and its exact selected source tree without build-time networking.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 146.0.7678.0-0.0.5
- Generate one checked Source0 from Chromium's official lite archive at SCM SRPM time.
- Remove bundled buildtools binaries and unused test-font sources.
- Adapt Chromium's release build files to Fedora Clang 22.

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
