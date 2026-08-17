#!/usr/bin/env bash
# Regenerates WSS.record.decisionsIndex from WSS.record.decisions — one row per `## `
# entry: the line it starts at, and its heading. Append-only means old entries
# keep their line numbers, so a row goes stale only when the log's preamble
# changes, and a regen fixes it.
#
# Declared in .claude/WSS.WORKFLOW.json as WSS.commands.indexRegen; `--check` verifies
# without writing, for callers that write nothing (WSS.commands.indexCheck).
# Run from the project directory. Both paths resolve from the manifest;
# WSS.record.decisionsIndex has deliberately no fallback (wss/workflow/WSS.MANIFEST.md), so
# an undeclared index is an error here rather than a guessed filename.
set -euo pipefail

manifest=".claude/WSS.WORKFLOW.json"
log="wss/logs/WSS.DECISIONS.md"
index=""
if [ -f "$manifest" ] && command -v jq >/dev/null 2>&1; then
  log=$(jq -r '.WSS.record.decisions // "wss/logs/WSS.DECISIONS.md"' "$manifest")
  index=$(jq -r '.WSS.record.decisionsIndex // empty' "$manifest")
fi
[ -n "$index" ] || {
  echo "wss-index-decisions.sh: WSS.record.decisionsIndex is not declared — nothing to write" >&2
  exit 1
}
[ -f "$log" ] || {
  echo "wss-index-decisions.sh: $log not found" >&2
  exit 1
}

render() {
  printf '# Decisions index\n\n'
  printf 'Generated from `%s` by `WSS.commands.indexRegen` — never hand-edit.\n' "$log"
  printf 'One row per entry: the line it starts at, and its heading.\n\n'
  # A log with no `## ` entries is an ordinary state, not a failure: that is
  # exactly what wss-reset-records.sh and wss-publish.sh leave behind, and its
  # index is legitimately header-only. But `grep` exits 1 on no match, `pipefail`
  # hands that to the pipeline, and this function is called PLAINLY at
  # `render >"$index"` — so `set -e` killed the run there with the index already
  # truncated by the redirect: exit 1, no rows, and not one word about why. The
  # same shape as wss-scaffold.sh's declared_root, which is where it was found.
  #
  # A no-match must therefore be swallowed and a REAL grep failure must not:
  # grep exits 1 on no match and 2 or more on an unreadable file, so the two are
  # distinguishable and only the second is worth dying for. Assigning first makes
  # the status readable — piping straight into sed would put sed's status last.
  local rows rc=0
  rows=$(grep -n '^## ' "$log") || rc=$?
  if [ "$rc" -gt 1 ]; then
    echo "wss-index-decisions.sh: cannot read $log (grep exited $rc)" >&2
    return 1
  fi
  [ -z "$rows" ] || printf '%s\n' "$rows" | sed -E 's|^([0-9]+):## |- L\1 — |'
}

if [ "${1:-}" = "--check" ]; then
  [ -f "$index" ] || {
    echo "index STALE: $index does not exist — run WSS.commands.indexRegen" >&2
    exit 1
  }
  # Rendered to a file rather than compared through `diff <(render)`: a process
  # substitution is a subshell, so a `return 1` from render there reaches nothing
  # and diff simply reports a difference — "index STALE" for a log that is not
  # stale at all. Written plainly, `set -e` stops on it and render's own message
  # is the last thing printed.
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  render >"$tmp"
  if diff "$tmp" "$index" >/dev/null; then
    echo "index current: $index matches $log"
  else
    echo "index STALE: $index does not match $log — run WSS.commands.indexRegen" >&2
    exit 1
  fi
else
  # Same temp file, for the other half of the reason: `render >"$index"` truncates
  # the index before render runs, so a render that fails leaves a header and no
  # rows where the real index used to be. Rendered aside and moved into place, a
  # failure costs nothing. `grep -c` prints 0 and exits 1 on an entry-less index;
  # that status is an argument to echo rather than the command's own, so it never
  # reaches errexit, and the count it prints is right either way.
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  render >"$tmp"
  cat "$tmp" >"$index"   # not `mv`: mktemp's 0600 would follow the file across
  echo "wrote $index ($(grep -c '^- ' "$index") entries)"
fi
