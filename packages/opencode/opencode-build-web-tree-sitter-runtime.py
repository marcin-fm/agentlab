#!/usr/bin/python3

import argparse
import subprocess
from pathlib import Path


def exported_names(path: Path) -> list[str]:
    return [
        f"_{line.strip().removesuffix(',').strip(chr(34))}"
        for line in path.read_text().splitlines()
        if line.strip()
    ]


parser = argparse.ArgumentParser()
parser.add_argument("--emcc", required=True)
parser.add_argument("--source", required=True, type=Path)
args = parser.parse_args()

source = args.source.resolve()
exports = exported_names(source / "lib/src/wasm/stdlib-symbols.txt")
exports += exported_names(source / "lib/binding_web/lib/exports.txt")
runtime_methods = [
    "AsciiToString",
    "stringToUTF8",
    "UTF8ToString",
    "lengthBytesUTF8",
    "stringToUTF16",
    "loadWebAssemblyModule",
    "getValue",
    "setValue",
]

command = [
    args.emcc,
    "-O3",
    "--minify",
    "0",
    "-s",
    "EXPORT_ES6=1",
    "-gsource-map",
    "--source-map-base",
    ".",
    "-fno-exceptions",
    "-std=c11",
    "-s",
    "WASM=1",
    "-s",
    "MODULARIZE=1",
    "-s",
    "INITIAL_MEMORY=33554432",
    "-s",
    "ALLOW_MEMORY_GROWTH=1",
    "-s",
    "SUPPORT_BIG_ENDIAN=1",
    "-s",
    "MAIN_MODULE=2",
    "-s",
    "FILESYSTEM=0",
    "-s",
    "NODEJS_CATCH_EXIT=0",
    "-s",
    "NODEJS_CATCH_REJECTION=0",
    "-s",
    f"EXPORTED_FUNCTIONS={','.join(exports)}",
    "-s",
    f"EXPORTED_RUNTIME_METHODS={','.join(runtime_methods)}",
    "-D",
    "fprintf(...)=",
    "-D",
    "NDEBUG=",
    "-D",
    "_POSIX_C_SOURCE=200112L",
    "-D",
    "_DEFAULT_SOURCE=",
    "-D",
    "_DARWIN_C_SOURCE=",
    "-I",
    "lib/src",
    "-I",
    "lib/include",
    "--js-library",
    "lib/binding_web/lib/imports.js",
    "--pre-js",
    "lib/binding_web/lib/prefix.js",
    "-o",
    "lib/binding_web/lib/tree-sitter.mjs",
    "lib/src/lib.c",
    "lib/binding_web/lib/tree-sitter.c",
]

subprocess.run(command, cwd=source, check=True)
