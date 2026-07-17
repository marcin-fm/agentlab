# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate tree-sitter-kotlin-sg
%global source_sha256 c06ec43ae3c12165d4ac08afe4e1f5fc6757ffe274fa7bd5af9007ef11ba4319

Name:           rust-tree-sitter-kotlin-sg0.4
Version:        0.4.1
Release:        0.1%{?dist}
Summary:        Kotlin grammar for the tree-sitter parsing library

License:        MIT
URL:            https://crates.io/crates/tree-sitter-kotlin-sg
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Patch0:         tree-sitter-kotlin-sg-fix-doctest.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Kotlin grammar for the tree-sitter parsing library.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+default-devel %{_description}

This package contains library source intended for building other packages which
use the "default" feature of the "%{crate}" crate.

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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.4.1-0.1
- Add the compatibility grammar crate required by ast-grep.
