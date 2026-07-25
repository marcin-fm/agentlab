# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate minimad
%global source_sha256 df8b688969b16915f3ecadc7829d5b7779dee4977e503f767f34136803d5c06f

Name:           rust-minimad0.14
Version:        0.14.0
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

%package     -n %{name}+escaping-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+escaping-devel %{_description}
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.14.0-0.1
- Add the compatibility crate required by termimad 0.34.1.
