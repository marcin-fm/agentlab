%global upstream_commit 4381388d56f49af3ae9b1dece7489a12fa64a1a1
%global source_sha256 6bb138a038d9a74c3a9b51bcc593d996054cf9eca95fc39df9e0e80c3944ddce
%bcond check 1

Name:           python-headroom-ai
Version:        0.32.0
Release:        0.9%{?dist}
Summary:        Context compression toolkit and MCP server

# Selected linked Rust closure from the exact released non-ML source graph.
# The configured target build regenerates LICENSE.dependencies from this graph.
License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0
URL:            https://github.com/headroomlabs-ai/headroom
Source0:        https://github.com/headroomlabs-ai/headroom/archive/%{upstream_commit}/headroom-%{upstream_commit}.tar.gz
# Packaging-only feature selection: upstream headroom-core defaults to ML and
# Cargo metadata resolves even unselected optional dependencies. Propagate the
# non-ML choice and remove only unselected ML/Redis dependency declarations.
# Not submitted; retain while upstream lacks a metadata-clean non-ML surface.
Patch0:         headroom-disable-default-ml.patch
# Fedora compatibility adaptation: use the available rusqlite 0.31 branch and
# system SQLite instead of the upstream bundled 0.32 branch. Not submitted;
# behavior and exact dependency closure still require clean buildroot proof.
Patch1:         headroom-system-rusqlite.patch
# Fedora cargo2rpm 0.3.3 inventories every workspace member and its package
# selector is broken. Narrow the packaging workspace to the built extension and
# core library. This is Fedora-tooling-specific and is not an upstream change.
Patch2:         headroom-python-workspace.patch
# Fedora 43/44/Rawhide do not package Criterion 0.5. It is referenced only by
# upstream benchmark targets, which RPM builds do not run. Keep proptest,
# tempfile, all Cargo tests, and the installed Python smokes. Fedora-specific;
# not submitted because this removes development-only benchmark coverage.
Patch3:         headroom-drop-benchmark-dev-dependency.patch
# Fedora ships the required ast-grep CLI from source. Remove only the upstream
# PyPI binary-wheel dependency and require the system executable instead.
# Fedora-specific; not submitted because upstream supports pip environments.
Patch4:         headroom-system-ast-grep.patch

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  gcc
BuildRequires:  pkgconfig(sqlite3)
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(fastapi) >= 0.100
BuildRequires:  rust >= 1.80

%description
Headroom compresses AI-agent context and exposes command-line and Model Context
Protocol interfaces. This Fedora package selects the released non-ML Rust
path without redefining Headroom's upstream command surface.

%package -n python3-headroom-ai
Summary:        %{summary}
Requires:       python3dist(fastapi) >= 0.100
Requires:       python3dist(mcp) >= 1
Requires:       python3dist(httpx) >= 0.24
Requires:       python3dist(starlette) >= 0.27
Requires:       python3dist(uvicorn) >= 0.23
Requires:       python3dist(uvicorn) < 1
Requires:       ast-grep >= 0.30.0

%description -n python3-headroom-ai
Headroom compresses AI-agent context and exposes command-line and Model Context
Protocol interfaces. This Fedora package selects the released non-ML Rust
path without redefining Headroom's upstream command surface.

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
%{cargo_license -n -f extension-module} > ../../LICENSE.dependencies
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
sqlite_test=$(find target/rpm/deps -maxdepth 1 -type f -name 'ccr_backends-*' -perm -0100 -print -quit)
test -n "$sqlite_test"
ldd "$sqlite_test" | grep -Eq '/(usr/)?lib64/libsqlite3\.so'
extension=$(find %{buildroot}%{python3_sitearch}/headroom -name '_core*.so' -print -quit)
test -n "$extension"
! readelf -d "$extension" | grep -Eq 'RPATH|RUNPATH'
nm -D --defined-only "$extension" | grep -Eq ' PyInit__core$'
PYTHONSAFEPATH=1 %{python3} -P - <<'PY'
import tempfile
from pathlib import Path

import headroom
import headroom._core
from headroom.cache.backends.sqlite import SQLiteBackend

with tempfile.TemporaryDirectory() as directory:
    backend = SQLiteBackend(Path(directory) / "ccr.db")
    assert backend.count() == 0
PY
PYTHONSAFEPATH=1 PYTHONPATH=%{buildroot}%{python3_sitearch} %{buildroot}%{_bindir}/headroom --help >/dev/null
%endif

%files -n python3-headroom-ai -f %{pyproject_files}
%license LICENSE NOTICE LICENSE.dependencies
%doc README.md
%{_bindir}/headroom

%changelog
* Thu Jul 23 2026 Marcin FM <marcin@lgic.pl> - 0.32.0-0.9
- Select the system ast-grep CLI and remove unselected optional native metadata.

* Thu Jul 23 2026 Marcin FM <marcin@lgic.pl> - 0.32.0-0.8
- Remove the unavailable benchmark-only Criterion dependency.

* Thu Jul 23 2026 Marcin FM <marcin@lgic.pl> - 0.32.0-0.7
- Select the released non-ML upstream surface and require system SQLite proof.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 0.32.0-0.6
- Correct repository validation evidence for intentional Rawhide-only packages.

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
