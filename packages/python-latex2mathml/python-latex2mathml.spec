%global source_sha256 4b959cdc3cac8686bc0e3e5aece8127dfb1b81ca1241bed8e00ef31b82bb4022
%global license_sha256 4ac1e1da07f6b343d54191c5e1716840534e08591b3f9eaec90d6800cdc47543
%global lppl_sha256 3d262cdf34dafa6955f703c634a8c238ec44109bc8dd6ef34fb7aa54809f7e66

Name:           python-latex2mathml
Version:        3.81.0
Release:        0.2%{?dist}
Summary:        Convert LaTeX math expressions to MathML
License:        MIT AND LPPL-1.3c
URL:            https://github.com/roniemartinez/latex2mathml
Source0:        https://files.pythonhosted.org/packages/3b/62/35bb816c5c19d4d0cde5bdfb82ebb996306243d5f94e03f201658c629960/latex2mathml-%{version}.tar.gz
Source1:        https://raw.githubusercontent.com/roniemartinez/latex2mathml/605e02726eca5a77bb07395631fde9e0acacdbab/LICENSE#/latex2mathml-LICENSE
Source2:        https://www.latex-project.org/lppl/lppl-1-3c.txt#/LPPL-1.3c.txt
# Build the unchanged Python payload with a backend available in Fedora 43 and 44.
# Fedora-specific; upstream intentionally selected uv_build in https://github.com/roniemartinez/latex2mathml/pull/574.
Patch0:         latex2mathml-use-hatchling.patch

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(hatchling) >= 1.27

%description
latex2mathml is a pure Python library and command-line interface that converts
LaTeX mathematical expressions into MathML. The package includes the Unicode
math symbol mapping required by the converter.

%package -n python3-latex2mathml
Summary:        %{summary}

%description -n python3-latex2mathml
latex2mathml is a pure Python library and command-line interface that converts
LaTeX mathematical expressions into MathML.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{license_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{lppl_sha256}  %{SOURCE2}" | sha256sum -c -
%autosetup -n latex2mathml-%{version} -p1

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -L latex2mathml
rm -f %{buildroot}%{_bindir}/l2m
ln -s latex2mathml %{buildroot}%{_bindir}/l2m
install -Dpm 0644 %{SOURCE1} %{buildroot}%{_licensedir}/%{name}/LICENSE
install -pm 0644 %{SOURCE2} %{buildroot}%{_licensedir}/%{name}/LPPL-1.3c.txt

%check
export PYTHONPATH=%{buildroot}%{python3_sitelib}
python3 - <<'PY'
from pathlib import Path

from latex2mathml.converter import convert
from latex2mathml.symbols_parser import SYMBOLS_FILE

mathml = convert(r"\frac{1}{2}")
assert "<mfrac>" in mathml, mathml
symbols = Path(SYMBOLS_FILE)
assert symbols.is_file(), symbols
assert "LaTeX Project Public License" in symbols.read_text(encoding="utf-8")
PY
%{buildroot}%{_bindir}/latex2mathml --version | grep -F '%{version}'
%{buildroot}%{_bindir}/l2m -t '\frac{1}{2}' | grep -F '<mfrac>'

%files -n python3-latex2mathml -f %{pyproject_files}
%license %{_licensedir}/%{name}/LICENSE
%license %{_licensedir}/%{name}/LPPL-1.3c.txt
%doc README.md
%{_bindir}/latex2mathml
%{_bindir}/l2m

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 3.81.0-0.2
- Document the Fedora build-backend substitution and upstream status.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 3.81.0-0.1
- Initial Fedora package for latex2mathml.
