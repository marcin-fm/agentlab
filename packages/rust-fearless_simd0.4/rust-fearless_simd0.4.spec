# Generated from the current Linebender fearless_simd 0.4.1 crate.
%bcond check 1
%global debug_package %{nil}

%global crate fearless_simd
%global source_sha256 b97b65636e5b9ef369943878ac74335ba1c55c1cb6adbf1e2c293c624248d693

Name:           rust-fearless_simd0.4
Version:        0.4.1
Release:        0.1%{?dist}
Summary:        Safer and easier portable SIMD interface

License:        Apache-2.0 OR MIT
URL:            https://crates.io/crates/fearless_simd
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
A safer and easier interface for portable SIMD vector types.}

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

%package     -n %{name}+force_support_fallback-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+force_support_fallback-devel %{_description}

This package contains library source intended for building other packages which
use the "force_support_fallback" feature of the "%{crate}" crate.

%files       -n %{name}+force_support_fallback-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+libm-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+libm-devel %{_description}

This package contains library source intended for building other packages which
use the "libm" feature of the "%{crate}" crate.

%files       -n %{name}+libm-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+safe_wrappers-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+safe_wrappers-devel %{_description}

This package contains library source intended for building other packages which
use the "safe_wrappers" feature of the "%{crate}" crate.

%files       -n %{name}+safe_wrappers-devel
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
* Thu Jul 23 2026 Marcin FM <marcin@lgic.pl> - 0.4.1-0.1
- Package the current Linebender crate for Fedora 43 Hayro builds.
