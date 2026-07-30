%global crate tree-sitter
%global source_sha256 5168a515fe492af54c5cc8800ff8c840be09fa5168de45838afaecd3e008bce4
%global license_sha256 5f9cf9fb6acb1972b35ae29119ce563bb60ec097656bc4b69b9bac2d04c7a147
%bcond check 0

Name:           rust-tree-sitter0.25.2
Version:        0.25.2
Release:        0.2%{?dist}
Summary:        Rust bindings to the tree-sitter incremental parsing library

# Upstream bundles the tree-sitter C library and ICU-derived Unicode sources.
License:        MIT AND Unicode-DFS-2016 AND BSD-2-Clause AND BSD-3-Clause AND LicenseRef-Fedora-Public-Domain
URL:            https://crates.io/crates/tree-sitter
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Source1:        https://raw.githubusercontent.com/tree-sitter/tree-sitter/v%{version}/LICENSE

# Fedora-specific metadata adaptation based on Fedora's tree-sitter 0.25
# compatibility package: keep the aggregate license, remove the unselected
# wasm/wasmtime edge, and require Fedora's bindgen branch.
Patch0:         tree-sitter-fix-metadata.diff
# Fedora-specific: always regenerate the Rust bindings from the bundled C
# headers so the package does not rely on upstream generated bindings.
Patch1:         tree-sitter-build-bindings-unconditionally.patch
# Fedora-specific: use the declared package MSRV directly instead of invoking
# Cargo recursively from the build script.
Patch2:         tree-sitter-bindgen-rust-version.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Rust bindings to the tree-sitter incremental parsing library. This exact
compatibility branch is required by Headroom 0.33.0.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch
# The crate contains a bundled copy of the tree-sitter C library.
Provides:       bundled(tree-sitter) = %{version}
# The tree-sitter C library contains a small subset of ICU 65.1 sources.
Provides:       bundled(icu) = 65.1

%description    devel %{_description}

This package contains library source intended for building other Rust packages.

%files          devel
%license %{crate_instdir}/LICENSE
%license %{crate_instdir}/src/unicode/LICENSE
%{cargo_registry}/%{crate}-%{version_no_tilde}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+default-devel %{_description}

This package contains library source for the default feature of the
"%{crate}" crate.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+std-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+std-devel %{_description}

This package contains library source for the std feature of the
"%{crate}" crate.

%files       -n %{name}+std-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{license_sha256}  %{SOURCE1}" | sha256sum -c -
%setup -q -n %{crate}-%{version_no_tilde}
%patch -P 0 -p1
%patch -P 1 -p1
%patch -P 2 -p1
install -pm0644 %{SOURCE1} LICENSE
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build

%install
%cargo_install
install -pm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE

%check
test "$(cargo2rpm --path Cargo.toml provides --feature default)" = "crate(tree-sitter/default) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature std)" = "crate(tree-sitter/std) = %{version}"

%if %{with check}
%cargo_test
%endif

%changelog
* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 0.25.2-0.2
- Install the separately sourced upstream license in the crate payload.

* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 0.25.2-0.1
- Add the exact tree-sitter compatibility branch required by Headroom 0.33.0.
