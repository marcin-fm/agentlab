# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate fancy-regex
%global source_sha256 72cf461f865c862bb7dc573f643dd6a2b6842f7c30b07882b56bd148cc2761b8

Name:           rust-fancy-regex0.17
Version:        0.17.0
Release:        0.2%{?dist}
Summary:        Regular expression engine with backreferences and look-around

License:        MIT
URL:            https://crates.io/crates/fancy-regex
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Regular expression engine supporting backreferences and look-around.}

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

%package     -n %{name}+perf-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+perf-devel %{_description}

This package contains library source intended for building other packages which
use the "perf" feature of the "%{crate}" crate.

%files       -n %{name}+perf-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+std-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+std-devel %{_description}

This package contains library source intended for building other packages which
use the "std" feature of the "%{crate}" crate.

%files       -n %{name}+std-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+track_caller-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+track_caller-devel %{_description}

This package contains library source intended for building other packages which
use the "track_caller" feature of the "%{crate}" crate.

%files       -n %{name}+track_caller-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+unicode-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+unicode-devel %{_description}

This package contains library source intended for building other packages which
use the "unicode" feature of the "%{crate}" crate.

%files       -n %{name}+unicode-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+variable-lookbehinds-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+variable-lookbehinds-devel %{_description}

This package contains library source intended for building other packages which
use the "variable-lookbehinds" feature of the "%{crate}" crate.

%files       -n %{name}+variable-lookbehinds-devel
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
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.17.0-0.2
- Retain the blocked draft for Headroom 0.32.0 exact tokenization.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.17.0-0.1
- Add the compatibility crate required by tiktoken-rs 0.11.
