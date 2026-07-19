%bcond check 1
%{?nodejs_default_filter}

# Disabled by package.yml until the source-hosting, license, architecture, and
# final clean-build gates are complete.
%global source_sha256 2bd9c13744a8105b469c7b0d68d6574e9d29ccd8fa08f2bb93261aa058f17108
%global types_node_sha256 cb0bc3624d2e6bc233ec332a3aea6ac317c0aadb3301bfb797a34864546c1401
%global undici_types_sha256 07a721cb2cd0dd798c24757de34d14e8b640ff8fddef85d662e00b392562a1f2

Name:           kreuzberg
Version:        4.10.2
Release:        0.0.7%{?dist}
Summary:        Document intelligence toolkit and Node bindings

License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CC0-1.0 AND CDLA-Permissive-2.0 AND ISC AND LicenseRef-Fedora-Public-Domain AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Unlicense AND WTFPL AND Zlib AND bzip2-1.0.6
URL:            https://github.com/kreuzberg-dev/kreuzberg-lts
Source0:        https://github.com/kreuzberg-dev/kreuzberg-lts/archive/refs/tags/v%{version}.tar.gz
Source1:        https://registry.npmjs.org/@types/node/-/node-26.1.1.tgz
Source2:        https://registry.npmjs.org/undici-types/-/undici-types-8.3.0.tgz
Source3:        kreuzberg-node-loader.js
Source4:        kreuzberg-date-xlsx-fixture
# Select the Fedora CLI, Node, and FFI feature surface with system PDFium.
# Fedora-specific; not submitted upstream because it is the RPM-selected surface.
Patch0:         kreuzberg-system-pdfium.patch
# Load ONNX Runtime dynamically rather than using upstream bundled artifacts.
# Fedora-specific; not submitted upstream because it selects Fedora system libraries.
Patch1:         kreuzberg-ort-dynamic.patch
# Select the dynamic Tesseract feature for Fedora-provided OCR libraries.
# Fedora-specific; not submitted upstream because it selects RPM system libraries.
Patch2:         kreuzberg-system-tesseract-feature.patch
# Invoke the RPM-owned CLI without Node runtime dependencies in source builds.
# Fedora-specific; not submitted upstream because it is RPM CLI integration.
Patch3:         kreuzberg-node-cli-cleanup.patch
# Limit the workspace to source-built CLI and Node binding crates.
# Fedora-specific; not submitted upstream because it narrows the RPM build scope.
Patch4:         kreuzberg-node-workspace.patch
# Remove WASM-only dependencies from the native Linux RPM dependency graph.
# Fedora-specific; not submitted upstream because it narrows the RPM target graph.
Patch5:         kreuzberg-native-targets.patch
# Adapt constructor registration to Fedora's compatible ctor package.
# Fedora-specific; not submitted upstream because it supports Fedora's crate version.
Patch6:         kreuzberg-ctor-compat.patch
# Pin Tokio to the compatible Fedora crate release.
# Fedora-specific; not submitted upstream because it supports Fedora's crate version.
Patch7:         kreuzberg-tokio-pin.patch
# Avoid the optional mimalloc crate in the Fedora Node build.
# Fedora-specific; not submitted upstream because it reduces RPM dependencies.
Patch8:         kreuzberg-no-mimalloc.patch
# Align ndarray dependencies with Fedora's packaged API version.
# Fedora-specific; not submitted upstream because it supports Fedora's crate version.
Patch9:         kreuzberg-ndarray-compat.patch
# Use compatible Fedora versions for unchanged crate APIs.
# Fedora-specific; not submitted upstream because it supports Fedora's crate versions.
Patch10:        kreuzberg-fedora-version-pins.patch
# Adapt spreadsheet date conversion to Fedora's older calamine API.
# Fedora-specific reversal of https://github.com/kreuzberg-dev/kreuzberg/commit/1b63779dd38cf042007739ccb3d1d2f3aacb697d.
Patch11:        kreuzberg-calamine-compat.patch
# Adapt encoding detection to Fedora's chardetng API.
# Fedora-specific; not submitted upstream because it supports Fedora's crate version.
Patch12:        kreuzberg-chardetng-compat.patch
# Adapt embedding token setup to Fedora's tokenizers API.
# Fedora-specific; not submitted upstream because it supports Fedora's crate version.
Patch13:        kreuzberg-tokenizers-compat.patch
# Adapt model downloads to Fedora hf-hub while retaining upstream environment handling.
# Fedora-specific adaptation of https://github.com/kreuzberg-dev/kreuzberg/commit/8fa32df7d7960652a0cd3d9bbee9915c047e5125.
Patch14:        kreuzberg-hf-hub-compat.patch
# Discover ONNX Runtime in Fedora's architecture-specific runtime library path.
# Fedora-specific; not submitted upstream because it is Fedora runtime integration.
Patch15:        kreuzberg-onnxruntime-path.patch
# Discover the versioned Fedora PDFium runtime library before generic lookup.
# Fedora-specific; not submitted upstream because it is Fedora runtime integration.
Patch16:        kreuzberg-pdfium-runtime-path.patch
# Enable source code guarded by Kreuzberg's existing dynamic Tesseract feature.
# Fedora-specific; not submitted upstream because it is Fedora system-library integration.
Patch17:        kreuzberg-system-tesseract.patch
# Skip unshipped FFI artifact generation while building the RPM Node addon.
# Fedora-specific; not submitted upstream because it is RPM build integration.
Patch18:        kreuzberg-node-no-ffi-artifacts.patch
# Avoid N-API type-definition generation not shipped by the RPM Node wrapper.
# Fedora-specific; not submitted upstream because it narrows the RPM build output.
Patch19:        kreuzberg-node-no-napi-type-def.patch

ExclusiveArch:  x86_64 aarch64

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  clang-devel
BuildRequires:  chrpath
BuildRequires:  gcc-c++
BuildRequires:  nodejs >= 22
BuildRequires:  nodejs-devel >= 22
BuildRequires:  nodejs-esbuild
BuildRequires:  nodejs-packaging
BuildRequires:  pkgconfig(libonnxruntime) >= 1.18
BuildRequires:  patch
BuildRequires:  pkgconfig(pdfium) >= 5.0
BuildRequires:  pkgconfig(tesseract)
BuildRequires:  tar
BuildRequires:  typescript >= 5.7.3
BuildRequires:  zip

# The selected integrations load these architecture-specific system libraries
# at runtime, so their requirements are not reliably generated from ELF links.
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
# Fedora's current Node file attribute does not match scoped installed roots.
Provides:       npm(@kreuzberg/node) = %{version}

%description -n nodejs-kreuzberg
Source-built N-API bindings for the Kreuzberg document intelligence library.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{types_node_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{undici_types_sha256}  %{SOURCE2}" | sha256sum -c -
%autosetup -p1 -n kreuzberg-lts-%{version}

mkdir -p crates/kreuzberg-node/node_modules/@types/node
mkdir -p crates/kreuzberg-node/node_modules/undici-types
tar -xzf %{SOURCE1} -C crates/kreuzberg-node/node_modules/@types/node --strip-components=1
tar -xzf %{SOURCE2} -C crates/kreuzberg-node/node_modules/undici-types --strip-components=1
install -pm0644 %{SOURCE3} crates/kreuzberg-node/index.js

%cargo_prep

%generate_buildrequires
# Only the CLI and Node packages are tested below. Do not pull unrelated
# workspace-member dev-dependencies into the dynamic build requirements.
/usr/bin/cargo2rpm --path Cargo.toml buildrequires

%build
export CARGO_NET_OFFLINE=true
export ORT_OFFLINE=1
export ORT_SKIP_DOWNLOAD=1
export ORT_DYLIB_PATH=%{_libdir}/libonnxruntime.so
export KREUZBERG_SKIP_FFI_ARTIFACTS=1

pushd crates/kreuzberg-node
/usr/bin/tsc --project tsconfig.json --emitDeclarationOnly --declaration --declarationMap false --sourceMap false
for entry in index cli errors types; do
  /usr/bin/esbuild "typescript/${entry}.ts" --bundle --platform=node --target=node22 \
    --format=cjs --sourcemap --outfile="dist/${entry}.js" \
    '--external:*.node' '--external:@kreuzberg/node-*' \
    --external:sharp --external:./index.js --external:../index.js --external:../../index.js
  /usr/bin/esbuild "typescript/${entry}.ts" --bundle --platform=node --target=node22 \
    --format=esm --sourcemap --outfile="dist/${entry}.mjs" \
    '--external:*.node' '--external:@kreuzberg/node-*' \
    --external:sharp --external:./index.js --external:../index.js --external:../../index.js
done
sed -i '1{/^#!\/usr\/bin\/env node$/d;}' dist/cli.d.ts
chmod 0755 dist/cli.js
popd

%cargo_build -- --package kreuzberg-cli --package kreuzberg-node
/usr/bin/chrpath -d target/rpm/kreuzberg
/usr/bin/chrpath -d target/rpm/libkreuzberg_node.so

# cargo2rpm accounts workspace roots. Patch4 leaves only the CLI and Node
# outputs plus their complete internal runtime crate closure.
%{cargo_license_summary}
%{cargo_license} > LICENSE.dependencies
test -s LICENSE.dependencies

%if %{with check}
%check
export CARGO_NET_OFFLINE=true
export ORT_OFFLINE=1
export ORT_SKIP_DOWNLOAD=1
export ORT_DYLIB_PATH=%{_libdir}/libonnxruntime.so
export KREUZBERG_SKIP_FFI_ARTIFACTS=1
export KREUZBERG_CACHE_DIR="$PWD/.cache/kreuzberg"
export HF_HOME="$PWD/.cache/huggingface"
%cargo_test -- --package kreuzberg-cli --bin kreuzberg
%cargo_test -- --package kreuzberg-cli --test config_env_overrides_test --test contract_cli --test log_level_robustness
%cargo_test -- --package kreuzberg-node

/usr/bin/bash %{SOURCE4} "$PWD/date-smoke.xlsx"

target/rpm/kreuzberg --version
target/rpm/kreuzberg detect test_documents/text/fake_text.txt --format json > mime-check.json
/usr/bin/grep -Fq '"mime_type": "text/plain"' mime-check.json
target/rpm/kreuzberg extract test_documents/text/fake_text.txt --format json > text-check.json
/usr/bin/grep -Eq '"mime_type"[[:space:]]*:[[:space:]]*"text/plain"' text-check.json
/usr/bin/grep -Fq 'Hamburgers are delicious' text-check.json
target/rpm/kreuzberg extract test_documents/pdf/tiny.pdf --format json > pdf-check.json
/usr/bin/grep -Eq '"mime_type"[[:space:]]*:[[:space:]]*"application/pdf"' pdf-check.json
/usr/bin/grep -Fq 'Simple document' pdf-check.json
target/rpm/kreuzberg extract test_documents/xlsx/excel_multi_sheet.xlsx --format json > xlsx-check.json
/usr/bin/grep -Fq '"mime_type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"' xlsx-check.json
/usr/bin/grep -Fq 'Tomato' xlsx-check.json
/usr/bin/grep -Fq 'Beetroot' xlsx-check.json
target/rpm/kreuzberg extract date-smoke.xlsx --format json > date-check.json
/usr/bin/grep -Fq '2035-02-13 12:00:00' date-check.json
rm -f date-smoke.xlsx date-check.json mime-check.json text-check.json pdf-check.json xlsx-check.json

case "%{_target_cpu}" in
  x86_64) node_arch=x64 ;;
  aarch64) node_arch=arm64 ;;
  *) exit 1 ;;
esac
cp target/rpm/libkreuzberg_node.so \
  "crates/kreuzberg-node/kreuzberg-node.linux-${node_arch}-gnu.node"
NAPI_RS_NATIVE_LIBRARY_PATH="$PWD/crates/kreuzberg-node/kreuzberg-node.linux-${node_arch}-gnu.node" \
  %{__nodejs} -e "const k=require('./crates/kreuzberg-node/dist/index.js'); const p='test_documents/text/fake_text.txt'; const r=k.extractFileSync(p); if (!k.__version__ || k.detectMimeTypeFromPath(p) !== 'text/plain' || r.mimeType !== 'text/plain' || !r.content.includes('Hamburgers are delicious')) process.exit(1)"
/usr/bin/env -u NAPI_RS_NATIVE_LIBRARY_PATH %{__nodejs} --input-type=module -e "const k=await import('./crates/kreuzberg-node/dist/index.mjs'); const p='test_documents/text/fake_text.txt'; const r=k.extractFileSync(p); if (!k.__version__ || k.detectMimeTypeFromPath(p) !== 'text/plain' || r.mimeType !== 'text/plain' || !r.content.includes('Hamburgers are delicious')) process.exit(1)"
crates/kreuzberg-node/dist/cli.js --version
%endif

%install
install -Dpm0755 target/rpm/kreuzberg %{buildroot}%{_bindir}/kreuzberg

install -d %{buildroot}%{nodejs_sitearch}/@kreuzberg/node
cp -a crates/kreuzberg-node/dist crates/kreuzberg-node/index.js \
  crates/kreuzberg-node/package.json crates/kreuzberg-node/README.md \
  %{buildroot}%{nodejs_sitearch}/@kreuzberg/node/

case "%{_target_cpu}" in
  x86_64) node_arch=x64 ;;
  aarch64) node_arch=arm64 ;;
esac
install -Dpm0755 target/rpm/libkreuzberg_node.so \
  "%{buildroot}%{nodejs_sitearch}/@kreuzberg/node/kreuzberg-node.linux-${node_arch}-gnu.node"

install -Dpm0644 LICENSE.dependencies \
  %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies
install -Dpm0644 LICENSE.dependencies \
  %{buildroot}%{_licensedir}/nodejs-kreuzberg/LICENSE.dependencies
cmp -s LICENSE.dependencies \
  %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies
cmp -s LICENSE.dependencies \
  %{buildroot}%{_licensedir}/nodejs-kreuzberg/LICENSE.dependencies

%files
%license LICENSE
%license %{_licensedir}/%{name}/LICENSE.dependencies
%doc README.md
%{_bindir}/kreuzberg

%files -n nodejs-kreuzberg
%license LICENSE
%license %{_licensedir}/nodejs-kreuzberg/LICENSE.dependencies
%doc crates/kreuzberg-node/README.md
%{nodejs_sitearch}/@kreuzberg/node/

%changelog
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.7
- Exercise Fedora calamine conversion without benchmark-only dev dependencies.
- Ship the generated dependency license inventory with both runtime packages.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.6
- Build the Node loader and declarations from tagged TypeScript source.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.5
- Remove the upstream origin RUNPATH from the native Node addon.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.4
- Keep workspace-wide license accounting on the system Tesseract feature path.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.3
- Limit generated build requirements to the selected CLI and Node package graph.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.2
- Use Fedora Cargo and native Node macros for builds, tests, license accounting, and payload paths.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 4.10.2-0.0.1
- Add a blocked source-build draft using system libraries and Fedora-standard dependency license accounting.
