%global source_sha256 a2e3ac73c051476625ec3f540c523553be2086282d3808c3f32979067a070ee6
%global source_audit_sha256 e6110883c400e12e859f04c0a2a1542746897be22493ddb2000f24edeac15e88

Name:           xberg
Version:        1.0.1
Release:        0.3%{?dist}
Summary:        Document intelligence toolkit

License:        MIT
URL:            https://github.com/xberg-io/xberg
Source0:        https://github.com/xberg-io/xberg/archive/refs/tags/v%{version}.tar.gz
Source1:        %{name}-%{version}-source-audit.json

%description
Xberg is a document intelligence toolkit. This source-package draft is
intentionally blocked pending a fresh Fedora dependency, license, native
binding, and offline-build audit for upstream Xberg v1.0.1.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{source_audit_sha256}  %{SOURCE1}" | sha256sum -c -
echo 'xberg is blocked: fresh upstream and Fedora source-build review required' >&2
exit 1

%changelog
* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.3
- Distinguish historical lock observations from a selected Xberg closure.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.2
- Record the released-source audit boundary and retain the fail-closed draft.

* Tue Jul 28 2026 Marcin FM <marcin@lgic.pl> - 1.0.1-0.1
- Add a fail-closed blocked draft for upstream Xberg v1.0.1.
