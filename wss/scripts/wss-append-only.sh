#!/usr/bin/env bash
# Refuse a change that deletes from an append-only record.
#
#   wss-append-only.sh                     # the staged change vs HEAD — the pre-commit form
#   wss-append-only.sh --base origin/main  # everything this branch adds, from the merge base — the CI form
#   wss-append-only.sh --range A..B        # an explicit two-dot range
#   wss-append-only.sh --dir /path/to/project
#   wss-append-only.sh --install-hook      # write .git/hooks/pre-commit for this checkout
#
# WHICH FILES, and why no path appears in this script: every record
# `WSS.recordMode` tags `log`, resolved through `WSS.record`. An adopted project
# inherits the check by declaring its own modes, not by matching this repo's
# layout, and `WSS.record.decisionsIndex` is out of scope because it carries the
# `generated` tag — never by an exemption on its name. An exemption by name is a
# rule with a hole that nothing re-examines.
#
# Zero log records is a FAILURE, not a clean run. A manifest that parses to an
# empty set means the parser stopped matching, and a check that reports success
# over nothing is the failure mode it exists to prevent. Both walks are counted
# and both counts are printed.
#
# WHAT IS REFUSED. A deleted line inside an entry body. That is the whole rule:
# amendment is a new entry, so a legitimate change never needs one. FOUR
# deletions are allowed, and each is a clause of wss/workflow/WSS.RECORD-CONTRACT.md
# rather than a concession to a file. It said three until 2026-08-19, while the
# code had four — the fourth had been added with a full comment and never
# enumerated here, so a session reading this block believed a relocation would
# be refused:
#
#   1. THE HEADER. Everything above the first `## ` heading is the record's
#      instructions — what it holds, who writes it, which key declares it — and
#      it describes the record now, so it is rewritten in place like any
#      register. "A record's header is not one of its entries."
#   2. AN `Outcome:` BLOCK, in a record that DECLARES it has one. The
#      contract's status-field table makes this field mutable for the records it
#      names and for no others: it states the entry's disposition today, not a
#      claim about the past. The line and the unbroken block under it. The
#      record says so with `WSS.recordMode.<key>.mutable: "outcome"`; absent
#      means none, which is the contract's answer for `WSS.record.decisions` —
#      alone of the logs, its entries are claims about the past.
#   3. THE ENTRY AT THE END THE RECORD GROWS AT, and only where the same hunk
#      adds lines. That is the draft still being written — the changelog's
#      unreleased entry becoming a released one, the entry appended minutes ago.
#      Which end that is comes from `WSS.recordMode.<key>.grows` and defaults to
#      the tail, so the OTHER end is sealed. Growth direction is part of the
#      rule rather than an exemption to it: add without modifying what is there,
#      always at the same end, which makes prepend and append one rule. A hunk
#      that only removes is an excision wherever it lands, including there.
#   4. A POINTER KEPT CORRECT: a deleted line paired 1:1 with a replacement
#      whose basename and every other character are identical, so only the
#      DIRECTORY part of a path changed. That is not rewriting history, it is
#      stopping a reference from rotting when its target moves — and without it
#      an absolute-path convention cannot be maintained inside an append-only
#      record at all. Renaming a file, or repointing a line at a DIFFERENT
#      file, still fails, because both change a basename. Owner's rule,
#      2026-08-15; the implementation is the branch at the end of the loop.
#
# Everything else fails, and so does a drop in the number of `## ` entries and
# the deletion of a log file, whatever the line counts say.
#
# The two halves see different things and both are wanted. Staged-vs-HEAD sees a
# deletion that a later commit puts back, which a range diff nets out to
# nothing; the range sees what the branch does as a whole, including a deletion
# committed while the hook was not installed.
set -euo pipefail

DIR="$PWD"
MODE=staged
BASE=""
RANGE=""
INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --staged)       MODE=staged ;;
    --base)         shift; BASE="${1:?--base needs a ref}"; MODE=base ;;
    --range)        shift; RANGE="${1:?--range needs A..B}"; MODE=range ;;
    --dir)          shift; DIR="${1:?--dir needs a path}" ;;
    --install-hook) INSTALL=1 ;;
    # header block only: from line 2 to the last consecutive leading-# line
    -h|--help)      awk 'NR==1{next} !/^#/{exit} {print}' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
cd "$DIR" || { echo "no such directory: $DIR" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $DIR" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ------------------------------------------------------------------ install

if [ "$INSTALL" -eq 1 ]; then
  gitdir=$(git rev-parse --git-common-dir)
  case "$gitdir" in /*) ;; *) gitdir="$PWD/$gitdir" ;; esac
  hook="$gitdir/hooks/pre-commit"
  # An explicit marker, not the script's own name in the exec line: the quoting
  # around an absolute path is exactly the sort of thing a "does it mention us"
  # grep gets wrong, and getting it wrong here means overwriting a hook someone
  # else wrote.
  marker="wss-append-only-hook"
  self=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
  if [ -e "$hook" ] && ! grep -qF "$marker" "$hook"; then
    echo "refusing to overwrite an existing pre-commit hook: $hook" >&2
    echo "add this line to it instead:" >&2
    echo "  \"$self\" --staged || exit 1" >&2
    exit 1
  fi
  mkdir -p "$gitdir/hooks"
  {
    printf '#!/usr/bin/env sh\n'
    printf '# %s — installed by wss-append-only.sh --install-hook. Re-run that to update it.\n' "$marker"
    printf '# Untracked by design: it lives in the git dir, so it names an absolute\n'
    printf '# path on this machine and travels nowhere. Every clone installs its own.\n'
    printf 'exec "%s" --staged\n' "$self"
  } > "$hook"
  chmod +x "$hook"
  echo "installed $hook"
  exit 0
fi

# ------------------------------------------------------- which records are logs

MANIFEST=".claude/WSS.WORKFLOW.json"
if [ ! -f "$MANIFEST" ]; then
  echo "wss-append-only: no $MANIFEST here — nothing declares a record, nothing to guard"
  exit 0
fi
jq -e . "$MANIFEST" >/dev/null 2>&1 || { echo "wss-append-only: $MANIFEST does not parse" >&2; exit 1; }

keys="$TMP/keys"
modes_walked=0
if jq -e '.WSS.recordMode | type == "object"' "$MANIFEST" >/dev/null 2>&1; then
  # Two legal value shapes. The string form is the original and stays exactly as
  # it was. The object form carries the same mode plus the record's declared
  # SHAPE — which end it grows at, and what its entries are made of — so the
  # guard reads those rather than inferring them. An adopted manifest carries
  # only strings, which is why every default below is today's behaviour.
  jq -r '.WSS.recordMode | to_entries[]
         | select((.value == "log")
                  or ((.value | type == "object") and .value.mode == "log"))
         | .key' "$MANIFEST" > "$keys"
  modes_walked=$(jq -r '.WSS.recordMode | length' "$MANIFEST")
  if [ "$modes_walked" -eq 0 ]; then
    echo "wss-append-only: WSS.recordMode is an empty object. Nothing is declared a log," >&2
    echo "so this check would report a clean run over an empty set. Declare the modes." >&2
    exit 1
  fi
else
  # Absent WSS.recordMode inherits the contract's table rather than guarding
  # nothing — the same fallback wss-doctor.sh warns about.
  printf '%s\n' changelog decisions stocktake audits > "$keys"
  echo "wss-append-only: no WSS.recordMode in $MANIFEST — inheriting the contract's log set" >&2
  modes_walked=$(wc -l < "$keys")
fi

paths="$TMP/paths"
: > "$paths"
logs_declared=0
while IFS= read -r key; do
  [ -n "$key" ] || continue
  logs_declared=$((logs_declared + 1))
  p=$(jq -r --arg k "$key" 'try (.WSS.record | getpath($k | split("."))) // empty | select(type == "string")' "$MANIFEST")
  if [ -z "$p" ]; then
    echo "wss-append-only: WSS.recordMode tags '$key' as a log, but WSS.record declares no path for it" >&2
    exit 1
  fi
  # The declared shape, with today's behaviour as the default for both. `grows`
  # names the end new entries arrive at; `entry` names what an entry looks like.
  grows=$(jq -r --arg k "$key" '.WSS.recordMode[$k] | if type == "object" then (.grows // "tail") else "tail" end' "$MANIFEST")
  entry=$(jq -r --arg k "$key" '.WSS.recordMode[$k] | if type == "object" then (.entry // "heading") else "heading" end' "$MANIFEST")
  case "$grows" in tail|head) ;; *)
    echo "wss-append-only: WSS.recordMode.$key declares grows='$grows' — only 'tail' or 'head'" >&2; exit 1 ;; esac
  case "$entry" in heading|table-row) ;; *)
    echo "wss-append-only: WSS.recordMode.$key declares entry='$entry' — only 'heading' or 'table-row'" >&2; exit 1 ;; esac
  # Which status field, if any, this record may have rewritten in place. Absent
  # means NONE — the safe default, and the contract's answer for every record
  # that is not named in its status-field table.
  mutable=$(jq -r --arg k "$key" '.WSS.recordMode[$k] | if type == "object" then (.mutable // "none") else "none" end' "$MANIFEST")
  case "$mutable" in none|outcome) ;; *)
    echo "wss-append-only: WSS.recordMode.$key declares mutable='$mutable' — only 'outcome' or 'none'" >&2; exit 1 ;; esac
  printf '%s\t%s\t%s\t%s\t%s\n' "$key" "$p" "$grows" "$entry" "$mutable" >> "$paths"
done < "$keys"

if [ "$logs_declared" -eq 0 ]; then
  echo "wss-append-only: walked $modes_walked record modes and resolved no log at all." >&2
  echo "An empty set is a parse that stopped matching, not a clean run." >&2
  exit 1
fi

# --------------------------------------------------------------- what to compare

EMPTY_TREE=$(git hash-object -t tree /dev/null)
DIFF_ARGS=()
case "$MODE" in
  staged)
    if head_rev=$(git rev-parse --verify -q HEAD); then
      BASE_REV="$head_rev"
    else
      BASE_REV="$EMPTY_TREE"   # no commits yet: every log is new, nothing to destroy
    fi
    DIFF_ARGS=(--cached)
    POST_SPEC=":"              # the index
    WHAT="staged vs $(git rev-parse --short "$BASE_REV" 2>/dev/null || echo 'the empty tree')"
    ;;
  base)
    git rev-parse --verify -q "$BASE^{commit}" >/dev/null || {
      echo "wss-append-only: --base '$BASE' does not resolve to a commit here." >&2
      echo "Fetch it, or pass an explicit --range. A base that cannot be resolved is not a pass." >&2
      exit 1
    }
    BASE_REV=$(git merge-base "$BASE" HEAD) || {
      echo "wss-append-only: no merge base between '$BASE' and HEAD — unrelated histories." >&2
      exit 1
    }
    DIFF_ARGS=("$BASE_REV" HEAD)
    POST_SPEC="HEAD:"
    WHAT="$(git rev-parse --short HEAD) since $(git rev-parse --short "$BASE_REV") (merge base with $BASE)"
    ;;
  range)
    case "$RANGE" in
      *..*) A=${RANGE%%..*}; B=${RANGE##*..} ;;
      *) echo "wss-append-only: --range wants A..B, got '$RANGE'" >&2; exit 1 ;;
    esac
    [ -n "$A" ] || { echo "wss-append-only: --range '$RANGE' has no left side" >&2; exit 1; }
    [ -n "$B" ] || B=HEAD
    for r in "$A" "$B"; do
      git rev-parse --verify -q "$r^{commit}" >/dev/null || {
        echo "wss-append-only: '$r' does not resolve to a commit here. A range that cannot be" >&2
        echo "resolved — a force-push, a deleted branch, an all-zero before-sha — is not a pass." >&2
        exit 1
      }
    done
    BASE_REV=$(git rev-parse "$A")
    DIFF_ARGS=("$A" "$B")
    POST_SPEC="$B:"
    WHAT="$(git rev-parse --short "$B") since $(git rev-parse --short "$A")"
    ;;
esac

# --------------------------------------------------------------------- the check

violations=0
checked=0

# new-path -> old-path, for records that moved inside the range. Built once,
# with no pathspec: rename detection only sees a rename when both halves are in
# the diff, and a pathspec removes one of them.
renames="$TMP/renames"
git diff -M --name-status --no-color "${DIFF_ARGS[@]}" \
  | awk -F'\t' '$1 ~ /^R/ { print $3 "\t" $2 }' > "$renames"

printf 'wss-append-only: %d log record(s) of %d declared modes, %s\n' \
  "$logs_declared" "$modes_walked" "$WHAT"

while IFS=$'\t' read -r key path grows entry mutable; do
  [ -n "$path" ] || continue
  checked=$((checked + 1))
  [ -n "$grows" ] || grows=tail
  [ -n "$entry" ] || entry=heading
  [ -n "$mutable" ] || mutable=none
  # What an entry BEGINS with, per the declaration. `audits` is a table of rows
  # and has no `## ` heading anywhere, so under the old hardcoded pattern it
  # resolved to zero entries and every one of its lines took the header
  # exemption — the record was wholly unguarded.
  case "$entry" in
    heading)   entry_re='^## ' ;;
    table-row) entry_re='^[[:space:]]*\|' ;;
  esac

  # The two sides are fetched as content and compared as content. Diffing the
  # declared path instead would be subtly wrong twice: a pathspec is applied
  # BEFORE rename detection, so `git diff -M -- <newpath>` reports a moved
  # record as a brand new file and carries any excision through with it; and the
  # hunk line numbers would then be relative to nothing.
  pre="$TMP/pre"
  from=$(awk -F'\t' -v p="$path" '$1 == p { print $2 }' "$renames" | head -1)
  if ! git show "$BASE_REV:$path" > "$pre" 2>/dev/null; then
    if [ -z "$from" ] || ! git show "$BASE_REV:$from" > "$pre" 2>/dev/null; then
      printf '  ok    %-24s %s is new since the base — nothing to destroy\n' "$key" "$path"
      continue
    fi
    printf '  note  %-24s %s was renamed from %s — following the content\n' "$key" "$path" "$from"
  fi
  post="$TMP/post"
  if ! git show "$POST_SPEC$path" > "$post" 2>/dev/null; then
    printf '  FAIL  %-24s %s is GONE — a log record may not be deleted\n' "$key" "$path"
    violations=$((violations + 1))
    continue
  fi

  d="$TMP/diff"
  rc=0
  git diff --no-index -U0 --no-color "$pre" "$post" > "$d" || rc=$?
  if [ "$rc" -gt 1 ]; then
    echo "wss-append-only: git diff failed on $path" >&2
    exit 1
  fi
  if [ ! -s "$d" ]; then
    printf '  ok    %-24s %s unchanged\n' "$key" "$path"
    continue
  fi

  # Entry starts in the pre-image, and the entry count on both sides.
  starts=()
  while IFS= read -r n; do starts+=("$n"); done < <(grep -nE "$entry_re" "$pre" | cut -d: -f1)
  pre_entries=${#starts[@]}
  post_entries=$(grep -cE "$entry_re" "$post" || true)

  # Entry starts in the post-image too. Needed only where the record grew
  # (post_entries > pre_entries): the discriminator for exemption 3 below is
  # post-image position relative to whichever end actually grew.
  #
  # A single change may append MORE THAN ONE entry — a branch measured from
  # its merge base carries every entry the branch added, and with -U0 they
  # arrive as one hunk with no unchanged line between them. Anchoring on the
  # single outermost heading exempts only the outermost new entry and judges
  # every earlier one as text smuggled into the old draft's body, which is how
  # a branch that did nothing but append fails this guard. So the anchor is the
  # FIRST heading of the appended run at the tail, and the first heading that
  # SURVIVED from the pre-image at the head. With one new entry both reduce to
  # the previous single-heading anchors exactly.
  # WHICH ENTRY GREW, PER END — read off the diff, never inferred from a count.
  # `post_entries - pre_entries` is TOTAL growth, and indexing post_starts by it
  # is correct only when every new entry sits at one end. With h added at the
  # head and t at the tail, the head anchor slid t entries too far down and the
  # tail anchor h too far up, so exemption 3 covered the old head entry's body
  # and the old tail entry's body — exactly the two it exists to stop covering.
  # Both ends then failed OPEN, and no case grown at one end only can see it.
  post_starts=()
  while IFS= read -r n; do post_starts+=("$n"); done < <(grep -nE "$entry_re" "$post" | cut -d: -f1)

  # Post-image line numbers of the headings this change INSERTED. Counted
  # inside hunks only: `!inhunk` drops the `---`/`+++` file headers, which
  # precede the first `@@`, and `\ No newline` lines occupy no post-image line.
  declare -A ins_heading=()
  while IFS= read -r n; do ins_heading[$n]=1; done < <(awk '
    /^@@/ { if (match($0, /\+[0-9]+/)) pl = substr($0, RSTART + 1, RLENGTH - 1) + 0
            inhunk = 1; next }
    !inhunk { next }
    /^\\/ { next }
    /^-/  { next }
    /^\+/ { if (substr($0, 2) ~ /^## /) print pl; pl++; next }
          { pl++ }' "$d")

  # The two runs: how many entries are new at each END specifically.
  head_grown=0
  for n in "${post_starts[@]}"; do
    [ -n "${ins_heading[$n]:-}" ] || break
    head_grown=$((head_grown + 1))
  done
  tail_grown=0
  for (( i = ${#post_starts[@]} - 1; i >= 0; i-- )); do
    [ -n "${ins_heading[${post_starts[$i]}]:-}" ] || break
    tail_grown=$((tail_grown + 1))
  done
  # Where every entry is new the two runs are the same run counted twice; clamp
  # so they cannot both claim the same headings.
  if [ $((head_grown + tail_grown)) -gt "${#post_starts[@]}" ]; then
    tail_grown=$(( ${#post_starts[@]} - head_grown ))
  fi

  # The anchors: the first entry SURVIVING from the pre-image at the head, the
  # first NEW entry at the tail. Left unset where that end did not grow — there
  # the old entry is still the draft and its exemption is whole.
  post_new_tail=""
  post_old_head=""
  [ "$head_grown" -gt 0 ] && post_old_head="${post_starts[$head_grown]:-}"
  [ "$tail_grown" -gt 0 ] && post_new_tail="${post_starts[$(( ${#post_starts[@]} - tail_grown ))]:-}"

  # Lines an `Outcome:` block covers: the field line and the unbroken block under it.
  #
  # SCOPED BY RECORD, and it was not until 2026-08-19. The contract's
  # status-field table is keyed by record — `WSS.record.stocktake` has
  # `Outcome`, `WSS.record.decisions` has NONE, deliberately, because alone of
  # them its entries are claims about the past. This build referenced no key at
  # all, so every log record got the exemption and an `Outcome:` block could be
  # deleted from any decision-log entry while the guard printed `intact`.
  # Probed: an Outcome block plus two detail lines removed from a MIDDLE entry
  # of a decisions-only log returned ok/rc=0; the control, an ordinary body line
  # in the same entry, returned rc=1. Middle matters — at either end the draft
  # exemption covers it anyway and the probe reads as a false negative.
  #
  # Which record has a mutable field is DECLARED, per the twenty-fourth entry's
  # direction, and defaults to none: a record that does not say it has one does
  # not get the exemption. Adopters keep whatever their own contract says
  # instead of inheriting this repo's table.
  declare -A outcome_ok=()
  if [ "$mutable" = outcome ]; then
  while IFS= read -r n; do outcome_ok[$n]=1; done < <(awk '
    /^[[:space:]]*[-*]*[[:space:]]*[*]*Outcome[*]*[[:space:]]*:/ { inblk = 1 }
    /^[[:space:]]*$/ { inblk = 0 }
    inblk { print NR }' "$pre")
  fi

  adds=0; dels=0; bad_lines=0
  bad_where="$TMP/where"; : > "$bad_where"
  # Minus the `+++`/`---` file headers, which the counts above swept in.
  adds=$(grep -c '^+' "$d" || true); adds=$((adds - 1)); if [ "$adds" -lt 0 ]; then adds=0; fi
  dels=$(grep -c '^-' "$d" || true); dels=$((dels - 1)); if [ "$dels" -lt 0 ]; then dels=0; fi

  while IFS=$'\x1f' read -r lineno hunkadds text plus kind postln; do
    [ -n "$lineno" ] || continue
    # 1. the header, everything above the first entry
    if [ "$pre_entries" -eq 0 ] || [ "$lineno" -lt "${starts[0]}" ]; then continue; fi
    # 2. a status field the contract makes mutable
    if [ -n "${outcome_ok[$lineno]:-}" ]; then continue; fi
    # which entry the line sits in
    idx=0
    for i in "${!starts[@]}"; do
      if [ "$lineno" -ge "${starts[$i]}" ]; then idx=$i; fi
    done
    # 3. the draft at either end, rewritten rather than excised -- but only
    #    where the record did NOT grow THERE. Once one or more brand-new
    #    entries sit at an end, the exemption at THAT end follows their own
    #    text (by post-image position, within the run they occupy) rather than
    #    the old entry that used to occupy it. A deleted line has no post-image
    #    position -- it only ever existed in the pre-image -- so once that end
    #    grew, a deletion there is judged like any other, never exempt here.
    #
    #    "Did the record grow" is asked PER END, and asking it globally was the
    #    defect: a tail append does not stop the head entry being the draft, and
    #    the global test both revoked the head exemption when only the tail grew
    #    and mis-anchored it when both did.
    #
    #    THE END IS NOW DECLARED, not guessed. A record grows at exactly one
    #    end, named by `grows`, and only the entry at THAT end is ever the
    #    draft — the other end is sealed permanently. The owner's ruling: the
    #    rule is to add without modifying what is there, and whether it stacks
    #    up or down is irrelevant so long as the direction never changes, so
    #    prepend and append are one rule rather than a rule and an exemption.
    if [ "$grows" = head ]; then draft_idx=0; else draft_idx=$((pre_entries - 1)); fi
    if [ "$hunkadds" -gt 0 ] && [ "$idx" -eq "$draft_idx" ]; then
      if [ "$idx" -eq 0 ] && [ "$head_grown" -eq 0 ]; then continue; fi
      if [ "$idx" -eq $((pre_entries - 1)) ] && [ "$tail_grown" -eq 0 ]; then continue; fi
      if [ "$kind" = I ]; then
        # A blank separator line carries no content; whether it reads as the
        # old entry's trailing blank or the new entry's leading one is not a
        # question this guard needs to answer, because either reading is
        # harmless — nothing is smuggled by inserting an empty line.
        if [ -z "$text" ]; then continue; fi
        if [ "$idx" -eq $((pre_entries - 1)) ] && [ -n "$post_new_tail" ] && [ "$postln" -ge "$post_new_tail" ]; then
          continue
        fi
        if [ "$idx" -eq 0 ] && [ -n "$post_old_head" ] && [ "$postln" -lt "$post_old_head" ]; then
          continue
        fi
      fi
    fi
    # 4. a pointer kept correct. A relocation changes only the DIRECTORY part of
    #    a path: the basename, and every other character on the line, must be
    #    identical. That is not rewriting history — it is stopping a reference
    #    from rotting when its target moves, and without it an absolute-path
    #    convention cannot be maintained inside an append-only record at all.
    #    Renaming a file, or repointing a line at a DIFFERENT file, still fails,
    #    because both change a basename. Owner's rule, 2026-08-15: paths are
    #    absolute so that a move is a grep-and-substitute with no strays.
    if [ "$kind" = D ] && [ -n "$plus" ] && [ "$text" != "$plus" ]; then
      nm_a=$(printf '%s' "$text" | sed -E 's#([A-Za-z0-9_.@~+-]*/)+##g')
      nm_b=$(printf '%s' "$plus" | sed -E 's#([A-Za-z0-9_.@~+-]*/)+##g')
      [ "$nm_a" = "$nm_b" ] && continue
    fi
    bad_lines=$((bad_lines + 1))
    if [ "$bad_lines" -le 3 ]; then
      head=$(sed -n "${starts[$idx]}p" "$pre" | cut -c1-64)
      printf '          L%s in "%s"\n            %s %s\n' "$lineno" "$head" "$([ "$kind" = I ] && echo + || echo -)" "$(printf '%s' "$text" | cut -c1-64)" >> "$bad_where"
    fi
  done < <(awk '
    # Deleted lines are buffered per hunk alongside the added lines, so each
    # deletion can be paired with the line that replaced it. Exemption 4 needs
    # that pair; the count check is what keeps the pairing honest — where a hunk
    # adds a different number of lines than it removes there is no 1:1
    # correspondence, so no replacement is offered and the deletion is judged
    # on its own, exactly as before.
    function flush(  i, p) {
      for (i = 1; i <= nm; i++) {
        p = (nm == np ? ptext[i] : "")
        printf "%d\037%d\037%s\037%s\037D\037\n", mline[i], add, mtext[i], p
      }
      # Gap 1: a hunk that adds more lines than it removes has smuggled text
      # INTO an entry body. A deletion-only predicate never saw it, so history
      # could be rewritten by addition with no symptom. The insertion point is
      # the hunk pre-image start, which is what decides the entry it lands in;
      # the draft exemption at either end still applies to it downstream.
      #
      # One record per surplus added line, each carrying its OWN post-image
      # line number: a single lumped record for the whole hunk cannot tell
      # a line inside the entry that already existed apart from a line that
      # belongs to the new entry, when an edit to the old draft and the
      # brand-new entry share a hunk with no unchanged line between them.
      # (No apostrophe in this comment on purpose: it sits inside a
      # single-quoted awk program, where one would end the quoting.)
      for (i = nm + 1; i <= np; i++) {
        printf "%d\037%d\037%s\037\037I\037%d\n", hstart, add, ptext[i], pline[i]
      }
      nm = 0; np = 0
    }
    /^--- / || /^\+\+\+ / { next }
    /^@@/ {
      flush()
      match($0, /-[0-9]+(,[0-9]+)?/); s = substr($0, RSTART + 1, RLENGTH - 1)
      c = index(s, ","); old = (c ? substr(s, 1, c - 1) + 0 : s + 0)
      match($0, /\+[0-9]+(,[0-9]+)?/); t = substr($0, RSTART + 1, RLENGTH - 1)
      c = index(t, ","); add = (c ? substr(t, c + 1) + 0 : 1)
      new = (c ? substr(t, 1, c - 1) + 0 : t + 0)
      hstart = old
      next
    }
    /^-/ { nm++; mline[nm] = old; mtext[nm] = substr($0, 2); old++; next }
    /^\+/ { np++; ptext[np] = substr($0, 2); pline[np] = new; new++; next }
    /^ /  { old++; new++; next }
    END { flush() }
  ' "$d")

  if [ "$post_entries" -lt "$pre_entries" ]; then
    printf '  FAIL  %-24s %s lost entries: %d became %d\n' "$key" "$path" "$pre_entries" "$post_entries"
    violations=$((violations + 1))
  elif [ "$bad_lines" -gt 0 ]; then
    printf '  FAIL  %-24s %s +%d -%d, %d line(s) rewriting an entry body\n' \
      "$key" "$path" "$adds" "$dels" "$bad_lines"
    cat "$bad_where"
    violations=$((violations + 1))
  else
    printf '  ok    %-24s %s +%d -%d\n' "$key" "$path" "$adds" "$dels"
  fi
  unset outcome_ok
done < "$paths"

if [ "$checked" -ne "$logs_declared" ]; then
  echo "wss-append-only: declared $logs_declared log records but examined $checked." >&2
  exit 1
fi

if [ "$violations" -gt 0 ]; then
  cat >&2 <<'EOF'

An append-only record lost a line. Nothing true was ever fixed by deleting it:
amendment is a new entry, and a correction is a later entry saying so. Restore
what was removed and append instead. The four deletions that ARE allowed — the
header above the first entry; an `Outcome:` block, in a record that declares it
has one; the draft entry at the end the record GROWS at, where the same hunk
rewrites it; and a path whose DIRECTORY part alone changed, basename intact —
are in wss/workflow/WSS.RECORD-CONTRACT.md. The other end is sealed.
EOF
  exit 1
fi

printf 'wss-append-only: %d log record(s) intact\n' "$checked"
