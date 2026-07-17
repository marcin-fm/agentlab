%global source_sha256 34135ce73e82cce494483133752f54d97391351d4faa49fbf66c6058eb18329d

Name:           python-docling-slim
Version:        2.113.0
Release:        0.2%{?dist}
Summary:        Modular Docling framework with remote service client
License:        MIT
URL:            https://github.com/docling-project/docling
Source0:        https://files.pythonhosted.org/packages/22/35/149f23813b0df840945c99a2789f0a749431a23a6846d4da132de4bbda40/docling_slim-%{version}.tar.gz
# Keep the selected service-client extra API-only by omitting command-only dependencies.
# Fedora-specific package split; upstream CLI design is https://github.com/docling-project/docling/pull/3622.
Patch0:         docling-slim-service-client-api-only.patch

BuildArch:      noarch
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel

%description
docling-slim provides the modular Docling framework and remote service client
while excluding local PDF parsing, local model execution, model weights, OCR,
and other conversion extras.

%package -n python3-docling-slim
Summary:        %{summary}
Provides:       python3dist(docling-slim[service-client]) = %{version}
Requires:       python3dist(httpx) >= 0.28
Requires:       python3dist(httpx) < 1
Requires:       python3dist(websockets) >= 14
Requires:       python3dist(websockets) < 17

%description -n python3-docling-slim
docling-slim provides the modular Docling framework and remote Docling service
client without local model or PDF parser extras. Upstream command wrappers are
omitted because they import the excluded local PDF backend at startup.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n docling_slim-%{version} -p1

%generate_buildrequires
%pyproject_buildrequires -x service-client

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l docling
rm -f %{buildroot}%{_bindir}/docling
rm -f %{buildroot}%{_bindir}/docling-tools

%check
export PYTHONPATH=%{buildroot}%{python3_sitelib}
python3 - <<'PY'
import docling
from docling.datamodel.base_models import InputFormat
from docling.service_client import DoclingServiceClient

assert InputFormat.DOCX.value == "docx"
DoclingServiceClient("http://127.0.0.1:1")
PY

rm -f health-port
python3 - <<'PY' &
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/health":
            self.send_error(404)
            return
        payload = json.dumps({"status": "ok"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        pass

server = HTTPServer(("127.0.0.1", 0), Handler)
Path("health-port").write_text(str(server.server_port))
server.serve_forever()
PY
server_pid=$!
trap 'kill ${server_pid} 2>/dev/null || :' EXIT
for attempt in $(seq 1 50); do
  test -s health-port && break
  sleep 0.1
done
test -s health-port
python3 - <<'PY'
from pathlib import Path
from docling.service_client import DoclingServiceClient

port = Path("health-port").read_text().strip()
response = DoclingServiceClient(f"http://127.0.0.1:{port}").health()
assert response.status == "ok"
PY
kill ${server_pid}
wait ${server_pid} 2>/dev/null || :
trap - EXIT

%files -n python3-docling-slim -f %{pyproject_files}
%license LICENSE
%doc packages/docling-slim/README.md

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.113.0-0.2
- Document the API-only service-client patch and upstream design.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 2.113.0-0.1
- Initial Fedora package for the remote-service Docling surface.
