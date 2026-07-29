%global source_sha256 a2e3ac73c051476625ec3f540c523553be2086282d3808c3f32979067a070ee6
%global source_audit_sha256 cb49f4c4a035795e87f0eedf0fee219bfde506347b085cbb7dfb6b6a0b97e12a
%global system_ort_audit_sha256 a68aa83911e275096845d17ad526277440ce04b9bc97bf6f918d226f5e882460
%global system_onnxruntime_patch_sha256 be0c9455871fdff3912986b420d7710eaff1777fdd4d82b5ae5524b3b1c8000b
%global fedora_onnxruntime_path_patch_sha256 b254d883cc4c0f15411eff83db7e0c072098b69fdd57e9aceaf99956e0e2121c
%global cargo_closure_sha256 1ed156386098a7a25590c918b9da8d58cff0923c07879ad5b6c463084244dd19
%global cargo_vendor_receipt_sha256 62f9932f13965696415d9b60c5e7b21d47ee132a81c680dd5815bcf94e40ab4b
%global license_text_presence_sha256 a58d4bb6bcb230b110e04f0d18e7aa7b7b1099bc46f730e517be34c437a60cc2
%global cargo_vendor_manifest_sha256 82e5024de178a5d65161d2c25068407b8a5a26436e49a5ca773ee2657ce85b02
%global cargo_auditor_sha256 5a137f12d19ad5f128b69c33fa0f38cf84c45fe67f4c9d70b2717faf181b4729

Name:           xberg
Version:        1.0.1
Release:        0.7%{?dist}
Summary:        Document intelligence toolkit

License:        MIT
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
# Fedora system ONNX Runtime: select Xberg's released dynamic feature path for
# the default CLI ML surface. Fedora-specific; local upstream history has no
# released default-Linux feature-edge equivalent.
Patch0:         xberg-system-onnxruntime.patch
# Fedora system ONNX Runtime: search the architecture-specific lib64 location.
# Fedora-specific; local upstream history has no released Fedora lib64 equivalent.
Patch1:         xberg-fedora-onnxruntime-path.patch

# The selected future dynamic-ORT recipe validates the system provider at build
# time and needs an explicit runtime dependency because dlopen has no ELF edge.
BuildRequires:  pkgconfig(libonnxruntime) >= 1.18
BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  ruby
BuildRequires:  rubypick
BuildRequires:  rubygem-json
BuildRequires:  tar
BuildRequires:  zstd
Requires:       onnxruntime%{?_isa} >= 1.18

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
echo "%{cargo_closure_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{cargo_vendor_receipt_sha256}  %{SOURCE4}" | sha256sum -c -
echo "%{license_text_presence_sha256}  %{SOURCE5}" | sha256sum -c -
echo "%{cargo_vendor_manifest_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{cargo_auditor_sha256}  %{SOURCE8}" | sha256sum -c -
%autosetup -p1 -n xberg-%{version} -N
echo "f5c39e192455b1f19b162176c15e343d45e096319d78082b379dd0b1a56257cd  Cargo.lock" | sha256sum -c -
install -Dm0755 %{SOURCE8} .agentlab-source/audit-xberg-cargo-closure
tar --zstd --extract --no-same-owner --no-same-permissions --file %{SOURCE6} --directory .
ruby .agentlab-source/audit-xberg-cargo-closure --verify --vendor-dir cargo-vendor --receipt %{SOURCE4}
test "$(wc -l < %{SOURCE7})" -eq 604
# Fedora's workspace-wide %cargo_vendor_manifest follows resolver-complete
# workspace semantics, not this selected 604-directory CLI contract. The
# auditor validates Source7 instead; do not make a false byte comparison.
%cargo_prep -v cargo-vendor
echo 'xberg is blocked: Cargo source delivery is checked, but linked-license, provider, native, and target-build proof remain incomplete' >&2
exit 1

%changelog
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
