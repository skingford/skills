#!/bin/bash
# Install all skills from this repo globally
# Usage: curl -fsSL https://raw.githubusercontent.com/skingford/skills/main/scripts/install.sh | bash
#
# Agent-specific install (when CLI supports --agent):
#   npx skills add skingford/skills --skill '*' -g -y --agent claude
#   npx skills add skingford/skills --skill '*' -g -y --agent codex
#   npx skills add skingford/skills --skill '*' -g -y --agent cursor

set -e

REPO="skingford/skills"

echo "Installing skills from $REPO..."
npx skills add "$REPO" --skill '*' -g -y

echo ""
echo "Done! Installed skills:"
npx skills list 2>/dev/null | grep -A1 "$REPO" || echo "  (run 'npx skills list' to verify)"
