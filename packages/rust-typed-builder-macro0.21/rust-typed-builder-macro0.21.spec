# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate typed-builder-macro
%global source_sha256 1ecb9ecf7799210407c14a8cfdfe0173365780968dc57973ed082211958e0b18

Name:           rust-typed-builder-macro0.21
Version:        0.21.2
Release:        0.1%{?dist}
Summary:        Compile-time type-checked builder derive implementation

License:        MIT OR Apache-2.0
URL:            https://crates.io/crates/typed-builder-macro
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Implementation crate for the typed-builder derive macro.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE-APACHE
%license %{crate_instdir}/LICENSE-MIT
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.21.2-0.1
- Add the exact macro crate required by typed-builder 0.21.2.
