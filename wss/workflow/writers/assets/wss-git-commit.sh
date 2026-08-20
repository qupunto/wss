#!/usr/bin/env bash
# The sole mechanism that stages, commits and (optionally) pushes on behalf
# of git-writer (../WSS.GIT-WRITER.md), which is the sole writer of commits
# and tags per wss/workflow/WSS.OWNERSHIP.md. Callers hand it facts; it makes no
# project or session assumption of its own — every fact that could differ
# between projects or between runs is an argument, never a default read from
# this file.
#
#   wss-git-commit.sh --files PATH [--files PATH ...] --message MSG \
#     --session ID --coauthor "Name <email>" --trailer-key KEY [--push REFSPEC]
#
#   wss-git-commit.sh --push-only REFSPEC
#
# The second form is the whole reason a push-only mode exists: a wrap that
# follows `--wss-start` (which commits each lane as it lands) can have
# nothing left to stage and still owe a push. It stages nothing, commits
# nothing, and skips trailer verification — see "Why push-only does not
# verify a trailer" below — then applies the same leading-`+` refusal and
# rejected-push handling as the commit-then-push form. It takes no other
# flag; combining it with --files/--message/--session/--coauthor/
# --trailer-key/--push is a usage error (nothing touched).
#
# Four structural guarantees — not conventions a caller could forget, but
# shapes the shell itself enforces:
#
#   1. Staging is always by exact name. `git add -- "${files[@]}"` — the `--`
#      ends option parsing (so a name starting with `-` cannot read as a
#      flag) and the array holds literal names with no glob expansion
#      performed here. There is no `-A`, no `.`, nothing meaning "everything"
#      for a caller to reach for even by habit.
#   2. The trailer paragraph is verified after the commit lands, with the
#      same `%(trailers:key=…)` query a reader would run, rather than
#      trusted because the message was assembled correctly above it.
#   3. A push refspec with a leading `+` is refused before it reaches git —
#      never a force-push by construction.
#   4. A rejected push is reported and this script exits nonzero. It is
#      never retried and never resolved with force; that is a merge decision
#      for the caller, per WSS.GIT-WRITER.md's "Pushes" section.
#
# The session id and the Co-Authored-By line are ARGUMENTS. Do not default
# or hardcode either here — a model name written into shared machinery is
# wrong the moment the model changes, and wrong in a way nothing detects
# (WSS.GIT-WRITER.md, "Do not copy a model name out of this file"). The same
# reasoning extends to the trailer key: it is `WSS.commitTrailer` in the
# CALLER's manifest, and an adopted tree is free to name it differently, so
# this script does not assume "Claude-Session" either.
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: wss-git-commit.sh --files PATH [--files PATH ...] --message MSG \
         --session ID --coauthor "Name <email>" --trailer-key KEY \
         [--push REFSPEC] [--writer NAME]

       wss-git-commit.sh --push-only REFSPEC

  --files PATH     One file to stage, by exact name. Repeat for more than
                    one. Never a glob, never a directory meaning "everything
                    in it" — each occurrence is one pathspec passed straight
                    to `git add --`.
  --message MSG    The commit subject/body — the why. Do not put trailers
                    in it; they are assembled from the flags below.
  --session ID     This session's id (the first block, from the scratchpad
                    path). Becomes the trailer's value. Never hardcode this.
  --coauthor LINE  The Co-Authored-By line the harness supplied for THIS
                    run. Never hardcode a model name here or in the caller.
  --trailer-key K  The trailer name — read it from the calling project's
                    manifest (`WSS.commitTrailer`), never assumed here.
  --refs VALUE     Optional. What this commit is work on — a tracker id, or
                    this suite's own `Cycle-N`. Emitted as a `Refs:` footer
                    beside the session trailer, per the commit profile that
                    adopted the field. A TRANSCRIPTION of something the caller
                    already has in hand, never a second list to keep: absent
                    means absent, and no empty footer is written.
  --writer NAME    The primitive or skill whose authority this commit's
                    record writes are made under, verbatim as the ownership
                    matrix spells it (record, writers/WSS.HANDOFF-WRITER.md).
                    Becomes the WSS_WRITER environment variable. The value is
                    the caller's, never assumed by this procedure.
  --push REFSPEC   Push after committing, as `git push origin REFSPEC`.
                    Omit to commit only. REFSPEC may not start with `+`.
                    This flag is never a default a caller falls into — the
                    grant to push is always the caller's to have already
                    obtained (WSS.GIT-WRITER.md, "The grant is the caller's,
                    always").
  --push-only REFSPEC
                    Push REFSPEC without staging or committing anything —
                    for the case where everything is already committed and
                    only the push is owed (e.g. a wrap after --wss-start,
                    which commits each lane as it lands). Mutually exclusive
                    with every other flag: this script does not stage
                    "nothing in particular" alongside a real commit request.
                    Same leading-`+` refusal and rejected-push handling as
                    --push; no trailer is verified — see the top-of-file
                    comment for why. REFSPEC may not start with `+`. The
                    grant to push is still always the caller's to have
                    already obtained.

Exit codes: 0 success. 2 bad arguments (nothing touched). 1 the commit or
the push did not go through — see stderr for which and why.
USAGE
  exit 2
}

files=()
message=
session=
coauthor=
trailer_key=
writer=
refs=
push_refspec=
do_push=0
push_only_refspec=
do_push_only=0

while [ $# -gt 0 ]; do
  case "$1" in
    --files)
      [ $# -ge 2 ] || usage
      files+=("$2")
      shift 2
      ;;
    --message)
      [ $# -ge 2 ] || usage
      message=$2
      shift 2
      ;;
    --session)
      [ $# -ge 2 ] || usage
      session=$2
      shift 2
      ;;
    --coauthor)
      [ $# -ge 2 ] || usage
      coauthor=$2
      shift 2
      ;;
    --trailer-key)
      [ $# -ge 2 ] || usage
      trailer_key=$2
      shift 2
      ;;
    --writer)
      [ $# -ge 2 ] || usage
      writer=$2
      shift 2
      ;;
    --refs)
      [ $# -ge 2 ] || usage
      refs=$2
      shift 2
      ;;
    --push)
      [ $# -ge 2 ] || usage
      push_refspec=$2
      do_push=1
      shift 2
      ;;
    --push-only)
      [ $# -ge 2 ] || usage
      push_only_refspec=$2
      do_push_only=1
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "wss-git-commit.sh: unrecognized argument: $1" >&2
      usage
      ;;
  esac
done

# do_push_and_exit REFSPEC : the leading-`+` refusal and rejected-push
# handling shared by --push (after a commit) and --push-only (with no
# commit of this call's own). Never called with a force refspec by
# construction; never retried or resolved with force on rejection.
do_push_and_exit() {
  local refspec=$1
  case "$refspec" in
    +*)
      echo "wss-git-commit.sh: refusing a push refspec with a leading '+' ('${refspec}') — this script never force-pushes." >&2
      exit 2
      ;;
  esac
  if ! git push origin "$refspec"; then
    echo "wss-git-commit.sh: push rejected (origin ${refspec}). Not retried and not forced — hand this back to the caller as a merge decision." >&2
    exit 1
  fi
  exit 0
}

# --- --push-only: nothing staged, nothing committed, no trailer check -------
# Why no trailer verification here: this script is the sole path to a commit
# in this repo (WSS.OWNERSHIP.md), so every commit already on the branch
# passed the SAME %(trailers:...) check at the moment it was made — a lane
# commit from --wss-start, for instance, was verified then. Re-checking HEAD
# here would only re-verify the tip of whatever range is being pushed, not
# the range itself, and would misfire on a HEAD that is a merge or tag
# commit carrying no trailer of its own even though every commit behind it
# is sound. Push-only trusts the commits it did not make because each one
# was checked when IT was made, not because checking is skipped as a matter
# of principle.
if [ "$do_push_only" -eq 1 ]; then
  if [ ${#files[@]} -gt 0 ] || [ -n "$message" ] || [ -n "$session" ] ||
     [ -n "$coauthor" ] || [ -n "$trailer_key" ] || [ "$do_push" -eq 1 ]; then
    echo "wss-git-commit.sh: --push-only is exclusive of --files/--message/--session/--coauthor/--trailer-key/--push" >&2
    exit 2
  fi
  do_push_and_exit "$push_only_refspec"
fi

[ ${#files[@]} -gt 0 ] || {
  echo "wss-git-commit.sh: at least one --files is required — this script never stages by any other means" >&2
  exit 2
}
[ -n "$message" ] || { echo "wss-git-commit.sh: --message is required" >&2; exit 2; }
[ -n "$session" ] || { echo "wss-git-commit.sh: --session is required" >&2; exit 2; }
[ -n "$coauthor" ] || { echo "wss-git-commit.sh: --coauthor is required" >&2; exit 2; }
[ -n "$trailer_key" ] || { echo "wss-git-commit.sh: --trailer-key is required" >&2; exit 2; }

# --- stage by name, structurally --------------------------------------------
# `--` ends option parsing, so a file named e.g. `-weird` or one starting
# with a glob character is a pathspec here and never a flag or a shell
# expansion. The array came from repeated --files occurrences, each already
# a literal string by the time bash split argv — nothing here re-globs it.
git add -- "${files[@]}"

# A REFUSED COMMIT MUST NOT LEAVE THE INDEX STAGED. `set -e` aborts this script
# the moment `git commit` is rejected — by the provenance guard, the append-only
# guard, or any other pre-commit hook — but the `git add` above has already run,
# so without this the staged set OUTLIVES the failure. The next invocation then
# commits its own `--files` PLUS whatever the refused one left behind, under the
# new call's authority, and `--files` exists precisely so nothing can reach for
# a file it did not name. Observed 2026-08-19: a provenance refusal left a
# record staged, and the following narrower commit inherited it.
#
# Only what THIS invocation staged is reset, never the whole index — a caller
# that staged something itself keeps it. `|| true` covers the no-HEAD case,
# where `git reset -- <path>` has nothing to reset against.
committed=0
trap '[ "$committed" -eq 1 ] || git reset -q -- "${files[@]}" 2>/dev/null || true' EXIT

# --- assemble the message ---------------------------------------------------
# Body, one blank line, then the trailer paragraph with NO blank line
# between its two lines. Git parses only the LAST paragraph of a message as
# trailers; a stray blank line demotes Co-Authored-By to ordinary body text
# and the verification query below finds nothing (WSS.GIT-WRITER.md, "Git
# parses only the last paragraph of a message as trailers").
tmp_msg=$(mktemp)
trap 'rm -f "$tmp_msg"; [ "$committed" -eq 1 ] || git reset -q -- "${files[@]}" 2>/dev/null || true' EXIT

{
  printf '%s\n' "$message"
  printf '\n'
  [ -n "$refs" ] && printf 'Refs: %s\n' "$refs"
  printf '%s: %s\n' "$trailer_key" "$session"
  printf 'Co-Authored-By: %s\n' "$coauthor"
} >"$tmp_msg"

if [ -n "$writer" ]; then
  export WSS_WRITER="$writer"
fi
git commit -F "$tmp_msg"
committed=1

# --- verify the trailer actually parsed -------------------------------------
# Checked with the same query a reader would run, rather than assumed correct
# because the paragraph above looks right. An empty result means the commit
# that just landed cannot be told apart from another session's — treat that
# as fatal rather than a warning, and stop before any push.
got=$(git log -1 --format="%(trailers:key=${trailer_key},valueonly)")
if [ -z "$got" ]; then
  echo "wss-git-commit.sh: the commit landed but %(trailers:key=${trailer_key},valueonly) came back empty — the trailer paragraph did not parse. Not pushing." >&2
  exit 1
fi
if [ "$got" != "$session" ]; then
  echo "wss-git-commit.sh: trailer mismatch — wrote '${session}', %(trailers:...) reads back '${got}'. Not pushing." >&2
  exit 1
fi

# --- push, only if asked ----------------------------------------------------
if [ "$do_push" -eq 1 ]; then
  do_push_and_exit "$push_refspec"
fi
