#!/usr/bin/env bash
#
# Strip the rows from an adopted rulebook, keeping every file and every
# structural section — the "structure only" half of the adoption choice.
#
#   ./wss-rules-truncate.sh            # show what would be stripped, change nothing
#   ./wss-rules-truncate.sh --write    # do it
#   ./wss-rules-truncate.sh --write --dir /path/to/project
#
# WHY THIS EXISTS. The rulebook ships to adopters as written — the owner's
# ruling — and the choice of whether to inherit those rules moves to adoption
# rather than to publication. An adopter who wants them takes them as is; one
# who does not takes the structure only, and this is what "structure only"
# means mechanically.
#
# WHAT "STRUCTURE ONLY" IS, AND WHY IT IS NOT AN EMPTY FILE. Every one of the
# rulebook's files survives, and so does every section that is not a row:
# `wss-rules-checkup.sh` resolves a consumer against the index's consumer table
# and then checks that each file it names EXISTS, so deleting a file breaks
# every consumer that names it. Only row blocks go. The result validates on
# arrival and is ready to receive the adopter's first row — which an empty stub
# that fails the checkup until they write one would not be.
#
# WHY IT IS NOT PART OF wss-reset-records.sh. That script blanks a record to a
# heading, reads only the SHIPPED manifest, and guards on `type == "string"`.
# `WSS.record.rules` is an ARRAY and lives in `.claude/WSS.LOCAL-RECORDS.json`,
# which `wss-publish.sh` deletes before Gate 2 — so an adopter's checkout has no
# manifest key that could reach the rulebook at all. Widening the type guard
# would buy nothing, and "overwrite with one heading" is the wrong shape here.
#
# A ROW IS `### <ID>` AND WHAT FOLLOWS IT. The id grammar is the row schema's:
# a domain prefix, the judge segment, and a zero-padded sequence. A heading that
# does not match that shape is a section, and sections stay.
#
# FENCED BLOCKS ARE SKIPPED. The index illustrates the row format inside a
# ```markdown block; a scan that counts it would strip the schema's own worked
# example out of the document that defines it.

set -euo pipefail

WRITE=0
DIR="."
while [ $# -gt 0 ]; do
  case "$1" in
    --write) WRITE=1 ;;
    --dir)   [ $# -ge 2 ] || { echo "wss-rules-truncate.sh: --dir needs a path" >&2; exit 2; }
             DIR="$2"; shift ;;
    *) echo "wss-rules-truncate.sh: unrecognised argument: $1" >&2; exit 2 ;;
  esac
  shift
done

RULES_DIR="$DIR/wss/rules"
INDEX="$RULES_DIR/WSS.RULES-INDEX.md"
[ -d "$RULES_DIR" ] || { echo "wss-rules-truncate.sh: no wss/rules/ under $DIR — nothing to truncate" >&2; exit 1; }
[ -f "$INDEX" ] || { echo "wss-rules-truncate.sh: no WSS.RULES-INDEX.md — the file list comes from its consumer table" >&2; exit 1; }

# THE FILE LIST IS THE DIRECTORY, not a path list kept here and not the index's
# consumer table. Avoiding a hardcoded list was the point, and a glob avoids it
# too — with the difference that a glob is COMPLETE. The consumer table names
# five consumers resolving to eight files; `WSS.RULES-HOOK.md` and five of the
# six `prospective/` files are named by no consumer at all, so a table-driven
# list would leave their rows behind. Harmless today, because those files carry
# no rows — and exactly the kind of gap that grows silently as the fill
# proceeds.
files=$(cd "$RULES_DIR" && ls *.md prospective/*.md 2>/dev/null | sort -u)
[ -n "$files" ] || { echo "wss-rules-truncate.sh: no .md files under wss/rules/ — refusing to guess" >&2; exit 1; }

stripped=0; touched=0
for rel in $files; do
  f="$RULES_DIR/$rel"
  [ -f "$f" ] || { printf '  skip   %-34s does not exist\n' "$rel"; continue; }
  before=$(grep -cE '^### [A-Z]+-[A-Z]+-[0-9]{3}$' "$f" || true)
  new=$(awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; print; next }
    fence { print; next }
    /^### [A-Z]+-[A-Z]+-[0-9]{3}$/ { inrow = 1; next }
    inrow && /^#{1,3} [^#]/ { inrow = 0 }
    inrow && /^---[[:space:]]*$/ { inrow = 0 }
    inrow { next }
    { print }
  ' "$f")
  if [ "$WRITE" -eq 1 ]; then
    printf '%s\n' "$new" > "$f"
    printf '  strip  %-34s %s row(s) removed\n' "$rel" "$before"
  else
    printf '  would  %-34s %s row(s) would be removed\n' "$rel" "$before"
  fi
  stripped=$((stripped + before)); touched=$((touched + 1))
done

if [ "$WRITE" -eq 1 ]; then
  echo "stripped $stripped row(s) across $touched file(s) — every file and every section kept"
else
  echo "$stripped row(s) across $touched file(s) would be stripped — nothing was written. Pass --write to do it."
fi
