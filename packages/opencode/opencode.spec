# Disabled by package.yml until Bun and the audited npm source closure are
# available. Do not replace these inputs with upstream platform binaries.
%global source_sha256 494041aedd7407079f91fd694de355f4ff022ba6bf876e09ff30983bbdc70ae1
%global bun_pty_commit 41dd5b887f3f47d7c307fd93f828a75dbee97d5a
%global bun_pty_source_sha256 d4731314a00c46d3810fa08b94ee0bcddb7a5026e47dbca88c83449d351bff9e
%global bun_pty_vendor_sha256 5c22d4bd79109a3460f3a3d3840d2541da9a6c4c91513c39065a1f4611b7ec5e
%global bun_pty_vendor_manifest_sha256 d57a66c2a1e90516e0b103b3074001f96cefcb4adb4ecc8c3a5532a2c884e500

Name:           opencode
Version:        1.18.3
Release:        0.5%{?dist}
Summary:        Open-source AI coding agent

# MIT covers OpenCode itself. Final license metadata must reflect OpenCode and
# the audited package-local source closure.
License:        MIT
URL:            https://github.com/anomalyco/opencode
Source0:        https://github.com/anomalyco/opencode/archive/refs/tags/v%{version}.tar.gz
Source1:        %{name}-%{version}-nm-prod-build.tar.zst
Source2:        %{name}-%{version}-nm-dev-test.tar.zst
Source3:        %{name}-%{version}-closure.json
Source4:        %{name}-%{version}-bundled-licenses.txt
Source5:        %{name}-%{version}-native.json
Source6:        https://github.com/sursaone/bun-pty/archive/%{bun_pty_commit}/bun-pty-%{bun_pty_commit}.tar.gz
Source7:        %{name}-%{version}-bun-pty-cargo-vendor.tar.zst
Source8:        %{name}-%{version}-bun-pty-cargo-vendor.txt

# Fedora omits the optional prebuilt FFF accelerator and selects OpenCode's
# existing system-ripgrep fallback instead.
# Upstream status: Fedora-specific; https://github.com/anomalyco/opencode/pull/31566
# added the fallback, and commit e4300e9b7433e068c3d57ac41fcb39bc5de3d32e
# supports disabling FFF.
Patch0:         opencode-disable-fff.patch

ExclusiveArch:  x86_64

BuildRequires:  bun = 1.3.14
BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  nodejs24-devel
BuildRequires:  nodejs24-npm
BuildRequires:  python3
BuildRequires:  coreutils
BuildRequires:  tar
BuildRequires:  zstd
Requires:       ripgrep

# The final executable embeds these modules but installs no Node module tree,
# so Fedora's automatic Node generator cannot run. This block is generated
# from Source3 by scripts/generate-node-bundled-provides.
# BEGIN GENERATED BUNDLED NODE PROVIDES
# END GENERATED BUNDLED NODE PROVIDES

%description
OpenCode is an open-source coding agent with a terminal user interface, local
server, and provider integrations.

This draft is intentionally excluded from COPR until every source-build and
license gate recorded in package.yml is complete.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n opencode-%{version} -p1

test -f %{SOURCE1}
test -f %{SOURCE3}
test -f %{SOURCE4}
test -f %{SOURCE5}
test -f %{SOURCE6}
test -f %{SOURCE7}
test -f %{SOURCE8}
echo "%{bun_pty_source_sha256}  %{SOURCE6}" | sha256sum -c -
echo "%{bun_pty_vendor_sha256}  %{SOURCE7}" | sha256sum -c -
echo "%{bun_pty_vendor_manifest_sha256}  %{SOURCE8}" | sha256sum -c -
python3 -m json.tool %{SOURCE3} >/dev/null
python3 -m json.tool %{SOURCE5} >/dev/null
cp -p %{SOURCE4} .
tar --extract --zstd --file %{SOURCE1}

# The npm package carries the released JS wrapper but only prebuilt Rust
# libraries. Replace that directory with the exact Git source and vendor input.
pushd packages/opencode >/dev/null
bun_pty="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("bun-pty/package.json")))')"
popd >/dev/null
rm -rf "$bun_pty/rust-pty"
mkdir -p .bun-pty-source
tar --extract --gzip --file %{SOURCE6} --strip-components=1 --directory .bun-pty-source
test ! -e .bun-pty-source/rust-pty/target
cp -a .bun-pty-source/rust-pty "$bun_pty/rust-pty"
tar --extract --zstd --file %{SOURCE7} --directory "$bun_pty/rust-pty"
pushd "$bun_pty/rust-pty" >/dev/null
%cargo_prep -v cargo-vendor
popd >/dev/null

%build
export CI=1
export OPENCODE_DISABLE_AUTOUPDATE=1
export BUN_INSTALL_CACHE_DIR="$PWD/.bun-cache"

# Build bun-pty with Fedora's offline Cargo profile. The prep macro preserves
# the target/release symlink expected by bun-pty's static Bun import.
pushd packages/opencode >/dev/null
bun_pty="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("bun-pty/package.json")))')"
popd >/dev/null
pushd "$bun_pty/rust-pty" >/dev/null
%cargo_build
%{cargo_license_summary}
%{cargo_license} > LICENSE.dependencies
%cargo_vendor_manifest
test "$(wc -l < cargo-vendor.txt)" -eq 43
cmp cargo-vendor.txt %{SOURCE8}
popd >/dev/null
cp -p "$bun_pty/rust-pty/LICENSE.dependencies" bun-pty-LICENSE.dependencies
cp -p "$bun_pty/rust-pty/cargo-vendor.txt" bun-pty-cargo-vendor.txt

# Rebuild the required Parcel watcher from the authenticated main-package
# sources and replace the published platform payload before Bun embeds it.
pushd packages/opencode >/dev/null
parcel_source="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("@parcel/watcher/package.json")))')"
parcel_platform="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("@parcel/watcher-linux-x64-glibc/package.json")))')"
popd >/dev/null
pushd "$parcel_source" >/dev/null
node-24 /usr/lib/node_modules_24/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --nodedir=/usr
popd >/dev/null
install -pm0755 "$parcel_source/build/Release/watcher.node" "$parcel_platform/watcher.node"

# The source closure is reconstructed before this point. Network-backed
# package resolution and lifecycle scripts are not permitted here.
bun run packages/opencode/script/build.ts --single --skip-install --skip-embed-web-ui

%check
test -f %{SOURCE2}
mkdir -p .test-dependencies
tar --extract --zstd --directory .test-dependencies --file %{SOURCE2}
pushd packages/opencode >/dev/null
bun_pty="$(node-24 -e 'process.stdout.write(require("path").dirname(require.resolve("bun-pty/package.json")))')"
popd >/dev/null
test -f "$bun_pty/rust-pty/target/release/librust_pty.so"
test "$(sha256sum "$bun_pty/rust-pty/target/release/librust_pty.so" | cut -d' ' -f1)" != a135c3d9f41d09a555e3e4609e0c80fa0ba035736c56791b9df3b55e6376438d
packages/opencode/dist/opencode-linux-x64/bin/opencode --version

%install
install -Dpm0755 \
  packages/opencode/dist/opencode-linux-x64/bin/opencode \
  %{buildroot}%{_bindir}/opencode

%files
%license LICENSE %{name}-%{version}-bundled-licenses.txt
%license bun-pty-LICENSE.dependencies bun-pty-cargo-vendor.txt
%doc README.md
%{_bindir}/opencode

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.5
- Reconcile the current selected-source audit records.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.4
- Rebuild bun-pty from exact Git and vendored Cargo sources.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.3
- Rebuild the Parcel watcher from source before compiling the selected CLI.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.2
- Omit the FFF native accelerator and use the system-ripgrep fallback.
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.18.3-0.1
- Refresh the blocked source-build draft to released version 1.18.3.
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.18.1-0.0.2
- Correct the Node application bundling model and reserve manual bundled(nodejs-...) metadata.
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 1.18.1-0.0.1
- Update the blocked draft to released version 1.18.1.
* Tue Jul 14 2026 Marcin FM <marcin@lgic.pl> - 1.17.20-0.0.1
- Add a disabled source-build draft and record the missing dependency gates.
