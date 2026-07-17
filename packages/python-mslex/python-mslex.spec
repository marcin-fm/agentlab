%global source_sha256 641c887d1d3db610eee2af37a8e5abda3f70b3006cdfd2d0d29dc0d1ae28a85d

Name:           python-mslex
Version:        1.3.0
Release:        0.2%{?dist}
Summary:        Windows command-line quoting and splitting for Python
License:        Apache-2.0
URL:            https://github.com/smoofra/mslex
Source0:        https://files.pythonhosted.org/packages/e0/97/7022667073c99a0fe028f2e34b9bf76b49a611afd21b02527fbfd92d4cd5/mslex-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(pytest)
BuildRequires:  python3dist(setuptools)
BuildRequires:  python3dist(wheel)

%description
mslex provides Windows command-line splitting, quoting, and joining functions
with behavior matching the Microsoft C runtime conventions.

%package -n python3-mslex
Summary:        %{summary}

%description -n python3-mslex
mslex provides Windows command-line splitting, quoting, and joining functions
with behavior matching the Microsoft C runtime conventions.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%setup -q -n mslex-%{version}

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l mslex

%check
%pytest -q

%files -n python3-mslex -f %{pyproject_files}
%license LICENSE
%doc README.rst AUTHORS.rst
%{_bindir}/mslex-split

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.3.0-0.2
- Document the expanded COPR architecture and Rawhide target matrix.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 1.3.0-0.1
- Initial Fedora package.
