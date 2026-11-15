#!/usr/bin/env bash
# Native python (ADR-010): print the distributions a hash lock pins, as a JSON
# array of normalised "name==version" strings, sorted.
#
# Usage: python-lock.sh <requirements.txt>
#
# The lock is the --generate-hashes format of pip-compile and uv: a line
# `name==version \` starts each requirement, and its `--hash=sha256:` lines
# follow. The name is normalised as PEP 503 says (lower case, runs of - _ .
# become one -), so it compares with what syft and importlib.metadata report.
#
# Fails on a lock that pip --require-hashes would also refuse: a requirement
# that is not `==`, a requirement with no sha256, an extra (`name[x]`), a
# marker, or an option line other than --hash. An empty lock fails too.
set -euo pipefail
LOCK="${1:?lock file}"
[[ -s "$LOCK" ]] || { echo "::error::python-lock.sh: ${LOCK} is missing or empty" >&2; exit 1; }

python3 -I - "$LOCK" <<'PY'
import json, re, sys
path = sys.argv[1]
text = open(path).read()
# Join the backslash continuations of one requirement.
logical = re.sub(r"\\\n", " ", text).splitlines()
req = re.compile(r"^([A-Za-z0-9][A-Za-z0-9._-]*)==([A-Za-z0-9.+!_-]+)((\s+--hash=sha256:[0-9a-f]{64})+)\s*$")
out, bad = [], []
for line in logical:
    s = line.split(" #", 1)[0].strip() if not line.lstrip().startswith("#") else ""
    if not s:
        continue
    m = req.match(s)
    if not m:
        bad.append(s[:100])
        continue
    out.append(re.sub(r"[-_.]+", "-", m.group(1)).lower() + "==" + m.group(2))
if bad:
    for b in bad:
        print(f"::error::python-lock.sh: not a hash-pinned requirement: {b}", file=sys.stderr)
    sys.exit(1)
if not out or len(set(out)) != len(out):
    print("::error::python-lock.sh: the lock is empty or pins a distribution twice", file=sys.stderr)
    sys.exit(1)
print(json.dumps(sorted(out)))
PY
