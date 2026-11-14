#!/usr/bin/env bash
# Run scripts/provenance-mode.sh against a fixture versions.json.
#
# The first-party build mode (ADR-008) lets a build entry skip the vendor
# binary comparison. These cases hold the build actor's pre-flight to the
# same rules as the policy: absence of `crosscheck` is never first-party, the
# declaration is explicit and reasoned, and only a source under
# https://github.com/infrashift/ may make it -- including through an Ory-style
# `repo` key, where the top-level url is a decoy.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/provenance-mode.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "error: test-provenance-mode: $*" >&2; exit 1; }

R="infrashift is the only publisher of this service, so no vendor binary exists to compare."
FP="\"firstParty\": { \"noVendorBinary\": true, \"reason\": \"${R}\" }"
XC='"crosscheck": { "image": "docker.io/oryd/keto" }'

cat > "$TMP/versions.json" <<EOF
{
  "sources": {
    "ours":      { "url": "https://github.com/infrashift/keto-cue" },
    "vendor":    { "url": "https://github.com/ory/keto" },
    "lookalike": { "url": "https://github.com/infrashift.evil/keto-cue" },
    "dotdot":    { "url": "https://github.com/infrashift/../ory/keto" },
    "plainhttp": { "url": "http://github.com/infrashift/keto-cue" },
    "nourl":     { },
    "ory":       { "url": "https://github.com/infrashift/decoy",
                   "repos": { "keto": { "url": "https://github.com/ory/keto" },
                              "fork": { "url": "https://github.com/infrashift/keto-fork" } } }
  },
  "images": {
    "vendor-ok":      { "kind": "build", "source": "vendor", ${XC} },
    "fp-ok":          { "kind": "build", "source": "ours", ${FP} },
    "fp-repo-ok":     { "kind": "build", "source": "ory", "repo": "fork", ${FP} },
    "neither":        { "kind": "build", "source": "ours" },
    "both":           { "kind": "build", "source": "ours", ${XC}, ${FP} },
    "fp-vendor":      { "kind": "build", "source": "vendor", ${FP} },
    "fp-lookalike":   { "kind": "build", "source": "lookalike", ${FP} },
    "fp-dotdot":      { "kind": "build", "source": "dotdot", ${FP} },
    "fp-plainhttp":   { "kind": "build", "source": "plainhttp", ${FP} },
    "fp-nourl":       { "kind": "build", "source": "nourl", ${FP} },
    "fp-repo-vendor": { "kind": "build", "source": "ory", "repo": "keto", ${FP} },
    "fp-false":       { "kind": "build", "source": "ours", "firstParty": { "noVendorBinary": false, "reason": "${R}" } },
    "fp-string":      { "kind": "build", "source": "ours", "firstParty": { "noVendorBinary": "true", "reason": "${R}" } },
    "fp-noreason":    { "kind": "build", "source": "ours", "firstParty": { "noVendorBinary": true } },
    "fp-short":       { "kind": "build", "source": "ours", "firstParty": { "noVendorBinary": true, "reason": "ours" } },
    "fp-padded":      { "kind": "build", "source": "ours", "firstParty": { "noVendorBinary": true, "reason": "     ours                                              " } },
    "fp-scalar":      { "kind": "build", "source": "ours", "firstParty": true },
    "mirror":         { "kind": "mirror" }
  }
}
EOF

run() { "$SCRIPT" "$1" "$TMP/versions.json" 2>"$TMP/err"; }

expect_mode() {
  local svc="$1" want="$2" out
  out=$(run "$svc") || { cat "$TMP/err" >&2; fail "${svc}: exited non-zero, want mode ${want}"; }
  [[ "$(jq -r '.mode' <<<"$out")" == "$want" ]] || fail "${svc}: got ${out}, want mode ${want}"
}

# The refusal must be for the RIGHT reason: a later check that happens to
# catch the case would hide a deleted earlier one.
expect_refused() {
  local svc="$1" said="$2" why="$3" out
  if out=$(run "$svc"); then
    fail "${svc}: accepted (${out}); it must be refused: ${why}"
  fi
  grep -q "::error::.*${said}" "$TMP/err" \
    || fail "${svc}: refused, but not with '${said}' (${why}): $(cat "$TMP/err")"
}

expect_mode vendor-ok  vendor-crosscheck
expect_mode fp-ok      first-party
expect_mode fp-repo-ok first-party
[[ "$(run fp-ok | jq -r '.sourceUrl')" == "https://github.com/infrashift/keto-cue" ]] || fail "fp-ok: wrong sourceUrl"
[[ "$(run fp-repo-ok | jq -r '.sourceUrl')" == "https://github.com/infrashift/keto-fork" ]] || fail "fp-repo-ok: sourceUrl must follow the repo key"
[[ "$(run fp-ok | jq -r '.reason')" == "$R" ]] || fail "fp-ok: reason not carried through"

expect_refused neither        "neither crosscheck nor firstParty" "absence of crosscheck is not a first-party claim"
expect_refused both           "both crosscheck and firstParty"    "the two modes exclude each other"
expect_refused fp-vendor      "not a repository under"            "a vendor source may not be first-party"
expect_refused fp-lookalike   "not a repository under"            "github.com/infrashift.evil is not github.com/infrashift"
expect_refused fp-dotdot      "not a repository under"            "a path that leaves the infrashift org"
expect_refused fp-plainhttp   "not a repository under"            "only https"
expect_refused fp-nourl       "not a repository under"            "no source url"
expect_refused fp-repo-vendor "not a repository under"            "the repo key resolves to ory/keto; the top-level url is a decoy"
expect_refused fp-false       "noVendorBinary is not"             "noVendorBinary must be true"
expect_refused fp-string      "noVendorBinary is not"             "noVendorBinary must be the boolean true"
expect_refused fp-noreason    "reason has 0 characters"           "a reason is mandatory"
expect_refused fp-short       "reason has 4 characters"           "the reason must have at least 40 characters"
expect_refused fp-padded      "reason has 4 characters"           "whitespace does not count toward the reason"
expect_refused fp-scalar      "noVendorBinary is not"             "firstParty must be an object"
expect_refused mirror         "not a build entry"                 "a mirror entry has no build provenance mode"
expect_refused no-such-image  "no image entry"                    "an unknown image"

echo "OK: provenance-mode.sh refuses an absent, double, malformed or non-infrashift first-party declaration, and resolves the source through the repo key"
