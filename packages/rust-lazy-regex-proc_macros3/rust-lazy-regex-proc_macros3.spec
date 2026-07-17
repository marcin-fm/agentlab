# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate lazy-regex-proc_macros
%global source_sha256 4ba01db5ef81e17eb10a5e0f2109d1b3a3e29bac3070fdbd7d156bf7dbd206a1

Name:           rust-lazy-regex-proc_macros3
Version:        3.4.1
Release:        0.1%{?dist}
Summary:        Proc macros for the lazy-regex crate

License:        MIT
URL:            https://crates.io/crates/lazy-regex-proc_macros
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# The proc-macro crate omits the matching workspace license file.
Source1:        LICENSE.mit

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Procedural macros for the lazy-regex crate.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch
%description    devel %{_description}
%files          devel
%license %{crate_instdir}/LICENSE
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+default-devel %{_description}
%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build

%install
%cargo_install
install -Dpm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE

%if %{with check}
%check
%cargo_test -- --lib
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 3.4.1-0.1
- Add the exact proc-macro crate required by lazy-regex 3.4.1.
- Restore the matching workspace MIT license text omitted from the crate.
- Run library tests only; copied parent-crate documentation is not standalone.
