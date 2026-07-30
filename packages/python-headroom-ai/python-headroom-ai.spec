%global source_sha256 97d817e5923903d72bed24f75e0424e9cb7f86b3ddde0fc1acec4f3f85deeb5a
%global selected_license_audit_sha256 3f8a0af6f859a553b6619b531c000dc805a4a8ba785e60768d1343faad2b2d71
%global unicode_license_sha256 74db5baf44a41b1000312c673544b3374e4198af5605c7f9080a402cec42cfa3
%global headroom_binary_license Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016
%bcond check 1

Name:           python-headroom-ai
Version:        0.33.0
Release:        0.2%{?dist}
Summary:        Context compression toolkit and MCP server

# Selected linked Rust closure from the exact released non-ML source graph.
# The configured target build regenerates LICENSE.dependencies from this graph.
License:        %{headroom_binary_license}
URL:            https://github.com/chopratejas/headroom
Source0:        https://files.pythonhosted.org/packages/87/2c/d3aeeb62d8f61430c9cf5b84c1bd0227362e43eaaaf710d6bb1759fec153/headroom_ai-%{version}.tar.gz
Source1:        headroom-%{version}-selected-cargo-license-audit.json
# Packaging-only feature selection: upstream headroom-core defaults to ML and
# Cargo metadata resolves even unselected optional dependencies. Propagate the
# non-ML choice and remove only unselected ML/Redis dependency declarations.
# Not submitted; retain while upstream lacks a metadata-clean non-ML surface.
Patch0:         headroom-disable-default-ml.patch
# Fedora compatibility adaptation: use the available rusqlite 0.31 branch and
# system SQLite instead of the upstream bundled 0.32 branch. Not submitted;
# behavior and exact dependency closure still require clean buildroot proof.
Patch1:         headroom-system-rusqlite.patch
# Fedora 43/44/Rawhide do not package Criterion 0.5. It is referenced only by
# upstream benchmark targets, which RPM builds do not run. Keep proptest,
# tempfile, all Cargo tests, and the installed Python smokes. Fedora-specific;
# not submitted because this removes development-only benchmark coverage.
Patch2:         headroom-drop-benchmark-dev-dependency.patch
# Fedora ships the required ast-grep CLI from source. Remove only the upstream
# PyPI binary-wheel dependency and require the system executable instead.
# Fedora-specific; not submitted because upstream supports pip environments.
Patch3:         headroom-system-ast-grep.patch

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
Requires:       python3dist(mcp) >= 1.28.1
Requires:       python3dist(mcp) < 2
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
echo "%{selected_license_audit_sha256}  %{SOURCE1}" | sha256sum -c -
%autosetup -n headroom_ai-%{version} -p1
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
%{python3} - "%{SOURCE1}" LICENSE.dependencies "%{headroom_binary_license}" <<'PY'
import json
import re
import sys
from pathlib import Path

audit = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

def canonicalize(line):
    return re.sub(r"^(.+: headroom-core v0\.1\.0) \(.*\)$", r"\1", line.strip())

actual = sorted({
    canonicalize(line)
    for line in Path(sys.argv[2]).read_text(encoding="utf-8").splitlines()
    if line.strip()
})

def normalize(expression):
    return expression.replace(" / ", "/").replace("/", " OR ")

records = audit["records"]
expected = sorted({
    f"{normalize(item['cargo_license_expression'])}: {item['name']} v{item['version']}"
    for item in records
})
if len(records) != 217 or len(expected) != 217:
    raise SystemExit("selected Cargo license receipt does not contain 217 unique records")
if audit["candidate_binary_spdx"] != sys.argv[3]:
    raise SystemExit("selected Cargo license expression differs from the spec")
if actual != expected:
    missing = sorted(set(expected) - set(actual))
    unexpected = sorted(set(actual) - set(expected))
    raise SystemExit(f"LICENSE.dependencies differs: missing={missing!r} unexpected={unexpected!r}")
if audit["validation"].get("target_license_dependencies_comparison_implemented") is not True:
    raise SystemExit("selected Cargo license receipt does not require the implemented target comparison")
Path(sys.argv[2]).write_text("\n".join(actual) + "\n", encoding="utf-8")
PY

unicode_license=/usr/share/cargo/registry/regex-syntax-0.8.11/src/unicode_tables/LICENSE-UNICODE
echo "%{unicode_license_sha256}  ${unicode_license}" | sha256sum -c -
install -pm0644 "${unicode_license}" LICENSE.regex-syntax-unicode

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
%license LICENSE NOTICE LICENSE.dependencies LICENSE.regex-syntax-unicode
%doc README.md
%{_bindir}/headroom

%changelog
* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 0.33.0-0.2
- Add the exact tree-sitter 0.25.2 compatibility provider.

* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 0.33.0-0.1
- Update to the complete published 0.33.0 PyPI sdist.
- Rebase the non-ML and system ast-grep metadata patches.

* Fri Jul 24 2026 Marcin FM <marcin@lgic.pl> - 0.32.1-0.1
- Update to the complete published PyPI sdist and use the upstream-narrowed workspace.

* Fri Jul 24 2026 Marcin FM <marcin@lgic.pl> - 0.32.0-0.10
- Correct the linked Rust license expression for Unicode-DFS-2016.

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
