%bcond tests 1

%global source_sha256 d5635f9b7999806a02bd323fc7a9f8c4b1cb5f600b2967d4e7e5dbb106b1c216

Name:           python-click
Epoch:          1
Version:        8.4.2
Release:        0.1%{?dist}
Summary:        Flexible command-line interface toolkit

License:        BSD-3-Clause
URL:            https://github.com/pallets/click
Source0:        %{url}/archive/%{version}/click-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  python%{python3_pkgversion}-devel
%if %{with tests}
BuildRequires:  /usr/bin/less
%endif

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
%doc README.md CHANGES.md

%changelog
* Sat Jul 25 2026 Marcin FM <marcin@lgic.pl> - 8.4.2-0.1
- Update the Fedora 43 compatibility package to Click 8.4.2.

* Thu Jul 23 2026 Marcin FM <marcin@lgic.pl> - 8.3.3-1.1
- Adapt Fedora's current Click branch for Fedora 43 Headroom builds.
