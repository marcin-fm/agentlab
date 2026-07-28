%bcond check 1
%global source_sha256 313e7706485c246b818a2138dabc6f8784f91bfa25cae7db445e6ca14c730022
%global cargo_closure_sha256 1517ea537c6e160fa03567d4c6c2b82aa01721b4964d652205b7981d2b36c6a6
%global cargo_vendor_receipt_sha256 64007acb028f36b99d30795bc19309055a1d926ba9c88ab848032a39f14321b2
%global cargo_license_audit_sha256 68070a97b47e8107b635e48adb79e7f1e903115ff8d70bbbdfbfa0ecf81ee778
%global cargo_vendor_manifest_sha256 ab25da7fe915f71771d9c5e3f78acb718557575bfdc96b1dfa5ac82aef0098e0
%global cargo_auditor_sha256 9abab1d177fa90a5d30b93f1eea54e9efa3d5a67564b57250b8ed3dfd9d43684
%global fedora_proof_sha256 ac566fd40dd6b9190bf596c92b76aa8dbf275d7712c4f848cdb58f223eb77028

Name:           agent-browser
Version:        0.33.1
Release:        0.13%{?dist}
Summary:        Browser automation CLI for AI agents

# The aggregate combines the cargo2rpm linked-license summary with the project,
# embedded axe-core, axe-core third-party, and React DevTools license boundaries.
License:        Apache-2.0 AND MPL-2.0 AND MIT AND ISC AND ((MIT OR Apache-2.0) AND NCSA) AND ((MIT OR Apache-2.0) AND Unicode-3.0) AND (0BSD OR MIT OR Apache-2.0) AND (Apache-2.0 AND ISC) AND (Apache-2.0 OR BSL-1.0) AND (Apache-2.0 OR ISC OR MIT) AND (Apache-2.0 OR MIT) AND (Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT) AND (BSD-2-Clause OR Apache-2.0 OR MIT) AND BSD-2-Clause AND (BSD-3-Clause OR Apache-2.0) AND BSD-3-Clause AND (CC0-1.0 OR Apache-2.0) AND CDLA-Permissive-2.0 AND (MIT OR Apache-2.0 OR LGPL-2.1-or-later) AND (MIT OR Apache-2.0 OR Zlib) AND (MIT OR Zlib OR Apache-2.0) AND (Unlicense OR MIT) AND (Zlib OR Apache-2.0 OR MIT) AND Zlib AND Unicode-3.0
URL:            https://github.com/vercel-labs/agent-browser
Source0:        https://github.com/vercel-labs/agent-browser/archive/refs/tags/v%{version}.tar.gz
Source1:        %{name}-%{version}-cargo-closure.json
Source2:        %{name}-%{version}-cargo-vendor-receipt.json
Source3:        %{name}-%{version}-license-audit.json
Source4:        %{name}-%{version}-cargo-vendor.tar.zst
Source5:        %{name}-%{version}-cargo-vendor.txt
Source6:        audit-agent-browser-cargo-closure
Source7:        %{name}-%{version}-fedora-proof.json

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  binutils
BuildRequires:  chromium
BuildRequires:  file
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
echo "%{fedora_proof_sha256}  %{SOURCE7}" | sha256sum -c -
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
install -d -m0700 .test-home
export HOME="$PWD/.test-home"
%cargo_test
target/rpm/agent-browser --help >/dev/null

license_file="$PWD/LICENSE.dependencies"
binary=%{buildroot}%{_libexecdir}/agent-browser/bin/agent-browser
public=%{buildroot}%{_bindir}/agent-browser
payload=%{buildroot}%{_libexecdir}/agent-browser

test "$(sha256sum "$license_file" | cut -d' ' -f1)" = b232a66a487cfb5c45519501e9e7e7c5cc7dfbc879b181c8a0f2fc5e3a2e0e06
test "$(wc -l < "$license_file")" -eq 264

test -x "$binary"
test -L "$public"
test "$(readlink "$public")" = "%{_libexecdir}/agent-browser/bin/agent-browser"
test -x "%{buildroot}$(readlink "$public")"
test -d "$payload/skills"
test -d "$payload/skill-data"
(
  cd %{buildroot}
  find ./usr/bin/agent-browser ./usr/libexec/agent-browser ./usr/share/licenses/agent-browser -printf '%%y %%m %%s %%p %%l\n'
) | LC_ALL=C sort >/dev/null

file "$binary"
readelf -h "$binary"
readelf -h "$binary" | grep -Eq 'Type:.*DYN'
readelf -d "$binary" > "$PWD/.agentlab-readelf-dynamic.txt"
if grep -Eq 'RPATH|RUNPATH' "$PWD/.agentlab-readelf-dynamic.txt"; then
  echo 'agent-browser proof found a forbidden RPATH or RUNPATH' >&2
  exit 1
fi
ldd -r "$binary" > "$PWD/.agentlab-ldd.txt"
if grep -Fq 'not found' "$PWD/.agentlab-ldd.txt"; then
  echo 'agent-browser proof found an unresolved dynamic dependency' >&2
  exit 1
fi

runtime_home=$(mktemp -d /tmp/agent-browser-copr-check.XXXXXX)
export HOME="$runtime_home"
export AGENT_BROWSER_SOCKET_DIR="$runtime_home/sockets"
install -d -m0700 "$AGENT_BROWSER_SOCKET_DIR"
cleanup_agent_browser_proof() {
  "$binary" --session copr-check close >/dev/null 2>&1 || :
  rm -rf "$runtime_home"
}
trap cleanup_agent_browser_proof EXIT
echo 'AGENT_BROWSER_CHROMIUM_SMOKE_BEGIN'
"$binary" --session copr-check --executable-path /usr/bin/chromium-browser --json open about:blank | grep -F '"url":"about:blank"'
"$binary" --session copr-check --json get url | grep -F '"url":"about:blank"'
"$binary" --session copr-check close
echo 'AGENT_BROWSER_CHROMIUM_SMOKE_END'
cleanup_agent_browser_proof
trap - EXIT
popd >/dev/null
%endif

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
* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.13
- Record the Fedora 44 x86_64 compile and runtime witness.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.12
- Emit linked-license, installed-payload, and system-Chromium proof evidence.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.11
- Export the isolated home directory for Cargo tests.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.10
- Use an isolated home directory for the Cargo test environment.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 0.33.1-0.9
- Generate the Cargo vendor manifest with Fedora cargo2rpm.

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
