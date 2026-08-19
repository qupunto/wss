#!/usr/bin/env bash
# Survey every adopted tree under one or more roots, then roll the results up
# into a surface-to-candidate mapping. Read-only: it writes nothing into any
# tree it surveys, and its per-tree output is `wss-tree-survey.sh`'s verbatim.
#
#   wss-survey-all.sh ~/projects
#   wss-survey-all.sh -o ~/surveys ~/projects ~/work /mnt/c/src
#   wss-survey-all.sh --no-gh --depth 6 ~/projects
#
# !important — THE OUTPUT IS LOCAL-ONLY. NEVER ROUTE IT UPSTREAM.
# Everything `wss-tree-survey.sh`'s header says applies here and applies more:
# this file names EVERY private project on the machine at once, with paths,
# branches, remotes and record layouts. `--wss-report` opens issues on a PUBLIC
# repository and publishing is irreversible. So do not pass this through
# `--wss-report`, `gh issue create`, or any other transport; do not paste it
# into a repository's records. Read it in a session, or keep it beside nothing.
#
# WHY A WALKER EXISTS SEPARATELY FROM THE SURVEYOR. The surveyor answers "what
# does THIS tree declare" and is deliberately finite. The question the roadmap
# actually asks — "which surfaces have a tree that can exercise them, and which
# have none" — is a question about a POPULATION, and cannot be answered by
# reading one survey at a time without the two errors below.
#
# ERROR ONE, AND THE REASON THE GROUPING COLUMN EXISTS: a worktree is not a
# project. Six directories sharing one checkout read as six candidates in a
# directory listing and are one tree that can be exercised once. This was not
# hypothetical — the first hand-run mapping counted six and the answer was one,
# and it is invisible from the names, which look like separate projects. So
# every count printed below is a count of PROJECTS, grouped by resolved git
# common directory, and the per-tree table shows which group each row is in.
#
# ERROR TWO: a probe that could not run prints nothing, and nothing reads as a
# clean result. A tree whose doctor never executed is not a passing tree, and a
# repository `gh` could not read has an UNKNOWN TODO list rather than a file one —
# which matters exactly here, because "the Issues provider has no candidate" is
# a conclusion drawn from TODO list rows. Every unread probe is therefore carried
# into the summary as a flag rather than left as an absence.
#
# WHAT IT STILL CANNOT ANSWER, and says so rather than guessing: whether a
# project is winding down. `/wss:retire` can only be exercised at the end of a
# tree's life with the suite, no manifest key records that intent, and inferring
# it from a quiet repository would be a fabricated candidate. The rollup prints
# that surface with its detection stated as impossible.

set -u

OUT=""
DEPTH=4
PASS=""
ROOTS=()

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  echo
  echo "  -o <dir>     where to write one survey per tree (default: \$PWD/wss-surveys)"
  echo "  --depth <n>  how deep under each root to look for .claude/ (default: 4)"
  echo "  --no-gh      passed through: skip the TODO list probe"
  echo "  --no-doctor  passed through: skip the doctor run"
}

while [ $# -gt 0 ]; do
  case $1 in
    -o)          shift; OUT=${1:?-o needs a path} ;;
    --depth)     shift; DEPTH=${1:?--depth needs a number} ;;
    --no-gh)     PASS="$PASS --no-gh" ;;
    --no-doctor) PASS="$PASS --no-doctor" ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "wss-survey-all.sh: unknown argument '$1'" >&2; exit 2 ;;
    *)           ROOTS+=("$1") ;;
  esac
  shift
done

# No default root. The throwaway this replaces hardcoded one person's projects
# directory, which is the single thing that made it unshippable — a walker that
# silently searches somewhere the caller did not name either finds nothing and
# reports an empty machine, or wanders into a tree nobody meant to survey.
if [ "${#ROOTS[@]}" -eq 0 ]; then
  echo "wss-survey-all.sh: name at least one root directory to walk" >&2
  echo "  wss-survey-all.sh ~/projects" >&2
  exit 2
fi

case "$DEPTH" in ''|*[!0-9]*) echo "wss-survey-all.sh: --depth wants a number" >&2; exit 2 ;; esac

# ---------------------------------------------------------------- resolution --

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SURVEY=""
for cand in "$SELF_DIR/wss-tree-survey.sh" "$CONFIG_DIR/wss-tree-survey.sh"; do
  [ -f "$cand" ] && { SURVEY="$cand"; break; }
done
if [ -z "$SURVEY" ]; then
  SURVEY=$(ls -1 "$CONFIG_DIR"/plugins/cache/*/*/*/wss-tree-survey.sh 2>/dev/null | tail -1)
fi
[ -n "$SURVEY" ] || {
  echo "wss-survey-all.sh: wss-tree-survey.sh not found beside this script, in" >&2
  echo "  $CONFIG_DIR, or in the plugin cache. Nothing to drive." >&2
  exit 2
}

TIMEOUT=""
command -v timeout >/dev/null 2>&1 && TIMEOUT="timeout 180"
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

[ -n "$OUT" ] || OUT="$PWD/wss-surveys"
mkdir -p "$OUT" || exit 2
OUT="$(cd "$OUT" && pwd -P)"

# ----------------------------------------------------------------- discovery --

TREES=()
for root in "${ROOTS[@]}"; do
  if [ ! -d "$root" ]; then
    echo "wss-survey-all.sh: no such root '$root' — skipped" >&2
    continue
  fi
  root="$(cd "$root" && pwd -P)"
  # BOTH manifest filenames. Matching only the current name is what makes a
  # pre-rename tree invisible to a walker, and a legacy tree is the one thing
  # the migration surface has been waiting for — the population where it is
  # most costly to miss a member.
  while IFS= read -r c; do
    [ -f "$c/WSS.WORKFLOW.json" ] || [ -f "$c/workflow.json" ] || continue
    TREES+=("$(dirname "$c")")
  done < <(find "$root" -maxdepth "$DEPTH" \
             \( -name node_modules -o -name .venv -o -name vendor -o -name .cache \) -prune -o \
             -type d -name .claude -print 2>/dev/null | sort)
done

if [ "${#TREES[@]}" -eq 0 ]; then
  echo "No adopted tree found under: ${ROOTS[*]} (depth $DEPTH)"
  echo "That is a finding, not an error — nothing on this machine declares a manifest."
  exit 0
fi

# A survey written inside its own subject would be picked up by that project's
# git status and by the next walk. The surveyor refuses this for itself; the
# walker has to refuse it for every tree it is about to visit, before it writes
# the first file.
for t in "${TREES[@]}"; do
  case "$OUT/" in
    "$t"/*|"$t"/)
      echo "wss-survey-all.sh: -o '$OUT' is inside a tree to be surveyed ($t)." >&2
      echo "  Point it outside every root, or the survey writes into its subject." >&2
      exit 2 ;;
  esac
done

# ------------------------------------------------------------------ grouping --

# Resolved git common directory: identical for a checkout and all of its
# worktrees, distinct for two separate clones. `--git-common-dir` returns a
# relative path on older git when asked from the tree root, so it is resolved
# against the tree rather than against $PWD.
common_dir() {
  local d
  d=$(git -C "$1" rev-parse --git-common-dir 2>/dev/null) || return 1
  case $d in /*) ;; *) d="$1/$d" ;; esac
  (cd "$d" 2>/dev/null && pwd -P)
}

TREE_PROJ=()     # per tree: group id, or "-" for a non-checkout
ORIGIN=()    # per tree: origin url, or ""
PROJ_IDS=()    # distinct group ids, in first-seen order
for t in "${TREES[@]}"; do
  g=$(common_dir "$t") || g=""
  [ -n "$g" ] || g="-no-git-$t"
  TREE_PROJ+=("$g")
  ORIGIN+=("$(git -C "$t" remote get-url origin 2>/dev/null || true)")
  seen=0
  for h in ${PROJ_IDS[@]+"${PROJ_IDS[@]}"}; do [ "$h" = "$g" ] && { seen=1; break; }; done
  [ "$seen" -eq 0 ] && PROJ_IDS+=("$g")
done

group_index() { local i=0 h; for h in "${PROJ_IDS[@]}"; do i=$((i+1)); [ "$h" = "$1" ] && { echo "$i"; return; }; done; echo 0; }

# ------------------------------------------------------------------ surveying --

echo "surveying ${#TREES[@]} tree(s) in ${#PROJ_IDS[@]} project(s) -> $OUT"
FILES=()
RCS=()
for i in "${!TREES[@]}"; do
  t="${TREES[$i]}"
  base="$(basename "$t")"; f="$base.txt"; n=2
  while [ -f "$OUT/$f" ]; do f="$base-$n.txt"; n=$((n+1)); done
  # rc is captured on the line after the run and nowhere else. The throwaway
  # this replaces printed `exit=$?` after a `wc -l` substitution, so every row
  # reported wc's status and every survey looked like it had succeeded.
  ( cd "$t" && $TIMEOUT bash "$SURVEY" $PASS ) > "$OUT/$f" 2>&1
  RCS+=("$?")
  FILES+=("$f")
done

# --------------------------------------------------------------------- flags --

# Each flag means "this row's evidence was not read", never "this row is bad".
flags_for() {
  local p="$OUT/$1" out=""
  grep -qF 'NOT FOUND' "$p" && out="${out}D"
  grep -qF 'doctor exit' "$p" && grep -q 'doctor exit .*FAILED' "$p" && case $out in *D*) ;; *) out="${out}D" ;; esac
  grep -qF -- '--no-doctor' "$p" && case $out in *D*) ;; *) out="${out}d" ;; esac
  grep -qF 'COULD NOT READ' "$p" && out="${out}B"
  grep -qF 'gh not installed' "$p" && case $out in *B*) ;; *) out="${out}B" ;; esac
  grep -qF -- '--no-gh' "$p" && case $out in *B*|*b*) ;; *) out="${out}b" ;; esac
  grep -qF 'jq not installed' "$p" && out="${out}J"
  grep -qF 'NOT INSTALLED' "$p" && case $out in *J*) ;; *) out="${out}J" ;; esac
  grep -q '^  MISSING' "$p" && out="${out}M"
  grep -qF 'PRE-RENAME' "$p" && out="${out}L"
  [ -n "$out" ] || out="-"
  printf '%s' "$out"
}

printf '\n=== trees ===\n'
printf '  %-3s %-28s %-5s %-4s %s\n' "prj" "tree" "flags" "exit" "survey"
for i in "${!TREES[@]}"; do
  printf '  %-3s %-28s %-5s %-4s %s\n' \
    "$(group_index "${TREE_PROJ[$i]}")" "$(basename "${TREES[$i]}")" \
    "$(flags_for "${FILES[$i]}")" "${RCS[$i]}" "${FILES[$i]}"
done
cat <<'LEGEND'
  flags  D doctor unread (not found / failed)   d doctor skipped by request
         B TODO list UNKNOWN (gh could not read)  b TODO list probe skipped
         J jq missing — every manifest row in that survey is unread, not empty
         M a declared record file does not exist
         L pre-rename manifest filename — this tree is on legacy conventions
  An unread probe is not a clean result. A B row cannot support any claim
  about that project's TODO list, including "it uses a file".
LEGEND

# The representative of a group is its MAIN checkout — the tree whose own
# `.git` is the shared common directory — and only a member in first-seen order
# when no main checkout was walked. Labelling a group by whichever member sorted
# first names a lane worktree as the candidate, which reads as a project that
# does not exist and sends a later reader to the wrong directory.
rep_of() {
  local g=$1 i fallback=""
  for i in "${!TREES[@]}"; do
    [ "${TREE_PROJ[$i]}" = "$g" ] || continue
    [ "${TREE_PROJ[$i]}" = "${TREES[$i]}/.git" ] && { echo "$i"; return; }
    [ -n "$fallback" ] || fallback="$i"
  done
  echo "$fallback"
}

# Two clones of one project are two trees and one candidate, the same as two
# worktrees are — so a shared origin across distinct groups is called out.
printf '\n=== projects ===\n'
for g in "${PROJ_IDS[@]}"; do
  idx=$(group_index "$g"); members=""; r=$(rep_of "$g")
  for i in "${!TREES[@]}"; do
    [ "${TREE_PROJ[$i]}" = "$g" ] || continue
    if [ "$i" = "$r" ]; then members="$members $(basename "${TREES[$i]}")*"
    else members="$members $(basename "${TREES[$i]}")"; fi
  done
  printf '  %-3s %s\n' "$idx" "${ORIGIN[$r]:-(no origin remote)}"
  printf '      %s\n' "$(echo "$members" | sed 's/^ //')"
done
echo "  * = the main checkout, and the tree every surface below is read from."

# ------------------------------------------------------------------- rollup --

# The rollup reads each project's MANIFEST rather than parsing the survey text
# above. Two readers of one fact drift, and the text is prose meant for a human;
# a mapping that decides whether a roadmap block has a candidate should not rest
# on a printf format staying still.
printf '\n=== surface -> candidates (%s project(s)) ===\n' "${#PROJ_IDS[@]}"
if [ "$HAVE_JQ" -eq 0 ]; then
  echo "  jq is NOT INSTALLED — no surface below can be evaluated. This is"
  echo "  unread, not zero candidates. Install jq and re-run."
else
  REPS=()
  for g in "${PROJ_IDS[@]}"; do REPS+=("${TREES[$(rep_of "$g")]}"); done

  # surface label | jq test over (.WSS // .)
  surface() {
    local label=$1 test=$2 hits=0 names=""
    for t in "${REPS[@]}"; do
      local mf=""
      [ -f "$t/.claude/WSS.WORKFLOW.json" ] && mf="$t/.claude/WSS.WORKFLOW.json"
      [ -z "$mf" ] && [ -f "$t/.claude/workflow.json" ] && mf="$t/.claude/workflow.json"
      [ -n "$mf" ] || continue
      if jq -e "(.WSS // .) as \$w | $test" "$mf" >/dev/null 2>&1; then
        hits=$((hits+1)); names="$names $(basename "$t")"
      fi
    done
    if [ "$hits" -eq 0 ]; then
      printf '  %-34s %s\n' "$label" "NO CANDIDATE — not a delayed one"
    else
      printf '  %-34s %d: %s\n' "$label" "$hits" "$(echo "$names" | sed 's/^ //')"
    fi
  }

  surface "lanes / lane-record-sync"   '($w.lanes.named // {} | length) > 0'
  surface "describe"               '$w.record.behaviour != null'
  surface "reference"              '$w.record.reference != null'
  surface "Issues TODO list provider"    '($w.record.todo | type) == "object"'
  surface "WSS.localCI"                '$w.localCI != null'
  surface "release + changelog"        '$w.record.releases != null and $w.record.changelog != null'
  surface "pr (integration!=publish)" '$w.branch.integration != null and $w.branch.integration != $w.branch.publish'

  # Migration is not a jq row over `$w`, and the first draft of it was wrong in
  # the direction that matters. `$w` is already the unwrapped root, so asking
  # `$w | has("WSS")` asks whether the INNER object nests a second time — false
  # for every current manifest — and every tree on current conventions reported
  # as a migration candidate. A tree that adopted natively has nothing to
  # migrate, so the test is the two pre-rename shapes and nothing else: the old
  # FILENAME, or flat keys with no `WSS` root.
  hits=0; names=""
  for t in "${REPS[@]}"; do
    if [ -f "$t/.claude/workflow.json" ] && [ ! -f "$t/.claude/WSS.WORKFLOW.json" ]; then
      hits=$((hits+1)); names="$names $(basename "$t")"
    elif [ -f "$t/.claude/WSS.WORKFLOW.json" ] &&
         ! jq -e 'has("WSS")' "$t/.claude/WSS.WORKFLOW.json" >/dev/null 2>&1; then
      hits=$((hits+1)); names="$names $(basename "$t") (flat schema)"
    fi
  done
  if [ "$hits" -eq 0 ]; then
    printf '  %-34s %s\n' "update migration" "NO CANDIDATE — every tree walked is already"
    printf '  %-34s %s\n' "" "on current conventions and has nothing to migrate."
  else
    printf '  %-34s %d: %s\n' "update migration" "$hits" "$(echo "$names" | sed 's/^ //')"
  fi

  # Two surfaces are deliberately not jq rows. The docs shape is a property of
  # the tree rather than of its manifest, and retire has no property at all.
  hits=0; names=""
  for t in "${REPS[@]}"; do
    if [ -f "$t/wss/docs/index.html" ] || [ -f "$t/wss/docs/_sidebar.md" ] || [ -f "$t/wss/docs/index.md" ] || \
       [ -f "$t/docs/index.html" ] || [ -f "$t/docs/_sidebar.md" ] || [ -f "$t/docs/index.md" ]; then
      hits=$((hits+1)); names="$names $(basename "$t")"
    fi
  done
  if [ "$hits" -eq 0 ]; then
    printf '  %-34s %s\n' "docs site / workflow page" "NO CANDIDATE — not a delayed one"
  else
    printf '  %-34s %d: %s\n' "docs site / workflow page" "$hits" "$(echo "$names" | sed 's/^ //')"
  fi
  printf '  %-34s %s\n' "/wss:retire" "NOT DETECTABLE — no key records intent."
  printf '  %-34s %s\n' "" "Ask each project by hand; a quiet repo is not a"
  printf '  %-34s %s\n' "" "winding-down one, and guessing invents a candidate."
fi

printf '\n=== reminder ===\n'
echo "  LOCAL ONLY. This names every private tree on the machine. Do not open an"
echo "  issue with it and do not route it through \`--wss-report\`: qupunto/wss is public."
