#!/usr/bin/env bash
set -euo pipefail

# Wrapper to run deterministic checks. Add new scripts here.

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

bash "$DIR/pr_ci_watch.sh" "haze2026ai"
