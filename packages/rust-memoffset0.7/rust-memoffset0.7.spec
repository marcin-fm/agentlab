# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate memoffset
%global source_sha256 5de893c32cde5f383baa4c04c5d6dbdd735cfd4a794b0debdb2bb1b421da5ff4

Name:           rust-memoffset0.7
Version:        0.7.1
Release:        0.1%{?dist}
Summary:        Offset_of functionality for Rust structs

License:        MIT
URL:            https://crates.io/crates/memoffset
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Offset_of functionality for Rust structs.}

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

This package contains library source intended for building other packages which
use the "default" feature of the "%{crate}" crate.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+unstable_const-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+unstable_const-devel %{_description}

This package contains library source intended for building other packages which
use the "unstable_const" feature of the "%{crate}" crate.

%files       -n %{name}+unstable_const-devel
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
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.7.1-0.1
- Add the Rawhide compatibility crate required by nix 0.26 socket support.
