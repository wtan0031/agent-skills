#!/usr/bin/env bash
# uninstall.sh — remove only the symlinks pointing back into THIS repo (however the
# path is spelled, or into a moved checkout) from every current and legacy AI tool
# skill directory. Safe on a shared machine — real directories and symlinks from
# other repos are left untouched.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=skill-links.sh
. "$REPO/skill-links.sh"

total=0
for DEST in "${ALL_DIRS[@]}"; do
  [ -d "$DEST" ] || continue
  removed=0
  for link in "$DEST"/*; do
    is_repo_link "$link" || continue
    rm "$link"; removed=$((removed + 1))
  done
  [ "$removed" -gt 0 ] && echo "✗ ${DEST/#"$SKILLS_HOME"/\~}: removed $removed symlink(s)"
  total=$((total + removed))
done

echo
echo "Removed $total symlink(s) total. Everything else left untouched."
