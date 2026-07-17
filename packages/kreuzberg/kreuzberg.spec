# Disabled by package.yml until the source-hosting, license, architecture, and
# final clean-build gates are complete.
%global source_sha256 2bd9c13744a8105b469c7b0d68d6574e9d29ccd8fa08f2bb93261aa058f17108
%global node_wrapper_sha256 44e344738f22c6d864046e14fd5a04c63f4f1451a6275934410bfa1f428f4025

Name:           kreuzberg
Version:        4.10.2
Release:        0.0.1%{?dist}
Summary:        Document intelligence toolkit and Node bindings

License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CC0-1.0 AND CDLA-Permissive-2.0 AND ISC AND LicenseRef-Fedora-Public-Domain AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Unlicense AND WTFPL AND Zlib AND bzip2-1.0.6
URL:            https://github.com/kreuzberg-dev/kreuzberg-lts
Source0:        https://github.com/kreuzberg-dev/kreuzberg-lts/archive/refs/tags/v%{version}.tar.gz
Source1:        https://registry.npmjs.org/@kreuzberg/node/-/node-%{version}.tgz
Source2:        kreuzberg-node-wrapper-fedora.patch
Source3:        collect-cargo-licenses.py
Patch0:         kreuzberg-system-libraries.patch
Patch1:         kreuzberg-node-workspace.patch
Patch2:         kreuzberg-native-targets.patch
Patch3:         kreuzberg-fedora-crates.patch
Patch4:         kreuzberg-fedora-runtime.patch
Patch5:         kreuzberg-system-tesseract.patch
Patch6:         kreuzberg-node-no-ffi-artifacts.patch
Patch7:         kreuzberg-ctor-features.patch
Patch8:         kreuzberg-node-no-napi-type-def.patch

ExclusiveArch:  x86_64 aarch64

BuildRequires:  cargo-rpm-macros
BuildRequires:  clang-devel
BuildRequires:  chrpath
BuildRequires:  gcc-c++
BuildRequires:  nodejs >= 22
BuildRequires:  nodejs-devel >= 22
BuildRequires:  nodejs-packaging
BuildRequires:  pkgconfig(libonnxruntime) >= 1.18
BuildRequires:  patch
BuildRequires:  pkgconfig(pdfium) >= 5.0
BuildRequires:  pkgconfig(tesseract)
BuildRequires:  python3
BuildRequires:  tar

Requires:       onnxruntime%{?_isa} >= 1.18
Requires:       pdfium%{?_isa} >= 146.0.7678.0
Requires:       tesseract%{?_isa}

%description
Kreuzberg extracts text, metadata, tables, and structured content from document
formats. This source package builds the command-line application and N-API
binding.

%package -n nodejs-kreuzberg
Summary:        Node.js bindings for Kreuzberg
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       nodejs >= 22
Provides:       npm(@kreuzberg/node) = %{version}

%description -n nodejs-kreuzberg
Source-built N-API bindings for the Kreuzberg document intelligence library.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{node_wrapper_sha256}  %{SOURCE1}" | sha256sum -c -
%autosetup -p1 -n kreuzberg-lts-%{version}

mkdir .node-wrapper
tar -xzf %{SOURCE1} -C .node-wrapper --strip-components=1
find .node-wrapper -type f \( -name '*.node' -o -name '*.so' -o -name '*.dll' -o -name '*.dylib' \) -print -quit | grep -q . && exit 1 || :
patch --fuzz=0 -p1 -d .node-wrapper < %{SOURCE2}
rm -f .node-wrapper/dist/cli.js.map .node-wrapper/dist/cli.mjs.map
chmod 0644 .node-wrapper/package.json
sed -i '1{/^#!\/usr\/bin\/env node$/d;}' .node-wrapper/dist/cli.d.ts .node-wrapper/dist/cli.d.mts

%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
export CARGO_NET_OFFLINE=true
export ORT_OFFLINE=1
export ORT_SKIP_DOWNLOAD=1
export ORT_DYLIB_PATH=%{_libdir}/libonnxruntime.so
export KREUZBERG_SKIP_FFI_ARTIFACTS=1
%{__cargo} build %{__cargo_common_opts} --profile rpm \
  -p kreuzberg-cli -p kreuzberg-node
/usr/bin/chrpath -d target/rpm/kreuzberg

%check
export CARGO_NET_OFFLINE=true
export ORT_OFFLINE=1
export ORT_SKIP_DOWNLOAD=1
export ORT_DYLIB_PATH=%{_libdir}/libonnxruntime.so
export KREUZBERG_SKIP_FFI_ARTIFACTS=1
export KREUZBERG_CACHE_DIR="$PWD/.cache/kreuzberg"
export HF_HOME="$PWD/.cache/huggingface"
env -u CARGO_ENCODED_RUSTFLAGS -u CARGO_BUILD_RUSTFLAGS \
  CARGO_HOME=.cargo CARGO_NET_OFFLINE=true RUSTC_BOOTSTRAP=1 RUSTFLAGS= \
  /usr/bin/cargo test -Z avoid-dev-deps -p kreuzberg-cli --bin kreuzberg
env -u CARGO_ENCODED_RUSTFLAGS -u CARGO_BUILD_RUSTFLAGS \
  CARGO_HOME=.cargo CARGO_NET_OFFLINE=true RUSTC_BOOTSTRAP=1 RUSTFLAGS= \
  /usr/bin/cargo test -Z avoid-dev-deps -p kreuzberg-cli \
  --test config_env_overrides_test --test contract_cli --test log_level_robustness
env -u CARGO_ENCODED_RUSTFLAGS -u CARGO_BUILD_RUSTFLAGS \
  CARGO_HOME=.cargo CARGO_NET_OFFLINE=true RUSTC_BOOTSTRAP=1 RUSTFLAGS= \
  /usr/bin/cargo test -Z avoid-dev-deps -p kreuzberg-node
target/rpm/kreuzberg --version
target/rpm/kreuzberg detect test_documents/text/fake_text.txt --format json > mime-check.json
/usr/bin/grep -Fq '"mime_type": "text/plain"' mime-check.json
target/rpm/kreuzberg extract test_documents/text/fake_text.txt --format json > text-check.json
/usr/bin/grep -Eq '"mime_type"[[:space:]]*:[[:space:]]*"text/plain"' text-check.json
/usr/bin/grep -Fq 'Hamburgers are delicious' text-check.json
target/rpm/kreuzberg extract test_documents/pdf/tiny.pdf --format json > pdf-check.json
/usr/bin/grep -Eq '"mime_type"[[:space:]]*:[[:space:]]*"application/pdf"' pdf-check.json
/usr/bin/grep -Fq 'Simple document' pdf-check.json
rm -f mime-check.json text-check.json pdf-check.json

case "%{_target_cpu}" in
  x86_64) node_arch=x64 ;;
  aarch64) node_arch=arm64 ;;
  *) exit 1 ;;
esac
cp target/rpm/libkreuzberg_node.so \
  ".node-wrapper/kreuzberg-node.linux-${node_arch}-gnu.node"
NAPI_RS_NATIVE_LIBRARY_PATH="$PWD/.node-wrapper/kreuzberg-node.linux-${node_arch}-gnu.node" \
  node -e "const k=require('./.node-wrapper/dist/index.js'); const p='test_documents/text/fake_text.txt'; const r=k.extractFileSync(p); if (!k.__version__ || k.detectMimeTypeFromPath(p) !== 'text/plain' || r.mimeType !== 'text/plain' || !r.content.includes('Hamburgers are delicious')) process.exit(1)"

%install
install -Dpm0755 target/rpm/kreuzberg %{buildroot}%{_bindir}/kreuzberg

install -d %{buildroot}%{nodejs_sitelib}/@kreuzberg/node
cp -a .node-wrapper/dist .node-wrapper/index.js .node-wrapper/index.d.ts \
  .node-wrapper/package.json .node-wrapper/README.md \
  %{buildroot}%{nodejs_sitelib}/@kreuzberg/node/

case "%{_target_cpu}" in
  x86_64) node_arch=x64 ;;
  aarch64) node_arch=arm64 ;;
esac
install -Dpm0755 target/rpm/libkreuzberg_node.so \
  "%{buildroot}%{nodejs_sitelib}/@kreuzberg/node/kreuzberg-node.linux-${node_arch}-gnu.node"

mkdir -p %{buildroot}%{_licensedir}/%{name}
CARGO_HOME=.cargo CARGO_NET_OFFLINE=true RUSTC_BOOTSTRAP=1 /usr/bin/cargo tree -Z avoid-dev-deps --offline \
  -p kreuzberg-cli --edges=no-build,no-dev,no-proc-macro --target all --prefix none \
  --format '{l}: {p}' > cli-licenses
CARGO_HOME=.cargo CARGO_NET_OFFLINE=true RUSTC_BOOTSTRAP=1 /usr/bin/cargo tree -Z avoid-dev-deps --offline \
  -p kreuzberg-node --edges=no-build,no-dev,no-proc-macro --target all --prefix none \
  --format '{l}: {p}' > node-licenses
sort -u cli-licenses node-licenses > %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies
test -s %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies
python3 %{SOURCE3} \
  --inventory %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies \
  --registry /usr/share/cargo/registry \
  --output %{buildroot}%{_licensedir}/%{name}/THIRD-PARTY-LICENSES
rm -f cli-licenses node-licenses

%files
%license LICENSE
%license %{_licensedir}/%{name}/LICENSE.dependencies
%license %{_licensedir}/%{name}/THIRD-PARTY-LICENSES
%doc README.md
%{_bindir}/kreuzberg

%files -n nodejs-kreuzberg
%license LICENSE
%doc crates/kreuzberg-node/README.md
%{nodejs_sitelib}/@kreuzberg/node/

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.1
- Add a blocked source-build draft using system PDFium and ONNX Runtime.
