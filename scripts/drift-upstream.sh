#!/usr/bin/env bash
# Detect upstream releases newer than our pins, within each entry's declared
# track, and rewrite versions.json in place.
#
# `track` is an ANCHORED regex bounding which upstream references a pin may
# legally move to. Widening one is a policy change, not a digest bump, which is
# why versions.json sits behind @infrashift/security-admins. Nothing here ever
# edits a track.
#
# Writes a markdown summary to $DRIFT_REPORT (default /tmp/drift-upstream.md).
set -euo pipefail

VERSIONS=versions.json
REPORT="${DRIFT_REPORT:-/tmp/drift-upstream.md}"
CHANGED=0
MIRROR_ROWS=""
BUILD_ROWS=""
ALARMS=""
: > "$REPORT"

# Highest version-sorted tag matching an anchored track regex. The re-grep after
# sorting is what mechanically guarantees an out-of-track tag can never be
# proposed: sort -V is a heuristic, the track is the contract.
highest_matching() {
  local tags="$1" track="$2" cand
  cand=$(grep -E "$track" <<<"$tags" | sort -V | tail -1 || true)
  [[ -n "$cand" ]] || return 1
  grep -qE "$track" <<<"$cand" || return 1
  printf '%s' "$cand"
}

# ===========================================================================
# Mirror track
# ===========================================================================
while IFS=$'\t' read -r svc variant; do
  repo=$(jq -r --arg s "$svc" '.images[$s].upstreamRepo' "$VERSIONS")
  tag=$(jq -r    --arg s "$svc" --arg v "$variant" '.images[$s].variants[$v].tag'    "$VERSIONS")
  track=$(jq -r  --arg s "$svc" --arg v "$variant" '.images[$s].variants[$v].track'  "$VERSIONS")
  pinned=$(jq -r --arg s "$svc" --arg v "$variant" '.images[$s].variants[$v].digest' "$VERSIONS")
  if ! TAGS=$(regctl tag ls "$repo" 2>/dev/null); then
    echo "  ${svc}/${variant}: cannot list tags (auth required, or registry error)"
    ALARMS+="- \`${svc}/${variant}\`: tag listing failed. DHI needs an authenticated session; check the OIDC login."$'\n'
    continue
  fi

  MATCHES=$(grep -cE "$track" <<<"$TAGS" || true)
  CAND=$(highest_matching "$TAGS" "$track" || echo "")
  if [[ -z "$CAND" ]]; then
    ALARMS+="- \`${svc}/${variant}\`: no upstream tag matches its own track \`${track}\`. The pin or the track is wrong."$'\n'
    continue
  fi

  # Where the pinned tag currently points, regardless of any newer tag.
  LIVE=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${repo}:${tag}" 2>/dev/null || echo "")

  if [[ "$MATCHES" -eq 1 && "$CAND" == "$tag" ]]; then
    # The track admits exactly one literal tag: a ROLLING tag. Upstream moves
    # the digest behind it on purpose -- that is how DHI ships its zero-CVE
    # rebuilds -- so a changed digest is expected and is the whole signal.
    if [[ -n "$LIVE" && "$LIVE" != "$pinned" ]]; then
      jq --arg s "$svc" --arg v "$variant" --arg d "$LIVE" \
        '.images[$s].variants[$v].digest = $d' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
      MIRROR_ROWS+="| \`${svc}/${variant}\` | rolling | \`${tag}\` | \`${pinned:0:19}…\` | \`${LIVE:0:19}…\` | re-pinned |"$'\n'
      printf '  %-22s rolling tag moved: %s -> %s\n' "${svc}/${variant}" "${pinned:0:19}…" "${LIVE:0:19}…"
      CHANGED=1
    else
      printf '  %-22s current\n' "${svc}/${variant}"
    fi
    continue
  fi

  # The track admits several tags: they are IMMUTABLE version tags. A newer one
  # is a version bump; the pinned one changing underneath us is a retag, which
  # should never happen and is reported separately and loudly.
  if [[ -n "$LIVE" && "$LIVE" != "$pinned" ]]; then
    ALARMS+="- **UPSTREAM RETAG**: \`${repo}:${tag}\` was \`${pinned}\`, is now \`${LIVE}\`. An immutable version tag moved. Investigate before merging anything."$'\n'
  fi

  if [[ "$CAND" != "$tag" ]]; then
    NEWDIG=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${repo}:${CAND}" 2>/dev/null || echo "")
    if [[ -z "$NEWDIG" ]]; then
      ALARMS+="- \`${svc}/${variant}\`: candidate \`${CAND}\` could not be resolved."$'\n'
      continue
    fi
    jq --arg s "$svc" --arg v "$variant" --arg t "$CAND" --arg d "$NEWDIG" \
      '.images[$s].variants[$v].tag = $t | .images[$s].variants[$v].digest = $d' \
      "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
    MIRROR_ROWS+="| \`${svc}/${variant}\` | tracked | \`${tag}\` → \`${CAND}\` | \`${pinned:0:19}…\` | \`${NEWDIG:0:19}…\` | bumped |"$'\n'
    printf '  %-22s new release within track: %s -> %s\n' "${svc}/${variant}" "$tag" "$CAND"
    CHANGED=1
  else
    printf '  %-22s current\n' "${svc}/${variant}"
  fi
done < <(jq -r '.images | to_entries[] | select(.value.kind=="mirror")
                | .key as $s | .value.variants | keys[] | [$s, .] | @tsv' "$VERSIONS")

# ===========================================================================
# Build track
# ===========================================================================
while read -r key; do
  url=$(jq -r   --arg k "$key" '.sources[$k].url // ""'  "$VERSIONS")
  track=$(jq -r --arg k "$key" '.sources[$k].track'      "$VERSIONS")
  ref=$(jq -r   --arg k "$key" '.sources[$k].ref'        "$VERSIONS")
  # Sources with a `repos` map (Ory) have no single top-level url; probe any
  # member repo for the tag list, since they release in lockstep off one tag.
  if [[ -z "$url" ]]; then
    url=$(jq -r --arg k "$key" '[.sources[$k].repos[]?.url] | first // ""' "$VERSIONS")
  fi
  TAGS=$(git ls-remote --tags --refs "$url" 2>/dev/null | awk '{print $2}' | sed 's|refs/tags/||' || true)
  if [[ -z "$TAGS" ]]; then
    ALARMS+="- source \`${key}\`: could not list tags at ${url}."$'\n'
    continue
  fi
  CAND=$(highest_matching "$TAGS" "$track" || echo "")
  if [[ -z "$CAND" ]]; then
    ALARMS+="- source \`${key}\`: no upstream tag matches its own track \`${track}\`."$'\n'
    continue
  fi
  if [[ "$CAND" == "$ref" ]]; then
    printf '  %-22s current (%s)\n' "source/${key}" "$ref"
    continue
  fi

  printf '  %-22s new release within track: %s -> %s\n' "source/${key}" "$ref" "$CAND"
  jq --arg k "$key" --arg r "$CAND" '.sources[$k].ref = $r' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"

  # Resolve the commit for every repo under this source. Ory releases four
  # repos in lockstep off one tag; a partial bump is a bug, so they all move
  # together or the run fails.
  if jq -e --arg k "$key" '.sources[$k].repos' "$VERSIONS" >/dev/null 2>&1; then
    while read -r rname; do
      rurl=$(jq -r --arg k "$key" --arg r "$rname" '.sources[$k].repos[$r].url' "$VERSIONS")
      SHA=$(git ls-remote "$rurl" "refs/tags/${CAND}^{}" 2>/dev/null | awk '{print $1}' | head -1)
      [[ -z "$SHA" ]] && SHA=$(git ls-remote "$rurl" "refs/tags/${CAND}" 2>/dev/null | awk '{print $1}' | head -1)
      if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
        ALARMS+="- source \`${key}/${rname}\`: tag \`${CAND}\` did not resolve to a commit. Lockstep bump aborted."$'\n'
        continue
      fi
      jq --arg k "$key" --arg r "$rname" --arg c "$SHA" \
        '.sources[$k].repos[$r].commit = $c' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
      BUILD_ROWS+="| \`${key}/${rname}\` | \`${ref}\` → \`${CAND}\` | \`${SHA:0:12}\` |"$'\n'
    done < <(jq -r --arg k "$key" '.sources[$k].repos | keys[]' "$VERSIONS")
  else
    SHA=$(git ls-remote "$url" "refs/tags/${CAND}^{}" 2>/dev/null | awk '{print $1}' | head -1)
    [[ -z "$SHA" ]] && SHA=$(git ls-remote "$url" "refs/tags/${CAND}" 2>/dev/null | awk '{print $1}' | head -1)
    if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
      ALARMS+="- source \`${key}\`: tag \`${CAND}\` did not resolve to a commit."$'\n'
      continue
    fi
    jq --arg k "$key" --arg c "$SHA" '.sources[$k].commit = $c' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
    BUILD_ROWS+="| \`${key}\` | \`${ref}\` → \`${CAND}\` | \`${SHA:0:12}\` |"$'\n'

    # A pinned shortCommit is git's DYNAMIC abbreviation for the full repo, so
    # it cannot be sliced from the full SHA. A blobless bare clone gives real
    # history cheaply and lets git compute it. Getting the length wrong changes
    # an embedded string and therefore the binary -- see
    # docs/build-track/dual-provenance.md.
    if jq -e --arg k "$key" '.sources[$k].shortCommit' "$VERSIONS" >/dev/null 2>&1; then
      TMPC=$(mktemp -d)
      if git clone --quiet --filter=blob:none --bare "$url" "$TMPC/r" 2>/dev/null; then
        SHORT=$(git -C "$TMPC/r" rev-parse --short "$SHA" 2>/dev/null || echo "")
        if [[ -n "$SHORT" && "$SHA" == "$SHORT"* ]]; then
          jq --arg k "$key" --arg s "$SHORT" '.sources[$k].shortCommit = $s' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
          BUILD_ROWS+="| \`${key}\` shortCommit | — | \`${SHORT}\` (${#SHORT} chars) |"$'\n'
        else
          ALARMS+="- source \`${key}\`: could not compute shortCommit; determine it manually before merging (see docs/build-track/dual-provenance.md)."$'\n'
        fi
      else
        ALARMS+="- source \`${key}\`: blobless clone failed; shortCommit not updated."$'\n'
      fi
      rm -rf "$TMPC"
    fi
  fi

  # Re-point every crosscheck reference that embeds the old version string.
  # Vendors template their per-platform tags off the release version, with or
  # without a leading v, so both forms are substituted.
  OLD_BARE="${ref#v}"; NEW_BARE="${CAND#v}"
  while IFS=$'\t' read -r svc arch; do
    xrepo=$(jq -r --arg s "$svc" '.images[$s].crosscheck.image' "$VERSIONS")
    xtag=$(jq -r  --arg s "$svc" --arg a "$arch" '.images[$s].crosscheck[$a].tag' "$VERSIONS")
    NEWTAG="${xtag//$ref/$CAND}"; NEWTAG="${NEWTAG//$OLD_BARE/$NEW_BARE}"
    [[ "$NEWTAG" == "$xtag" ]] && continue
    XD=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${xrepo}:${NEWTAG}" 2>/dev/null || echo "")
    if [[ -z "$XD" ]]; then
      ALARMS+="- \`${svc}\`: crosscheck tag \`${NEWTAG}\` could not be resolved; re-pin it manually."$'\n'
      continue
    fi
    jq --arg s "$svc" --arg a "$arch" --arg t "$NEWTAG" --arg d "$XD" \
      '.images[$s].crosscheck[$a].tag = $t | .images[$s].crosscheck[$a].digest = $d' \
      "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
    BUILD_ROWS+="| \`${svc}\` crosscheck ${arch} | \`${xtag}\` → \`${NEWTAG}\` | \`${XD:0:12}\` |"$'\n'
  done < <(jq -r --arg k "$key" '.images | to_entries[]
            | select(.value.kind=="build" and .value.source==$k)
            | .key as $s | (.value.crosscheck | keys[] | select(. == "amd64" or . == "arm64")) as $a
            | [$s, $a] | @tsv' "$VERSIONS")

  CHANGED=1
done < <(jq -r '.sources | keys[]' "$VERSIONS")

# ===========================================================================
# Report
# ===========================================================================
if [[ "$CHANGED" -eq 1 || -n "$ALARMS" ]]; then
  TODAY=$(date -u +'%Y-%m-%d')
  [[ "$CHANGED" -eq 1 ]] && {
    jq --arg d "$TODAY" '.images |= with_entries(.value.updated = $d)' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"; }
  {
    echo "Automated scan found upstream references newer than the pins in \`versions.json\`,"
    echo "within each entry's declared track. **No track was widened** — a track change is a"
    echo "policy decision and needs its own reviewed PR."
    echo
    [[ -n "$MIRROR_ROWS" ]] && { echo "### Mirror track"; echo; echo "| Image | Kind | Tag | Pinned | Current | |"; echo "|---|---|---|---|---|---|"; printf '%s' "$MIRROR_ROWS"; echo; }
    [[ -n "$BUILD_ROWS" ]]  && { echo "### Build track"; echo; echo "| Entry | Ref | New value |"; echo "|---|---|---|"; printf '%s' "$BUILD_ROWS"; echo; }
    [[ -n "$ALARMS" ]] && { echo "### Needs attention"; echo; printf '%s' "$ALARMS"; echo; }
    echo "### Before merging"
    echo
    echo '```'
    echo "make -f Ops.mk verify-pins   # re-resolve every pin"
    echo "make -f Ops.mk validate      # schema, policy, lints"
    echo '```'
    echo
    echo "A build-track bump also moves the source commit, so read the upstream release"
    echo "notes: these are application version changes, not just rebuilds."
  } > "$REPORT"
  if [[ "$CHANGED" -eq 1 ]]; then echo "drift detected; versions.json updated"; else echo "no drift, but items need attention"; fi
else
  echo "No upstream drift: every pin is the newest reference within its track." > "$REPORT"
  echo "no drift"
fi

# CHANGED gates whether a branch is pushed; alarms alone must not produce an
# empty proposal PR. They still reach the tracking issue and the step summary.
[[ -n "$ALARMS" ]] && echo "alarms=1" >> "${GITHUB_OUTPUT:-/dev/null}" || echo "alarms=0" >> "${GITHUB_OUTPUT:-/dev/null}"

echo "changed=${CHANGED}" >> "${GITHUB_OUTPUT:-/dev/null}"
