import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [packageRoot, bashWasm, powershellWasm] = process.argv.slice(2);
if (!packageRoot || !bashWasm || !powershellWasm) {
  throw new Error("usage: validate-tree-sitter PACKAGE_ROOT BASH_WASM POWERSHELL_WASM");
}

const { Parser, Language } = await import(pathToFileURL(join(packageRoot, "tree-sitter.js")));
await Parser.init({
  locateFile() {
    return join(packageRoot, "tree-sitter.wasm");
  },
});

const cases = [
  {
    name: "bash",
    wasm: bashWasm,
    source: "for name in alpha beta; do printf '%s\\n' \"$name\"; done",
  },
  {
    name: "powershell",
    wasm: powershellWasm,
    source: "$items = @('alpha', 'beta'); foreach ($item in $items) { Write-Output $item }",
  },
];

for (const testCase of cases) {
  const language = await Language.load(testCase.wasm);
  const parser = new Parser();
  parser.setLanguage(language);
  const tree = parser.parse(testCase.source);
  const result = {
    grammar: testCase.name,
    rootType: tree.rootNode.type,
    hasError: tree.rootNode.hasError,
  };
  console.log(JSON.stringify(result));
  if (result.rootType !== "program" || result.hasError) process.exitCode = 1;
  tree.delete();
  parser.delete();
}
