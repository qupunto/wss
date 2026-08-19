#!/usr/bin/env bash
# Export or import the machine-local workflow state of the project in $PWD.
#
#   wss-export-records.sh [-o <archive>]           # default: records-export.tar.gz
#   wss-export-records.sh --all [-o <archive>]     # retirement snapshot — see below
#   wss-export-records.sh --import <archive> [--force]
#
# WHAT TRAVELS: only what a `git clone` on the next machine would NOT bring —
# manifest-declared record files (`WSS.record.*` and `WSS.lanes.named.*.records.*`)
# that git does not track, the `.claude/WSS.LANE` selector, and `WSS.BUG-REPORTS.md`
# when run in the config directory, which is the one file whose loss is
# unrecoverable. A project that keeps its records out of its repository is the
# whole audience; a project whose records are tracked has nothing here to move.
#
# WHAT DOES NOT: tracked records (the clone brings them), and the sweep
# checkpoint (`.claude/WSS.SWEEPS.json`) — a cache whose loss costs one re-sweep
# and can never cost correctness, so moving it buys nothing worth the bytes.
#
# Import is ALL-OR-NOTHING. It refuses absolute and `..` entries outright, and
# refuses to overwrite any existing non-empty file unless --force is given —
# a half-restored record set reads exactly like a complete one, which is the
# same reason wss-doctor.sh fails on a half-split lane map.
#
# The archive is a snapshot, not a record: do not commit it, and treat one from
# another machine as stale the moment either side writes.
#
# A PRE-RENAME tree (legacy .claude/workflow.json, schema workflow/v1) is read
# too, export-only, so the snapshot can be taken BEFORE a migration rather than
# only after it. Import needs no such support: the archive carries paths.
#
# --all IS A DIFFERENT QUESTION: not "what would a clone lose" but "what would
# a deletion lose". It keeps tracked records IN and adds the docs tree, because
# its audience is a project about to retire the workflow (wss-retire-workflow.sh
# --records deletes files whether or not git remembers them, and a repo the user
# later deletes remembers nothing). The sweep checkpoint stays out either way —
# a cache whose loss costs one re-sweep. Import handles both kinds of archive
# identically; the refuse-non-empty-collisions rule is what makes restoring an
# --all archive over a live clone safe rather than a silent mass overwrite.

set -u

MODE=export
ARCHIVE="records-export.tar.gz"
FORCE=0
ALL=0
while [ $# -gt 0 ]; do
  case $1 in
    -o)       shift; ARCHIVE=${1:?-o needs a path} ;;
    --all)    ALL=1 ;;
    --import) MODE=import; shift; ARCHIVE=${1:?--import needs an archive} ;;
    --force)  FORCE=1 ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "wss-export-records.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MANIFEST="$PWD/.claude/WSS.WORKFLOW.json"

# A PRE-RENAME tree (.claude/workflow.json, flat keys, no WSS root) is exactly
# the tree whose snapshot matters most: the migration that fixes it is also
# what could lose its records, and requiring migration before export closes
# the snapshot path to the only audience that needs it (issue #16's second
# bite). The jq below reads both shapes; nothing else changes.
LEGACY=0
if [ ! -f "$MANIFEST" ] && [ -f "$PWD/.claude/workflow.json" ]; then
  MANIFEST="$PWD/.claude/workflow.json"
  LEGACY=1
fi

# ---------------------------------------------------------------------- import
if [ "$MODE" = import ]; then
  [ -f "$ARCHIVE" ] || { echo "no archive at $ARCHIVE" >&2; exit 1; }

  # Refuse hostile entries BEFORE anything is written: an absolute path, or
  # `..` as its own segment anywhere in the path — the only way out of the
  # project root.
  bad=$(tar tzf "$ARCHIVE" | grep -E '^/|(^|/)\.\.(/|$)' || true)
  if [ -n "$bad" ]; then
    echo "REFUSED: archive contains entries that escape the project:" >&2
    printf '%s\n' "$bad" | sed 's/^/  /' >&2
    exit 1
  fi

  # All-or-nothing: collect every collision first, then either stop or extract.
  clobber=""
  while IFS= read -r e; do
    case $e in */) continue ;; esac
    [ -s "$PWD/$e" ] && clobber="$clobber  $e
"
  done < <(tar tzf "$ARCHIVE")
  if [ -n "$clobber" ] && [ "$FORCE" -eq 0 ]; then
    echo "REFUSED: these files exist here and are not empty (use --force to overwrite):" >&2
    printf '%s' "$clobber" >&2
    exit 1
  fi

  tar xzf "$ARCHIVE" -C "$PWD" || exit 1
  echo "restored into $PWD:"
  tar tzf "$ARCHIVE" | sed 's/^/  /'
  exit 0
fi

# ---------------------------------------------------------------------- export
list=$(mktemp)
trap 'rm -f "$list"' EXIT

candidates() {
  if [ -f "$MANIFEST" ] && command -v jq >/dev/null 2>&1; then
    # Strings and arrays under WSS.record.*; provider objects have no file and
    # WSS.record.tooling contributes only its catalog and inventory. Lane records are record
    # paths like any other. `WSS.sweeps` is deliberately absent — see the header.
    # `(.WSS // .)` is the two-shape read: the v2 root when it exists, the
    # whole flat document on a legacy workflow/v1 manifest. Key names inside
    # are enumerated by value, so v1's renamed roles (record.audits) travel
    # the same as v2's.
    jq -r '
      def hazards_sibling:
        if contains("/") then (split("/")[:-1] | join("/")) + "/WSS.HAZARDS.md"
        else "WSS.HAZARDS.md" end;
      (.WSS // .) as $w |
      [ ($w.record // {} | to_entries[] | .value
          | if type == "string" then .
            elif type == "array" then .[]
            else empty end),
        ($w.record.tooling // {} | .catalog // empty),
        ($w.record.tooling // {} | .inventory // empty),
        ($w.lanes.named // {} | .[]? | (.records // {}) | .[]?),
        ($w.lanes.named // {} | .[]? | .transfer // empty),
        ($w.lanes.conflicts // empty),
        # A handoff overflow sibling is part of the handoff record — the retire
        # and reset scripts both treat it that way, so an archive that misses
        # it loses one file the deletion takes.
        ($w.record.handoff // empty | select(type == "string") | hazards_sibling),
        ($w.lanes.named // {} | .[]? | (.records.handoff // empty)
          | select(type == "string") | hazards_sibling)
      ] | .[] | select(type == "string")' "$MANIFEST" 2>/dev/null
  fi
  echo ".claude/WSS.LANE"
  # The pre-rename selector name, so a legacy worktree's lane identity makes
  # the snapshot too. Absent files are filtered below either way.
  [ "$LEGACY" -eq 1 ] && echo ".claude/lane"
  # The inbox is config-directory state, included only when this IS the config
  # directory — from any other project it belongs to a different export.
  if [ "$PWD" -ef "$CONFIG_DIR" ] && [ -f "$PWD/WSS.BUG-REPORTS.md" ]; then
    echo "WSS.BUG-REPORTS.md"
  fi
  # The docs site has no manifest key — docs finds it by trying wss/docs/,
  # docs/ and other fallbacks in order, and so does this. Files only, and `find`
  # without -L, so a symlink pointing out of the project is skipped rather than
  # followed.
  if [ "$ALL" -eq 1 ]; then
    if [ -d "$PWD/wss/docs" ]; then
      (cd "$PWD" && find wss/docs -type f)
    elif [ -d "$PWD/docs" ]; then
      (cd "$PWD" && find docs -type f)
    fi
  fi
}

in_git=0
git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1 && in_git=1

while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -f "$PWD/$p" ] || continue
  # Tracked files travel with the repository; only the rest need the archive.
  # Under --all they stay: the snapshot must survive the repository itself.
  if [ "$ALL" -eq 0 ] && [ "$in_git" -eq 1 ] &&
     git -C "$PWD" ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    continue
  fi
  printf '%s\n' "$p"
done < <(candidates) | sort -u > "$list"

if [ ! -s "$list" ]; then
  echo "nothing to export: every declared record is tracked, and no selector or inbox is here"
  exit 0
fi

tar czf "$ARCHIVE" -C "$PWD" -T "$list" || exit 1
echo "exported to $ARCHIVE:"
sed 's/^/  /' "$list"
if [ "$LEGACY" -eq 1 ]; then
  echo "note: read the PRE-RENAME manifest .claude/workflow.json — this is a"
  echo "snapshot only; migrate the tree with \`--wss-update\`."
fi
