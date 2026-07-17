# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate deser-hjson
%global source_sha256 7d94aac4095c08ded7e4b9ba7fc2b2929f11b94bb96897ca188b0f64e01688e1

Name:           rust-deser-hjson2
Version:        2.2.4
Release:        0.2%{?dist}
Summary:        Hjson deserializer for Serde

License:        MIT
URL:            https://crates.io/crates/deser-hjson
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Omit the benchmark-only glassbench dependency from Fedora's build and test graph.
# Fedora-specific; upstream retains the benchmark added in commit 2e5027d.
Patch0:         deser-hjson-drop-benchmark-dependency.patch

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Hjson deserializer for Serde.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch
%description    devel %{_description}
%files          devel
%license %{crate_instdir}/LICENSE
%doc %{crate_instdir}/README.md
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch
%description -n %{name}+default-devel %{_description}
%files       -n %{name}+default-devel
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
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.2.4-0.2
- Document the benchmark-only dependency patch and upstream status.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 2.2.4-0.1
- Add the compatibility crate required by termimad 0.34.1.
- Drop the benchmark-only glassbench dependency from the package build graph.
