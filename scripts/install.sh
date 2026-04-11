#!/bin/bash
# Install all skills from this repo globally
# Usage: curl -fsSL https://raw.githubusercontent.com/kingford/skills/main/scripts/install.sh | bash

set -e

REPO="kingford/skills"

echo "Installing skills from $REPO..."
npx skills add "$REPO" --skill '*' -g -y

echo ""
echo "Done! Installed skills:"
npx skills list 2>/dev/null | grep -A1 "$REPO" || echo "  (run 'npx skills list' to verify)"
