#!/usr/bin/python3
"""Offline packaged smoke for the bounded Docling remote-conversion profile."""

import asyncio
import json
import os
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

from docling_core.types.doc.document import DoclingDocument
from docling_core.types.doc.labels import DocItemLabel
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


BASE_SERVER = os.environ["DOCLING_MCP_BASE_SERVER"]
REMOTE_SERVER = os.environ["DOCLING_MCP_REMOTE_SERVER"]


def run_rejected_configuration(
    environment: dict[str, str], cwd: Path, expected: str
) -> None:
    completed = subprocess.run(
        [REMOTE_SERVER],
        cwd=cwd,
        env=environment,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=10,
        check=False,
    )
    assert completed.returncode != 0
    assert expected in completed.stderr


def start_fake_serve(document_json: dict) -> tuple[ThreadingHTTPServer, dict]:
    state = {
        "api_keys": [],
        "mode": "success",
        "paths": [],
        "post_count": 0,
        "task_modes": {},
    }

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: object) -> None:
            return

        def send_json(self, status: int, payload: dict) -> None:
            body = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def record_request(self) -> str:
            path = urlsplit(self.path).path
            state["paths"].append(path)
            state["api_keys"].append(self.headers.get("X-Api-Key"))
            return path

        def do_GET(self) -> None:
            path = self.record_request()
            if path == "/health":
                status = "degraded" if state["mode"] == "bad-health" else "ok"
                self.send_json(200, {"status": status})
                return

            if path.startswith("/v1/status/poll/"):
                task_id = path.rsplit("/", 1)[1]
                mode = state["task_modes"][task_id]
                task_status = "failure" if mode == "failure" else "success"
                self.send_json(
                    200,
                    {
                        "task_id": task_id,
                        "task_type": "convert",
                        "task_status": task_status,
                        "error_message": "expected failure"
                        if task_status == "failure"
                        else None,
                    },
                )
                return

            if path.startswith("/v1/result/"):
                task_id = path.rsplit("/", 1)[1]
                mode = state["task_modes"][task_id]
                if mode == "malformed":
                    self.send_json(200, {"unexpected": True})
                else:
                    self.send_json(
                        200,
                        {
                            "document": {
                                "filename": "remote.md",
                                "json_content": document_json,
                            },
                            "status": "failure"
                            if mode == "failure"
                            else "success",
                            "processing_time": 0.01,
                        },
                    )
                return

            self.send_json(404, {"detail": "not found"})

        def do_POST(self) -> None:
            path = self.record_request()
            content_length = int(self.headers.get("Content-Length", "0"))
            self.rfile.read(content_length)
            assert path == "/v1/convert/file/async"

            state["post_count"] += 1
            if state["post_count"] % 2 == 1:
                self.send_json(
                    400,
                    {"detail": "artifact storage to be configured by administrator"},
                )
                return

            task_id = f"task-{state['post_count'] // 2}"
            state["task_modes"][task_id] = state["mode"]
            self.send_json(
                200,
                {
                    "task_id": task_id,
                    "task_type": "convert",
                    "task_status": "pending",
                },
            )

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, state


def result_payload(result: object) -> dict:
    structured = getattr(result, "structuredContent", None)
    if structured is not None:
        return structured
    content = getattr(result, "content")
    return json.loads(content[0].text)


async def base_smoke() -> None:
    server = StdioServerParameters(
        command=BASE_SERVER,
        env=dict(os.environ),
    )
    async with stdio_client(server) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = {tool.name for tool in tools.tools}
            assert "create_new_docling_document" in names
            assert "get_overview_of_document_anchors" in names
            assert "convert_document_into_docling_document" not in names
            assert "convert_directory_files_into_docling_document" not in names
            assert "add_table_in_html_format_to_docling_document" not in names
            created = await session.call_tool(
                "create_new_docling_document", {"prompt": "Fedora smoke"}
            )
            assert created.content


async def remote_smoke(
    environment: dict[str, str], root: Path, state: dict
) -> None:
    good = root / "good.md"
    failed = root / "failed.md"
    malformed = root / "malformed.md"
    bad_health = root / "bad-health.md"
    oversized = root / "oversized.md"
    good.write_text("Fedora remote conversion\n", encoding="utf-8")
    failed.write_text("Expected task failure\n", encoding="utf-8")
    malformed.write_text("Expected malformed result\n", encoding="utf-8")
    bad_health.write_text("Expected bad health\n", encoding="utf-8")
    oversized.write_bytes(b"x" * 65)

    outside = root.parent / "outside.md"
    outside.write_text("Outside approved root\n", encoding="utf-8")
    symlink = root / "symlink.md"
    symlink.symlink_to(outside)

    server = StdioServerParameters(
        command=REMOTE_SERVER,
        env=environment,
    )
    async with stdio_client(server) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            await session.initialize()
            tools = await session.list_tools()
            names = {tool.name for tool in tools.tools}
            assert "create_new_docling_document" in names
            assert "get_overview_of_document_anchors" in names
            assert "convert_document_into_docling_document" in names
            assert "convert_directory_files_into_docling_document" not in names

            converted = await session.call_tool(
                "convert_document_into_docling_document", {"source": str(good)}
            )
            assert not converted.isError
            first_payload = result_payload(converted)
            assert first_payload["from_cache"] is False
            assert len(first_payload["document_key"]) == 32

            cached = await session.call_tool(
                "convert_document_into_docling_document", {"source": str(good)}
            )
            assert not cached.isError
            second_payload = result_payload(cached)
            assert second_payload == {
                "from_cache": True,
                "document_key": first_payload["document_key"],
            }

            requests_before = len(state["paths"])
            for rejected_source in (
                "https://example.invalid/document.pdf",
                "http://127.0.0.1/private",
                str(outside),
                str(symlink),
                str(root),
                str(oversized),
            ):
                rejected = await session.call_tool(
                    "convert_document_into_docling_document",
                    {"source": rejected_source},
                )
                assert rejected.isError
            assert len(state["paths"]) == requests_before

            state["mode"] = "bad-health"
            posts_before = state["post_count"]
            rejected = await session.call_tool(
                "convert_document_into_docling_document",
                {"source": str(bad_health)},
            )
            assert rejected.isError
            assert state["post_count"] == posts_before

            state["mode"] = "failure"
            rejected = await session.call_tool(
                "convert_document_into_docling_document",
                {"source": str(failed)},
            )
            assert rejected.isError

            state["mode"] = "malformed"
            rejected = await session.call_tool(
                "convert_document_into_docling_document",
                {"source": str(malformed)},
            )
            assert rejected.isError


def main() -> None:
    remote_document = DoclingDocument(name="fedora-remote")
    remote_document.add_text(label=DocItemLabel.TEXT, text="converted")
    server, state = start_fake_serve(remote_document.model_dump(mode="json"))

    try:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            upload_root = temporary_path / "uploads"
            upload_root.mkdir()

            base_environment = dict(os.environ)
            for variable in (
                "DOCLING_SERVICE_URL",
                "DOCLING_SERVICE_UPLOAD_ROOT",
                "DOCLING_SERVICE_API_KEY",
            ):
                base_environment.pop(variable, None)

            (upload_root / ".env").write_text(
                "DOCLING_SERVICE_URL=http://127.0.0.1:9\n"
                f"DOCLING_SERVICE_UPLOAD_ROOT={upload_root}\n",
                encoding="utf-8",
            )
            run_rejected_configuration(
                base_environment, upload_root, "service_url"
            )

            remote_environment = dict(base_environment)
            remote_environment.update(
                {
                    "DOCLING_SERVICE_URL": (
                        f"http://127.0.0.1:{server.server_address[1]}"
                    ),
                    "DOCLING_SERVICE_UPLOAD_ROOT": str(upload_root),
                    "DOCLING_SERVICE_API_KEY": "fedora-secret",
                    "DOCLING_SERVICE_POLL_INTERVAL": "0.01",
                    "DOCLING_SERVICE_MAX_INPUT_BYTES": "64",
                    "DOCLING_SERVICE_MAX_ARTIFACT_DOWNLOAD_BYTES": "1024",
                }
            )
            credential_environment = dict(remote_environment)
            credential_environment["DOCLING_SERVICE_URL"] = (
                f"http://user:password@127.0.0.1:{server.server_address[1]}"
            )
            run_rejected_configuration(
                credential_environment, upload_root, "credentials"
            )

            invalid_cap_environment = dict(remote_environment)
            invalid_cap_environment[
                "DOCLING_SERVICE_MAX_ARTIFACT_DOWNLOAD_BYTES"
            ] = "67108865"
            run_rejected_configuration(
                invalid_cap_environment,
                upload_root,
                "service_max_artifact_download_bytes",
            )

            import_check = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    (
                        "import sys; "
                        "import docling_mcp.tools.remote_conversion; "
                        "banned={'docling.document_converter', "
                        "'docling_mcp.tools.converters.factory', "
                        "'docling_mcp.tools.converters.local'}; "
                        "assert banned.isdisjoint(sys.modules)"
                    ),
                ],
                env=remote_environment,
                cwd=upload_root,
                timeout=10,
                check=False,
            )
            assert import_check.returncode == 0

            asyncio.run(asyncio.wait_for(base_smoke(), timeout=30))
            asyncio.run(
                asyncio.wait_for(
                    remote_smoke(remote_environment, upload_root, state),
                    timeout=60,
                )
            )

        assert state["post_count"] == 6
        assert "/v1/convert/source/async" not in state["paths"]
        assert state["api_keys"]
        assert set(state["api_keys"]) == {"fedora-secret"}
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
