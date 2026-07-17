# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate ls-types
%global source_sha256 896e16b8e17d8732b9efe4d5b66cb0cc162b3023a2d8122f2aea6f7f185e0a67

Name:           rust-ls-types0.0.6
Version:        0.0.6
Release:        0.1%{?dist}
Summary:        Types for the Language Server Protocol specification

License:        MIT
URL:            https://crates.io/crates/ls-types
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Types for the Language Server Protocol specification.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE
%doc %{crate_instdir}/CHANGELOG.md
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

%if %{with check}
%check
%cargo_test
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.0.6-0.1
- Add the exact semver-zero compatibility crate required by ast-grep 0.44.1.
