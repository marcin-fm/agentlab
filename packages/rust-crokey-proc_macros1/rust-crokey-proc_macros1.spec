# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate crokey-proc_macros
%global source_sha256 3bf1a727caeb5ee5e0a0826a97f205a9cf84ee964b0b48239fef5214a00ae439

Name:           rust-crokey-proc_macros1
Version:        1.3.0
Release:        0.1%{?dist}
Summary:        Procedural macros for the crokey crate

License:        MIT
URL:            https://crates.io/crates/crokey-proc_macros
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Exact workspace license shipped by the sibling crokey 1.3.0 crate.
Source1:        LICENSE.mit

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Procedural macros for the crokey crate.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch
%description    devel %{_description}
%files          devel
%license %{crate_instdir}/LICENSE
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
install -Dpm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE

%if %{with check}
%check
%cargo_test
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.3.0-0.1
- Add the exact proc-macro crate required by crokey 1.3.0.
- Restore the workspace MIT license omitted from the published crate.
