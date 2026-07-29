%global source_sha256 a2e3ac73c051476625ec3f540c523553be2086282d3808c3f32979067a070ee6
%global source_audit_sha256 cb49f4c4a035795e87f0eedf0fee219bfde506347b085cbb7dfb6b6a0b97e12a
%global system_ort_audit_sha256 a68aa83911e275096845d17ad526277440ce04b9bc97bf6f918d226f5e882460
%global system_onnxruntime_patch_sha256 be0c9455871fdff3912986b420d7710eaff1777fdd4d82b5ae5524b3b1c8000b
%global fedora_onnxruntime_path_patch_sha256 b254d883cc4c0f15411eff83db7e0c072098b69fdd57e9aceaf99956e0e2121c
%global cargo_lock_sha256 ca592b84261f3bff605b43adc49b99e2401907a9697fe936dc7f27225c16ca52
%global cargo_closure_sha256 4de24a9fd1d98ef475e0029a5e13732a718d6b541459b4ca727b2c5ef0f538ff
%global cargo_vendor_receipt_sha256 ff7fcbd21efc96098c609b843f9b70a06ae447f1a1fdff18f189ef3bf5c15498
%global license_text_presence_sha256 537c397f02885ab7e5d291a060f90101fa74fcfd5e8ce7d0501ad70a0170796e
%global cargo_vendor_manifest_sha256 e0554364055d65efa64692ed42e016ea0f3d63aeba96038b1a665989fc32b569
%global cargo_auditor_sha256 22902bdd818c3c949757d6cf2874328877b79455fa1e2ce2d767e8371f442eb3
%global dynamic_tesseract_patch_sha256 8ef0d3253fac28c655ad303a9649d356e51aff024fadc12d642394af0ccb0d7f
%global selected_workspace_patch_sha256 8adc6c208ff3cc888400c290049315bd285e9229b4fd08890070bb3f34ea6ecf
%global source_license_receipt_sha256 3cbf7857f5b572fa6ca5a7f061c0ac4d226e87db3dd554ffd4bdc792fd5d2925
%global provider_proof_sha256 8b11b645c50d23b323231f01d23fe699ba1b3a1a50755811878de1ced7e66adc
%global fedora_license_allowlist_sha256 9594bfb8b0426fe8f0329606d0fcbf6a2a744ce7a4099c60887491b4dc5619c0
%global proof_auditor_sha256 2ccd90220247f1faef4401117188d68f84ea46e79035a6fdbcdb376d65d0c420
%global source_filter_sha256 233d5ce7fe8630ef7fad81d7b52878e3d282999c11f1294cc7b271f392984fbd

Name:           xberg
Version:        1.0.1
Release:        0.18%{?dist}
Summary:        Document intelligence toolkit

%global xberg_source_license_expression ((Apache-2.0 OR MIT) AND BSD-3-Clause) AND ((MIT OR Apache-2.0) AND Apache-2.0) AND ((MIT OR Apache-2.0) AND ISC) AND ((MIT OR Apache-2.0) AND NCSA) AND ((MIT OR Apache-2.0) AND Unicode-3.0) AND ((MIT OR Apache-2.0) AND Unicode-DFS-2016) AND (0BSD OR CC0-1.0) AND (0BSD OR MIT OR Apache-2.0) AND Apache-2.0 AND (Apache-2.0 AND ISC) AND (Apache-2.0 AND MIT) AND (Apache-2.0 OR BSL-1.0) AND (Apache-2.0 OR BSL-1.0 OR MIT) AND (Apache-2.0 OR ISC OR MIT) AND (Apache-2.0 OR MIT) AND (Apache-2.0 OR MIT OR Zlib) AND Apache-2.0 WITH LLVM-exception AND (Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT) AND BSD-2-Clause AND (BSD-2-Clause OR Apache-2.0 OR MIT) AND BSD-3-Clause AND (BSD-3-Clause AND MIT) AND (BSD-3-Clause OR Apache-2.0) AND (BSD-3-Clause OR MIT) AND BSL-1.0 AND (BlueOak-1.0.0 OR MIT OR Apache-2.0) AND CC0-1.0 AND (CC0-1.0 OR Apache-2.0) AND (CC0-1.0 OR Apache-2.0 OR Apache-2.0 WITH LLVM-exception) AND (CC0-1.0 OR MIT-0) AND (CC0-1.0 OR MIT-0 OR Apache-2.0) AND CDDL-1.0 AND CDLA-Permissive-2.0 AND GPL-2.0-or-later AND ISC AND (ISC AND (Apache-2.0 OR ISC)) AND (ISC AND (Apache-2.0 OR ISC) AND Apache-2.0 AND MIT AND BSD-3-Clause AND (Apache-2.0 OR ISC OR MIT) AND (Apache-2.0 OR ISC OR MIT-0)) AND MIT AND (MIT AND BSD-3-Clause) AND (MIT OR Apache-2.0) AND (MIT OR Apache-2.0 OR LGPL-2.1-or-later) AND (MIT OR Apache-2.0 OR Zlib) AND (MIT OR Zlib OR Apache-2.0) AND MIT-0 AND MPL-2.0 AND (MPL-2.0 OR LGPL-2.1-or-later) AND Unicode-3.0 AND (Unlicense OR MIT) AND (Unlicense OR MIT OR Apache-2.0 OR CC0-1.0) AND Zlib AND (Zlib OR Apache-2.0 OR MIT) AND bzip2-1.0.6
License:        %{xberg_source_license_expression}
URL:            https://github.com/xberg-io/xberg
Source0:        https://github.com/xberg-io/xberg/archive/refs/tags/v%{version}.tar.gz
Source1:        %{name}-%{version}-source-audit.json
Source2:        %{name}-%{version}-system-ort-audit.json
Source3:        %{name}-%{version}-cargo-closure.json
Source4:        %{name}-%{version}-cargo-vendor-receipt.json
Source5:        %{name}-%{version}-license-text-presence.json
Source6:        %{name}-%{version}-cargo-vendor.tar.zst
Source7:        %{name}-%{version}-cargo-vendor.txt
Source8:        audit-xberg-cargo-closure
Source9:        %{name}-%{version}-source-filter.json
Source10:       %{name}-%{version}-fedora-Cargo.lock
Source11:       %{name}-%{version}-provider-proof.json
Source12:       %{name}-%{version}-source-license-receipt.json
Source13:       %{name}-%{version}-fedora-license-allowlist.json
Source14:       audit-xberg-proof-receipts
# Fedora system ONNX Runtime: select Xberg's released dynamic feature path for
# the default CLI ML surface. Fedora-specific; local upstream history has no
# released default-Linux feature-edge equivalent.
Patch0:         xberg-system-onnxruntime.patch
# Fedora system ONNX Runtime: search the architecture-specific lib64 location.
# Fedora-specific; local upstream history has no released Fedora lib64 equivalent.
Patch1:         xberg-fedora-onnxruntime-path.patch
# Replace upstream Tesseract's download path with Fedora's dynamic provider.
# Fedora-specific; upstream's released default remains download-based.
Patch2:         xberg-dynamic-tesseract.patch
# Select the six-member Fedora workspace and remove unselected Candle metadata.
# Fedora-specific; not submitted upstream because this is package-surface selection.
Patch3:         xberg-selected-workspace.patch

# The selected future dynamic-ORT recipe validates the system provider at build
# time and needs an explicit runtime dependency because dlopen has no ELF edge.
BuildRequires:  pkgconfig(libonnxruntime) >= 1.18
BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  gcc
BuildRequires:  gcc-c++
BuildRequires:  cmake
BuildRequires:  clang
BuildRequires:  perl
BuildRequires:  binutils
BuildRequires:  pkgconfig(libheif)
BuildRequires:  pkgconfig(tesseract)
BuildRequires:  pkgconfig(lept)
BuildRequires:  tesseract-langpack-eng
BuildRequires:  ruby
BuildRequires:  rubypick
BuildRequires:  rubygem-json
BuildRequires:  tar
BuildRequires:  zstd

%description
Xberg is a document intelligence toolkit. This source-package draft is
intentionally blocked pending a fresh Fedora dependency, license, native
binding, and offline-build audit for upstream Xberg v1.0.1.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{source_audit_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{system_ort_audit_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{system_onnxruntime_patch_sha256}  %{PATCH0}" | sha256sum -c -
echo "%{fedora_onnxruntime_path_patch_sha256}  %{PATCH1}" | sha256sum -c -
echo "%{dynamic_tesseract_patch_sha256}  %{PATCH2}" | sha256sum -c -
echo "%{selected_workspace_patch_sha256}  %{PATCH3}" | sha256sum -c -
echo "%{cargo_closure_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{cargo_vendor_receipt_sha256}  %{SOURCE4}" | sha256sum -c -
echo "%{license_text_presence_sha256}  %{SOURCE5}" | sha256sum -c -
echo "%{cargo_vendor_manifest_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{cargo_auditor_sha256}  %{SOURCE8}" | sha256sum -c -
echo "%{source_filter_sha256}  %{SOURCE9}" | sha256sum -c -
echo "%{cargo_lock_sha256}  %{SOURCE10}" | sha256sum -c -
echo "%{provider_proof_sha256}  %{SOURCE11}" | sha256sum -c -
echo "%{source_license_receipt_sha256}  %{SOURCE12}" | sha256sum -c -
echo "%{fedora_license_allowlist_sha256}  %{SOURCE13}" | sha256sum -c -
echo "%{proof_auditor_sha256}  %{SOURCE14}" | sha256sum -c -
%setup -q -n xberg-%{version}
install -Dm0755 %{SOURCE8} .agentlab-source/audit-xberg-cargo-closure
install -Dm0755 %{SOURCE14} .agentlab-source/audit-xberg-proof-receipts
ruby .agentlab-source/audit-xberg-cargo-closure --sanitize-only --source . --filter %{SOURCE9}
%autopatch -p1
install -pm0644 %{PATCH0} %{PATCH1} %{PATCH2} %{PATCH3} .agentlab-source/
install -pm0644 %{SOURCE10} Cargo.lock
echo "%{cargo_lock_sha256}  Cargo.lock" | sha256sum -c -
tar --zstd --extract --no-same-owner --no-same-permissions --file %{SOURCE6} --directory .
ruby .agentlab-source/audit-xberg-cargo-closure --verify --vendor-dir cargo-vendor --receipt %{SOURCE4}
test "$(find cargo-vendor -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1040
test "$(wc -l < %{SOURCE7})" -eq 1040
%cargo_prep -v cargo-vendor
install -d -m0700 .agentlab-proof-output .agentlab-proof-work
ruby .agentlab-source/audit-xberg-proof-receipts --prepared-source "$PWD" --vendor-dir "$PWD/cargo-vendor" --patch-dir .agentlab-source --closure %{SOURCE3} --presence %{SOURCE5} --allowlist %{SOURCE13} --provider %{SOURCE11} --output-dir .agentlab-proof-output --workdir .agentlab-proof-work
cmp .agentlab-proof-output/xberg-1.0.1-source-license-receipt.json %{SOURCE12}
cmp .agentlab-proof-output/xberg-1.0.1-provider-proof.json %{SOURCE11}

%build
export CARGO_NET_OFFLINE=true
export ORT_DYLIB_PATH=/usr/lib64/libonnxruntime.so
export TESSDATA_PREFIX=/usr/share/tesseract/tessdata
export HF_HUB_OFFLINE=1
export HF_DATASETS_OFFLINE=1
install -d -m0700 .test-home .cargo-cache
export HOME="$PWD/.test-home"
export CARGO_HOME="$PWD/.cargo-cache"
%cargo_build_crate -n xberg-cli

%check
test -s target/rpm/xberg
test -f LICENSE.dependencies
test "$(wc -l < LICENSE.dependencies)" -gt 0
sha256sum LICENSE.dependencies > .agentlab-license-dependencies.sha256
target/rpm/xberg --version
target/rpm/xberg --help >/dev/null
ldd -r target/rpm/xberg > .agentlab-ldd-r.txt 2>&1
! grep -E 'not found|undefined symbol' .agentlab-ldd-r.txt
readelf -d target/rpm/xberg >> .agentlab-ldd-r.txt
echo 'xberg remains blocked after the deliberate post-build integration gate: final linked-license, runtime, model, matrix, and publication proof are incomplete' >&2
exit 1

%changelog
* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.18
- Verify every Fedora patch before applying the compile-proof source contract.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.17
- Add the corrected source contract and fail-closed Fedora compile proof.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.16
- Record the configured-SCM source and fail-closed prep proof.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.15
- Prevent the explanatory vendor-manifest comment from expanding as an RPM macro.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.14
- Bind the corrected extended-path Cargo vendor tree receipt.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.13
- Canonicalize Cargo graph receipts by sorted package identity.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.12
- Safely honor GNU and POSIX extended tar paths during Cargo extraction.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.11
- Keep unsafe-link filtering specific to archives that declare a checked filter.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.10
- Filter only checked unsafe source links before applying Fedora patches.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.9
- Safely preserve in-tree symbolic and hard links during configured-SCM extraction.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.8
- Record resolver-complete cache-independent Cargo generation and patch application.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.7
- Bind the retained closure report identity to the blocked Cargo receipt.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.6
- Add the checked configured-SCM Cargo source contract and retain the build gate.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.5
- Record the source-only system ONNX Runtime adaptation and keep the build blocked.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.4
- Correct the Xberg tag commit and record its source tree separately.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.3
- Distinguish historical lock observations from a selected Xberg closure.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.2
- Record the released-source audit boundary and retain the fail-closed draft.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.1
- Add a fail-closed blocked draft for upstream Xberg v1.0.1.
