#!/usr/bin/env bash
# wss-sweep-stamp.sh — the deterministic half of the sweep checkpoint's Stamp
# step (wss/workflow/writers/WSS.SWEEP-TRACKER.md#stamp): computing and writing
# one entry of WSS.sweeps. The judgment half — whether a stamp may be
# freshness-only, what voids a carry-forward, whether a caller's coverage is
# honest — stays prose in WSS.SWEEP-TRACKER.md and wss/workflow/WSS.SWEEP-CHECKPOINT.md.
# This script does not decide any of that; it only refuses the shapes those
# two files already rule out (wss/logs/WSS.DECISIONS.md, "2026-08-13 (sixth)").
#
# The one fact this script exists to make impossible: a baseline or a distance
# typed by hand instead of computed. That same decision entry records the real
# drift it caused — a stamp recording baseline `2002f7f` and "39 behind"
# against real values of `258b9c8` and 20. So `baseline` here is ALWAYS
# `git rev-parse --short HEAD`, plus `+dirty` when `git status --porcelain`
# is non-empty — never accepted as an argument, never typeable.
#
#   wss-sweep-stamp.sh <entry> --freshness
#   wss-sweep-stamp.sh <entry> --test-run --result <green|red> [--test-count N] [--complete <true|false>]
#   wss-sweep-stamp.sh <entry> --method <incremental|full> --complete <true|false> --scopes-file <path>
#
# --scopes-file points at a JSON array of {"name": str, "covered": [...],
# "not-covered": [...]} — exactly WSS.SWEEP-CHECKPOINT.md's `scopes` shape.
# The caller (a sweeping skill) still decides what went in each list; this
# script only refuses to write a scoped stamp with none at all (Stamp step 1:
# "Refuse a stamp that carries no coverage").
#
# Run from the project directory. Resolves WSS.sweeps from
# .claude/WSS.WORKFLOW.json, falling back to .claude/WSS.SWEEPS.json — same
# resolution as wss-sweep-distance.sh and wss-wrap-status.sh. Requires jq and
# git; refuses rather than half-writing when either is missing, when the
# existing file is not valid JSON or not `sweeps/v1`, or when the resolved
# path is not gitignored (Stamp step 4) — it never edits .gitignore itself.
# Exit 2: usage error. Exit 1: refused (nothing written). Exit 0: stamped.

set -u

usage() {
  echo "usage: $0 <entry> --freshness" >&2
  echo "       $0 <entry> --test-run --result <green|red> [--test-count N] [--complete <true|false>]" >&2
  echo "       $0 <entry> --method <incremental|full> --complete <true|false> --scopes-file <path>" >&2
  exit 2
}

die() { echo "wss-sweep-stamp.sh: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required and not on PATH — refusing to half-write the checkpoint"
command -v git >/dev/null 2>&1 || die "git is required to compute the baseline"

[ $# -ge 1 ] || usage
ENTRY="$1"; shift
[ -n "$ENTRY" ] || usage

MODE=""
METHOD=""
COMPLETE=""
SCOPES_FILE=""
RESULT=""
TEST_COUNT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --freshness) [ -z "$MODE" ] || usage; MODE=freshness; shift ;;
    --test-run)  [ -z "$MODE" ] || usage; MODE=test-run; shift ;;
    --method)      [ $# -ge 2 ] || usage; METHOD="$2"; shift 2 ;;
    --complete)    [ $# -ge 2 ] || usage; COMPLETE="$2"; shift 2 ;;
    --scopes-file) [ $# -ge 2 ] || usage; SCOPES_FILE="$2"; shift 2 ;;
    --result)      [ $# -ge 2 ] || usage; RESULT="$2"; shift 2 ;;
    --test-count)  [ $# -ge 2 ] || usage; TEST_COUNT="$2"; shift 2 ;;
    *) echo "wss-sweep-stamp.sh: unrecognised argument: $1" >&2; usage ;;
  esac
done
[ -n "$MODE" ] || MODE=scoped

# Mode-exclusive arguments. A freshness stamp "claims nothing because it
# claims nothing at all" (WSS.SWEEP-CHECKPOINT.md) — giving it scopes or a
# method would contradict its own shape, so that is refused rather than
# silently dropped.
if [ "$MODE" = freshness ]; then
  { [ -n "$METHOD" ] || [ -n "$COMPLETE" ] || [ -n "$SCOPES_FILE" ] || [ -n "$RESULT" ] || [ -n "$TEST_COUNT" ]; } \
    && die "--freshness carries only baseline and at — no method/complete/scopes-file/result/test-count"
elif [ "$MODE" = test-run ]; then
  [ -z "$SCOPES_FILE" ] || die "--test-run has no scopes — a suite is meaningful only in whole (WSS.SWEEP-CHECKPOINT.md)"
else
  [ -z "$RESULT" ] || die "--result is a --test-run argument"
  [ -z "$TEST_COUNT" ] || die "--test-count is a --test-run argument"
fi

# --- baseline: computed, never accepted ------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree — cannot compute a baseline"
SHA="$(git rev-parse --short HEAD 2>/dev/null)"
[ -n "$SHA" ] || die "git rev-parse --short HEAD failed — no commits on this branch yet?"
DIRTY=0
[ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=1
BASELINE="$SHA"
[ "$DIRTY" = 1 ] && BASELINE="${SHA}+dirty"
AT="$(date +%F)"

# --- resolve the checkpoint path -------------------------------------------
MANIFEST=".claude/WSS.WORKFLOW.json"
SWEEPS=""
[ -f "$MANIFEST" ] && SWEEPS="$(jq -r '.WSS.sweeps // empty' "$MANIFEST" 2>/dev/null)"
SWEEPS="${SWEEPS:-.claude/WSS.SWEEPS.json}"

# Stamp step 4: gitignored before the first write, checked against the
# manifest-resolved path (never a literal one — a project declaring its
# checkpoint elsewhere must not pass this check vacuously). This script
# refuses instead of adding the rule itself: editing .gitignore is a hazard
# this script does not own.
if ! git check-ignore -q "$SWEEPS" 2>/dev/null; then
  die "$SWEEPS is not gitignored — add the rule to .gitignore before stamping (this script will not edit .gitignore itself)"
fi

# --- build the entry ---------------------------------------------------
case "$MODE" in
  freshness)
    NEW_ENTRY=$(jq -n --arg baseline "$BASELINE" --arg at "$AT" \
      '{baseline: $baseline, at: $at}')
    ;;

  test-run)
    [ -n "$RESULT" ] || die "--test-run requires --result green|red"
    case "$RESULT" in green|red) ;; *) die "--result must be 'green' or 'red', got: $RESULT" ;; esac
    [ -n "$COMPLETE" ] || COMPLETE=true
    case "$COMPLETE" in true|false) ;; *) die "--complete must be 'true' or 'false', got: $COMPLETE" ;; esac
    [ -n "$METHOD" ] || METHOD=full
    [ "$METHOD" = full ] || die "test-run is whole-suite only — method must be 'full' (WSS.SWEEP-CHECKPOINT.md: 'a suite is meaningful only in whole')"
    TC_JSON=null
    if [ -n "$TEST_COUNT" ]; then
      case "$TEST_COUNT" in ''|*[!0-9]*) die "--test-count must be a non-negative integer, got: $TEST_COUNT" ;; esac
      TC_JSON="$TEST_COUNT"
    fi
    NEW_ENTRY=$(jq -n --arg baseline "$BASELINE" --arg at "$AT" --arg method "$METHOD" \
      --argjson complete "$COMPLETE" --arg result "$RESULT" --argjson tc "$TC_JSON" \
      '{baseline: $baseline, at: $at, method: $method, complete: $complete, result: $result}
       + (if $tc == null then {} else {"test-count": $tc} end)')
    ;;

  scoped)
    [ -n "$METHOD" ] || die "a scoped stamp requires --method incremental|full"
    case "$METHOD" in incremental|full) ;; *) die "--method must be 'incremental' or 'full', got: $METHOD" ;; esac
    [ -n "$COMPLETE" ] || die "a scoped stamp requires --complete true|false"
    case "$COMPLETE" in true|false) ;; *) die "--complete must be 'true' or 'false', got: $COMPLETE" ;; esac
    [ -n "$SCOPES_FILE" ] || die "a scoped stamp requires --scopes-file — refusing a stamp with no coverage (Stamp step 1)"
    [ -f "$SCOPES_FILE" ] || die "--scopes-file not found: $SCOPES_FILE"

    jq -e 'type == "array" and length > 0' "$SCOPES_FILE" >/dev/null 2>&1 \
      || die "--scopes-file must be a non-empty JSON array of {name, covered, not-covered} — refusing a stamp with no coverage (Stamp step 1)"

    jq -e 'all(.[];
             (has("name") and (.name | type == "string") and (.name | length > 0))
             and (has("covered") and (.covered | type == "array"))
             and (has("not-covered") and (.["not-covered"] | type == "array"))
           )' "$SCOPES_FILE" >/dev/null 2>&1 \
      || die "--scopes-file: every scope needs name (non-empty string), covered (array), not-covered (array)"

    DUP="$(jq -r '[.[].name] | group_by(.) | map(select(length > 1)) | .[0][0] // empty' "$SCOPES_FILE")"
    [ -z "$DUP" ] || die "--scopes-file has a duplicate scope name: $DUP"

    SCOPES_JSON="$(jq -c '.' "$SCOPES_FILE")"
    NEW_ENTRY=$(jq -n --arg baseline "$BASELINE" --arg at "$AT" --arg method "$METHOD" \
      --argjson complete "$COMPLETE" --argjson scopes "$SCOPES_JSON" \
      '{baseline: $baseline, at: $at, method: $method, complete: $complete, scopes: $scopes}')
    ;;
esac

# --- merge into the checkpoint, replacing this entry only ------------------
if [ -f "$SWEEPS" ]; then
  jq -e '.' "$SWEEPS" >/dev/null 2>&1 \
    || die "$SWEEPS exists but is not valid JSON — refusing to write over it (see Reset in WSS.SWEEP-TRACKER.md)"
  jq -e '.sweep == "sweeps/v1"' "$SWEEPS" >/dev/null 2>&1 \
    || die "$SWEEPS has a missing or unrecognised 'sweep' version — refusing to write blind"
  CURRENT="$(cat "$SWEEPS")"
else
  CURRENT='{"sweep":"sweeps/v1","entries":{}}'
fi

mkdir -p "$(dirname "$SWEEPS")" || die "could not create $(dirname "$SWEEPS")"
TMP="$(mktemp "${SWEEPS}.XXXXXX")" || die "mktemp failed"
trap 'rm -f "$TMP"' EXIT

printf '%s' "$CURRENT" | jq --arg key "$ENTRY" --argjson entry "$NEW_ENTRY" \
  '.entries[$key] = $entry' > "$TMP" || die "jq merge failed — nothing written"

chmod 644 "$TMP" 2>/dev/null || true
mv "$TMP" "$SWEEPS"
trap - EXIT

echo "stamped '$ENTRY' in $SWEEPS — baseline $BASELINE, at $AT"
