# Disabled by package.yml until Bun and the audited npm source closure are
# available. Do not replace these inputs with upstream platform binaries.
%global source_sha256 494041aedd7407079f91fd694de355f4ff022ba6bf876e09ff30983bbdc70ae1

Name:           opencode
Version:        1.18.3
Release:        0.2%{?dist}
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

# Fedora omits the optional prebuilt FFF accelerator and selects OpenCode's
# existing system-ripgrep fallback instead.
# Upstream status: Fedora-specific; https://github.com/anomalyco/opencode/pull/31566
# added the fallback, and commit e4300e9b7433e068c3d57ac41fcb39bc5de3d32e
# supports disabling FFF.
Patch0:         opencode-disable-fff.patch

ExclusiveArch:  x86_64

BuildRequires:  bun = 1.3.14
BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  nodejs-devel
BuildRequires:  nodejs-packaging
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
python3 -m json.tool %{SOURCE3} >/dev/null
python3 -m json.tool %{SOURCE5} >/dev/null
cp -p %{SOURCE4} .
tar --extract --zstd --file %{SOURCE1}

%build
export CI=1
export OPENCODE_DISABLE_AUTOUPDATE=1
export BUN_INSTALL_CACHE_DIR="$PWD/.bun-cache"

# The source closure is reconstructed before this point. Network-backed
# package resolution and lifecycle scripts are not permitted here.
bun run packages/opencode/script/build.ts --single

%check
test -f %{SOURCE2}
mkdir -p .test-dependencies
tar --extract --zstd --directory .test-dependencies --file %{SOURCE2}
packages/opencode/dist/opencode-linux-x64/bin/opencode --version

%install
install -Dpm0755 \
  packages/opencode/dist/opencode-linux-x64/bin/opencode \
  %{buildroot}%{_bindir}/opencode

%files
%license LICENSE %{name}-%{version}-bundled-licenses.txt
%doc README.md
%{_bindir}/opencode

%changelog
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
