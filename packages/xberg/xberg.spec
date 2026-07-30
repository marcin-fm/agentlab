%global source_sha256 238b8087a398b7753562b341abf082c8305a0359786424976909dc59b251058e
%global source_audit_sha256 0aeba6bb536a247e5fd941c44dcb8a86b42737561eab16bfb7a52e2dc3d48f5c
%global system_ort_audit_sha256 95f51ae6fa6e1fe0b519875feda0d2a12510cefc469c5936def24921bc2e7d76
%global system_onnxruntime_patch_sha256 8b2e12741c26338aba679514262171fa2dfe2772a771255372df8d70144606ab
%global fedora_onnxruntime_path_patch_sha256 b254d883cc4c0f15411eff83db7e0c072098b69fdd57e9aceaf99956e0e2121c
%global cargo_lock_sha256 a8e11cce6425868975b00b13db98acf21a7bc2cb8e7fe143a80aa5ebfeddf667
%global cargo_closure_sha256 3882ffdd756c9d65921934afb59c8c546abc5da1753fbfa378fc42c2df5f7907
%global cargo_vendor_receipt_sha256 8980a1d9bb4a1123b2cbdc6dcc082993226c3d0eca09facc59c39124896f2819
%global license_text_presence_sha256 99b5a7f6d2f1f3d5b2559f784b3d729a21743e14eee89721b5c0c24ab4fed691
%global cargo_vendor_manifest_sha256 5d571bb5bc923c855a1e75f335d32187fda5cbb6f9d64b20af960b8c5a7ba544
%global cargo_auditor_sha256 fbcf02cdc6f20f325cd86fd9a4882f47d69fe5839ed2f01f1c75d7936d5057ce
%global dynamic_tesseract_patch_sha256 8ef0d3253fac28c655ad303a9649d356e51aff024fadc12d642394af0ccb0d7f
%global selected_workspace_patch_sha256 054d4fa336f1a823babaa26eaad3c223fc0d54e6d4e898009aeec77e0301f0b2
%global fedora_tessdata_patch_sha256 a27928a78f6f51296c0af68e82e9481e972a17c7e004b320d4bda600af9bcc20
%global source_license_receipt_sha256 151db6184d9e3bab63aa60a8976345b3d6bf29f3f4483564ebc01ea67a4cce32
%global provider_proof_sha256 961816ce0f789c92091bc4d7f40e780a7a16abdb02d1819df1c121b7dc48a937
%global fedora_license_allowlist_sha256 9594bfb8b0426fe8f0329606d0fcbf6a2a744ce7a4099c60887491b4dc5619c0
%global proof_auditor_sha256 f976958e8a51865710b7f91c38fb2d2bea2a33304ed587aff7713013e1a045d8
%global source_filter_sha256 baf0efc96f735fbda22cad3fb22d08a79dc9a8e9286aa1f150972dbc3bbc5a0d
%global cargo_license_writer_sha256 7dd6a505e65900dceded74405d586459180e2a701806b31ac24452e37acd1a51
%global xberg_cli_features formats,analysis,core-cli,embeddings,html,url-ingestion,liter-llm,ocr,paddle-ocr,layout-detection,chunking-tokenizers

Name:           xberg
Version:        1.0.3
Release:        0.2%{?dist}
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
Source15:       write-xberg-cargo-license-receipts
# Fedora system ONNX Runtime: select Xberg's released dynamic feature path for
# the selected CLI ML surface. Fedora-specific; local upstream history has no
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
# Use Fedora's packaged tessdata and fail locally for missing languages instead
# of downloading mutable tessdata_fast/main content. Fedora-specific; not
# submitted upstream because this selects RPM-managed runtime data.
Patch4:         xberg-fedora-system-tessdata.patch

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
Requires:       onnxruntime%{?_isa} >= 1.18
Requires:       tesseract-langpack-eng

%description
Xberg is a document intelligence toolkit. This source-package draft is
intentionally blocked pending a fresh Fedora dependency, license, native
binding, and offline-build audit for upstream Xberg v1.0.3.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{source_audit_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{system_ort_audit_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{system_onnxruntime_patch_sha256}  %{PATCH0}" | sha256sum -c -
echo "%{fedora_onnxruntime_path_patch_sha256}  %{PATCH1}" | sha256sum -c -
echo "%{dynamic_tesseract_patch_sha256}  %{PATCH2}" | sha256sum -c -
echo "%{selected_workspace_patch_sha256}  %{PATCH3}" | sha256sum -c -
echo "%{fedora_tessdata_patch_sha256}  %{PATCH4}" | sha256sum -c -
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
echo "%{cargo_license_writer_sha256}  %{SOURCE15}" | sha256sum -c -
%setup -q -n xberg-%{version}
install -Dm0755 %{SOURCE8} .agentlab-source/audit-xberg-cargo-closure
install -Dm0755 %{SOURCE14} .agentlab-source/audit-xberg-proof-receipts
install -Dm0755 %{SOURCE15} .agentlab-source/write-xberg-cargo-license-receipts
ruby .agentlab-source/audit-xberg-cargo-closure --sanitize-only --source . --filter %{SOURCE9}
%autopatch -p1
install -pm0644 %{PATCH0} %{PATCH1} %{PATCH2} %{PATCH3} %{PATCH4} .agentlab-source/
install -pm0644 %{SOURCE10} Cargo.lock
echo "%{cargo_lock_sha256}  Cargo.lock" | sha256sum -c -
tar --zstd --extract --no-same-owner --no-same-permissions --file %{SOURCE6} --directory .
ruby .agentlab-source/audit-xberg-cargo-closure --verify --vendor-dir cargo-vendor --receipt %{SOURCE4}
test "$(find cargo-vendor -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1034
test "$(wc -l < %{SOURCE7})" -eq 1034
%cargo_prep -v cargo-vendor
install -d -m0700 .agentlab-proof-output .agentlab-proof-work
ruby .agentlab-source/audit-xberg-proof-receipts --prepared-source "$PWD" --vendor-dir "$PWD/cargo-vendor" --patch-dir .agentlab-source --closure %{SOURCE3} --presence %{SOURCE5} --allowlist %{SOURCE13} --provider %{SOURCE11} --output-dir .agentlab-proof-output --workdir .agentlab-proof-work
cmp .agentlab-proof-output/xberg-%{version}-source-license-receipt.json %{SOURCE12}
cmp .agentlab-proof-output/xberg-%{version}-provider-proof.json %{SOURCE11}

%build
export CARGO_NET_OFFLINE=true
export ORT_DYLIB_PATH=/usr/lib64/libonnxruntime.so
export TESSDATA_PREFIX=/usr/share/tesseract/tessdata
export HF_HUB_OFFLINE=1
export HF_DATASETS_OFFLINE=1
install -d -m0700 .test-home .cargo-cache
export HOME="$PWD/.test-home"
export CARGO_HOME="$PWD/.cargo-cache"
%cargo_build -- --package xberg-cli --no-default-features --features %{xberg_cli_features} --locked
ruby .agentlab-source/write-xberg-cargo-license-receipts --output LICENSE.dependencies

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
* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 1.0.3-0.2
- Correct the exact Source0 safe-symlink inventory and rebind its audits.

* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 1.0.3-0.1
- Update to upstream Xberg 1.0.3 and regenerate every source-bound receipt.
- Retain the exact default-minus-tree-sitter Fedora feature surface.
- Rebase the workspace and Fedora tessdata patches without changing policy.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.21
- Omit tree-sitter initially and use Fedora-managed Tesseract language data.
- Regenerate the exact default-minus-tree-sitter source and license receipts.
- Make the system ONNX Runtime feature patch contextual and fail-closed.
- Require dynamic ONNX Runtime and default English tessdata at runtime.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.20
- Build and account for the exact default-feature Xberg CLI surface.

* Wed Jul 29 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.19
- Exclude the independently audited vendor tree from Source0 manifest checks.

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
