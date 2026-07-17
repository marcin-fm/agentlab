# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate async-tungstenite
%global source_sha256 8acc405d38be14342132609f06f02acaf825ddccfe76c4824a69281e0458ebd4

Name:           rust-async-tungstenite0.32
Version:        0.32.1
Release:        0.1%{?dist}
Summary:        Async bindings for the Tungstenite WebSocket library

License:        MIT
URL:            https://crates.io/crates/async-tungstenite
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Async bindings for the Tungstenite stream-based WebSocket library.}

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
%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+futures-03-sink-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+futures-03-sink-devel %{_description}
%files       -n %{name}+futures-03-sink-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+futures-util-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+futures-util-devel %{_description}
%files       -n %{name}+futures-util-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+handshake-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+handshake-devel %{_description}
%files       -n %{name}+handshake-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+tokio-runtime-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+tokio-runtime-devel %{_description}
%files       -n %{name}+tokio-runtime-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+tokio-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+tokio-devel %{_description}
%files       -n %{name}+tokio-devel
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.32.1-0.1
- Add the compatibility crate required by tower-lsp-server 0.23.
