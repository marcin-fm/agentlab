%global source_sha256 a2c19e63519e49f993d93103481934b772db701c80c683900476f898dfac841a

Name:           python-docling-core
Version:        2.87.1
Release:        0.2%{?dist}
Summary:        Core document types and serialization for Docling
License:        MIT
URL:            https://github.com/docling-project/docling-core
Source0:        https://files.pythonhosted.org/packages/6c/36/96e3c029d8e018403e178e1d68b2135b63413c1a3ed4c39a56fec032d265/docling_core-%{version}.tar.gz
# Declare the standard setuptools backend omitted from the published sdist metadata.
# Not submitted upstream; no matching issue or pull request found as of 2026-07-17.
Patch0:         docling-core-setuptools-backend.patch
# Declare requests for the installed CLI file resolver's unconditional import.
# Not submitted upstream; no matching issue or pull request found as of 2026-07-17.
Patch1:         docling-core-add-requests.patch

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  python3dist(pytest)
BuildRequires:  python3dist(setuptools)

%description
docling-core defines the validated document model, conversion helpers, schema
data, and command-line utilities shared by Docling applications. Optional
chunking, model, and text processing features are not part of this base
package.

%package -n python3-docling-core
Summary:        %{summary}

%description -n python3-docling-core
docling-core provides the validated document model, conversion helpers,
schema data, and command-line utilities shared by Docling applications.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n docling_core-%{version} -p1

%generate_buildrequires
%pyproject_buildrequires

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l docling_core

%check
%pytest -q \
  test/test_base.py \
  test/test_data_gen_flag.py \
  test/test_doc_base.py \
  test/test_otsl_table_export.py \
  test/test_page.py \
  test/test_regions_to_table.py

export PYTHONPATH=%{buildroot}%{python3_sitelib}
python3 - <<'PY'
from pathlib import Path
from tempfile import TemporaryDirectory

from docling_core.transforms.serializer.doclang import DocLangDocSerializer
from docling_core.types.doc import DocItemLabel, DoclingDocument

doc = DoclingDocument(name="fedora-smoke")
doc.add_text(label=DocItemLabel.TEXT, text="Hello Fedora")
with TemporaryDirectory() as directory:
    output = Path(directory) / "document.json"
    doc.save_as_json(output)
    loaded = DoclingDocument.load_from_json(output)
    assert loaded.texts[0].text == "Hello Fedora"

serialized = DocLangDocSerializer(doc=doc).serialize().text
assert "<doclang" in serialized, serialized
PY
%{buildroot}%{_bindir}/docling-serialize --help >/dev/null
%{buildroot}%{_bindir}/docling-view --help >/dev/null

%files -n python3-docling-core -f %{pyproject_files}
%license LICENSE
%doc README.md
%{_bindir}/docling-serialize
%{_bindir}/docling-view

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.87.1-0.2
- Document the build metadata patches and their upstream status.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.87.1-0.1
- Initial Fedora package for docling-core.
