# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate bit-vec
%global source_sha256 5727b15fa97d4f4fee0a3b7c3d550ed0269f54329207b86388de918604e31269

Name:           rust-bit-vec0.10
Version:        0.10.1
Release:        0.1%{?dist}
Summary:        Vector of bits

License:        Apache-2.0 OR MIT
URL:            https://crates.io/crates/bit-vec
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Fedora-specific: retain only the default/std surface selected by bit-set and
# omit unselected serialization features, optional dependencies, and metadata.
# Not submitted upstream because this is a distribution feature selection.
Patch0:         bit-vec-selected-features.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
A vector of bits.}

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
* Fri Jul 24 2026 Marcin FM <marcin@lgic.pl> - 0.10.1-0.1
- Add the compatibility crate required by bit-set 0.11.
- Limit the package to the selected default and std feature surface.
