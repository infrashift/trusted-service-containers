#!/usr/bin/env bash
# Mechanical drift checks across the workflow set.
#
# Every check here corresponds to a drift the reference repo actually suffered:
# a paths filter that fell out of sync with the gate's regex (it has a dedicated
# fix commit for that), a required status context spelled differently in two
# places, and actions pinned by tag rather than SHA.
set -euo pipefail

fail=0
err() { echo "error: $*" >&2; fail=1; }
ok()  { printf '  %-52s %s\n' "$1" "OK"; }

WF=.github/workflows

# --- 1. Every uses: is pinned to a 40-hex commit SHA -----------------------
if grep -rhoE '^\s*(- )?uses: \S+' "$WF" | grep -qvE '@[0-9a-f]{40}$'; then
  err "unpinned action(s):"
  grep -rhoE '^\s*(- )?uses: \S+' "$WF" | grep -vE '@[0-9a-f]{40}$' >&2
else
  ok "all actions SHA-pinned"
fi

# --- 2. workflow_run references resolve to a real workflow name -----------
python3 - <<'PY' || exit 1
import glob, sys, yaml
names = {}
for f in glob.glob('.github/workflows/*.yml'):
    names[yaml.safe_load(open(f))['name']] = f
bad = False
for f in glob.glob('.github/workflows/*.yml'):
    d = yaml.safe_load(open(f))
    on = d.get(True) or d.get('on')   # YAML 1.1 parses bare `on:` as boolean True
    if not isinstance(on, dict):
        continue
    for w in (on.get('workflow_run') or {}).get('workflows', []):
        if w not in names:
            print(f"error: {f} triggers on workflow_run of {w!r}, which no workflow declares", file=sys.stderr)
            bad = True
print("  %-52s %s" % ("workflow_run references resolve", "OK"))
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || fail=1

# --- 3. The injection guard is byte-identical in all three consumers -------
# build-matrix.json crosses a trust boundary three times. If one copy of the
# guard drifts, that boundary is unguarded and nothing else would notice.
guard_hash() {
  awk '/if ! jq -e .$/,/build-matrix.json > \/dev\/null; then/' "$1" \
    | grep -vE '^\s*$' | sed 's/^[[:space:]]*//' | sha256sum | cut -d' ' -f1
}
H_BUILD=$(guard_hash "$WF/build.yml")
H_REVIEW=$(guard_hash "$WF/review.yml")
H_RELEASE=$(guard_hash "$WF/release.yml")
if [[ -z "$H_BUILD" || "$H_BUILD" != "$H_REVIEW" || "$H_BUILD" != "$H_RELEASE" ]]; then
  err "matrix injection guard differs between build.yml / review.yml / release.yml"
  err "  build=${H_BUILD:0:16} review=${H_REVIEW:0:16} release=${H_RELEASE:0:16}"
else
  ok "matrix injection guard identical (3 copies)"
fi

# --- 4. The commit-status context is one string, spelled once --------------
CONTEXTS=$(grep -rhoE '\-f context="[^"]+"' "$WF" | sed 's/.*context="//; s/"//' | sort -u)
if [[ "$(wc -l <<<"$CONTEXTS")" -ne 1 ]]; then
  err "more than one commit-status context in use:"; echo "$CONTEXTS" >&2
elif [[ "$CONTEXTS" != "review/cve-policy" ]]; then
  err "unexpected commit-status context: $CONTEXTS"
else
  ok "commit status context: review/cve-policy"
fi
# Both the seeder and the resolver must exist, or a required check hangs forever.
grep -q 'context="review/cve-policy"' "$WF/pr-gate.yml" || err "pr-gate.yml does not seed review/cve-policy"
grep -q 'context="review/cve-policy"' "$WF/review.yml"  || err "review.yml does not resolve review/cve-policy"

# --- 5. pr-gate's BUILD_PATHS regex covers build.yml's paths filter --------
python3 - <<'PY' || fail=1
import re, sys, yaml
b = yaml.safe_load(open('.github/workflows/build.yml'))
on = b.get(True) or b.get('on')
paths = (on.get('pull_request') or {}).get('paths', [])
src = open('.github/workflows/pr-gate.yml').read()
m = re.search(r"BUILD_PATHS='([^']+)'", src)
if not m:
    print("error: pr-gate.yml has no BUILD_PATHS regex", file=sys.stderr); sys.exit(1)
rx = re.compile(m.group(1))
missing = []
for p in paths:
    # Turn a glob into a representative path the regex must match.
    probe = p.replace('/**', '/x').replace('**/', '').replace('*', 'x')
    if not rx.search(probe):
        missing.append((p, probe))
if missing:
    for p, probe in missing:
        print(f"error: build.yml watches {p!r} but pr-gate BUILD_PATHS does not match {probe!r}", file=sys.stderr)
    sys.exit(1)
print("  %-52s %s" % (f"pr-gate BUILD_PATHS covers build.yml paths ({len(paths)})", "OK"))
PY

# --- 6. Least privilege: top-level permissions must be empty --------------
python3 - <<'PY' || fail=1
import glob, sys, yaml
bad = False
for f in sorted(glob.glob('.github/workflows/*.yml')):
    d = yaml.safe_load(open(f))
    if d.get('permissions') != {}:
        print(f"error: {f} does not declare `permissions: {{}}` at top level", file=sys.stderr)
        bad = True
print("  %-52s %s" % ("top-level permissions: {} everywhere", "OK"))
sys.exit(1 if bad else 0)
PY

# --- 7. Signing jobs bind an environment ----------------------------------
# The environment key is the ENTIRE key-isolation mechanism: all three actors
# read the same secret name, and which key they get is decided solely by this.
python3 - <<'PY' || fail=1
import glob, sys, yaml
bad = False
for f in sorted(glob.glob('.github/workflows/*.yml')):
    d = yaml.safe_load(open(f))
    for name, job in (d.get('jobs') or {}).items():
        uses_key = 'COSIGN_PRIVATE_KEY' in yaml.dump(job)
        if uses_key and not job.get('environment'):
            print(f"error: {f}:{name} uses COSIGN_PRIVATE_KEY without an environment: binding", file=sys.stderr)
            bad = True
print("  %-52s %s" % ("every signing job binds an environment", "OK"))
sys.exit(1 if bad else 0)
PY

# --- 8. Referenced scripts exist and are executable ------------------------
while read -r s; do
  [[ -x "${s#./}" ]] || err "workflow references ${s}, which is missing or not executable"
done < <(grep -rhoE '\./scripts/[a-z-]+\.(sh|py)' "$WF" | sort -u)
ok "referenced scripts present"

# --- 9. --replace is never passed to cosign attest ------------------------
# It was safe in the reference; here it would DELETE the vendor attestations the
# mirror exists to preserve, and clobber the amd64 SBOM when writing arm64.
# Exclude this file (it names the flag in order to forbid it) and comment lines.
HITS=$(grep -rn 'cosign attest' scripts/ "$WF" \
        | grep -v '^scripts/lint-workflows\.sh:' \
        | grep -vE ':[[:space:]]*#' \
        | grep -- '--replace' || true)
if [[ -n "$HITS" ]]; then
  err "cosign attest --replace found; it would destroy mirrored vendor attestations:"
  echo "$HITS" >&2
else
  ok "no cosign attest --replace"
fi

[[ "$fail" -eq 0 ]] && echo "OK: workflow lint passed"
exit "$fail"
