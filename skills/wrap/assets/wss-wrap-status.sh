#!/usr/bin/env bash
# wss-wrap-status.sh — one read-only call replacing --wss-wrap step 6's read
# and step 7 entirely.
#
# Emits: dirty files, unpushed commits, ahead-of-publish, the four record
# counts (todo / open-decisions / roadmap open blocks / milestones
# outstanding), open-decision titles, the next unchecked roadmap block, every
# roadmap goal whose blocks are ALL checked (`goal-closed:`  — every such
# goal, not just the one before the current open goal: which goal a release
# milestone cites is prose, decided by the step that reads this line, not by
# file order here — see skills/wrap/SKILL.md step 6), the sweep line
# (delegated to wss-sweep-distance.sh --compact — the single implementation,
# never reimplemented here), and the always-on-bytes delta against the last
# wrap's stamp.
#
#   wss-wrap-status.sh
#
# Run it from the project directory. Read-only and offline except for one
# narrow exception: it reads the manifest, git and the records, and writes,
# stages, commits, pushes or advances nothing EXCEPT its own
# .claude/WSS.ALWAYS-ON-STAMP.json, a sibling of the sweep checkpoint that
# this script alone owns (WSS.SWEEPS.json stays sweep-tracker's, untouched
# here). The one network call — the TODO list provider branch below — fails
# soft: a gh error is reported as "not counted", never folded into a zero,
# matching wss-probe.sh's rule that external state offline is not the same
# fact as external state at zero.

set -u

MANIFEST=".claude/WSS.WORKFLOW.json"
HAVE_JQ=1; command -v jq >/dev/null 2>&1 || HAVE_JQ=0
HAVE_MANIFEST=0; [ -f "$MANIFEST" ] && HAVE_MANIFEST=1

# With a manifest, an undeclared key is reported "undeclared" — no fallback.
# With no manifest at all, the conventional names from wss/workflow/WSS.MANIFEST.md
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

echo "== wss-wrap-status =="
[ "$HAVE_MANIFEST" = 0 ] && echo "note: no manifest — conventional fallback names in use"
[ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 0 ] && \
  echo "note: jq unavailable — manifest unreadable, every key reads as undeclared"
echo "lane: ${LANE:-none}"

echo
echo "== tree =="
if git rev-parse --git-dir >/dev/null 2>&1; then
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "dirty: $dirty"

  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo '')"
  if [ -z "$branch" ]; then
    echo "unpushed: detached HEAD — not checked"
  elif ! git rev-parse --verify -q "${branch}@{u}" >/dev/null 2>&1; then
    echo "unpushed ($branch): no upstream tracking branch"
  else
    up="$(git rev-list --count "${branch}@{u}..HEAD" 2>/dev/null)"
    echo "unpushed ($branch): ${up:-not checked}"
  fi

  INTEG="$(mget '.WSS.branch.integration' '')"
  PUBLISH="$(mget '.WSS.branch.publish' '')"
  resolve_ref() { # resolve_ref <branch> — prefer the remote-tracking copy
    if git rev-parse --verify -q "origin/$1" >/dev/null 2>&1; then
      printf 'origin/%s\n' "$1"
    elif git rev-parse --verify -q "$1" >/dev/null 2>&1; then
      printf '%s\n' "$1"
    fi
  }
  if [ -z "$INTEG" ] || [ -z "$PUBLISH" ]; then
    echo "ahead-of-publish: not checked — branch.integration/branch.publish undeclared"
  else
    ir="$(resolve_ref "$INTEG")"; pr="$(resolve_ref "$PUBLISH")"
    if [ -z "$ir" ] || [ -z "$pr" ]; then
      echo "ahead-of-publish: not checked — no ref for $INTEG or $PUBLISH"
    else
      n="$(git rev-list --count "$pr..$ir" 2>/dev/null)"
      echo "ahead-of-publish ($INTEG vs $PUBLISH): ${n:-not checked}"
    fi
  fi
else
  echo "not a git repository — every git-derived line above is unavailable"
fi

# --- todo: file or provider (absorbs the gh/jq branch out of the SKILL) ---
TODO_TYPE="file"
PROVIDER_REPO=""; PROVIDER_LABEL=""
if [ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 1 ]; then
  provider="$(jq -r '.WSS.record.todo | if type == "object" and has("provider") then .provider else empty end' "$MANIFEST" 2>/dev/null)"
  if [ -n "$provider" ]; then
    TODO_TYPE="provider:$provider"
    PROVIDER_REPO="$(jq -r '.WSS.record.todo.repo // empty' "$MANIFEST" 2>/dev/null)"
    PROVIDER_LABEL="$(jq -r '.WSS.record.todo.label // empty' "$MANIFEST" 2>/dev/null)"
  fi
fi

TODO_N=""; TODO_NOTE=""
if [ "$TODO_TYPE" = "file" ]; then
  TODO_PATH="$(resolve_record todo wss/records/WSS.TODO.md)"
  if [ -z "$TODO_PATH" ]; then
    TODO_NOTE="undeclared"
  elif [ ! -f "$TODO_PATH" ]; then
    TODO_NOTE="missing $TODO_PATH"
  else
    TODO_N="$(grep -c '^[[:space:]]*- \[ \]' "$TODO_PATH" 2>/dev/null || true)"
  fi
else
  # Client-side filter, never --label — this is the read-after-write case
  # WSS.GITHUB-ISSUES.md calls out: step 7 runs right after step 5's commit,
  # which may have just closed issues --label's search index has not caught
  # up to yet.
  if ! command -v gh >/dev/null 2>&1; then
    TODO_NOTE="${provider} provider — gh not found, not counted"
  elif [ -z "$PROVIDER_REPO" ]; then
    TODO_NOTE="${provider} provider — repo undeclared in manifest, drift"
  else
    if RAW="$(gh issue list --repo "$PROVIDER_REPO" --state open --limit 500 \
                --json number,labels 2>/dev/null)"; then
      cnt_and_len="$(printf '%s' "$RAW" | jq -r --arg L "$PROVIDER_LABEL" \
        '[.[] | select($L == "" or (.labels
           | any((.name | ascii_downcase) == ($L | ascii_downcase))))] as $m
         | "\($m | length) \(. | length)"' 2>/dev/null)"
      if [ -z "$cnt_and_len" ]; then
        TODO_NOTE="${provider} provider ($PROVIDER_REPO) — response unreadable, not counted"
      else
        TODO_N="${cnt_and_len%% *}"
        total="${cnt_and_len##* }"
        [ "$total" = 500 ] && TODO_NOTE="at the 500 ceiling — may be truncated, raise --limit"
      fi
    else
      TODO_NOTE="${provider} provider ($PROVIDER_REPO) — gh call failed, not counted"
    fi
  fi
fi

echo
echo "== counts =="
if [ -n "$TODO_N" ]; then
  line="todo=$TODO_N"
else
  line="todo=?($TODO_NOTE)"
fi

OD_PATH="$(resolve_record openDecisions wss/records/WSS.OPEN-DECISIONS.md)"
OD_N=""
if [ -z "$OD_PATH" ]; then
  line="$line decisions=?(undeclared)"
elif [ ! -f "$OD_PATH" ]; then
  line="$line decisions=?(missing $OD_PATH)"
else
  OD_N="$(grep -c '^## ' "$OD_PATH" 2>/dev/null || true)"
  line="$line decisions=$OD_N"
fi

ROADMAP="$(resolve_record roadmap wss/records/WSS.ROADMAP.md)"
RM_SUMMARY=""
if [ -z "$ROADMAP" ]; then
  line="$line roadmap-open=?(undeclared)"
elif [ ! -f "$ROADMAP" ]; then
  line="$line roadmap-open=?(missing $ROADMAP)"
else
  # Line 4 (goal-closed) is EVERY goal whose blocks are all checked, not the
  # goal immediately before the first open one — that positional reading is a
  # constant of the roadmap's layout, not an event, and cannot report a goal
  # that closes while an earlier goal is still open. "Closed" requires at
  # least one `- [x]` in the goal, so a goal with no checkboxes at all (never
  # started) does not count as closed by vacuous truth. Which closed goal a
  # release milestone cites is left to the step that consumes this line
  # (skills/wrap/SKILL.md step 6), not decided here — this script only
  # reports the roadmap's state.
  RM_SUMMARY="$(awk '
    /^## / { g++; goals[g] = substr($0, 4); next }
    /^[[:space:]]*- \[ \]/ {
      total++
      if (g > 0) {
        open[g]++
        if (firstblock[g] == "") {
          b = $0; sub(/^[[:space:]]*- \[ \][[:space:]]*/, "", b); firstblock[g] = b
        }
      }
    }
    /^[[:space:]]*- \[[xX]\]/ { if (g > 0) closed[g]++ }
    END {
      if (g == 0) { print "0" ; print "none — no ## headings"; print ""; print "none"; exit }
      cur = 0
      for (i = 1; i <= g; i++) if (open[i] > 0) { cur = i; break }
      closed_list = ""
      closed_n = 0
      for (i = 1; i <= g; i++) {
        if (open[i] + 0 == 0 && closed[i] + 0 > 0) {
          closed_n++
          closed_list = (closed_list == "") ? goals[i] : closed_list " | " goals[i]
        }
      }
      # Bare "none" (no explanatory suffix) on purpose: this is the one
      # value on this line a caller could plausibly still match exactly,
      # matching the old single-goal lines "none" case.
      if (closed_n == 0) closed_list = "none"
      if (cur == 0) {
        print "0"
        printf "none — every goal closed\n"
        print ""
        print closed_list
        exit
      }
      print open[cur] + 0
      printf "%s — %d open blocks\n", goals[cur], open[cur] + 0
      print firstblock[cur]
      print closed_list
    }
  ' "$ROADMAP")"
  rm_open="$(printf '%s\n' "$RM_SUMMARY" | sed -n 1p)"
  line="$line roadmap-open=$rm_open"
fi

RELEASES="$(mget '.WSS.record.releases' 'wss/records/WSS.RELEASES.md')"
if [ -z "$RELEASES" ]; then
  line="$line milestones=?(undeclared)"
elif [ ! -f "$RELEASES" ]; then
  line="$line milestones=?(missing $RELEASES)"
else
  rel_out="$(awk '
    /^## / {
      t = substr($0, 4)
      if (t ~ /\*end of milestones\*/) { ended = 1; next }
      m++
      comp[m] = (t ~ /\*completed\*/) ? 1 : 0
      next
    }
    END {
      out = 0
      for (i = 1; i <= m; i++) if (!comp[i]) out++
      print out
      if (out == 0 && ended) print "end-of-milestones declared"
    }
  ' "$RELEASES")"
  rel_n="$(printf '%s\n' "$rel_out" | sed -n 1p)"
  rel_note="$(printf '%s\n' "$rel_out" | sed -n 2p)"
  line="$line milestones=$rel_n${rel_note:+ ($rel_note)}"
fi
echo "$line"

echo
echo "== open-decision titles =="
if [ -n "$OD_PATH" ] && [ -f "$OD_PATH" ]; then
  if [ -z "$OD_N" ] || [ "$OD_N" = 0 ]; then
    echo "none"
  else
    grep '^## ' "$OD_PATH" | sed 's/^## //' | head -20
    [ "$OD_N" -gt 20 ] && echo "...and $((OD_N - 20)) more"
  fi
else
  echo "not read — $OD_PATH"
fi

echo
echo "== roadmap =="
if [ -n "$ROADMAP" ] && [ -f "$ROADMAP" ]; then
  printf 'roadmap: %s%s\n' "$ROADMAP" "${LANE:+ (lane: $LANE)}"
  printf 'current: %s\n' "$(printf '%s\n' "$RM_SUMMARY" | sed -n 2p)"
  nb="$(printf '%s\n' "$RM_SUMMARY" | sed -n 3p)"
  [ -n "$nb" ] && printf 'next unchecked block: %s\n' "$nb"
  printf 'goal-closed: %s\n' "$(printf '%s\n' "$RM_SUMMARY" | sed -n 4p)"
else
  echo "roadmap: ${ROADMAP:-undeclared}${ROADMAP:+ — missing}"
fi

echo
echo "== sweep =="
DIST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../overview/assets" 2>/dev/null && pwd)"
if [ -n "$DIST_DIR" ] && [ -f "$DIST_DIR/wss-sweep-distance.sh" ]; then
  bash "$DIST_DIR/wss-sweep-distance.sh" --compact
else
  echo "wss-sweep-distance.sh not found beside the installation — sweep line not read"
fi

# --- always-on bytes: CLAUDE.md + visible skill descriptions + handoff card.
#
# Delegated to wss-audit-assets.sh's --always-on-basis flag — the single
# implementation of what counts as always-on (CLAUDE.md bytes + loaded skill
# description bytes + the handoff card), never mirrored here a second time.
# Discovered the same way wss-sweep-distance.sh is discovered above: resolved
# relative to this script's own location, with the same not-found message
# shape when it is not found beside the installation. wss-audit-assets.sh
# lives under the installation's wss/scripts/ rather than beside a sibling
# skill, so the relative path differs, but the idiom — cd-and-pwd a candidate directory, test -f the
# target inside it, degrade gracefully to a one-line note if absent — is the
# same one used for wss-sweep-distance.sh above, not a second one invented
# here. The flag itself skips wss-audit-assets.sh's "Mechanical floor"
# section (./wss-doctor.sh + the full contract suite), which would otherwise
# turn every --wss-wrap into a full test run — directly at odds with this
# script's read-only/offline/fast contract above.
#
# Stamped in .claude/WSS.ALWAYS-ON-STAMP.json, a sibling of the sweep
# checkpoint (.claude/WSS.SWEEPS.json) that this script owns outright — never
# a new key in WSS.SWEEPS.json itself, which is sweep-tracker's alone, and
# whose `entries[].baseline` is a commit sha, not a byte count; folding a
# byte-count baseline into that shape would make wss-sweep-distance.sh, which
# walks every entry generically, try to resolve it as a commit and report
# "no such commit". Read and written with grep/sed, not jq: the file's shape
# is fixed and fully controlled by this script, so it carries no new
# dependency the rest of this script does not already tolerate missing.
ALWAYS_ON_STAMP=".claude/WSS.ALWAYS-ON-STAMP.json"

AUDIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../wss/scripts" 2>/dev/null && pwd)"
basis_total=""
if [ -n "$AUDIT_DIR" ] && [ -f "$AUDIT_DIR/wss-audit-assets.sh" ]; then
  # --root "$PWD": this script runs from inside the project it reports on
  # ("Run it from the project directory", above), but wss-audit-assets.sh
  # itself lives under the suite install's wss/scripts/, which is a different directory
  # under a plugin install. Without --root, --always-on-basis measured
  # wherever it happened to live instead of the project calling it.
  basis_total="$(bash "$AUDIT_DIR/wss-audit-assets.sh" --always-on-basis --root "$PWD" 2>/dev/null)"
  case "$basis_total" in *[!0-9]*|'') basis_total="" ;; esac
fi

if [ -z "$basis_total" ]; then
  echo "wss-audit-assets.sh not found under the installation's wss/scripts/ — always-on line not read"
else
  prev_bytes=""; prev_at=""
  if [ -f "$ALWAYS_ON_STAMP" ]; then
    prev_bytes="$(grep -o '"bytes"[[:space:]]*:[[:space:]]*[0-9]\+' "$ALWAYS_ON_STAMP" 2>/dev/null \
      | grep -o '[0-9]\+$')"
    prev_at="$(grep -o '"at"[[:space:]]*:[[:space:]]*"[^"]*"' "$ALWAYS_ON_STAMP" 2>/dev/null \
      | sed -E 's/.*"([^"]*)"$/\1/')"
  fi

  if [ -z "$prev_bytes" ]; then
    echo "always-on: ${basis_total} B (no prior stamp — baseline written)"
  else
    delta=$((basis_total - prev_bytes))
    if [ "$delta" -gt 0 ]; then
      dtxt="+${delta} B since ${prev_at:-unknown} stamp"
    elif [ "$delta" -lt 0 ]; then
      dtxt="${delta} B since ${prev_at:-unknown} stamp"
    else
      dtxt="no change since ${prev_at:-unknown} stamp"
    fi
    echo "always-on: ${basis_total} B (${dtxt})"
  fi

  stamp_sha="$(git rev-parse --short HEAD 2>/dev/null)"
  stamp_date="$(date +%Y-%m-%d)"
  mkdir -p "$(dirname "$ALWAYS_ON_STAMP")" 2>/dev/null
  printf '{\n  "bytes": %s,\n  "at": "%s",\n  "sha": "%s"\n}\n' \
    "$basis_total" "$stamp_date" "${stamp_sha:-unknown}" > "$ALWAYS_ON_STAMP" 2>/dev/null
fi

exit 0
