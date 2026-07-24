# Disabled by package.yml. This spec remains proof-only until the production
# build and final static-consumer license closure are proven.
%bcond check 1
%global codex_distribution_channel fedora

%global source_sha256 b3472ef0b53e9b6191e19f51f491f818749671b9cb1b8dbe51466dc2702abcd9
%global closure_sha256 b5be10ceca68a9185c5ae9b9369415bac2040dfd059059636757b759773708c3
%global vendor_receipt_sha256 047d9e62f570c6887696a579bf40617c70c800ae8d810328d9e15bed401c0b0e
%global resolver_supplement_sha256 51eab69c077b119435029d2e225d9839ff332b0e471d5270282e418b815e1876
%global resolver_vendor_receipt_sha256 9d20d17d7e649f822413033e417e4fb6060598cb86bd76649ce1e2a137480355
%global license_audit_sha256 b13315e6e6442605b05b921c2832b1a990869c56f4381abd9b91b121f69b2426
%global source_lock_sha256 175793a40a3147db1fee08fd9db0acc59312c344b3513dd7ee316f5446d8119e
%global patched_lock_sha256 cedc827a0f1a411000c9042e639cf230d72fbb0c36a824aa61ea0640f9587636
%global normalized_lock_sha256 8c2217fa79ef815a5ee5b25e54573928dbf73a9953397b76d404e38cc820ff33
%global cargo_audit_sha256 23787eaca470511c874a8a4479cc4bbe4b7f18a1ac91dbd671b5cd309cdaaefe
%global source_preparer_sha256 946dd1864478fcba5af2a695997b73385f36650d5eff4fdbcd6f5b4eaa176324
%global vendor_verifier_sha256 147b9f9ba99a477905a632b6d6b3dbd5baaf32a071acd8dc3b4cec5b6bb3b8e0
%global license_text_receipt_sha256 7f5fc635a0d9a1b901c5684f0d49e6a100b2fafb2408497d58a868570cce45fd
%global supplemental_license_receipt_sha256 770df1349e90ec39eff515443f9a8556d86e105038b631346fabf484c3b1e0af
%global supplemental_license_preparer_sha256 90e7d74a314a9fa00e57a1ebf980b5c3f57d06d50940db11fb637f39357b270d
%global commit 87db9bc18ba5bc82c1cb4e4381b44f693ee35623

Name:           codex-cli
Version:        0.144.5
Release:        0.21%{?dist}
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
Source6:        %{name}-%{version}-selected-cargo-license-audit.json
Source7:        audit-codex-cargo-closure
Source8:        prepare-codex-cargo-srpm-sources
Source9:        codex_cargo_vendor.rb
Source10:       %{name}-%{version}-resolver-cargo-vendor.tar.gz
Source11:       %{name}-%{version}-resolver-cargo-vendor.txt
Source12:       %{name}-%{version}-resolver-cargo-vendor.config.toml
Source13:       %{name}-%{version}-cargo-license-text-inventory.json
Source14:       %{name}-%{version}-cargo-supplemental-license-sources.json
Source15:       %{name}-%{version}-cargo-supplemental-license-sources.tar.gz
Source16:       prepare-codex-cargo-license-sources

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
# Fedora packaging: select the first released rust-openssl pair with OpenSSL 4
# support while preserving the released Codex dependency graph.
# Upstream status: released in openssl 0.10.78 and openssl-sys 0.9.114 via
# https://github.com/sfackler/rust-openssl/pull/2591
Patch3:         %{name}-openssl-4.patch

ExclusiveArch:  x86_64

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  pkgconfig(openssl)
BuildRequires:  rust >= 1.95
BuildRequires:  ruby
BuildRequires:  ruby-default-gems
BuildRequires:  rubygem-json
BuildRequires:  rusty-v8-static(abi) = 149.2.0

%description
Codex CLI is an open-source coding agent that runs in a terminal and integrates
with local developer tools.

This source-build draft is intentionally blocked. Its repository-backed source
builder materializes the selected Cargo closure and resolver-only supplement as
a semantically verified offline source, but the selected-aware Cargo audit's
873 Linux-linked packages now have complete checked license-text mappings. The
package must not produce an RPM until final Fedora SPDX and aggregate license
approval, the Rusty V8 static consumer closure, the build/install/test flow,
and offline Fedora builds are proven.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{closure_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{vendor_receipt_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{resolver_supplement_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{resolver_vendor_receipt_sha256}  %{SOURCE4}" | sha256sum -c -
echo "%{license_audit_sha256}  %{SOURCE6}" | sha256sum -c -
%autosetup -n codex-%{commit} -N
echo "%{source_lock_sha256}  codex-rs/Cargo.lock" | sha256sum -c -
%autopatch -p1
echo "%{patched_lock_sha256}  codex-rs/Cargo.lock" | sha256sum -c -
test "$(grep -Fxc 'check_for_update_on_startup = false' %{SOURCE5})" -eq 1
test "$(grep -cx 'version = "0\.0\.0"' codex-rs/Cargo.lock)" -eq 132
sed -i 's/^version = "0\.0\.0"$/version = "0.144.5"/' codex-rs/Cargo.lock
echo "%{normalized_lock_sha256}  codex-rs/Cargo.lock" | sha256sum -c -
echo "%{cargo_audit_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{source_preparer_sha256}  %{SOURCE8}" | sha256sum -c -
echo "%{vendor_verifier_sha256}  %{SOURCE9}" | sha256sum -c -
echo "%{license_text_receipt_sha256}  %{SOURCE13}" | sha256sum -c -
echo "%{supplemental_license_receipt_sha256}  %{SOURCE14}" | sha256sum -c -
echo "%{supplemental_license_preparer_sha256}  %{SOURCE16}" | sha256sum -c -
install -d -m0755 .agentlab-codex-source-tools/lib
install -pm0755 %{SOURCE8} .agentlab-codex-source-tools/prepare-codex-cargo-srpm-sources
install -pm0644 %{SOURCE9} .agentlab-codex-source-tools/lib/codex_cargo_vendor.rb
install -pm0755 %{SOURCE16} .agentlab-codex-source-tools/prepare-codex-cargo-license-sources
ruby .agentlab-codex-source-tools/prepare-codex-cargo-srpm-sources \
  --check \
  --source-dir "$PWD" \
  --archive %{SOURCE10} \
  --manifest %{SOURCE11} \
  --config %{SOURCE12} \
  --receipt %{SOURCE4} \
  --closure %{SOURCE1} \
  --supplement %{SOURCE3} \
  --license-audit %{SOURCE6} \
  --license-texts %{SOURCE13} \
  --work-dir-root %{_tmppath}
ruby .agentlab-codex-source-tools/prepare-codex-cargo-license-sources \
  --check \
  --receipt %{SOURCE14} \
  --archive %{SOURCE15} \
  --vendor-archive %{SOURCE10} \
  --cache-dir %{_tmppath}/codex-supplemental-license-cache \
  --offline-cache
tar --extract --gzip --file %{SOURCE15} --directory codex-rs
tar --extract --gzip --file %{SOURCE10} --directory codex-rs
pushd codex-rs >/dev/null
%cargo_prep -N
cat %{SOURCE12} >> .cargo/config.toml
%{__cargo_to_rpm} -p %{SOURCE11} parse-vendor-manifest > cargo-bundled-provides.txt
test "$(wc -l < cargo-bundled-provides.txt)" -eq 1124
install -pm0644 %{SOURCE11} cargo-vendor.txt
cmp cargo-vendor.txt %{SOURCE11}
popd >/dev/null
%build
export CODEX_DISTRIBUTION_CHANNEL=%{codex_distribution_channel}
export RUSTY_V8_ARCHIVE=%{_libdir}/rust-v8/149.2.0/librusty_v8.a
export GN_ARGS='use_custom_libcxx=false'
pushd codex-rs >/dev/null
%cargo_build -- -vv --package codex-cli --bin codex
popd >/dev/null

%install
install -Dpm0755 codex-rs/target/rpm/codex %{buildroot}%{_bindir}/codex
install -Dpm0644 %{SOURCE5} %{buildroot}%{_sysconfdir}/codex/config.toml
install -Dpm0644 codex-rs/cargo-vendor.txt %{buildroot}%{_licensedir}/%{name}/cargo-vendor.txt
install -d -m0755 %{buildroot}%{_licensedir}/%{name}/supplemental
install -pm0644 codex-rs/codex-cli-%{version}-supplemental-license-sources/*.txt %{buildroot}%{_licensedir}/%{name}/supplemental/

%check
%if %{with check}
export CODEX_DISTRIBUTION_CHANNEL=%{codex_distribution_channel}
export RUSTY_V8_ARCHIVE=%{_libdir}/rust-v8/149.2.0/librusty_v8.a
export GN_ARGS='use_custom_libcxx=false'
install -d -m0755 .codex-home
install -pm0644 %{SOURCE5} .codex-home/config.toml
CODEX_HOME="$PWD/.codex-home" codex-rs/target/rpm/codex --version
CODEX_HOME="$PWD/.codex-home" codex-rs/target/rpm/codex --help >/dev/null
CODEX_HOME="$PWD/.codex-home" codex-rs/target/rpm/codex doctor
%endif

%files
%license LICENSE
%license %{_licensedir}/%{name}/cargo-vendor.txt
%license %{_licensedir}/%{name}/supplemental/*.txt
%{_bindir}/codex
%config(noreplace) %{_sysconfdir}/codex/config.toml

%changelog
* Fri Jul 24 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.21
- Select released rust-openssl support for Fedora Rawhide OpenSSL 4.
- Keep the resolver-complete offline source and Rusty V8 contracts unchanged.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.20
- Retain the immutable bech32 0.11.0 crate transport checksum.
- Verify later-release license evidence during fresh SCM source generation.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.19
- Keep later-release archive evidence out of GitHub raw VCS reconstruction.
- Restore fresh configured-SCM supplemental source generation.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.18
- Add the system OpenSSL development metadata required by openssl-sys.
- Keep the offline source graph and Rusty V8 provider contract unchanged.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.17
- Use a buildroot-compatible temporary directory for supplemental license checks.
- Retry the first offline x86_64 production build without changing its source graph.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.16
- Start the first offline x86_64 production build against the Rusty V8 provider.
- Retain verbose Cargo linker evidence for the final static-consumer closure.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.15
- Use the five filed upstream requests with pinned canonical MIT and Apache-2.0 texts.
- Complete the linked Cargo license-text mapping while retaining final SPDX and native-static review.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.14
- Bind bech32 0.9.1's MIT text to the checked later 0.11.0 release and merged upstream fix.
- Retain five crates pending upstream license-text requests and final aggregate review.

* Tue Jul 21 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.13
- Reuse Fedora's exact rust-notify 8.2.0 CC0 license and payload precedent.
- Remove the redundant notify policy hold while retaining final aggregate review.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.12
- Resolve three additional Cargo license-text records from exact release history.
- Retain six crates pending upstream requests and keep final license approval blocked.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.11
- Add checked cargo-vcs, release-history, and canonical-standard provenance.
- Resolve eight supplemental Cargo license-text records while retaining nine holds.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.10
- Add checked supplemental Cargo license sources and ICU data comparison.
- Keep unresolved canonical-text, CC0-content, and native-static review blocked.
- Record the successful Rusty V8 x86_64 provider cells without clearing its remaining gates.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.9
- Inventory package-local Cargo license texts with exact graph roles.
- Define the package-scoped build, install, bundled Provides, and smoke checks.
- Keep execution blocked pending unresolved texts and Rusty V8 completion.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.8
- Generate the resolver-complete Cargo source through the repository SCM path.
- Verify the semantic vendor tree and prepare Fedora's offline Cargo metadata.
- Repair the ordered Fedora update-policy patch application.
- Keep compilation blocked pending licenses, Rusty V8 completion, and build proof.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.7
- Select the separate blocked Rusty V8 149.2.0 ABI provider contract.
- Match Codex's default crate feature to the system-libstdc++ archive link mode.
- Keep recursive V8 sources, native licenses, and offline provider builds gated.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.6
- Record the selected Linux and Fedora all-target Cargo license graphs.
- Keep native Rusty V8 license texts and the final aggregate License tag blocked.

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
