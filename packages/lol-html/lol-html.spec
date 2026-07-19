%bcond check 1

%global c_api_version 1.4.0
%global source_sha256 41ed4231fd05b1c73c0664f1f05f18b0d96a34aabf488e6cb601c3bdc7306af9
%global vendor_sha256 55da2f37159c90797e8ddeb81535c31067a1b1f884f0de2779dd17467279639f
%global vendor_manifest_sha256 7888d3e9abab58ad0a218f12896337a9288e98fed840f36a6842c03ecba00d65
%global license_dependencies_sha256 cd8b5eec2634147c47f82a6b3a5eeb95893f18ab84ddcad983189346f9a0329a
%global license_payload_sha256 4c92aaab2bc59e6d1634ef5f3f4351ed7403999dc22ef2e9914aeb4d3537b429
%global source_helper_sha256 7c61b27f8affd806a69e3bf62f6eda3f9e4ae17978339e6b493ff2292ebbc919
%global source_receipt_sha256 2f34f8e89868cef2eb84377bbdf3f83ee438cb0b6ed280ec0c677432320779fa
%global license_patch_sha256 03b853b37f75dbd8c35f3c8a920163c198c45ad6cca1b6f819f9d85c960a6594

Name:           lol-html
Version:        3.0.0
Release:        0.7%{?dist}
Summary:        Streaming HTML parser and transformation C library

License:        BSD-3-Clause AND (Apache-2.0 OR MIT) AND MIT AND MPL-2.0 AND (Unlicense OR MIT) AND Zlib
URL:            https://github.com/cloudflare/lol-html
Source0:        https://github.com/cloudflare/lol-html/archive/refs/tags/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
# Generated during repository-backed SRPM construction from c-api/Cargo.lock.
Source1:        %{name}-%{version}-cargo-vendor.tar.gz
Source2:        prepare-lol-html-srpm-sources
Source3:        %{name}-%{version}-cargo-vendor.json
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
echo "%{vendor_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{source_helper_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{source_receipt_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{license_patch_sha256}  %{PATCH0}" | sha256sum -c -
%autosetup -n lol-html-%{version} -p1
echo "11a173c126f925a466a2554925207c377c6ba78863dd8f0a5f31a0bb46b78e8e  c-api/Cargo.toml" | sha256sum -c -
echo "4fbb6a7b50b9e139fe44a8c652d6acbcbd4f93f2f127cf7b85b59dc5b59705ec  c-api/Cargo.lock" | sha256sum -c -
echo "7fe574ddaad36931ee4d72a43c0cf375e3b697b94ab4c137fe58d8643c402293  c-api/include/lol_html.h" | sha256sum -c -
tar --extract --gzip --file %{SOURCE1} --directory c-api
pushd c-api >/dev/null
%cargo_prep -v vendor
test "$(find vendor -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 43
popd >/dev/null

%build
pushd c-api >/dev/null
%{__cargo} cbuild %{__cargo_common_opts} \
  --profile rpm \
  --locked \
  --offline \
  --library-type cdylib
%{cargo_license_summary}
%{cargo_license} > ../LICENSE.dependencies
ruby-mri -e 'path = ARGV.fetch(0); text = File.read(path); changed = text.sub!(/^BSD-3-Clause: lol_html v3\.0\.0 .*$/, "BSD-3-Clause: lol_html v3.0.0"); abort "missing local lol_html license record" unless changed; File.write(path, text)' ../LICENSE.dependencies
echo "%{license_dependencies_sha256}  ../LICENSE.dependencies" | sha256sum -c -
%cargo_vendor_manifest
ruby-mri -e 'path = ARGV.fetch(0); text = File.read(path); changed = text.sub!(/^lol_html v3\.0\.0 \([^\n]+\)$/, "lol_html v3.0.0"); abort "missing local lol_html vendor record" unless changed; File.write(path, text)' cargo-vendor.txt
echo "%{vendor_manifest_sha256}  cargo-vendor.txt" | sha256sum -c -
test "$(wc -l < cargo-vendor.txt)" -eq 41
cp -p cargo-vendor.txt ..
ruby-mri <<'RUBY'
require "digest"
require "fileutils"

entries = File.readlines("../LICENSE.dependencies", chomp: true).filter_map do |line|
  match = line.match(/\A[^:]+: ([A-Za-z0-9_-]+) v([^ ]+)/)
  match && [match[1], match[2]]
end
linked = entries.reject { |name, _version| ["lol_html", "lol_html_c_api"].include?(name) }.uniq.sort
abort "unexpected linked dependency count" unless linked.length == 27

payload = "../LICENSES.dependencies"
FileUtils.rm_rf(payload)
FileUtils.mkdir_p(payload)
manifest = []

linked.each do |name, version|
  source = File.join("vendor", "#{name}-#{version}")
  abort "missing linked dependency source #{source}" unless File.directory?(source)
  files = Dir.children(source).grep(/\A(?:LICENSE|COPYING|NOTICE)(?:[._-]|\z)/i).sort

  if name == "selectors" && version == "0.37.0"
    abort "unexpected selectors license file" unless files.empty?
    rust_sources = Dir.glob(File.join(source, "**", "*.rs")).select { |path| File.file?(path) }
    abort "missing selectors source files" if rust_sources.empty?
    abort "selectors source lacks MPL notice" unless rust_sources.all? do |path|
      text = File.read(path, 256)
      text.include?("Mozilla Public") && text.include?("https://mozilla.org/MPL/2.0/")
    end
    next
  end

  abort "missing license files for #{name} v#{version}" if files.empty?
  files.each do |file|
    source_file = File.join(source, file)
    digest = Digest::SHA256.file(source_file).hexdigest
    destination = File.join(payload, "#{digest}.txt")
    if File.exist?(destination)
      abort "license payload collision for #{digest}" unless Digest::SHA256.file(destination).hexdigest == digest
    else
      FileUtils.cp(source_file, destination, preserve: true)
    end
    source_relative = File.join("#{name}-#{version}", file)
    manifest << "#{digest}  #{source_relative} => #{digest}.txt"
  end
end

File.write("../LICENSES.dependencies.manifest", manifest.join("\n") + "\n")
RUBY
test "$(find ../LICENSES.dependencies -type f | wc -l)" -eq 28
echo "%{license_payload_sha256}  ../LICENSES.dependencies.manifest" | sha256sum -c -
popd >/dev/null

%install
pushd c-api >/dev/null
%{__cargo} cinstall %{__cargo_common_opts} \
  --profile rpm \
  --locked \
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
%license LICENSE LICENSE.dependencies LICENSES.dependencies LICENSES.dependencies.manifest cargo-vendor.txt
%doc README.md
%{_libdir}/liblolhtml.so.1
%{_libdir}/liblolhtml.so.%{c_api_version}

%files devel
%doc README.md
%{_includedir}/lol_html.h
%{_libdir}/liblolhtml.so
%{_libdir}/pkgconfig/lol-html.pc

%changelog
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
