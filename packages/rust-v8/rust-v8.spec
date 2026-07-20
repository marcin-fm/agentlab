# Disabled by package.yml. This spec reconstructs and patches the exact Git
# submodule source closure for local production-build proof; publication remains
# blocked until the package metadata gates are complete.
%bcond check 1
%global debug_package %{nil}
%global source_commit 5d0e31ea6bf67f4559faa759b91e22bc3f1cd696
%global source_sha256 8f63ff709b52b7a2de0453e37ba8f661c21d0a398e4ecf5298b273ab8018747a
%global closure_sha256 ae63c79b9242eb4cb078a5abeccd1912a7df091d0eb42b5bfa4c31a3c5e6e6fc
%global license_audit_sha256 8929839588526022f7b6f3adde346b063556507b03bd68281bc9c43eab248c22
%global archive_graph_sha256 97a2288f1e83d382b5e5aa9e034c34998f7cb17d15b31c3eca63b7e694130bc9
%global fedora_license_evidence_sha256 b63ee251799012a6492526d85dab76a64bb93d813b4526c64a0a1266fd22acc3
%global dynamic_linking_sha256 d1f8e4952c7189877c4ca587861a985fb7ac05a47720691fb3a2971e5d046818
%global source_filter_sha256 a611159b2626cb36600c1ebf332d4f7da093f9be310496a9145aec53d1d81ffa
%global static_license_sha256 b2748c7b706f7d1862f0eab4d74cb1dce9ec89378fd4d88b36bf8e4ea671c483
%global system_rust_patch_sha256 36d5b76fd4010b15a9134fcc9474eab32bd1de3599e31d28052133b4bb01eb1e
%global gcc_patch_sha256 1f59329cba6b69028ef2bc9a198f75605a6f0ebcf106f0d321453d56ceb25dcf
%global siphash_patch_sha256 899c0ebecaefd5ca655ecaa8b0b78d168ac1dc980514610ca5fa2c32ee1712ca
%global allocator_license_sha256 813df42f500205608c3668a069496e1a6d86a949204db89aff3c6332ad775558
%global source_preparer_sha256 cf49573ca92537748b029bb1cbf89dd1dc871126c72de8b3ff6cb09325cb027c

Name:           rust-v8
Version:        149.2.0
Release:        0.14%{?dist}
Summary:        Source-built Rusty V8 static archive

# Complete retained Fedora 44 x86_64 1,795-object archive expression. The 31
# implicit Rust rlibs and system libraries are not embedded in this package.
License:        Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BSD-Protection AND LicenseRef-Fedora-Public-Domain AND LicenseRef-Fedora-UltraPermissive AND MIT AND NAIST-2003 AND Python-2.0.1 AND Unicode-3.0 AND Unicode-DFS-2016 AND Unlicense AND (Apache-2.0 OR BSL-1.0 OR MIT) AND (Apache-2.0 WITH LLVM-exception OR BSL-1.0)
URL:            https://github.com/denoland/rusty_v8
Source0:        https://codeload.github.com/denoland/rusty_v8/tar.gz/%{source_commit}#/%{name}-%{version}.tar.gz
Source1:        https://codeload.github.com/denoland/chromium_build/tar.gz/fffa45f2e9df48c0230a4c799b7d12e7f83d8219#/%{name}-%{version}-build-fffa45f2e9df48c0230a4c799b7d12e7f83d8219.tar.gz
Source2:        https://chromium.googlesource.com/chromium/src/buildtools/+archive/c9110ba7150d93134b1c85ea392033b4a82d28f7.tar.gz#/%{name}-%{version}-buildtools-c9110ba7150d93134b1c85ea392033b4a82d28f7.tar.gz
Source3:        https://chromium.googlesource.com/chromium/src/third_party/abseil-cpp/+archive/5e42a36a85a252d8cdee6c39661d2bfd9883fd5c.tar.gz#/%{name}-%{version}-third_party-abseil-cpp-5e42a36a85a252d8cdee6c39661d2bfd9883fd5c.tar.gz
Source4:        https://chromium.googlesource.com/external/github.com/jk-jeon/dragonbox/+archive/beeeef91cf6fef89a4d4ba5e95d47ca64ccb3a44.tar.gz#/%{name}-%{version}-third_party-dragonbox-src-beeeef91cf6fef89a4d4ba5e95d47ca64ccb3a44.tar.gz
Source5:        https://chromium.googlesource.com/external/github.com/fastfloat/fast_float/+archive/05087a303dad9c98768b33c829d398223a649bc6.tar.gz#/%{name}-%{version}-third_party-fast_float-src-05087a303dad9c98768b33c829d398223a649bc6.tar.gz
Source6:        https://codeload.github.com/Maratyszcza/FP16/tar.gz/3d2de1816307bac63c16a297e8c4dc501b4076df#/%{name}-%{version}-third_party-fp16-src-3d2de1816307bac63c16a297e8c4dc501b4076df.tar.gz
Source7:        https://chromium.googlesource.com/external/github.com/google/highway/+archive/2607d3b5b0113992fe84d3848859eae13b3b52c1.tar.gz#/%{name}-%{version}-third_party-highway-src-2607d3b5b0113992fe84d3848859eae13b3b52c1.tar.gz
Source8:        https://chromium.googlesource.com/chromium/deps/icu/+archive/ee5f27adc28bd3f15b2c293f726d14d2e336cbd5.tar.gz#/%{name}-%{version}-third_party-icu-ee5f27adc28bd3f15b2c293f726d14d2e336cbd5.tar.gz
Source9:        https://chromium.googlesource.com/chromium/src/third_party/jinja2/+archive/c3027d884967773057bf74b957e3fea87e5df4d7.tar.gz#/%{name}-%{version}-third_party-jinja2-c3027d884967773057bf74b957e3fea87e5df4d7.tar.gz
Source10:       https://chromium.googlesource.com/external/github.com/llvm/llvm-project/libcxx/+archive/99457fa555797f8c5ac3c076ca288d8481d3b23a.tar.gz#/%{name}-%{version}-third_party-libc-src-99457fa555797f8c5ac3c076ca288d8481d3b23a.tar.gz
Source11:       https://chromium.googlesource.com/external/github.com/llvm/llvm-project/libcxxabi/+archive/8f11bb1d4438d0239d0dfc1bd9456a9f31629dda.tar.gz#/%{name}-%{version}-third_party-libc-abi-src-8f11bb1d4438d0239d0dfc1bd9456a9f31629dda.tar.gz
Source12:       https://chromium.googlesource.com/external/github.com/llvm/llvm-project/libunwind/+archive/a2530baf3d11013afd0f1c1941ab6bef5ba71d0a.tar.gz#/%{name}-%{version}-third_party-libunwind-src-a2530baf3d11013afd0f1c1941ab6bef5ba71d0a.tar.gz
Source13:       https://chromium.googlesource.com/external/github.com/llvm/llvm-project/libc/+archive/cb952785ccee13811f293f3c419958d1e3ddafbf.tar.gz#/%{name}-%{version}-third_party-llvm-libc-src-cb952785ccee13811f293f3c419958d1e3ddafbf.tar.gz
Source14:       https://chromium.googlesource.com/chromium/src/third_party/markupsafe/+archive/4256084ae14175d38a3ff7d739dca83ae49ccec6.tar.gz#/%{name}-%{version}-third_party-markupsafe-4256084ae14175d38a3ff7d739dca83ae49ccec6.tar.gz
Source15:       https://chromium.googlesource.com/chromium/src/base/allocator/partition_allocator/+archive/fafdd4c9f559c6d0cfdf2ed3170ce370b59bfdbf.tar.gz#/%{name}-%{version}-third_party-partition_alloc-fafdd4c9f559c6d0cfdf2ed3170ce370b59bfdbf.tar.gz
Source16:       https://chromium.googlesource.com/chromium/src/third_party/rust/+archive/2b055f4ecac78bbf34a0d34217c699b7b09b44dd.tar.gz#/%{name}-%{version}-third_party-rust-2b055f4ecac78bbf34a0d34217c699b7b09b44dd.tar.gz
Source17:       https://chromium.googlesource.com/chromium/src/third_party/simdutf/+archive/f7356eed293f8208c40b3c1b344a50bd70971983.tar.gz#/%{name}-%{version}-third_party-simdutf-f7356eed293f8208c40b3c1b344a50bd70971983.tar.gz
Source18:       https://chromium.googlesource.com/chromium/src/tools/clang/+archive/61150a5f1ddf6460bad3d896c1502c6a56e15311.tar.gz#/%{name}-%{version}-tools-clang-61150a5f1ddf6460bad3d896c1502c6a56e15311.tar.gz
Source19:       https://chromium.googlesource.com/chromium/src/tools/win/+archive/d16e6b55b2bd699735919d8a13a55ff284086603.tar.gz#/%{name}-%{version}-tools-win-d16e6b55b2bd699735919d8a13a55ff284086603.tar.gz
Source20:       %{name}-%{version}-v8-73d19698991616a34a00ca691a6e697dbb69e2ef-filtered-siphash.tar.gz
Source21:       %{name}-%{version}-source-closure.json
Source22:       %{name}-%{version}-license-audit.json
Source23:       %{name}-%{version}-archive-graph.json
Source24:       %{name}-%{version}-fedora-license-evidence.json
Source25:       %{name}-%{version}-dynamic-linking.json
Source26:       %{name}-%{version}-source-filter.json
Source27:       %{name}-%{version}-static-license.json
Source28:       %{name}-stable-system-allocator-license.txt
Source29:       prepare-rust-v8-srpm-sources
Source30:       README.md
# Guard Chromium nightly-only Rust behavior and use Fedora's stable toolchain.
# Fedora-specific; not submitted while the exact system-toolchain boundary is reviewed.
Patch0:         %{name}-system-rust-toolchain.patch
# Make V8's warning preprocessing GCC-compatible and add one required include.
# Fedora-specific; not submitted while the GCC build boundary is reviewed.
Patch1:         %{name}-gcc-portability.patch
# Keep the already-disabled SipHash implementation out of the selected graph.
# Fedora-specific; not submitted while V8 carries the sources unconditionally.
Patch2:         %{name}-disable-unused-siphash.patch

ExclusiveArch:  x86_64 aarch64

BuildRequires:  bindgen-cli >= 0.72
BuildRequires:  binutils
BuildRequires:  clang-libs >= 19
BuildRequires:  gcc-c++
BuildRequires:  gn
BuildRequires:  libatomic
BuildRequires:  lld
BuildRequires:  ninja-build
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  pkgconfig(gmodule-2.0)
BuildRequires:  pkgconfig(gobject-2.0)
BuildRequires:  pkgconfig(gthread-2.0)
BuildRequires:  python3
BuildRequires:  python-unversioned-command
BuildRequires:  rust >= 1.91
BuildRequires:  rustfmt
BuildRequires:  ruby
BuildRequires:  ruby-default-gems
BuildRequires:  rubygem-json

%description
Rusty V8 provides Rust bindings to Google's V8 JavaScript engine. This source
package builds the exact static archive consumed by the `v8 149.2.0` crate.

This draft is intentionally blocked. The root and 19 nested Git component
archives are commit-addressed RPM inputs. The exact V8 input is filtered at SRPM
time to remove three unused CC0 SipHash files. Every archive is accepted by its
exact tree rather than compressor-specific bytes. The resulting 21-component
tree matches Git except for those reviewed exclusions and accepts the three
Fedora patches. A full Chromium dependency-client checkout is not claimed. A
retained Fedora 44 prototype witness matches 1,795 selected objects to 1,795
archive members and has a complete selected static-license expression and text
map. Production source-bound builds, final consumer Rust libraries, and
architecture proof remain separate blocked gates.

%package static
Summary:        Exact-version Rusty V8 static archive
Provides:       rusty-v8-static(abi) = %{version}

%description static
This package contains `librusty_v8.a` for the exact `v8 149.2.0` crate. Cargo
consumers select it with `RUSTY_V8_ARCHIVE` during their own source builds.

%prep
echo "%{closure_sha256}  %{SOURCE21}" | sha256sum -c -
echo "%{license_audit_sha256}  %{SOURCE22}" | sha256sum -c -
echo "%{archive_graph_sha256}  %{SOURCE23}" | sha256sum -c -
echo "%{fedora_license_evidence_sha256}  %{SOURCE24}" | sha256sum -c -
echo "%{dynamic_linking_sha256}  %{SOURCE25}" | sha256sum -c -
echo "%{source_filter_sha256}  %{SOURCE26}" | sha256sum -c -
echo "%{static_license_sha256}  %{SOURCE27}" | sha256sum -c -
echo "%{allocator_license_sha256}  %{SOURCE28}" | sha256sum -c -
echo "%{source_preparer_sha256}  %{SOURCE29}" | sha256sum -c -
echo "%{system_rust_patch_sha256}  %{PATCH0}" | sha256sum -c -
echo "%{gcc_patch_sha256}  %{PATCH1}" | sha256sum -c -
echo "%{siphash_patch_sha256}  %{PATCH2}" | sha256sum -c -
TMPDIR="%{_tmppath}" ruby "%{SOURCE29}" \
  --output "%{SOURCE20}" --receipt "%{SOURCE26}" --check \
  --closure "%{SOURCE21}" \
  --source "%{SOURCE0}" --source "%{SOURCE1}" --source "%{SOURCE2}" \
  --source "%{SOURCE3}" --source "%{SOURCE4}" --source "%{SOURCE5}" \
  --source "%{SOURCE6}" --source "%{SOURCE7}" --source "%{SOURCE8}" \
  --source "%{SOURCE9}" --source "%{SOURCE10}" --source "%{SOURCE11}" \
  --source "%{SOURCE12}" --source "%{SOURCE13}" --source "%{SOURCE14}" \
  --source "%{SOURCE15}" --source "%{SOURCE16}" --source "%{SOURCE17}" \
  --source "%{SOURCE18}" --source "%{SOURCE19}" --source "%{SOURCE20}"
python3 - "%{SOURCE21}" "%{SOURCE22}" "%{SOURCE23}" "%{SOURCE24}" "%{SOURCE25}" \
  "%{SOURCE26}" "%{SOURCE27}" \
  "%{SOURCE0}" "%{SOURCE1}" "%{SOURCE2}" "%{SOURCE3}" "%{SOURCE4}" \
  "%{SOURCE5}" "%{SOURCE6}" "%{SOURCE7}" "%{SOURCE8}" "%{SOURCE9}" \
  "%{SOURCE10}" "%{SOURCE11}" "%{SOURCE12}" "%{SOURCE13}" "%{SOURCE14}" \
  "%{SOURCE15}" "%{SOURCE16}" "%{SOURCE17}" "%{SOURCE18}" "%{SOURCE19}" \
  "%{SOURCE20}" <<'PY'
import hashlib
import json
import os
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
license_audit = json.load(open(sys.argv[2], encoding="utf-8"))
archive_graph = json.load(open(sys.argv[3], encoding="utf-8"))
fedora_license_evidence = json.load(open(sys.argv[4], encoding="utf-8"))
dynamic_linking = json.load(open(sys.argv[5], encoding="utf-8"))
source_filter = json.load(open(sys.argv[6], encoding="utf-8"))
static_license = json.load(open(sys.argv[7], encoding="utf-8"))
sources = sys.argv[8:]
components = receipt["components"]
assert receipt["schema"] == "rust-v8-source-closure/v4"
assert receipt["release"]["version"] == "%{version}"
assert len(components) == len(sources) == 21
assert receipt["closure_scope"]["kind"] == "git-submodule-closure-with-reviewed-source-filter"
assert receipt["closure_scope"]["full_deps_checkout_claimed"] is False
assert receipt["validation"]["exact_git_submodule_closure_verified"] is False
assert receipt["validation"]["reviewed_filtered_git_submodule_closure_verified"] is True
assert receipt["validation"]["full_deps_checkout_verified"] is False
assert receipt["validation"]["immutable_recursive_rpm_source_verified"] is True
assert receipt["validation"]["recursive_component_archive_trees_match_git"] is False
assert receipt["validation"]["recursive_component_archive_trees_match_git_except_reviewed_exclusions"] is True
assert receipt["validation"]["recursive_source_tree_matches_git"] is False
assert receipt["validation"]["recursive_source_tree_matches_git_except_reviewed_exclusions"] is True
assert license_audit["schema"] == "rust-v8-license-audit/v1"
assert license_audit["source_closure"]["sha256"] == "%{closure_sha256}"
assert license_audit["validation"]["all_source_components_inventoried"] is True
assert license_audit["validation"]["declared_license_syntax_classified"] is True
assert license_audit["validation"]["unmaterialized_deps_declarations_classified"] is True
assert license_audit["validation"]["vendored_rust_source_package_declarations_complete"] is True
assert license_audit["validation"]["vendored_rust_source_package_candidate_texts_present"] is True
assert license_audit["validation"]["vendored_rust_fedora_license_evidence_recorded"] is True
assert license_audit["validation"]["declared_license_text_semantic_review_complete"] is False
assert license_audit["validation"]["required_license_texts_verified"] is False
assert license_audit["validation"]["fedora_allowed_spdx_verified"] is False
assert fedora_license_evidence["schema"] == "rust-v8-fedora-license-evidence/v1"
assert fedora_license_evidence["release"] == "%{version}"
assert fedora_license_evidence["summary"] == {
    "vendored_rust_source_packages": 216,
    "exact": 136,
    "version_different": 26,
    "absent": 54,
}
assert fedora_license_evidence["validation"]["exact_matches_include_fedora_license_metadata"] is True
assert fedora_license_evidence["validation"]["linked_archive_selection_verified"] is False
assert fedora_license_evidence["validation"]["final_static_archive_license_complete"] is False
assert license_audit["fedora_license_evidence"]["sha256"] == "%{fedora_license_evidence_sha256}"
assert dynamic_linking["schema"] == "rust-v8-dynamic-linking-feasibility/v1"
assert dynamic_linking["release"] == "%{version}"
assert dynamic_linking["source_closure_reference"]["sha256"] == "%{closure_sha256}"
assert dynamic_linking["upstream_contract"]["rusty_v8_gn_target_type"] == "static_library"
assert dynamic_linking["upstream_contract"]["cargo_native_link_kind"] == "static"
assert dynamic_linking["upstream_contract"]["v8_component_build_available"] is True
assert dynamic_linking["shared_provider"]["upstream_supported"] is False
assert dynamic_linking["shared_provider"]["existing_rust_consumers_supported"] is False
assert dynamic_linking["decision"]["package_shared_library"] is False
assert dynamic_linking["decision"]["retain_exact_static_provider"] is True
assert source_filter["schema"] == "rust-v8-source-filter/v3"
assert source_filter["release"] == "%{version}"
assert source_filter["output"]["filename"] == os.path.basename(sources[20])
assert source_filter["output"]["archive_root"] == components[20]["archive"]["archive_root"]
assert source_filter["output"]["tree_file_records"] == components[20]["archive"]["tree_file_records"]
assert source_filter["output"]["tree_sha256"] == components[20]["archive"]["tree_sha256"]
assert source_filter["validation"]["generated_archive_transport_identity_required"] is False
assert source_filter["validation"]["cc0_executable_source_present"] is False
assert receipt["source_filter"]["sha256"] == "%{source_filter_sha256}"
assert static_license["schema"] == "rust-v8-static-license/v1"
assert static_license["release"] == "%{version}"
assert static_license["source_closure_reference"]["sha256"] == "%{closure_sha256}"
assert static_license["archive_graph_reference"]["sha256"] == "%{archive_graph_sha256}"
assert static_license["static_archive"]["expression"] == "Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BSD-Protection AND LicenseRef-Fedora-Public-Domain AND LicenseRef-Fedora-UltraPermissive AND MIT AND NAIST-2003 AND Python-2.0.1 AND Unicode-3.0 AND Unicode-DFS-2016 AND Unlicense AND (Apache-2.0 OR BSL-1.0 OR MIT) AND (Apache-2.0 WITH LLVM-exception OR BSL-1.0)"
assert static_license["selected_graph"]["archive_objects"] == 1795
assert static_license["selected_graph"]["implicit_rust_rlibs"] == 31
assert static_license["selected_graph"]["implicit_rust_rlibs_embedded"] is False
assert static_license["validation"]["required_license_texts_verified"] is True
assert static_license["validation"]["fedora_allowed_spdx_verified"] is True
assert static_license["validation"]["prototype_static_archive_license_complete"] is True
assert static_license["validation"]["production_static_archive_license_complete"] is False
assert archive_graph["schema"] == "rust-v8-archive-graph-witness/v1"
assert archive_graph["source_closure_reference"]["sha256"] == "%{closure_sha256}"
assert archive_graph["source_closure_reference"]["provenance_verified"] is False
assert archive_graph["gn"]["target"] == "//:rusty_v8"
assert archive_graph["archive"]["member_name_multiset_matches_object_basenames"] is True
assert archive_graph["archive"]["member_contents_match_object_contents_verified"] is False
assert archive_graph["archive"]["implicit_rust_rlibs_embedded_in_archive"] is False
assert archive_graph["archive"]["object_input_count"] == 1795
assert archive_graph["archive"]["selected_googletest_inputs"] == []
assert archive_graph["validation"]["prototype_selected_archive_graph_captured"] is True
assert archive_graph["validation"]["selected_build_dependency_closure_verified"] is False
assert archive_graph["validation"]["network_isolated_build_verified"] is False
assert archive_graph["validation"]["final_consumer_link_closure_verified"] is False
for index, (component, source) in enumerate(zip(components, sources)):
    archive = component["archive"]
    assert component["rpm_source"] == index
    assert os.path.basename(source) == archive["filename"]
    assert archive["transport_identity_required"] is False
    if index == 20:
        assert archive["generated"] is True
PY

%setup -q -n rusty_v8-%{source_commit}

extract_flat() {
  rm -rf "$1"
  mkdir -p "$1"
  tar -xzf "$2" -C "$1" --no-same-owner
}
extract_wrapped() {
  rm -rf "$1"
  mkdir -p "$1"
  tar -xzf "$2" -C "$1" --no-same-owner --strip-components=1
}

extract_wrapped build %{SOURCE1}
extract_flat buildtools %{SOURCE2}
extract_flat third_party/abseil-cpp %{SOURCE3}
extract_flat third_party/dragonbox/src %{SOURCE4}
extract_flat third_party/fast_float/src %{SOURCE5}
extract_wrapped third_party/fp16/src %{SOURCE6}
extract_flat third_party/highway/src %{SOURCE7}
extract_flat third_party/icu %{SOURCE8}
extract_flat third_party/jinja2 %{SOURCE9}
extract_flat third_party/libc++/src %{SOURCE10}
extract_flat third_party/libc++abi/src %{SOURCE11}
extract_flat third_party/libunwind/src %{SOURCE12}
extract_flat third_party/llvm-libc/src %{SOURCE13}
extract_flat third_party/markupsafe %{SOURCE14}
extract_flat third_party/partition_alloc %{SOURCE15}
extract_flat third_party/rust %{SOURCE16}
extract_flat third_party/simdutf %{SOURCE17}
extract_flat tools/clang %{SOURCE18}
extract_flat tools/win %{SOURCE19}
extract_wrapped v8 %{SOURCE20}

patch --batch --fuzz=0 -p1 < %{PATCH0}
patch --batch --fuzz=0 -p1 < %{PATCH1}
patch --batch --fuzz=0 -p1 < %{PATCH2}

%build
mkdir -p out/fedora
cat > out/fedora/args.gn <<'GN'
is_debug = false
is_clang = false
use_lld = true
use_custom_libcxx = false
symbol_level = 1
line_tables_only = false
no_inline_line_tables = false
clang_base_path = "/usr"
clang_version = "22"
v8_enable_sandbox = false
v8_enable_pointer_compression = false
v8_enable_v8_checks = false
rusty_v8_enable_simdutf = false
treat_warnings_as_errors = false
rust_sysroot_absolute = "/usr"
rust_bindgen_root = "/usr"
toolchain_supports_rust_thin_lto = false
GN
rustc_version="$(rpm -q --qf '%{VERSION}-Fedora-%{VERSION}-%{RELEASE}' rust)"
printf 'rustc_version = "%s"\n' "$rustc_version" >> out/fedora/args.gn
gn gen out/fedora
%{__ninja} -C out/fedora -j%{_smp_build_ncpus} obj/librusty_v8.a

%check
%if %{with check}
python3 - "%{SOURCE23}" <<'PY'
import hashlib
import json
import os
import subprocess
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
archive = "out/fedora/obj/librusty_v8.a"
assert os.path.isfile(archive)
query = subprocess.check_output(
    ["ninja", "-C", "out/fedora", "-t", "query", "obj/librusty_v8.a"],
    text=True,
)
lines = query.splitlines()
start = lines.index("  input: alink") + 1
inputs = []
for line in lines[start:]:
    if line == "  outputs:":
        break
    if line.startswith("    "):
        value = line.strip()
        if not value.startswith("||"):
            inputs.append(value.removeprefix("| "))
objects = [path for path in inputs if path.endswith(".o")]
rlibs = [path for path in inputs if path.endswith(".rlib")]
members = subprocess.check_output(["ar", "t", archive], text=True).splitlines()

def lines_sha256(values):
    return hashlib.sha256(("\n".join(sorted(values)) + "\n").encode()).hexdigest()

assert len(objects) == receipt["archive"]["object_input_count"]
assert len(rlibs) == receipt["archive"]["implicit_rust_rlib_count"]
assert lines_sha256(objects) == receipt["archive"]["object_input_paths_sha256"]
assert lines_sha256(rlibs) == receipt["archive"]["implicit_rust_rlib_paths_sha256"]
assert lines_sha256(members) == receipt["archive"]["member_names_sha256"]
assert sorted(members) == sorted(os.path.basename(path) for path in objects)
assert not any("googletest" in path or "/gtest/" in path or "/gmock/" in path for path in inputs)
assert not any("halfsiphash" in path for path in inputs)
PY
%endif

%install
install -Dpm0644 out/fedora/obj/librusty_v8.a \
  %{buildroot}%{_libdir}/rust-v8/%{version}/librusty_v8.a
install -Dpm0644 %{SOURCE30} %{buildroot}%{_docdir}/%{name}-static/README.md
python3 - "%{SOURCE27}" "%{buildroot}%{_licensedir}/%{name}-static" <<'PY'
import json
import hashlib
import os
import shutil
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
destination = sys.argv[2]
os.makedirs(destination, exist_ok=True)
for record in receipt["static_archive"]["required_license_texts"]:
    source = record["path"]
    if os.path.getsize(source) != record["bytes"]:
        raise RuntimeError(f"license text size changed: {source}")
    with open(source, "rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != record["sha256"]:
            raise RuntimeError(f"license text hash changed: {source}")
    target = os.path.join(destination, record["install_name"])
    shutil.copyfile(source, target)
    os.chmod(target, 0o644)
PY

%files static
%license %{_licensedir}/%{name}-static/*
%doc %{_docdir}/%{name}-static/README.md
%{_libdir}/rust-v8/%{version}/librusty_v8.a

%changelog
* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.14
- Install libatomic for Rust host-tool linking on Fedora 43.
- Omit V8's Clang-only ARM64 assembly marker in the Fedora GCC build.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.13
- Express native aarch64 tool selection with valid GN syntax.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.12
- Use GCC's supported minimal debug mode instead of a Clang-only flag.
- Select native GCC tools when building directly on aarch64.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.11
- Guard Chromium's Rust DWARF flag when using Fedora stable Rust.
- Preserve line-table debug information on x86_64 and aarch64.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.10
- Allow native configured-SCM proof builds on x86_64 and aarch64.
- Keep architecture-specific graph and license evidence fail-closed.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.9
- Validate the generated V8 source by its exact filtered tree instead of gzip bytes.
- Verify every commit archive by its exact tree without tracking generated assets.
- Run the exact retained GN/Ninja graph for a source-bound Fedora build proof.
- Provide Chromium's unversioned Python command through the Fedora package.
- Declare the GLib pkg-config interfaces required by Chromium's Linux config.
- Bind Chromium's custom Rust toolchain check to normalized Fedora RPM identity.
- Keep debug sections embedded in the generated static archive.
- Ship the package design and consumer contract as runtime documentation.
- Build line-table debug information into static archive members.

* Mon Jul 20 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.8
- Remove the unused CC0 SipHash implementation from the reviewed source input.
- Record the complete retained static-archive expression and exact license texts.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.7
- Record the exact-source dynamic-linking feasibility decision.
- Retain the supported static provider instead of inventing a shared ABI.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.6
- Reuse Fedora 44 license metadata for 136 exact vendored Rust crate versions.
- Keep selected-link and final aggregate-license decisions fail-closed.

* Sun Jul 19 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.5
- Semantically normalize four ambiguous Chromium license declarations.
- Preserve the remaining Fedora and final static-license gates.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.4
- Capture the retained prototype archive graph without claiming production closure.
- Record mechanical license normalization and scoped Chromium parent evidence.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.3
- Scope the immutable inputs explicitly to the exact Git submodule closure.
- Classify unmaterialized DEPS declarations and ambiguous license syntax.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.2
- Add all 20 immutable recursive component archives as checked RPM sources.
- Reconstruct the exact Git tree and apply the Fedora toolchain patches.
- Inventory component legal texts and classify 216 vendored Rust source packages.

* Sat Jul 18 2026 Marcin FM <marcin@lgic.pl> - 149.2.0-0.1
- Add a fail-closed exact-version Rusty V8 static provider draft.
- Record the 21-component recursive source identity and Fedora stable-Rust patches.
