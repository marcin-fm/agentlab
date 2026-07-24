# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate bit-set
%global source_sha256 56d87354e4229f54a44f7bf2435906a4656dba36026ab6eaca629a2c436a691c

Name:           rust-bit-set0.11
Version:        0.11.1
Release:        0.1%{?dist}
Summary:        Set of bits

License:        Apache-2.0 OR MIT
URL:            https://crates.io/crates/bit-set
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Fedora-specific: retain only the default/std surface selected by ast-grep and
# omit unselected serialization features, optional dependencies, and benchmarks.
# Not submitted upstream because this is a distribution feature selection.
Patch0:         bit-set-selected-features.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
A set of bits.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE-APACHE
%license %{crate_instdir}/LICENSE-MIT
%doc %{crate_instdir}/README.md
%doc %{crate_instdir}/RELEASES.md
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+default-devel %{_description}

This package contains library source intended for building other packages which
use the "default" feature of the "%{crate}" crate.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+std-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+std-devel %{_description}

This package contains library source intended for building other packages which
use the "std" feature of the "%{crate}" crate.

%files       -n %{name}+std-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires -n -f std

%build
%cargo_build -n -f std

%install
%cargo_install -n -f std

%if %{with check}
%check
%cargo_test -n -f std
%endif

%changelog
* Fri Jul 24 2026 Marcin FM <marcin@lgic.pl> - 0.11.1-0.1
- Add the compatibility crate required by ast-grep 0.45.
- Limit the package to the selected default and std feature surface.
