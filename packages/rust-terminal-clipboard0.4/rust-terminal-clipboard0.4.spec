# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate terminal-clipboard
%global source_sha256 4e0fd8cb5cf744b501e657eb27df7909ff917eacbfee34bc4bb13d4e6411a131

Name:           rust-terminal-clipboard0.4
Version:        0.4.1
Release:        0.2%{?dist}
Summary:        Minimal cross-platform clipboard

License:        MIT
URL:            https://crates.io/crates/terminal-clipboard
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# The published crate declares MIT but omits the license file.
Source1:        LICENSE.mit
# Fedora-only: omit Android, macOS, and Windows crates from the Linux build graph.
# Not a backport; upstream release and current main retain those target dependencies:
# https://github.com/Canop/terminal-clipboard/commit/f00647c1189c44a2510818ca31108a143b49c173
Patch0:         terminal-clipboard-fix-metadata-auto.diff

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Minimal cross-platform clipboard.}

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
install -Dpm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE

%if %{with check}
%check
%cargo_test
%endif

%changelog
* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 0.4.1-0.2
- Document the Fedora patch purpose and upstream status.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.4.1-0.1
- Add the compatibility crate required by termimad 0.34.1.
- Remove foreign target dependencies and restore the omitted MIT license text.
