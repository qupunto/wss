#!/usr/bin/env bash
# wss-skill-levels.sh — toggle step 1's whole level table, in one
# read-only call: every skill directory under both `skills/` trees, its
# effective `skillOverrides` level, which settings file set it, which tree
# it came from, and whether its own frontmatter hides it.
#
#   wss-skill-levels.sh
#   wss-skill-levels.sh -h | --help
#
# Reads $PWD/.claude/settings.json and
# ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json — precedence is PER-SKILL:
# the first of the two files that names a given skill wins, and a project
# file that exists but does not mention the skill is not an answer for it.
# NEVER settings.local.json, the same exclusion the resolver this table
# mirrors — skill_disabled() in hooks/wss-shorthand-flags.sh — makes.
#
# Reads the two skills trees at $PWD/.claude/skills and the config dir's
# skills, plus $CLAUDE_PLUGIN_ROOT/skills when that variable is set and its
# skills directory exists — listed separately, at the end, as not
# controllable here: the harness ignores skillOverrides for plugin skills.
# Writes nothing, runs no git, makes no network call.
#
# Refuses rather than rendering a table it cannot trust — printing NO table
# and exiting 1 — in three cases: jq is not on PATH; a settings file that
# exists is not valid JSON; or the enumeration across both trees turns up no
# skill directory at all. A table read from any of those looks exactly like
# "nothing is overridden", and that false reading is what a wrong edit then
# gets made against.
set -u

usage() {
  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  "") ;;
  *)
    echo "wss-skill-levels.sh: unknown argument: $1" >&2
    exit 2
    ;;
esac

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PROJ_SETTINGS="$PWD/.claude/settings.json"
USER_SETTINGS="$CONFIG_DIR/settings.json"
PROJ_SKILLS="$PWD/.claude/skills"
USER_SKILLS="$CONFIG_DIR/skills"

if ! command -v jq >/dev/null 2>&1; then
  echo "wss-skill-levels.sh: jq not found — refusing to render a table it cannot verify" >&2
  exit 1
fi

# A settings file that exists but is not valid JSON is unreadable, same as jq
# being missing — refuse rather than silently reading every skill as
# "(no entry)", which is exactly what an unreadable file would otherwise
# produce.
for f in "$PROJ_SETTINGS" "$USER_SETTINGS"; do
  [ -f "$f" ] || continue
  jq empty "$f" >/dev/null 2>&1 || {
    echo "wss-skill-levels.sh: $f exists but is not valid JSON — refusing to render a table it cannot verify" >&2
    exit 1
  }
done

present_absent() { [ -e "$1" ] && echo present || echo absent; }

# --- enumerate: directory names holding a SKILL.md, per tree ---------------
# One shared loop over both trees rather than two copies, so a regression in
# the enumeration cannot affect one tree and not the other unnoticed.
declare -A IN_PROJECT=() IN_USER=()
for pair in "project $PROJ_SKILLS" "user $USER_SKILLS"; do
  who=${pair%% *}
  TREE=${pair#* }
  [ -d "$TREE" ] || continue
  for d in "$TREE"/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    [ -f "$d/SKILL.md" ] || continue
    if [ "$who" = project ]; then IN_PROJECT[$n]=1; else IN_USER[$n]=1; fi
  done
done

ALL_NAMES=$(
  { printf '%s\n' "${!IN_PROJECT[@]}" 2>/dev/null; printf '%s\n' "${!IN_USER[@]}" 2>/dev/null; } \
    | grep -v '^$' | LC_ALL=C sort -u
)

if [ -z "$ALL_NAMES" ]; then
  echo "wss-skill-levels.sh: no skills tree exists — neither $PROJ_SKILLS nor $USER_SKILLS holds a skill directory to read" >&2
  exit 1
fi

# --- per-skill level, set-by and tree ---------------------------------------
declare -A LEVEL=() SETBY=() SKTREE=()
for n in $ALL_NAMES; do
  if [ -n "${IN_PROJECT[$n]:-}" ] && [ -n "${IN_USER[$n]:-}" ]; then
    SKTREE[$n]=both
  elif [ -n "${IN_PROJECT[$n]:-}" ]; then
    SKTREE[$n]=project
  else
    SKTREE[$n]=user
  fi

  # Per-skill precedence, not per-file: the first file that NAMES this skill
  # wins. A project file that exists but is silent on this skill is not an
  # answer, so the search continues to the user file.
  lvl=""
  # ASCII, not an em dash: printf's %-10s pads by BYTES, and a 3-byte "—"
  # would short the column by two on every unoverridden row — which is most
  # of the table.
  setby="-"
  for entry in "$PROJ_SETTINGS project" "$USER_SETTINGS user"; do
    f=${entry% *}; who=${entry##* }
    [ -f "$f" ] || continue
    v=$(jq -r --arg s "$n" '.skillOverrides[$s] // empty' "$f" 2>/dev/null)
    [ -n "$v" ] || continue
    lvl=$v
    setby=$who
    break
  done
  [ -n "$lvl" ] || lvl="(no entry)"
  LEVEL[$n]=$lvl
  SETBY[$n]=$setby
done

# frontmatter: hidden when either spelling of the author-side key is true, in
# the SKILL.md the harness actually loads for this skill — project's, where
# the skill exists in both trees, since project wins for what is loaded.
frontmatter_for() {
  local n=$1 f
  case "${SKTREE[$n]}" in
    project | both) f="$PROJ_SKILLS/$n/SKILL.md" ;;
    user) f="$USER_SKILLS/$n/SKILL.md" ;;
  esac
  if grep -qE '^(disableModelInvocation|disable-model-invocation): *true' "$f" 2>/dev/null; then
    echo hidden
  else
    echo visible
  fi
}

echo "== toggle: effective skill levels =="
echo "project settings: .claude/settings.json ($(present_absent "$PROJ_SETTINGS"))"
echo "user settings: $USER_SETTINGS ($(present_absent "$USER_SETTINGS"))"
echo "project skills: .claude/skills ($(present_absent "$PROJ_SKILLS"))"
echo "user skills: $USER_SKILLS ($(present_absent "$USER_SKILLS"))"
echo
printf '%-25s %-21s %-10s %-9s %s\n' "skill" "level" "set by" "tree" "frontmatter"
count=0
overridden=0
for n in $ALL_NAMES; do
  count=$((count + 1))
  [ "${LEVEL[$n]}" != "(no entry)" ] && overridden=$((overridden + 1))
  printf '%-25s %-21s %-10s %-9s %s\n' "$n" "${LEVEL[$n]}" "${SETBY[$n]}" "${SKTREE[$n]}" "$(frontmatter_for "$n")"
done
echo
echo "$count skills, $overridden with an override"

# --- plugin skills: listed, never merged — the harness ignores overrides for
# them, so a level column would misrepresent what a toggle here can do.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT/skills" ]; then
  echo
  echo "== plugin skills (not controllable here) =="
  for d in "$CLAUDE_PLUGIN_ROOT/skills"/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    [ -f "$d/SKILL.md" ] && printf '%s\n' "$n"
  done | LC_ALL=C sort -u
fi
