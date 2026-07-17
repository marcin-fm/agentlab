%global source_sha256 ca50615357e46ebf9597bb9065b9112367103ec24bd539f8ae12649224cf50b0

Name:           python-doclang
Version:        0.7.3
Release:        0.1%{?dist}
Summary:        Reference toolkit for the DocLang document markup format
License:        Apache-2.0
URL:            https://github.com/doclang-project/doclang
Source0:        https://files.pythonhosted.org/packages/f5/3a/005e4856ad8e9b9879414a4df4dbc56dc3663b96f9d8c920ef210e8931cf/doclang-%{version}.tar.gz
# Lower only the build-tool floor to Fedora 43's compatible setuptools.
# Fedora-specific; no matching upstream issue or pull request found as of 2026-07-17.
Patch0:         doclang-fedora-setuptools.patch

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(lxml) >= 4.8
BuildRequires:  python3dist(setuptools)
BuildRequires:  python3dist(typer) >= 0.15.1

%description
DocLang is an AI-native document markup format. This package provides the
reference Python toolkit, XML validation helpers, bundled XSD and Schematron
schema files, and the doclang command-line interface.

The optional Saxon-based processor extra is not packaged because it is not
required by the Docling consumer or the default runtime dependency set.

%package -n python3-doclang
Summary:        %{summary}

%description -n python3-doclang
DocLang is an AI-native document markup format. This package provides the
reference Python toolkit, bundled schema files, and command-line interface.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n doclang-%{version} -p1

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l doclang

%check
export PYTHONPATH=%{buildroot}%{python3_sitelib}
python3 - <<'PY'
from pathlib import Path
import doclang
from doclang._schemas import _bundled_schema_paths

xsd, schematron = _bundled_schema_paths()
assert xsd.is_file(), xsd
assert schematron.is_file(), schematron
assert doclang.__file__
PY
%{buildroot}%{_bindir}/doclang --help >/dev/null
cat > test-doclang.xmld <<'XML'
<doclang xmlns="https://www.doclang.ai/ns/v0">
  <text>Hello Fedora</text>
</doclang>
XML
%{buildroot}%{_bindir}/doclang validate --xsd-only test-doclang.xmld
rm -f test-doclang.xmld

%files -n python3-doclang -f %{pyproject_files}
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/doclang

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.7.3-0.1
- Initial Fedora package for DocLang.
