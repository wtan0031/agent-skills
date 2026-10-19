# skill-links.sh — shared by install.sh and uninstall.sh.
# Sourced, not run: the one list of AI-tool skill directories, and the test for
# whether a symlink in them belongs to this repo. Callers set REPO (a physical path).
# AGENT_SKILLS_HOME overrides $HOME (point it at a temporary tree to test safely).

SKILLS_HOME="${AGENT_SKILLS_HOME:-$HOME}"

# Where install.sh links skills.
INSTALL_DIRS=(
  "$SKILLS_HOME/.claude/skills"  # Claude Code
  "$SKILLS_HOME/.agents/skills"  # Codex CLI and GitHub Copilot CLI (Gemini CLI reads it too)
  "$SKILLS_HOME/.gemini/skills"  # Gemini CLI
  "$SKILLS_HOME/.codex/skills"   # Codex CLI legacy path (still read; same-target links listed once)
)
# Every directory a past or present install may have linked into; removal scans all of them.
ALL_DIRS=("${INSTALL_DIRS[@]}" "$SKILLS_HOME/.copilot/skills")  # Copilot's pre-~/.agents path

# is_repo_link <path> — true if <path> is a symlink into this repo's skills/: it resolves
# there (however the path is spelled), or it is broken and points into this checkout or a
# previous one with the same folder name (the repo was moved).
is_repo_link() {
  local link="$1"
  [ -L "$link" ] || return 1
  if [ -e "$link" ]; then
    case "$(cd "$link" 2>/dev/null && pwd -P)" in "$REPO"/skills/*) return 0 ;; esac
    return 1
  fi
  case "$(readlink "$link")" in "$REPO"/skills/*|*/"$(basename "$REPO")"/skills/*) return 0 ;; esac
  return 1
}
