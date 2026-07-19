# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate cssparser
%global source_sha256 dae61cf9c0abb83bd659dab65b7e4e38d8236824c85f0f804f173567bda257d2

Name:           rust-cssparser0.36
Version:        0.36.0
Release:        0.1%{?dist}
Summary:        Rust implementation of CSS Syntax Level 3

License:        MPL-2.0
URL:            https://crates.io/crates/cssparser
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Rust implementation of CSS Syntax Level 3.}

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

%package     -n %{name}+bench-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+bench-devel %{_description}

This package contains library source intended for building other packages which
use the "bench" feature of the "%{crate}" crate.

%files       -n %{name}+bench-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+dummy_match_byte-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+dummy_match_byte-devel %{_description}

This package contains library source intended for building other packages which
use the "dummy_match_byte" feature of the "%{crate}" crate.

%files       -n %{name}+dummy_match_byte-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+serde-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+serde-devel %{_description}

This package contains library source intended for building other packages which
use the "serde" feature of the "%{crate}" crate.

%files       -n %{name}+serde-devel
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
# The crate intentionally omits its large upstream fixture corpus.
# https://github.com/servo/rust-cssparser/issues/213
%cargo_test -- --doc
%endif

%changelog
* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 0.36.0-0.1
- Add the compatibility crate required by selectors 0.37.
