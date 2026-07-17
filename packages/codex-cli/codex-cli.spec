# Disabled by package.yml. This spec deliberately aborts before compilation
# until the selected Linux source closure and Fedora integration are proven.
%global source_sha256 b3472ef0b53e9b6191e19f51f491f818749671b9cb1b8dbe51466dc2702abcd9
%global commit 87db9bc18ba5bc82c1cb4e4381b44f693ee35623

Name:           codex-cli
Version:        0.144.5
Release:        0.1%{?dist}
Summary:        OpenAI coding agent command-line interface

# Apache-2.0 covers Codex. The provisional aggregate also records the vendored
# Bubblewrap sources until their final system-source treatment is decided.
License:        Apache-2.0 AND LGPL-2.0-or-later
URL:            https://github.com/openai/codex
Source0:        https://codeload.github.com/openai/codex/tar.gz/%{commit}#/%{name}-%{version}.tar.gz

ExclusiveArch:  x86_64

BuildRequires:  cargo-rpm-macros
BuildRequires:  rust >= 1.95

%description
Codex CLI is an open-source coding agent that runs in a terminal and integrates
with local developer tools.

This source-build draft is intentionally blocked. It must not produce an RPM
until the selected Linux Cargo closure, Git sources, native sandbox sources,
license evidence, Fedora update policy, and offline builds are proven.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo 'codex-cli is blocked: see package.yml and dependencies.yml' >&2
exit 1

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.144.5-0.1
- Add a fail-closed draft for the released Codex CLI source.
