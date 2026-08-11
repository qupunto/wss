#!/usr/bin/env bash
# wss-sweep-distance.sh — how far each sweep has fallen behind HEAD.
#
# One computation, two renderings. `wss-probe.sh` calls it for --wss-overview's
# `== sweeps ==` block (verbose: baseline, stamp, method, result, distance, one
# entry per line); --wss-wrap step 7 calls it with --compact for its single
# closing line (`name: N, name: N`). The difference is formatting only — before
# this file the two lived as two implementations and could disagree silently.
#
#   wss-sweep-distance.sh [--verbose|--compact]
#
# Run it from the project directory. Read-only and offline: it reads the
# manifest, the checkpoint and git, and writes nothing. Measuring a baseline is
# not advancing one — the checkpoint is `sweep-tracker`'s file.
#
# THE FIGURES ARE A REPORT AND NOT A GATE. Every path exits 0, including no
# checkpoint, no entries and an unreadable baseline, so nothing here can block
# or fail a caller. Only a usage error exits non-zero.

set -u

MODE=verbose
case "${1:---verbose}" in
  --verbose) MODE=verbose ;;
  --compact) MODE=compact ;;
  *) printf 'usage: %s [--verbose|--compact]\n' "${0##*/}" >&2; exit 2 ;;
esac

# Same resolution as wss-session-check.sh and wss-doctor.sh: the declared key,
# else the conventional path. An undeclared WSS.sweeps is NOT the absent case —
# a project that swept without declaring the key still gets its line, and only a
# path with no file behind it goes quiet.
MANIFEST=".claude/WSS.WORKFLOW.json"
HAVE_JQ=1; command -v jq >/dev/null 2>&1 || HAVE_JQ=0
SWEEPS=""
[ "$HAVE_JQ" = 1 ] && [ -f "$MANIFEST" ] && \
  SWEEPS="$(jq -r '.WSS.sweeps // empty' "$MANIFEST" 2>/dev/null)"
SWEEPS="${SWEEPS:-.claude/WSS.SWEEPS.json}"

if [ ! -f "$SWEEPS" ]; then
  # A project that has never swept has no distance, and inventing a zero for it
  # would claim freshness it has not earned. The compact line stays silent.
  [ "$MODE" = verbose ] && echo "no checkpoint file at $SWEEPS — no sweep has ever run here"
  exit 0
fi
if [ "$HAVE_JQ" = 0 ]; then
  [ "$MODE" = verbose ] && echo "checkpoint exists at $SWEEPS but jq is unavailable — not read"
  exit 0
fi

# Only `entries` is read, matching what `sweep-tracker` resolves. A stamp at the
# root of the file is invisible to the tracker, and a reporter that saw further
# than the writer would report freshness the sweep machinery does not have.
#
# Joined on US (\037), NOT on a tab, and read with IFS set to it. A tab is IFS
# whitespace, so `read` collapses a run of them however IFS is set: an entry with
# no `baseline` field loses its empty column and every later field shifts left,
# which made a missing baseline read as whatever `at` held. Both hand-written
# copies of this loop split on tabs, and this is where they disagreed.
ENTRIES="$(jq -r '
    .entries // {} | to_entries[]
    | [.key, (.value.baseline // ""), (.value.at // "-"),
       (.value.method // "-"), (.value.result // "")] | join("\u001f")' \
  "$SWEEPS" 2>/dev/null)"

if [ -z "$ENTRIES" ]; then
  [ "$MODE" = verbose ] && echo "checkpoint exists but holds no entries"
  exit 0
fi

line=""
while IFS=$'\037' read -r name baseline at method result; do
  [ -n "$name" ] || continue

  # A sweep that stamped over a dirty tree records `<sha>+dirty`. The sha is the
  # commit; the suffix is a note about the tree, and git resolves neither with it.
  sha="${baseline%+dirty}"
  mark=""; [ "$sha" != "$baseline" ] && mark=", dirty at stamp"

  # Four states, and only one of them is a number. `rev-list` would happily
  # count from a baseline HEAD does not descend from, but what it counts is
  # everything on HEAD's side of the divergence, which reads as catastrophic
  # drift when the only fact is that the sha no longer sits behind HEAD. An
  # empty baseline is worse: `..HEAD` counts zero and claims perfect freshness.
  n=""
  if   [ -z "$sha" ]; then                                        state=nobaseline
  elif ! git cat-file -e "$sha^{commit}" 2>/dev/null; then        state=nocommit
  elif ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then state=offhistory
  else
    n="$(git rev-list --count "$sha"..HEAD 2>/dev/null)"
    if [ -n "$n" ]; then state=behind; else state=nocommit; fi
  fi

  if [ "$MODE" = compact ]; then
    case $state in
      behind)     v="$n" ;;
      nobaseline) v="no baseline" ;;
      nocommit)   v="no such commit" ;;
      offhistory) v="off this history" ;;
    esac
    line="${line:+$line, }$name: $v"
  else
    extra=""; [ -n "$result" ] && extra=", result $result"
    case $state in
      behind)
        printf '%s: baseline %s (%s, %s%s%s) — %s commits behind HEAD\n' \
          "$name" "$sha" "$at" "$method" "$mark" "$extra" "$n" ;;
      nobaseline)
        printf '%s: no baseline recorded — sweep in full\n' "$name" ;;
      nocommit)
        printf '%s: baseline %s is not a commit in this repository — sweep in full\n' \
          "$name" "$baseline" ;;
      offhistory)
        printf '%s: baseline %s is off this history — HEAD does not descend from it, sweep in full\n' \
          "$name" "$baseline" ;;
    esac
  fi
done <<< "$ENTRIES"

[ "$MODE" = compact ] && [ -n "$line" ] && printf '%s\n' "$line"
exit 0
