# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate inquire
%global source_sha256 6654738b8024300cf062d04a1c13c10c8e2cea598ec1c47dc9b6641159429756
%global license_sha256 f72340c0a3886a23409003bddfd1aeab6c64acd128582ef4436e1ad5ae2033c8

Name:           rust-inquire0.9
Version:        0.9.4
Release:        0.1%{?dist}
Summary:        Inquire is a library for building interactive prompts on terminals

License:        MIT
URL:            https://crates.io/crates/inquire
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Source1:        https://raw.githubusercontent.com/mikaelmello/inquire/v%{version}/LICENSE#/%{crate}-%{version}-LICENSE

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Inquire is a library for building interactive prompts on terminals.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE
%doc %{crate_instdir}/CRATE_README.md
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+default-devel %{_description}

This package contains library source intended for building other packages which
use the "default" feature of the "%{crate}" crate.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+chrono-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+chrono-devel %{_description}

This package contains library source intended for building other packages which
use the "chrono" feature of the "%{crate}" crate.

%files       -n %{name}+chrono-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+console-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+console-devel %{_description}

This package contains library source intended for building other packages which
use the "console" feature of the "%{crate}" crate.

%files       -n %{name}+console-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+crossterm-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+crossterm-devel %{_description}

This package contains library source intended for building other packages which
use the "crossterm" feature of the "%{crate}" crate.

%files       -n %{name}+crossterm-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+date-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+date-devel %{_description}

This package contains library source intended for building other packages which
use the "date" feature of the "%{crate}" crate.

%files       -n %{name}+date-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+editor-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+editor-devel %{_description}

This package contains library source intended for building other packages which
use the "editor" feature of the "%{crate}" crate.

%files       -n %{name}+editor-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+experimental-multiline-input-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+experimental-multiline-input-devel %{_description}

This package contains library source intended for building other packages which
use the "experimental-multiline-input" feature of the "%{crate}" crate.

%files       -n %{name}+experimental-multiline-input-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+fuzzy-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+fuzzy-devel %{_description}

This package contains library source intended for building other packages which
use the "fuzzy" feature of the "%{crate}" crate.

%files       -n %{name}+fuzzy-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+fuzzy-matcher-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+fuzzy-matcher-devel %{_description}

This package contains library source intended for building other packages which
use the "fuzzy-matcher" feature of the "%{crate}" crate.

%files       -n %{name}+fuzzy-matcher-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+macros-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+macros-devel %{_description}

This package contains library source intended for building other packages which
use the "macros" feature of the "%{crate}" crate.

%files       -n %{name}+macros-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+one-liners-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+one-liners-devel %{_description}

This package contains library source intended for building other packages which
use the "one-liners" feature of the "%{crate}" crate.

%files       -n %{name}+one-liners-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+tempfile-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+tempfile-devel %{_description}

This package contains library source intended for building other packages which
use the "tempfile" feature of the "%{crate}" crate.

%files       -n %{name}+tempfile-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+termion-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+termion-devel %{_description}

This package contains library source intended for building other packages which
use the "termion" feature of the "%{crate}" crate.

%files       -n %{name}+termion-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{license_sha256}  %{SOURCE1}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build

%install
%cargo_install
install -Dpm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE

%if %{with check}
%check
%cargo_test
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.9.4-0.1
- Add the compatibility crate required by ast-grep.
- Restore the MIT license file omitted from the published crate archive.
