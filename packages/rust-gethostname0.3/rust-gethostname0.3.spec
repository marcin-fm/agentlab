# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate gethostname
%global source_sha256 bb65d4ba3173c56a500b555b532f72c42e8d1fe64962b518897f8959fae2c177

Name:           rust-gethostname0.3
Version:        0.3.0
Release:        0.1%{?dist}
Summary:        Gethostname for all platforms

License:        Apache-2.0
URL:            https://crates.io/crates/gethostname
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Patch0:         gethostname-fix-metadata-auto.diff

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  hostname

%global _description %{expand:
Gethostname implementation for Rust applications.}

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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.3.0-0.1
- Add the exact compatibility crate required by x11rb 0.12.0.
- Remove the Windows-only dependency from the Fedora build graph.
- Add the hostname command required by the upstream test suite.
