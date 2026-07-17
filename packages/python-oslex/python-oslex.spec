%global source_sha256 30d9f4a7201bdce3ab7d9cfc0f9ee9e18c423b2b1d1668141b0dd3594b368ffe

Name:           python-oslex
Version:        2.0.0
Release:        0.1%{?dist}
Summary:        OS-independent command-line quoting wrapper
License:        MIT
URL:            https://github.com/petamas/oslex
Source0:        https://files.pythonhosted.org/packages/24/19/b74ea9590378a35014acf72f221e84c5980aa7531d1852ef961764e7d3a6/oslex-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(hatchling)
BuildRequires:  python3dist(mslex) >= 1.3
BuildRequires:  python3dist(mslex) < 2
BuildRequires:  python3dist(pytest)

%description
oslex provides an OS-independent wrapper for POSIX and Windows command-line
parsing.

%package -n python3-oslex
Summary:        %{summary}
Requires:       python3dist(mslex) >= 1.3
Requires:       python3dist(mslex) < 2

%description -n python3-oslex
oslex provides an OS-independent wrapper for POSIX and Windows command-line
parsing.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%setup -q -n oslex-%{version}
sed -i 's/\r$//' README.md

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l oslex

%check
%pytest -q

%files -n python3-oslex -f %{pyproject_files}
%license LICENSE
%doc README.md

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.0.0-0.1
- Initial Fedora package draft; blocked on the missing mslex provider.
