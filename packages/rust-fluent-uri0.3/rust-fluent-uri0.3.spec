# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate fluent-uri
%global source_sha256 1918b65d96df47d3591bed19c5cca17e3fa5d0707318e4b5ef2eae01764df7e5

Name:           rust-fluent-uri0.3
Version:        0.3.2
Release:        0.1%{?dist}
Summary:        Generic URI and IRI handling library

License:        MIT
URL:            https://crates.io/crates/fluent-uri
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
A generic URI and IRI handling library compliant with RFC 3986 and RFC 3987.}

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

%package     -n %{name}+net-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+net-devel %{_description}
%files       -n %{name}+net-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+serde-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+serde-devel %{_description}
%files       -n %{name}+serde-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+std-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+std-devel %{_description}
%files       -n %{name}+std-devel
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.3.2-0.1
- Add the compatibility crate required by ls-types 0.0.2.
