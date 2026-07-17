# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate atty
%global source_sha256 d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8

Name:           rust-atty0.2
Version:        0.2.14
Release:        0.2%{?dist}
Summary:        Simple interface for querying atty

License:        MIT
URL:            https://crates.io/crates/atty
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Remove Hermit and Windows-only dependencies from Fedora's Unix build graph.
# Fedora-generated target pruning; not submitted because upstream supports those platforms.
Patch:          atty-fix-metadata-auto.diff

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
A simple interface for querying atty.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE
%doc %{crate_instdir}/CHANGELOG.md
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
# The crate's unit tests require all three standard streams to be attached to a
# TTY, which is not true in mock. Keep the portable doctests enabled.
%cargo_test -- --doc
%endif

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.2.14-0.2
- Document Fedora target pruning and its upstream status.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.2.14-0.1
- Add the Fedora 44 compatibility crate required by ast-grep.
