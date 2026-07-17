# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate tungstenite
%global source_sha256 8628dcc84e5a09eb3d8423d6cb682965dea9133204e8fb3efee74c2a0c259442

Name:           rust-tungstenite0.28
Version:        0.28.0
Release:        0.1%{?dist}
Summary:        Lightweight stream-based WebSocket implementation

License:        MIT OR Apache-2.0
URL:            https://crates.io/crates/tungstenite
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Patch0:         tungstenite-drop-benchmark-dependency.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Lightweight stream-based WebSocket implementation.}

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
%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+data-encoding-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+data-encoding-devel %{_description}
%files       -n %{name}+data-encoding-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+handshake-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+handshake-devel %{_description}
%files       -n %{name}+handshake-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+http-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+http-devel %{_description}
%files       -n %{name}+http-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+httparse-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+httparse-devel %{_description}
%files       -n %{name}+httparse-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+sha1-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+sha1-devel %{_description}
%files       -n %{name}+sha1-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+url-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+url-devel %{_description}
%files       -n %{name}+url-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires -f url

%build
%cargo_build -f url

%install
%cargo_install

%if %{with check}
%check
%cargo_test -f url
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.28.0-0.1
- Add the Fedora 43 compatibility crate required by async-tungstenite 0.32.
