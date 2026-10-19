#!/usr/bin/env bash
# install.sh — symlink every skill in this repo into each AI tool's skills directory.
# Run after cloning on a new machine, or after adding a skill.
#
#   ./install.sh            link every skill into all supported tools
#   ./install.sh <bundle>   link only skills/<bundle>/
#
# Supported tools (directories are created automatically if missing):
#   Claude Code                   → ~/.claude/skills/
#   Codex CLI, GitHub Copilot CLI → ~/.agents/skills/ (shared Agent Skills directory)
#   Gemini CLI                    → ~/.gemini/skills/
#   Codex CLI (legacy path)       → ~/.codex/skills/
# The list lives in skill-links.sh, shared with uninstall.sh.
#
# Symlinks (not copies) so `git pull` and local edits stay in sync with the repo.
# Skips recipes (frontmatter `metadata.recipe: "true"`) and preserves existing
# real directories and symlinks owned by another location. Links into this repo by
# another path, or into a moved checkout, are relinked, so re-running repairs them.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BUNDLE="${1:-all}"
# shellcheck source=skill-links.sh
. "$REPO/skill-links.sh"

SCOPE="$REPO/skills"
if [ "$BUNDLE" != "all" ]; then
  if [ -d "$REPO/skills/$BUNDLE" ]; then
    SCOPE="$REPO/skills/$BUNDLE"
  else
    echo "Unknown bundle '$BUNDLE' (no $REPO/skills/$BUNDLE). Use 'all' or a category folder name." >&2
    exit 1
  fi
fi

# True when the frontmatter sets `recipe: true` (top-level or under `metadata:`, quoted or not).
is_recipe() {
  awk '/^---[[:space:]]*$/ { n++; next }
       n == 1 && /^[[:space:]]*recipe:[[:space:]]*["'\'']?true["'\'']?[[:space:]]*$/ { found = 1 }
       n >= 2 { exit }
       END { exit !found }' "$1"
}

# Collect skills to link (excluding recipes)
SKILLS=(); recipes=0
while IFS= read -r skillmd; do
  src="$(cd "$(dirname "$skillmd")" && pwd -P)"
  if is_recipe "$skillmd"; then
    echo "· skip $(basename "$src") (recipe, not a slash skill)"
    recipes=$((recipes + 1)); continue
  fi
  SKILLS+=("$src")
done < <(find "$SCOPE" -name SKILL.md -type f | sort)

echo "Found ${#SKILLS[@]} skill(s)  ($recipes recipe(s) skipped)."
echo

canonical_ok=1
for DEST in "${INSTALL_DIRS[@]}"; do
  case "$DEST" in
    */.claude/skills)   label="Claude Code" ;;
    */.agents/skills)   label="Codex CLI and GitHub Copilot CLI" ;;
    */.gemini/skills)   label="Gemini CLI" ;;
    */.codex/skills)    label="Codex CLI (legacy path)" ;;
    *)                  label="$DEST" ;;
  esac

  mkdir -p "$DEST"
  linked=0; skipped=0
  for src in "${SKILLS[@]}"; do
    name="$(basename "$src")"
    link="$DEST/$name"
    if [ -L "$link" ]; then
      target="$(readlink "$link")"
      if [ "$target" = "$src" ]; then
        linked=$((linked + 1)); continue
      fi
      if ! is_repo_link "$link"; then
        if [ -e "$link" ]; then
          echo "  ⚠ skip $name — symlink already points elsewhere at $link"
        else
          echo "  ⚠ skip $name — broken symlink to $target at $link (remove it to relink)"
        fi
        skipped=$((skipped + 1)); continue
      fi
      rm "$link"   # this repo via another path, or a moved checkout — relink canonically
      echo "  ↻ relink $name (was → $target)"
    elif [ -e "$link" ]; then
      echo "  ⚠ skip $name — real directory at $link (remove manually to use repo version)"
      skipped=$((skipped + 1)); continue
    fi
    ln -s "$src" "$link"
    linked=$((linked + 1))
  done
  if [ "$DEST" = "$SKILLS_HOME/.agents/skills" ] && [ "$skipped" -gt 0 ]; then
    canonical_ok=0
  fi
  skip_msg=""
  [ "$skipped" -gt 0 ] && skip_msg=", skipped $skipped"
  echo "✓ $label (${DEST/#"$SKILLS_HOME"/\~}): linked $linked${skip_msg}"
done

# Copilot also reads ~/.agents/skills. Retire only matching links from this
# repository after every selected skill is available at the canonical path.
if [ "$canonical_ok" -eq 1 ]; then
  LEGACY_COPILOT="$SKILLS_HOME/.copilot/skills"
  if [ -d "$LEGACY_COPILOT" ]; then
    migrated=0
    for src in "${SKILLS[@]}"; do
      name="$(basename "$src")"
      link="$LEGACY_COPILOT/$name"
      if is_repo_link "$link"; then
        rm "$link"
        migrated=$((migrated + 1))
      fi
    done
    [ "$migrated" -gt 0 ] && echo "↪ ${LEGACY_COPILOT/#"$SKILLS_HOME"/\~}: retired $migrated duplicate repo link(s)"
  fi
else
  echo "↪ Kept legacy Copilot links because the canonical installation was incomplete."
fi

echo
echo "↻ Restart your AI tool (or open a new session) for new /commands to register."
