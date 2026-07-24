# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate termimad
%global source_sha256 d53d4b1294b87e81925b7ae7f8f4d000376e3a5b3349d978429665428a793fcb

Name:           rust-termimad0.35
Version:        0.35.1
Release:        0.1%{?dist}
Summary:        Markdown Renderer for the Terminal

License:        MIT
URL:            https://crates.io/crates/termimad
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Markdown Renderer for the Terminal.}

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

This package contains library source intended for building other packages which
use the "default" feature of the "%{crate}" crate.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+special-renders-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+special-renders-devel %{_description}

This package contains library source intended for building other packages which
use the "special-renders" feature of the "%{crate}" crate.

%files       -n %{name}+special-renders-devel
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
* Fri Jul 24 2026 Marcin FM <marcin@lgic.pl> - 0.35.1-0.1
- Add the compatibility crate required by ast-grep 0.45.
