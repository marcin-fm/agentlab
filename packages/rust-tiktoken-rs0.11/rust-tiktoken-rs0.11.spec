# Generated with rust2rpm 28 and reviewed by Marcin FM.
%bcond check 1
%global debug_package %{nil}

%global crate tiktoken-rs
%global source_sha256 fac4a168cfc1d8ed65bf17a6ee0843ad9a68f863c63c0fb2fa7eab67838782ee
%global license_sha256 f7c6ddf9d84fd7b8ad5917e4074d4c05e4c1dfb752a28a0058f06bd0f5e2edcc
%global openai_license_sha256 418cb499b436128d653d79941333a5437b7be2ea9213dcc2f04d15d5d2c51d86
%global cl100k_sha256 223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7
%global o200k_sha256 446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d
%global p50k_sha256 94b5ca7dff4d00767bc256fdd1b27e5b17361d7b8a5f968547f9f23eb70d2069
%global r50k_sha256 306cd27f03c1a714eca7108e03d66b7dc042abe8c258b44c199a7ed9838dd930

Name:           rust-tiktoken-rs0.11
Version:        0.11.0
Release:        0.2%{?dist}
Summary:        OpenAI-compatible byte pair tokenizer for Rust

License:        MIT
URL:            https://crates.io/crates/tiktoken-rs
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
Source1:        https://raw.githubusercontent.com/zurawiki/tiktoken-rs/b1151970e4ae250b01352a80281c097e4a1c0cc5/LICENSE#/tiktoken-rs-LICENSE
Source2:        https://raw.githubusercontent.com/openai/tiktoken/eedc856364506a9d4651645a0290eb0ba81e6935/LICENSE#/openai-tiktoken-LICENSE

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Byte pair encoding library compatible with OpenAI tokenizers.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other packages which
use the "%{crate}" crate.

%files          devel
%license %{crate_instdir}/LICENSE
%license %{crate_instdir}/OPENAI-LICENSE
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

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{license_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{openai_license_sha256}  %{SOURCE2}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1
echo "%{cl100k_sha256}  assets/cl100k_base.tiktoken" | sha256sum -c -
echo "%{o200k_sha256}  assets/o200k_base.tiktoken" | sha256sum -c -
echo "%{p50k_sha256}  assets/p50k_base.tiktoken" | sha256sum -c -
echo "%{r50k_sha256}  assets/r50k_base.tiktoken" | sha256sum -c -
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build

%install
%cargo_install
install -Dpm0644 %{SOURCE1} %{buildroot}%{crate_instdir}/LICENSE
install -Dpm0644 %{SOURCE2} %{buildroot}%{crate_instdir}/OPENAI-LICENSE

%if %{with check}
%check
%cargo_test
%endif

%changelog
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.11.0-0.2
- Retain the exact tokenizer branch required by Headroom 0.32.0.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.11.0-0.1
- Add the exact tokenizer crate required by Headroom 0.31.0.
- Restore the project and vendored OpenAI MIT license texts.
