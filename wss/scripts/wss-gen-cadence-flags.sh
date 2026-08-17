#!/usr/bin/env bash
# Regenerates the derived copy of the Flag column in the "How often" table
# inside README.md from its canon — the same column in the "| When | Flag |"
# table from skills/adopt/SKILL.md's cadence card. This generator
# reproduces the flag list for comparison and must never write it, because
# README.md is a declared record (WSS.record.reference) with a sole writer
# (reference-writer), and a second writer to a record violates the
# WSS.RECORD-CONTRACT.md rule.
#
#   bash wss/scripts/wss-gen-cadence-flags.sh          # extract and compare, exit 0 on match
#   bash wss/scripts/wss-gen-cadence-flags.sh --check  # same as above
#
# Exit 0 on match, exit 1 on drift, exit 2 on argument error or refusal.
set -euo pipefail
export LC_ALL=C

SUITE_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
CANON="$SUITE_ROOT/skills/adopt/SKILL.md"
TARGET="$SUITE_ROOT/README.md"
REGEN="bash wss/scripts/wss-gen-cadence-flags.sh"

CHECK=0
while [ $# -gt 0 ]; do
  case $1 in
    --check) CHECK=1; shift ;;
    --write)
      echo "wss-gen-cadence-flags.sh: --write refused: README.md is a declared record (WSS.record.reference) whose sole writer is reference-writer. This generator reproduces the Flag column for comparison only and must never write it, because a second writer to a record violates the WSS.RECORD-CONTRACT.md rule on derived copies." >&2
      exit 2
      ;;
    *) echo "wss-gen-cadence-flags.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

cadence_flags_() { # file -> the flag column of the "| When | Flag |" table
  awk '
    /^\|[[:space:]]*When[[:space:]]*\|[[:space:]]*Flag[[:space:]]*\|/ { t = 1; next }
    t && /^\|[[:space:]]*[-:]/ { next }
    t && /^\|/ {
      n = split($0, f, "|")
      if (n >= 3 && match(f[3], /--wss-[a-z-]+/))
        print substr(f[3], RSTART, RLENGTH)
      next
    }
    t { t = 0 }
  ' "$1" | sort
}

[ -f "$CANON" ] || {
  echo "wss-gen-cadence-flags.sh: ${CANON#"$SUITE_ROOT"/} does not exist" >&2
  exit 1
}

[ -f "$TARGET" ] || {
  echo "wss-gen-cadence-flags.sh: ${TARGET#"$SUITE_ROOT"/} does not exist" >&2
  exit 1
}

canon_flags=$(cadence_flags_ "$CANON")
target_flags=$(cadence_flags_ "$TARGET")

if [ "$canon_flags" = "$target_flags" ]; then
  echo "README.md's cadence flag column current, matches ${CANON#"$SUITE_ROOT"/}"
  exit 0
else
  {
    echo "README.md's cadence flag column STALE — does not match ${CANON#"$SUITE_ROOT"/} — run $REGEN"
    echo ""
    echo "Flags in card but not in README:"
    comm -23 <(printf '%s\n' "$canon_flags") <(printf '%s\n' "$target_flags") || true
    echo ""
    echo "Flags in README but not in card:"
    comm -13 <(printf '%s\n' "$canon_flags") <(printf '%s\n' "$target_flags") || true
  } >&2
  exit 1
fi
