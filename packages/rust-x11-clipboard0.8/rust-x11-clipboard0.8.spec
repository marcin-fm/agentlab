# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate x11-clipboard
%global source_sha256 b41aca1115b1f195f21c541c5efb423470848d48143127d0f07f8b90c27440df

Name:           rust-x11-clipboard0.8
Version:        0.8.1
Release:        0.1%{?dist}
Summary:        X11 clipboard support for Rust

License:        MIT
URL:            https://crates.io/crates/x11-clipboard
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  xorg-x11-server-Xvfb

%global _description %{expand:
X11 clipboard support for Rust.}

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
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
xvfb_pid=$!
trap 'kill ${xvfb_pid}' EXIT
sleep 1
export DISPLAY=:99
%cargo_test
%endif

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.8.1-0.1
- Add the Linux clipboard dependency required by terminal-clipboard 0.4.1.
- Run the upstream X11 integration tests under Xvfb.
