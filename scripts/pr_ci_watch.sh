#!/usr/bin/env bash
set -euo pipefail

OWNER="${1:-haze2026ai}"
TOKEN_FILE="/etc/openclaw/creds/github_token"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install with: apt-get install -y gh" >&2
  exit 2
fi

if [ -z "${GH_TOKEN:-}" ] && [ -f "$TOKEN_FILE" ]; then
  export GH_TOKEN
  GH_TOKEN="$(cat "$TOKEN_FILE")"
fi

if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN not set and $TOKEN_FILE not found." >&2
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
    checks=$(gh pr checks "$num" --repo "$OWNER/$repo" --json name,status,conclusion --jq '.[] | "\(.name)\t\(.status)\t\(.conclusion)"') || true
    if [ -z "$checks" ]; then
      summary+="$OWNER/$repo#$num: no checks found\n"
      continue
    fi

    while IFS=$'\t' read -r name status conclusion; do
      if [ "$status" != "COMPLETED" ] && [ "$status" != "completed" ]; then
        summary+="$OWNER/$repo#$num: $name is $status\n"
        fail=1
      elif [ "$conclusion" != "SUCCESS" ] && [ "$conclusion" != "success" ] && [ "$conclusion" != "NEUTRAL" ] && [ "$conclusion" != "neutral" ]; then
        summary+="$OWNER/$repo#$num: $name concluded $conclusion\n"
        fail=1
      fi
    done <<< "$checks"
  done <<< "$prs"

done

if [ $fail -eq 1 ]; then
  echo -e "CI check issues detected:\n$summary"
  exit 1
fi

echo "All PR checks are green or neutral."
