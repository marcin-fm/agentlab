# Disabled by package.yml. This spec deliberately aborts before unpacking or
# building until an upstream-supported selected surface replaces the removed
# downstream product and security profiles.
%global source_sha256 46ea64354ae6b7e5956e5f93da62b4329906766cf1f130314ace8eefb4c058c7

Name:           python-docling-mcp
Version:        2.1.0
Release:        0.6%{?dist}
Summary:        MCP server for Docling document processing

License:        MIT
URL:            https://github.com/docling-project/docling-mcp
Source0:        https://files.pythonhosted.org/packages/e3/bc/59f74a19ac66ddebfe2bee76f8f5c6b208f9dd1fe96fff5d020720985f5d/docling_mcp-%{version}.tar.gz

%description
Docling MCP exposes document conversion, generation, and manipulation tools
through multiple Model Context Protocol transports.

This draft must not produce an RPM until the selected package surface uses
upstream-supported configuration without downstream product or security
profiles and its complete Fedora dependency and transport graph is reviewed.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo 'python-docling-mcp is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Fri Jul 31 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.6
- Refresh the completed Docling Slim service-client provider reference.

* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.5
- Refresh the completed Docling Core and Slim provider references.

* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.4
- Block the package after removing downstream product and security profiles.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.3
- Document the downstream security-profile patch purpose and status.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.2
- Add an opt-in bounded remote-conversion stdio subpackage.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.1.0-0.1
- Package the stdio generation and manipulation MCP surface.
