#!/usr/bin/env bash
# wss-handoff-state.sh — mechanical splice for the handoff's `## State`
# section and for the hazard register (the handoff's own card, and its
# overflow document), per the decision log's 2026-08-12 twelfth entry:
# `--wss-wrap` stops READING `WSS.record.handoff` before writing it.
#
# What "reading nothing" means here: this script never opens a file to
# decide WHAT the new text should say — that judgment stays with whatever
# calls it (a session, not this script). It opens a file only to locate an
# ANCHOR (a marker line or a heading, matched exactly) so it knows WHERE to
# splice. Locating a byte offset is not re-deriving content.
#
# Three operations:
#
#   state <handoff-file> <content-file|->
#     Wipes and rewrites the `## State` section in place: everything between
#     the literal line `<!-- handoff:card-ends -->` and the next literal
#     `## Where everything else is` heading is replaced, wholesale, with a
#     fresh `## State` heading followed by <content-file>'s body. The
#     previous body is never inspected — this is supersession, not an edit.
#
#   hazard-append <file> <heading-anchor> <entry-file|->
#     Appends <entry-file>'s body as a new paragraph at the end of the
#     section that starts at the line matching <heading-anchor> exactly
#     (up to, but not including, the next `^## ` heading or EOF). Use when
#     the session found a new standing hazard.
#
#   hazard-delete <file> <heading-anchor> <start-pattern>
#     Deletes the paragraph beginning at the line within that same section
#     matching extended-regex <start-pattern>, through the next blank line.
#     Use when the session fixed a hazard its entry named.
#
# Every operation refuses (exit 1, nothing written) when its anchor is
# absent, duplicated, or matches ambiguously — silently truncating or
# guessing is the one failure mode this script exists to rule out. A
# post-write check also refuses any write that would push the handoff's
# CARD (everything up to and including `<!-- handoff:card-ends -->`) over
# the 4096-byte budget `wss-doctor.sh` enforces — that only bites
# hazard-append/-delete run against a heading above the marker; `state`
# never touches the card.
set -euo pipefail

CARD_MARKER='<!-- handoff:card-ends -->'
CARD_CAP=4096

die() { echo "wss-handoff-state.sh: $*" >&2; exit 1; }

# read_body FILE|- : the trimmed body of a content/entry argument. Command
# substitution strips ALL trailing blank lines on its own, which doubles as
# the normalizer that keeps splice output single-blank-line-separated
# regardless of how the caller formatted the source.
read_body() {
  local src=$1
  if [ "$src" = "-" ]; then cat; else
    [ -f "$src" ] || die "$src: no such file"
    cat "$src"
  fi
}

# exact_count FILE LINE : how many lines of FILE equal LINE exactly.
exact_count() { grep -F -x -c -- "$2" "$1" 2>/dev/null || true; }

# exact_line FILE LINE : the (1-based) line number of the first exact match.
exact_line() { grep -F -x -n -- "$2" "$1" | head -1 | cut -d: -f1; }

# section_end FILE START_LINE : the line number of the first `## ` heading
# OR the card marker, whichever comes first strictly after START_LINE, or
# (total lines + 1) when the section runs to EOF — i.e. the exclusive end of
# the section that starts at START_LINE. The marker counts as a boundary of
# its own because it cuts a section (e.g. the card's `## !important`) without
# being a heading itself — the card ends AT the marker regardless of what
# heading comes next in the raw file order.
section_end() {
  local file=$1 start=$2 n
  n=$(awk -v s="$((start + 1))" -v marker="$CARD_MARKER" \
    'NR>=s && (/^## / || $0==marker) {print NR; exit}' "$file")
  if [ -z "$n" ]; then n=$(($(wc -l <"$file") + 1)); fi
  printf '%s' "$n"
}

# check_card_budget FILE : refuse (nonzero exit) if FILE now carries the
# card marker and the bytes up to and including it exceed CARD_CAP. A file
# with no marker (the overflow document, or an unsplit handoff) is exempt —
# there is no card to bound.
check_card_budget() {
  local file=$1 mark card_bytes
  mark=$(exact_line "$file" "$CARD_MARKER") || true
  [ -n "$mark" ] || return 0
  card_bytes=$(head -n "$mark" "$file" | wc -c | tr -d ' ')
  if [ "$card_bytes" -gt "$CARD_CAP" ]; then
    echo "wss-handoff-state.sh: refusing to write — the card would be \
${card_bytes}B, over the ${CARD_CAP}B budget wss-doctor.sh enforces. Move \
this hazard to the overflow document instead of the card." >&2
    return 1
  fi
}

# atomic_write FILE CONTENT : write CONTENT to FILE via a temp file in the
# same directory (so mv is a same-filesystem rename), preserving FILE's
# existing permission bits — `> tmp && mv tmp file` otherwise hands the
# result whatever the umask says, silently.
atomic_write() {
  local file=$1 content=$2 mode tmp
  mode=$(stat -c '%a' "$file")
  tmp=$(mktemp "$(dirname -- "$file")/.wss-handoff-state.XXXXXX")
  printf '%s\n' "$content" >"$tmp"
  chmod "$mode" "$tmp"
  mv -- "$tmp" "$file"
}

cmd_state() {
  local file=$1 content_src=$2
  [ -f "$file" ] || die "$file: no such file"
  local heading='## Where everything else is'

  local mc hc
  mc=$(exact_count "$file" "$CARD_MARKER")
  [ "${mc:-0}" -eq 1 ] || die "$file has $mc occurrence(s) of the exact line \
'$CARD_MARKER' — need exactly 1 to know where the card ends. Fix the anchor \
by hand before splicing."
  hc=$(exact_count "$file" "$heading")
  [ "${hc:-0}" -eq 1 ] || die "$file has $hc occurrence(s) of the exact line \
'$heading' — need exactly 1 to know where '## State' ends. Fix the anchor by \
hand before splicing."

  local m n
  m=$(exact_line "$file" "$CARD_MARKER")
  n=$(exact_line "$file" "$heading")
  [ "$n" -gt "$m" ] || die "'$heading' is at line $n, at or before the card \
marker at line $m — anchors are out of order, refusing to guess which side \
of the marker '## State' belongs on."

  local body
  body=$(read_body "$content_src")
  [ -n "$body" ] || die "the new state body is empty — a wipe is not a \
delete; pass content or use hazard-delete on the card instead"

  local first_nonblank
  first_nonblank=$(printf '%s\n' "$body" | awk 'NF{print; exit}')
  [ "$first_nonblank" != "## State" ] || die "content file's first \
non-blank line is '## State' — this script re-emits that heading itself; \
pass body only (the text that goes UNDER '## State'), or the write would \
produce two consecutive '## State' headings."

  local prefix suffix new
  prefix=$(head -n "$m" "$file")
  suffix=$(tail -n "+$n" "$file")
  new=$(printf '%s\n\n## State\n\n%s\n\n%s' "$prefix" "$body" "$suffix")

  local tmp_check
  tmp_check=$(mktemp)
  printf '%s\n' "$new" >"$tmp_check"
  check_card_budget "$tmp_check" || { rm -f "$tmp_check"; exit 1; }
  rm -f "$tmp_check"

  atomic_write "$file" "$new"
  echo "wss-handoff-state.sh: state — replaced lines $((m + 1))-$((n - 1)) of $file"
}

cmd_hazard_append() {
  local file=$1 anchor=$2 entry_src=$3
  [ -f "$file" ] || die "$file: no such file"

  local hc
  hc=$(exact_count "$file" "$anchor")
  [ "${hc:-0}" -eq 1 ] || die "$file has $hc occurrence(s) of the exact \
heading '$anchor' — need exactly 1 to know which section to append to."

  local h e
  h=$(exact_line "$file" "$anchor")
  e=$(section_end "$file" "$h")

  local entry
  entry=$(read_body "$entry_src")
  [ -n "$entry" ] || die "the new hazard entry is empty — nothing to append"

  local prefix suffix new
  prefix=$(head -n "$((e - 1))" "$file")
  if [ "$e" -le "$(wc -l <"$file")" ]; then
    suffix=$(tail -n "+$e" "$file")
    new=$(printf '%s\n\n%s\n\n%s' "$prefix" "$entry" "$suffix")
  else
    new=$(printf '%s\n\n%s' "$prefix" "$entry")
  fi

  local tmp_check
  tmp_check=$(mktemp)
  printf '%s\n' "$new" >"$tmp_check"
  check_card_budget "$tmp_check" || { rm -f "$tmp_check"; exit 1; }
  rm -f "$tmp_check"

  atomic_write "$file" "$new"
  echo "wss-handoff-state.sh: hazard-append — added to '$anchor' in $file"
}

cmd_hazard_delete() {
  local file=$1 anchor=$2 start_pattern=$3
  [ -f "$file" ] || die "$file: no such file"

  local hc
  hc=$(exact_count "$file" "$anchor")
  [ "${hc:-0}" -eq 1 ] || die "$file has $hc occurrence(s) of the exact \
heading '$anchor' — need exactly 1 to know which section to delete from."

  local h e
  h=$(exact_line "$file" "$anchor")
  e=$(section_end "$file" "$h")

  # Confine the match to this section's body (h+1 .. e-1) so a pattern that
  # happens to also match text in another section is not silently taken.
  local sc s
  sc=$(awk -v lo="$((h + 1))" -v hi="$((e - 1))" -v pat="$start_pattern" \
    'NR>=lo && NR<=hi && $0 ~ pat {c++} END{print c+0}' "$file")
  [ "$sc" -eq 1 ] || die "'$start_pattern' matches $sc line(s) within \
'$anchor' — need exactly 1 to know which entry to delete. Narrow the \
pattern."
  s=$(awk -v lo="$((h + 1))" -v hi="$((e - 1))" -v pat="$start_pattern" \
    'NR>=lo && NR<=hi && $0 ~ pat {print NR; exit}' "$file")

  # The paragraph runs from s through the line before the next blank line
  # (or the section boundary), i.e. its extent within THIS section only.
  local p
  p=$(awk -v lo="$s" -v hi="$((e - 1))" \
    'NR>=lo && NR<=hi {
       if (NF==0) { print NR-1; found=1; exit }
       last=NR
     }
     END { if (!found) print last }' "$file")
  # after_start skips one adjoining blank line, if the paragraph is
  # followed by one, so the deletion does not leave a doubled blank.
  local after_start next_line
  next_line=$((p + 1))
  if [ "$next_line" -le "$(wc -l <"$file")" ] &&
     [ -z "$(sed -n "${next_line}p" "$file")" ]; then
    after_start=$((next_line + 1))
  else
    after_start=$next_line
  fi

  local prefix suffix new
  prefix=$(head -n "$((s - 1))" "$file")
  if [ "$after_start" -le "$(wc -l <"$file")" ]; then
    suffix=$(tail -n "+$after_start" "$file")
    new=$(printf '%s\n\n%s' "$prefix" "$suffix")
  else
    new=$prefix
  fi

  local tmp_check
  tmp_check=$(mktemp)
  printf '%s\n' "$new" >"$tmp_check"
  check_card_budget "$tmp_check" || { rm -f "$tmp_check"; exit 1; }
  rm -f "$tmp_check"

  atomic_write "$file" "$new"
  echo "wss-handoff-state.sh: hazard-delete — removed lines $s-$p from '$anchor' in $file"
}

usage() {
  cat >&2 <<'EOF'
usage:
  wss-handoff-state.sh state <handoff-file> <content-file|->
  wss-handoff-state.sh hazard-append <file> <heading-anchor> <entry-file|->
  wss-handoff-state.sh hazard-delete <file> <heading-anchor> <start-pattern>
EOF
  exit 2
}

main() {
  [ $# -ge 1 ] || usage
  local op=$1; shift
  case "$op" in
    state)
      [ $# -eq 2 ] || usage
      cmd_state "$1" "$2"
      ;;
    hazard-append)
      [ $# -eq 3 ] || usage
      cmd_hazard_append "$1" "$2" "$3"
      ;;
    hazard-delete)
      [ $# -eq 3 ] || usage
      cmd_hazard_delete "$1" "$2" "$3"
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
