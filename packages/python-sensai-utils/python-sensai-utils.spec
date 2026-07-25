%global source_sha256 e50ae6bbd7c62a961f25b98e55b29029450efd66444678931b3b9c43e9bf9e95

Name:           python-sensai-utils
Version:        1.6.0
Release:        0.1%{?dist}
Summary:        General-purpose utility modules from sensAI
License:        MIT
URL:            https://github.com/opcode81/sensAI-utils
Source0:        https://files.pythonhosted.org/packages/75/5a/b0a1db8703754ec933b0b8288541ee585c13f7bd0684d8623da4271b374b/sensai_utils-%{version}.tar.gz
# Restore the sole runtime requirement omitted from the published 1.6.0 sdist.
# Source-artifact-specific; upstream repository includes requirements.txt, so this was not submitted.
Patch0:         sensai-utils-fix-missing-requirements.patch

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(pytest)
BuildRequires:  python3dist(setuptools)
BuildRequires:  python3dist(wheel)

%description
sensAI-utils contains the general-purpose utility modules shared by sensAI and
applications such as the Serena semantic coding MCP server.

%package -n python3-sensai-utils
Summary:        %{summary}

%description -n python3-sensai-utils
sensAI-utils contains the general-purpose utility modules shared by sensAI and
applications such as the Serena semantic coding MCP server.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%setup -q -n sensai_utils-%{version}
# The published sdist uses CRLF for setup.py; normalize it before applying the
# metadata repair so the patch remains reviewable and applies with zero fuzz.
sed -i 's/\r$//' setup.py README.md
%autopatch -p1

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l sensai

%check
%pytest -q

%files -n python3-sensai-utils -f %{pyproject_files}
%doc README.md

%changelog
* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 1.6.0-0.1
- Update to sensAI Utils 1.6.0.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.5.0-0.3
- Document the expanded COPR architecture and Rawhide target matrix.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.5.0-0.2
- Document the published-sdist metadata repair and upstream status.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.5.0-0.1
- Initial Fedora package.
