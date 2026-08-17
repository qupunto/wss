#!/usr/bin/env bash
# wss-orient.sh — the deterministic half of --wss-start Phase 0, in one
# read-only call.
#
# Emits: the tree pin (branch, HEAD, dirty paths, commits on the integration
# branch not yet on its origin remote), the CI result where the manifest
# names a workflow, and the mechanical facts about the three planning
# records plus the decisions index — resolved path, existence, size in
# bytes, and (openDecisions only) how many `## ` entries it holds, per
# WSS.RECORD-CONTRACT.md's one-heading-per-entry rule. Sweep freshness is
# delegated to wss-sweep-distance.sh rather than recomputed here —
# skills/overview/assets/wss-sweep-distance.sh is the one
# implementation, already shared between --wss-overview and --wss-wrap.
#
# It reports facts, never their meaning. SKILL.md's Phase 0 step 3 is
# explicit that a summary of the three planning records cannot be
# partitioned into lanes, so this script never reads their CONTENTS and
# cannot substitute for reading them directly. It also does not run the
# lane sync-forward / transfer-queue drain (references/WSS.LANES.md) or
# create the task list (--wss-track) — both need judgment this script does
# not have.
#
#   wss-orient.sh
#
# Run it from the project directory being started in. Read-only except for
# one narrow exception: the CI section, which only fires when the manifest
# names a workflow, and degrades to "not checked" rather than a false zero
# when the tool is missing or the query fails — the rule wss-probe.sh and
# wss-wrap-status.sh both already follow for external state.

set -u

INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MANIFEST=".claude/WSS.WORKFLOW.json"
HAVE_JQ=1; command -v jq >/dev/null 2>&1 || HAVE_JQ=0
HAVE_MANIFEST=0; [ -f "$MANIFEST" ] && HAVE_MANIFEST=1
# A manifest that exists but is not valid JSON is unreadable, same as jq
# being missing — matches wss-docs-audit.sh's own manifest-validity check.
MANIFEST_INVALID=0
if [ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 1 ] && ! jq empty "$MANIFEST" >/dev/null 2>&1; then
  MANIFEST_INVALID=1
  HAVE_JQ=0
fi

# With a manifest, an undeclared key is reported "undeclared" — no fallback.
# With no manifest at all, the conventional names from wss/workflow/WSS.MANIFEST.md
# apply. A manifest that exists but cannot be read — jq missing, or the file
# is not valid JSON — is unreadable rather than merely undeclared: every key
# still reads as "undeclared", but a note says why, for either cause. Same
# manifest-validity guard as wss-docs-audit.sh, and the same `mget` shape as
# wss-probe.sh and wss-wrap-status.sh — one behaviour, not a fourth copy of it.
mget() { # mget <jq-path> <fallback-with-no-manifest>
  if [ "$HAVE_MANIFEST" = 1 ]; then
    [ "$HAVE_JQ" = 1 ] && jq -r "$1 // empty" "$MANIFEST" 2>/dev/null || true
  else
    printf '%s\n' "$2"
  fi
}

LANE=""
[ -f .claude/WSS.LANE ] && LANE="$(head -1 .claude/WSS.LANE 2>/dev/null | tr -d '[:space:]' || true)"

resolve_record() { # resolve_record <key> <fallback> — lane-aware per WSS.MANIFEST.md
  local path override
  path="$(mget ".WSS.record.$1" "$2")"
  if [ -n "$LANE" ]; then
    override="$(mget ".WSS.lanes.named.\"$LANE\".records.$1" "")"
    [ -n "$override" ] && path="$override"
  fi
  printf '%s\n' "$path"
}

echo "== wss-orient: Phase 0 mechanical state =="
[ "$HAVE_MANIFEST" = 0 ] && echo "note: no manifest — conventional fallback names in use"
if [ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 0 ]; then
  if [ "$MANIFEST_INVALID" = 1 ]; then
    echo "note: $MANIFEST is not valid JSON — manifest unreadable, every key reads as undeclared"
  else
    echo "note: jq unavailable — manifest unreadable, every key reads as undeclared"
  fi
fi
echo "lane: ${LANE:-none}"

echo
echo "== tree =="
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "branch: $(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo detached)"
  echo "head: $(git rev-parse --short HEAD 2>/dev/null || echo none)"
  dirty="$(git status --porcelain 2>/dev/null || true)"
  n_dirty="$(printf '%s\n' "$dirty" | grep -c . || true)"
  if [ -z "$dirty" ]; then
    echo "worktree: clean"
  else
    echo "worktree: dirty ($n_dirty paths)"
    printf '%s\n' "$dirty" | sed 's/^/  /'
  fi

  integration="$(mget '.WSS.branch.integration' 'main')"
  if [ -z "$integration" ]; then
    echo "unpushed: not checked — branch.integration undeclared"
  elif ! git rev-parse --verify -q "origin/$integration" >/dev/null 2>&1; then
    echo "unpushed on $integration: origin/$integration not found — not checked"
  else
    unpushed="$(git log "origin/$integration..$integration" --oneline 2>/dev/null || true)"
    if [ -z "$unpushed" ]; then
      echo "unpushed on $integration: none"
    else
      n_unpushed="$(printf '%s\n' "$unpushed" | grep -c . || true)"
      echo "unpushed on $integration: $n_unpushed commit(s)"
      printf '%s\n' "$unpushed" | sed 's/^/  /'
    fi
  fi
else
  echo "not a git repository — every git-derived line above is unavailable"
fi

echo
echo "== CI =="
ci_tool="$(mget '.WSS.commands.ci.tool' '')"
ci_workflow="$(mget '.WSS.commands.ci.workflow' '')"
if [ -z "$ci_tool" ] || [ -z "$ci_workflow" ]; then
  echo "ci: undeclared — nothing to check"
elif [ "$ci_tool" != gh ]; then
  echo "ci: $ci_workflow declared via '$ci_tool' — only 'gh' is understood here, not checked"
elif ! command -v gh >/dev/null 2>&1; then
  echo "ci: $ci_workflow — gh not available, not checked"
else
  status_line="$(gh run list --workflow "$ci_workflow" --limit 1 \
    --json status,conclusion,headSha \
    --jq '.[0] | "\(.status)/\(.conclusion // "-") at \(.headSha)"' 2>/dev/null || true)"
  if [ -z "$status_line" ]; then
    echo "ci: $ci_workflow — gh query returned nothing (offline, unauthenticated, or no runs), not checked"
  else
    echo "ci: $ci_workflow — latest run: $status_line"
  fi
fi

echo
echo "== planning records =="
# openDecisions, todo, roadmap — the three the table at the top of SKILL.md
# names. Mechanical facts only: path, existence, size, and (openDecisions
# only) its entry count. Never the content.
for key in openDecisions todo roadmap; do
  case $key in
    openDecisions) fallback=wss/records/WSS.OPEN-DECISIONS.md ;;
    todo) fallback=wss/records/WSS.TODO.md ;;
    roadmap) fallback=wss/records/WSS.ROADMAP.md ;;
  esac
  path="$(resolve_record "$key" "$fallback")"
  if [ -z "$path" ]; then
    echo "$key: undeclared"
    continue
  fi
  # A provider-backed todo has no file for this script to measure.
  if [ "$key" = todo ] && [ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 1 ]; then
    provider="$(jq -r '.WSS.record.todo | if type == "object" and has("provider") then .provider else empty end' "$MANIFEST" 2>/dev/null || true)"
    if [ -n "$provider" ]; then
      echo "todo: $provider provider — no file to measure, read via the provider contract"
      continue
    fi
  fi
  if [ ! -f "$path" ]; then
    echo "$key: $path — missing"
    continue
  fi
  size="$(wc -c < "$path" 2>/dev/null | tr -d ' ' || true)"
  if [ "$key" = openDecisions ]; then
    entries="$(grep -c '^## ' "$path" 2>/dev/null || true)"
    echo "$key: $path — ${size:-0}B, ${entries:-0} entries"
  else
    echo "$key: $path — ${size:-0}B"
  fi
done

decisions_index="$(mget '.WSS.record.decisionsIndex' 'wss/generated/WSS.DECISIONS-INDEX.md')"
if [ -z "$decisions_index" ]; then
  echo "decisionsIndex: undeclared"
elif [ ! -f "$decisions_index" ]; then
  echo "decisionsIndex: $decisions_index — missing"
else
  size="$(wc -c < "$decisions_index" 2>/dev/null | tr -d ' ' || true)"
  echo "decisionsIndex: $decisions_index — ${size:-0}B"
fi

echo
echo "== sweeps =="
# One implementation, not a fourth copy: skills/overview/assets/wss-sweep-distance.sh
# is what --wss-overview and --wss-wrap already call. This composes it rather
# than recomputing sweep freshness a new way.
DISTANCE="$INSTALL_ROOT/skills/overview/assets/wss-sweep-distance.sh"
if [ -f "$DISTANCE" ]; then
  bash "$DISTANCE" --verbose
else
  echo "wss-sweep-distance.sh not found at $DISTANCE — sweep freshness not read"
fi
