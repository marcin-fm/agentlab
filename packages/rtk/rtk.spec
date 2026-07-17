%global crate rtk
%global source_sha256 196bec9e9b438f0b8cd0198f68e05f072ccdfdec2c2655a3562d6ea357fa485b

Name:           rtk
Version:        0.43.0
Release:        0.3%{?dist}
Summary:        CLI proxy that reduces command output sent to language models

License:        Apache-2.0 AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib
URL:            https://github.com/rtk-ai/rtk
Source0:        https://github.com/rtk-ai/rtk/archive/refs/tags/v%{version}.tar.gz
Source1:        collect-cargo-licenses.py
# Link RTK against Fedora system SQLite instead of compiling rusqlite's bundled copy.
# Upstream support is proposed in https://github.com/rtk-ai/rtk/pull/2404; Fedora selects it unconditionally.
Patch0:         rtk-use-system-sqlite.patch

BuildRequires:  cargo-rpm-macros
BuildRequires:  binutils
BuildRequires:  git-core
BuildRequires:  python3
BuildRequires:  sqlite-devel

%description
RTK filters and compresses command output before it reaches an AI coding
agent, reducing repetitive context while preserving actionable failures.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build_crate

%check
%cargo_test
readelf -d target/rpm/%{name} | grep -q 'libsqlite3.so.0'
RTK_TELEMETRY_DISABLED=1 RTK_DB_PATH="$PWD/rtk-smoke.db" \
  target/rpm/%{name} proxy true >/dev/null
test -s rtk-smoke.db

%install
%cargo_install
install -Dpm0644 LICENSE.dependencies \
  %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies
python3 %{SOURCE1} \
  --inventory %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies \
  --registry /usr/share/cargo/registry \
  --output %{buildroot}%{_licensedir}/%{name}/THIRD-PARTY-LICENSES \
  --closure-output %{buildroot}%{_licensedir}/%{name}/CARGO-PROVIDERS.tsv

%files
%license LICENSE
%license %{_licensedir}/%{name}/LICENSE.dependencies
%license %{_licensedir}/%{name}/CARGO-PROVIDERS.tsv
%license %{_licensedir}/%{name}/THIRD-PARTY-LICENSES
%doc README.md
%{_bindir}/rtk

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.3
- Document the system-SQLite patch purpose and upstream status.

* Thu Jul 16 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.2
- Add fail-closed collection of full linked-crate license evidence.
- Retain the exact resolved Cargo crate to Fedora provider mapping.
- Validate current Fedora 43 and Fedora 44 builds and artifact receipts.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.1
- Complete clean Fedora 43 and Fedora 44 source builds.
- Use system SQLite and include the linked Rust dependency license inventory.

* Tue Jul 14 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.0.1
- Add an initial Fedora source-build draft using system SQLite.
