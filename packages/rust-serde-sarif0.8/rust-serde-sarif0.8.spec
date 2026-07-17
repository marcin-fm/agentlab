# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate serde-sarif
%global source_sha256 a053c46f18a8043570d4e32fefc4c6377f82bf29ec310a33e93f273048e3b0be

Name:           rust-serde-sarif0.8
Version:        0.8.0
Release:        0.1%{?dist}
Summary:        Serde serialization for SARIF files

License:        MIT
URL:            https://crates.io/crates/serde-sarif
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Patch0:         serde-sarif-fix-builder-doctest.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Serde serialization for SARIF files.}

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

%package     -n %{name}+anyhow-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+anyhow-devel %{_description}

This package contains library source intended for building other packages which
use the "anyhow" feature of the "%{crate}" crate.

%files       -n %{name}+anyhow-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+cargo_metadata-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+cargo_metadata-devel %{_description}

This package contains library source intended for building other packages which
use the "cargo_metadata" feature of the "%{crate}" crate.

%files       -n %{name}+cargo_metadata-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+clang-tidy-converters-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+clang-tidy-converters-devel %{_description}

This package contains library source intended for building other packages which
use the "clang-tidy-converters" feature of the "%{crate}" crate.

%files       -n %{name}+clang-tidy-converters-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+clippy-converters-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+clippy-converters-devel %{_description}

This package contains library source intended for building other packages which
use the "clippy-converters" feature of the "%{crate}" crate.

%files       -n %{name}+clippy-converters-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+hadolint-converters-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+hadolint-converters-devel %{_description}

This package contains library source intended for building other packages which
use the "hadolint-converters" feature of the "%{crate}" crate.

%files       -n %{name}+hadolint-converters-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+miri-converters-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+miri-converters-devel %{_description}

This package contains library source intended for building other packages which
use the "miri-converters" feature of the "%{crate}" crate.

%files       -n %{name}+miri-converters-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+once_cell-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+once_cell-devel %{_description}

This package contains library source intended for building other packages which
use the "once_cell" feature of the "%{crate}" crate.

%files       -n %{name}+once_cell-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+opt-builder-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+opt-builder-devel %{_description}

This package contains library source intended for building other packages which
use the "opt-builder" feature of the "%{crate}" crate.

%files       -n %{name}+opt-builder-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+regex-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+regex-devel %{_description}

This package contains library source intended for building other packages which
use the "regex" feature of the "%{crate}" crate.

%files       -n %{name}+regex-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+shellcheck-converters-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+shellcheck-converters-devel %{_description}

This package contains library source intended for building other packages which
use the "shellcheck-converters" feature of the "%{crate}" crate.

%files       -n %{name}+shellcheck-converters-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires -f opt-builder

%build
%cargo_build -f opt-builder

%install
%cargo_install

%if %{with check}
%check
%cargo_test -f opt-builder
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.8.0-0.1
- Add the compatibility crate required by ast-grep.
