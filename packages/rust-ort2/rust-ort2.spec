# Curated for Kreuzberg's system-ONNX Runtime feature surface.
%bcond check 1
%global debug_package %{nil}

%global crate ort
%global crate_version 2.0.0-rc.12
%global source_sha256 d7de3af33d24a745ffb8fab904b13478438d1cd52868e6f17735ef6e1f8bf133

Name:           rust-ort2
Version:        2.0.0~rc.12
Release:        0.4%{?dist}
Summary:        Safe Rust wrapper for ONNX Runtime
License:        MIT OR Apache-2.0
URL:            https://crates.io/crates/ort
Source:         https://static.crates.io/crates/%{crate}/%{crate}-%{crate_version}.crate
# Select Fedora's available ndarray 0.16 compatibility branch.
# Fedora-specific; not submitted upstream because the released crate selects ndarray 0.17.
Patch:          ort-fedora-ndarray.diff
# Adapt the optimization-level enum to Fedora's system ONNX Runtime API.
# Fedora-specific system-library compatibility change; not submitted upstream.
Patch1:         ort-system-onnxruntime.diff

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  pkgconfig(libonnxruntime) >= 1.18

%global _description %{expand:
A safe Rust wrapper for ONNX Runtime, built against Fedora's system ONNX
Runtime with the Kreuzberg feature surface.}

%description %{_description}

%package devel
Summary:        %{summary}
BuildArch:      noarch

%description devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files devel
%license %{crate_instdir}/LICENSE-APACHE
%license %{crate_instdir}/LICENSE-MIT
%doc %{crate_instdir}/README.md
%{crate_instdir}/

%package -n %{name}+api-17-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+api-17-devel %{_description}

This package contains library source intended for building other packages which
use the "api-17" feature of the "%{crate}" crate.

%files -n %{name}+api-17-devel
%ghost %{crate_instdir}/Cargo.toml

%package -n %{name}+api-18-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+api-18-devel %{_description}

This package contains library source intended for building other packages which
use the "api-18" feature of the "%{crate}" crate.

%files -n %{name}+api-18-devel
%ghost %{crate_instdir}/Cargo.toml

%package -n %{name}+std-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+std-devel %{_description}

This package contains library source intended for building other packages which
use the "std" feature of the "%{crate}" crate.

%files -n %{name}+std-devel
%ghost %{crate_instdir}/Cargo.toml

%package -n %{name}+ndarray-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+ndarray-devel %{_description}

This package contains library source intended for building other packages which
use the "ndarray" feature of the "%{crate}" crate.

%files -n %{name}+ndarray-devel
%ghost %{crate_instdir}/Cargo.toml

%package -n %{name}+preload-dylibs-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+preload-dylibs-devel %{_description}

This package contains library source intended for building other packages which
use the "preload-dylibs" feature of the "%{crate}" crate.

%files -n %{name}+preload-dylibs-devel
%ghost %{crate_instdir}/Cargo.toml

%package -n %{name}+load-dynamic-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+load-dynamic-devel %{_description}

This package contains library source intended for building other packages which
use the "load-dynamic" feature of the "%{crate}" crate.

%files -n %{name}+load-dynamic-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{crate_version} -p1
%cargo_prep

%generate_buildrequires
export ORT_OFFLINE=1
export ORT_SKIP_DOWNLOAD=1
%cargo_generate_buildrequires -n -f api-18,load-dynamic,ndarray,std

%build
export ORT_OFFLINE=1
export ORT_SKIP_DOWNLOAD=1
%cargo_build -n -f api-18,load-dynamic,ndarray,std

%install
%cargo_install -n -f api-18,load-dynamic,ndarray,std

%if %{with check}
%check
export ORT_OFFLINE=1
export ORT_SKIP_DOWNLOAD=1
export ORT_DYLIB_PATH=%{_libdir}/libonnxruntime.so
%cargo_test -n -f api-18,load-dynamic,ndarray,std -- --lib -- --skip operator::tests::test_custom_ops
%endif

%changelog
* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 2.0.0~rc.12-0.4
- Validate the system ONNX Runtime wrapper for publication.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 2.0.0~rc.12-0.3
- Use Fedora Cargo macros for dependency generation, build, install, and tests.

* Thu Jul 16 2026 Marcin FM <marcin@lgic.pl> - 2.0.0~rc.12-0.2
- Build the offline system-ONNX Runtime feature surface.
