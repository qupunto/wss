#!/usr/bin/env bash
# PostToolUse hook: regenerate .claude/WSS.TOOLS.json when tooling files are edited.
#
# Why this exists. wss-tools-inventory.sh walks the tooling tree and writes
# .claude/WSS.TOOLS.json, the measured inventory. The JSON staleness guard is
# what makes correctness hold — wss-doctor.sh fails if it differs from the
# live tree. But inventories go stale the moment someone writes a new skill or
# agent or hook: they edit the file, the JSON is not regenerated, and
# wss-doctor.sh's --check fails until someone remembers to run the script by hand.
#
# This hook is a convenience layer that keeps discipline from failing. It is
# NOT what makes correctness hold — that is the doctor's `--check`. A hook
# that fires on every write would cost too much (4.2 seconds per write), so
# the prefilter is deliberately allowed to be over-broad: a false positive
# wastes one regeneration; a false negative costs nothing, because the doctor
# is the real guarantee. The bias is toward matching.
#
# ALWAYS exits 0, unconditionally, including on every error path. A hook that
# fails must never block a tool call. SILENT on the no-op path (prefilter does
# not match) — a hook that prints on every write is one the user disables.

# No `trap ... ERR` here on purpose. wss-session-check.sh carries that shape
# and it is a known hazard in this tree: the trap exits 0, so a bare
# `x=$(cmd)` that fails aborts the script before it reaches anything after it.
# Every failure path below is guarded explicitly instead, and the script ends
# in an unconditional `exit 0`.

# Resolves the installation root the way wss-session-check.sh does, exported
# so the child inherits the answer rather than re-deriving it.
export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CLAUDE_DIR="$CLAUDE_CONFIG_DIR"
INSTALLATION_ROOT="${CLAUDE_PLUGIN_ROOT:-$CLAUDE_DIR}"

# Read the hook JSON payload from stdin.
payload=$(cat 2>/dev/null)
file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

[ -n "$file_path" ] || exit 0

# Anchor to this installation FIRST. A file outside it cannot be one of this
# suite's tooling files whatever it is named, and the directory names below
# are not distinctive: `tests/` and `hooks/` occur in most projects, so an
# unanchored match puts a 4-second regeneration on writes that have nothing
# to do with the suite. Measured: an unanchored prefilter cost 4.3s on
# `<some project>/tests/foo.test.js`. Anchoring is not the over-broad part.
case "$file_path" in
  "$INSTALLATION_ROOT"/*) rel=${file_path#"$INSTALLATION_ROOT"/} ;;
  "$CLAUDE_DIR"/*)        rel=${file_path#"$CLAUDE_DIR"/} ;;
  *) exit 0 ;;
esac

# Cheap path prefilter, within this installation only: skills/, agents/,
# wss/workflow/, commands/, hooks/, wss/tests/ (wss-doctor.sh and the
# check-method files live there since the reorg), or any other wss-*.sh
# under wss/scripts/.
# THIS part is deliberately allowed to be over-broad — a false positive costs
# one 4.2-second regeneration; a false negative costs nothing, because
# wss-doctor.sh's --check is the real guarantee. Bias toward matching, and do
# not "tighten" it into a correctness dependency it was never meant to be.
case "$rel" in
  skills/*|agents/*|wss/workflow/*|commands/*|hooks/*|wss/tests/*)
    : # Match
    ;;
  wss-*.sh|wss/scripts/wss-*.sh)
    : # Match
    ;;
  *)
    # No match: prefilter did not trigger, exit silently
    exit 0
    ;;
esac

# On a match, regenerate synchronously by running this installation's own
# wss-tools-inventory.sh. Do not background it — a write racing the doctor's
# --check is the failure this design is avoiding.
if [ -x "$INSTALLATION_ROOT/wss/scripts/wss-tools-inventory.sh" ]; then
  bash "$INSTALLATION_ROOT/wss/scripts/wss-tools-inventory.sh" >/dev/null 2>&1 || true
fi

exit 0
