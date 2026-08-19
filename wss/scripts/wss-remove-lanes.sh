#!/usr/bin/env bash
# Turn worktree-lane mode OFF for the project in $PWD, without losing work.
#
#   wss-remove-lanes.sh                    # show what would change, change nothing
#   wss-remove-lanes.sh --write            # remove the two signals
#   wss-remove-lanes.sh --write --allow-orphans   # ...even where lane files still hold content
#   wss-remove-lanes.sh --dir /path/to/project
#
# Lane mode is ON where EITHER signal is present, so both must go:
#
#   1. .claude/WSS.LANE            — this checkout's selector, naming which lane it is
#   2. .WSS.lanes.named            — the project manifest's map of lane -> records
#
# This script removes those two, plus `.WSS.lanes.conflicts`, which addresses a
# consumer that can no longer run. Nothing else.
#
# NEVER REMOVED, whatever the flags — this is the whole reason the script exists:
#
#   `.WSS.lanes.exclusive`, `.serialize`, `.generated` STAY. They are not
#   worktree machinery. They are the concurrent-write collision paths that drive
#   --wss-start's Phase 3 when it partitions a batch into parallel agents INSIDE
#   ONE CHECKOUT, and that works with no worktrees at all. Deleting the `lanes`
#   block wholesale is the mistake this script exists to prevent: it reads as
#   tidying and silently removes the guard that stops two agents writing one
#   schema.
#
#   Every lane RECORD FILE stays on disk — each lane's splittable records, its
#   transfer queue, and the conflicts inbox. Which records are splittable is
#   stated in wss/workflow/WSS.LANE-CONTRACT.md ("Which records may split, and
#   which must never"), and is deliberately not restated here. They hold a
#   TODO list, unmade decisions and goals. This script does not delete a record
#   under any flag. Merge them into the unsplit records first if you want them
#   carried over; `wss-retire-workflow.sh --write --records` is the tool that
#   deletes records, deliberately behind its own second flag.
#
# ONE CHECKOUT AT A TIME. Every lane worktree carries its own .claude/WSS.LANE.
# This clears the one in --dir and lists the others it found; run it there too,
# or remove those worktrees, or lane mode stays on for them.
set -euo pipefail

DIR="$PWD"
WRITE=0
ALLOW_ORPHANS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --write)          WRITE=1 ;;
    --allow-orphans)  ALLOW_ORPHANS=1 ;;
    --dir)            shift; DIR="${1:?--dir needs a path}" ;;
    # header block only: from line 2 to the last consecutive leading-# line
    -h|--help)        awk 'NR==1{next} !/^#/{exit} {print}' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

MANIFEST="$DIR/.claude/WSS.WORKFLOW.json"
SELECTOR="$DIR/.claude/WSS.LANE"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

if [ ! -f "$MANIFEST" ]; then
  echo "no .claude/WSS.WORKFLOW.json in $DIR — nothing declares lanes here." >&2
  echo "A stray selector alone still turns lane mode on; check for $SELECTOR." >&2
  exit 1
fi
jq -e . "$MANIFEST" >/dev/null 2>&1 || { echo "$MANIFEST is not valid JSON — fix it first" >&2; exit 1; }

has_named=$(jq -r '((.WSS.lanes.named // {}) | length) > 0' "$MANIFEST")
[ -f "$SELECTOR" ] && has_sel=1 || has_sel=0

if [ "$has_named" != true ] && [ "$has_sel" = 0 ]; then
  echo "Lane mode is already OFF in $DIR:"
  echo "  no .claude/WSS.LANE selector, and the manifest declares no WSS.lanes.named."
  jq -e '.WSS.lanes' "$MANIFEST" >/dev/null 2>&1 \
    && echo "  (the collision paths in WSS.lanes are untouched, as they should be)"
  exit 0
fi

echo "Project: $DIR"
echo
echo "SIGNALS TO REMOVE"
[ "$has_sel" = 1 ] && echo "  selector   .claude/WSS.LANE -> $(tr -d '\n' <"$SELECTOR")" \
                   || echo "  selector   none in this checkout"
if [ "$has_named" = true ]; then
  echo "  manifest   .WSS.lanes.named ($(jq -r '.WSS.lanes.named | keys | join(", ")' "$MANIFEST"))"
else
  echo "  manifest   .WSS.lanes.named absent"
fi
jq -e '.WSS.lanes.conflicts' "$MANIFEST" >/dev/null 2>&1 \
  && echo "  manifest   .WSS.lanes.conflicts ($(jq -r '.WSS.lanes.conflicts' "$MANIFEST"))"

echo
echo "KEPT — collision paths, which are not worktree machinery"
for k in exclusive serialize generated; do
  n=$(jq -r --arg k "$k" '(.WSS.lanes[$k] // []) | length' "$MANIFEST")
  [ "$n" != 0 ] && echo "  WSS.lanes.$k  $n path(s) — still drives Phase 3 batch partitioning"
done
jq -e '((.WSS.lanes.exclusive // []) + (.WSS.lanes.serialize // []) + (.WSS.lanes.generated // [])) | length > 0' \
  "$MANIFEST" >/dev/null 2>&1 || echo "  none declared"

# Lane-owned files. Reported, never deleted. A file with content is what makes
# turning the mode off lossy, so it gates --write rather than being cleaned up.
echo
echo "LANE FILES — left on disk, always"
withcontent=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  f="$DIR/$rel"
  if [ ! -e "$f" ]; then
    printf '  %-46s missing\n' "$rel"
  elif [ -s "$f" ] && grep -qE '^[[:space:]]*[^[:space:]#]' "$f" 2>/dev/null; then
    printf '  %-46s %s bytes, HAS CONTENT\n' "$rel" "$(wc -c <"$f" | tr -d ' ')"
    withcontent=$((withcontent + 1))
  else
    printf '  %-46s empty or headings only\n' "$rel"
  fi
done < <(jq -r '
  ((.WSS.lanes.named // {}) | to_entries[] |
     ((.value.records // {}) | to_entries[] | .value),
     (.value.transfer // empty)),
  (.WSS.lanes.conflicts // empty)' "$MANIFEST" | sort -u)

# Other worktrees carry their own selector and this run cannot reach them.
others=""
if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  others=$(git -C "$DIR" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{print $2}' | grep -Fxv "$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)" || true)
fi
if [ -n "$others" ]; then
  echo
  echo "OTHER WORKTREES — each keeps its own selector; this run does not reach them"
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    [ -f "$w/.claude/WSS.LANE" ] \
      && echo "  $w  (selector: $(tr -d '\n' <"$w/.claude/WSS.LANE")) — run this script there too" \
      || echo "  $w  (no selector)"
  done <<<"$others"
fi

if [ "$WRITE" = 0 ]; then
  echo
  echo "Dry run. Nothing changed. Re-run with --write to remove the signals above."
  exit 0
fi

if [ "$withcontent" -gt 0 ] && [ "$ALLOW_ORPHANS" = 0 ]; then
  echo >&2
  echo "REFUSING: $withcontent lane file(s) still hold content." >&2
  echo "Turning the mode off does not delete them, but nothing will read them again —" >&2
  echo "a TODO list item or an unmade decision would sit there unseen. Merge them into" >&2
  echo "the unsplit records first (\`--wss-todo\`, \`--wss-plan\`, \`--wss-log\` own those writes)," >&2
  echo "or re-run with --allow-orphans to leave them orphaned deliberately." >&2
  exit 1
fi

# The manifest rewrite wants a route back. git is that route, so refuse to
# rewrite a copy git could not restore rather than writing a .bak nobody prunes.
if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if ! git -C "$DIR" ls-files --error-unmatch -- "$MANIFEST" >/dev/null 2>&1; then
    echo "REFUSING: $MANIFEST is untracked, so this rewrite could not be undone." >&2
    echo "Commit it first, or copy it aside." >&2
    exit 1
  fi
  if ! git -C "$DIR" diff --quiet -- "$MANIFEST"; then
    echo "REFUSING: $MANIFEST has uncommitted changes — commit them so the rewrite" >&2
    echo "is a diff you can read and revert on its own." >&2
    exit 1
  fi
fi

tmp=$(mktemp)
jq '
  del(.WSS.lanes.named) | del(.WSS.lanes.conflicts)
  | if (.WSS.lanes // {}) == {} then del(.WSS.lanes) else . end
' "$MANIFEST" >"$tmp"
jq -e . "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; echo "rewrite produced invalid JSON, aborted" >&2; exit 1; }
mv "$tmp" "$MANIFEST"
echo
echo "removed  .WSS.lanes.named and .WSS.lanes.conflicts from the manifest"

if [ "$has_sel" = 1 ]; then
  rm -f "$SELECTOR"
  echo "removed  .claude/WSS.LANE"
fi

echo
echo "Lane mode is now OFF for this checkout."
echo "Every lane record file is still on disk and still in git; nothing was deleted."
[ -n "$others" ] && echo "Other worktrees still carry their own selector — run this there too."
echo "Verify with: wss-doctor.sh"
