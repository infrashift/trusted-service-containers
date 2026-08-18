#!/usr/bin/env bash
# Publish a drift proposal: push a branch with the versions.json change, and
# upsert a single tracking issue.
#
# GITHUB_TOKEN cannot open pull requests while "Allow GitHub Actions to create
# and approve pull requests" is disabled -- and it stays disabled, because the
# same setting would let a workflow satisfy a required approval. It CAN create
# and edit issues, so the issue is how drift becomes visible. The reference repo
# settles for a ::warning::, which nobody sees unless they open the Actions tab.
#
# A GITHUB_TOKEN-authored commit also does not trigger downstream workflows, so
# the PR a human opens from this branch is what actually runs build/review.
#
# Required env: BRANCH LABEL TITLE REPORT GITHUB_REPOSITORY GH_TOKEN
# Optional:     CHANGED (0/1) ALARMS (0/1)
set -euo pipefail

: "${BRANCH:?}" "${LABEL:?}" "${TITLE:?}" "${REPORT:?}" "${GITHUB_REPOSITORY:?}"
CHANGED="${CHANGED:-0}"
ALARMS="${ALARMS:-0}"

[[ -f "$REPORT" ]] || { echo "::error::report ${REPORT} not found"; exit 1; }

COMPARE="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/compare/main...${BRANCH}?expand=1"

# --- Close the loop when everything is clean -------------------------------
if [[ "$CHANGED" != "1" && "$ALARMS" != "1" ]]; then
  echo "nothing to propose"
  EXISTING=$(gh issue list --repo "$GITHUB_REPOSITORY" --label "$LABEL" --state open \
              --json number --jq '.[0].number // empty' || true)
  if [[ -n "$EXISTING" ]]; then
    gh issue comment "$EXISTING" --repo "$GITHUB_REPOSITORY" \
      --body "Resolved: every pin is current as of $(date -u +'%Y-%m-%d'). Closing." >/dev/null
    gh issue close "$EXISTING" --repo "$GITHUB_REPOSITORY" >/dev/null
    echo "closed tracking issue #${EXISTING}"
  fi
  exit 0
fi

# --- Push the branch, only when versions.json actually changed -------------
if [[ "$CHANGED" == "1" ]]; then
  if git diff --quiet -- versions.json; then
    echo "::warning::CHANGED=1 but versions.json has no diff; not pushing a branch"
  else
    git config user.name  "infrashift-drift[bot]"
    git config user.email "drift@infrashift.io"
    git checkout -B "$BRANCH"
    git add versions.json
    git commit -q -m "chore(pins): ${TITLE}" -F - <<EOF
chore(pins): ${TITLE}

$(cat "$REPORT")
EOF
    # Force-push keeps exactly one outstanding proposal rather than a pile of
    # near-identical branches.
    git push --force -q origin "$BRANCH"
    echo "pushed ${BRANCH}"
  fi
fi

# --- Upsert one tracking issue ---------------------------------------------
BODY=$(mktemp)
{
  cat "$REPORT"
  echo
  if [[ "$CHANGED" == "1" ]]; then
    echo "---"
    echo
    echo "Branch \`${BRANCH}\` has been updated with these changes."
    echo "**[Open the pull request](${COMPARE})** — a human must open it, because"
    echo "\`GITHUB_TOKEN\` cannot create PRs here by design, and a token-authored"
    echo "commit would not trigger \`build.yml\` anyway."
  fi
  echo
  echo "<sub>Updated by \`${GITHUB_WORKFLOW:-drift}\` on $(date -u +'%Y-%m-%d %H:%M UTC'). "
  echo "This issue is reused, not duplicated; it closes automatically when every pin is current.</sub>"
} > "$BODY"

gh label create "$LABEL" --repo "$GITHUB_REPOSITORY" --color 0E8A16 \
  --description "Automated upstream/base drift tracking" >/dev/null 2>&1 || true

EXISTING=$(gh issue list --repo "$GITHUB_REPOSITORY" --label "$LABEL" --state open \
            --json number --jq '.[0].number // empty' || true)
if [[ -n "$EXISTING" ]]; then
  gh issue edit "$EXISTING" --repo "$GITHUB_REPOSITORY" --title "$TITLE" --body-file "$BODY" >/dev/null
  echo "updated tracking issue #${EXISTING}"
else
  URL=$(gh issue create --repo "$GITHUB_REPOSITORY" --title "$TITLE" \
          --label "$LABEL" --body-file "$BODY")
  echo "created tracking issue ${URL}"
fi

{ echo "## ${TITLE}"; echo; cat "$BODY"; } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
rm -f "$BODY"
