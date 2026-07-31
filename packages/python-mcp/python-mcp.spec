%global extras cli,rich,ws
%global source_sha256 d51e36a5f5644faea4f85ea649bfffa6bc6c26770d42798ad6a3de3d2ba69683

Name:           python-mcp
Version:        1.28.1
Release:        0.5%{?dist}
Summary:        Model Context Protocol SDK
License:        MIT
URL:            https://modelcontextprotocol.io
Source0:        https://files.pythonhosted.org/packages/6e/77/9450b8f251a13affb6281997d0523c4615f8a8b35d0b21ff30db3a5aac9d/mcp-%{version}.tar.gz

# Fedora 43 lacks python3-uv-dynamic-versioning; use hatch-vcs for the shared
# source build. Upstream v1.28.1 still uses uv-dynamic-versioning.
# Upstream status: Fedora-specific, not submitted.
Patch0:         replace-uv-dynamic-version-with-hatchling-vcs.diff
# Fedora's test environment exposes the built package through PYTHONPATH;
# propagate it to the temporary stdio-server subprocess.
# Upstream issue: https://github.com/modelcontextprotocol/python-sdk/issues/1027
Patch1:         pass-pythonpath-for-subprocess.diff

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  tomcli
BuildRequires:  python3-pytest
BuildRequires:  python3-pytest-xdist
BuildRequires:  python3-requests
BuildRequires:  python3-inline-snapshot
BuildRequires:  python3-dirty-equals

%description
The Model Context Protocol allows applications to provide context for LLMs in a
standardized way. This Python SDK implements the full MCP specification.

%package -n python3-mcp
Summary:        %{summary}

%description -n python3-mcp
The Model Context Protocol allows applications to provide context for LLMs in a
standardized way. This Python SDK implements the full MCP specification.

%pyproject_extras_subpkg -n python3-mcp %{extras}

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -N -n mcp-%{version}
%if 0%{?fedora} == 43
%patch -P 0 -p1
%endif
%patch -P 1 -p1

%generate_buildrequires
%pyproject_buildrequires -x %{extras}

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l mcp

%check
%pyproject_check_import
%pytest --ignore tests/test_examples.py -k "not test_command_execution"

%files -n python3-mcp -f %{pyproject_files}
%license LICENSE
%doc README.md SECURITY.md CODE_OF_CONDUCT.md
%{_bindir}/mcp

%changelog
* Fri Jul 31 2026 Marcin FM <marcin@lgic.pl> - 1.28.1-0.5
- Bind the MCP 2 audit to the selected Headroom source identity.

* Fri Jul 31 2026 Marcin FM <marcin@lgic.pl> - 1.28.1-0.4
- Bind the complete MCP 2 rejection contract and package release metadata.

* Fri Jul 31 2026 Marcin FM <marcin@lgic.pl> - 1.28.1-0.3
- Make the MCP 2 compatibility evidence fail closed under repository validation.

* Fri Jul 31 2026 Marcin FM <marcin@lgic.pl> - 1.28.1-0.2
- Record the fail-closed MCP 2.0.0 compatibility audit for Headroom 0.33.0.

* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 1.28.1-0.1
- Add the released MCP SDK required by python-headroom-ai 0.33.0.
