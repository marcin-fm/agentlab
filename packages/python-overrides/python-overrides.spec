%global source_sha256 55158fa3d93b98cc75299b1e67078ad9003ca27945c76162c1c0766d6f91820a

Name:           python-overrides
Version:        7.7.0
Release:        0.1%{?dist}
Summary:        Decorators for detecting method override mismatches
License:        Apache-2.0
URL:            https://github.com/mkorpela/overrides
Source0:        https://files.pythonhosted.org/packages/36/86/b585f53236dec60aba864e050778b25045f857e17f6e5ea0ae95fe80edd2/overrides-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(pytest)
BuildRequires:  python3dist(setuptools)
BuildRequires:  python3dist(wheel)

%description
The overrides package provides decorators that detect mismatches when a method
is intended to override a method inherited from a base class.

%package -n python3-overrides
Summary:        %{summary}

%description -n python3-overrides
The overrides package provides decorators that detect mismatches when a method
is intended to override a method inherited from a base class.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%setup -q -n overrides-%{version}

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l overrides

%check
%pytest -q

%files -n python3-overrides -f %{pyproject_files}
%license LICENSE
%doc README.rst

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 7.7.0-0.1
- Initial Fedora package.
