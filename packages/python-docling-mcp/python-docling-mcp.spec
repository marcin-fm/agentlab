%global source_sha256 46ea64354ae6b7e5956e5f93da62b4329906766cf1f130314ace8eefb4c058c7

Name:           python-docling-mcp
Version:        2.1.0
Release:        0.2%{?dist}
Summary:        Stdio Docling document-generation MCP server
License:        MIT
URL:            https://github.com/docling-project/docling-mcp
Source0:        https://files.pythonhosted.org/packages/e3/bc/59f74a19ac66ddebfe2bee76f8f5c6b208f9dd1fe96fff5d020720985f5d/docling_mcp-%{version}.tar.gz
Source1:        docling-mcp-remote-smoke.py
Patch0:         docling-mcp-stdio-generation.patch
Patch1:         docling-mcp-remote-conversion.patch

BuildArch:       noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(hatchling)
BuildRequires:  python3dist(pydantic-settings) >= 2.4

%description
Docling MCP exposes Docling document creation and manipulation tools through a
local stdio Model Context Protocol server. HTTP transports, conversion tools,
remote services, local models, and runtime model downloads are excluded.

%package -n python3-docling-mcp-remote-conversion
Summary:        Opt-in Docling Serve conversion tools for Docling MCP
Requires:       python-docling-mcp = %{version}-%{release}
Requires:       python3dist(docling-slim[service-client]) >= 2.113
Requires:       python3dist(pydantic-settings) >= 2.4

%description -n python3-docling-mcp-remote-conversion
Opt-in stdio-only remote conversion tools for an administrator-configured
Docling Serve endpoint and upload root. This optional package does not provide
local conversion, directory conversion, model execution, or URL-source
submission.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n docling_mcp-%{version} -p1

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files docling_mcp

%check
export PYTHONPATH=%{buildroot}%{python3_sitelib}
export DOCLING_MCP_BASE_SERVER=%{buildroot}%{_bindir}/docling-mcp-server
export DOCLING_MCP_REMOTE_SERVER=%{buildroot}%{_bindir}/docling-mcp-remote-conversion
python3 %{SOURCE1}

%files -f %{pyproject_files}
%license LICENSE
%doc README.md
%{_bindir}/docling-mcp-server
%exclude %{python3_sitelib}/docling_mcp/servers/remote_conversion_server.py
%exclude %{python3_sitelib}/docling_mcp/servers/__pycache__/remote_conversion_server.*.pyc
%exclude %{python3_sitelib}/docling_mcp/settings/remote_service.py
%exclude %{python3_sitelib}/docling_mcp/settings/__pycache__/remote_service.*.pyc
%exclude %{python3_sitelib}/docling_mcp/tools/remote_conversion.py
%exclude %{python3_sitelib}/docling_mcp/tools/__pycache__/remote_conversion.*.pyc

%files -n python3-docling-mcp-remote-conversion
%{_bindir}/docling-mcp-remote-conversion
%{python3_sitelib}/docling_mcp/servers/remote_conversion_server.py
%{python3_sitelib}/docling_mcp/servers/__pycache__/remote_conversion_server.*.pyc
%{python3_sitelib}/docling_mcp/settings/remote_service.py
%{python3_sitelib}/docling_mcp/settings/__pycache__/remote_service.*.pyc
%{python3_sitelib}/docling_mcp/tools/remote_conversion.py
%{python3_sitelib}/docling_mcp/tools/__pycache__/remote_conversion.*.pyc

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.2
- Add an opt-in bounded remote-conversion stdio subpackage.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.1
- Package the stdio generation and manipulation MCP surface.
