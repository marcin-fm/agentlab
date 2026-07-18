# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate nix
%global source_sha256 598beaf3cc6fdd9a5dfb1630c2800c7acd31df7aaf0f565796fba2b53ca1af1b

Name:           rust-nix0.26
Version:        0.26.4
Release:        0.2%{?dist}
Summary:        Rust friendly bindings to Unix APIs

License:        MIT
URL:            https://crates.io/crates/nix
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Remove a FreeBSD-only test dependency from Fedora's Linux build graph.
# Fedora-generated target pruning; not submitted because upstream supports FreeBSD.
Patch0:         nix-fix-metadata-auto.diff

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Rust friendly bindings to Unix APIs.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE
%doc %{crate_instdir}/CHANGELOG.md
%doc %{crate_instdir}/README.md
%{crate_instdir}/

%package     -n %{name}+fs-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+fs-devel %{_description}

This package contains library source intended for building other packages which
use the "fs" feature of the "%{crate}" crate.

%files       -n %{name}+fs-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+memoffset-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+memoffset-devel %{_description}

This package contains library source intended for building other packages which
use the "memoffset" feature of the "%{crate}" crate.

%files       -n %{name}+memoffset-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+poll-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+poll-devel %{_description}

This package contains library source intended for building other packages which
use the "poll" feature of the "%{crate}" crate.

%files       -n %{name}+poll-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+socket-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+socket-devel %{_description}

This package contains library source intended for building other packages which
use the "socket" feature of the "%{crate}" crate.

%files       -n %{name}+socket-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+uio-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+uio-devel %{_description}

This package contains library source intended for building other packages which
use the "uio" feature of the "%{crate}" crate.

%files       -n %{name}+uio-devel
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
# Fedora also excludes the AF_ALG cipher test as hardware-dependent and the
# queue-accounting assertion because it is flaky.
# The kmod and process-accounting tests require host kernel build files or
# privileges that are intentionally unavailable inside Mock.
%{cargo_test -- -- %{shrink:
    --skip sys::test_socket::test_af_alg_cipher
    --skip sys::test_socket::test_recvmsg_rxq_ovfl
    --skip test_kmod::test_delete_module_not_loaded
    --skip test_kmod::test_finit_and_delete_module
    --skip test_kmod::test_finit_and_delete_module_with_params
    --skip test_kmod::test_finit_module_invalid
    --skip test_kmod::test_finit_module_twice_and_delete_module
    --skip test_kmod::test_init_and_delete_module
    --skip test_kmod::test_init_and_delete_module_with_params
    --skip test_unistd::test_acct
}}
%endif

%changelog
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.26.4-0.2
- Skip the hardware-dependent AF_ALG cipher test excluded by Fedora.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.26.4-0.1
- Add the Rawhide compatibility crate required by x11rb 0.12.
- Remove a FreeBSD-only test dependency from the Linux build graph.
- Skip only the tests that are flaky or require unavailable Mock privileges.
