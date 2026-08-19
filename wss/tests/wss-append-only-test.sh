#!/usr/bin/env bash
# Contract test for wss-append-only.sh's exemption 3 (the draft entry at
# either end, rewritten rather than excised) under a hunk that adds MORE
# THAN ONE entry at once — the case a single-heading anchor mis-judges.
#
# Builds a throwaway git repo, never touching this checkout's own git state.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Overridable so the suite can be pointed at another build of the guard —
# `git show <ref>:wss/scripts/wss-append-only.sh` to a temp file, then run this
# with WSS_APPEND_ONLY_BIN set. That is how `append_many` below was shown to
# fail before the fix and pass after; without it a regression case can only be
# asserted, never demonstrated.
SCRIPT="${WSS_APPEND_ONLY_BIN:-$HERE/wss/scripts/wss-append-only.sh}"

REPO=$(mktemp -d)
trap 'rm -rf "$REPO"' EXIT

export GIT_AUTHOR_NAME=wss-test GIT_AUTHOR_EMAIL=wss-test@example.com
export GIT_COMMITTER_NAME=wss-test GIT_COMMITTER_EMAIL=wss-test@example.com

git -c init.defaultBranch=main init -q "$REPO"

mkdir -p "$REPO/.claude"
cat > "$REPO/.claude/WSS.WORKFLOW.json" <<'JSON'
{
  "WSS": {
    "record": {
      "changelog": "log.md"
    },
    "recordMode": {
      "changelog": "log"
    }
  }
}
JSON

cat > "$REPO/log.md" <<'MD'
# Log

Header.

## Entry 1
Body one.

## Entry 2
Body two.

## Entry 3
Body three.
MD

git -C "$REPO" add -A
git -C "$REPO" commit -q -m base

append_one_mut() {
  printf '\n## Entry 4\nBody four.\n' >> "$REPO/log.md"
}

append_many_mut() {
  printf '\n## Entry 4\nBody four.\n\n## Entry 5\nBody five.\n\n## Entry 6\nBody six.\n\n## Entry 7\nBody seven.\n' \
    >> "$REPO/log.md"
}

prepend_many_mut() {
  awk '
    /^## Entry 1/ && !done {
      print "## New 1"; print "Body new one."; print ""
      print "## New 2"; print "Body new two."; print ""
      print "## New 3"; print "Body new three."; print ""
      print "## New 4"; print "Body new four."; print ""
      done = 1
    }
    { print }
  ' "$REPO/log.md" > "$REPO/log.md.tmp"
  mv "$REPO/log.md.tmp" "$REPO/log.md"
}

body_edit_mut() {
  sed -i 's/^Body two\.$/Body two modified./' "$REPO/log.md"
}

# The one that proves the widened anchor did not blunt the guard: four new
# entries appended AND a line smuggled into the body of the entry that used to
# be the tail. The whole risk of anchoring on the START of the appended run
# rather than its last heading is that everything below the anchor goes exempt;
# this case is what says it does not. Measured 2026-08-16: caught as one line,
# attributed to "## Entry 3".
append_many_smuggle_mut() {
  sed -i 's/^Body three\.$/Body three.\nSMUGGLED into the old tail entry./' "$REPO/log.md"
  append_many_mut
}

# The head-side counterpart of append_many_smuggle: entries added at the HEAD
# while a line is smuggled into the body of the entry that used to be the head.
# Measured 2026-08-17: caught, attributed to "## Entry 1".
#
# It is a real head-branch case and it is NOT the discriminating one the TODO
# list asked for — it behaves identically against aa1df86's build and
# c4ba710's. That is not an oversight in the case; see the test-coverage entry
# in the TODO list, which records why no CORRECT discriminating case exists.
smuggle_head_mut() {
  perl -0pi -e 's/^## Entry 1\n/## New A\nBody new a.\n\n## New B\nBody new b.\n\n## Entry 1\n/m' "$REPO/log.md"
  perl -0pi -e 's/^Body one\.\n/Body one.\nSMUGGLED into the old head entry.\n/m' "$REPO/log.md"
}

# The negative control both end-exemptions need: an ordinary append at the tail
# alongside a line smuggled into a MIDDLE entry, which no end-of-record
# exemption may ever cover however the anchors are computed.
smuggle_middle_mut() {
  perl -0pi -e 's/^Body two\.\n/Body two.\nSMUGGLED into a middle entry.\n/m' "$REPO/log.md"
  printf '\n## Entry 4\nBody four.\n' >> "$REPO/log.md"
}

# ---- growth at BOTH ends in one change ----------------------------------
#
# The arrangement no earlier case reached, and the one where anchoring on TOTAL
# growth failed open at both ends: with one entry added at the head and one at
# the tail, `post_starts[grown]` slid past the old head entry and
# `post_starts[pre_entries]` slid above the old tail entry, so a line smuggled
# into either was exempted. All four below are measured against `c4ba710`'s
# build via WSS_APPEND_ONLY_BIN — the two `fail` cases PASS against it, which is
# what makes them regression tests rather than assertions.

# Legitimate: both ends grow and nothing else is touched. Guards the fix
# against over-refusing, which is the direction that would break every record
# commit rather than one test.
grow_both_ends_mut() {
  perl -0pi -e 's/^## Entry 1\n/## New Head\nBody new head.\n\n## Entry 1\n/m' "$REPO/log.md"
  printf '\n## Entry 4\nBody four.\n' >> "$REPO/log.md"
}

# The head half of the false accept.
smuggle_head_both_ends_mut() {
  perl -0pi -e 's/^## Entry 1\n/## New Head\nBody new head.\n\n## Entry 1\n/m' "$REPO/log.md"
  perl -0pi -e 's/^Body one\.\n/Body one.\nSMUGGLED into the old head entry.\n/m' "$REPO/log.md"
  printf '\n## Entry 4\nBody four.\n' >> "$REPO/log.md"
}

# The tail half. Same shape mirrored, because one anchor being wrong says
# nothing about the other and each is computed independently.
smuggle_tail_both_ends_mut() {
  perl -0pi -e 's/^## Entry 1\n/## New Head\nBody new head.\n\n## Entry 1\n/m' "$REPO/log.md"
  perl -0pi -e 's/^Body three\.\n/Body three.\nSMUGGLED into the old tail entry.\n/m' "$REPO/log.md"
  printf '\n## Entry 4\nBody four.\n' >> "$REPO/log.md"
}

# The end a record grows at is DECLARED, not inferred, and only the entry at
# that end is ever the draft. This case asserted the opposite until 2026-08-18 —
# that a head entry stayed a draft while the tail grew — which was correct while
# the guard had to allow either end, because nothing told it which one grew.
# The owner then ruled direction a property of the record: add without modifying
# what is there, always at the same end, so prepend and append are one rule
# rather than a rule plus an exemption. Decision log, 2026-08-18 (twenty-fourth).
#
# This fixture declares no direction, so it grows at the tail and its head is
# sealed. Same mutation as before; the expectation is inverted.
head_sealed_under_tail_growth_mut() {
  perl -0pi -e 's/^Body one\.\n/Body one.\nThe head draft is still being drafted.\n/m' "$REPO/log.md"
  printf '\n## Entry 4\nBody four.\n' >> "$REPO/log.md"
}

# ...and the same rewrite is exempt once the record says it grows at the head.
# This is the changelog: newest first, by the convention its readers expect.
head_draft_when_head_declared_mut() {
  perl -0pi -e 's/"changelog": "log"/"changelog": {"mode":"log","grows":"head"}/' \
    "$REPO/.claude/WSS.WORKFLOW.json"
  perl -0pi -e 's/^Body one\.\n/Body one.\nThe head draft is still being drafted.\n/m' "$REPO/log.md"
}

fails=0

run_case() {
  local name="$1" want="$2" mutator="$3"
  local branch="case-$name"
  git -C "$REPO" checkout -q -b "$branch" main
  "$mutator"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "$name"

  local rc=0 out
  out=$(bash "$SCRIPT" --dir "$REPO" --range "main..$branch" 2>&1) || rc=$?
  git -C "$REPO" checkout -q main
  git -C "$REPO" branch -q -D "$branch"

  if { [ "$want" = pass ] && [ "$rc" -eq 0 ]; } || { [ "$want" = fail ] && [ "$rc" -ne 0 ]; }; then
    echo "PASS $name (exit $rc, wanted $want)"
  else
    echo "FAIL $name (exit $rc, wanted $want)"
    printf '%s\n' "$out"
    fails=$((fails + 1))
  fi
}

run_case append_one   pass append_one_mut
run_case append_many  pass append_many_mut
# NOT a test of exemption 3's head branch, despite the name. Measured
# 2026-08-16: with the new entries added above the first `## ` heading, the
# hunk's pre-image start lands ABOVE that heading, so exemption 1 (the header,
# everything above the first entry) takes it and the head anchor is never
# consulted. It passes against the pre-fix script too. Kept because a
# newest-first record must not start failing, but it discriminates nothing —
# `post_old_head` has no case here that fails without it. See the test-coverage
# entry in the TODO list.
run_case prepend_many pass prepend_many_mut
run_case body_edit    fail body_edit_mut
run_case append_many_smuggle fail append_many_smuggle_mut
run_case smuggle_head   fail smuggle_head_mut
run_case smuggle_middle fail smuggle_middle_mut
run_case grow_both_ends pass grow_both_ends_mut
run_case smuggle_head_both_ends fail smuggle_head_both_ends_mut
run_case smuggle_tail_both_ends fail smuggle_tail_both_ends_mut
run_case head_sealed_under_tail_growth  fail head_sealed_under_tail_growth_mut
run_case head_draft_when_head_declared  pass head_draft_when_head_declared_mut

if [ "$fails" -eq 0 ]; then
  echo "wss-append-only-test: all 12 cases behaved as required"
  exit 0
else
  echo "wss-append-only-test: $fails case(s) did not behave as required"
  exit 1
fi
