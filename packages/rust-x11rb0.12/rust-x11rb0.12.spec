# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate x11rb
%global source_sha256 b1641b26d4dec61337c35a1b1aaf9e3cba8f46f0b43636c609ab0291a648040a

Name:           rust-x11rb0.12
Version:        0.12.0
Release:        0.2%{?dist}
Summary:        Rust bindings to X11

License:        MIT OR Apache-2.0
URL:            https://crates.io/crates/x11rb
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Fedora-only: omit Windows-only winapi dependencies from the Linux build graph.
# Not an exact backport; upstream removed them only in a broader rustix port:
# https://github.com/psychon/x11rb/commit/fff41699d3a73439c62c3e22f90ff5d4d34fb0ce
Patch0:         x11rb-fix-metadata-auto.diff

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Rust bindings to X11.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch
%description    devel %{_description}
%files          devel
%license %{crate_instdir}/LICENSE-APACHE
%license %{crate_instdir}/LICENSE-MIT
%doc %{crate_instdir}/README.md
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+default-devel %{_description}
%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+render-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+render-devel %{_description}
%files       -n %{name}+render-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+shape-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+shape-devel %{_description}
%files       -n %{name}+shape-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+xfixes-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+xfixes-devel %{_description}
%files       -n %{name}+xfixes-devel
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
* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 0.12.0-0.2
- Document the Fedora patch purpose and upstream status.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.12.0-0.1
- Add the exact X11 crate required by x11-clipboard 0.8.1.
- Remove Windows-only dependencies from the Fedora build graph.
