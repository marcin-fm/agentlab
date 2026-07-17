# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate lazy-regex
%global source_sha256 60c7310b93682b36b98fa7ea4de998d3463ccbebd94d935d6b48ba5b6ffa7126

Name:           rust-lazy-regex3
Version:        3.4.1
Release:        0.1%{?dist}
Summary:        Lazy static regular expressions checked at compile time

License:        MIT
URL:            https://crates.io/crates/lazy-regex
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Lazy static regular expressions checked at compile time.}

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

%package     -n %{name}+regex-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+regex-devel %{_description}
%files       -n %{name}+regex-devel
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 3.4.1-0.1
- Add the compatibility crate required by termimad 0.34.1.
