# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate polling
%global source_sha256 4be1c66a6add46bff50935c313dae30a5030cf8385c5206e8a95e9e9def974aa

Name:           rust-polling2
Version:        2.7.0
Release:        0.2%{?dist}
Summary:        Portable interface to epoll, kqueue, event ports, and IOCP

License:        Apache-2.0 OR MIT
URL:            https://crates.io/crates/polling
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Remove Windows-only dependencies from Fedora's Unix build graph.
# Fedora-generated target pruning; not submitted because upstream supports Windows.
Patch0:         polling-fix-metadata-auto.diff

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Portable interface to epoll, kqueue, event ports, and IOCP.}

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
* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 2.7.0-0.2
- Record the intentional Rawhide-only target scope.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 2.7.0-0.1
- Add the Rawhide compatibility crate required by x11rb 0.12 tests.
- Remove Windows-only dependencies from the Unix build graph.
