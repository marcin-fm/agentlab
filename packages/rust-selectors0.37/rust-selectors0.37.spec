# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate selectors
%global source_sha256 2cfaaa6035167f0e604e42723c7650d59ee269ef220d7bbe0565602c8a0173b9

Name:           rust-selectors0.37
Version:        0.37.0
Release:        0.1%{?dist}
Summary:        CSS Selectors matching for Rust

License:        MPL-2.0
URL:            https://crates.io/crates/selectors
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
CSS Selectors matching for Rust.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
# Upstream supplies no standalone license file; MPL-2.0 notices are embedded in
# the installed Rust source.
%doc %{crate_instdir}/CHANGES.md
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

%package     -n %{name}+bench-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+bench-devel %{_description}

This package contains library source intended for building other packages which
use the "bench" feature of the "%{crate}" crate.

%files       -n %{name}+bench-devel
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
* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 0.37.0-0.1
- Add the compatibility crate required by lol-html 3.0.0.
