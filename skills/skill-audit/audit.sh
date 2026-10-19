#!/usr/bin/env bash
# audit.sh — measure token footprint of every skill in a skills/ tree.
# Deterministic measurement only; scoring/judgement is the model's job (see SKILL.md).
#
#   ./audit.sh [SKILLS_DIR]   default: ./skills, else the repo's skills/
#
# Thresholds (from Anthropic's progressive-disclosure rubric, references/rubric.md):
#   description : <=1024 chars hard limit; flag >220 as trimmable recurring cost
#   SKILL.md    : <=500 lines hard ceiling; flag >250 as a split candidate
# It also counts over-constraint signals (CAPS absolutes, forced re-verification,
# reasoning echo, severity filters, anti-format and tool-suppression lines, personas,
# pinned effort, bodies past the 5k-token compaction window) for the rubric's
# "Over-constraint" pass.
set -euo pipefail

DIR="${1:-}"
if [ -z "$DIR" ]; then
  if [ -d "./skills" ]; then DIR="./skills"
  elif [ -d "$(git rev-parse --show-toplevel 2>/dev/null)/skills" ]; then
    DIR="$(git rev-parse --show-toplevel)/skills"
  else echo "No skills/ dir found. Pass one as \$1." >&2; exit 1; fi
fi

DESC_WARN=220   # chars — recurring (always-loaded) cost worth trimming
BODY_WARN=250   # lines — split-to-references candidate
BODY_MAX=500    # lines — Anthropic hard ceiling

printf "Auditing %s\n\n" "$DIR"

# ---- Frontmatter description length (RECURRING cost — loads every session) ----
printf "== Description length (chars) — recurring cost, flag > %s ==\n" "$DESC_WARN"
for f in "$DIR"/*/SKILL.md; do
  [ -e "$f" ] || continue
  d=$(awk 'f&&/^[a-zA-Z_-]+:/{exit} /^description:/{f=1} f' "$f" | sed 's/^description: *//')
  flag=""; [ "${#d}" -gt "$DESC_WARN" ] && flag="  <-- TRIM"
  printf "%5d  %-22s%s\n" "${#d}" "$(basename "$(dirname "$f")")" "$flag"
done | sort -rn
echo

# ---- SKILL.md body size (per-activation cost) ----
printf "== SKILL.md size (lines) — flag > %s (split), hard ceiling %s ==\n" "$BODY_WARN" "$BODY_MAX"
for f in "$DIR"/*/SKILL.md; do
  [ -e "$f" ] || continue
  L=$(wc -l < "$f"); name="$(basename "$(dirname "$f")")"
  hasref=""; [ -d "$(dirname "$f")/references" ] && hasref="ref/"
  flag=""
  if   [ "$L" -gt "$BODY_MAX" ];  then flag="  <-- OVER CEILING"
  elif [ "$L" -gt "$BODY_WARN" ]; then flag="  <-- split candidate"; fi
  printf "%5d  %-6s %-22s%s\n" "$L" "$hasref" "$name" "$flag"
done | sort -rn
echo

# ---- Reference / content .md files (on-demand cost) ----
printf "== Reference .md files (load on demand) — informational ==\n"
find "$DIR" -name "*.md" ! -name "SKILL.md" -print0 2>/dev/null | while IFS= read -r -d '' f; do
  printf "%5d  %s\n" "$(wc -l < "$f")" "${f#"$DIR"/}"
done | sort -rn | head -25
echo

# ---- Quick heuristic flags inside SKILL.md bodies ----
printf "== Inline-content heuristics (likely should be a reference file / script) ==\n"
for f in "$DIR"/*/SKILL.md; do
  [ -e "$f" ] || continue
  name="$(basename "$(dirname "$f")")"
  fences=$(awk '/^```/ { count++ } END { print count + 0 }' "$f"); fences=$((fences/2))
  htmlcss=$(awk '/<!DOCTYPE|<html|^[[:space:]]*:root[[:space:]]*\{|<style|stroke-dashoffset|@keyframes/ { count++ } END { print count + 0 }' "$f")
  rules=$(awk '/^#+ *(Important Rules|Hard Rules|Hard rules|Important rules)/ { count++ } END { print count + 0 }' "$f")
  notes=""
  [ "$fences" -ge 4 ]   && notes="$notes ${fences}-code-blocks"
  [ "$htmlcss" -gt 0 ]  && notes="$notes inline-HTML/CSS"
  [ "$rules" -gt 0 ]    && notes="$notes rules-tail(dedupe?)"
  [ -n "$notes" ] && printf "  %-22s%s\n" "$name" "$notes"
done
echo

# ---- Over-constraint heuristics (instruction fit — rubric: "Over-constraint") ----
# Counts only; a hit is a prompt to read the lines, not proof of a problem.
printf "== Over-constraint heuristics (absolutes, repeated gates, obsolete scaffolding) ==\n"
for f in "$DIR"/*/SKILL.md; do
  [ -e "$f" ] || continue
  name="$(basename "$(dirname "$f")")"
  body="$(awk '/^---[[:space:]]*$/ && n < 2 { n++; next } n >= 2' "$f")"
  caps=$(printf '%s\n' "$body" | grep -o -w -E 'MUST|NEVER|ALWAYS|CRITICAL|IMPORTANT|REQUIRED' | wc -l | tr -d ' ' || true)
  abs=$(printf '%s\n' "$body" | grep -c -i -w -E 'never|always|must' || true)
  reverify=$(printf '%s\n' "$body" | grep -c -i -E 'double-check|re-verify|re-check|sanity[- ]check|verify (your (work|answer|output)|twice)|subagent to (verify|double-check|check your)' || true)
  reasoning=$(printf '%s\n' "$body" | grep -c -i -E '(show|explain|write out|include) your (reasoning|thinking)|think step[- ]by[- ]step' || true)
  # blanket deliberation nudges only, not task-specific care ("think carefully about privacy")
  thinknudge=$(printf '%s\n' "$body" | grep -c -i -E 'think (carefully|hard|deeply) (before|prior to) (answering|responding|you (answer|respond|reply))' || true)
  # review-output filters only, not general caution ("be conservative when pruning")
  severity=$(printf '%s\n' "$body" | grep -c -i -E '(only (report|flag|surface|list)|report only) (the )?(high|critical|severe|major)|be conservative (in|when|about|with) (report|flag|finding|issue)' || true)
  antifmt=$(printf '%s\n' "$body" | grep -c -i -E "(no|avoid|don't use) (bullets|bold|headers|markdown)" || true)
  toolneg=$(printf '%s\n' "$body" | grep -c -i -E 'minimi[sz]e (tool calls|searches|web search)|only (search|use tools?) (when|if) (strictly )?necessary' || true)
  holdfind=$(printf '%s\n' "$body" | grep -c -i -E 'hold (all |your )?(findings|results|updates) (for|until)' || true)
  chars=$(printf '%s' "$body" | wc -c | tr -d ' ')
  # a single role line is fine (rubric); flag persona headings and multi-line trait lists
  persona=$(printf '%s\n' "$body" | grep -c -E '^#+ *Persona' || true)
  traits=$(printf '%s\n' "$body" | grep -c -E '^([-*] +)?You (are|never|always|must) ' || true)
  [ "$traits" -ge 2 ] && persona=$((persona + traits))
  whento=$(printf '%s\n' "$body" | grep -c -i -E '^#+ *When to use' || true)
  effort=$(awk '/^---[[:space:]]*$/ { n++; next } n == 1 && /^effort:/ { sub(/^effort:[[:space:]]*/, ""); print }' "$f")
  notes=""
  [ "$caps" -ge 3 ]      && notes="$notes ${caps}x-CAPS-absolutes"
  [ "$abs" -ge 10 ]      && notes="$notes ${abs}-never/always/must-lines"
  [ "$reverify" -gt 0 ]  && notes="$notes forced-reverify"
  [ "$reasoning" -gt 0 ] && notes="$notes reasoning-echo"
  [ "$thinknudge" -gt 0 ] && notes="$notes think-nudge"
  [ "$severity" -gt 0 ]  && notes="$notes severity-filter"
  [ "$antifmt" -gt 0 ]   && notes="$notes anti-format-rule"
  [ "$toolneg" -gt 0 ]   && notes="$notes search-discouraging"
  [ "$holdfind" -gt 0 ]  && notes="$notes narration-suppression"
  # ~4 chars/token; Claude Code re-attaches only the first 5k tokens after compaction
  [ "$chars" -gt 20000 ] && notes="$notes body>5k-tokens"
  [ "$persona" -gt 0 ]   && notes="$notes persona"
  [ "$whento" -gt 0 ]    && notes="$notes when-to-use-in-body"
  [ -n "$effort" ]       && notes="$notes effort-pinned:$effort"
  [ -n "$notes" ] && printf "  %-22s%s\n" "$name" "$notes"
done
echo "Done. Feed flagged skills to the deep-read step in SKILL.md."
