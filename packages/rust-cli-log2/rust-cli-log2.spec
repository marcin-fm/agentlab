# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate cli-log
%global source_sha256 e220aa46e5395cd473a054f8e7e52403108ce147a4eb68c001afb01672a4e046

Name:           rust-cli-log2
Version:        2.1.0
Release:        0.1%{?dist}
Summary:        Environment-configured logging and timing facility

License:        MIT
URL:            https://crates.io/crates/cli-log
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Patch0:         cli-log-fix-doctest.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
An environment-configured logging and timing facility.}

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
%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+file-size-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+file-size-devel %{_description}
%files       -n %{name}+file-size-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+mem-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+mem-devel %{_description}
%files       -n %{name}+mem-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+proc-status-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+proc-status-devel %{_description}
%files       -n %{name}+proc-status-devel
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.1
- Add the compatibility crate required by termimad 0.34.
