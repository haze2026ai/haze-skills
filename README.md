# haze-skills

Deterministic scripts + skills for OpenClaw workflows. Keep this repo as the single source of truth for reusable automation.

## Scripts

- `scripts/pr_ci_watch.sh` — check CI status for all open PRs across `haze2026ai` repos.
- `scripts/run_checks.sh` — wrapper to run checks (extend with more scripts).

## Usage

```bash
export GH_TOKEN=... # or ensure /etc/openclaw/creds/github_token exists
bash scripts/run_checks.sh
```

## Extending

Add new scripts in `scripts/` and wire them into `scripts/run_checks.sh`.
