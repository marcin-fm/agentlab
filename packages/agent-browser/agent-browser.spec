%bcond check 1
%global source_sha256 313e7706485c246b818a2138dabc6f8784f91bfa25cae7db445e6ca14c730022
%global cargo_closure_sha256 1517ea537c6e160fa03567d4c6c2b82aa01721b4964d652205b7981d2b36c6a6
%global cargo_vendor_receipt_sha256 5ad99b32aedb5744ade04726aa09ad760b1e68d0faa4acef4d3d9a8c45f06138
%global cargo_license_audit_sha256 68070a97b47e8107b635e48adb79e7f1e903115ff8d70bbbdfbfa0ecf81ee778
%global cargo_vendor_manifest_sha256 be6d14be1b89eed71091e1184a9ba69d9477d21a9668747effb5689ba2ec9be8
%global cargo_auditor_sha256 2705c8e05455e594350a751fb9ce59a5ad52ce5f53f2eb8e7925c3b2d692877a

Name:           agent-browser
Version:        0.33.1
Release:        0.8%{?dist}
Summary:        Browser automation CLI for AI agents

# Apache-2.0 is the project source license. This disabled proof spec does not
# assert a final binary expression until the recorded link/payload gates pass.
License:        Apache-2.0
URL:            https://github.com/vercel-labs/agent-browser
Source0:        https://github.com/vercel-labs/agent-browser/archive/refs/tags/v%{version}.tar.gz
Source1:        %{name}-%{version}-cargo-closure.json
Source2:        %{name}-%{version}-cargo-vendor-receipt.json
Source3:        %{name}-%{version}-license-audit.json
Source4:        %{name}-%{version}-cargo-vendor.tar.zst
Source5:        %{name}-%{version}-cargo-vendor.txt
Source6:        audit-agent-browser-cargo-closure

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  ruby
BuildRequires:  rubypick
BuildRequires:  rubygem-json
BuildRequires:  zstd
Requires:       chromium

%description
Native Rust browser automation CLI for AI agents.

This package is a blocked source-build draft. It is intended to install the
source-built binary below %{_libexecdir}/agent-browser, the upstream skills/
and skill-data/ directories, and a public %{_bindir}/agent-browser command.
It must not use npm postinstall prebuilt downloads, Chrome for Testing
downloads, or package-manager mutation during RPM phases.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{cargo_closure_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{cargo_vendor_receipt_sha256}  %{SOURCE2}" | sha256sum -c -
echo "%{cargo_license_audit_sha256}  %{SOURCE3}" | sha256sum -c -
echo "%{cargo_vendor_manifest_sha256}  %{SOURCE5}" | sha256sum -c -
echo "%{cargo_auditor_sha256}  %{SOURCE6}" | sha256sum -c -
%autosetup -n agent-browser-%{version} -N
echo "afa68d9dc97647e34be8ae1b62ae2a977dae0e09266e7780fd08ff17a4b74ffb  cli/Cargo.lock" | sha256sum -c -
install -Dm0755 %{SOURCE6} .agentlab-source/audit-agent-browser-cargo-closure
tar --zstd --extract --no-same-owner --no-same-permissions --file %{SOURCE4} --directory cli
ruby .agentlab-source/audit-agent-browser-cargo-closure --verify --vendor-dir cli/cargo-vendor --receipt %{SOURCE2}
pushd cli >/dev/null
%cargo_prep -v cargo-vendor
%cargo_vendor_manifest
cmp cargo-vendor.txt %{SOURCE5}
popd >/dev/null

%build
pushd cli >/dev/null
%cargo_build_crate
popd >/dev/null

%install
install -Dpm0755 cli/target/rpm/agent-browser %{buildroot}%{_libexecdir}/agent-browser/bin/agent-browser
install -d -m0755 %{buildroot}%{_libexecdir}/agent-browser
cp -a skills skill-data %{buildroot}%{_libexecdir}/agent-browser/
install -d -m0755 %{buildroot}%{_bindir}
ln -s %{_libexecdir}/agent-browser/bin/agent-browser %{buildroot}%{_bindir}/agent-browser
install -Dpm0644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE
install -Dpm0644 cli/src/native/a11y/LICENSE-axe-core.txt %{buildroot}%{_licensedir}/%{name}/LICENSE-axe-core.txt
install -Dpm0644 cli/src/native/a11y/LICENSE-axe-core-THIRD-PARTY.txt %{buildroot}%{_licensedir}/%{name}/LICENSE-axe-core-THIRD-PARTY.txt
install -Dpm0644 cli/src/native/react/installHook.js %{buildroot}%{_licensedir}/%{name}/React-DevTools-MIT-notice.js
install -Dpm0644 cli/cargo-vendor.txt %{buildroot}%{_licensedir}/%{name}/cargo-vendor.txt
install -Dpm0644 cli/LICENSE.dependencies %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies

%check
%if %{with check}
# Browser-required tests must be identified from a COPR proof before excluding
# them; do not preemptively skip the ordinary locked Cargo test suite.
pushd cli >/dev/null
%cargo_test
target/rpm/agent-browser --help >/dev/null
popd >/dev/null
%endif
echo 'agent-browser proof intentionally fails after compile/tests: final linked-license, installed-payload, and Chromium runtime gates remain unproven.' >&2
exit 1

%files
%license %{_licensedir}/%{name}/LICENSE
%license %{_licensedir}/%{name}/LICENSE-axe-core.txt
%license %{_licensedir}/%{name}/LICENSE-axe-core-THIRD-PARTY.txt
%license %{_licensedir}/%{name}/React-DevTools-MIT-notice.js
%license %{_licensedir}/%{name}/cargo-vendor.txt
%license %{_licensedir}/%{name}/LICENSE.dependencies
%{_bindir}/agent-browser
%{_libexecdir}/agent-browser

%changelog
* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.8
- Require JSON support for the Cargo vendor verifier.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.7
- Require the Ruby command selector for the Cargo vendor verifier.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.6
- Require Ruby for the Cargo vendor verifier.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.5
- Fix configured-SCM Source0 archive discovery.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.4
- Verify the generated Cargo vendor tree without archive-byte identity.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.3
- Make the blocked remote Cargo proof fail closed after checks.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.2
- Add reproducible Cargo source closure and source-build proof recipe.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.1
- Add a fail-closed Fedora source-build draft for agent-browser 0.33.1.
