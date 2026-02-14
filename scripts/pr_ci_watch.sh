#!/usr/bin/env bash
set -euo pipefail

OWNER="${1:-haze2026ai}"
TOKEN_FILE="${GH_TOKEN_FILE:-}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install with: apt-get install -y gh" >&2
  exit 2
fi

if [ -z "${GH_TOKEN:-}" ] && [ -n "$TOKEN_FILE" ] && [ -f "$TOKEN_FILE" ]; then
  export GH_TOKEN
  GH_TOKEN="$(cat "$TOKEN_FILE")"
fi

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN not set. Set GH_TOKEN or GH_TOKEN_FILE." >&2
  exit 2
fi

# List repos (public + private) for owner
repos=$(gh repo list "$OWNER" --limit 200 --json name --jq '.[].name')

fail=0
summary=""

for repo in $repos; do
  prs=$(gh pr list --repo "$OWNER/$repo" --state open --json number,headRefName,title --jq '.[] | "\(.number)\t\(.headRefName)\t\(.title)"') || true
  if [ -z "$prs" ]; then
    continue
  fi

  while IFS=$'\t' read -r num head title; do
    sha=$(gh pr view "$num" --repo "$OWNER/$repo" --json headRefOid --jq .headRefOid) || true
    if [ -z "$sha" ]; then
      summary+="$OWNER/$repo#$num: unable to resolve head SHA\n"
      fail=1
      continue
    fi

    # Check runs
    checks=$(gh api "repos/$OWNER/$repo/commits/$sha/check-runs" --jq '.check_runs[] | "\(.name)\t\(.status)\t\(.conclusion)"') || true
    if [ -n "$checks" ]; then
      while IFS=$'\t' read -r name status conclusion; do
        if [ "$status" != "completed" ]; then
          summary+="$OWNER/$repo#$num: $name is $status\n"
          fail=1
        elif [ "$conclusion" != "success" ] && [ "$conclusion" != "neutral" ] && [ "$conclusion" != "skipped" ]; then
          summary+="$OWNER/$repo#$num: $name concluded $conclusion\n"
          fail=1
        fi
      done <<< "$checks"
    fi

    # Commit status contexts
    statuses=$(gh api "repos/$OWNER/$repo/commits/$sha/status" --jq '.statuses[] | "\(.context)\t\(.state)"') || true
    if [ -n "$statuses" ]; then
      while IFS=$'\t' read -r ctx state; do
        if [ "$state" != "success" ] && [ "$state" != "neutral" ]; then
          summary+="$OWNER/$repo#$num: $ctx is $state\n"
          fail=1
        fi
      done <<< "$statuses"
    fi
  done <<< "$prs"

done

if [ $fail -eq 1 ]; then
  echo -e "CI check issues detected:\n$summary"
  exit 1
fi

echo "All PR checks are green or neutral."
