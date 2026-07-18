# Disabled by package.yml. This spec deliberately aborts before compilation
# until the selected Linux source closure and Fedora integration are proven.
%bcond check 1
%global codex_distribution_channel fedora

%global source_sha256 b3472ef0b53e9b6191e19f51f491f818749671b9cb1b8dbe51466dc2702abcd9
%global closure_sha256 a2f284d34455370a6bf846c5308369a188f86cab4c25e684e490eba62bb2834c
%global vendor_receipt_sha256 57857f050b55d9b596995e3de3842894a77d16d53b4a2ca23f9ceb83b5c2b5ef
%global resolver_supplement_sha256 a9a5612e905e4bf1f1b4fd2214291cddc24af688b031a64809749651358e40ff
%global resolver_vendor_receipt_sha256 fe302ea41ef17b47432921f19361eda93576b51b2ddfdde31dcde66693db4d1b
%global source_lock_sha256 175793a40a3147db1fee08fd9db0acc59312c344b3513dd7ee316f5446d8119e
%global normalized_lock_sha256 2a5c38ba7ec277dba77477db379950530ca32dad01f34ad4bc6e3bac5636b9d9
%global commit 87db9bc18ba5bc82c1cb4e4381b44f693ee35623

Name:           codex-cli
Version:        0.144.5
Release:        0.5%{?dist}
Summary:        OpenAI coding agent command-line interface

# This is the upstream project license. The aggregate statically linked Cargo
# license expression remains a fail-closed packaging gate.
License:        Apache-2.0
URL:            https://github.com/openai/codex
Source0:        https://codeload.github.com/openai/codex/tar.gz/%{commit}#/%{name}-%{version}.tar.gz
Source1:        %{name}-%{version}-selected-cargo-closure.json
Source2:        %{name}-%{version}-selected-cargo-vendor-receipt.json
Source3:        %{name}-%{version}-cargo-resolver-supplement.json
Source4:        %{name}-%{version}-resolver-cargo-vendor-receipt.json
Source5:        %{name}-fedora-config.toml

# Fedora packaging: make doctor suppress its network version probe when the
# centrally managed update setting is disabled.
# Upstream status: not submitted; suitable for a focused upstream fix.
Patch0:         %{name}-doctor-update-setting.patch
# Fedora packaging: mark this downstream build as RPM-managed and suppress
# upstream self-update commands and recommendations.
# Upstream status: not submitted; Fedora-specific integration.
Patch1:         %{name}-fedora-update-policy.patch
# Fedora packaging: prevent the RPM build from running the standalone daemon
# installer and hourly downloader.
# Upstream status: not submitted; Fedora-specific integration.
Patch2:         %{name}-fedora-standalone-updater.patch

ExclusiveArch:  x86_64

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  rust >= 1.95

%description
Codex CLI is an open-source coding agent that runs in a terminal and integrates
with local developer tools.

This source-build draft is intentionally blocked. The selected Cargo closure
and separate resolver-only supplement materialize reproducibly and resolve
offline as evidence, but the combined archive is not an immutable RPM source or
approved license closure. The package must not produce an RPM until Cargo source
publication and integration, upstreamable V8 integration, license evidence,
and offline builds are proven.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{closure_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{vendor_receipt_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{resolver_supplement_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{resolver_vendor_receipt_sha256}  %{SOURCE4}" | sha256sum -c -
%autosetup -n codex-%{commit} -N
%autopatch -p1
test "$(grep -Fxc 'check_for_update_on_startup = false' %{SOURCE5})" -eq 1
echo "%{source_lock_sha256}  codex-rs/Cargo.lock" | sha256sum -c -
test "$(grep -cx 'version = "0\.0\.0"' codex-rs/Cargo.lock)" -eq 132
sed -i 's/^version = "0\.0\.0"$/version = "0.144.5"/' codex-rs/Cargo.lock
echo "%{normalized_lock_sha256}  codex-rs/Cargo.lock" | sha256sum -c -
echo 'codex-cli is blocked: see package.yml and dependencies.yml' >&2
exit 1

%build
export CODEX_DISTRIBUTION_CHANNEL=%{codex_distribution_channel}

%install
install -Dpm0644 %{SOURCE5} %{buildroot}%{_sysconfdir}/codex/config.toml

%files
%config(noreplace) %{_sysconfdir}/codex/config.toml

%changelog
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.5
- Make doctor honor disabled update checks and install the Fedora default.
- Disable upstream self-update recommendations and standalone daemon downloads in the Fedora build.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.4
- Record the separate 239-crate resolver-only normal/build source and license supplement.
- Reproduce the 1,124-source combined directory model and prove selected and all-target offline resolution.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.3
- Materialize the exact selected Cargo sources twice with identical tree, manifest, configuration, archive, and receipt hashes.
- Record the inactive-target Cargo resolver blocker and keep the package fail-closed.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.2
- Record the selected Linux Cargo closure and local source-built V8 runtime proof.
- Verify the release-specific Cargo.lock normalization with exact hash and count guards.
- Keep the package blocked pending upstreamable V8 integration, immutable sources, licenses, update policy, and offline Fedora builds.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.1
- Add a fail-closed draft for the released Codex CLI source.
