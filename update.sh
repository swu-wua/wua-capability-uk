#!/usr/bin/env bash
# Quick-update for the UK repo. Edit index.html, then run this.
set -euo pipefail
cd "$(dirname "$0")"
if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to push."
  exit 0
fi
git add .
git commit -m "${1:-Content update $(date +%Y-%m-%d)}"
git push
echo
echo "✅ Pushed. Vercel will redeploy in ~20-30s."
