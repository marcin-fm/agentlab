# Disabled by package.yml. This spec deliberately aborts before compilation
# until the selected Linux source closure and Fedora integration are proven.
%bcond check 1

%global source_sha256 b3472ef0b53e9b6191e19f51f491f818749671b9cb1b8dbe51466dc2702abcd9
%global closure_sha256 a2f284d34455370a6bf846c5308369a188f86cab4c25e684e490eba62bb2834c
%global vendor_receipt_sha256 57857f050b55d9b596995e3de3842894a77d16d53b4a2ca23f9ceb83b5c2b5ef
%global source_lock_sha256 175793a40a3147db1fee08fd9db0acc59312c344b3513dd7ee316f5446d8119e
%global normalized_lock_sha256 2a5c38ba7ec277dba77477db379950530ca32dad01f34ad4bc6e3bac5636b9d9
%global commit 87db9bc18ba5bc82c1cb4e4381b44f693ee35623

Name:           codex-cli
Version:        0.144.5
Release:        0.3%{?dist}
Summary:        OpenAI coding agent command-line interface

# This is the upstream project license. The aggregate statically linked Cargo
# license expression remains a fail-closed packaging gate.
License:        Apache-2.0
URL:            https://github.com/openai/codex
Source0:        https://codeload.github.com/openai/codex/tar.gz/%{commit}#/%{name}-%{version}.tar.gz
Source1:        %{name}-%{version}-selected-cargo-closure.json
Source2:        %{name}-%{version}-selected-cargo-vendor-receipt.json

ExclusiveArch:  x86_64

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  rust >= 1.95

%description
Codex CLI is an open-source coding agent that runs in a terminal and integrates
with local developer tools.

This source-build draft is intentionally blocked. The selected Cargo sources
materialize reproducibly as evidence, but they are not a resolver-complete
offline directory source. The package must not produce an RPM until the Cargo
source model, upstreamable V8 integration and source closure, license evidence,
Fedora update policy, and offline builds are proven.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{closure_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{vendor_receipt_sha256}  %{SOURCE2}" | sha256sum -c -
%autosetup -n codex-%{commit} -N
echo "%{source_lock_sha256}  codex-rs/Cargo.lock" | sha256sum -c -
test "$(grep -cx 'version = "0\.0\.0"' codex-rs/Cargo.lock)" -eq 132
sed -i 's/^version = "0\.0\.0"$/version = "0.144.5"/' codex-rs/Cargo.lock
echo "%{normalized_lock_sha256}  codex-rs/Cargo.lock" | sha256sum -c -
echo 'codex-cli is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.3
- Materialize the exact selected Cargo sources twice with identical tree, manifest, configuration, archive, and receipt hashes.
- Record the inactive-target Cargo resolver blocker and keep the package fail-closed.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.2
- Record the selected Linux Cargo closure and local source-built V8 runtime proof.
- Verify the release-specific Cargo.lock normalization with exact hash and count guards.
- Keep the package blocked pending upstreamable V8 integration, immutable sources, licenses, update policy, and offline Fedora builds.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.1
- Add a fail-closed draft for the released Codex CLI source.
