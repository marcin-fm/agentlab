%bcond check 1

%global crate rtk
%global source_sha256 735623ee670483216bc5fe7ca0885f1f1358d8f9facf22782a6ea8e8a44f3b3a
%global source_contract_sha256 116106bef8d568217ca25f986912b1a2b75818288efac02c548addbec8e568ae
%global system_sqlite_patch_sha256 2496b4395840cc4ed84ba4e39124250336b10d03b321fbda2c62d7601b16f080
%global dirs6_patch_sha256 826e2cd42dd4b70e6f8b50a178e5305c6946d81e219f1dd17e0cabe4d0e839b5
%global rtk_source_license_expression Apache-2.0 AND BSD-3-Clause AND CDLA-Permissive-2.0 AND ISC AND MIT AND MPL-2.0 AND Unicode-3.0 AND Unicode-DFS-2016 AND Zlib

Name:           rtk
Version:        0.44.1
Release:        0.1%{?dist}
Summary:        CLI proxy that reduces command output sent to language models

License:        %{rtk_source_license_expression}
URL:            https://github.com/rtk-ai/rtk
Source0:        https://github.com/rtk-ai/rtk/archive/refs/tags/v%{version}.tar.gz
Source1:        rtk-%{version}-source-contract.json
# Link RTK against Fedora system SQLite instead of compiling rusqlite's bundled copy.
# Upstream PR https://github.com/rtk-ai/rtk/pull/2404 at commit
# d0a922f1cd04e343957b9b0b9603438677ad6353 is unreleased and retains the
# bundled feature as default. This patch is Fedora-specific, not a backport.
Patch0:         rtk-use-system-sqlite.patch
# Use Fedora's common dirs 6 branch and remove the need for dirs 5 compatibility packages.
# Fedora-specific; no upstream issue, pull request, or commit was found as of
# 2026-07-31, and v0.44.1 still selects dirs 5.
Patch1:         rtk-use-dirs6.patch

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  binutils
BuildRequires:  cargo >= 1.91
BuildRequires:  git-core
BuildRequires:  rust >= 1.91
BuildRequires:  sqlite
BuildRequires:  sqlite-devel

%description
RTK filters and compresses command output before it reaches an AI coding
agent, reducing repetitive context while preserving actionable failures.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
echo "%{source_contract_sha256}  %{SOURCE1}" | sha256sum -c -
echo "%{system_sqlite_patch_sha256}  %{PATCH0}" | sha256sum -c -
echo "%{dirs6_patch_sha256}  %{PATCH1}" | sha256sum -c -
%autosetup -n %{crate}-%{version} -N
%autopatch -p1
%cargo_prep

%generate_buildrequires
%cargo_generate_buildrequires

%build
%cargo_build_crate

%if %{with check}
%check
%cargo_test
test -s LICENSE.dependencies
target_license_expression="$(%cargo_license_summary)"
test "$target_license_expression" = "%{rtk_source_license_expression}"
readelf -d target/rpm/%{name} > rtk-smoke.dynamic
grep -Eq '\(NEEDED\).*\[libsqlite3\.so\.0\]' rtk-smoke.dynamic
! grep -Eq '\((RPATH|RUNPATH)\)' rtk-smoke.dynamic
RTK_TELEMETRY_DISABLED=1 RTK_DB_PATH="$PWD/rtk-smoke.db" \
  target/rpm/%{name} proxy true >/dev/null
test -s rtk-smoke.db
sqlite3 -noheader rtk-smoke.db \
  "select name from sqlite_master where type = 'table' order by name" \
  > rtk-smoke.tables
printf '%s\n' commands parse_failures \
  > rtk-smoke.expected-tables
cmp -s rtk-smoke.expected-tables rtk-smoke.tables
commands_columns="$(sqlite3 -noheader rtk-smoke.db \
  "select group_concat(name, ' ') from pragma_table_info('commands')")"
test "$commands_columns" = "id timestamp original_cmd rtk_cmd input_tokens output_tokens saved_tokens savings_pct exec_time_ms project_path"
parse_failure_columns="$(sqlite3 -noheader rtk-smoke.db \
  "select group_concat(name, ' ') from pragma_table_info('parse_failures')")"
test "$parse_failure_columns" = "id timestamp raw_command error_message fallback_succeeded"
indexes="$(sqlite3 -noheader rtk-smoke.db \
  "select group_concat(name, ' ') from (select name from sqlite_master where type = 'index' order by name)")"
test "$indexes" = "idx_pf_timestamp idx_project_path_timestamp idx_timestamp"
command_records="$(sqlite3 -noheader rtk-smoke.db \
  "select count(*) from commands")"
test "$command_records" = "1"
proxy_records="$(sqlite3 -noheader rtk-smoke.db \
  "select count(*) from commands where trim(original_cmd) = 'true' and trim(rtk_cmd) = 'rtk proxy true' and input_tokens = 0 and output_tokens = 0 and saved_tokens = 0 and timestamp <> '' and exec_time_ms >= 0")"
test "$proxy_records" = "1"
%endif

%install
%cargo_install
install -Dpm0644 LICENSE.dependencies \
  %{buildroot}%{_licensedir}/%{name}/LICENSE.dependencies

%files
%license LICENSE
%license %{_licensedir}/%{name}/LICENSE.dependencies
%doc README.md
%{_bindir}/rtk

%changelog
* Thu Jul 30 2026 Marcin FM <marcin@lgic.pl> - 0.44.1-0.1
- Update to RTK 0.44.1.
- Rebase the system SQLite and Fedora dirs 6 dependency patches.
- Add checked source, license, test, linkage, database, and runtime contracts.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.6
- Migrate to Fedora's common dirs 6 dependency branch.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.5
- Generate test dependencies through the Fedora check bcond.
- Remove the copied system-provider license corpus from the runtime payload.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.4
- Document the expanded COPR architecture and Rawhide target matrix.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.3
- Document the system-SQLite patch purpose and upstream status.

* Thu Jul 16 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.2
- Add fail-closed collection of full linked-crate license evidence.
- Retain the exact resolved Cargo crate to Fedora provider mapping.
- Validate current Fedora 43 and Fedora 44 builds and artifact receipts.

* Wed Jul 15 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.1
- Complete clean Fedora 43 and Fedora 44 source builds.
- Use system SQLite and include the linked Rust dependency license inventory.

* Tue Jul 14 2026 Marcin FM <marcin@lgic.pl> - 0.43.0-0.0.1
- Add an initial Fedora source-build draft using system SQLite.
