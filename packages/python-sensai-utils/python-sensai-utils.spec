%global source_sha256 2ca709a0d5807caf1632d665a455c173987b25276ce61693021672e875f0f17b

Name:           python-sensai-utils
Version:        1.5.0
Release:        0.1%{?dist}
Summary:        General-purpose utility modules from sensAI
License:        MIT
URL:            https://github.com/opcode81/sensAI-utils
Source0:        https://files.pythonhosted.org/packages/8c/dd/faa2e2de71a03af3def212c70777e794dd54ad5ab87927bb5c29f85f24fc/sensai_utils-%{version}.tar.gz
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
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.5.0-0.1
- Initial Fedora package.
