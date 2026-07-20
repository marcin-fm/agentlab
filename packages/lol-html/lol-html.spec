%bcond check 1

%global c_api_version 1.4.0
%global source_sha256 41ed4231fd05b1c73c0664f1f05f18b0d96a34aabf488e6cb601c3bdc7306af9
%global license_patch_sha256 03b853b37f75dbd8c35f3c8a920163c198c45ad6cca1b6f819f9d85c960a6594

Name:           lol-html
Version:        3.0.0
Release:        0.9%{?dist}
Summary:        Streaming HTML parser and transformation C library

License:        BSD-3-Clause AND (Apache-2.0 OR MIT) AND MIT AND MPL-2.0 AND (Unlicense OR MIT) AND Zlib
URL:            https://github.com/cloudflare/lol-html
Source0:        https://github.com/cloudflare/lol-html/archive/refs/tags/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
# Record the root project's BSD license in the unpublished C API crate metadata.
# Fedora metadata correction; not yet submitted upstream.
Patch0:         lol-html-c-api-license.patch

BuildRequires:  binutils
BuildRequires:  cargo >= 1.89
BuildRequires:  cargo-c
BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  gcc
BuildRequires:  pkgconf-pkg-config
BuildRequires:  rust >= 1.89
BuildRequires:  ruby

%description
lol-html is a low-output-latency streaming HTML parser and transformation
engine. This package provides its stable C API as a versioned shared library.

%package devel
Summary:        Development files for lol-html
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description devel
The lol-html C header, linker name, and pkg-config metadata.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{license_patch_sha256}  %{PATCH0}" | sha256sum -c -
%autosetup -n lol-html-%{version} -p1
echo "11a173c126f925a466a2554925207c377c6ba78863dd8f0a5f31a0bb46b78e8e  c-api/Cargo.toml" | sha256sum -c -
echo "4fbb6a7b50b9e139fe44a8c652d6acbcbd4f93f2f127cf7b85b59dc5b59705ec  c-api/Cargo.lock" | sha256sum -c -
echo "7fe574ddaad36931ee4d72a43c0cf375e3b697b94ab4c137fe58d8643c402293  c-api/include/lol_html.h" | sha256sum -c -
pushd c-api >/dev/null
%cargo_prep
popd >/dev/null

%generate_buildrequires
%global lol_html_with_check %{?with_check}
%undefine with_check
%cargo_generate_buildrequires
%global with_check %{lol_html_with_check}
pushd c-api >/dev/null
%cargo_generate_buildrequires
popd >/dev/null

%build
pushd c-api >/dev/null
%{__cargo} cbuild %{__cargo_common_opts} \
  --profile rpm \
  --offline \
  --library-type cdylib
%{cargo_license_summary}
%{cargo_license} > ../LICENSE.dependencies
ruby-mri -e 'path = ARGV.fetch(0); text = File.read(path); changed = text.sub!(/^BSD-3-Clause: lol_html v3\.0\.0 .*$/, "BSD-3-Clause: lol_html v3.0.0"); abort "missing local lol_html license record" unless changed; File.write(path, text)' ../LICENSE.dependencies
popd >/dev/null

%install
pushd c-api >/dev/null
%{__cargo} cinstall %{__cargo_common_opts} \
  --profile rpm \
  --offline \
  --library-type cdylib \
  --destdir %{buildroot} \
  --prefix %{_prefix} \
  --libdir %{_libdir} \
  --includedir %{_includedir} \
  --pkgconfigdir %{_libdir}/pkgconfig
popd >/dev/null
test ! -e %{buildroot}%{_libdir}/liblolhtml.a

%if %{with check}
%check
library=%{buildroot}%{_libdir}/liblolhtml.so.%{c_api_version}
test -f "$library"
test "$(readlink %{buildroot}%{_libdir}/liblolhtml.so)" = "liblolhtml.so.%{c_api_version}"
test "$(readlink %{buildroot}%{_libdir}/liblolhtml.so.1)" = "liblolhtml.so.%{c_api_version}"
readelf -d "$library" | grep -Fq 'Library soname: [liblolhtml.so.1]'
! readelf -d "$library" | grep -Eq 'RPATH|RUNPATH'
test "$(nm -D --defined-only "$library" | grep -Ec ' (lol_html_|unstable_lol_html_)')" -eq 97
PKG_CONFIG_PATH=%{buildroot}%{_libdir}/pkgconfig pkg-config --exact-version=%{c_api_version} lol-html
grep -Fq 'graceful_bail_out_on_memory_limit_exceeded' %{buildroot}%{_includedir}/lol_html.h
cat > c-api-smoke.c <<'EOF'
#include <lol_html.h>

int main(void) {
    static const char selector_text[] = "div";
    lol_html_selector_t *selector = lol_html_selector_parse(selector_text, 3);
    if (selector == NULL) {
        return 1;
    }
    lol_html_selector_free(selector);
    return 0;
}
EOF
gcc %{build_cflags} -I%{buildroot}%{_includedir} c-api-smoke.c \
  -L%{buildroot}%{_libdir} -Wl,-rpath,%{buildroot}%{_libdir} -llolhtml \
  %{build_ldflags} -o c-api-smoke
LD_LIBRARY_PATH=%{buildroot}%{_libdir} ./c-api-smoke
cat > c-api-tests-main.c <<'EOF'
int run_tests(void);

int main(void) {
    return run_tests();
}
EOF
gcc %{build_cflags} -std=c99 -pthread \
  -Wcast-qual -Wwrite-strings -Wshadow -Winline \
  -Wdisabled-optimization -Wuninitialized -Wcast-align \
  -Wno-missing-field-initializers -Wno-address -Wall -Wextra -Werror \
  -Ic-api/include -Ic-api/c-tests/src -Ic-api/c-tests/src/deps/picotest \
  c-api/c-tests/src/deps/picotest/picotest.c c-api/c-tests/src/*.c \
  c-api-tests-main.c -L%{buildroot}%{_libdir} \
  -Wl,-rpath,%{buildroot}%{_libdir} -llolhtml %{build_ldflags} -o c-api-tests
LD_LIBRARY_PATH=%{buildroot}%{_libdir} ./c-api-tests
ldd -r "$library"
%endif

%files
%license LICENSE LICENSE.dependencies
%doc README.md
%{_libdir}/liblolhtml.so.1
%{_libdir}/liblolhtml.so.%{c_api_version}

%files devel
%doc README.md
%{_includedir}/lol_html.h
%{_libdir}/liblolhtml.so
%{_libdir}/pkgconfig/lol-html.pc

%changelog
* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.9
- Generate root dependency requirements through the standard Cargo macro.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.8
- Build against Fedora system crate packages instead of a vendor archive.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.7
- Invoke Fedora's versioned Ruby interpreter in package build phases.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.6
- Require Ruby for build-time manifest and license processing.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.5
- Deduplicate identical linked dependency license texts by content hash.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.4
- Run the complete upstream C suite against the shared library.
- Install the checked linked Rust dependency license payload.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.3
- Wrap the runtime description for package lint compliance.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.2
- Correct package wording and document the development subpackage.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 3.0.0-0.1
- Package the released C API as a versioned shared library for Bun.
