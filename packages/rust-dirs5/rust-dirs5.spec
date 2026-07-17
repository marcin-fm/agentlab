# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}
%global crate dirs
%global source_sha256 44c45a9d03d6676652bcb5e724c7e988de1acad23a711b5217ab9cbecbec2225

Name:           rust-dirs5
Version:        5.0.1
Release:        0.2%{?dist}
Summary:        Standard directory locations for Rust applications

License:        MIT OR Apache-2.0
URL:            https://crates.io/crates/dirs
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Platform-specific standard locations for configuration, cache, and data files.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building Rust packages that
use the dirs crate.

%files          devel
%license %{crate_instdir}/LICENSE-APACHE
%license %{crate_instdir}/LICENSE-MIT
%doc %{crate_instdir}/README.md
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+default-devel %{_description}

This package contains library source for the default feature of dirs.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{version}
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
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 5.0.1-0.2
- Expand COPR targets to Fedora 44 and Rawhide on x86_64 and aarch64.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 5.0.1-0.1
- Add the Fedora 44 compatibility crate required by RTK.
