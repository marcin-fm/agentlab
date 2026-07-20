# Adapted from Fedora's golang-github-evanw-esbuild package.
%bcond_without check

%global goipath         github.com/evanw/esbuild
%global source_sha256   65c756fa87d43178ac4a5242454c2bd0fde325f8ecf77997f8fa4b88f94d5cd2
Version:                0.28.1

%gometa -L -f

%global common_description %{expand:
This is a JavaScript bundler and minifier. It packages up JavaScript and
TypeScript code for distribution on the web.}

%global golicenses      LICENSE.md
%global godocs          docs CHANGELOG.md README.md version.txt

Name:           golang-github-evanw-esbuild
Release:        0.2%{?dist}
Summary:        Fast JavaScript bundler and minifier

License:        MIT
URL:            %{gourl}
Source0:        %{gosource}

BuildRequires:  nodejs
BuildRequires:  nodejs-devel

%description %{common_description}

%gopkg

%package -n nodejs-esbuild
Summary:        ESBuild Node.js module
Requires:       %{name}%{?_isa} = %{version}-%{release}

%description -n nodejs-esbuild %{common_description} (JavaScript library)

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum --check --strict -
%goprep -A

%generate_buildrequires
%go_generate_buildrequires

%build
%gobuild -o %{gobuilddir}/bin/esbuild %{goipath}/cmd/esbuild

# Generate the public JavaScript module with the source-built executable.
%{__nodejs} scripts/esbuild.js %{gobuilddir}/bin/esbuild --neutral

%install
%gopkginstall
install -m 0755 -vd                     %{buildroot}%{_bindir}
install -m 0755 -vp %{gobuilddir}/bin/* %{buildroot}%{_bindir}/

node_platform=$(%{__nodejs} -p 'process.platform + "-" + process.arch')
install -m 0755 -vd %{buildroot}%{nodejs_sitelib}/esbuild
cp -pr npm/esbuild/lib %{buildroot}%{nodejs_sitelib}/esbuild/
install -m 0644 -vp npm/esbuild/package.json \
  %{buildroot}%{nodejs_sitelib}/esbuild/

install -m 0755 -vd \
  %{buildroot}%{nodejs_sitelib}/@esbuild/${node_platform}/bin
install -m 0644 -vp npm/@esbuild/${node_platform}/package.json \
  %{buildroot}%{nodejs_sitelib}/@esbuild/${node_platform}/
ln -s %{_bindir}/esbuild \
  %{buildroot}%{nodejs_sitelib}/@esbuild/${node_platform}/bin/esbuild

%if %{with check}
%check
%gocheck

# Exercise the same package selection used by npm consumers without running
# the upstream installer or downloading a platform binary.
node_platform=$(%{__nodejs} -p 'process.platform + "-" + process.arch')
install -m 0755 -vd npm/@esbuild/${node_platform}/bin
ln -sfn %{gobuilddir}/bin/esbuild npm/@esbuild/${node_platform}/bin/esbuild
NODE_PATH="$PWD/npm" %{__nodejs} - <<'EOF'
const esbuild = require('./npm/esbuild')
if (esbuild.version !== '0.28.1') throw new Error(`unexpected version: ${esbuild.version}`)
const result = esbuild.transformSync('const value: number = 6 * 7', { loader: 'ts' })
if (!result.code.includes('const value = 6 * 7')) throw new Error(result.code)
EOF
%{gobuilddir}/bin/esbuild --version | grep -Fx '%{version}'
%endif

%files
%license LICENSE.md
%doc docs CHANGELOG.md README.md
%{_bindir}/esbuild

%gopkgfiles

%files -n nodejs-esbuild
%{nodejs_sitelib}/esbuild
%{nodejs_sitelib}/@esbuild

%changelog
* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.28.1-0.2
- Require the Node.js runtime explicitly for Fedora 43 builds

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.28.1-0.1
- Adapt Fedora's package to exact esbuild 0.28.1 for Playwright builds
- Verify the immutable source and test the source-built Node.js module offline
