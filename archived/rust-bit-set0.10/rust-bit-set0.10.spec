# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate bit-set
%global source_sha256 09ec2f926cc3060f09db9ebc5b52823d85268d24bb917e472c0c4bea35780a7d

Name:           rust-bit-set0.10
Version:        0.10.0
Release:        0.1%{?dist}
Summary:        Set of bits

License:        Apache-2.0 OR MIT
URL:            https://crates.io/crates/bit-set
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
A set of bits.}

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
%doc %{crate_instdir}/README.md
%doc %{crate_instdir}/RELEASES.md
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+default-devel %{_description}

This package contains library source intended for building other packages which
use the "default" feature of the "%{crate}" crate.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+borsh-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+borsh-devel %{_description}

This package contains library source intended for building other packages which
use the "borsh" feature of the "%{crate}" crate.

%files       -n %{name}+borsh-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+borsh_std-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+borsh_std-devel %{_description}

This package contains library source intended for building other packages which
use the "borsh_std" feature of the "%{crate}" crate.

%files       -n %{name}+borsh_std-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+miniserde-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+miniserde-devel %{_description}

This package contains library source intended for building other packages which
use the "miniserde" feature of the "%{crate}" crate.

%files       -n %{name}+miniserde-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+nanoserde-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+nanoserde-devel %{_description}

This package contains library source intended for building other packages which
use the "nanoserde" feature of the "%{crate}" crate.

%files       -n %{name}+nanoserde-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+serde-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+serde-devel %{_description}

This package contains library source intended for building other packages which
use the "serde" feature of the "%{crate}" crate.

%files       -n %{name}+serde-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+serde_no_std-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+serde_no_std-devel %{_description}

This package contains library source intended for building other packages which
use the "serde_no_std" feature of the "%{crate}" crate.

%files       -n %{name}+serde_no_std-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+serde_std-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+serde_std-devel %{_description}

This package contains library source intended for building other packages which
use the "serde_std" feature of the "%{crate}" crate.

%files       -n %{name}+serde_std-devel
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
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.10.0-0.1
- Add the compatibility crate required by ast-grep.
