#!/usr/bin/env bash
set -euo pipefail

# Sync fork with upstream LibreChat
# Usage: ./scripts/sync-upstream.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Fetching upstream..."
git fetch upstream

echo "==> Current branch: $(git branch --show-current)"

echo "==> Rebasing onto upstream/main..."
git rebase upstream/main

echo "==> Upstream sync complete."
echo "    Review with: git log --oneline -20"
echo "    Push with:   git push origin main"
