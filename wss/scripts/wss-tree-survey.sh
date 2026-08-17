#!/usr/bin/env bash
# Survey one adopted tree: print the properties that decide which suite surface
# that tree can exercise. Read-only — it writes nothing into the tree it
# surveys, contacts no network except the optional `gh` probe, and runs from
# inside the project root.
#
#   cd <project> && ~/.claude/wss-tree-survey.sh
#   ~/.claude/wss-tree-survey.sh --no-gh --no-doctor
#   ~/.claude/wss-tree-survey.sh -o ~/surveys/proj.txt   # also tee to a file
#
# !important — THE OUTPUT IS LOCAL-ONLY. NEVER ROUTE IT UPSTREAM.
# It names a private project, its path, its branch names, its remote URLs and
# its record layout. `--wss-report` opens issues on a PUBLIC repository, and
# publishing is irreversible — forks and caches outlive a deletion. So:
#
#   * do NOT pass this through `--wss-report`, `gh issue create`, or any other
#     GitHub transport;
#   * do NOT paste it into a public repository's records — the suite repo's own
#     rule is that a record holds only its own project;
#   * DO paste it into a session, or save it beside the tree it describes.
#
# What is missing upstream was never transport, it is a report KIND. A survey
# does not become publishable by being useful.
#
# WHAT IT ANSWERS, and why those and not others. The roadmap goal "Proven by
# use" is blocked on a mapping from each unexercised surface to a tree that can
# exercise it, and that mapping needs properties rather than names: does the
# tree split records by lane, is its TODO list a file or a provider, does it
# declare a behaviour record, does it declare local CI, is it on current
# conventions or pre-rename ones. The tree's own manifest is the only honest
# source; guessing from a project name is exactly what the block forbids.
#
# WHAT IT CANNOT ANSWER. Whether the project is actively using the suite or
# winding down. Nothing detects that, and it decides whether `--wss-retire` is
# exerciseable at all, so the report ends by asking for it by hand.
#
# A TREE WITH NO MANIFEST IS SURVEYED TOO, and said to be unadopted rather than
# skipped: its adoption is itself an exercise, and knowing its shape beforehand
# says what `--wss-adopt` is about to meet. Every property it cannot read prints
# a reason. A survey that prints blanks for a tree it could not read is worse
# than one that says so — the blanks read as "declares nothing", which is a
# different fact.

set -u

GH=1
DOCTOR=1
OUT=""
while [ $# -gt 0 ]; do
  case $1 in
    --no-gh)     GH=0 ;;
    --no-doctor) DOCTOR=0 ;;
    -o)          shift; OUT=${1:?-o needs a path} ;;
    -h|--help)   sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "wss-tree-survey.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

TREE="$(pwd -P)"

# `-o` inside the surveyed tree would make a read-only survey write to its
# subject, and the file would then be picked up by that project's own git
# status, its next survey, or a publish gate. Refuse it rather than warn: the
# same shape as wss-publish.sh refusing an output directory inside its source.
if [ -n "$OUT" ]; then
  out_dir="$(cd "$(dirname "$OUT")" 2>/dev/null && pwd -P)" ||
    { echo "wss-tree-survey.sh: no directory for -o '$OUT'" >&2; exit 2; }
  [ -n "$out_dir" ] || { echo "wss-tree-survey.sh: no directory for -o '$OUT'" >&2; exit 2; }
  case "$out_dir/" in
    "$TREE"/*|"$TREE"/)
      echo "wss-tree-survey.sh: refusing to write inside the tree being surveyed" >&2
      if [ "$out_dir" = "$TREE" ]; then
        echo "  $out_dir IS the tree — the survey must not touch its subject." >&2
      else
        echo "  $out_dir is under $TREE — the survey must not touch its subject." >&2
      fi
      echo "  Point -o outside the project, or drop it and paste stdout." >&2
      exit 2 ;;
  esac
  OUT="$out_dir/$(basename "$OUT")"
fi

# ---------------------------------------------------------------- resolution --

# The doctor ships one level up from this script (wss-doctor.sh did not move
# in 2026-08-15's tier 2, and this script did), so its own location needs no
# environment to be known — the same reason wss-doctor.sh asks where IT lives. The other two
# levels exist for a copy of this file run from somewhere else. The plugin-cache
# glob is deliberately name-agnostic: the marketplace and plugin segments have
# already been renamed once, and a glob spelling the old name finds nothing and
# says nothing.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DOCTOR_SH=""
# wss/tests/, not the tree root: the 2026-08-16 reorg moved the doctor there and
# left all three candidates below pointing at where it used to be, so every one
# of them missed and this fell through to the empty-string branch on a tree with
# a perfectly good doctor in it. SELF_DIR is wss/scripts/, so the sibling hop is
# ../tests and not ../../.
for cand in "$SELF_DIR/../tests/wss-doctor.sh" "$CONFIG_DIR/wss/tests/wss-doctor.sh"; do
  [ -f "$cand" ] && { DOCTOR_SH="$cand"; break; }
done
if [ -z "$DOCTOR_SH" ]; then
  DOCTOR_SH=$(ls -1 "$CONFIG_DIR"/plugins/cache/*/*/*/wss/tests/wss-doctor.sh 2>/dev/null | tail -1)
fi

# The two manifest shapes. The pre-rename FILENAME is the dangerous one: no
# current reader looks for it, so left undetected it reads as cleanly absent
# rather than as legacy — which is the single fact this survey most needs to
# get right, since "legacy conventions" is one of the properties being mapped.
MANIFEST=""
MANIFEST_KIND="none"
if [ -f "$TREE/.claude/WSS.WORKFLOW.json" ]; then
  MANIFEST="$TREE/.claude/WSS.WORKFLOW.json"; MANIFEST_KIND="current-name"
elif [ -f "$TREE/.claude/workflow.json" ]; then
  MANIFEST="$TREE/.claude/workflow.json";     MANIFEST_KIND="legacy-name"
fi

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# A v1 manifest is not merely an old v2: one key changed MEANING across the
# split. `record.audits` named the stocktake log under v1 and names the audit
# index under v2 (wss/workflow/WSS.MANIFEST.md, "record" section). Reading a legacy
# value under the current label is the one way this survey could report a
# confident wrong property rather than an unread one, so the shape is detected
# once here and the affected row says which meaning it is showing.
LEGACY_SCHEMA=0
if [ -n "$MANIFEST" ] && [ "$HAVE_JQ" -eq 1 ]; then
  jq -e 'has("WSS")' "$MANIFEST" >/dev/null 2>&1 || LEGACY_SCHEMA=1
fi

# Every manifest read goes through here, and every one of them can fail for
# three different reasons that must not be confused: no manifest, no jq, or a
# key genuinely absent. Each gets its own words.
#
# `(.WSS // .)` is the two-shape read wss-export-records.sh uses: the v2 root
# where it exists, the whole flat document on a pre-rename workflow/v1
# manifest. Reading only `.WSS` would report every legacy tree as declaring
# nothing at all.
m() { # jq-expression [absent-text]
  if [ -z "$MANIFEST" ]; then printf '(no manifest — cannot tell)'; return; fi
  if [ "$HAVE_JQ" -eq 0 ]; then printf '(jq not installed — cannot read the manifest)'; return; fi
  local v
  v=$(jq -r "(.WSS // .) as \$w | $1" "$MANIFEST" 2>/dev/null) || v=""
  if [ -z "$v" ] || [ "$v" = "null" ]; then printf '%s' "${2:-not declared}"; else printf '%s' "$v"; fi
}

row() { printf '  %-26s %s\n' "$1" "$2"; }
sec() { printf '\n--- %s ---\n' "$1"; }

# --------------------------------------------------------------- the survey --

survey() {

printf '==============================================\n'
printf 'TREE:   %s\n' "$(basename "$TREE")"
printf 'PATH:   %s\n' "$TREE"
printf 'DATE:   %s\n' "$(date -I)"
printf 'SURVEY: wss-tree-survey.sh — LOCAL ONLY, never send upstream\n'
printf '==============================================\n'

sec "adopted?"
case "$MANIFEST_KIND" in
  current-name) row "manifest file" ".claude/WSS.WORKFLOW.json (current name)" ;;
  legacy-name)  row "manifest file" ".claude/workflow.json (PRE-RENAME name — needs --wss-update)" ;;
  none)         row "manifest file" "NONE — this tree has not adopted the suite" ;;
esac
if [ -n "$MANIFEST" ]; then
  schema=$(m '$w.manifest // empty' "(absent — pre-v2 or hand-written)")
  row "schema" "$schema"
  if [ "$HAVE_JQ" -eq 1 ]; then
    if jq -e 'has("WSS")' "$MANIFEST" >/dev/null 2>&1; then
      row "WSS root" "present (v2 nesting)"
    else
      row "WSS root" "ABSENT — flat keys, LEGACY schema"
    fi
    jq -e . "$MANIFEST" >/dev/null 2>&1 || row "parse" "FAILED — the manifest is not valid JSON"
  fi
  row "suite stamp" "$(m '$w.suite | if . == null then empty else "\(.version // "?") @ \(.commit // "?")" end' "not stamped (never migrated by update)")"
fi
[ "$HAVE_JQ" -eq 0 ] && row "jq" "NOT INSTALLED — every manifest property below is unread, not empty"

sec "properties the surface mapping needs"
row "lanes declared" "$(m '($w.lanes.named // {} | keys | join(", ")) // empty' "no — unsplit project")"
row "lane conflict queue" "$(m '$w.lanes.conflicts // empty')"
row "TODO list" "$(m '$w.record.todo | if . == null then empty elif type == "object" then "PROVIDER: \(.provider // "?") \(.repo // "") \(.label // "")" else "file: \(.)" end' "not declared (fallback WSS.TODO.md)")"
row "behaviour record" "$(m '$w.record.behaviour // empty' "not declared")"
row "local CI" "$(m '$w.localCI // empty' "not declared")"
row "stocktake record" "$(m '$w.record.stocktake // empty' "not declared")"
if [ "$LEGACY_SCHEMA" -eq 1 ]; then
  row "record.audits (v1)" "$(m '$w.record.audits // empty' "not declared")  <- v1: this key is the STOCKTAKE log, not the audit index"
else
  row "audit index" "$(m '$w.record.audits // empty' "not declared")"
fi
row "toolbelt" "$(m '$w.record.toolbelt // empty' "not declared")"
row "docs decisions" "$(m '$w.record.decisions // empty' "not declared")"
row "decisions index" "$(m '$w.record.decisionsIndex // empty' "not declared (no indexRegen command)")"
row "reference record(s)" "$(m '$w.record.reference | if type == "array" then join(", ") else . end // empty' "not declared")"
row "branches" "$(m '"integration=\($w.branch.integration // "?") publish=\($w.branch.publish // "?") merge=\($w.branch.mergeMethod // "merge (fallback)")"')"
row "CI command" "$(m '$w.commands.ci | if . == null then empty elif type == "object" then "\(.tool // "?"):\(.workflow // "?")" else . end' "not declared")"
row "test command" "$(m '$w.commands.test // empty' "not declared")"
row "typecheck command" "$(m '$w.commands.typecheck // empty' "not declared")"
row "agents declared" "$(m '($w.agents // {} | keys | join(", ")) // empty' "none — every role falls back")"
row "audit dimensions" "$(m '($w.audit.dimensions // [] | map(if type == "object" then .name else . end) | join(", ")) // empty' "built-in set only")"
row "onSchemaChange" "$(m '$w.onSchemaChange // empty' "not declared")"
row "hazard pointers" "$(m '($w.hazards // {} | keys | join(", ")) // empty' "none")"

sec "declared record files — do they exist?"
if [ -z "$MANIFEST" ]; then
  echo "  (no manifest — nothing declared to check)"
elif [ "$HAVE_JQ" -eq 0 ]; then
  echo "  (jq not installed — cannot enumerate)"
else
  # Strings and arrays under record.*, plus the tooling catalog and every lane
  # record. A provider object has no file and contributes nothing.
  jq -r '(.WSS // .) as $w |
    [ ($w.record // {} | to_entries[] | .value
        | if type == "string" then . elif type == "array" then .[] else empty end),
      ($w.record.tooling // {} | .catalog // empty),
      ($w.lanes.named // {} | .[]? | (.records // {}) | .[]?),
      ($w.lanes.named // {} | .[]? | .transfer // empty),
      ($w.lanes.conflicts // empty)
    ] | .[] | select(type == "string")' "$MANIFEST" 2>/dev/null | sort -u |
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ -f "$TREE/$p" ]; then
      printf '  %-6s %s\n' "ok" "$p"
    else
      printf '  %-6s %s\n' "MISSING" "$p"
    fi
  done
fi

sec "lane selector and worktrees"
if [ -f "$TREE/.claude/WSS.LANE" ]; then
  row "selector" "this worktree is lane '$(cat "$TREE/.claude/WSS.LANE")'"
elif [ -f "$TREE/.claude/lane" ]; then
  row "selector" "PRE-RENAME .claude/lane — lane '$(cat "$TREE/.claude/lane")'"
else
  row "selector" "none in this worktree"
fi
# Guarded on the git test rather than on `git … | sed || echo`: a pipeline's
# status is its LAST command's, so sed always succeeded and the fallback never
# fired — a non-checkout printed nothing here and read as "one worktree, no
# lanes". Measured on a fixture, not predicted.
if git -C "$TREE" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$TREE" worktree list 2>/dev/null | sed 's/^/  /'
else
  echo "  (not a git checkout — no worktrees to list)"
fi

sec "docs site"
found=0
for f in wss/docs/index.html wss/docs/_sidebar.md wss/docs/index.md; do
  [ -f "$TREE/$f" ] && { printf '  %s\n' "$f"; found=1; }
done
if [ "$found" -eq 0 ]; then
  for f in docs/index.html docs/_sidebar.md docs/index.md; do
    [ -f "$TREE/$f" ] && { printf '  %s\n' "$f"; found=1; }
  done
fi
[ "$found" -eq 0 ] && echo "  (no docs site)"

sec "git"
if git -C "$TREE" rev-parse --git-dir >/dev/null 2>&1; then
  row "branch" "$(git -C "$TREE" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  row "dirty files" "$(git -C "$TREE" status --porcelain 2>/dev/null | wc -l)"
  row "commits" "$(git -C "$TREE" rev-list --count HEAD 2>/dev/null || echo '?')"
  row "last commit" "$(git -C "$TREE" log -1 --format='%ad' --date=short 2>/dev/null || echo '?')"
  git -C "$TREE" remote -v 2>/dev/null | head -2 | sed 's/^/  /'
  git -C "$TREE" status --porcelain 2>/dev/null | head -5 | sed 's/^/  /'
else
  echo "  (not a git checkout)"
fi

sec "TODO list probe"
if [ "$GH" -eq 0 ]; then
  echo "  (skipped — --no-gh)"
elif ! command -v gh >/dev/null 2>&1; then
  echo "  (gh not installed — cannot tell whether issues are in use)"
elif gh_out=$(gh issue list --limit 3 2>&1); then
  # THREE outcomes, and the difference between the last two is the whole point
  # of the probe: issues in use, a repo with none, and a repo gh could not read
  # at all. Collapsing the third into the second reports "file TODO list" for a
  # tree whose TODO list was never looked at.
  if [ -n "$gh_out" ]; then
    printf '%s\n' "$gh_out" | head -5 | sed 's/^/  /'
  else
    echo "  (no open issues — a file TODO list, or an empty one)"
  fi
else
  echo "  (gh COULD NOT READ issues here — not a GitHub repo, or not"
  echo "   authenticated. This is unknown, not 'no issues':)"
  printf '%s\n' "$gh_out" | head -2 | sed 's/^/     /'
fi

sec "doctor"
if [ "$DOCTOR" -eq 0 ]; then
  echo "  (skipped — --no-doctor)"
elif [ -z "$DOCTOR_SH" ]; then
  echo "  wss-doctor.sh NOT FOUND — looked beside this script, in"
  echo "  $CONFIG_DIR, and in the plugin cache. The suite may not be"
  echo "  installed on this machine at all, which is itself a survey finding."
else
  printf '  using %s\n' "$DOCTOR_SH"
  # tail -30 keeps the report bounded, which also throws away the head — so the
  # exit code is reported separately rather than inferred from what survived
  # the tail. `set -u` and no pipefail: PIPESTATUS[0] is the doctor's own.
  bash "$DOCTOR_SH" 2>&1 | tail -30 | sed 's/^/  /'
  drc=${PIPESTATUS[0]}
  case "$drc" in
    0) row "doctor exit" "0 — passed" ;;
    *) row "doctor exit" "$drc — FAILED (the tail above may not show why)" ;;
  esac
fi

sec "the one question nothing can detect"
cat <<'ASK'
  ANSWER BY HAND. It decides whether --wss-retire is exerciseable at all:
  a real run removes the workflow from the project, so it can only be
  exercised at the END of a tree's life with the suite. If no surveyed
  tree is ever winding down, that block is unexerciseable and belongs
  written off in the roadmap rather than left reading as scheduled work.

    [ ] actively using the suite
    [ ] winding down / would be willing to run --wss-retire on it
ASK

sec "reminder"
echo "  LOCAL ONLY. Do not open a GitHub issue with this and do not route it"
echo "  through --wss-report: qupunto/wss is public, this names a private tree."

}

if [ -n "$OUT" ]; then
  survey 2>&1 | tee "$OUT"
  printf '\nsaved to %s\n' "$OUT"
else
  survey 2>&1
fi
