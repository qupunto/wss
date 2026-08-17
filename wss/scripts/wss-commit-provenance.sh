#!/usr/bin/env bash
# Enforce that a record-touching commit declares which records and whose authority
# the write is made under. Delimited block in the commit message, self-declared by
# the author, emitted by prepare-commit-msg and asserted by commit-msg.
#
#   wss-commit-provenance.sh --emit MSGFILE [SOURCE SHA]
#   wss-commit-provenance.sh --assert MSGFILE [SOURCE SHA]
#   wss-commit-provenance.sh --writers MATRIX-FILE
#   wss-commit-provenance.sh --print
#   wss-commit-provenance.sh --install-hook
#   wss-commit-provenance.sh --dir /path/to/project
#
# The block is SELF-DECLARED, so this catches mistakes rather than misconduct:
# what it sees is a session writing a record from the wrong skill, which is the
# one failure no tree-level check can reach, having no baseline to diff against.
# A commit touching no record is silent, and only the block's interior is fixed —
# the author writes freely before and after it.
set -euo pipefail

# -------------------------------------------------------- arg parse

DIR="$PWD"
INSTALL=0
MODE=""
MSGFILE=""
MATRIX=""
EMIT_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --emit)
      MODE=emit
      [ $# -ge 2 ] || { echo "--emit needs a msgfile" >&2; exit 2; }
      MSGFILE="$2"
      shift 2
      # Collect remaining args for emit
      EMIT_ARGS=("$@")
      break
      ;;
    --assert)
      MODE=assert
      [ $# -ge 2 ] || { echo "--assert needs a msgfile" >&2; exit 2; }
      MSGFILE="$2"
      shift 2
      # Collect remaining args for assert
      EMIT_ARGS=("$@")
      break
      ;;
    --writers)      MODE=writers; MATRIX="${2:?--writers needs a matrix file}"; shift 2 ;;
    --print)        MODE=print; shift ;;
    --install-hook) INSTALL=1; shift ;;
    --dir)          DIR="${2:?--dir needs a path}"; shift 2 ;;
    -h|--help)      awk 'NR==1{next} !/^#/{exit} {print}' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# -------------------------------------------------------- preconditions

# --writers is a PURE TEXT OPERATION on a markdown table and must not require a
# git repository, jq, or anything else. wss-doctor.sh calls it to parse an
# ownership matrix from whatever directory the doctor happens to be checking,
# which is frequently not a repository at all — and because a failed call prints
# nothing, gating it behind the repo check made the doctor read the silence as
# "no writers claimed" and reach no verdict on a matrix full of them. Silence
# from a parser must never be indistinguishable from a clean parse.
if [ "$MODE" = writers ]; then
  [ -r "$MATRIX" ] || { echo "no such matrix file: $MATRIX" >&2; exit 1; }
else
  command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
  command -v jq  >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
  cd "$DIR" || { echo "no such directory: $DIR" >&2; exit 1; }
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $DIR" >&2; exit 1; }
fi

# -------------------------------------------------------- utilities

sole_writers_() {
  # Parse ownership matrix and output key<TAB>writer pairs
  awk '
    /^\|[[:space:]]*Verb[[:space:]]*\|/ { t = 1; next }
    t && /^\|[[:space:]]*[-:]/ { next }
    t && /^\|/ {
      n = split($0, f, "|")
      if (n >= 7) {
        skill = f[4]; own = f[6]; who = ""
        if (match(skill, /writers\/[A-Za-z0-9.-]+\.md/)) who = substr(skill, RSTART, RLENGTH)
        else if (match(skill, /`[^`]+`/)) who = substr(skill, RSTART + 1, RLENGTH - 2)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", own)
        if (own !~ /^\*\*nothing/)
          while (match(own, /WSS\.(record|lanes)\.[a-zA-Z]+(\.[a-zA-Z]+)?|WSS\.sweeps/)) {
            print substr(own, RSTART, RLENGTH) "\t" who
            own = substr(own, RSTART + RLENGTH)
          }
      }
      next
    }
    t { t = 0 }
  ' "$1" | sort -u
}

# -------------------------------------------------------- --install-hook

if [ "$INSTALL" -eq 1 ]; then
  gitdir=$(git rev-parse --git-common-dir)
  case "$gitdir" in /*) ;; *) gitdir="$PWD/$gitdir" ;; esac
  self=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
  marker="wss-commit-provenance-hook"

  for h in prepare-commit-msg commit-msg; do
    hook="$gitdir/hooks/$h"
    if [ -e "$hook" ] && ! grep -qF "$marker" "$hook"; then
      echo "refusing to overwrite an existing $h hook: $hook" >&2
      echo "add this line to it instead:" >&2
      if [ "$h" = "prepare-commit-msg" ]; then
        echo "  \"$self\" --emit \"\$1\" \"\$2\" \"\$3\" || exit 1" >&2
      else
        echo "  \"$self\" --assert \"\$1\" \"\$2\" \"\$3\" || exit 1" >&2
      fi
      exit 1
    fi
  done

  mkdir -p "$gitdir/hooks"

  # prepare-commit-msg
  {
    printf '#!/usr/bin/env sh\n'
    printf '# %s — installed by wss-commit-provenance.sh --install-hook. Re-run that to update it.\n' "$marker"
    printf '# Untracked by design: it lives in the git dir, so it names an absolute\n'
    printf '# path on this machine and travels nowhere. Every clone installs its own.\n'
    printf 'exec "%s" --emit "$1" "$2" "$3"\n' "$self"
  } > "$gitdir/hooks/prepare-commit-msg"
  chmod +x "$gitdir/hooks/prepare-commit-msg"

  # commit-msg
  {
    printf '#!/usr/bin/env sh\n'
    printf '# %s — installed by wss-commit-provenance.sh --install-hook. Re-run that to update it.\n' "$marker"
    printf '# Untracked by design: it lives in the git dir, so it names an absolute\n'
    printf '# path on this machine and travels nowhere. Every clone installs its own.\n'
    printf 'exec "%s" --assert "$1" "$2" "$3"\n' "$self"
  } > "$gitdir/hooks/commit-msg"
  chmod +x "$gitdir/hooks/commit-msg"

  echo "installed $gitdir/hooks/prepare-commit-msg and $gitdir/hooks/commit-msg"
  exit 0
fi

# -------------------------------------------------------- --writers

if [ "$MODE" = "writers" ]; then
  if [ ! -f "$MATRIX" ]; then
    echo "wss-commit-provenance: matrix file not found: $MATRIX" >&2
    exit 1
  fi
  sole_writers_ "$MATRIX"
  exit 0
fi

# -------------------------------------------------------- resolve_() — walk manifest and join

resolve_() {
  # Returns path<TAB>key<TAB>writer for all records touched
  # Returns nothing if no records are touched or no manifest exists

  local manifest=".claude/WSS.WORKFLOW.json"
  [ -f "$manifest" ] || return 0

  local own_matrix="${CLAUDE_DIR:-.}/wss/workflow/WSS.OWNERSHIP.md"
  [ -f "$own_matrix" ] || return 1

  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN

  # 1. Get staged paths
  git diff --cached --name-only --no-renames | sort > "$tmp/staged"
  [ -s "$tmp/staged" ] || return 0

  # 2. Walk manifest to build path->key map (exclude glob patterns)
  jq -r '
    ((.WSS.record // {}) |
      to_entries[] |
      if .value | type == "string" then
        "WSS.record." + .key + ": " + .value
      elif .value | type == "array" then
        "WSS.record." + .key + ": " + (.value | join(", "))
      else
        empty
      end),
    ((.WSS.lanes // {}) |
      to_entries[] |
      if .value | type == "string" then
        "WSS.lanes." + .key + ": " + .value
      elif .value | type == "array" then
        "WSS.lanes." + .key + ": " + (.value | join(", "))
      else
        empty
      end),
    ((.WSS.sweeps // empty) | "WSS.sweeps: " + .)
  ' "$manifest" 2>/dev/null | awk -F': ' '
    NF == 2 {
      key = $1
      paths = $2
      # Skip if contains glob
      if (paths !~ /\*/) {
        split(paths, p, ", ")
        for (i in p) print p[i] "\t" key
      }
    }
  ' | sort -u > "$tmp/paths"

  [ -s "$tmp/paths" ] || return 0

  # 3. Get writers from matrix
  sole_writers_ "$own_matrix" | sort -u > "$tmp/writers"
  [ -s "$tmp/writers" ] || return 1

  # 4. Join: path<TAB>key<TAB>writer
  # For each path in the manifest that is also staged, find its key(s), then find the writer(s)
  while IFS=$'\t' read -r path key; do
    [ -n "$path" ] || continue
    # Only include if this path is actually staged
    if grep -Fxq "$path" "$tmp/staged"; then
      writer=$(awk -F'\t' -v k="$key" '$1 == k {print $2; exit}' "$tmp/writers")
      if [ -n "$writer" ]; then
        echo "$path	$key	$writer"
      fi
    fi
  done < "$tmp/paths" | sort -u > "$tmp/triples"

  [ -s "$tmp/triples" ] || return 0

  # 5-6. Group by key and emit sorted record lines
  awk -F'\t' '
    {
      key = $2
      path = $1
      writer = $3
      if (!(key in files)) {
        keys[++nkeys] = key
        writers[key] = writer
      }
      if (files[key] != "") files[key] = files[key] ", "
      files[key] = files[key] path
    }
    END {
      # Sort keys in C locale
      n = asort(keys)
      for (i = 1; i <= n; i++) {
        key = keys[i]
        print "record: " key " | writer: " writers[key] " | file: " files[key]
      }
    }
  ' "$tmp/triples"
}

# -------------------------------------------------------- block_() — render block

block_() {
  # Reads from resolve_() and renders the full block with delimiters and authority
  local lines
  lines=$(resolve_)

  if [ -z "$lines" ]; then
    # No records, don't emit block
    return 1
  fi

  echo "WSS-RECORDS-BEGIN v1"
  printf '%s\n' "$lines" | sort
  printf 'authority: %s\n' "${WSS_WRITER:-UNDECLARED}"
  echo "WSS-RECORDS-END"
  return 0
}

# -------------------------------------------------------- --print

if [ "$MODE" = "print" ]; then
  block_ || true
  exit 0
fi

# -------------------------------------------------------- --emit

if [ "$MODE" = "emit" ]; then
  SOURCE="${EMIT_ARGS[0]:-}"
  SHA="${EMIT_ARGS[1]:-}"

  # Get or create the block
  block_text=$(block_ 2>/dev/null) || block_text=""

  if [ -n "$block_text" ]; then
    # THE BLOCK GOES BEFORE THE TRAILER PARAGRAPH, NEVER AFTER IT.
    #
    # Git recognises trailers only in the LAST paragraph of a message. The
    # first version of this placed the block "before the first comment line or
    # at end" — and `git commit -m` writes no comment lines at all, so every
    # non-interactive commit took the `at end` arm and put this block after the
    # trailers. That silently destroyed the session trailer:
    # `%(trailers:key=Claude-Session)` came back empty, and wss-git-commit.sh —
    # which verifies exactly that, and is the only sanctioned path to a commit
    # here — refused to push after every record commit. Found on 2026-08-16 on
    # the first real record commit made with these hooks installed, having
    # passed every fixture, because no fixture combined the two.
    #
    # A single pass rather than a replace-in-place branch: an existing block is
    # STRIPPED and a fresh one inserted at the computed position, so a
    # mis-placed block written by the older version heals itself on the next
    # amend instead of being rewritten where it already was.
    comment_char=$(git config --get core.commentChar 2>/dev/null || true)
    case "$comment_char" in ''|auto) comment_char='#' ;; esac
    awk -v block="$block_text" -v cc="$comment_char" '
      {
        if ($0 == "WSS-RECORDS-BEGIN v1") { inb = 1; next }
        if ($0 == "WSS-RECORDS-END")      { inb = 0; next }
        if (inb) next
        line[++n] = $0
      }
      END {
        # Collapse the blank runs stripping a block can leave, and drop
        # trailing blanks, so the position search sees a clean message.
        m = 0
        for (i = 1; i <= n; i++) {
          if (line[i] ~ /[^ \t]/) { out[++m] = line[i]; blank = 0 }
          else if (!blank && m > 0) { out[++m] = ""; blank = 1 }
        }
        while (m > 0 && out[m] == "") m--

        # The scissors/comment region is not part of the message.
        cut = m + 1
        for (i = 1; i <= m; i++)
          if (substr(out[i], 1, length(cc)) == cc) { cut = i; break }

        last = 0
        for (i = cut - 1; i >= 1; i--) if (out[i] ~ /[^ \t]/) { last = i; break }

        # A trailing paragraph counts as trailers only if EVERY line of it is
        # trailer-shaped, and only if something precedes it — a message that is
        # nothing but trailers has no body to sit above.
        ins = 0
        if (last > 0) {
          start = last
          while (start > 1 && out[start - 1] ~ /[^ \t]/) start--
          ok = 1
          for (i = start; i <= last; i++)
            if (out[i] !~ /^[A-Za-z][A-Za-z0-9-]*:[ \t]/) { ok = 0; break }
          if (ok && start > 1) ins = start
        }
        if (ins == 0) ins = cut

        for (i = 1; i < ins; i++) print out[i]
        if (ins > 1 && out[ins - 1] ~ /[^ \t]/) print ""
        print block
        if (ins <= m) { print ""; for (i = ins; i <= m; i++) print out[i] }
      }
    ' "$MSGFILE" > "$MSGFILE.tmp"
    mv "$MSGFILE.tmp" "$MSGFILE"
  fi

  # The append-only check, for EVERY commit shape this hook sees — amend included.
  #
  # This ran `--amend-base "$SHA"` inside an `[ "$SOURCE" = "commit" ]` guard
  # until 2026-08-16. Two measured defects killed that shape, and both are
  # properties of git's prepare-commit-msg contract rather than of this script:
  #   - `git commit --amend -m …` and `--amend -F …` arrive as SOURCE=message
  #     with an EMPTY third argument, so the guard never fired for the scripted
  #     amend — the form `git-writer` uses.
  #   - `git commit -C <sha>` arrives as SOURCE=commit with the sha of the
  #     commit whose MESSAGE is being reused, on a brand-new commit. The old
  #     line then judged the index against an unrelated commit's parent.
  # `--staged` is unconditional here because it is correct for all of them: it
  # diffs --cached against HEAD, and during an amend HEAD is still the commit
  # being amended, which is the strict baseline. See the decision log.
  # Output is held and replayed ONLY on failure. A clone carrying both hooks
  # runs this check twice per commit — `pre-commit` from wss-append-only.sh
  # --install-hook, then here — and two identical all-clear banners per commit
  # is noise that trains a reader to skim the one that matters. The check
  # itself still runs both times, deliberately: the whole point is that a
  # provenance-only clone has no pre-commit hook to rely on, and this side
  # cannot know which shape it is in without reintroducing the conditional
  # that caused the defect above. Nothing parses this banner (it is printed at
  # wss-append-only.sh:374 and read by no script, test or CI step), so holding
  # it costs no contract.
  CLAUDE_DIR="${CLAUDE_DIR:-.}"
  if [ -x "$CLAUDE_DIR/wss/scripts/wss-append-only.sh" ]; then
    if ! ao_out=$(bash "$CLAUDE_DIR/wss/scripts/wss-append-only.sh" --staged 2>&1); then
      printf '%s\n' "$ao_out" >&2
      exit 1
    fi
  fi

  exit 0
fi

# -------------------------------------------------------- --assert

if [ "$MODE" = "assert" ]; then
  SOURCE="${EMIT_ARGS[0]:-}"
  SHA="${EMIT_ARGS[1]:-}"

  # Get the recomputed block
  if computed_block=$(block_ 2>/dev/null); then
    has_computed=1
  else
    has_computed=0
    computed_block=""
  fi

  # Get the block from the message
  if grep -q "WSS-RECORDS-BEGIN v1" "$MSGFILE"; then
    found_block=$(sed -n '/^WSS-RECORDS-BEGIN v1$/,/^WSS-RECORDS-END$/p' "$MSGFILE")
  else
    found_block=""
  fi

  # Compare
  if [ $has_computed -eq 0 ] || [ -z "$computed_block" ]; then
    # No records in computed
    if [ -n "$found_block" ]; then
      echo "wss-commit-provenance: stale block in message — no records are touched in this commit" >&2
      exit 1
    fi
    # Both empty, OK
    exit 0
  fi

  # Has computed records
  if [ -z "$found_block" ]; then
    echo "wss-commit-provenance: missing block — this commit touches records but declares none" >&2
    exit 1
  fi

  # Compare byte for byte (trailing whitespace stripped)
  computed_clean=$(printf '%s\n' "$computed_block" | sed 's/[[:space:]]*$//')
  found_clean=$(printf '%s\n' "$found_block" | sed 's/[[:space:]]*$//')

  if [ "$computed_clean" != "$found_clean" ]; then
    echo "wss-commit-provenance: altered block — the declared records do not match the staged files" >&2
    exit 1
  fi

  # Check authority line
  authority=$(printf '%s\n' "$found_block" | grep '^authority:' | sed 's/^authority: //')

  # Get all writer values from the block
  writers=$(printf '%s\n' "$found_block" | grep '^record:' | awk -F'|' '{print $2}' | sed 's/^ *writer: //' | awk '{print $1}' | sort -u)

  if [ -z "$authority" ]; then
    printf 'NOTICE: authority is missing (UNDECLARED)\n'
    exit 0
  fi

  if [ "$authority" = "UNDECLARED" ]; then
    printf 'NOTICE: authority is UNDECLARED — this path is not yet taught to pass --writer\n'
    exit 0
  fi

  # Check if authority matches any writer
  found_match=0
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    if [ "$authority" = "$w" ]; then
      found_match=1
      break
    fi
  done <<< "$writers"

  if [ $found_match -eq 0 ]; then
    echo "wss-commit-provenance: wrong authority — '$authority' is not a writer for any record in this commit" >&2
    exit 1
  fi

  exit 0
fi

echo "wss-commit-provenance: no mode selected" >&2
exit 2
