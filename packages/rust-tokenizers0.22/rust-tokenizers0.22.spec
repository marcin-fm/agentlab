# Adapted from Fedora rust-tokenizers 0.22.2-5.
%bcond check 1
%global debug_package %{nil}

%global crate tokenizers
%global source_sha256 b238e22d44a15349529690fb07bd645cf58149a1b1e44d6cb5bd1641ff1a6223

Name:           rust-tokenizers0.22
Version:        0.22.2
Release:        0.1%{?dist}
Summary:        Implementation of widely used tokenizers in Rust

License:        Apache-2.0
URL:            https://crates.io/crates/tokenizers
Source0:        https://static.crates.io/crates/%{crate}/%{crate}-%{version}.crate
# Fedora-specific metadata adaptation from rust-tokenizers 0.22.2-5:
# widen compatible dependency branches, select Fedora onig, and omit the
# benchmark-only Criterion dependency. Upstream fancy-regex widening is tracked
# at https://github.com/huggingface/tokenizers/pull/1940.
Patch0:         tokenizers-fix-metadata.diff

BuildRequires:  cargo-rpm-macros >= 24

%global _description %{expand:
Implementation of widely used tokenizers with a focus on performance and
versatility. This compatibility branch is selected by Headroom 0.33.0 on
Fedora Rawhide.}

%description %{_description}

%package        devel
Summary:        %{summary}
BuildArch:      noarch

%description    devel %{_description}

This package contains library source intended for building other Rust packages.

%files          devel
%license %{crate_instdir}/LICENSE
%doc %{crate_instdir}/CHANGELOG.md
%doc %{crate_instdir}/README.md
%{crate_instdir}/

%package     -n %{name}+default-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+default-devel %{_description}

This package contains library source for the default feature.

%files       -n %{name}+default-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+esaxx_fast-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+esaxx_fast-devel %{_description}

This package contains library source for the esaxx_fast feature.

%files       -n %{name}+esaxx_fast-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+fancy-regex-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+fancy-regex-devel %{_description}

This package contains library source for the fancy-regex feature.

%files       -n %{name}+fancy-regex-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+hf-hub-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+hf-hub-devel %{_description}

This package contains library source for the hf-hub feature.

%files       -n %{name}+hf-hub-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+http-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+http-devel %{_description}

This package contains library source for the http feature.

%files       -n %{name}+http-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+indicatif-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+indicatif-devel %{_description}

This package contains library source for the indicatif feature.

%files       -n %{name}+indicatif-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+onig-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+onig-devel %{_description}

This package contains library source for the onig feature.

%files       -n %{name}+onig-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+progressbar-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+progressbar-devel %{_description}

This package contains library source for the progressbar feature.

%files       -n %{name}+progressbar-devel
%ghost %{crate_instdir}/Cargo.toml

%package     -n %{name}+rustls-tls-devel
Summary:        %{summary}
BuildArch:      noarch

%description -n %{name}+rustls-tls-devel %{_description}

This package contains library source for the rustls-tls feature.

%files       -n %{name}+rustls-tls-devel
%ghost %{crate_instdir}/Cargo.toml

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%setup -q -n %{crate}-%{version}
%patch -P 0 -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build

%install
%cargo_install

%check
test "$(cargo2rpm --path Cargo.toml provides --feature default)" = "crate(tokenizers/default) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature esaxx_fast)" = "crate(tokenizers/esaxx_fast) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature fancy-regex)" = "crate(tokenizers/fancy-regex) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature hf-hub)" = "crate(tokenizers/hf-hub) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature http)" = "crate(tokenizers/http) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature indicatif)" = "crate(tokenizers/indicatif) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature onig)" = "crate(tokenizers/onig) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature progressbar)" = "crate(tokenizers/progressbar) = %{version}"
test "$(cargo2rpm --path Cargo.toml provides --feature rustls-tls)" = "crate(tokenizers/rustls-tls) = %{version}"

%if %{with check}
# Match Fedora's selected test surface: omitted upstream repositories/data and
# the known flaky unigram sample are not required to prove the packaged crate.
%cargo_test -- --doc -- --skip 926
%{cargo_test -- --test added_tokens -- --exact %{shrink:
    --skip lstrip_tokens
    --skip overlapping_tokens
    --skip rstrip_tokens
    --skip single_word_tokens
}}
%cargo_test -- --test from_pretrained
%{cargo_test -- --test serialization -- --exact %{shrink:
    --skip bpe_serde
    --skip test_deserialize_long_file
    --skip wordlevel_serde
    --skip wordpiece_serde
}}
%endif

%changelog
* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 0.22.2-0.1
- Add the Rawhide compatibility branch selected by Headroom 0.33.0.
