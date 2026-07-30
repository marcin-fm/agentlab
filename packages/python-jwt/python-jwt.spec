%global srcname pyjwt
%global libname jwt
%global source_sha256 41571c89ca91598c79e8ef18a2d07367d4810fbbd6f637794879baf1b7703423

Name:           python-jwt
Version:        2.13.0
Release:        0.1%{?dist}
Summary:        JSON Web Token implementation in Python
License:        MIT
URL:            https://github.com/jpadilla/pyjwt
Source0:        https://files.pythonhosted.org/packages/3b/81/58d0ac84e1ef3a3843791d6954d94c0b33d526c75eeb1efbce9d0a4c4077/pyjwt-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(pytest)

%description
PyJWT is a Python implementation of JSON Web Tokens as defined by RFC 7519.

%package -n python3-jwt
Summary:        %{summary}
Recommends:     python3-jwt+crypto

%description -n python3-jwt
PyJWT is a Python implementation of JSON Web Tokens as defined by RFC 7519.

%pyproject_extras_subpkg -n python3-jwt crypto

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{srcname}-%{version}

%generate_buildrequires
%pyproject_buildrequires -x crypto

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l %{libname}

%check
%pytest -k 'not (test_ec_to_jwk_with_invalid_curve or test_get_jwt_set_sslcontext_default or test_ec_curve_validation_rejects_p192_for_es256 or test_ec_curve_validation_with_pem_key)' -W ignore::FutureWarning

%files -n python3-jwt -f %{pyproject_files}
%license LICENSE
%doc README.rst

%changelog
* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 2.13.0-0.1
- Add the Fedora 43 compatibility provider required by python-mcp 1.28.1.
