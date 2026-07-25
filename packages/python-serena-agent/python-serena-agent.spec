# Disabled by package.yml. This spec deliberately aborts before unpacking or
# building until an upstream-supported selected surface replaces the removed
# downstream product and security restrictions.
%global source_sha256 5e87906cc32271e816b159748204df3c76ea4ac8af64b14e80f417008dbeb4b6

Name:           python-serena-agent
Version:        1.6.1
Release:        0.1%{?dist}
Summary:        MCP toolkit for semantic code retrieval and editing

License:        MIT
URL:            https://github.com/oraios/serena
Source0:        https://files.pythonhosted.org/packages/56/b3/d722048c005d5e5d8b709e2a1395d899e486a77cd74d07ce7e8f07e2adc3/serena_agent-%{version}.tar.gz
%description
Serena is an MCP toolkit for semantic code retrieval, editing, refactoring,
and diagnostics through language-server backends.

This draft must not produce an RPM until the selected package surface uses
upstream-supported configuration without downstream product or security
restrictions and its complete Fedora dependency graph is reviewed.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo 'python-serena-agent is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.6.1-0.1
- Update released source evidence and block the package after removing downstream product restrictions.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 1.6.0-0.3
- Add a focused Python 3.15 metadata compatibility patch for Rawhide.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.6.0-0.2
- Document the downstream security-profile patch purpose and status.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.6.0-0.1
- Package the latest released headless stdio MCP server.
