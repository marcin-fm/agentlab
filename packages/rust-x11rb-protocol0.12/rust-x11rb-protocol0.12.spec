# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate x11rb-protocol
%global source_sha256 82d6c3f9a0fb6701fab8f6cea9b0c0bd5d6876f1f89f7fada07e558077c344bc

Name:           rust-x11rb-protocol0.12
Version:        0.12.0
Release:        0.1%{?dist}
Summary:        Rust bindings to the X11 protocol

License:        MIT OR Apache-2.0
URL:            https://crates.io/crates/x11rb-protocol
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Patch0:         x11rb-protocol-drop-benchmark-dependency.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Rust bindings to the X11 protocol.}

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

%package     -n %{name}+nix-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+nix-devel %{_description}
%files       -n %{name}+nix-devel
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

%package     -n %{name}+std-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+std-devel %{_description}
%files       -n %{name}+std-devel
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.12.0-0.1
- Add the exact protocol crate required by x11-clipboard 0.8.1.
- Drop the benchmark-only criterion dependency from the package build graph.
