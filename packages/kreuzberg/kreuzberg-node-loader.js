"use strict";

const path = require("node:path");

let nativePath = process.env.NAPI_RS_NATIVE_LIBRARY_PATH;

if (!nativePath) {
  if (process.platform !== "linux") {
    throw new Error(`Unsupported Kreuzberg platform: ${process.platform}`);
  }

  let nodeArch;

  switch (process.arch) {
    case "x64":
      nodeArch = "x64";
      break;
    case "arm64":
      nodeArch = "arm64";
      break;
    default:
      throw new Error(`Unsupported Kreuzberg architecture: ${process.arch}`);
  }

  nativePath = path.join(__dirname, `kreuzberg-node.linux-${nodeArch}-gnu.node`);
}

module.exports = require(nativePath);
