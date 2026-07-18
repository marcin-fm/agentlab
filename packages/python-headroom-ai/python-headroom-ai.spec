%global upstream_commit 4381388d56f49af3ae9b1dece7489a12fa64a1a1
%global source_sha256 6bb138a038d9a74c3a9b51bcc593d996054cf9eca95fc39df9e0e80c3944ddce
%bcond check 1

Name:           python-headroom-ai
Version:        0.32.0
Release:        0.5%{?dist}
Summary:        Context compression toolkit and MCP server

# Candidate from the scoped source probe; regenerate the selected closure in
# Fedora 43 and Fedora 44 buildroots before treating this as publication-ready.
License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0
URL:            https://github.com/headroomlabs-ai/headroom
Source0:        https://github.com/headroomlabs-ai/headroom/archive/%{upstream_commit}/headroom-%{upstream_commit}.tar.gz
# Packaging-only feature propagation: upstream headroom-core defaults to ML,
# but headroom-py cannot disable that dependency default. Not submitted yet;
# retain only while upstream lacks a forwarding feature or default opt-out.
Patch0:         headroom-disable-default-ml.patch
# Fedora compatibility adaptation: use the available rusqlite 0.31 branch and
# system SQLite instead of the upstream bundled 0.32 branch. Not submitted;
# behavior and exact dependency closure still require clean buildroot proof.
Patch1:         headroom-system-rusqlite.patch
# Fedora cargo2rpm 0.3.3 inventories every workspace member and its package
# selector is broken. Narrow the packaging workspace to the built extension and
# core library. This is Fedora-tooling-specific and is not an upstream change.
Patch2:         headroom-python-workspace.patch

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  gcc
BuildRequires:  pkgconfig(sqlite3)
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  rust >= 1.80

%description
Headroom compresses AI-agent context and exposes command-line and Model Context
Protocol integrations. This blocked Fedora draft selects the released non-ML
Rust path without redefining Headroom's upstream command surface.

%package -n python3-headroom-ai
Summary:        %{summary}
Requires:       python3dist(mcp) >= 1
Requires:       python3dist(httpx) >= 0.24
Requires:       python3dist(starlette) >= 0.27
Requires:       python3dist(uvicorn) >= 0.23
Requires:       python3dist(uvicorn) < 1

%description -n python3-headroom-ai
Headroom compresses AI-agent context and exposes command-line and Model Context
Protocol integrations. This blocked Fedora draft selects the released non-ML
Rust path without redefining Headroom's upstream command surface.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n headroom-%{upstream_commit} -p1
%cargo_prep

%generate_buildrequires
pushd crates/headroom-py >/dev/null
%cargo_generate_buildrequires -n -f extension-module
popd >/dev/null
%if %{with check}
pushd crates/headroom-core >/dev/null
%cargo_generate_buildrequires -n
popd >/dev/null
%endif
%pyproject_buildrequires -x mcp

%build
export MATURIN_PEP517_ARGS="--no-default-features --features extension-module"
%pyproject_wheel
pushd crates/headroom-py >/dev/null
%cargo_license_summary -n -f extension-module
%cargo_license -n -f extension-module > ../../LICENSE.dependencies
popd >/dev/null
test -s LICENSE.dependencies

%install
%pyproject_install
%pyproject_save_files -l headroom

%if %{with check}
%check
pushd crates/headroom-core >/dev/null
%cargo_test -n
popd >/dev/null
export PYTHONPATH=%{buildroot}%{python3_sitearch}
extension=$(find %{buildroot}%{python3_sitearch}/headroom -name '_core*.so' -print -quit)
test -n "$extension"
if ldd "$extension" | grep -q 'libsqlite3.so'; then
  ldd "$extension" | grep -Eq '/(usr/)?lib64/libsqlite3\.so'
fi
! readelf -d "$extension" | grep -Eq 'RPATH|RUNPATH'
%{python3} - <<'PY'
import headroom
import headroom._core
PY
%endif

%files -n python3-headroom-ai -f %{pyproject_files}
%license LICENSE NOTICE LICENSE.dependencies
%doc README.md
%{_bindir}/headroom

%changelog
* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.32.0-0.5
- Scope Cargo license accounting to the native extension and record its candidate aggregate SPDX expression.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.32.0-0.4
- Re-scope the blocked draft to the released upstream non-ML feature boundary.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.31.0-0.3
- Record the substantive-rework hold for the downstream feature patches.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.31.0-0.2
- Restore exact local OpenAI tokenization through tiktoken-rs 0.11.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.31.0-0.1
- Add the Fedora MCP-minimal source build.
