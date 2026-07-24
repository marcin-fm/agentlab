%bcond tests 1

%global source_sha256 d3757817029a666ecd2191b0f571b140177cb62f6588248fc6e97610f3356152

Name:           python-click
Epoch:          1
Version:        8.3.3
Release:        1.1%{?dist}
Summary:        Flexible command-line interface toolkit

License:        BSD-3-Clause
URL:            https://github.com/pallets/click
Source0:        %{url}/archive/%{version}/click-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  python%{python3_pkgversion}-devel

%global _description %{expand:
Click is a Python package for building command-line interfaces with good
defaults and a highly configurable API.}

%description %{_description}

%package -n python%{python3_pkgversion}-click
Summary:        %{summary}

%description -n python%{python3_pkgversion}-click %{_description}

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n click-%{version} -p1

%generate_buildrequires
%pyproject_buildrequires %{?with_tests:-g tests}

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files click

%check
%pyproject_check_import
%if %{with tests}
%pytest
%endif

%files -n python%{python3_pkgversion}-click -f %{pyproject_files}
%license LICENSE.txt
%doc README.md CHANGES.rst

%changelog
* Thu Jul 23 2026 Marcin FM <marcin@lgic.pl> - 8.3.3-1.1
- Adapt Fedora's current Click branch for Fedora 43 Headroom builds.
