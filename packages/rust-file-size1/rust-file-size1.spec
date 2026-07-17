# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate file-size
%global source_sha256 9544f10105d33957765016b8a9baea7e689bf1f0f2f32c2fa2f568770c38d2b3

Name:           rust-file-size1
Version:        1.0.3
Release:        0.1%{?dist}
Summary:        Function formatting file sizes in four characters

License:        MIT
URL:            https://crates.io/crates/file-size
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# The published crate declares MIT but omits the license file.
Source1:        LICENSE.mit

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
A function formatting file sizes in four characters.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE
%doc %{crate_instdir}/README.md
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
%cargo_test
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.0.3-0.1
- Add the compatibility crate required by cli-log 2.
- Restore the MIT license text omitted from the published crate.
