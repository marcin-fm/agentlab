# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate unidiff
%global source_sha256 e3ae26d2e6582eb32eff85cffebf74d20b6510e8b558bbac3a23b48965cf952f

Name:           rust-unidiff0.4
Version:        0.4.0
Release:        0.1%{?dist}
Summary:        Unified diff parsing and metadata extraction library for Rust

License:        MIT
URL:            https://crates.io/crates/unidiff
Source0:        %{crates_source}

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Unified diff parsing and metadata extraction library for Rust.}

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

This package contains library source intended for building other packages which
use the "default" feature of the "%{crate}" crate.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+encoding-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+encoding-devel %{_description}

This package contains library source intended for building other packages which
use the "encoding" feature of the "%{crate}" crate.

%files       -n %{name}+encoding-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+unstable-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+unstable-devel %{_description}

This package contains library source intended for building other packages which
use the "unstable" feature of the "%{crate}" crate.

%files       -n %{name}+unstable-devel
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
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.4.0-0.1
- Add the initial Fedora package.
