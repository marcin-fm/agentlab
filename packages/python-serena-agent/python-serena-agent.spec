%global source_sha256 b547908dce45db62591f434156c016b2cc164306fe8d434e90f42f388befc440

Name:           python-serena-agent
Version:        1.6.0
Release:        0.2%{?dist}
Summary:        Headless MCP server for semantic code retrieval and editing
License:        MIT
URL:            https://github.com/oraios/serena
Source0:        https://files.pythonhosted.org/packages/31/5b/de5ebc95ac17909c25e2251e2b2bd8353e6db49c8c1d388cd0ccffb22e84/serena_agent-1.6.0.tar.gz
# Reduce dependencies and force headless local LSP operation without telemetry or downloads.
# Downstream security profile; upstream intentionally supports the omitted application surfaces.
Patch0:         serena-headless-fedora.patch
# Enforce stdio-only MCP and omit dashboard, project-server, JetBrains, and query surfaces.
# Downstream security profile; not submitted because upstream does not enforce this boundary.
Patch1:         serena-stdio-only-fedora.patch
BuildArch:       noarch

BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel

%description
Serena is an MCP server providing semantic code retrieval, editing, refactoring,
and diagnostics through system-provided language-server backends. This package
supports only the headless local stdio MCP server.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n serena_agent-%{version} -p1
rm -f src/serena/resources/config/modes/query-projects.yml
rm -f src/solidlsp/.gitignore
rm -f src/interprompt/.syncCommitId.remote src/interprompt/.syncCommitId.this

%generate_buildrequires
# Do not replace this with networked pip or uv resolution.
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l serena interprompt solidlsp
rm -f %{buildroot}%{_bindir}/serena-agent
ln -s serena %{buildroot}%{_bindir}/serena-agent
for context in ide jb-ai-assistant; do
    rm -f %{buildroot}%{python3_sitelib}/serena/resources/config/contexts/${context}.yml
    ln -s antigravity.yml %{buildroot}%{python3_sitelib}/serena/resources/config/contexts/${context}.yml
done

%check
PYTHONPATH=src %{python3} -m compileall -q src/serena src/solidlsp
PYTHONPATH=src %{python3} - <<'PY'
from types import SimpleNamespace

from serena.config.serena_config import LanguageBackend, SerenaConfig
from solidlsp.dependency_provider import LanguageServerDependencyProviderBaseCommand
from solidlsp.ls_utils import FileUtils

config = SerenaConfig().with_headless_mode_overrides()
assert not config.web_dashboard and not config.gui_log_window
assert config.language_backend is LanguageBackend.LSP
try:
    config.determine_language_backend(SimpleNamespace(language_backend=LanguageBackend.JETBRAINS))
except ValueError as error:
    assert "only the LSP" in str(error)
else:
    raise AssertionError("project configuration re-enabled the JetBrains backend")

try:
    FileUtils.download_file("https://example.invalid/never", "never")
except RuntimeError as error:
    assert "Fedora Serena" in str(error)
else:
    raise AssertionError("managed download was not blocked")

class LocalProvider(LanguageServerDependencyProviderBaseCommand):
    def _create_default_base_command(self):
        raise AssertionError("local override must bypass managed acquisition")
    def _create_launch_command_from_base_command(self, command):
        return command

assert LocalProvider({"ls_path": "/usr/bin/local-ls"}, ".").create_launch_command() == ["/usr/bin/local-ls"]
PY

export PYTHONPATH=%{buildroot}%{python3_sitelib}
export HOME="$PWD/.home"
mkdir -p "$HOME"
test ! -e %{buildroot}%{python3_sitelib}/serena/resources/config/modes/query-projects.yml
export SERENA_SERVER=%{buildroot}%{_bindir}/serena
%{python3} - <<'PY'
import asyncio
import os

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def smoke() -> None:
    server = StdioServerParameters(
        command=os.environ["SERENA_SERVER"],
        args=["start-mcp-server", "--transport", "stdio", "--context", "agent", "--open-web-dashboard", "False"],
        env=dict(os.environ),
    )
    async with stdio_client(server) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = {tool.name for tool in tools.tools}
            assert "get_current_config" in names
            assert "open_dashboard" not in names
            assert "query_project" not in names


asyncio.run(asyncio.wait_for(smoke(), timeout=30))
PY

%files -f %{pyproject_files}
%license LICENSE
%doc README.md
%{_bindir}/serena
%{_bindir}/serena-agent
%{_bindir}/serena-hooks

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.6.0-0.2
- Document the downstream security-profile patch purpose and status.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.6.0-0.1
- Package the latest released headless stdio MCP server.
