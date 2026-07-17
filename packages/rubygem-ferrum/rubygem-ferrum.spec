%global gem_name ferrum
%global source_sha256 2c2540a850b211a46f4d81de21bfd62048f507e4c327d1807225c3823c17e6ee

Name:           rubygem-ferrum
Version:        0.17.2
Release:        0.2%{?dist}
Summary:        Ruby headless Chrome driver

License:        MIT
URL:            https://github.com/rubycdp/ferrum
Source0:        https://rubygems.org/downloads/%{gem_name}-%{version}.gem

Requires:       ruby(release) >= 3.1
BuildRequires:  ruby(release)
BuildRequires:  rubygems-devel
BuildRequires:  ruby >= 3.1
BuildRequires:  rubygem(addressable) >= 2.5
BuildRequires:  rubygem(base64) >= 0.2
BuildRequires:  rubygem(concurrent-ruby) >= 1.1
BuildRequires:  rubygem(webrick) >= 1.7
BuildRequires:  rubygem(websocket-driver) >= 0.7
BuildRequires:  chromium-headless
BuildArch:      noarch

%description
Ferrum controls Chrome and Chromium browsers through the Chrome DevTools
Protocol. It provides a pure-Ruby browser automation API without Selenium or
an external driver executable.

%package doc
Summary:        Documentation for %{name}
Requires:       %{name} = %{version}-%{release}
BuildArch:      noarch

%description doc
Documentation for %{name}.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%setup -q -n %{gem_name}-%{version}

%build
gem build ../%{gem_name}-%{version}.gemspec
%gem_install

%install
mkdir -p %{buildroot}%{gem_dir}
cp -a .%{gem_dir}/* %{buildroot}%{gem_dir}/

%check
BROWSER_PATH=%{_libdir}/chromium-browser/headless_shell \
FERRUM_CHROME_DOCKERIZE=true \
ruby -I.%{gem_libdir} <<'RUBY'
require "ferrum"

browser = Ferrum::Browser.new
browser.go_to("data:text/html,<title>Ferrum</title><h1 id='result'>source build</h1>")
raise "unexpected title" unless browser.title == "Ferrum"
raise "DOM smoke test failed" unless browser.at_css("#result").text == "source build"
browser.quit
RUBY

%files
%dir %{gem_instdir}
%license %{gem_instdir}/LICENSE
%doc %{gem_instdir}/README.md
%{gem_libdir}
%exclude %{gem_cache}
%{gem_spec}

%files doc
%doc %{gem_docdir}

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.17.2-0.2
- Document the expanded COPR architecture and Rawhide target matrix.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.17.2-0.1
- Add the initial Fedora source package with a local Chromium CDP smoke test.
