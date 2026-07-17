# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate tower-lsp-server
%global source_sha256 2f0e711655c89181a6bc6a2cc348131fcd9680085f5b06b6af13427a393a6e72

Name:           rust-tower-lsp-server0.23
Version:        0.23.0
Release:        0.1%{?dist}
Summary:        Language Server Protocol implementation based on Tower

License:        MIT OR Apache-2.0
URL:            https://crates.io/crates/tower-lsp-server
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Language Server Protocol implementation based on Tower.}

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
%doc %{crate_instdir}/CODE_OF_CONDUCT.md
%doc %{crate_instdir}/CONTRIBUTING.md
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

%package     -n %{name}+async-codec-lite-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+async-codec-lite-devel %{_description}

This package contains library source intended for building other packages which
use the "async-codec-lite" feature of the "%{crate}" crate.

%files       -n %{name}+async-codec-lite-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+proposed-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+proposed-devel %{_description}

This package contains library source intended for building other packages which
use the "proposed" feature of the "%{crate}" crate.

%files       -n %{name}+proposed-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+runtime-agnostic-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+runtime-agnostic-devel %{_description}

This package contains library source intended for building other packages which
use the "runtime-agnostic" feature of the "%{crate}" crate.

%files       -n %{name}+runtime-agnostic-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+runtime-tokio-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+runtime-tokio-devel %{_description}

This package contains library source intended for building other packages which
use the "runtime-tokio" feature of the "%{crate}" crate.

%files       -n %{name}+runtime-tokio-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+tokio-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+tokio-devel %{_description}

This package contains library source intended for building other packages which
use the "tokio" feature of the "%{crate}" crate.

%files       -n %{name}+tokio-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+tokio-util-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+tokio-util-devel %{_description}

This package contains library source intended for building other packages which
use the "tokio-util" feature of the "%{crate}" crate.

%files       -n %{name}+tokio-util-devel
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.23.0-0.1
- Add the compatibility crate required by ast-grep.
