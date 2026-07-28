#!/usr/bin/env python3
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

root = Path("/srv/tmp/agentlab-kreuzberg/final-license-audit")
inventory = root / "payloads/kreuzberg/usr/share/licenses/kreuzberg/LICENSE.dependencies"
allowed = {
    "0BSD", "Apache-2.0", "Apache-2.0 WITH LLVM-exception", "BSD-2-Clause",
    "BSD-3-Clause", "BSL-1.0", "CC0-1.0", "CDLA-Permissive-2.0", "ISC", "MIT",
    "MIT-0", "MPL-2.0", "Unicode-3.0", "Unicode-DFS-2016", "Unlicense", "Zlib",
    "bzip2-1.0.6", "LicenseRef-Fedora-Public-Domain",
}
normalize = {"Apache-2.0 / MIT": "Apache-2.0 OR MIT", "Apache-2.0/MIT": "Apache-2.0 OR MIT", "MIT/Apache-2.0": "MIT OR Apache-2.0"}
counts = Counter()
records = []
for line, raw in enumerate(inventory.read_text().splitlines(), 1):
    expression, package = raw.rsplit(": ", 1)
    expression = normalize.get(expression, expression)
    identifiers = [value for value in re.findall(r"(?:LicenseRef-[A-Za-z0-9.-]+|[A-Za-z0-9.-]+(?: WITH [A-Za-z0-9.-]+)?)", expression) if value not in {"AND", "OR", "WITH"}]
    counts.update(identifiers)
    records.append({"line": line, "package": package, "license": expression, "identifiers": identifiers, "allowed": all(value in allowed for value in identifiers)})

result = {"schema": "kreuzberg-fedora-license-audit/v1", "inventory_sha256": hashlib.sha256(inventory.read_bytes()).hexdigest(), "line_count": len(records), "identifier_counts": dict(sorted(counts.items())), "all_identifiers_fedora_allowed": all(record["allowed"] for record in records), "records": records}
(root / "inventory.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
