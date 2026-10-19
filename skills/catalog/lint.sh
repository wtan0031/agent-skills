#!/usr/bin/env bash
# lint.sh — skill health check: install drift, dangling symlinks, frontmatter
# completeness, description token budget, non-standard top-level keys and dead
# reference-file paths. Run directly or via `/catalog health`. Exit 1 if any FAIL.
set -uo pipefail

DESC_BUDGET=200   # chars; descriptions load into every session, keep them lean
# Agent Skills spec keys + Claude Code frontmatter extensions
FM_KEYS='name|description|license|compatibility|metadata|allowed-tools|argument-hint|arguments|disable-model-invocation|user-invocable|when_to_use|effort|model|context|agent|background|hooks|paths|shell|disallowed-tools'

resolve() {
  local p="$1" t
  while [ -L "$p" ]; do
    t="$(readlink "$p")"
    case "$t" in
      /*) p="$t" ;;
      *)  p="$(cd "$(dirname "$p")" && pwd)/$t" ;;
    esac
  done
  printf '%s\n' "$p"
}
SRC="$(resolve "${BASH_SOURCE[0]}")"
SCRIPTDIR="$(cd "$(dirname "$SRC")" && pwd -P)"

SKILLS_ROOT=""
d="$SCRIPTDIR"
while [ "$d" != "/" ]; do
  if [ "$(basename "$d")" = "skills" ]; then SKILLS_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
if [ -z "$SKILLS_ROOT" ] || [ ! -d "$SKILLS_ROOT" ]; then
  echo "lint: could not locate the repo skills/ directory" >&2; exit 1
fi
INSTALL_DIR="$HOME/.claude/skills"

fails=0; warns=0
fail(){ printf '  ✗ FAIL  %s\n' "$1"; fails=$((fails+1)); }
warn(){ printf '  ⚠ WARN  %s\n' "$1"; warns=$((warns+1)); }
ok(){   printf '  ✓ ok    %s\n' "$1"; }

fm(){ # fm <file> <key> -> frontmatter value (one line, quotes stripped)
  awk -v key="$2" '
    BEGIN{ started=0; infm=0 }
    /^---[ \t]*$/ { if(!started){started=1;infm=1;next} else if(infm){exit} }
    infm {
      i=index($0,":"); if(i<1) next
      k=substr($0,1,i-1); v=substr($0,i+1)
      gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v)
      gsub(/^["'"'"']|["'"'"']$/,"",v)
      if(k==key){ print v; exit }
    }' "$1"
}

echo "═══════════════════════════════════════════════════════════════"
echo "  SKILL LINT  ·  repo: ${SKILLS_ROOT/#"$HOME"/\~}  ·  installs: ${INSTALL_DIR/#"$HOME"/\~}"
echo "═══════════════════════════════════════════════════════════════"

echo
echo "── Install symlinks"
# dangling links in the install dir
if [ -d "$INSTALL_DIR" ]; then
  for l in "$INSTALL_DIR"/*; do
    [ -L "$l" ] || continue
    [ -e "$l" ] || fail "dangling symlink: ${l/#"$HOME"/\~} -> $(readlink "$l")"
  done
else
  warn "no install dir at ${INSTALL_DIR/#"$HOME"/\~}"
fi
# every repo skill installed (unless recipe: true)
for dir in "$SKILLS_ROOT"/*/; do
  name="$(basename "$dir")"
  sk="$dir/SKILL.md"
  [ -f "$sk" ] || { warn "$name: no SKILL.md"; continue; }
  if [ "$(fm "$sk" recipe)" = "true" ]; then
    ok "$name (recipe — install not required)"
    continue
  fi
  if [ -e "$INSTALL_DIR/$name" ]; then
    ok "$name installed"
  else
    fail "$name exists in repo but is NOT installed (ln -s ${dir%/} ${INSTALL_DIR/#"$HOME"/\~}/$name)"
  fi
done

echo
echo "── Frontmatter"
for dir in "$SKILLS_ROOT"/*/; do
  name="$(basename "$dir")"
  sk="$dir/SKILL.md"
  [ -f "$sk" ] || continue
  fmname="$(fm "$sk" name)"
  desc="$(fm "$sk" description)"
  tools="$(fm "$sk" allowed-tools)"
  [ -z "$fmname" ] && fail "$name: missing 'name:'"
  [ -n "$fmname" ] && [ "$fmname" != "$name" ] && warn "$name: frontmatter name '$fmname' != folder name"
  if [ -z "$desc" ]; then
    fail "$name: missing 'description:'"
  elif [ "${#desc}" -gt "$DESC_BUDGET" ]; then
    warn "$name: description is ${#desc} chars (budget $DESC_BUDGET) — it loads into every session"
  fi
  # unquoted ': ' in the description value breaks strict YAML parsers (Copilot/Gemini/Codex)
  rawdesc="$(grep -m1 '^description:' "$sk" | sed 's/^description:[[:space:]]*//')"
  case "$rawdesc" in
    \"*|\'*) : ;;                     # quoted — safe
    *": "*) fail "$name: description contains ': ' but is unquoted — wrap it in double quotes (strict YAML)" ;;
  esac
  [ -z "$tools" ] && warn "$name: missing 'allowed-tools:'"
  # allow spec keys + Claude Code's documented extensions (local hosts read them); custom
  # fields belong under metadata:. Strict upload validators (claude.ai, Skills API) accept
  # only the spec keys, so a clean lint doesn't mean a skill is upload-ready.
  extra="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^[A-Za-z][A-Za-z0-9_-]*:/{sub(/:.*/,"");print}' "$sk" \
    | grep -vxE "$FM_KEYS" | tr '\n' ' ' || true)"
  [ -n "$extra" ] && warn "$name: non-standard top-level key(s): ${extra% } — move custom fields under metadata:"
done
echo "  (description budget: $DESC_BUDGET chars)"

echo
echo "── Referenced files"
deadrefs=0
for dir in "$SKILLS_ROOT"/*/; do
  name="$(basename "$dir")"
  sk="$dir/SKILL.md"
  [ -f "$sk" ] || continue
  # relative paths mentioned in backticks or markdown links: references/x.md, ../other-skill/y.json ...
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    if [ ! -e "$dir/$ref" ]; then
      fail "$name: SKILL.md mentions '$ref' but ${dir%/}/$ref does not exist"
      deadrefs=$((deadrefs+1))
    fi
  done < <({ grep -o '`[^`]*`' "$sk" | tr -d '`'
             grep -oE '\]\([^)]+\)' "$sk" | sed 's/^](//; s/)$//'
           } | grep -E '^(references/|\.\./)[A-Za-z0-9._/-]+\.[a-z]+$' | sort -u)
done
[ "$deadrefs" -eq 0 ] && echo "  ✓ ok    every references/ and ../ path mentioned in a SKILL.md exists"

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  $fails fail · $warns warn"
[ "$fails" -gt 0 ] && exit 1
exit 0
