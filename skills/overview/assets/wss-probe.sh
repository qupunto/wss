#!/usr/bin/env bash
# wss-probe.sh — the mechanical half of --wss-overview, in one read-only call.
#
# Emits every countable line of the overview report: tree, per-record open
# counts, warning counts, sweep freshness, roadmap position. The skill adds
# the judgment lines only. Writes nothing, stamps nothing, never touches the
# network — external state (backlog providers, gh, CI) is reported as not
# counted here, never as zero.
#
# Run it from the project directory. It lives with the installation, which is
# how it finds wss-doctor.sh in both install forms (checkout and plugin cache).

INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MANIFEST=".claude/WSS.WORKFLOW.json"

HAVE_JQ=1; command -v jq >/dev/null 2>&1 || HAVE_JQ=0
HAVE_MANIFEST=0; [ -f "$MANIFEST" ] && HAVE_MANIFEST=1

# With a manifest, an undeclared key is reported "undeclared" — no fallback.
# With no manifest at all, the conventional names from workflow/WSS.MANIFEST.md
# apply. jq missing while a manifest exists makes it unreadable: every key
# reads as undeclared, and the header says why.
mget() { # mget <jq-path> <fallback-with-no-manifest>
  if [ "$HAVE_MANIFEST" = 1 ]; then
    [ "$HAVE_JQ" = 1 ] && jq -r "$1 // empty" "$MANIFEST" 2>/dev/null || true
  else
    printf '%s\n' "$2"
  fi
}

LANE=""
[ -f .claude/WSS.LANE ] && LANE="$(head -1 .claude/WSS.LANE 2>/dev/null | tr -d '[:space:]')"

resolve_record() { # resolve_record <key> <fallback> — lane-aware per WSS.MANIFEST.md
  local path override
  path="$(mget ".WSS.record.$1" "$2")"
  if [ -n "$LANE" ]; then
    override="$(mget ".WSS.lanes.named.\"$LANE\".records.$1" "")"
    [ -n "$override" ] && path="$override"
  fi
  printf '%s\n' "$path"
}

count_line() { # count_line <label> <path-or-empty> <grep-pattern> <unit>
  if [ -z "$2" ]; then
    printf '%s: undeclared\n' "$1"
  elif [ ! -f "$2" ]; then
    printf '%s: %s — missing\n' "$1" "$2"
  else
    printf '%s: %s — %s %s\n' "$1" "$2" "$(grep -c "$3" "$2" 2>/dev/null || true)" "$4"
  fi
}

echo "== probe =="
echo "mechanical block only; judgment lines are the skill's"
[ "$HAVE_MANIFEST" = 0 ] && echo "note: no manifest — conventional fallback names in use"
[ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 0 ] && \
  echo "note: jq unavailable — manifest unreadable, every key reads as undeclared"

echo
echo "== tree =="
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "branch: $(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo detached)"
  echo "head: $(git rev-parse --short HEAD 2>/dev/null || echo none)"
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$dirty" = 0 ]; then echo "worktree: clean"; else echo "worktree: dirty ($dirty paths)"; fi
else
  echo "not a git repository — every git-derived line below is unavailable"
fi
echo "lane: ${LANE:-none}"

echo
echo "== records =="
TODO_TYPE="file"
if [ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 1 ]; then
  provider="$(jq -r '.WSS.record.todo | if type == "object" and has("provider") then .provider else empty end' "$MANIFEST" 2>/dev/null)"
  [ -n "$provider" ] && TODO_TYPE="provider:$provider"
fi
if [ "$TODO_TYPE" = "file" ]; then
  count_line "todo" "$(resolve_record todo WSS.TODO.md)" '^[[:space:]]*- \[ \]' "open"
else
  echo "todo: ${TODO_TYPE#provider:} provider — not counted here; count via the provider contract"
fi
count_line "open-decisions" "$(resolve_record openDecisions docs/WSS.OPEN-DECISIONS.md)" '^## ' "entries"

lanes="$(mget '.WSS.lanes.named | keys[]?' '')"
if [ -n "$lanes" ]; then
  echo "lanes declared:"
  while IFS= read -r l; do
    lt="$(mget ".WSS.lanes.named.\"$l\".records.todo" "")"; lt="${lt:-$(mget '.WSS.record.todo' 'WSS.TODO.md')}"
    lo="$(mget ".WSS.lanes.named.\"$l\".records.openDecisions" "")"; lo="${lo:-$(mget '.WSS.record.openDecisions' 'docs/WSS.OPEN-DECISIONS.md')}"
    tn="?"; on="?"
    [ -f "$lt" ] && tn="$(grep -c '^[[:space:]]*- \[ \]' "$lt" 2>/dev/null || true)"
    [ -f "$lo" ] && on="$(grep -c '^## ' "$lo" 2>/dev/null || true)"
    printf '  %s: todo %s open (%s), open-decisions %s (%s)\n' "$l" "$tn" "$lt" "$on" "$lo"
  done <<< "$lanes"
fi

echo
echo "== warnings =="
if [ -x "$INSTALL_ROOT/wss-doctor.sh" ]; then
  doctor_out="$("$INSTALL_ROOT/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
  printf '%s\n' "$doctor_out" | grep '^  FAIL  ' | sed 's/^  FAIL  /doctor FAIL: /' || true
  printf 'doctor result: %s\n' "$(printf '%s\n' "$doctor_out" | tail -1 | sed 's/^  *//')"
else
  echo "doctor: not found at $INSTALL_ROOT — not checked"
fi
count_line "inbox open reports" "$CONFIG_DIR/WSS.BUG-REPORTS.md" '^## \[open\]' ""
count_line "handoff !important blocks" "$(resolve_record handoff CLAUDE.md)" '!important' ""

echo
echo "== sweeps =="
SWEEPS="$(mget '.WSS.sweeps' '.claude/WSS.SWEEPS.json')"
SWEEPS="${SWEEPS:-.claude/WSS.SWEEPS.json}"
if [ ! -f "$SWEEPS" ]; then
  echo "no checkpoint file at $SWEEPS — no sweep has ever run here"
elif [ "$HAVE_JQ" = 0 ]; then
  echo "checkpoint exists at $SWEEPS but jq is unavailable — not read"
else
  jq -r '.entries | to_entries[] | [.key, .value.baseline, (.value.at // "-"), (.value.method // "-"), (.value.result // "")] | @tsv' \
      "$SWEEPS" 2>/dev/null | \
  while IFS=$'\t' read -r name baseline at method result; do
    base="${baseline%+dirty}"
    mark=""; [ "$base" != "$baseline" ] && mark=", dirty at stamp"
    extra=""; [ -n "$result" ] && extra=", result $result"
    ahead="$(git rev-list --count "$base"..HEAD 2>/dev/null)"
    if [ -n "$ahead" ]; then
      printf '%s: baseline %s (%s, %s%s%s) — %s commits behind HEAD\n' \
        "$name" "$base" "$at" "$method" "$mark" "$extra" "$ahead"
    else
      printf '%s: baseline %s is not a commit in this repository — sweep in full\n' "$name" "$baseline"
    fi
  done
  [ -z "$(jq -r '.entries | keys[]?' "$SWEEPS" 2>/dev/null)" ] && echo "checkpoint exists but holds no entries"
fi

echo
echo "== roadmap (goals) =="
# Lane-aware: a lane worktree reports its own goals. Milestones are NOT here —
# a roadmap carries no version and no completion mark, per WSS.RECORD-CONTRACT.md.
ROADMAP="$(resolve_record roadmap WSS.ROADMAP.md)"
if [ -z "$ROADMAP" ]; then
  echo "roadmap: undeclared"
elif [ ! -f "$ROADMAP" ]; then
  echo "roadmap: $ROADMAP — missing"
else
  printf 'roadmap: %s%s\n' "$ROADMAP" "${LANE:+ (lane: $LANE)}"
  awk '
    /^## / {
      g++; goals[g] = substr($0, 4)
      next
    }
    /^[[:space:]]*- \[ \]/ {
      total++
      if (g > 0) {
        open[g]++
        if (firstblock[g] == "") {
          b = $0; sub(/^[[:space:]]*- \[ \][[:space:]]*/, "", b); firstblock[g] = b
        }
      }
    }
    END {
      printf "goals (## headings): %d, open blocks total: %d\n", g + 0, total + 0
      if (g == 0) { print "current: none — no ## headings"; exit }
      cur = 0
      for (i = 1; i <= g; i++) if (open[i] > 0) { cur = i; break }
      if (cur == 0) { print "current: none — every goal has its blocks checked off"; exit }
      printf "current (first goal with open blocks): %s\n", goals[cur]
      printf "  open blocks here: %d\n", open[cur] + 0
      if (firstblock[cur] != "") printf "  next unchecked block: %s\n", firstblock[cur]
      if (cur < g) printf "next after it: %s\n", goals[cur + 1]
    }
  ' "$ROADMAP"
  # Heading-anchored, so a version mentioned in prose is not a finding.
  if grep -qE '^#{1,6} .*(\*completed\*|v?[0-9]+\.[0-9]+\.[0-9]+)' "$ROADMAP"; then
    echo "WARNING: a heading here carries a version or a completion mark — those"
    echo "         belong in WSS.record.releases; wss-doctor.sh fails on it"
  fi
fi

echo
echo "== releases =="
# Never lane-resolved: one release list per project, however many lanes it runs.
RELEASES="$(mget '.WSS.record.releases' 'WSS.RELEASES.md')"
if [ -z "$RELEASES" ]; then
  echo "releases: undeclared"
elif [ ! -f "$RELEASES" ]; then
  echo "releases: $RELEASES — missing"
else
  printf 'releases: %s\n' "$RELEASES"
  awk '
    /^## / {
      m++; title = substr($0, 4)
      miles[m] = title
      comp[m] = (title ~ /\*completed\*/) ? 1 : 0
      if (title ~ /[Mm]aintenance|no (further|more) milestones|end(ed)? milestones/) ended = 1
      next
    }
    END {
      printf "milestones (## headings): %d\n", m + 0
      if (m == 0) { print "current: none — no ## headings"; exit }
      cur = 0
      for (i = 1; i <= m; i++) if (!comp[i]) { cur = i; break }
      if (cur == 0) {
        print "current: none — every milestone is marked completed"
        if (ended) print "  a section reads as an end-of-milestones declaration — --wss-release case 4"
        else print "  and NO end-of-milestones declaration was recognised — --wss-release cannot cut a"
        if (!ended) print "  further release until --wss-plan writes one (its case 4)"
        exit
      }
      printf "current (first not marked completed): %s\n", miles[cur]
      if (cur < m) printf "next after it: %s\n", miles[cur + 1]
    }
  ' "$RELEASES"
fi
