#!/usr/bin/env bash
#
# Read the project's toggles out of `WSS.record.toggles`' `## Toggles` table.
#
#   ./wss-toggle.sh                 # every toggle, as `name<TAB>value`
#   ./wss-toggle.sh <name>          # one value; exit 1 if the toggle has no row
#   ./wss-toggle.sh --on <name>     # exit 0 if the value is `on`, else 1
#
# WHY A SCRIPT RATHER THAN A LINE IN EACH CONSUMER. Several consumers read the
# same table — `wss-doctor.sh` for its own defaults, `git-writer` for message
# shape — and a second parser is a second thing to drift. The table's shape is
# `wss/workflow/WSS.ADDRESSING.md`'s structured-region grammar, and the region
# markers around it are what let a blanked record still declare its shape.
#
# ABSENT MEANS OFF, ALWAYS. A toggle with no row is not an error at the call
# site: it is the default state, and every consumer treats it that way. Only an
# explicit lookup of a named toggle reports absence, so a caller that wants to
# tell "off" from "never declared" can, and no caller has to.
#
# WHY THE WHOLE TABLE IS THE DEFAULT OUTPUT. `wss-doctor.sh` is forked about 144
# times by the contract suite; a consumer that shells out once per toggle pays
# that per toggle per fork. One call returns everything and the caller parses it
# once — the same lesson the per-grant spawn floor records at a larger scale.

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DIR="${WSS_TOGGLE_DIR:-$PWD}"
MANIFEST="$DIR/.claude/WSS.WORKFLOW.json"

toggles_path_() {
  if [ -f "$MANIFEST" ] && command -v jq >/dev/null 2>&1; then
    jq -r '.WSS.record.toggles // empty' "$MANIFEST" 2>/dev/null
  fi
}

rel=$(toggles_path_)
[ -n "$rel" ] || rel="wss/records/WSS.TOGGLES.md"
file="$DIR/$rel"
# NO CROSS-TREE FALLBACK. Toggle state is per-tree by construction, so a tree
# with no registry of its own reads every toggle as off — the suite-wide
# absent-means-off rule — rather than silently reading the suite install's own
# rows. The decision log's `2026-08-19 (ninety-first)` entry.

# Rows live between the `## Toggles` heading and the next `## `, and inside the
# region markers where those are present. A header row and its separator are not
# toggles; neither is a line outside the table.
all_() {
  [ -f "$file" ] || return 0
  awk '
    /^## Toggles/ { intoggles = 1; next }
    intoggles && /^## / { intoggles = 0 }
    !intoggles { next }
    /^\|/ {
      line = $0
      if (line ~ /^\|[ :-]*\|[ :-]*\|/) next          # separator
      n = split(line, c, "|")
      if (n < 3) next
      name = c[2]; val = c[3]
      gsub(/^[ \t]+|[ \t]+$/, "", name)
      gsub(/^[ \t]+|[ \t]+$/, "", val)
      gsub(/`/, "", name); gsub(/`/, "", val)
      if (name == "" || tolower(name) == "toggle") next   # header
      printf "%s\t%s\n", name, val
    }
  ' "$file"
}

case "${1:-}" in
  "")      all_ ;;
  --on)    [ $# -ge 2 ] || { echo "usage: $0 --on <name>" >&2; exit 2; }
           v=$(all_ | awk -F'\t' -v k="$2" '$1==k{print $2; exit}')
           [ "$v" = "on" ] ;;
  -h|--help) sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)       v=$(all_ | awk -F'\t' -v k="$1" '$1==k{print $2; exit}')
           [ -n "$v" ] || { echo "wss-toggle.sh: no toggle named '$1'" >&2; exit 1; }
           printf '%s\n' "$v" ;;
esac
