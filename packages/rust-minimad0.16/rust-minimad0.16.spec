# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate minimad
%global source_sha256 de632ee829aec3a874d18a4192eae64a0460b3a45c54ed556b334f6fe5a1d62f

Name:           rust-minimad0.16
Version:        0.16.0
Release:        0.1%{?dist}
Summary:        Light Markdown parser

License:        MIT
URL:            https://crates.io/crates/minimad
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Light Markdown parser.}

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

%package     -n %{name}+escaping-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+escaping-devel %{_description}

This package contains library source intended for building other packages which
use the "escaping" feature of the "%{crate}" crate.

%files       -n %{name}+escaping-devel
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
* Fri Jul 24 2026 Marcin FM <marcin@lgic.pl> - 0.16.0-0.1
- Add the compatibility crate required by termimad 0.35.
