# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate tree-sitter-md
%global source_sha256 2efd398be546456c814598ee56c0f51769a77241511b4a58077815d120afa882
%global license_sha256 52ec8a1bf8256511e2a92613e0bb41ffefba3897f16fa958d7bb28c466dd4804

Name:           rust-tree-sitter-md0.5
Version:        0.5.3
Release:        0.1%{?dist}
Summary:        Markdown grammar for tree-sitter

License:        MIT
URL:            https://crates.io/crates/tree-sitter-md
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Source1:        https://raw.githubusercontent.com/tree-sitter-grammars/tree-sitter-markdown/v%{version}/LICENSE#/%{crate}-%{version}-LICENSE

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Markdown grammar for tree-sitter.}

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

%package     -n %{name}+parser-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+parser-devel %{_description}

This package contains library source intended for building other packages which
use the "parser" feature of the "%{crate}" crate.

%files       -n %{name}+parser-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{license_sha256}  %{SOURCE1}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires -f parser

%build
%cargo_build -f parser

%install
%cargo_install -f parser
install -Dpm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE
rm -f %{buildroot}%{_bindir}/benchmark

%if %{with check}
%check
%cargo_test -f parser
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.5.3-0.1
- Add the compatibility grammar crate required by ast-grep.
- Restore the MIT license file omitted from the published crate archive.
