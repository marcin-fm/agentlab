%global source_sha256 a13f9764be168e4d075fd80ff6ee5d47a9febe0152b82ad28bab0e949fcd9bd3
%bcond check 1

Name:           python-headroom-ai
Version:        0.31.0
Release:        0.2%{?dist}
Summary:        Local context compression and stdio MCP server

License:        Apache-2.0
URL:            https://github.com/headroomlabs-ai/headroom
Source0:        https://files.pythonhosted.org/packages/ad/fd/fe59aa45a74ead7ce0faad8175b29f02e5ef81034a434ff2a0da7f59a0a6/headroom_ai-%{version}.tar.gz
Patch0:         headroom-mcp-minimal.patch
Patch1:         headroom-mcp-minimal-tests.patch
Patch2:         headroom-mcp-remove-unavailable-native-deps.patch

BuildRequires:  cargo-rpm-macros >= 24
BuildRequires:  gcc
BuildRequires:  pkgconfig(sqlite3)
BuildRequires:  pyproject-rpm-macros
BuildRequires:  python3-devel
BuildRequires:  rust >= 1.80

%description
Headroom compresses AI-agent context locally. This Fedora package retains the
native compression core while disabling model downloads, proxy integration,
update checks, and non-stdio MCP behavior.

%package -n python3-headroom-ai
Summary:        %{summary}
Requires:       python3dist(mcp) >= 1

%description -n python3-headroom-ai
Headroom compresses AI-agent context locally. This Fedora package retains the
native compression core while disabling model downloads, proxy integration,
update checks, and non-stdio MCP behavior.

%prep
echo "%{source_sha256}  %{SOURCE0}" | sha256sum -c -
%autosetup -n headroom_ai-%{version} -p1
%cargo_prep

%generate_buildrequires
pushd crates/headroom-py >/dev/null
%cargo_generate_buildrequires -n -f extension-module,mcp-minimal
popd >/dev/null
%if %{with check}
pushd crates/headroom-core >/dev/null
%cargo_generate_buildrequires -n -f mcp-minimal
popd >/dev/null
%endif
%pyproject_buildrequires -x mcp

%build
%pyproject_wheel

%install
%pyproject_install
%pyproject_save_files -l headroom

%if %{with check}
%check
%{__cargo} test %{__cargo_common_opts} --profile rpm --no-fail-fast \
  -p headroom-core --no-default-features --features mcp-minimal --lib
%{__cargo} test %{__cargo_common_opts} --profile rpm --no-fail-fast \
  -p headroom-core --no-default-features --features mcp-minimal \
  --test ccr_backends
%{__cargo} test %{__cargo_common_opts} --profile rpm --no-fail-fast \
  -p headroom-core --no-default-features --features mcp-minimal \
  --test tokenizer_proptest

%{python3} - <<'PY'
import tiktoken

encoding = tiktoken.encoding_for_model("gpt-4o-mini")
assert len(encoding.encode("hello")) == 1
assert len(encoding.encode("Hello, world!")) == 4
assert len(encoding.encode("the quick brown fox jumps over the lazy dog")) == 9
PY

export PYTHONPATH=%{buildroot}%{python3_sitearch}
export HOME="$PWD/.home"
export XDG_CACHE_HOME="$PWD/.cache"
export XDG_CONFIG_HOME="$PWD/.config"
export XDG_STATE_HOME="$PWD/.state"
export HEADROOM_WORKSPACE_DIR="$PWD/.headroom"
export HEADROOM_CCR_BACKEND=memory
export HEADROOM_STATELESS=1
export HEADROOM_MCP_READ=on
export HEADROOM_SERVER=%{buildroot}%{_bindir}/headroom
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

extension=$(find %{buildroot}%{python3_sitearch}/headroom -name '_core*.so' -print -quit)
test -n "$extension"
if ldd "$extension" | grep -q 'libsqlite3.so'; then
  ldd "$extension" | grep -Eq '/(usr/)?lib64/libsqlite3\.so'
fi
! readelf -d "$extension" | grep -Eq 'RPATH|RUNPATH'

%{python3} - <<'PY'
import asyncio
import json
import os

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


def payload(result):
    assert result.content and hasattr(result.content[0], "text")
    return json.loads(result.content[0].text)


async def smoke() -> None:
    server = StdioServerParameters(
        command=os.environ["HEADROOM_SERVER"],
        args=["mcp", "serve"],
        env=dict(os.environ),
    )
    async with stdio_client(server) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = {tool.name for tool in tools.tools}
            assert names == {
                "headroom_compress",
                "headroom_retrieve",
                "headroom_stats",
            }, names

            original = json.dumps(
                [
                    {
                        "id": index,
                        "status": "ok",
                        "message": "repeated Fedora Headroom validation content",
                    }
                    for index in range(400)
                ]
            )
            compressed = payload(
                await session.call_tool("headroom_compress", {"content": original})
            )
            assert compressed["hash"]
            assert compressed["original_tokens"] > compressed["compressed_tokens"]
            assert compressed["tokens_saved"] > 0
            assert "proxy" not in compressed and "warning" not in compressed

            restored = payload(
                await session.call_tool("headroom_retrieve", {"hash": compressed["hash"]})
            )
            assert restored["source"] == "local"
            assert restored["original_content"] == original

            missing = payload(
                await session.call_tool("headroom_retrieve", {"hash": "missing-fedora-hash"})
            )
            assert "error" in missing and "source" not in missing

            stats = payload(await session.call_tool("headroom_stats", {}))
            assert stats["compressions"] >= 1
            assert stats["retrievals"] >= 1
            assert stats["total_tokens_saved"] > 0


asyncio.run(asyncio.wait_for(smoke(), timeout=60))
PY
%endif

%files -n python3-headroom-ai -f %{pyproject_files}
%license LICENSE NOTICE
%doc README.md
%{_bindir}/headroom

%changelog
* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.31.0-0.2
- Restore exact local OpenAI tokenization through tiktoken-rs 0.11.

* Fri Jul 17 2026 Marcin FM <marcin@lgic.pl> - 0.31.0-0.1
- Add the Fedora MCP-minimal source build.
