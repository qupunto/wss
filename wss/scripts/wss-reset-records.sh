#!/usr/bin/env bash
#
# Blank every record this project declares, back to its canonical heading —
# a fresh start, with the structure kept and the content gone.
#
#   ./wss-reset-records.sh            # show what would be blanked, change nothing
#   ./wss-reset-records.sh --write    # do it
#   ./wss-reset-records.sh --write --dir /path/to/project
#
# WHY THIS EXISTS. A record's structure is the workflow; its content is one
# project's history. Someone adopting this suite wants the first, never the
# second — a session reading an inherited backlog will pick work off it and
# believe it. `wss-publish.sh` calls this so the published tree ships agnostic, and
# an adopter can run it directly after cloning or forking.
#
# WHAT IT WILL NOT DO. It refuses to touch a record that is not declared in the
# manifest, and it never invents files. `WSS.record.reference` (README.md) and
# `WSS.record.tooling.catalog` (.claude/WSS.TOOLING.md) are records that describe the
# TOOLING rather than the project, so blanking them would destroy the landing
# page — they are deliberately not in the table below, and deriving this list
# from the manifest instead of naming it is the mistake that would. A handoff
# at CLAUDE.md is kept, loudly, because that file also holds the project's
# standing agent instructions. Lane records (`WSS.lanes.named.*.records.*`) ARE
# blanked — they are the same records under other names.
#
# It is read-only unless you pass --write, and it prints what it is about to do
# either way, because a script that empties files should be boring to run by
# accident.
set -euo pipefail

DIR="$PWD"
WRITE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --write) WRITE=1 ;;
    --dir)   shift; DIR="${1:?--dir needs a path}" ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

MANIFEST="$DIR/.claude/WSS.WORKFLOW.json"
[ -f "$MANIFEST" ] || { echo "no .claude/WSS.WORKFLOW.json in $DIR — nothing declares a record here" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "wss-reset-records.sh needs jq" >&2; exit 1; }

# manifest key | canonical heading. The heading is what `--wss-adopt` would create,
# and nothing more: the owning skill writes the first real line, so that the
# first real line is a true one.
RECORDS='
todo|# Todo list
backlog|# Backlog
roadmap|# Roadmap
releases|# Release list
changelog|# Changelog
handoff|# Handoff
setup|# Setup
decisions|# Decision log
decisionsIndex|# Decisions index
openDecisions|# Open decisions
stocktake|# Stocktake log
audits|# Audit index
'

DIR_ABS="$(cd "$DIR" && pwd -P)"

# A manifest is data, and this script writes. `WSS.record.todo: "../../notes.md"`
# was followed and blanked — outside the project, so outside its git, so
# unrecoverable. A record that is a SYMLINK was written through onto its target
# for the same reason. Neither needs malice: a hand-edited manifest and a
# symlinked record are both things people do.
#
# So every path is resolved and must land inside the project, and a symlinked
# record is refused rather than resolved — a record that points somewhere else
# is a question for a person, not something to guess at while truncating a file.
# Refusal is loud AND fatal: wss-publish.sh depends on this script, and a partial
# reset that exits 0 would publish a tree carrying somebody's content.
#
# **`refused` is set by the CALLER, never in here, and that is the whole point.**
# This function is invoked as `abs=$(contained ...)`, which is a COMMAND
# SUBSTITUTION — a subshell. A `refused=1` assigned inside it dies with that
# subshell, so the fatal-exit block at the end of this file was unreachable and
# the script returned 0 while refusing, which is exactly the failure the
# paragraph above claims to prevent. It shipped that way, and the tests could
# not see it because they discarded the exit code with `|| :`.
refused=0
contained() { # relative-path, label -> prints the absolute path, or returns 1
  local rel=$1 target tdir abs
  target="$DIR/$rel"
  if [ -L "$target" ]; then
    printf '  REFUSE %-14s %s is a symlink — resolve it yourself\n' "$2" "$rel" >&2
    return 1
  fi
  tdir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    printf '  REFUSE %-14s %s has no reachable directory\n' "$2" "$rel" >&2
    return 1
  }
  abs="$tdir/$(basename "$target")"
  case "$abs/" in
    "$DIR_ABS"/*) ;;
    *) printf '  REFUSE %-14s %s resolves outside the project (%s)\n' "$2" "$rel" "$abs" >&2
       return 1 ;;
  esac
  # An unwritable record is refused HERE rather than discovered at the `>`
  # redirect — audit pass 6's M3: under `set -euo pipefail` that redirect kills
  # the run mid-loop, records already blanked, nothing reporting why. Refusing
  # at resolution keeps the established shape: skip the file, keep going,
  # exit 1 at the end — and the dry run predicts the same refusal.
  if [ -e "$abs" ] && [ ! -w "$abs" ]; then
    printf '  REFUSE %-14s %s is not writable\n' "$2" "$rel" >&2
    return 1
  fi
  printf '%s' "$abs"
}

changed=0 skipped=0
blanked=()
while IFS='|' read -r key heading; do
  [ -n "$key" ] || continue
  rel=$(jq -r --arg k "$key" '.WSS.record[$k] // empty | if type == "string" then . else empty end' "$MANIFEST")
  # `if type == "string"` is not defensive noise: WSS.record.todo may be a PROVIDER
  # object naming a GitHub label, and there is no file to blank in that case.
  # Emptying a backlog that lives in someone's issue tracker is not this
  # script's business, and could not be undone from here.
  if [ -z "$rel" ]; then
    printf '  skip   %-14s not declared as a file\n' "$key"; skipped=$((skipped + 1)); continue
  fi
  # A handoff at CLAUDE.md also holds the project's standing agent
  # instructions — WSS.MANIFEST.md's fallback merges the two into one file — so
  # blanking it destroys more than a record. wss-retire-workflow.sh already kept
  # it for that reason and this script blanked it, an asymmetry audit pass 10
  # read as an oversight (F5); it now was one no longer. Trimming the handoff
  # section out of an inherited CLAUDE.md is a judgement call, so it is left
  # to a person, loudly.
  if [ "$key" = "handoff" ]; then
    case "$rel" in CLAUDE.md|./CLAUDE.md)
      printf '  keep   %-14s %s also holds the project'\''s own instructions — trim the handoff section by hand\n' "$key" "$rel"
      skipped=$((skipped + 1)); continue ;;
    esac
  fi
  if [ ! -f "$DIR/$rel" ]; then
    printf '  skip   %-14s %s does not exist\n' "$key" "$rel"; skipped=$((skipped + 1)); continue
  fi
  abs=$(contained "$rel" "$key") || { refused=1; skipped=$((skipped + 1)); continue; }
  blanked+=("$rel")
  before=$(wc -c < "$abs" | tr -d ' ')
  # A STRUCTURED-REGION MARKER SURVIVES THE BLANKING — owner's ruling,
  # 2026-08-19: "structured regions have a reason to be". The marker is part of
  # the record's SHAPE, not its content, so an adopter receives a blanked record
  # that still declares how its body is built. Each surviving region is emitted
  # EMPTY: the opening marker and its end, back to back, in source order. A
  # record with no marker is written exactly as before — one heading, byte for
  # byte — which is what keeps this change invisible to every existing caller.
  regions=$(awk '
    /^<!--[[:space:]]*wss:region[[:space:]]+entry=/ { print; print "<!-- wss:region-end -->" }
  ' "$abs")
  if [ "$WRITE" -eq 1 ]; then
    if [ -n "$regions" ]; then
      printf '%s\n\n%s\n' "$heading" "$regions" > "$abs"
    else
      printf '%s\n' "$heading" > "$abs"
    fi
    after=$(wc -c < "$abs" | tr -d ' ')
    printf '  blank  %-14s %s (was %s bytes -> %s)\n' "$key" "$rel" "$before" "$after"
  else
    if [ -n "$regions" ]; then
      would=$(printf '%s\n\n%s\n' "$heading" "$regions" | wc -c | tr -d ' ')
    else
      would=$(( ${#heading} + 1 ))
    fi
    printf '  would  %-14s %s (%s bytes -> %s)\n' "$key" "$rel" "$before" "$would"
  fi
  changed=$((changed + 1))
done <<EOF
$RECORDS
EOF

# Lane records are the same records under other names — split per lane by
# WSS.LANE-CONTRACT.md's resolution rule, with the same owners and the same content
# hazard. wss-export-records.sh and wss-retire-workflow.sh both enumerate
# `WSS.lanes.named.*.records.*`; this script did not, and a forked lane-split
# project shipped every lane's backlog, open decisions and handoff un-blanked
# (audit pass 10, F1 — proven against a seeded two-lane fixture). Headings key
# on the record name from the table above; a lane handoff's directory can
# carry a WSS.HAZARDS.md sibling of its own, blanked here like the top-level one
# below.
while IFS=$'\t' read -r lkey lrec rel; do
  [ -n "$rel" ] || continue
  heading=$(printf '%s\n' "$RECORDS" | awk -F'|' -v k="$lrec" '$1 == k {print $2; exit}')
  # The transfer queue is not in RECORDS and must not be: that table drives the
  # TOP-LEVEL loop, which resolves each key against `.WSS.record[…]`, and a queue is
  # declared beside `records` rather than in it. It reaches this loop only as a
  # lane key, so its heading is named here. A queue carries one project's
  # cross-lane requests, which is exactly the content an adopter must not
  # inherit — and unlike a record, an inherited one would be silently drained
  # into that adopter's backlog by the first `--wss-start`.
  [ "$lrec" = "transfer" ] && heading="# Transfer queue"
  [ -n "$heading" ] || heading="# ${lrec}"
  if [ "$lrec" = "handoff" ]; then
    case "$rel" in CLAUDE.md|./CLAUDE.md)
      printf '  keep   %-14s %s also holds the project'\''s own instructions — trim the handoff section by hand\n' "$lkey" "$rel"
      skipped=$((skipped + 1)); continue ;;
    esac
  fi
  if [ ! -f "$DIR/$rel" ]; then
    printf '  skip   %-14s %s does not exist\n' "$lkey" "$rel"; skipped=$((skipped + 1)); continue
  fi
  abs=$(contained "$rel" "$lkey") || { refused=1; skipped=$((skipped + 1)); continue; }
  blanked+=("$rel")
  before=$(wc -c < "$abs" | tr -d ' ')
  if [ "$WRITE" -eq 1 ]; then
    printf '%s\n' "$heading" > "$abs"
    printf '  blank  %-14s %s (was %s bytes)\n' "$lkey" "$rel" "$before"
  else
    printf '  would  %-14s %s (%s bytes -> %s)\n' "$lkey" "$rel" "$before" "${#heading}"
  fi
  changed=$((changed + 1))
  if [ "$lrec" = "handoff" ]; then
    lhz="$(dirname "$rel")/WSS.HAZARDS.md"; lhz="${lhz#./}"
    if [ -f "$DIR/$lhz" ]; then
      if abs=$(contained "$lhz" "$lkey.hazards"); then
        blanked+=("$lhz")
        if [ "$WRITE" -eq 1 ]; then
          printf '# Standing hazards\n' > "$abs"
          printf '  blank  %-14s %s\n' "$lkey.hazards" "$lhz"
        else
          printf '  would  %-14s %s\n' "$lkey.hazards" "$lhz"
        fi
        changed=$((changed + 1))
      else
        refused=1; skipped=$((skipped + 1))
      fi
    fi
  fi
done < <(jq -r '.WSS.lanes.named // {} | to_entries[] | .key as $l
    | ( ((.value.records // {}) | to_entries[]
          | select(.value | type == "string")
          | ["lane:" + $l + "." + .key, .key, .value]),
        ((.value.transfer // empty)
          | ["lane:" + $l + ".transfer", "transfer", .]) )
    | @tsv' "$MANIFEST" 2>/dev/null)

# The conflict inbox is project-level rather than per-lane, so it is reached by
# neither loop above. An inherited one is one project's cross-lane disputes, and
# the adopting project's first synch run would mediate them as its own.
conf_rel=$(jq -r '.WSS.lanes.conflicts // empty' "$MANIFEST" 2>/dev/null || true)
if [ -n "$conf_rel" ] && [ -f "$DIR/$conf_rel" ]; then
  if abs=$(contained "$conf_rel" "WSS.lanes.conflicts"); then
    before=$(wc -c < "$abs" | tr -d ' ')
    if [ "$WRITE" -eq 1 ]; then
      printf '# Conflict inbox\n' > "$abs"
      printf '  blank  %-14s %s (was %s bytes)\n' "WSS.lanes.conflicts" "$conf_rel" "$before"
    else
      printf '  would  %-14s %s (%s bytes -> 17)\n' "WSS.lanes.conflicts" "$conf_rel" "$before"
    fi
    changed=$((changed + 1))
  else
    refused=1; skipped=$((skipped + 1))
  fi
fi

# The hazards file is not a record, but it carries standing warnings about
# whichever repository wrote them — which is exactly the content an adopter
# must not inherit. It is the handoff's overflow sibling, so it lives in
# `WSS.record.handoff`'s own directory — resolved from the manifest, not assumed:
# the path was hardcoded to .claude/WSS.HAZARDS.md, and a fork keeping its handoff
# anywhere else shipped its hazards un-blanked (audit pass 9, F7). The
# hardcoded path stays as the fallback where no handoff is declared as a file.
# `WSS.hazards.*` manifest keys may anchor into it; those pointers are trimmed
# below, with the content their anchors named.
# Through contained() like every other record, because it is one in every way
# that matters here: it is a file this script truncates. Written directly, it
# was the one path that could still be followed through a symlink onto an
# external target — in the same change that claimed to close that class.
hz_rel="wss/records/WSS.HAZARDS.md"
handoff_rel=$(jq -r '.WSS.record.handoff // empty | if type == "string" then . else empty end' "$MANIFEST")
if [ -n "$handoff_rel" ]; then
  hz_rel="$(dirname "$handoff_rel")/WSS.HAZARDS.md"
  hz_rel="${hz_rel#./}"
fi
if [ -f "$DIR/$hz_rel" ]; then
  if abs=$(contained "$hz_rel" "hazards"); then
    blanked+=("$hz_rel")
    if [ "$WRITE" -eq 1 ]; then
      printf '# Standing hazards\n' > "$abs"
      printf '  blank  %-14s %s\n' "hazards" "$hz_rel"
    else
      printf '  would  %-14s %s\n' "hazards" "$hz_rel"
    fi
    changed=$((changed + 1))
  else
    refused=1; skipped=$((skipped + 1))
  fi
fi

# A `WSS.hazards.*` pointer anchored into a file blanked above now dangles — the
# heading its #anchor named went with the content — and a dangling pointer is a
# doctor FAILURE in the very tree this script exists to make healthy. Trim
# exactly those. A pointer into a file this run did not touch is the project's
# own and stays, whatever it says.
if [ ${#blanked[@]} -gt 0 ] &&
   jq -e '.WSS.hazards | type == "object"' "$MANIFEST" >/dev/null 2>&1; then
  bj=$(printf '%s\n' "${blanked[@]}" | jq -R . | jq -s .)
  doomed=$(jq -r --argjson b "$bj" '
    .WSS.hazards | to_entries[]
    | select((.value | split("#")[0]) as $f | ($b | index($f)) != null)
    | .key' "$MANIFEST")
  if [ -n "$doomed" ]; then
    if [ "$WRITE" -eq 1 ]; then
      tmp=$(mktemp)
      jq --argjson b "$bj" '
        .WSS.hazards |= with_entries(
          select((.value | split("#")[0]) as $f | ($b | index($f)) == null))
        | if .WSS.hazards == {} then del(.WSS.hazards) else . end' \
        "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
      for k in $doomed; do
        printf '  trim   %-14s hazards.%s pointed into a blanked file\n' "manifest" "$k"
      done
    else
      for k in $doomed; do
        printf '  would  %-14s trim hazards.%s — points into a blanked file\n' "manifest" "$k"
      done
    fi
  fi
fi

echo
if [ "$WRITE" -eq 1 ]; then
  echo "blanked $changed, skipped $skipped"
else
  echo "$changed would be blanked, $skipped skipped — nothing was written. Pass --write to do it."
fi
[ "$refused" -eq 0 ] || {
  echo "REFUSED at least one record — see above. Nothing outside the project was touched." >&2
  exit 1
}
