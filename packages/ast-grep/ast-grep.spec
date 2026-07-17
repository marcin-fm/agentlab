%bcond check 1
%global crate ast-grep
%global source_sha256 a5a1eea64346853f5c911982f332f3e1fb670f18483d805d33686086dcce510f

Name:           ast-grep
Version:        0.44.1
Release:        0.1%{?dist}
Summary:        Structural code search, linting, and rewriting tool

License:        MIT AND Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND ISC AND MIT-0 AND Unicode-DFS-2016 AND LicenseRef-Fedora-Public-Domain
URL:            https://ast-grep.github.io/
Source0:        https://github.com/ast-grep/ast-grep/archive/refs/tags/%{version}.tar.gz
Patch0:         ast-grep-cli-workspace.patch

BuildRequires:  cargo-rpm-macros
BuildRequires:  gcc

%description
ast-grep is a command-line tool for structural code search, linting, and
rewriting using tree-sitter syntax trees.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -p1

# These upstream test fixtures are prebuilt shared libraries for language
# bindings that are not part of the native CLI package.
rm -f fixtures/json-linux.so fixtures/json-mac.so

%cargo_prep

%generate_buildrequires
cd crates/cli
%cargo_generate_buildrequires

%build
cd crates/cli
%cargo_build_crate

%check
%if %{with check}
cd crates/cli
%cargo_test
../../target/rpm/ast-grep --version
printf 'const answer = 42;\n' | ../../target/rpm/ast-grep --pattern 'const $A = $B' --lang javascript --stdin
%endif

%install
cd crates/cli
%cargo_install
rm -f %{buildroot}%{_bindir}/sg

install -Dpm0644 LICENSE.dependencies \
  %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies

install -d %{buildroot}%{bash_completions_dir}
%{buildroot}%{_bindir}/ast-grep completions bash > \
  %{buildroot}%{bash_completions_dir}/ast-grep

install -d %{buildroot}%{zsh_completions_dir}
%{buildroot}%{_bindir}/ast-grep completions zsh > \
  %{buildroot}%{zsh_completions_dir}/_ast-grep

install -d %{buildroot}%{fish_completions_dir}
%{buildroot}%{_bindir}/ast-grep completions fish > \
  %{buildroot}%{fish_completions_dir}/ast-grep.fish

%files
%license LICENSE
%license %{_licensedir}/%{name}/LICENSE.dependencies
%doc CHANGELOG.md README.md
%{_bindir}/ast-grep
%{bash_completions_dir}/ast-grep
%{zsh_completions_dir}/_ast-grep
%{fish_completions_dir}/ast-grep.fish

%changelog
* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.44.1-0.1
- Complete Fedora 43 and Fedora 44 source builds and dependency license audit.
- Build only the native CLI, omit the conflicting sg alias, and generate shell completions.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.44.1-0.0.1
- Add a blocked source-build draft for the native ast-grep CLI.
