#!/usr/bin/env bash
# catalog.sh — print a grouped inventory of every skill in this repo, read live
# from each SKILL.md's frontmatter so it never drifts. Optional arg filters by
# category name, or "rare" to show only the rarely-used skills.
set -uo pipefail

US=$'\037'   # field separator: a non-whitespace control char, so empty fields survive `read`

# ---- resolve this script's real location (works through the install symlink) ----
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
# pwd -P resolves a symlinked *parent* dir too (install.sh symlinks the whole skill folder)
SCRIPTDIR="$(cd "$(dirname "$SRC")" && pwd -P)"

# ---- find the repo's skills/ root: nearest ancestor dir named "skills" ----
SKILLS_ROOT=""
d="$SCRIPTDIR"
while [ "$d" != "/" ]; do
  if [ "$(basename "$d")" = "skills" ]; then SKILLS_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -z "$SKILLS_ROOT" ] && [ -d "$HOME/.claude/skills" ] && SKILLS_ROOT="$HOME/.claude/skills"
if [ -z "$SKILLS_ROOT" ] || [ ! -d "$SKILLS_ROOT" ]; then
  echo "catalog: could not locate a skills/ directory" >&2; exit 1
fi

FILTER="${1:-}"   # "", a category name, "rare", or "health"

# health check lives in its own script
if [ "$FILTER" = "health" ]; then exec bash "$SCRIPTDIR/lint.sh"; fi

# ---- gather one row per skill: category US name US cadence US description US when-to-use ----
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
while IFS= read -r f; do
  rel="${f#"$SKILLS_ROOT"/}"
  case "$rel" in
    */*/*) pathcat="${rel%%/*}" ;;   # cat/name/SKILL.md  -> nested
    *)     pathcat="" ;;             # name/SKILL.md      -> flat
  esac
  awk -v pathcat="$pathcat" -v US="$US" '
    BEGIN{ started=0; infm=0 }
    /^---[ \t]*$/ { if(!started){started=1;infm=1;next} else if(infm){infm=0} }
    infm {
      i=index($0,":"); if(i<1) next
      k=substr($0,1,i-1); v=substr($0,i+1)
      gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v)
      gsub(/^["'"'"']|["'"'"']$/,"",v)   # strip one layer of surrounding quotes
      d[k]=v
    }
    END{
      cat = d["category"]!="" ? d["category"] : (pathcat!="" ? pathcat : "uncategorized")
      printf "%s%s%s%s%s%s%s%s%s\n", cat, US, d["name"], US, tolower(d["cadence"]), US, d["description"], US, d["when-to-use"]
    }
  ' "$f" >> "$TMP"
done < <(find "$SKILLS_ROOT" -name SKILL.md -type f 2>/dev/null)

# drop rows with no name (malformed frontmatter)
awk -F"$US" '$2!=""' "$TMP" > "$TMP.clean" && mv "$TMP.clean" "$TMP"

trunc(){ local s="$1" n="${2:-64}"; if [ "${#s}" -gt "$n" ]; then printf '%s…' "${s:0:$((n-1))}"; else printf '%s' "$s"; fi; }
is_rare(){ case "$1" in monthly|quarterly|yearly|rare) return 0;; *) return 1;; esac; }

TOTAL="$(wc -l < "$TMP" | tr -d ' ')"

echo "═══════════════════════════════════════════════════════════════"
echo "  SKILL CATALOG  ·  $TOTAL skills  ·  source: ${SKILLS_ROOT/#"$HOME"/\~}"
[ -n "$FILTER" ] && echo "  filter: $FILTER"
echo "═══════════════════════════════════════════════════════════════"

print_rows_for_cat(){
  awk -F"$US" -v c="$1" '$1==c' "$TMP" | LC_ALL=C sort -t"$US" -k2,2 | \
  while IFS="$US" read -r cat name cad desc wtu; do
    tag=""
    if is_rare "$cad"; then tag="  ·  ⏳${cad}"; fi
    printf '  /%-18s %s%s\n' "$name" "$(trunc "$desc")" "$tag"
    if [ -n "$wtu" ]; then printf '   %18s use when: %s\n' "" "$(trunc "$wtu" 60)"; fi
  done
}

if [ "$FILTER" = "rare" ]; then
  echo
  echo "⏳ RARELY USED — you don't reach for these often"
  echo "───────────────────────────────────────────────────────────────"
  any=0
  while IFS="$US" read -r cat name cad desc wtu; do
    if is_rare "$cad"; then printf '  /%-18s %s  (%s)\n' "$name" "$(trunc "$desc")" "$cad"; any=1; fi
  done < "$TMP"
  if [ "$any" -eq 0 ]; then
    echo "  (none tagged yet — add  cadence: monthly|quarterly|rare  under a skill's frontmatter metadata:)"
  fi
  exit 0
fi

# main grouped listing
CATS="$(awk -F"$US" '{print $1}' "$TMP" | LC_ALL=C sort -u)"
while IFS= read -r cat; do
  [ -n "$cat" ] || continue
  if [ -n "$FILTER" ] && [ "$(printf '%s' "$cat" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$FILTER" | tr '[:upper:]' '[:lower:]')" ]; then
    continue
  fi
  echo
  printf '%s ──────────────────────────────────────\n' "$(printf '%s' "$cat" | tr '[:lower:]' '[:upper:]')"
  print_rows_for_cat "$cat"
done <<< "$CATS"

# rarely-used recap (only in the unfiltered view)
if [ -z "$FILTER" ]; then
  recap=""
  while IFS="$US" read -r cat name cad desc wtu; do
    if is_rare "$cad"; then recap+="$(printf '  /%-18s %s' "$name" "$(trunc "$desc")")"$'\n'; fi
  done < "$TMP"
  if [ -n "$recap" ]; then
    echo
    echo "⏳ RARELY USED — easy to forget you have these"
    echo "───────────────────────────────────────────────────────────────"
    printf '%s' "$recap"
  fi
fi

echo
echo "  /catalog <category>  one group  ·  /catalog rare  rare ones  ·  /catalog health  lint"
