#!/usr/bin/env bash
# Contract tests for the suite's executables — the hooks, wss-doctor.sh, the
# operational scripts (publish, reset/export/retire) and the skill asset scripts.
#
#   ~/.claude/tests/wss-hook-contract.sh
#
# Runs anywhere, needs only bash and jq, touches nothing outside a temp dir.
#
# Why this exists: a syntax error or a bad case label in that hook breaks EVERY
# flag at once, silently — the hook exits non-zero, Claude Code carries on, and
# each flag quietly degrades to being matched from a skill description. There is
# no symptom to notice. The hook was also edited several times with no way to
# check it beyond firing flags by hand and reading the output.
#
# Every test sets HOME to an empty directory. Without that, skill_exists() finds
# the real ~/.claude/skills and the gating tests pass for the wrong reason on a
# machine where this repo is installed — which is every machine that matters.

set -u

# The hooks moved to `hooks/` on 2026-08-01. CHECK below derives from this path's
# dirname, so both follow from this one line; the root fallback keeps a checkout
# made before the move testable rather than silently skipping every hook test.
#
# The probe fills the DEFAULT only. An explicitly passed HOOK must survive even
# when it does not exist, so a wrong override fails loudly here instead of
# silently retargeting the suite at the repo's own hook and passing.
_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
_default="$_root/hooks/wss-shorthand-flags.sh"
[ -f "$_default" ] || _default="$_root/wss-shorthand-flags.sh"
HOOK="${HOOK:-$_default}"
pass=0 fail=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/project/.claude/skills" "$TMP/bare"

ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail + 1)); }
head_(){ printf '\n\033[1m%s\033[0m\n' "$1"; }

command -v jq  >/dev/null 2>&1 || { echo "needs jq"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "needs git"; exit 1; }
[ -f "$HOOK" ] || { echo "no hook at $HOOK"; exit 1; }

# Run the hook with a given prompt, from a given directory, with an empty HOME.
# Prints the injected context, or nothing.
run() {
  local prompt=$1 dir=${2:-$TMP/project}
  (cd "$dir" && printf '%s' "$(jq -nc --arg p "$prompt" '{prompt:$p}')" \
    | HOME="$TMP/home" bash "$HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
}

fires() { # prompt, expected-flag, [dir]
  local out; out=$(run "$1" "${3:-$TMP/project}")
  if printf '%s' "$out" | grep -q -- "included the \`$2\` flag\|flags: .*$2"; then
    ok "[$1] fires $2"
  else
    bad "[$1] should fire $2 but did not"
  fi
}

silent() { # prompt, why
  local out; out=$(run "$1")
  if [ -z "$out" ]; then ok "[$1] silent — $2"
  else bad "[$1] should be silent ($2) but injected $(printf '%s' "$out" | wc -c) bytes"
  fi
}

# ---------------------------------------------------------------- structure

head_ "Structure"

if bash -n "$HOOK" 2>/dev/null; then ok "parses"
else bad "SYNTAX ERROR — this breaks every flag, not one"; fi

FLAGS=$(sed -n 's/^FLAGS=(\(.*\))$/\1/p' "$HOOK")
[ -n "$FLAGS" ] && ok "FLAGS array parses ($(printf '%s' "$FLAGS" | wc -w) flags)" \
                || bad "cannot parse the FLAGS array"

# Every flag needs a skill mapping, a block, and a stated authorization. A flag
# in FLAGS with no block is worse than an absent flag: it is claimed and then
# injects nothing.
for f in $FLAGS; do
  skill=$(awk -v flag="$f" '
    /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*echo/ {
      alts=$0; sub(/\).*/,"",alts); gsub(/[[:space:]]/,"",alts)
      n=split(alts,a,"|"); for(i=1;i<=n;i++) if(a[i]==flag){
        t=$0; sub(/.*echo[[:space:]]+/,"",t); sub(/[[:space:]]*;;.*/,"",t); print t; exit }
    }' "$HOOK")
  [ -n "$skill" ] || { bad "$f has no skill_for() mapping"; continue; }
  # A block_for() label may be an alternation — `--wss-flags | --wss-help)` covers both —
  # so test membership of the alternatives rather than pattern-matching the
  # start of the line. Matching only `^  FLAG)` reported --wss-help as having no
  # block when it was the second alternative of one, which is the same defect
  # the skill_for() reader above already had to fix.
  awk -v flag="$f" '
    /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*$/ {
      alts=$0; sub(/\).*/,"",alts); gsub(/[[:space:]]/,"",alts)
      n=split(alts,a,"|"); for(i=1;i<=n;i++) if(a[i]==flag){ found=1; exit }
    } END { exit !found }' "$HOOK" ||
    { bad "$f has no block_for() case"; continue; }
  # `-` means the hook serves the flag itself; there is no skill to plant.
  if [ "$skill" != "-" ]; then
    mkdir -p "$TMP/project/.claude/skills/$skill" && : > "$TMP/project/.claude/skills/$skill/SKILL.md"
  fi
  ok "$f -> $skill, block present"
done

head_ "Every block states an authorization"

for f in $FLAGS; do
  out=$(run "$f")
  case $out in
    *"Authorization:"*) ok "$f states its grant" ;;
    "") bad "$f injected nothing even with its skill present" ;;
    *) bad "$f injects a block with no Authorization line" ;;
  esac
done

# ------------------------------------------------------------------ matching

head_ "Exact decomposition is the whole signal; position is none of it"

# Position stopped being the signal when the flags gained the wss- prefix: no
# real command carries a --wss-* option, so an exact token is intent wherever
# it sits. What still gates firing is decomposition with nothing left over.
fires  "--wss-wrap" "--wss-wrap"
fires  "--wss-wrap the purge work is done" "--wss-wrap"
fires  "that is everything for today --wss-wrap" "--wss-wrap"
fires  "remind me what --wss-wrap does" "--wss-wrap"
fires  "commit that, then --wss-todo the rest as one entry" "--wss-todo"
silent "git branch --track origin/dev" "pasted command: --track is not a wss- flag"
silent "see the --wss-wrapper module" "glued to a word: does not decompose"
silent "no flags here at all" "nothing to fire"

head_ "Runs fire every flag they name, in typed order"

out=$(run "--wss-stocktake--wss-release--wss-wrap")
case $out in
  *"--wss-stocktake --wss-release --wss-wrap"*) ok "glued run keeps typed order" ;;
  *) bad "glued run lost order or flags: $(printf '%s' "$out" | head -1)" ;;
esac

out=$(run "--wss-wrap --wss-stocktake")
case $out in
  *"--wss-wrap --wss-stocktake"*) ok "spaced run keeps typed order" ;;
  *) bad "spaced run did not preserve order" ;;
esac

head_ "Audit scope is mutually exclusive, wider wins"

out=$(run "--wss-full-stocktake --wss-stocktake")
if printf '%s' "$out" | grep -q -- "--wss-full-stocktake" && \
   ! printf '%s' "$out" | grep -qE 'flags: .*--wss-stocktake( |$)'; then
  ok "--wss-full-stocktake suppresses --wss-stocktake"
else
  bad "--wss-stocktake was not suppressed by --wss-full-stocktake"
fi

head_ "A record sweep does not run twice"

# wss-stocktake runs --wss-check's method over --wss-check's files as its record
# dimension: "invoke one or the other, never both". Firing both sweeps the
# record twice, and the second reports the first one's writes as fresh drift.
for wide in --wss-stocktake --wss-full-stocktake; do
  out=$(run "$wide --wss-check")
  if printf '%s' "$out" | grep -q -- "included the \`$wide\` flag" && \
     ! printf '%s' "$out" | grep -q -- "included the \`--wss-check\` flag"; then
    ok "$wide absorbs --wss-check"
  else
    bad "--wss-check was not absorbed by $wide"
  fi
done

# The half with no symptom. --wss-full-check is a different SKILL rather than a
# wider scope — it also sweeps the docs site and the tooling files, which no
# stocktake touches — so absorbing it would silently narrow the request.
out=$(run "--wss-stocktake --wss-full-check")
if printf '%s' "$out" | grep -q -- "flags: --wss-stocktake --wss-full-check"; then
  ok "--wss-stocktake leaves --wss-full-check standing"
else
  bad "--wss-full-check was wrongly absorbed by --wss-stocktake"
fi

# Suppressed since the pair was introduced, never covered until now.
out=$(run "--wss-full-check --wss-check")
if printf '%s' "$out" | grep -q -- "included the \`--wss-full-check\` flag" && \
   ! printf '%s' "$out" | grep -q -- "included the \`--wss-check\` flag"; then
  ok "--wss-full-check absorbs --wss-check"
else
  bad "--wss-check was not absorbed by --wss-full-check"
fi

# -------------------------------------------------------------------- gating

head_ "A flag whose skill resolves nowhere is inert, not broken"

for f in $FLAGS; do
  # The flags the hook serves ITSELF are exempt, and must be: gating the flag
  # list on a skill existing would silence it in exactly the configuration
  # where a user most needs to ask what is available. Test the opposite for
  # those — they must still fire from a bare directory.
  fskill=$(awk -v flag="$f" '
    /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*echo/ {
      alts=$0; sub(/\).*/,"",alts); gsub(/[[:space:]]/,"",alts)
      n=split(alts,a,"|"); for(i=1;i<=n;i++) if(a[i]==flag){
        t=$0; sub(/.*echo[[:space:]]+/,"",t); sub(/[[:space:]]*;;.*/,"",t); print t; exit }
    }' "$HOOK")
  out=$(run "$f" "$TMP/bare")
  if [ "$fskill" = "-" ]; then
    [ -n "$out" ] && ok "$f still fires where no skill exists — it needs none" \
                  || bad "$f went inert in a bare project, which is where it is most needed"
    continue
  fi
  [ -z "$out" ] && ok "$f inert where its skill is absent" \
                || bad "$f fired with no skill to carry it out"
done

head_ "The flag list is computed, not written down"

# The whole value of --wss-flags is that it cannot go stale. It is built from the
# FLAGS array and skill_for() at run time, so a flag added without touching it
# still appears. A hand-written list would pass every other test in this file
# while being wrong, which is the failure this asserts against: every flag in
# FLAGS must have a row.
out=$(run "--wss-flags" "$TMP/bare")
missing=""
for f in $FLAGS; do
  printf '%s' "$out" | grep -qF "| \`$f\`" || missing="$missing $f"
done
[ -z "$missing" ] && ok "--wss-flags lists every flag in FLAGS ($(printf '%s' "$FLAGS" | wc -w) rows)" \
                  || bad "--wss-flags omitted:$missing — the list is not computed from FLAGS"

# And it must be honest about what does not resolve, which is most of its value
# in a project that has not adopted the suite.
case $out in
  *'**no**'*) ok "--wss-flags marks a flag whose skill is absent as inert" ;;
  *) bad "--wss-flags reported nothing as inert from a bare project — it cannot be reading the disk" ;;
esac

head_ "A settings-disabled skill does not get its flag block either"

# Absent and disabled look identical from the hook's side only if it looks. An
# override leaves SKILL.md exactly where it was, so the gate above passes and
# the block gets injected for a skill the harness then refuses — an instruction
# and a refusal in the same turn.
#
# Two of the four levels block model invocation and two do not, so both
# directions are asserted here. Treating `name-only` as disabled would lose a
# flag that works, which is the same silent loss the gate exists to prevent.

overrides() { # scope, level — write one entry, or remove the file when level is empty
  local dir
  case $1 in
    project) dir="$TMP/project/.claude" ;;
    user)    dir="$TMP/home/.claude" ;;
  esac
  mkdir -p "$dir"
  if [ -z "$2" ]; then
    rm -f "$dir/settings.json"
  else
    jq -nc --arg l "$2" '{skillOverrides:{"wss-wrap":$l}}' > "$dir/settings.json"
  fi
}

for level in off user-invocable-only; do
  overrides user "$level"
  out=$(run "--wss-wrap")
  [ -z "$out" ] && ok "--wss-wrap inert while wss-wrap is \"$level\"" \
                || bad "--wss-wrap fired for a skill the harness will refuse (\"$level\")"
done

for level in on name-only; do
  overrides user "$level"
  out=$(run "--wss-wrap")
  printf '%s' "$out" | grep -q -- 'included the `--wss-wrap` flag' \
    && ok "--wss-wrap still fires while wss-wrap is \"$level\"" \
    || bad "--wss-wrap lost to an override that does not block model invocation (\"$level\")"
done

# Project outranks user for this key. That is why the lookup stops at the first
# file naming the skill rather than merging the two.
overrides user off
overrides project on
out=$(run "--wss-wrap")
printf '%s' "$out" | grep -q -- 'included the `--wss-wrap` flag' \
  && ok "project settings outrank user settings" \
  || bad "a user-level off beat a project-level on"

overrides user ""
overrides project ""

# ------------------------------------------------------------- session-check

head_ "SessionStart check is silent when there is nothing to say"

# The whole design rests on this one property. It fires in every session of
# every project and its output goes into the model's context, so a version that
# speaks on a clean tree is a permanent token cost AND a warning nobody reads.
# It is also the property most easily lost by a later edit, and losing it has no
# symptom beyond a slightly noisier session.
# Overridable for the same reason $HOOK is: the swallowed-output assertions at
# the end of this section are only meaningful if they can be pointed at a
# deliberately broken copy and seen to fail. A guard nobody has watched fail is
# a guard nobody has tested.
CHECK="${CHECK:-$(dirname "$HOOK")/wss-session-check.sh}"
if [ ! -x "$CHECK" ]; then
  bad "wss-session-check.sh is missing or not executable — SessionStart fires nothing"
else
  ok "wss-session-check.sh is executable"
  bash -n "$CHECK" 2>/dev/null && ok "wss-session-check.sh parses" \
    || bad "wss-session-check.sh has a syntax error"

  # A config directory with no doctor at all: nothing to report, so nothing said.
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent when there is no doctor to run" \
                || bad "spoke with nothing to report: $out"

  # A failing doctor MUST be surfaced — that is the one case it exists for.
  mkdir -p "$TMP/failconf"
  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$TMP/failconf/wss-doctor.sh"
  chmod +x "$TMP/failconf/wss-doctor.sh"
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *FAIL*) ok "surfaces a failing doctor" ;;
                 *) bad "a FAILING doctor produced no output — the hook's only job" ;;
  esac

  # It must never break a session, whatever it finds.
  (cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null >/dev/null 2>&1)
  [ $? -eq 0 ] && ok "exits 0 even when the doctor fails" \
               || bad "exited non-zero — a hook that can block startup on its own finding"

  # The handoff exception. A project that maps WSS.record.handoff away from
  # CLAUDE.md has a handoff the harness never loads; this hook is what loads it.
  # Both halves matter: injecting it where it was moved, and NOT injecting it
  # where CLAUDE.md already carries it — that second one has no symptom beyond
  # paying for the same file twice, so nothing else would ever catch it.
  hoproj="$TMP/handoff-proj"
  mkdir -p "$hoproj/.claude"
  printf '# Handoff\n\nSENTINEL-HANDOFF-BODY\n' > "$hoproj/.claude/WSS.HANDOFF.md"

  printf '{"WSS":{"record":{"handoff":".claude/WSS.HANDOFF.md"}}}\n' > "$hoproj/.claude/WSS.WORKFLOW.json"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-HANDOFF-BODY*) ok "injects a handoff mapped away from CLAUDE.md" ;;
                 *) bad "handoff mapped off CLAUDE.md was not injected — nothing else loads it" ;;
  esac

  printf '{"WSS":{"record":{"handoff":"CLAUDE.md"}}}\n' > "$hoproj/.claude/WSS.WORKFLOW.json"
  printf '# Handoff\n' > "$hoproj/CLAUDE.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent where CLAUDE.md is the handoff — the harness loads it" \
                || bad "injected a handoff the harness already loads: $out"

  printf '{"WSS":{"record":{"handoff":".claude/GONE.md"}}}\n' > "$hoproj/.claude/WSS.WORKFLOW.json"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent where the declared handoff does not exist" \
                || bad "spoke about a handoff file that is not there: $out"

  # The card cut. Injecting the whole handoff is what made this repo's own cost
  # 23 KB a session. The marker is the budget, and BOTH halves are load-bearing:
  # a cut that silently dropped the card would be caught by any test above, but
  # a cut that silently stopped cutting would not be caught by any of them — the
  # output stays correct and merely costs five times as much, forever.
  printf '{"WSS":{"record":{"handoff":".claude/WSS.HANDOFF.md"}}}\n' > "$hoproj/.claude/WSS.WORKFLOW.json"
  printf 'SENTINEL-CARD\n<!-- handoff:card-ends -->\nSENTINEL-BELOW-THE-LINE\n' \
    > "$hoproj/.claude/WSS.HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-CARD*) ok "injects the card above the marker" ;;
                 *) bad "the card above handoff:card-ends was not injected" ;;
  esac
  case "$out" in *SENTINEL-BELOW-THE-LINE*)
        bad "injected the body below handoff:card-ends — the cut is not cutting" ;;
                 *) ok "stops at the marker, leaving the body on disk" ;;
  esac
  case "$out" in *"deliberately NOT loaded"*)
        ok "says where the rest went, so it is read rather than assumed absent" ;;
                 *) bad "cut the handoff without telling the session the rest exists" ;;
  esac

  # A project that has not split its handoff is not broken, and must not be
  # silently truncated to nothing by a marker it never wrote.
  printf 'SENTINEL-UNMARKED-WHOLE\nSTILL-HERE\n' > "$hoproj/.claude/WSS.HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-UNMARKED-WHOLE*STILL-HERE*)
        ok "a handoff with no marker is injected whole" ;;
                 *) bad "an unmarked handoff lost content — back-compat broken" ;;
  esac

  # The fallback half. Since 2026-08-07 the handoff fallback is WSS.HANDOFF.md,
  # which the harness does NOT auto-load — so an undeclared key, or no manifest
  # at all, resolves to a file only this hook can put in front of a session. A
  # hook that stays silent there hands the project a handoff nothing reads,
  # which is exactly the fault the injection exists to fix. The stale
  # .claude/WSS.HANDOFF.md left by the cases above must NOT be found — the
  # fallback is the project root's file, not a remembered declared path.
  printf '{"WSS":{"manifest":"workflow/v2"}}\n' > "$hoproj/.claude/WSS.WORKFLOW.json"
  printf 'SENTINEL-FALLBACK-HANDOFF\n' > "$hoproj/WSS.HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-FALLBACK-HANDOFF*)
        ok "an undeclared handoff key falls back to WSS.HANDOFF.md and injects it" ;;
                 *) bad "manifest without a handoff key left WSS.HANDOFF.md unread" ;;
  esac

  rm -f "$hoproj/.claude/WSS.WORKFLOW.json"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-FALLBACK-HANDOFF*)
        ok "a project with no manifest still gets its WSS.HANDOFF.md injected" ;;
                 *) bad "no manifest left WSS.HANDOFF.md unread — the fallback is dead" ;;
  esac

  rm -f "$hoproj/WSS.HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent where no manifest and no WSS.HANDOFF.md exist" \
                || bad "spoke in a project with nothing to inject: $out"

  # The lane selector. A worktree of a lane-split project carries .claude/WSS.LANE,
  # and WSS.lanes.named.<lane>.records.handoff then overrides WSS.record.handoff —
  # WSS.MANIFEST.md's resolution rule. Both directions matter: the selected lane
  # must get ITS card, and a selector that resolves to nothing must DEGRADE to
  # the unsplit record rather than kill the hook — wss-doctor.sh is where a bad
  # selector fails loudly, never here.
  laneproj="$TMP/lane-proj"
  mkdir -p "$laneproj/.claude" "$laneproj/docs/handoff"
  printf '{"WSS":{"record":{"handoff":".claude/WSS.HANDOFF.md"},
           "lanes":{"named":{
             "backend":{"scope":["backend/**"],"records":{"handoff":"docs/handoff/backend.md"}},
             "frontend":{"scope":["frontend/**"],"records":{"handoff":"docs/handoff/frontend.md"}}}}}}\n' \
    > "$laneproj/.claude/WSS.WORKFLOW.json"
  printf 'SENTINEL-UNSPLIT-HANDOFF\n' > "$laneproj/.claude/WSS.HANDOFF.md"
  printf 'SENTINEL-BACKEND-HANDOFF\n' > "$laneproj/docs/handoff/backend.md"
  printf 'SENTINEL-FRONTEND-HANDOFF\n' > "$laneproj/docs/handoff/frontend.md"

  printf 'backend\n' > "$laneproj/.claude/WSS.LANE"
  out=$(cd "$laneproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-BACKEND-HANDOFF*) ok "a lane worktree gets its lane's handoff" ;;
                 *) bad "the selected lane's handoff was not injected" ;;
  esac
  case "$out" in *SENTINEL-UNSPLIT-HANDOFF* | *SENTINEL-FRONTEND-HANDOFF*)
        bad "injected a handoff belonging to another lane or to the unsplit record" ;;
                 *) ok "and only that lane's — not the unsplit or a sibling's" ;;
  esac

  # A selector naming an undeclared lane resolves to the unsplit record. The
  # hook degrades; the doctor is what fails on it.
  printf 'nosuchlane\n' > "$laneproj/.claude/WSS.LANE"
  out=$(cd "$laneproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-UNSPLIT-HANDOFF*)
        ok "an undeclared lane degrades to the unsplit handoff" ;;
                 *) bad "an undeclared selector lost the handoff entirely" ;;
  esac

  # No selector at all: the main checkout of a split project reads the unsplit
  # records, exactly as before lanes existed.
  rm -f "$laneproj/.claude/WSS.LANE"
  out=$(cd "$laneproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-UNSPLIT-HANDOFF*)
        ok "no selector reads the unsplit records — back-compat holds" ;;
                 *) bad "a split manifest with no selector lost the unsplit handoff" ;;
  esac

  # The swallowed-output class, at the selector read. chmod 000 makes the tr
  # redirection fail; unguarded, that status reaches the ERR trap through the
  # assignment and the hook exits 0 having printed nothing — discarding a
  # doctor FAILURE, the one thing it exists to print. A directory would NOT
  # exercise this: the -f test in front of the read already skips one, so only
  # an unreadable FILE reaches the guard at all — proven by stripping the
  # guard from a copy and watching this assertion fail, per the hazard note.
  : > "$laneproj/.claude/WSS.LANE"; chmod 000 "$laneproj/.claude/WSS.LANE"
  out=$(cd "$laneproj" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *FAIL*) ok "an unreadable selector does not swallow a doctor FAILURE" ;;
                 *) bad "a selector read failure silenced the hook — the ERR-trap class" ;;
  esac
  chmod 644 "$laneproj/.claude/WSS.LANE"; rm -f "$laneproj/.claude/WSS.LANE"

  # The first-session orientation. A plugin cannot speak at install time — no
  # such mechanism exists — so the first session after an install gets one
  # block, and the marker is what makes "one" true. Three directions matter:
  # it fires exactly once, it never fires for a checkout, and it must not
  # displace a doctor FAILURE when both have something to say.
  wc=$(mktemp -d); mkdir -p "$wc/conf" "$wc/proj"
  out=$(cd "$wc/proj" && CLAUDE_CONFIG_DIR="$wc/conf" CLAUDE_PLUGIN_ROOT="$wc/conf" \
        bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *"--wss-adopt"*"--wss-flags"*|*"--wss-flags"*"--wss-adopt"*)
        ok "a fresh plugin install gets the one-time orientation" ;;
                 *) bad "first plugin session got no orientation — install stays mute" ;;
  esac
  [ -f "$wc/conf/.wss-welcomed" ] && ok "and the marker makes it one-time" \
                                 || bad "no marker written — the orientation would repeat forever"
  out=$(cd "$wc/proj" && CLAUDE_CONFIG_DIR="$wc/conf" CLAUDE_PLUGIN_ROOT="$wc/conf" \
        bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "the second plugin session is silent again" \
                || bad "the orientation repeated past its marker: $out"
  rm -f "$wc/conf/.wss-welcomed"
  out=$(cd "$wc/proj" && CLAUDE_CONFIG_DIR="$wc/conf" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "a checkout session never sees the plugin orientation" \
                || bad "the orientation fired without a plugin root: $out"
  # Both at once: a failing doctor plus the first session — neither displaces
  # the other.
  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$wc/conf/wss-doctor.sh"
  chmod +x "$wc/conf/wss-doctor.sh"
  out=$(cd "$wc/proj" && CLAUDE_CONFIG_DIR="$wc/conf" CLAUDE_PLUGIN_ROOT="$wc/conf" \
        bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *FAIL*"--wss-adopt"*|*"--wss-adopt"*FAIL*)
        ok "the orientation and a doctor FAILURE travel together" ;;
                 *) bad "one of orientation/doctor-failure displaced the other: ${out:0:80}" ;;
  esac

  # ------------------------------------------------------------- record age
  head_ "Record age nudges, and the far larger set of cases where it must not"

  # Nothing else in the suite resurfaces deferred work, so this is the only
  # thing that will ever say an open decision has been blocking for a while.
  # It counts COMMITS, not dates — asserted below by building distance out of
  # commits alone, since a wall-clock version would be a design decision nobody
  # made and would pass none of these.
  #
  # The silence cases outnumber the firing ones deliberately. This fires on
  # every session of every project; the failure that matters is not "it missed
  # one", it is "it spoke about a file that was fine", because that is what
  # trains the reader to skip the doctor failures printed alongside it.

  recfix() { # dir, manifest-json, open-decisions-body, todo-body, [roadmap-body]
    local d=$1
    rm -rf "$d"; mkdir -p "$d/.claude" "$d/docs"
    git init -q "$d" 2>/dev/null
    git -C "$d" config user.email t@test; git -C "$d" config user.name t
    # These fixtures make ~121 commits each in a tight loop. gc.auto=0 only
    # gates the gc task: since git 2.46 every commit detaches a maintenance
    # child, and git 2.54 made its default strategy a geometric repack that
    # fires at ~100 loose objects regardless of gc.auto — repacking under a
    # still-committing loop until HEAD transiently fails to parse.
    # maintenance.auto=false stops the spawn itself; gc.auto=0 stays for the
    # gc path of older gits. A signing hook belongs to whoever's machine this
    # is, not to the test.
    git -C "$d" config gc.auto 0
    git -C "$d" config maintenance.auto false
    git -C "$d" config commit.gpgsign false
    printf '{"WSS":%s}\n' "$2" > "$d/.claude/WSS.WORKFLOW.json"
    printf '%s\n' "$3" > "$d/docs/WSS.OPEN-DECISIONS.md"
    printf '%s\n' "$4" > "$d/WSS.TODO.md"
    [ -n "${5:-}" ] && printf '%s\n' "$5" > "$d/WSS.ROADMAP.md"
    git -C "$d" add -A >/dev/null 2>&1
    git -C "$d" commit -q -m "records" >/dev/null 2>&1 \
      || bad "recfix: the records commit failed in $d — every nudge assertion below is meaningless"
  }
  # The nudges count COMMITS SINCE THE RECORD LAST CHANGED, so a single lost
  # commit here shifts every threshold by one and the fixture then tests the
  # wrong distance — silently, and in the direction that reads as "the nudge did
  # not fire". That is exactly what the 2026-08-02 CI flake looked like: silent
  # at the 79 check, silent again at the 80 check. Discarding git's output made
  # a lost commit invisible, so the failure surfaced as a mystery two steps later.
  advance() { # dir, n — distance measured purely in commits
    local i err
    for i in $(seq 1 "$2"); do
      err=$(git -C "$1" commit -q --allow-empty -m c 2>&1) || {
        bad "advance: commit $i of $2 failed in $1 — $(printf '%s' "$err" | head -1)"
        return 1
      }
    done
  }
  # Assert the distance the next assertion depends on. A fixture that has drifted
  # now fails AS a fixture fault, naming the number it actually had, instead of
  # being reported as the hook staying quiet.
  at_distance() { # dir, file, expected
    local last n
    last=$(git -C "$1" log -1 --format=%H -- "$2" 2>/dev/null)
    [ -n "$last" ] || { bad "at_distance: nothing in $1 ever touched $2"; return 1; }
    n=$(git -C "$1" rev-list --count "$last"..HEAD 2>/dev/null)
    [ "$n" = "$3" ] || { bad "at_distance: $2 is $n commits behind, expected $3"; return 1; }
  }
  recrun() { # dir
    local err_f out
    err_f=$(mktemp)
    out=$(cd "$1" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>"$err_f" \
      | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    # Discarding stderr hid the other candidate explanation for the same flake:
    # the hook dying mid-pipeline looks identical to the hook deciding to stay
    # quiet. Empty output plus something on stderr is now reported, not swallowed.
    if [ -z "$out" ] && [ -s "$err_f" ]; then
      bad "recrun: the hook wrote to stderr and produced nothing — $(head -1 "$err_f")"
    fi
    rm -f "$err_f"
    printf '%s' "$out"
  }

  BOTH='{"record":{"todo":"WSS.TODO.md","openDecisions":"docs/WSS.OPEN-DECISIONS.md"}}'
  ENTRY='# Open decisions

## Whether to do X

**Blocks:** everything downstream.'
  ITEM='# Backlog

- [ ] **Thing.**
      Do the thing.'

  rec="$TMP/rec"
  recfix "$rec" "$BOTH" "$ENTRY" "$ITEM"

  out=$(recrun "$rec")
  [ -z "$out" ] && ok "silent while both records are current" \
                || bad "nudged about records that just changed: $out"

  advance "$rec" 24
  out=$(recrun "$rec")
  [ -z "$out" ] && ok "silent one commit short of the open-decision threshold" \
                || bad "open-decision nudge fired early: $out"

  # An open decision blocks work and gets settled by accident by whoever writes
  # the first line depending on it, so it nudges before the backlog does.
  advance "$rec" 1
  out=$(recrun "$rec")
  case "$out" in
    *"open decision"*"docs/WSS.OPEN-DECISIONS.md"*) ok "nudges on a stale open decision" ;;
    *) bad "an open decision blocked for 25 commits and nothing was said: $out" ;;
  esac
  printf '%s' "$out" | grep -q -- '--wss-start' \
    && ok "the open-decision nudge names --wss-start" \
    || bad "nudge with no flag to act on — the reader is told a fact and no move"
  printf '%s' "$out" | grep -q 'WSS.TODO.md' \
    && bad "backlog nudged at 25 commits; the two thresholds are not separate" \
    || ok "backlog stays quiet while only the open decision is stale"

  advance "$rec" 54          # 79 behind
  out=$(recrun "$rec")
  printf '%s' "$out" | grep -q 'WSS.TODO.md' \
    && bad "backlog nudge fired one commit short of its threshold" \
    || ok "silent on the backlog one commit short of its threshold"

  advance "$rec" 1           # 80 behind
  out=$(recrun "$rec")
  case "$out" in
    *"WSS.TODO.md"*) ok "nudges on a backlog untouched for 80 commits" ;;
    *) bad "backlog untouched through 80 commits of work and nothing was said" ;;
  esac
  printf '%s' "$out" | grep -q -- '--wss-stocktake' \
    && ok "the backlog nudge names --wss-stocktake" \
    || bad "backlog nudge names no flag"

  (cd "$rec" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null >/dev/null 2>&1)
  [ $? -eq 0 ] && ok "exits 0 while both record nudges fire" \
               || bad "exited non-zero with something to say"

  # The roadmap is the third nudge and the last one. WSS.record.decisions and
  # WSS.record.stocktake are deliberately uncovered — the decision log is append-only
  # so its age carries no signal, and the sweep nudge above already fires on a
  # stale --wss-stocktake baseline at 40. Asserting the roadmap ALONE here is the
  # point of the fixture: the open-decisions file is empty by design and the
  # backlog is finished, so anything else in the output is a nudge that should
  # not have fired.
  QUIET_OD='# Open decisions

**Nothing is open.** That is a state, not a gap.'
  DONE_TD='# Backlog

- [x] **Shipped.**'
  PLAN='# Roadmap

## M1 — the first milestone

- [ ] **A block nobody has built.**'
  ALL_R='{"record":{"todo":"WSS.TODO.md","openDecisions":"docs/WSS.OPEN-DECISIONS.md","roadmap":"WSS.ROADMAP.md"}}'

  rmd="$TMP/rec-roadmap"
  recfix "$rmd" "$ALL_R" "$QUIET_OD" "$DONE_TD" "$PLAN"

  advance "$rmd" 79
  at_distance "$rmd" WSS.ROADMAP.md 79
  out=$(recrun "$rmd")
  [ -z "$out" ] && ok "silent one commit short of the roadmap threshold" \
                || bad "roadmap nudge fired early: $out"

  # It reuses the backlog's 80 rather than the sweeps' 40, because a long
  # focused push through one milestone legitimately does not touch this file —
  # that is the milestone working, and a nudge on correct behaviour is what
  # discredits the whole block.
  advance "$rmd" 1
  at_distance "$rmd" WSS.ROADMAP.md 80
  out=$(recrun "$rmd")
  case "$out" in
    *"WSS.ROADMAP.md"*) ok "nudges on a roadmap untouched for 80 commits" ;;
    *) bad "roadmap untouched through 80 commits of work and nothing was said: $out" ;;
  esac
  printf '%s' "$out" | grep -q -- '--wss-plan' \
    && ok "the roadmap nudge names --wss-plan" \
    || bad "roadmap nudge names no flag — the reader gets a fact and no move"
  printf '%s' "$out" | grep -q 'WSS.TODO.md\|open-decisions' \
    && bad "a record that is correctly empty was nudged alongside the roadmap: $out" \
    || ok "the roadmap nudge fires alone, with both other records quiet"

  # The record-age nudges follow the lane selector too. A lane worktree whose
  # pending decision sits in ITS open-decisions file must be nudged about that
  # file — nudging it about the unsplit one, which is correctly quiet, would
  # tell the one session that can settle the decision that nothing is open.
  lanerec="$TMP/rec-lane"
  recfix "$lanerec" '{"record":{"todo":"WSS.TODO.md","openDecisions":"docs/WSS.OPEN-DECISIONS.md"},
    "lanes":{"named":{
      "backend":{"records":{"openDecisions":"docs/open-decisions.backend.md"}},
      "frontend":{"records":{"openDecisions":"docs/open-decisions.frontend.md"}}}}}' \
    "$QUIET_OD" "$DONE_TD"
  printf '%s\n' "$ENTRY" > "$lanerec/docs/open-decisions.backend.md"
  printf '%s\n' "$QUIET_OD" > "$lanerec/docs/open-decisions.frontend.md"
  printf 'backend\n' > "$lanerec/.claude/WSS.LANE"
  git -C "$lanerec" add -A >/dev/null 2>&1
  git -C "$lanerec" commit -q -m lane >/dev/null 2>&1 \
    || bad "rec-lane: the lane-records commit failed — the lane nudge assertions are meaningless"
  advance "$lanerec" 25
  at_distance "$lanerec" docs/open-decisions.backend.md 25
  out=$(recrun "$lanerec")
  case "$out" in
    *"open decision"*"docs/open-decisions.backend.md"*)
        ok "the open-decision nudge follows the lane selector" ;;
    *) bad "a lane worktree's own open decision drew no nudge: $out" ;;
  esac

  # A roadmap whose blocks are all marked completed is FINISHED, not neglected.
  # This is the roadmap's version of the empty-by-design case below, and it is
  # the one that matters most: a completed plan is the normal end state, so a
  # nudge here would fire on every project that ever finished a milestone.
  donep="$TMP/rec-roadmap-done"
  recfix "$donep" "$ALL_R" "$QUIET_OD" "$DONE_TD" '# Roadmap

## M1 — shipped

- [x] **A block that landed.**'
  advance "$donep" 120
  out=$(recrun "$donep")
  [ -z "$out" ] && ok "silent on a roadmap whose blocks are all completed, at 120 commits" \
                || bad "nudged about a finished roadmap: $out"

  # Declared and absent: ordinary in a project that adopted the workflow before
  # it had a roadmap, and it has no age to be behind.
  norm="$TMP/rec-roadmap-absent"
  recfix "$norm" "$ALL_R" "$QUIET_OD" "$DONE_TD"
  advance "$norm" 120
  out=$(recrun "$norm")
  [ -z "$out" ] && ok "silent where the declared roadmap does not exist" \
                || bad "spoke about a roadmap file that is not there: $out"

  # Undeclared is not absent. A project with a WSS.ROADMAP.md sitting in the tree
  # and no roadmap key never asked to be nudged towards --wss-plan.
  noplan="$TMP/rec-roadmap-undeclared"
  recfix "$noplan" "$BOTH" "$QUIET_OD" "$DONE_TD" "$PLAN"
  advance "$noplan" 120
  out=$(recrun "$noplan")
  [ -z "$out" ] && ok "silent where a roadmap exists but the manifest omits the key" \
                || bad "nudged about a record the manifest never declared: $out"

  # THE case this must get right. docs/WSS.OPEN-DECISIONS.md is empty by design most
  # of the time — "nothing is open" is a state, not a gap — and a backlog with
  # no unchecked item is finished, not neglected. Nudging about either is the
  # noise that would discredit every other line this hook prints.
  emp="$TMP/rec-empty"
  recfix "$emp" "$BOTH" \
    '# Open decisions

**Nothing is open.** That is a state, not a gap.' \
    '# Backlog

## Section

Nothing pending.'
  advance "$emp" 120
  out=$(recrun "$emp")
  [ -z "$out" ] && ok "silent on records that are correctly empty, at 120 commits" \
                || bad "nudged about a file that is empty by design: $out"

  # Declared and absent, and declared and never committed. Both are ordinary in
  # a project mid-adoption, and neither has an age to be behind.
  gone="$TMP/rec-gone"
  recfix "$gone" '{"record":{"todo":"NOPE.md","openDecisions":"docs/nope.md"}}' "$ENTRY" "$ITEM"
  advance "$gone" 120
  out=$(recrun "$gone")
  [ -z "$out" ] && ok "silent where the declared records do not exist" \
                || bad "spoke about record files that are not there: $out"

  printf '%s\n' "$ITEM"  > "$gone/NOPE.md"
  printf '%s\n' "$ENTRY" > "$gone/docs/nope.md"
  out=$(recrun "$gone")
  [ -z "$out" ] && ok "silent where a declared record was never committed" \
                || bad "claimed an age for a file git has never seen: $out"

  # Undeclared is not the same as absent. A project that adopted the workflow
  # without declaring these keys, or never adopted it at all, gets no nudge
  # towards a flag it has not asked for — even with an old WSS.TODO.md sitting there.
  und="$TMP/rec-undeclared"
  recfix "$und" '{"record":{"handoff":"CLAUDE.md"}}' "$ENTRY" "$ITEM"
  advance "$und" 120
  out=$(recrun "$und")
  [ -z "$out" ] && ok "silent where the manifest declares neither record" \
                || bad "nudged about a record the manifest never declared: $out"

  rm -f "$und/.claude/WSS.WORKFLOW.json"
  out=$(recrun "$und")
  [ -z "$out" ] && ok "silent in a project with no manifest at all" \
                || bad "nudged a project that never adopted this workflow: $out"

  # Malformed input must not cost a session, and must not be read as staleness.
  printf 'not json {{{ at all\n' > "$und/.claude/WSS.WORKFLOW.json"
  out=$(recrun "$und")
  [ -z "$out" ] && ok "silent on a malformed manifest" \
                || bad "read something out of a manifest that is not JSON: $out"

  # Run the hook DIRECTLY, not through recrun's pipeline — a pipe reports jq's
  # status, and jq exits 0 on empty input, so the piped form would report
  # success no matter what the hook did.
  (cd "$und" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null >/dev/null 2>&1)
  [ $? -eq 0 ] && ok "exits 0 on a malformed manifest" \
               || bad "a broken manifest took the session down with it"

  # Exiting 0 is not the same as behaving. jq exits non-zero on a manifest that
  # is not JSON; that failure propagates out of the assignment and the hook's
  # own ERR trap exits 0 — discarding everything already collected. A broken
  # WSS.WORKFLOW.json would then silently swallow a doctor FAILURE, and the exit
  # code above would still say the hook was fine. Nothing else catches this.
  out=$(cd "$und" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *FAIL*) ok "a malformed manifest does not swallow a doctor FAILURE" ;;
                 *) bad "unreadable WSS.WORKFLOW.json silently discarded the doctor's failures" ;;
  esac

  # --------------------------------------------------- the swallowed-output class
  head_ "An unreadable file must not swallow what was already collected"

  # The class every exit-code assertion in this file is structurally blind to.
  # `trap exit_clean ERR` exits 0, so a bare `x=$(cmd)` that fails aborts the
  # hook BEFORE it prints — after $out already held a doctor FAILURE. The hook
  # exits 0 whether or not that happened, which is what the trap is for, so only
  # stdout CONTENT separates the broken version from the fixed one.
  #
  # The manifest jq site is covered directly above. The two asserted here are
  # the ones fixed at d7f995c by behavioural repro rather than by a test — the
  # bug-report awk and the handoff cat — which is exactly why they are worth
  # pinning: a repro is not repeated, and the next edit to this file reopens
  # them silently. Prove any NEW guard the same way: chmod 000 the target and
  # check the hook still prints.
  #
  # Skipped rather than passed when the chmod does not bite. Root reads a 000
  # file regardless, and a test that cannot fail is worse than no test — it
  # reports coverage that does not exist.
  probe="$TMP/unreadable-probe"
  : > "$probe"; chmod 000 "$probe"
  if cat "$probe" >/dev/null 2>&1; then
    printf '  \033[33mskip\033[0m  chmod 000 not enforced here (root?) — swallow tests cannot fail\n'
  else
    # The inbox lives in the CONFIG dir, beside the doctor whose failure it
    # would discard.
    sw="$TMP/swallow-inbox"
    rm -rf "$sw"; mkdir -p "$sw"
    printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$sw/wss-doctor.sh"
    chmod +x "$sw/wss-doctor.sh"
    : > "$sw/WSS.BUG-REPORTS.md"; chmod 000 "$sw/WSS.BUG-REPORTS.md"
    out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$sw" bash "$CHECK" </dev/null 2>/dev/null \
          | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    case "$out" in *FAIL*) ok "an unreadable bug-report inbox does not swallow a doctor FAILURE" ;;
                   *) bad "unreadable WSS.BUG-REPORTS.md discarded the doctor's failures" ;;
    esac
    chmod 644 "$sw/WSS.BUG-REPORTS.md"

    # The handoff cat is the LAST thing to touch $out, so a failure there loses
    # everything collected before it — the doctor, the sweeps and all three
    # record nudges at once. The worst site of the three, and the one whose
    # symptom is most completely absent.
    swh="$TMP/swallow-handoff"
    rm -rf "$swh"; mkdir -p "$swh/.claude"
    printf '{"WSS":{"record":{"handoff":".claude/WSS.HANDOFF.md"}}}\n' > "$swh/.claude/WSS.WORKFLOW.json"
    printf '# Handoff\n' > "$swh/.claude/WSS.HANDOFF.md"
    chmod 000 "$swh/.claude/WSS.HANDOFF.md"
    out=$(cd "$swh" && CLAUDE_CONFIG_DIR="$TMP/failconf" bash "$CHECK" </dev/null 2>/dev/null \
          | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    case "$out" in *FAIL*) ok "an unreadable handoff does not swallow a doctor FAILURE" ;;
                   *) bad "unreadable handoff discarded everything collected before it" ;;
    esac
    chmod 644 "$swh/.claude/WSS.HANDOFF.md"
  fi
  chmod 644 "$probe"

  # ---------------------------------------------------- inbox entry counting
  head_ "The inbox counter reads marked and marker-less files alike"

  # Both counters (here and wss-doctor.sh) count `## [open]` below the append
  # marker, so the fenced template above it never registers as an entry. But no
  # filing template mentions the marker, so a fresh machine's first filing
  # creates the file bare — and a counter that REQUIRES the marker reads that
  # inbox as empty forever (audit pass 9, F1: the finding dies unsurfaced).
  # Both directions are asserted because each has been broken once: the false
  # positive by the fenced template, the false negative by requiring the marker.
  ib="$TMP/inbox-conf"
  rm -rf "$ib"; mkdir -p "$ib"
  printf '## [open] filed from a fresh machine\nDetail: no marker anywhere in this file\n' > "$ib/WSS.BUG-REPORTS.md"
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$ib" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"1 open bug report"*) ok "a marker-less inbox is counted in full" ;;
    *) bad "an entry in a marker-less inbox stayed invisible: $out" ;;
  esac

  printf '# Bug reports\n\nFormat:\n\n```\n## [open] <one-line summary>\n```\n\n<!-- Append new entries below this line. -->\n' > "$ib/WSS.BUG-REPORTS.md"
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$ib" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"bug report"*) bad "the fenced template above the marker was counted as an entry: $out" ;;
    *) ok "an empty inbox with template and marker stays silent" ;;
  esac

  printf '\n## [open] a real entry below the marker\n' >> "$ib/WSS.BUG-REPORTS.md"
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$ib" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"1 open bug report"*) ok "an entry below the marker counts; the template above does not" ;;
    *) bad "a marked inbox miscounted its entries: $out" ;;
  esac

  # ---------------------------------------------------- upstream issue nudge
  head_ "The upstream check reports counts and unreachability, never silence"

  # Fires only in a session standing in the suite's own checkout (PWD is the
  # config dir and it carries the plugin manifest), and its failure mode is the
  # contract: gh unreachable must SAY not-checked, because silence there renders
  # "unreachable" identical to "zero". gh is stubbed on PATH both ways.
  upc="$TMP/upstream-conf"
  rm -rf "$upc"; mkdir -p "$upc/.claude-plugin" "$upc/stubs"
  printf '{"name":"workflow-secretary-suite","version":"0.0.1","description":"d"}\n' \
    > "$upc/.claude-plugin/plugin.json"
  printf '#!/usr/bin/env bash\necho 3\n' > "$upc/stubs/gh"; chmod +x "$upc/stubs/gh"
  out=$(cd "$upc" && CLAUDE_CONFIG_DIR="$upc" PATH="$upc/stubs:$PATH" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"3 open issue(s) on qupunto/workflow-secretary-suite"*) ok "open upstream issues are counted in the nudge" ;;
    *) bad "3 open upstream issues went unmentioned: $out" ;;
  esac

  printf '#!/usr/bin/env bash\nexit 1\n' > "$upc/stubs/gh"; chmod +x "$upc/stubs/gh"
  out=$(cd "$upc" && CLAUDE_CONFIG_DIR="$upc" PATH="$upc/stubs:$PATH" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"NOT checked"*) ok "an unreachable upstream repo says so rather than nothing" ;;
    *) bad "gh failing rendered as silence — unreachable reads as zero: $out" ;;
  esac

  printf '#!/usr/bin/env bash\necho 0\n' > "$upc/stubs/gh"; chmod +x "$upc/stubs/gh"
  out=$(cd "$upc" && CLAUDE_CONFIG_DIR="$upc" PATH="$upc/stubs:$PATH" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"qupunto/workflow-secretary-suite"*) bad "zero upstream issues still produced a nudge: $out" ;;
    *) ok "zero upstream issues stay silent" ;;
  esac

  printf '#!/usr/bin/env bash\necho 3\n' > "$upc/stubs/gh"; chmod +x "$upc/stubs/gh"
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$upc" PATH="$upc/stubs:$PATH" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"workflow-secretary-suite"*) bad "the upstream check fired outside the suite checkout" ;;
    *) ok "no upstream check outside the suite's own checkout" ;;
  esac
fi

# ------------------------------------------------------------------- wss-doctor.sh

head_ "wss-doctor.sh reports a fault planted where its parsers look"

# wss-doctor.sh is ~770 lines of awk and grep run against files it does not own. Its
# checks are stated as prose ABOUT wss-shorthand-flags.sh, WSS.OWNERSHIP.md and the
# markdown tree, so every one of them stops matching the day one of those files
# is reworded — a renamed `FLAGS=` line, a reworded `Authorization:`, a heading
# that moved. There is no symptom: a parser that matches nothing reports nothing
# to report, and the run ends "all checks passed".
#
# So the shape here is a synthetic config directory the doctor calls entirely
# clean, and then one copy of it per fault, each broken in exactly one way. The
# CLEAN run is the load-bearing half: it is what fails when a parser stops
# matching, because a doctor that can no longer see anything still reports every
# broken fixture as broken by saying nothing about it.
#
# Overridable like $HOOK and $CHECK above, for the same reason: point DOCTOR at a
# deliberately mutated copy and every guard here must go red.

#
# Derived from the REPO ROOT, not from $HOOK's directory. Those were the same
# place until the hooks moved into hooks/ on 2026-08-01, and deriving from the
# hook then pointed this at hooks/wss-doctor.sh — a path that has never existed.
# wss-doctor.sh stays at the root deliberately: it is run by hand as often as by the
# SessionStart hook.
DOCTOR="${DOCTOR:-$_root/wss-doctor.sh}"

if [ ! -f "$DOCTOR" ]; then
  bad "wss-doctor.sh not found at $DOCTOR — nothing below ran"
else
  ok "wss-doctor.sh is present"
  bash -n "$DOCTOR" 2>/dev/null && ok "wss-doctor.sh parses" \
    || bad "wss-doctor.sh has a syntax error — every check in it is dead"

  # A config directory the doctor must report entirely clean, carrying only the
  # SHAPES its parsers look for. The doctor never RUNS the hook, it reads it, so
  # this stand-in does not have to work — but it must be laid out exactly like
  # the real one: `FLAGS=` at column 0, the case arms two spaces in, the
  # heredoc's `Authorization:` and its terminator at column 0. Those positions
  # are the contract every awk program here depends on.
  docfix() { # dir
    local d=$1
    rm -rf "$d"
    mkdir -p "$d/skills/alpha-skill" "$d/skills/beta-skill" "$d/workflow"
    printf '.credentials.json\n' > "$d/.gitignore"
    printf '%s\n' '{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"~/.claude/wss-shorthand-flags.sh"}]}]}}' \
      > "$d/settings.json"

    cat > "$d/wss-shorthand-flags.sh" <<'HOOKFIX'
#!/usr/bin/env bash
FLAGS=(--alpha --beta)

skill_for() {
  case $1 in
    --alpha) echo alpha-skill ;;
    --beta)  echo beta-skill ;;
  esac
}

block_for() {
  case $1 in
  --alpha)
    cat <<'EOF'
The user included the `--alpha` flag.

Authorization: COMMIT. Not push.
EOF
    ;;
  --beta)
    cat <<'EOF'
The user included the `--beta` flag.

Authorization: none.
EOF
    ;;
  esac
}
HOOKFIX
    chmod +x "$d/wss-shorthand-flags.sh"

    cat > "$d/workflow/WSS.OWNERSHIP.md" <<'OWNFIX'
# Ownership

## The matrix

| Verb | Flag | Skill | Tier | Sole writer of | Authorization the flag grants |
|---|---|---|---|---|---|
| alpha | `--alpha` | `alpha-skill` | primitive | nothing | commit, **not** push |
| beta | `--beta` | `beta-skill` | primitive | nothing | — |
OWNFIX

    printf '# alpha-skill\n\nDoes the alpha thing.\n' > "$d/skills/alpha-skill/SKILL.md"
    printf '# beta-skill\n\nDoes the beta thing.\n'   > "$d/skills/beta-skill/SKILL.md"
    mkdir -p "$d/commands"
    printf -- '---\ndescription: alpha wrapper\n---\n--alpha $ARGUMENTS\n' > "$d/commands/alpha.md"
    printf '# Fixture\n\nSee [the matrix](workflow/WSS.OWNERSHIP.md#the-matrix).\n' > "$d/README.md"

    # A checkout, because three checks below only run in one: the credentials
    # pair, the dirty-tree warn, and the anchor walk, which reads `git ls-files`
    # rather than the whole tree.
    git init -q "$d" 2>/dev/null
    git -C "$d" config user.email t@test; git -C "$d" config user.name t
    docommit "$d"
  }
  docommit() { # dir — leave the tree clean, and every .md visible to ls-files
    git -C "$1" add -A >/dev/null 2>&1
    git -C "$1" commit -q -m fixture >/dev/null 2>&1
  }
  # sed -i is not portable and mv is. Every fault below is one substitution.
  edit_() { # file, sed-expression
    sed "$2" "$1" > "$1.new" && mv "$1.new" "$1"
  }
  doc() { # config-dir, [doctor args] — inspect a config from a project-less PWD,
          # so the $PWD-dependent checks skip rather than report another project's
          # state as this fixture's.
    (cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$1" CLAUDE_DIR="$1" bash "$DOCTOR" "${@:2}" 2>&1)
  }
  says() { # dir, needle, label — the doctor must name this fault
    printf '%s' "$(doc "$1")" | grep -q -- "$2" \
      && ok "$3" || bad "$3 — the doctor said nothing about it"
  }

  clean="$TMP/doc-clean"
  docfix "$clean"
  out=$(doc "$clean"); st=$?

  [ $st -eq 0 ] && ok "clean fixture: exit 0" \
    || bad "clean fixture reported a fault: $(printf '%s' "$out" | grep -aE 'FAIL|warn' | head -2)"
  printf '%s' "$out" | grep -q 'all checks passed' \
    && ok "clean fixture: all checks passed" \
    || bad "clean fixture never reached a clean result"

  # Each of these is a parser reporting that it matched. Without them a doctor
  # whose awk has gone blind passes this whole section: it says nothing about
  # every planted fault below, and saying nothing is what those tests read as
  # the fault being absent.
  printf '%s' "$out" | grep -q -- '--alpha -> alpha-skill' \
    && ok "the flag->skill parser resolved a mapping" \
    || bad "flag->skill parser matched nothing on a hook shaped like the real one"
  printf '%s' "$out" | grep -q "no flag is a prefix of another" \
    && ok "the prefix-clash check ran over a parsed FLAGS array" \
    || bad "prefix-clash check reached no verdict — the FLAGS array parsed as empty"
  # The count is the assertion, not the sentence. "every flag's grant matches"
  # is exactly what a comparison that read NOTHING used to print, so the pass
  # line only means something if it says how many flags it got through.
  printf '%s' "$out" | grep -q "every flag's grant matches between the hook and WSS.OWNERSHIP.md (2 checked)" \
    && ok "the grant comparison reached a verdict on both flags" \
    || bad "grant comparison reached no verdict, or claimed one over fewer than 2 flags"
  printf '%s' "$out" | grep -q "no date-shaped prose in any rule file" \
    && ok "the prose-date check reached a verdict on the rule files" \
    || bad "prose-date check reached no verdict on a clean fixture"

  # History stays in the log: a date in a rule file's prose is named as
  # history; the same date inside a fenced block is exempt.
  hist="$TMP/doc-history"
  docfix "$hist"
  printf '# alpha-skill\n\nDoes the alpha thing. Fixed on 2026-08-01 after an incident.\n' \
    > "$hist/skills/alpha-skill/SKILL.md"
  printf '# beta-skill\n\nDoes the beta thing.\n\n```\nat: 2026-08-01\n```\n' \
    > "$hist/skills/beta-skill/SKILL.md"
  docommit "$hist"
  says "$hist" "history in a rule file: skills/alpha-skill/SKILL.md" \
    "a prose date in a rule file is named as history"
  printf '%s' "$(doc "$hist")" | grep -q "history in a rule file: skills/beta-skill" \
    && bad "a fenced date was flagged — the fence exemption is broken" \
    || ok "a date inside a fenced block stays exempt"

  # A wrapper's name is its contract: the body must fire the flag the filename
  # promises, and that flag must exist in the hook's FLAGS array.
  printf '%s' "$out" | grep -q "every command wrapper fires the flag its name promises (1 checked)" \
    && ok "the wrapper check reached a verdict on the clean fixture" \
    || bad "wrapper check reached no verdict, or checked a different count"
  wmis="$TMP/doc-wrapper-mismatch"
  docfix "$wmis"
  printf -- '---\ndescription: alpha wrapper\n---\n--beta $ARGUMENTS\n' > "$wmis/commands/alpha.md"
  docommit "$wmis"
  says "$wmis" "a wrapper's body must fire" \
    "a wrapper firing a different flag than its name is a FAILURE"
  wgone="$TMP/doc-wrapper-unserved"
  docfix "$wgone"
  printf -- '---\ndescription: gamma wrapper\n---\n--gamma $ARGUMENTS\n' > "$wgone/commands/gamma.md"
  docommit "$wgone"
  says "$wgone" "not in the hook's FLAGS" \
    "a wrapper naming a flag the hook does not serve is a FAILURE"

  # The cadence card and README's "How often" table are two hand-copies of one
  # list. The flag column must agree; wording and the third column must stay
  # free to differ, or the check would be demanding one document instead of an
  # agreement between two. A fixture carrying wss-adopt draws an unrelated
  # dispatch-only warn, so these assert on the needle rather than on exit 0.
  cadfix() { # dir, adopt-flags, readme-flags — one cadence table in each file
    docfix "$1"
    mkdir -p "$1/skills/wss-adopt"
    { printf '# wss-adopt\n\nThe cadence card:\n\n| When | Flag |\n|---|---|\n'
      for f in $2; do printf '| Some moment | `%s` |\n' "$f"; done
    } > "$1/skills/wss-adopt/SKILL.md"
    { printf '# Fixture\n\nSee [the matrix](workflow/WSS.OWNERSHIP.md#the-matrix).\n'
      printf '\n### How often\n\n| When | Flag | Why then |\n|---|---|---|\n'
      for f in $3; do printf '| A different wording | `%s` | because |\n' "$f"; done
    } > "$1/README.md"
    docommit "$1"
  }
  cadok="$TMP/doc-cadence-agree"
  cadfix "$cadok" "--wss-track --wss-wrap" "--wss-track --wss-wrap"
  printf '%s' "$(doc "$cadok")" | grep -q "both cadence tables name the same flags (2 checked)" \
    && ok "the cadence comparison reached a verdict over both tables" \
    || bad "cadence comparison reached no verdict, or read fewer than 2 flags"
  cadrift="$TMP/doc-cadence-drift"
  cadfix "$cadrift" "--wss-track --wss-wrap" "--wss-track --wss-wrap --wss-scout"
  says "$cadrift" "the two cadence tables name different flags" \
    "a flag in one cadence table and not the other is a FAILURE"
  printf '%s' "$(doc "$cadrift")" | grep -q "Only in README.md's 'How often' table: --wss-scout" \
    && ok "the cadence failure names the flag that drifted, and which side has it" \
    || bad "cadence failure did not name --wss-scout as README-only"
  cadblind="$TMP/doc-cadence-unreadable"
  cadfix "$cadblind" "--wss-track" "--wss-track"
  edit_ "$cadblind/README.md" 's/^| When | Flag | Why then |$/| Moment | Shorthand | Why then |/'
  docommit "$cadblind"
  says "$cadblind" "no cadence table found in README.md" \
    "a table the parser cannot find is a FAILURE, not a silent agreement"

  # The catalog's method table and workflow/checks/WSS.CHECKS.md's are the same rows
  # written twice. Unlike the cadence pair EVERY column must agree — those two
  # address different readers, these two address the same one — so the fixture
  # drifts a description rather than a row. What stays free to differ is the
  # link target, the files sitting at different depths, so the two sides here
  # carry deliberately different hrefs: an agreeing verdict then proves the
  # normalisation rather than merely proving the fixture is a copy of itself.
  mtfix() { # dir, catalog-finds, readme-finds — one row differs, one always agrees
    docfix "$1"
    mkdir -p "$1/.claude" "$1/workflow/checks"
    printf '# record-drift\n' > "$1/workflow/checks/WSS.RECORD-DRIFT.md"
    printf '# docs-audit\n'   > "$1/workflow/checks/WSS.DOCS-AUDIT.md"
    { printf '# Tooling\n\n## The shared check methods\n\n'
      printf '| Method | What it finds | Run by |\n|---|---|---|\n'
      printf '| [`WSS.RECORD-DRIFT.md`](../workflow/checks/WSS.RECORD-DRIFT.md) | %s | `--alpha` |\n' "$2"
      printf '| [`WSS.DOCS-AUDIT.md`](../workflow/checks/WSS.DOCS-AUDIT.md) | a docs site | `--beta` |\n'
    } > "$1/.claude/WSS.TOOLING.md"
    { printf '# The checks\n\n## Method and runner\n\n'
      printf '| Method | What it finds | Run by |\n|---|---|---|\n'
      printf '| [`WSS.RECORD-DRIFT.md`](WSS.RECORD-DRIFT.md) | %s | `--alpha` |\n' "$3"
      printf '| [`WSS.DOCS-AUDIT.md`](WSS.DOCS-AUDIT.md) | a docs site | `--beta` |\n'
    } > "$1/workflow/checks/WSS.CHECKS.md"
    docommit "$1"
  }
  mtok="$TMP/doc-methods-agree"
  mtfix "$mtok" "the classes of drift" "the classes of drift"
  printf '%s' "$(doc "$mtok")" | grep -q "both check-method tables carry the same rows (2 checked)" \
    && ok "the method comparison agrees across two different link targets" \
    || bad "method comparison reached no verdict, or the differing hrefs broke it"
  mtdrift="$TMP/doc-methods-drift"
  mtfix "$mtdrift" "the classes of drift" "the classes of drift in a record"
  says "$mtdrift" "the two check-method tables disagree" \
    "a description worded differently in the two method tables is a FAILURE"
  printf '%s' "$(doc "$mtdrift")" | grep -q "Differing rows in .claude/WSS.TOOLING.md: WSS.RECORD-DRIFT.md" \
    && ok "the method failure names the row that drifted, not just that one did" \
    || bad "method failure did not name WSS.RECORD-DRIFT.md as the drifting row"
  mtblind="$TMP/doc-methods-unreadable"
  mtfix "$mtblind" "the classes of drift" "the classes of drift"
  edit_ "$mtblind/workflow/checks/WSS.CHECKS.md" 's/^| Method | What it finds | Run by |$/| Check | What it finds | Run by |/'
  docommit "$mtblind"
  says "$mtblind" "no check-method table found in workflow/checks/WSS.CHECKS.md" \
    "a method table the parser cannot find is a FAILURE, not a silent agreement"

  # The two lane-table pairs, one comparison each. The four-rulings pair must
  # agree in every cell except a trailing "— see below" pointer, so the clean
  # fixture carries the pointer on one side only: an agreeing verdict proves
  # the normalisation, as the method fixture's differing hrefs do. The
  # record-vs-queue pair compares labels one way — the fixture's contract
  # holds a row the annex skips, and must still agree.
  lanefix() { # dir, skill-decline-cell, annex-decline-cell, annex-extra-row
    docfix "$1"
    mkdir -p "$1/skills/wss-lane-record-sync" "$1/docs/annex"
    { printf '# wss-lane-record-sync\n\n### The four rulings\n\n'
      printf '| Ruling | Files to the queue | Next run |\n|---|---|---|\n'
      printf '| **Accept** | yes, unmarked | — |\n'
      printf '| **Decline** | no | %s |\n' "$2"
    } > "$1/skills/wss-lane-record-sync/SKILL.md"
    { printf '# The record contract\n\n'
      printf '| | A record | A transfer queue |\n|---|---|---|\n'
      printf '| Writers | exactly one | **any lane** |\n'
      printf '| Write mode | append-only or rewritten in place | append-only, always |\n'
    } > "$1/workflow/WSS.RECORD-CONTRACT.md"
    { printf '# Lane synching\n\n'
      printf '| | A record | A transfer queue |\n|---|---|---|\n'
      printf '| Writers | exactly one | any lane |\n'
      [ -n "$4" ] && printf '| %s | something | something |\n' "$4"
      printf '\n### The four rulings\n\n'
      printf '| Ruling | Files to the queue | Next run |\n|---|---|---|\n'
      printf '| **Accept** | yes, unmarked | — |\n'
      printf '| **Decline** | no | %s |\n' "$3"
    } > "$1/docs/annex/lane-synching.md"
    docommit "$1"
  }
  lnok="$TMP/doc-lanes-agree"
  lanefix "$lnok" "**does not ask** — see below" "**does not ask**" ""
  printf '%s' "$(doc "$lnok")" | grep -q "both four-rulings tables carry the same rows (2 checked)" \
    && ok "the rulings comparison agrees across the '— see below' pointer" \
    || bad "rulings comparison reached no verdict, or the pointer broke it"
  printf '%s' "$(doc "$lnok")" | grep -q "record-vs-queue rows all exist in the contract (1 checked)" \
    && ok "a contract-only row stays free in the record-vs-queue comparison" \
    || bad "record-vs-queue comparison reached no verdict, or flagged the contract's extra row"
  lndrift="$TMP/doc-lanes-drift"
  lanefix "$lndrift" "**does not ask**" "**asks again**" ""
  says "$lndrift" "the two four-rulings tables disagree" \
    "a ruling cell worded differently on the two sides is a FAILURE"
  printf '%s' "$(doc "$lndrift")" | grep -q "Differing rows in skills/wss-lane-record-sync/SKILL.md: \*\*Decline\*\*" \
    && ok "the rulings failure names the row that drifted, not just that one did" \
    || bad "rulings failure did not name **Decline** as the drifting row"
  lnextra="$TMP/doc-lanes-annex-extra"
  lanefix "$lnextra" "**does not ask**" "**does not ask**" "Steady state"
  says "$lnextra" "carries rows" \
    "an annex-only record-vs-queue row is a FAILURE"
  lnblind="$TMP/doc-lanes-unreadable"
  lanefix "$lnblind" "**does not ask**" "**does not ask**" ""
  edit_ "$lnblind/docs/annex/lane-synching.md" 's/^| Ruling | Files to the queue | Next run |$/| Ruling | Queue | Next run |/'
  docommit "$lnblind"
  says "$lnblind" "no four-rulings table found in docs/annex/lane-synching.md" \
    "a rulings table the parser cannot find is a FAILURE, not a silent agreement"

  # --strict's entire job is an exit code, so nothing but an exit code tests it.
  # Both directions: a clean run must stay 0 under it, or it is just `exit 1`.
  doc "$clean" --bogus >/dev/null 2>&1
  [ $? -eq 2 ] && ok "an unknown argument exits 2 rather than being ignored" \
               || bad "wss-doctor.sh accepted an argument it does not implement"

  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$out" | grep -q 'every link anchor resolves (1 checked)' \
      && ok "the link-anchor walker found the fixture's one link" \
      || bad "link-anchor walker found no links in a fixture that has exactly one"

    doc "$clean" --strict >/dev/null 2>&1
    [ $? -eq 0 ] && ok "--strict leaves a warning-free run at 0" \
                 || bad "--strict failed a run with nothing to warn about"
  else
    printf '  \033[33mskip\033[0m  link anchors need python3 — the doctor warns instead of checking\n'
  fi

  # 1. The FLAGS array. One renamed line and every check below it is computed
  #    from an empty list, which reads as "nothing to check" rather than as an
  #    error — the failure this whole section exists for, in its purest form.
  dfix="$TMP/doc-noflags"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" 's/^FLAGS=(/SHORTHAND_FLAGS=(/'; docommit "$dfix"
  says "$dfix" 'could not parse the FLAGS array' "a renamed FLAGS= line is a failure, not a quiet pass"

  # 2. A flag claimed in FLAGS and mapped to no skill. Worse than an absent flag:
  #    it is announced and then resolves to nothing.
  dfix="$TMP/doc-nomap"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" 's/^FLAGS=(--alpha --beta)$/FLAGS=(--alpha --beta --gamma)/'
  docommit "$dfix"
  says "$dfix" 'has no skill_for() mapping' "a flag with no skill_for() arm is reported"

  # 3. Mapped, but with no block to inject. The flag fires and says nothing.
  dfix="$TMP/doc-noblock"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" 's/^  --beta)$/  --betaX)/'; docommit "$dfix"
  says "$dfix" 'has no block_for() case' "a flag whose block_for() case is gone is reported"

  # 4. The grant comparison, which is the only thing that reads the heredoc's
  #    `Authorization:` line at all. Reword that line's shape in wss-doctor.sh and
  #    the hook side comes back empty, the flag is skipped, and this fixture —
  #    a flag that grants push where the matrix grants nothing — passes.
  dfix="$TMP/doc-grant"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" 's/^Authorization: none\.$/Authorization: COMMIT and push./'
  docommit "$dfix"
  says "$dfix" 'grants disagree' "a flag that gained push in the hook alone is reported"

  # 5. The other half of the same comparison: the matrix row. A flag stating a
  #    grant that the authority does not list is either an undocumented flag or
  #    one that should not exist, and both need a human.
  dfix="$TMP/doc-norow"; docfix "$dfix"
  edit_ "$dfix/workflow/WSS.OWNERSHIP.md" '/^| beta |/d'; docommit "$dfix"
  says "$dfix" 'no row in' "a flag missing from WSS.OWNERSHIP.md's matrix is reported"

  # 6. Neither half readable. Reword, indent or drop a block's `Authorization:`
  #    line and the hook side comes back empty for every flag at once — which is
  #    indistinguishable from a parser that has gone blind, and used to be
  #    reported as agreement. A check that could not look must say so.
  dfix="$TMP/doc-noauth"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" 's/^Authorization:/**Authorization**:/'; docommit "$dfix"
  says "$dfix" 'compared against nothing' "a block with no readable Authorization line is reported"
  printf '%s' "$(doc "$dfix")" | grep -q "every flag's grant matches" \
    && bad "the grant check claimed a match while it could read no grant at all" \
    || ok "an unreadable grant withholds the pass line instead of claiming a match"

  # 7. A dangling authority citation — failure (2) in wss-doctor.sh's own header.
  #    The grep that finds these is a fixed alternation of citing phrases, so it
  #    goes blind to a whole class the moment one is edited out.
  dfix="$TMP/doc-dangling"; docfix "$dfix"
  printf 'Dispatch via `ghost-skill`.\n' >> "$dfix/skills/alpha-skill/SKILL.md"
  docommit "$dfix"
  says "$dfix" 'resolves to neither' "a citation of a skill that exists nowhere is reported"

  # 8. A link whose heading moved. It opens the top of the file instead, which
  #    is indistinguishable from a live link to anyone who does not click it.
  if command -v python3 >/dev/null 2>&1; then
    dfix="$TMP/doc-anchor"; docfix "$dfix"
    printf 'Also [gone](workflow/WSS.OWNERSHIP.md#no-such-heading).\n' >> "$dfix/README.md"
    docommit "$dfix"
    says "$dfix" 'no-such-heading' "a link to a heading that does not exist is reported"
  fi

  # 9. --strict, in the direction that matters. The warn class carries the real
  #    drift — "resolves nowhere", "grants disagree" — and only fails set exit 1,
  #    so without this flag all of it lands green in CI.
  dfix="$TMP/doc-warn"; docfix "$dfix"
  rm -rf "$dfix/skills/beta-skill"; docommit "$dfix"
  says "$dfix" 'resolves in neither' "a flag whose skill is absent warns"
  doc "$dfix" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "a warning alone does not fail an ordinary run" \
               || bad "the warn class failed a plain run — --strict then means nothing"
  doc "$dfix" --strict >/dev/null 2>&1
  [ $? -eq 1 ] && ok "--strict turns that same warning into exit 1" \
               || bad "--strict passed a run with warnings — CI's only guard against warn-class drift"

  # 10. "Checked nothing" must not read as "everything resolved". The citing-
  #     phrase alternation is a shape wss-doctor.sh does not own — it is prose,
  #     written by hand in every skill file — so rewording those phrases, or
  #     adding a way of citing an authority the alternation does not list, blinds
  #     the extractor for every file at once. The clean fixture reaches this
  #     without any mutation: its two skills cite nothing, so the extractor
  #     legitimately returns nothing, and the old pass line claimed resolution
  #     over an empty set. Test 7 plants a dangling citation and proves the check
  #     can see; this proves it admits when it saw nothing.
  printf '%s' "$out" | grep -q 'every cited skill/agent/procedure resolves' \
    && bad "the cross-reference check claimed every citation resolves having extracted none" \
    || ok "a fixture with no citations withholds the resolution claim"
  printf '%s' "$out" | grep -q 'no skill/agent/procedure citations to check' \
    && ok "it says it had nothing to check instead" \
    || bad "the cross-reference check said neither that it passed nor that it was empty"

  # 11. The same rule one section up. A citation the extractor CAN see must be
  #     reported with its count, so a drop to zero is visible rather than
  #     indistinguishable from a clean run.
  dfix="$TMP/doc-cites"; docfix "$dfix"
  printf 'Dispatch via `beta-skill`.\n' >> "$dfix/skills/alpha-skill/SKILL.md"
  docommit "$dfix"
  says "$dfix" 'every cited skill/agent/procedure resolves (1 checked)' \
    "a resolvable citation is counted in the pass line"

  # 12. Hook commands, same defect class. The jq selector below walks a layout
  #     this script does not own — settings.json's hook shape is Claude Code's,
  #     and it has changed before. Restructure it and the selector matches
  #     nothing, the loop never runs, and the section prints no failure at all:
  #     silence that is indistinguishable from every hook being fine.
  dfix="$TMP/doc-hookshape"; docfix "$dfix"
  printf '%s\n' '{"hooks":{"UserPromptSubmit":[{"handlers":[{"type":"command","command":"~/.claude/wss-shorthand-flags.sh"}]}]}}' \
    > "$dfix/settings.json"
  docommit "$dfix"
  says "$dfix" 'no command could be read out of them' \
    "a hook layout whose commands cannot be read is reported, not passed over"

  # 13. A dispatch-only skill with no `skillOverrides` entry. Its description
  #     loads in every session of every project while never being used as a
  #     trigger, because no flag maps to it — and nothing about the file says so.
  #     Four primitives were added at once on 2026-08-01 and all four were
  #     forgotten together, which is the case this assertion is written from.
  #     The clean fixture cannot exercise it: both its skills are flag-mapped.
  dfix="$TMP/doc-nooverride"; docfix "$dfix"
  mkdir -p "$dfix/skills/gamma-writer"
  printf '# gamma-writer\n\nReached only by dispatch.\n' > "$dfix/skills/gamma-writer/SKILL.md"
  docommit "$dfix"
  says "$dfix" 'reached only by dispatch' \
    "a dispatch-only skill with no skillOverrides entry is reported"

  # The other half, and the one that catches a check gone blind: the clean
  # fixture must say it looked. A parser that matched nothing reports every
  # fixture as fine by saying nothing at all.
  printf '%s' "$out" | grep -q 'every dispatch-only skill is set to name-only' \
    && ok "the override check reports that it ran on a clean fixture" \
    || bad "the override check said nothing on a clean fixture — it may be blind"

  # 14. The inbox counter, both directions — the doctor's copy of the rule the
  #     session hook is tested on above. The marker suppresses the fenced
  #     template; its absence must not suppress real entries, because no filing
  #     template mentions the marker and a fresh machine's inbox is bare
  #     (audit pass 9, F1).
  dfix="$TMP/doc-inbox"; docfix "$dfix"
  printf '## [open] filed bare from a fresh machine\n' > "$dfix/WSS.BUG-REPORTS.md"
  says "$dfix" '1 open bug report' \
    "the doctor counts a marker-less inbox in full"
  printf '# Bug reports\n\n```\n## [open] <one-line summary>\n```\n\n<!-- Append new entries below this line. -->\n' > "$dfix/WSS.BUG-REPORTS.md"
  printf '%s' "$(doc "$dfix")" | grep -q 'no open entries' \
    && ok "the fenced template above the marker still counts as nothing" \
    || bad "an empty marked inbox reads as having open entries"

  # 15. plugin.json's version against the newest tag. The plugin cache path
  #     keys on that field, so a trailing version means two published vintages
  #     overwrite one directory — found two tags behind with no owner by audit
  #     pass 10 (F2). Leading passes: the release procedure bumps before it
  #     tags, so a version ahead of the tags is a release in flight.
  dfix="$TMP/doc-pver"; docfix "$dfix"
  mkdir -p "$dfix/.claude-plugin"
  printf '{"name":"x","version":"0.1.0"}\n' > "$dfix/.claude-plugin/plugin.json"
  docommit "$dfix"
  git -C "$dfix" tag v0.2.0
  says "$dfix" 'plugin.json says 0.1.0 while the newest tag is v0.2.0' \
    "a plugin manifest trailing the newest tag is reported"
  printf '{"name":"x","version":"0.2.0"}\n' > "$dfix/.claude-plugin/plugin.json"
  docommit "$dfix"
  printf '%s' "$(doc "$dfix")" | grep -q 'matches the newest tag v0.2.0' \
    && ok "a matching plugin version passes" \
    || bad "a matching plugin version did not pass"
  printf '{"name":"x","version":"0.3.0"}\n' > "$dfix/.claude-plugin/plugin.json"
  docommit "$dfix"
  printf '%s' "$(doc "$dfix")" | grep -q 'leads the newest tag' \
    && ok "a leading plugin version is a release in flight, not a warning" \
    || bad "a leading plugin version warned or failed"

fi

# ------------------------------------------------------- the transfer queue

head_ "wss-lane-record-sync is reachable only by slash"

# No flag, no wrapper, and both are design constraints rather than omissions:
# the run is expensive and it writes into every lane's inbox, so it must never
# fire from a phrase in a sentence or from another skill's dispatch. A flag
# added later would remove that property silently — nothing else would fail.
synch="$_root/skills/wss-lane-record-sync/SKILL.md"
[ -f "$synch" ] && ok "the skill exists" || bad "skills/wss-lane-record-sync/SKILL.md is missing"
case " $FLAGS " in
  *lane-record-sync*)
    bad "wss-lane-record-sync has a FLAGS entry — it is slash-only by design" ;;
  *) ok "no flag serves it" ;;
esac
if [ -e "$_root/commands/wss-lane-record-sync.md" ]; then
  bad "a commands/ wrapper exists for it — a wrapper must fire a flag, and it has none"
else
  ok "no commands/ wrapper for it"
fi
# The main-checkout precondition is the one that makes its findings trustworthy:
# from a lane it would read siblings as the integration branch last delivered
# them and report a partial picture as a complete one.
grep -q 'main checkout, never a lane worktree' "$synch" \
  && ok "it states the main-checkout precondition" \
  || bad "the main-checkout precondition is gone — a lane run would report a stale picture as complete"

# The four rulings, and the asymmetry that is the only reason two of them are
# separate answers. Defer and Decline both file nothing; if Decline stops being
# written down they collapse, every run re-litigates every rejection, and the
# gate degrades into a prompt the user clears unread — which costs the
# approvals that actually matter.
for r in 'Accept as critical' 'Accept' 'Defer' 'Decline'; do
  grep -q "\*\*$r\*\*" "$synch" \
    && ok "the '$r' ruling is offered" \
    || bad "the '$r' ruling is gone from the gate"
done
grep -q 'WSS.record.decisionsIndex' "$synch" \
  && ok "a previous run's declines are read back, so they are not re-asked" \
  || bad "the decline lookup is gone — the skill is stateless and re-litigates every rejection"
grep -qi 'remembered nowhere' "$synch" \
  && ok "a deferral is deliberately not remembered" \
  || bad "the defer semantics are gone — if a deferral is remembered it is just a decline"

head_ "A lane's transfer queue is a sibling of records, not one of them"

# The queue is how a lane files work into another lane WITHOUT writing its
# records, which is what keeps one-writer-per-record intact. Every assertion
# here defends that: put it under `records` and it becomes a record with many
# writers; declare it for some lanes only and the rest get their requests
# written by hand into their records instead, which is the second writer the
# queue exists to prevent.
tq="$TMP/transfer-queue"
drun_tq() { (cd "$tq" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
                bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); }
rm -rf "$tq"; mkdir -p "$tq/.claude" "$tq/docs/transfer"
printf '# Backlog\n' > "$tq/WSS.TODO.md"
printf '# Backlog\n' > "$tq/TODO.design.md"
printf '# Backlog\n' > "$tq/TODO.data.md"
printf '# Transfer queue\n' > "$tq/docs/transfer/design.md"
printf '# Transfer queue\n' > "$tq/docs/transfer/data.md"

lanes_json() { # $1 = design's extra keys, $2 = data's extra keys
  cat > "$tq/.claude/WSS.WORKFLOW.json" <<JSON
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": "WSS.TODO.md" },
  "lanes": { "named": {
    "design": { "scope": ["d/**"], "records": { "todo": "TODO.design.md" }$1 },
    "data":   { "scope": ["t/**"], "records": { "todo": "TODO.data.md" }$2 } } } }
}
JSON
}

# Declared for every lane: the ordinary case.
lanes_json ', "transfer": "docs/transfer/design.md"' ', "transfer": "docs/transfer/data.md"'
out=$(drun_tq)
case $out in
  *"every lane declares a transfer queue and its path exists"*)
    ok "a queue per lane, each path resolving, passes" ;;
  *) bad "a correctly declared pair of queues did not pass: $(printf '%s' "$out" | grep -i transfer)" ;;
esac

# Declared for one lane only. The other lane is one nothing can file to.
lanes_json ', "transfer": "docs/transfer/design.md"' ''
out=$(drun_tq)
case $out in
  *"transfer queue is declared for 1 of 2 lanes"*)
    ok "a half-declared queue is a FAILURE, like a half-split record" ;;
  *) bad "a queue declared for one lane of two passed — the other lane's requests land in its records by hand" ;;
esac

# Declared, but the file is not there. An absent queue is not an empty one.
lanes_json ', "transfer": "docs/transfer/design.md"' ', "transfer": "docs/transfer/gone.md"'
out=$(drun_tq)
case $out in
  *"WSS.lanes.named.data.transfer is missing"*)
    ok "a declared queue whose file is absent is a FAILURE" ;;
  *) bad "a missing queue path passed — a sibling appending to it creates a file nothing reads" ;;
esac

# Inside `records` rather than beside it. This is the mistake the nesting
# exists to make impossible, so it gets its own message rather than the
# generic not-a-splittable-record one.
cat > "$tq/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": "WSS.TODO.md" },
  "lanes": { "named": {
    "design": { "scope": ["d/**"],
      "records": { "todo": "TODO.design.md", "transfer": "docs/transfer/design.md" } },
    "data": { "scope": ["t/**"], "records": { "todo": "TODO.data.md" } } } } }
}
JSON
out=$(drun_tq)
case $out in
  *"the transfer queue is a"*"SIBLING of records"*)
    ok "transfer under records is refused, and says where it belongs" ;;
  *) bad "transfer was accepted under records — a record with many writers" ;;
esac

# No queues at all is legal: an unsplit-in-practice project, or one whose lanes
# genuinely never file to each other. It must not read as a failure.
lanes_json '' ''
out=$(drun_tq)
case $out in
  *"no transfer queues declared"*)
    ok "declaring no queues at all is reported, not failed" ;;
  *) bad "a project with no queues was failed or went unmentioned" ;;
esac

# --- the conflict inbox: ONE per project, not one per lane ------------------
# A contradiction between two lanes belongs to neither, so it is a sibling of
# `named` rather than a key inside a lane. wss-lane-record-sync is its only
# consumer, which is what makes a declared-but-absent path the dangerous case:
# a session appends and creates a file nothing was told to read.
printf '# Conflict inbox\n' > "$tq/docs/conflicts.md"
cat > "$tq/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": "WSS.TODO.md" },
  "lanes": { "named": { "design": { "scope": ["d/**"], "records": {} },
                        "data":   { "scope": ["t/**"], "records": {} } },
             "conflicts": "docs/conflicts.md" } }
}
JSON
out=$(drun_tq)
case $out in
  *"conflict inbox declared and present"*)
    ok "a declared conflict inbox that exists passes" ;;
  *) bad "a valid WSS.lanes.conflicts did not pass: $(printf '%s' "$out" | grep -i conflict)" ;;
esac
case $out in
  *"'conflicts' is not a splittable record"*|*"WSS.MANIFEST.md does not document"*)
    bad "WSS.lanes.conflicts reads as an unknown key — declaring it is dead config" ;;
  *) ok "WSS.lanes.conflicts is a known manifest key" ;;
esac

cat > "$tq/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": "WSS.TODO.md" },
  "lanes": { "named": { "design": { "scope": ["d/**"], "records": {} },
                        "data":   { "scope": ["t/**"], "records": {} } },
             "conflicts": "docs/gone.md" } }
}
JSON
out=$(drun_tq)
case $out in
  *"WSS.lanes.conflicts is missing"*)
    ok "a declared inbox whose file is absent is a FAILURE" ;;
  *) bad "a missing WSS.lanes.conflicts passed — a filed contradiction would go nowhere" ;;
esac

# Declared with no lanes at all: nothing can write it and the skill refuses to
# run, so it is dead config rather than a fault.
cat > "$tq/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": "WSS.TODO.md" },
  "lanes": { "conflicts": "docs/conflicts.md" } }
}
JSON
out=$(drun_tq)
case $out in
  *"WSS.lanes.conflicts is declared but no lanes are named"*)
    ok "an inbox with no lanes is warned about as dead config" ;;
  *) bad "WSS.lanes.conflicts with no lanes passed silently" ;;
esac

# The skill must state that a filed entry is re-verified rather than acted on,
# and must report both halves of what it did with the inbox. Drop either and the
# gate becomes a rubber stamp on evidence from a session that is long gone.
grep -q 'a claim, not a conflict' "$synch" \
  && ok "the inbox's entries are claims to be re-verified" \
  || bad "the re-verification rule is gone — synch would act on unchecked reports"
grep -q 'deleted as not reproducing' "$synch" \
  && ok "the report covers deletions, not only promotions" \
  || bad "the report no longer names what was deleted — a rubber stamp reads identically"

# ------------------------------------------------- a lane lands on integration

head_ "A lane wrap fast-forwards onto the integration branch, or is refused"

# --wss-wrap in a lane worktree pushes the lane's branch and then lands it on
# WSS.branch.integration. The whole safety argument is that this is NOT a merge:
# a refspec push with no leading `+` fast-forwards or the remote refuses it, so
# a wrap can never hit a conflict at the one moment its context is being
# cleared. Two things are pinned here — that git really behaves that way, since
# the design has no conflict handling BECAUSE of it, and that the hook block
# still says so, since "simplify" on that line means a force push.

out=$(run --wss-wrap)
case $out in
  *'NO leading `+`'*) ok "the wrap block spells out the no-force refspec" ;;
  *) bad "the --wss-wrap block lost the no-leading-plus rule — a lane landing could become a force push" ;;
esac
case $out in
  *"session is ending rather than because the work was approved"*)
    ok "the wrap block withholds the landing on an unfinished-work wrap" ;;
  *) bad "the unfinished-work guard is gone — half-done work would land on the branch every lane syncs from" ;;
esac

# The mechanism itself, against a real remote. If this ever stopped holding,
# every "report and stop" above would be silently wrong.
ff="$TMP/lane-ff"
rm -rf "$ff"; mkdir -p "$ff"
git init -q --bare "$ff/origin.git" 2>/dev/null
git init -q "$ff/w" 2>/dev/null
git -C "$ff/w" config user.email t@test; git -C "$ff/w" config user.name t
git -C "$ff/w" config commit.gpgsign false
git -C "$ff/w" remote add origin "$ff/origin.git"
printf 'base\n' > "$ff/w/f.txt"
git -C "$ff/w" add -A >/dev/null 2>&1
git -C "$ff/w" commit -q -m base >/dev/null 2>&1
git -C "$ff/w" push -q origin HEAD:refs/heads/dev >/dev/null 2>&1

# A lane branched from dev, one commit ahead: the ordinary case, and it lands.
git -C "$ff/w" checkout -q -b lane 2>/dev/null
printf 'lane\n' >> "$ff/w/f.txt"
git -C "$ff/w" commit -qam lane >/dev/null 2>&1
if git -C "$ff/w" push -q origin lane:dev >/dev/null 2>&1; then
  ok "a lane ahead of integration fast-forwards onto it"
else
  bad "a fast-forwardable lane was refused — the ordinary case does not work"
fi

# dev moves underneath, as another lane landing would move it. The lane is now
# divergent, and the push must be REFUSED rather than merged or forced.
git -C "$ff/w" checkout -q -B other origin/dev 2>/dev/null
printf 'other\n' > "$ff/w/g.txt"
git -C "$ff/w" add -A >/dev/null 2>&1
git -C "$ff/w" commit -q -m other >/dev/null 2>&1
git -C "$ff/w" push -q origin other:dev >/dev/null 2>&1
git -C "$ff/w" checkout -q lane 2>/dev/null
printf 'more\n' >> "$ff/w/f.txt"
git -C "$ff/w" commit -qam more >/dev/null 2>&1
if git -C "$ff/w" push -q origin lane:dev >/dev/null 2>&1; then
  bad "a DIVERGED lane was accepted onto integration — the refusal this design rests on did not happen"
else
  ok "a diverged lane is refused, not merged: nothing to conflict, nothing to unwind"
fi
# And the refusal left integration exactly where the other lane put it.
git -C "$ff/w" fetch -q origin >/dev/null 2>&1
[ "$(git -C "$ff/w" rev-parse origin/dev)" = "$(git -C "$ff/w" rev-parse other)" ] \
  && ok "the refused push moved nothing on the integration branch" \
  || bad "a refused push still moved WSS.branch.integration"

# ------------------------------------------------------- roadmap vs releases

head_ "Goals split by lane; the release list never does"

# WSS.record.roadmap holds goals and may split per lane. WSS.record.releases holds the
# milestones, their versions and their marks, never splits, and is the only
# planning record --wss-release reads. The prohibition below is the ONLY thing
# keeping a release checkpoint singular once roadmaps split — a version or a
# mark in a lane's roadmap is a checkpoint one worktree cut for the whole
# project, and nothing downstream would ever notice it.
rvp="$TMP/roadmap-releases"
drun_rvp() { (cd "$rvp" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
                bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); }
rm -rf "$rvp"; mkdir -p "$rvp/.claude"
printf '# Roadmap\n\n## A goal\n\n- [ ] **A block.**\n' > "$rvp/WSS.ROADMAP.md"
printf '# Release list\n\n## `0.1.0` — first — *completed*\n' > "$rvp/WSS.RELEASES.md"
printf '# Roadmap\n\n## Backend goal\n' > "$rvp/ROADMAP.backend.md"
printf '# Backlog\n' > "$rvp/WSS.TODO.md"
printf '# Backlog\n' > "$rvp/TODO.backend.md"

# 1. WSS.record.releases is a key the doctor knows. An unknown key is dead config.
cat > "$rvp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "roadmap": "WSS.ROADMAP.md", "releases": "WSS.RELEASES.md" } }
}
JSON
out=$(drun_rvp)
case $out in
  *"WSS.record.releases"*"nothing reads"*|*"unknown"*"WSS.record.releases"*)
    bad "WSS.record.releases reads as an unknown manifest key — declaring it is dead config" ;;
  *) ok "WSS.record.releases is a known manifest key" ;;
esac

# 2. roadmap may be redirected per lane — it is the fourth splittable record.
cat > "$rvp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "roadmap": "WSS.ROADMAP.md", "releases": "WSS.RELEASES.md", "todo": "WSS.TODO.md" },
  "lanes": { "named": { "backend": { "scope": ["b/**"],
    "records": { "roadmap": "ROADMAP.backend.md", "todo": "TODO.backend.md" } } } } }
}
JSON
out=$(drun_rvp)
case $out in
  *"'roadmap' is not a splittable record"*)
    bad "a lane roadmap was refused — goals are exactly what splits by lane" ;;
  *) ok "roadmap may be redirected under a lane's records" ;;
esac

# 3. releases may NOT. This is the rule the whole split rests on.
cat > "$rvp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "roadmap": "WSS.ROADMAP.md", "releases": "WSS.RELEASES.md" },
  "lanes": { "named": { "backend": { "scope": ["b/**"],
    "records": { "roadmap": "ROADMAP.backend.md", "releases": "RELEASES.backend.md" } } } } }
}
JSON
out=$(drun_rvp)
case $out in
  *"the release list never"*"splits"*)
    ok "a per-lane release list is refused, and says why" ;;
  *) bad "WSS.lanes.named.<lane>.records.releases was accepted — N lanes, N release checkpoints" ;;
esac

# 4. A version or a completion mark in ANY roadmap heading fails — lane or not.
#    Heading-anchored: prose may mention a version, a heading may not.
cat > "$rvp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "roadmap": "WSS.ROADMAP.md", "releases": "WSS.RELEASES.md" } }
}
JSON
printf '# Roadmap\n\n## A goal — *completed*\n\n- [ ] **A block.**\n' > "$rvp/WSS.ROADMAP.md"
out=$(drun_rvp)
case $out in
  *"carries a version number or a completion mark in a heading"*)
    ok "a completion mark in a roadmap heading FAILS the doctor" ;;
  *) bad "a roadmap heading carrying *completed* passed — that is a release checkpoint in the wrong file" ;;
esac

printf '# Roadmap\n\n## `0.7.0` — a goal\n\n- [ ] **A block.**\n' > "$rvp/WSS.ROADMAP.md"
out=$(drun_rvp)
case $out in
  *"carries a version number or a completion mark in a heading"*)
    ok "a version number in a roadmap heading FAILS the doctor" ;;
  *) bad "a roadmap heading carrying a version passed" ;;
esac

# The lane's copy is held to the same rule, and it is the one that matters most.
cat > "$rvp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "roadmap": "WSS.ROADMAP.md", "releases": "WSS.RELEASES.md", "todo": "WSS.TODO.md" },
  "lanes": { "named": { "backend": { "scope": ["b/**"],
    "records": { "roadmap": "ROADMAP.backend.md", "todo": "TODO.backend.md" } } } } }
}
JSON
printf '# Roadmap\n\n## A goal\n\n- [ ] **A block.**\n' > "$rvp/WSS.ROADMAP.md"
printf '# Roadmap\n\n## Backend goal — *completed*\n' > "$rvp/ROADMAP.backend.md"
out=$(drun_rvp)
case $out in
  *"ROADMAP.backend.md carries a version number or a completion mark"*)
    ok "a LANE roadmap is held to the rule too — the case the split exists for" ;;
  *) bad "a mark in a lane roadmap passed: one worktree cutting a checkpoint for the whole project" ;;
esac

# Prose is not a heading. A block may say a thing ships in 2.x without that
# being a milestone, and a check that cannot tell them apart gets switched off.
printf '# Roadmap\n\n## A goal\n\nBlocked until the rewrite ships in 2.1.0.\n\n- [ ] **A block.**\n' \
  > "$rvp/WSS.ROADMAP.md"
printf '# Roadmap\n\n## Backend goal\n' > "$rvp/ROADMAP.backend.md"
out=$(drun_rvp)
case $out in
  *"carries a version number or a completion mark in a heading"*)
    bad "a version mentioned in ordinary prose was reported — the check is heading-anchored" ;;
  *) ok "a version in prose is not a finding" ;;
esac

# -------------------------------------------------------------------- result

head_ "A provider-backed backlog is not mistaken for files"

# WSS.record.todo may be a provider object instead of a path. Two things must hold,
# and both were broken by the first version: the manifest path walk must not
# treat the provider name, repo slug and label as three declared files, and the
# SessionStart backlog nudge must skip a backlog it cannot measure rather than
# testing `-f` against a blob of JSON and skipping by luck.
provp="$TMP/provider-proj"
mkdir -p "$provp/.claude"
cat > "$provp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": { "provider": "github-issues", "repo": "o/n", "label": "backlog" } } }
}
JSON
out=$(cd "$provp" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"declared in WSS.WORKFLOW.json but missing: github-issues"*|\
  *"declared in WSS.WORKFLOW.json but missing: o/n"*|\
  *"declared in WSS.WORKFLOW.json but missing: backlog"*)
    bad "the manifest path walk read a provider object as declared file paths" ;;
  *) ok "a provider object is not walked as declared paths" ;;
esac
case $out in
  *"nothing implements"*) bad "github-issues reported as unimplemented" ;;
  *) ok "github-issues is recognised as a real provider" ;;
esac

cat > "$provp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2", "record": { "todo": { "provider": "acme-tracker", "repo": "o/n" } } }
}
JSON
out=$(cd "$provp" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"nothing implements"*) ok "a provider nothing implements is a FAILURE, not a silent fallback" ;;
  *) bad "an unimplemented provider passed — --wss-todo would write nowhere and say nothing" ;;
esac

# The nudge must be silent here, and for the stated reason rather than by luck.
out=$(cd "$provp" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
      | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
case $out in
  *"open item(s) in"*) bad "the backlog-age nudge fired on a provider it cannot measure" ;;
  *) ok "the backlog-age nudge skips a provider-backed backlog" ;;
esac

head_ "Installation paths in runnable blocks"

# ~/.claude is the config directory in both install forms but the INSTALLATION
# only in a checkout, so a fenced block running ~/.claude/wss-doctor.sh is dead under
# a plugin. The check exists because the class recurred inside the commit that
# claimed to close it: the fix grepped for the inline-backtick form, so every
# surviving instance — all of them in fenced blocks — reported clean.
#
# CLAUDE_CONFIG_DIR redirects CLAUDE_DIR, which is what md_files_ scans, so the
# fault is planted in a scratch suite rather than in the real tree.
instp="$TMP/instpath"
mkdir -p "$instp/skills/demo"
printf '# Demo\n\n```bash\n~/.claude/wss-doctor.sh\n```\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    ok "a fenced block hard-coding an installation path FAILS" ;;
  *) bad "a fenced ~/.claude/wss-doctor.sh passed — it is dead under a plugin install" ;;
esac

# The same path in prose must NOT fire. Prose is a wrong label and a judgement
# call; only the runnable form is a fault, and a check that fired on both would
# be ignored for its noise.
printf '# Demo\n\nRun `~/.claude/wss-doctor.sh` when in doubt.\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    bad "the check fired on a prose mention, which it must not" ;;
  *) ok "a prose mention of an installation path does not fire the check" ;;
esac

# The one sanctioned exemption, per line so it cannot silently cover a block.
printf '# Demo\n\n```bash\n~/.claude/wss-doctor.sh   # doctor:checkout-only\n```\n' \
  > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    bad "the doctor:checkout-only marker did not suppress the check" ;;
  *) ok "the doctor:checkout-only marker suppresses the check, per line" ;;
esac

# $CLAUDE_PLUGIN_ROOT is right for a hook and useless in a fenced block: measured
# 2026-08-02 from a real git-hosted install, it is EMPTY in a model-run Bash
# command, so a block keyed on it silently becomes the adopter's own config dir.
printf '# Demo\n\n```bash\n"$CLAUDE_PLUGIN_ROOT"/wss-doctor.sh\n```\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"EMPTY in a"*) ok "a fenced block keyed on \$CLAUDE_PLUGIN_ROOT FAILS" ;;
  *) bad "a fenced \$CLAUDE_PLUGIN_ROOT passed — it is empty in a model-run Bash command" ;;
esac

# The resolver that replaced it must itself pass, or the fix cannot be applied.
printf '# Demo\n\n```bash\nS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"\n[ -x "$S/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/workflow-secretary-suite/*/ 2>/dev/null | tail -1)\n"$S"/wss-doctor.sh\n```\n' \
  > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path"*|*"EMPTY in a"*)
    bad "the sanctioned resolver trips the check it was written to satisfy" ;;
  *) ok "the sanctioned root resolver passes both rules" ;;
esac

# A config-directory path is correct in BOTH forms and must never be flagged —
# the bug inbox and the transcript directory genuinely live at ~/.claude.
printf '# Demo\n\n```bash\ncat ~/.claude/WSS.BUG-REPORTS.md\n```\n' > "$instp/skills/demo/SKILL.md"
out=$(CLAUDE_CONFIG_DIR="$instp" CLAUDE_DIR="$instp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"runs an installation path that only exists in a checkout"*)
    bad "the check flagged a config-directory path, which is correct in both forms" ;;
  *) ok "a config-directory path in a fenced block is not flagged" ;;
esac

head_ "The doctor inspects the installation it shipped with"

# The defect this guards was live in the tree published on 2026-08-02, for about
# an hour. CLAUDE_DIR fell back to CONFIG_DIR whenever $CLAUDE_PLUGIN_ROOT was
# absent — and it is absent in every model-run or hand-run Bash command, which is
# how the doctor is normally invoked. So an adopter who installed the plugin and
# ran the command every skill prescribes got three failures and an empty skill
# enumeration, on a correct install, from the check the README tells them not to
# skip.
#
# The fixture must sit OUTSIDE any git checkout: "am I a plugin" is answered
# partly by not being the root of one, and building this under $TMP inside the
# repo would make the answer depend on where the suite happens to run.
# Under the real cache layout, `plugins/cache/<marketplace>/<plugin>/<version>/`,
# because that is what identifies an install now — not the absence of a `.git`,
# which varies by how the marketplace was fetched.
pdir=$(mktemp -d)/plugins/cache/mk/demo-plugin/0.0.1
mkdir -p "$pdir/.claude-plugin" "$pdir/skills/demo" "$pdir/hooks" "$pdir/workflow"
printf '{"name":"x","version":"0.0.1","description":"d"}\n' > "$pdir/.claude-plugin/plugin.json"
printf -- '---\nname: demo\ndescription: d\n---\n\nBody.\n' > "$pdir/skills/demo/SKILL.md"
cp "$HOOK" "$pdir/hooks/wss-shorthand-flags.sh" 2>/dev/null || : > "$pdir/hooks/wss-shorthand-flags.sh"
cp "$CHECK" "$pdir/hooks/wss-session-check.sh" 2>/dev/null || : > "$pdir/hooks/wss-session-check.sh"
printf '.credentials.json\n' > "$pdir/.gitignore"
cp "$DOCTOR" "$pdir/wss-doctor.sh"; chmod +x "$pdir/wss-doctor.sh"

bare=$(mktemp -d)   # the adopter's own config dir: no skills, no hooks, no repo
printf '{"permissions":{"defaultMode":"auto"}}\n' > "$bare/settings.json"

out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$bare" bash "$pdir/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"not a git checkout"*|*"wss-shorthand-flags.sh missing"*)
    bad "the doctor read the config dir as the installation with CLAUDE_PLUGIN_ROOT unset" ;;
  *) ok "a plugin-root doctor inspects itself, not the adopter's config dir" ;;
esac
case $out in
  *"no skills could be enumerated"*)
    bad "the doctor enumerated no skills while sitting in a tree that has one" ;;
  *) ok "and finds the skills that shipped with it" ;;
esac

# A plugin fetched from a git-hosted marketplace over SSH IS a clone and IS its
# own git toplevel. The first version of this rule asked "am I not a toplevel",
# which is not a property of being a plugin, so that shape regressed straight
# back to the defect above. Build the fixture under a path with the real cache
# layout in it, because that is what the rule keys on now.
gdir=$(mktemp -d)/plugins/cache/mk/demo-plugin/0.0.1
mkdir -p "$gdir"; cp -r "$pdir"/. "$gdir"/
git -C "$gdir" init -q .
out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$bare" bash "$gdir/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"not a git checkout"*|*"wss-shorthand-flags.sh missing"*)
    bad "a plugin that carries its own .git regressed to reading the config dir" ;;
  *) ok "a plugin cache that is itself a clone is still a plugin" ;;
esac

# And the direction that loses checks rather than adding noise: a checkout
# reached through a symlink reports a LOGICAL path. That made a real checkout
# announce itself as a plugin and silently drop the credentials and settings
# checks — worse than any false failure, because a check that disappears reports
# nothing.
#
# Hermetic: a fixture that is a git checkout root AND carries a plugin manifest,
# which is exactly the source repository's own shape. Pointing this at the real
# tree instead made it depend on $HOME/.claude existing, so it proved nothing on
# a CI runner — and said so, because the third branch below exists.
cdir=$(mktemp -d)/checkout
mkdir -p "$cdir"; cp -r "$pdir"/. "$cdir"/
git -C "$cdir" init -q .
sdir=$(mktemp -d)/link; ln -s "$cdir" "$sdir"
out=$(cd "$sdir" && CLAUDE_CONFIG_DIR="$sdir" bash "$sdir/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"installed as a plugin"*)
    bad "a symlinked checkout read as a plugin — the credentials check goes off with it" ;;
  *"all checks passed"*|*"failed"*)
    ok "a symlinked checkout is still a checkout" ;;
  *) bad "symlinked checkout: the doctor produced no result, so this proved nothing" ;;
esac

# The other half of the same rule, and the reason self-preference is conditional
# rather than absolute: pointing the doctor at a synthetic installation through
# CLAUDE_CONFIG_DIR is how every fixture above drives it. A doctor that always
# preferred its own location would report those fixtures on a tree it never read.
out=$(CLAUDE_CONFIG_DIR="$TMP/doc-clean" CLAUDE_DIR="$TMP/doc-clean" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"all checks passed"*)
    ok "CLAUDE_CONFIG_DIR still redirects the installation for a checkout doctor" ;;
  *) bad "CLAUDE_CONFIG_DIR no longer reaches the installation: $(printf '%s' "$out" | grep -a FAIL | head -2)" ;;
esac

# ------------------------------------------------- plugin/checkout coexistence
#
# Both install forms on one machine double-fire the hooks. The doctor must FAIL
# on the combination through either evidence route (cache directory, or
# enabledPlugins naming the suite), stay quiet on either form alone, and warn
# on the residue an uninstall leaves behind in a tracked settings.json.

co="$TMP/doc-coexist"
docfix "$co"
mkdir -p "$co/.claude-plugin"
printf '{"name":"workflow-secretary-suite","version":"0.0.1","description":"d"}\n' \
  > "$co/.claude-plugin/plugin.json"
docommit "$co"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'installed at most once' \
  && ok "the checkout form alone is not coexistence" \
  || bad "checkout form alone: the coexistence check reached no verdict"

mkdir -p "$co/plugins/cache/mk/workflow-secretary-suite/0.0.1"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'installed TWICE' \
  && ok "a cached plugin install beside the checkout FAILs as coexistence" \
  || bad "a cached workflow-secretary-suite install beside the checkout passed silently"

rm -rf "$co/plugins"
edit_ "$co/settings.json" 's/{"hooks"/{"enabledPlugins":{"workflow-secretary-suite@mk":true},"hooks"/'
out=$(doc "$co")
printf '%s' "$out" | grep -q 'installed TWICE' \
  && ok "enabledPlugins naming the suite FAILs as coexistence" \
  || bad "enabledPlugins naming workflow-secretary-suite passed silently"

edit_ "$co/settings.json" 's/"enabledPlugins":{"workflow-secretary-suite@mk":true}/"enabledPlugins":{}/'
docommit "$co"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'uninstall residue' \
  && ok "empty enabledPlugins in tracked settings.json warns as residue" \
  || bad "uninstall residue in tracked settings.json went unmentioned"
printf '%s' "$out" | grep -q 'installed TWICE' \
  && bad "residue alone was reported as coexistence" \
  || ok "residue alone is not coexistence"

# An adopter's machine: a cached install present, config dir NOT the suite's
# checkout. The normal plugin case must not be reported as coexistence.
ad=$(mktemp -d)
printf '{"permissions":{"defaultMode":"auto"}}\n' > "$ad/settings.json"
mkdir -p "$ad/plugins/cache/mk/workflow-secretary-suite/0.0.1"
out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$ad" CLAUDE_DIR="$pdir" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
printf '%s' "$out" | grep -q 'installed TWICE' \
  && bad "a plain plugin install with no checkout was reported as coexistence" \
  || ok "a plugin install alone is not coexistence"

# A cached doctor pointed at ANOTHER installation must judge that one, not
# itself. Before this, running the shipped tests from a plugin cache failed 21
# of 162 on a healthy install — every fixture said "inspect this directory" and
# the cached doctor preferred itself, so plugin-shaped checks ran against
# checkout-shaped fixtures. A confident wrong answer from the obvious diagnostic
# is worse than shipping no tests at all.
out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$TMP/doc-clean" CLAUDE_DIR="$TMP/doc-clean" \
      bash "$pdir/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"plugin has no hooks/hooks.json"*|*"installed as a plugin"*)
    bad "a cached doctor applied plugin checks to the checkout it was pointed at" ;;
  *"all checks passed"*)
    ok "an explicit CLAUDE_DIR overrides the doctor's own location" ;;
  *) bad "explicit CLAUDE_DIR: no result line, so this proved nothing" ;;
esac

head_ "A description cannot invite invocation on an ordinary word"

# `wss-wrap` listed `"done"` and `wss-release` listed `"ship it"` — both hold a push
# grant, so "ok that's done" could commit and push. The fix for the class is to
# NAME the tempting word and refuse it, so the check has to pass a description
# that mentions the word in order to forbid it, or it forbids its own remedy.
tp=$(mktemp -d)
mkdir -p "$tp/skills"/{bare,errata,refused,curly,elsewhere,proper}
printf -- '---\nname: bare\ndescription: "Close out. Also trigger on \\"done\\", \\"wrap this up\\"."\n---\n\nB.\n' \
  > "$tp/skills/bare/SKILL.md"
printf -- '---\nname: errata\ndescription: "Release. Also trigger on \\"cut a release\\", \\"ship it\\"."\n---\n\nB.\n' \
  > "$tp/skills/errata/SKILL.md"
printf -- '---\nname: refused\ndescription: "Close out. Also on \\"wrap this up\\". Never infer it from \\"done\\"."\n---\n\nB.\n' \
  > "$tp/skills/refused/SKILL.md"
# Curly quotes are what a description picks up from being drafted anywhere but
# an editor, and the first normaliser here mangled its own input trying to
# handle them — every fixture went quiet at once.
printf -- '---\nname: curly\ndescription: "Close out. Also trigger on \xe2\x80\x9cdone\xe2\x80\x9d."\n---\n\nB.\n' \
  > "$tp/skills/curly/SKILL.md"
# A negation about something ELSE must not license a bare trigger. Reading only
# the trigger clause is what makes this work without an escape hatch.
printf -- '---\nname: elsewhere\ndescription: "Close out. Also trigger on \\"done\\". Not for release notes."\n---\n\nB.\n' \
  > "$tp/skills/elsewhere/SKILL.md"
# And the false positive that would have got the whole check disabled: a quoted
# one-word proper noun in a sentence that is not a trigger clause at all.
printf -- '---\nname: proper\ndescription: "Move work to the publish branch, which is \\"main\\" by default."\n---\n\nB.\n' \
  > "$tp/skills/proper/SKILL.md"
out=$(CLAUDE_DIR="$tp" CLAUDE_CONFIG_DIR="$tp" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
for want in bare errata curly elsewhere; do
  case $out in
    *"'$want' offers one-word trigger"*) ok "trigger fixture '$want' is reported" ;;
    *) bad "trigger fixture '$want' was NOT reported" ;;
  esac
done
case $out in
  *"'refused' offers"*) bad "the check forbids its own remedy — naming a word to refuse it must pass" ;;
  *) ok "naming the word in a sentence that refuses it passes" ;;
esac
case $out in
  *"'proper' offers"*) bad "a quoted proper noun outside any trigger clause was wrongly failed" ;;
  *) ok "a quoted one-word proper noun outside a trigger clause passes" ;;
esac

head_ "The audit index and CI's walks stay in agreement"

# Two checks added after the index skipped pass 6 with nothing noticing, and
# after the frozen-reports exemption once landed in the doctor but not in CI.
# The fixture carries only what the checks read: an audits/ directory and a
# verify.yml holding the exemption pair twice and the bare credential walk once.
ax=$(mktemp -d)
mkdir -p "$ax/audits" "$ax/.github/workflows"
printf '# Index\n\n| `2026-01-01-pass1.md` | first | ok | tree |\n' > "$ax/audits/README.md"
printf '# Report one\n' > "$ax/audits/2026-01-01-pass1.md"
cat > "$ax/.github/workflows/verify.yml" <<'YML'
      run: |
        done < <({ git ls-files -z '*.md' ':(exclude)audits/**'
                   git ls-files -z 'audits/README.md'
                 })
      run: |
        done < <({ git ls-files -z '*.md' '*.sh' ':(exclude)audits/**'
                   git ls-files -z 'audits/README.md'
                 })
      run: |
        done < <(git ls-files -z)
YML
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"every audit report has an index row (1 checked)"*)
    ok "an indexed report passes, and the pass line carries the count" ;;
  *) bad "audit-index check reached no counted verdict on an indexed report" ;;
esac
case $out in
  *"CI's two markdown walks carry md_files_'s exemption pair"*)
    ok "a verify.yml carrying the pair twice passes" ;;
  *) bad "walk-agreement check reached no verdict on an agreeing verify.yml" ;;
esac
case $out in
  *"CI's credential scan still walks every tracked file"*)
    ok "the bare credential walk is recognised" ;;
  *) bad "credential-walk check reached no verdict on a bare walk" ;;
esac

# A report with no row must be named. This is the pass-6 shape exactly.
printf '# Report two\n' > "$ax/audits/2026-01-02-pass2.md"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"no index row for 2026-01-02-pass2.md"*)
    ok "an unindexed report is named as a failure" ;;
  *) bad "a report with no index row went unreported — the pass-6 gap again" ;;
esac
rm -f "$ax/audits/2026-01-02-pass2.md"

# One exemption dropped from one walk is the eleven-red-commits drift.
sed '0,/:(exclude)audits/s/ '\'':(exclude)audits\/\*\*'\''//' \
  "$ax/.github/workflows/verify.yml" > "$ax/.github/workflows/verify.yml.new" \
  && mv "$ax/.github/workflows/verify.yml.new" "$ax/.github/workflows/verify.yml"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"markdown walks disagree with md_files_"*)
    ok "a walk missing the exclusion is reported as disagreement" ;;
  *) bad "verify.yml lost an exclusion and the doctor said nothing" ;;
esac

# The credential scan acquiring the exclusion is the failure in the OTHER
# direction: a walk that must never narrow, narrowed.
sed 's|done < <(git ls-files -z)|done < <(git ls-files -z ":(exclude)audits/**" "audits/README.md-no")|' \
  "$ax/.github/workflows/verify.yml" > "$ax/.github/workflows/verify.yml.new" \
  && mv "$ax/.github/workflows/verify.yml.new" "$ax/.github/workflows/verify.yml"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"credential scan no longer walks"*)
    ok "a narrowed credential walk is reported" ;;
  *) bad "the credential walk narrowed and the doctor said nothing" ;;
esac

# Since 2026-08-07 the index is `WSS.record.audits`, resolved from the tree's
# own manifest; every fixture above declares no key and exercises the
# `audits/README.md` fallback. A declared key must MOVE the check — the row is
# required in the declared file, and a missing row names that file, not the
# fallback.
mkdir -p "$ax/.claude" "$ax/docs"
printf '{"WSS":{"manifest":"workflow/v2","record":{"audits":"docs/WSS.AUDITS.md"}}}\n' \
  > "$ax/.claude/WSS.WORKFLOW.json"
printf '# Audit index\n\n| `2026-01-01-pass1.md` | first | ok | tree |\n' \
  > "$ax/docs/WSS.AUDITS.md"
printf '# Index moved\n' > "$ax/audits/README.md"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"every audit report has an index row (1 checked)"*)
    ok "a declared WSS.record.audits is where the row is looked for" ;;
  *) bad "the index check ignored a declared WSS.record.audits" ;;
esac
printf '# Report two\n' > "$ax/audits/2026-01-02-pass2.md"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"docs/WSS.AUDITS.md has no index row for 2026-01-02-pass2.md"*)
    ok "a missing row names the declared index, not the fallback" ;;
  *) bad "a report with no row in the declared index went unreported" ;;
esac
rm -f "$ax/audits/2026-01-02-pass2.md"

head_ "wss-reset-records.sh cannot write outside the project"

# It ships, it truncates files, and it reads its list from a manifest — which is
# data. A `../` path was followed and blanked, and a symlinked record was written
# through onto its target. Both landed outside the project, so outside its git,
# so unrecoverable.
RR="$_root/wss-reset-records.sh"
if [ ! -x "$RR" ]; then
  bad "wss-reset-records.sh missing or not executable at $RR"
else
  rr=$(mktemp -d); mkdir -p "$rr/proj/.claude" "$rr/outside"
  printf 'PRECIOUS\n' > "$rr/outside/notes.md"
  printf '{"WSS":{"record":{"todo":"../outside/notes.md"}}}\n' > "$rr/proj/.claude/WSS.WORKFLOW.json"
  bash "$RR" --write --dir "$rr/proj" >/dev/null 2>&1; rc=$?
  [ "$(cat "$rr/outside/notes.md")" = "PRECIOUS" ] \
    && ok "a manifest path escaping the project is refused" \
    || bad "wss-reset-records.sh blanked a file OUTSIDE the project"
  # The EXIT CODE is a separate claim from the file surviving, and it was the
  # false half: `refused=1` was assigned inside a command substitution, so it
  # died in that subshell and the fatal block never ran. Discarding rc with
  # `|| :` is what let a script that refuses-and-returns-0 ship, and wss-publish.sh
  # depends on this exit code.
  [ "$rc" -ne 0 ] \
    && ok "and refusing is fatal, not merely loud" \
    || bad "wss-reset-records.sh refused a record and still exited 0"

  printf 'ALSO PRECIOUS\n' > "$rr/outside/target.md"
  ln -s "$rr/outside/target.md" "$rr/proj/WSS.TODO.md"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md"}}}\n' > "$rr/proj/.claude/WSS.WORKFLOW.json"
  bash "$RR" --write --dir "$rr/proj" >/dev/null 2>&1; rc=$?
  [ "$(cat "$rr/outside/target.md")" = "ALSO PRECIOUS" ] \
    && ok "a symlinked record is refused rather than written through" \
    || bad "wss-reset-records.sh wrote through a symlink onto an external file"
  [ "$rc" -ne 0 ] || bad "a symlinked record was refused but the exit code was 0"

  # WSS.HAZARDS.md is blanked by NAME rather than through the manifest, and that
  # path bypassed the containment guard entirely — the one file that could still
  # be written through a symlink, in the change that claimed to close the class.
  hz=$(mktemp -d); mkdir -p "$hz/proj/.claude" "$hz/outside"
  printf '{"WSS":{"record":{}}}\n' > "$hz/proj/.claude/WSS.WORKFLOW.json"
  printf 'PRECIOUS HAZARDS\n' > "$hz/outside/haz.md"
  ln -s "$hz/outside/haz.md" "$hz/proj/.claude/WSS.HAZARDS.md"
  bash "$RR" --write --dir "$hz/proj" >/dev/null 2>&1; rc=$?
  [ "$(cat "$hz/outside/haz.md")" = "PRECIOUS HAZARDS" ] \
    && ok "a symlinked WSS.HAZARDS.md is refused like any other record" \
    || bad "wss-reset-records.sh wrote through .claude/WSS.HAZARDS.md onto an external file"
  [ "$rc" -ne 0 ] || bad "a symlinked WSS.HAZARDS.md was refused but the exit code was 0"

  # And it must still do its job, or the guards above are satisfied by a script
  # that refuses everything.
  mkdir -p "$rr/ok/.claude"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md","roadmap":"WSS.ROADMAP.md","releases":"WSS.RELEASES.md"}}}\n' \
    > "$rr/ok/.claude/WSS.WORKFLOW.json"
  printf '# Backlog\n\nsomeone else content\n' > "$rr/ok/WSS.TODO.md"
  # The top-level records are enumerated here rather than derived, so a record
  # added to the contract and forgotten in this list ships someone's goals and
  # unreleased plans into the assembled tree — silently, since nothing else
  # reads the list against the manifest.
  printf '# Roadmap\n\nsomeone else goals\n' > "$rr/ok/WSS.ROADMAP.md"
  printf '# Release list\n\nsomeone else milestones\n' > "$rr/ok/WSS.RELEASES.md"
  bash "$RR" --write --dir "$rr/ok" >/dev/null 2>&1
  [ "$(cat "$rr/ok/WSS.TODO.md")" = "# Backlog" ] \
    && ok "a record inside the project is still blanked to its heading" \
    || bad "wss-reset-records.sh refused a legitimate record"
  [ "$(cat "$rr/ok/WSS.ROADMAP.md")" = "# Roadmap" ] \
    && ok "WSS.record.roadmap is blanked" \
    || bad "wss-reset-records.sh left WSS.ROADMAP.md carrying content"
  [ "$(cat "$rr/ok/WSS.RELEASES.md")" = "# Release list" ] \
    && ok "WSS.record.releases is blanked — it is in the enumerated list" \
    || bad "wss-reset-records.sh left WSS.RELEASES.md carrying content: a new record missing from RECORDS"

  # An UNWRITABLE record used to kill the run at the `>` redirect under
  # `set -euo pipefail` — mid-loop, records already blanked, no refusal
  # reported (audit pass 6, M3). It must be an ordinary refusal instead:
  # skipped, loud, fatal at the end, with the other records still blanked.
  ro=$(mktemp -d); mkdir -p "$ro/proj/.claude"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md","roadmap":"WSS.ROADMAP.md"}}}\n' \
    > "$ro/proj/.claude/WSS.WORKFLOW.json"
  printf '# Backlog\n\nlocked content\n' > "$ro/proj/WSS.TODO.md"
  printf '# Roadmap\n\nblankable content\n' > "$ro/proj/WSS.ROADMAP.md"
  chmod a-w "$ro/proj/WSS.TODO.md"
  bash "$RR" --write --dir "$ro/proj" >/dev/null 2>&1; rc=$?
  chmod u+w "$ro/proj/WSS.TODO.md"
  [ "$rc" -ne 0 ] \
    && ok "an unwritable record is refused, not a mid-run crash" \
    || bad "wss-reset-records.sh exited 0 with an unwritable record in the set"
  [ "$(cat "$ro/proj/WSS.ROADMAP.md")" = "# Roadmap" ] \
    && ok "and the records after it are still blanked" \
    || bad "an unwritable record aborted the run before later records were blanked"
  rm -rf "$ro"

  # Dry run is the default, and a default that writes is a footgun.
  printf '# Backlog\n\nstill here\n' > "$rr/ok/WSS.TODO.md"
  bash "$RR" --dir "$rr/ok" >/dev/null 2>&1
  grep -q 'still here' "$rr/ok/WSS.TODO.md" \
    && ok "without --write it changes nothing" \
    || bad "wss-reset-records.sh wrote without --write"

  # A WSS.hazards.* pointer anchored into a file this script blanks must be
  # trimmed with the content — the anchor is gone, and a dangling pointer is a
  # doctor FAILURE in the very tree the script exists to make healthy. Found
  # by wss-publish.sh's Gate 3 the day WSS.hazards.* was first declared. A pointer
  # into a file the run did not touch is the project's own and must survive.
  hzm=$(mktemp -d); mkdir -p "$hzm/proj/.claude" "$hzm/proj/docs"
  printf '{"WSS":{"record":{"handoff":".claude/WSS.HANDOFF.md"},
           "hazards":{"doomed":".claude/WSS.HANDOFF.md#some-section",
                      "kept":"docs/traps.md#live-section"}}}\n' \
    > "$hzm/proj/.claude/WSS.WORKFLOW.json"
  printf '# Handoff\n\n## Some section\n' > "$hzm/proj/.claude/WSS.HANDOFF.md"
  printf '# Traps\n\n## Live section\n' > "$hzm/proj/docs/traps.md"
  bash "$RR" --write --dir "$hzm/proj" >/dev/null 2>&1
  jq -e '.WSS.hazards.doomed' "$hzm/proj/.claude/WSS.WORKFLOW.json" >/dev/null 2>&1 \
    && bad "a hazards pointer into a blanked file was left dangling" \
    || ok "a hazards pointer into a blanked file is trimmed"
  jq -e '.WSS.hazards.kept == "docs/traps.md#live-section"' \
      "$hzm/proj/.claude/WSS.WORKFLOW.json" >/dev/null 2>&1 \
    && ok "a hazards pointer into an untouched file survives" \
    || bad "wss-reset-records.sh trimmed a hazards pointer it had no reason to"

  # The hazards sibling is resolved from WSS.record.handoff's own directory, not
  # from a hardcoded .claude/WSS.HAZARDS.md — the hardcoded path shipped a
  # relocated fork's standing warnings un-blanked (audit pass 9, F7).
  rh=$(mktemp -d); mkdir -p "$rh/proj/docs" "$rh/proj/.claude"
  printf '{"WSS":{"record":{"handoff":"docs/WSS.HANDOFF.md"}}}\n' > "$rh/proj/.claude/WSS.WORKFLOW.json"
  printf '# Handoff\n\ncontent\n' > "$rh/proj/docs/WSS.HANDOFF.md"
  printf '# Standing hazards\n\nthis forks warnings\n' > "$rh/proj/docs/WSS.HAZARDS.md"
  bash "$RR" --write --dir "$rh/proj" >/dev/null 2>&1
  [ "$(cat "$rh/proj/docs/WSS.HAZARDS.md")" = "# Standing hazards" ] \
    && ok "a hazards file beside a relocated handoff is blanked" \
    || bad "wss-reset-records.sh left a relocated fork's hazards un-blanked"
  [ ! -f "$rh/proj/.claude/WSS.HAZARDS.md" ] \
    && ok "and nothing is invented at the old hardcoded path" \
    || bad "wss-reset-records.sh created .claude/WSS.HAZARDS.md out of nothing"

  # Lane records are the same records under other names, and the enumeration
  # missed the whole class — a forked lane-split project shipped every lane's
  # backlog, open decisions and handoff un-blanked while export and retire
  # both handled them (audit pass 10, F1). And a handoff at CLAUDE.md is KEPT:
  # that file also holds the project's standing instructions, which is why
  # wss-retire-workflow.sh kept it while this script blanked it (F5).
  lp=$(mktemp -d); mkdir -p "$lp/proj/.claude" "$lp/proj/docs"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md","handoff":"CLAUDE.md"},
           "lanes":{"named":{"backend":{"records":{
             "todo":"TODO.backend.md","handoff":"docs/handoff.backend.md"},
             "transfer":"docs/transfer.backend.md"}}}}}\n' \
    > "$lp/proj/.claude/WSS.WORKFLOW.json"
  for f in WSS.TODO.md CLAUDE.md TODO.backend.md docs/handoff.backend.md docs/WSS.HAZARDS.md \
           docs/transfer.backend.md; do
    printf 'PRIVATE\n' > "$lp/proj/$f"
  done
  bash "$RR" --write --dir "$lp/proj" >/dev/null 2>&1
  [ "$(cat "$lp/proj/TODO.backend.md")" = "# Backlog" ] \
    && [ "$(cat "$lp/proj/docs/handoff.backend.md")" = "# Handoff" ] \
    && ok "lane records are blanked like the records they are" \
    || bad "a lane record survived --write with its content (pass 10 F1)"
  [ "$(cat "$lp/proj/docs/WSS.HAZARDS.md")" = "# Standing hazards" ] \
    && ok "a lane handoff's hazards sibling is blanked with it" \
    || bad "a lane handoff's WSS.HAZARDS.md sibling kept its content"
  grep -q 'PRIVATE' "$lp/proj/CLAUDE.md" \
    && ok "a CLAUDE.md handoff is kept — it also holds standing instructions" \
    || bad "wss-reset-records.sh blanked a CLAUDE.md handoff (pass 10 F5)"
  # A transfer queue is declared BESIDE records rather than inside them, so it
  # is reached by its own arm of the lane walk and would be missed by a reader
  # that only descends into `.records`. An inherited queue is worse than an
  # inherited record: the adopter's first --wss-start drains it silently into
  # their own backlog.
  [ "$(cat "$lp/proj/docs/transfer.backend.md")" = "# Transfer queue" ] \
    && ok "a lane transfer queue is blanked too" \
    || bad "wss-reset-records.sh shipped a lane's transfer queue with its content"
fi

head_ "wss-export-records.sh moves only what a clone would not bring"

# It exists for the machine change: untracked records travel in an archive,
# tracked ones travel with the repository. The failure modes worth pinning are
# the same class as wss-reset-records.sh's — it reads paths from a manifest, which
# is data, and an import writes files from an archive, which is also data.
ER="$_root/wss-export-records.sh"
if [ ! -x "$ER" ]; then
  bad "wss-export-records.sh missing or not executable at $ER"
else
  ex=$(mktemp -d); mkdir -p "$ex/proj/.claude" "$ex/proj/docs"
  git init -q "$ex/proj"
  git -C "$ex/proj" config user.email t@t; git -C "$ex/proj" config user.name t
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md","openDecisions":"docs/od.md"}}}\n' \
    > "$ex/proj/.claude/WSS.WORKFLOW.json"
  printf 'TRACKED\n' > "$ex/proj/WSS.TODO.md"
  printf 'UNTRACKED-RECORD\n' > "$ex/proj/docs/od.md"
  printf 'docs/\n' > "$ex/proj/.gitignore"
  git -C "$ex/proj" add .gitignore WSS.TODO.md .claude/WSS.WORKFLOW.json
  git -C "$ex/proj" commit -qm x
  (cd "$ex/proj" && bash "$ER" -o out.tar.gz >/dev/null 2>&1)
  if [ -f "$ex/proj/out.tar.gz" ]; then
    tar tzf "$ex/proj/out.tar.gz" | grep -qx 'docs/od.md' \
      && ok "an untracked record is exported" \
      || bad "the untracked record did not make the archive"
    tar tzf "$ex/proj/out.tar.gz" | grep -qx 'WSS.TODO.md' \
      && bad "a TRACKED record was exported — the clone already brings it" \
      || ok "a tracked record stays out of the archive"
  else
    bad "export produced no archive at all"
  fi

  # Round trip into a bare destination.
  mkdir -p "$ex/dest/docs"
  (cd "$ex/dest" && bash "$ER" --import "$ex/proj/out.tar.gz" >/dev/null 2>&1)
  [ "$(cat "$ex/dest/docs/od.md" 2>/dev/null)" = "UNTRACKED-RECORD" ] \
    && ok "import restores the record byte-for-byte" \
    || bad "the round trip lost the record"

  # All-or-nothing: a non-empty collision refuses the WHOLE import.
  printf 'DO NOT CLOBBER\n' > "$ex/dest/docs/od.md"
  (cd "$ex/dest" && bash "$ER" --import "$ex/proj/out.tar.gz" >/dev/null 2>&1); rc=$?
  [ "$rc" -ne 0 ] && [ "$(cat "$ex/dest/docs/od.md")" = "DO NOT CLOBBER" ] \
    && ok "a non-empty collision refuses the import without --force" \
    || bad "import overwrote an existing file, or refused and exited 0"
  (cd "$ex/dest" && bash "$ER" --import "$ex/proj/out.tar.gz" --force >/dev/null 2>&1)
  [ "$(cat "$ex/dest/docs/od.md")" = "UNTRACKED-RECORD" ] \
    && ok "--force overwrites, so the refusal is a guard and not a wall" \
    || bad "--force did not restore the record"

  # A hostile archive must be refused before anything is written. GNU tar
  # strips a leading ../ itself, but the refusal is the contract — a tar that
  # extracts differently is not a reason this script writes outside a project.
  mkdir -p "$ex/evil"; printf 'x\n' > "$ex/evil/p"
  tar czf "$ex/hostile.tar.gz" --transform 's|^|../|' -C "$ex/evil" p 2>/dev/null
  (cd "$ex/dest" && bash "$ER" --import "$ex/hostile.tar.gz" >/dev/null 2>&1); rc=$?
  [ "$rc" -ne 0 ] \
    && ok "an entry escaping the project refuses the import" \
    || bad "a ../ archive entry was accepted"

  # --all is the retirement snapshot: not "what would a clone lose" but "what
  # would a deletion lose". Tracked records stay IN, and the docs tree — which
  # no manifest key names — travels by the same docs/ convention wss-docs uses.
  printf 'SITE\n' > "$ex/proj/docs/index.html"
  (cd "$ex/proj" && bash "$ER" --all -o all.tar.gz >/dev/null 2>&1)
  if [ -f "$ex/proj/all.tar.gz" ]; then
    tar tzf "$ex/proj/all.tar.gz" | grep -qx 'WSS.TODO.md' \
      && ok "--all keeps a tracked record in the archive" \
      || bad "--all filtered out a tracked record — the snapshot loses it on deletion"
    tar tzf "$ex/proj/all.tar.gz" | grep -qx 'docs/index.html' \
      && ok "--all sweeps the docs tree" \
      || bad "--all missed the docs site"
    tar tzf "$ex/proj/all.tar.gz" | grep -qx 'docs/od.md' \
      && ok "--all still carries the untracked records" \
      || bad "--all dropped an untracked record the plain export carries"
  else
    bad "--all produced no archive"
  fi

  # The handoff's overflow sibling is part of the handoff record — retire
  # deletes it and reset blanks it, so the snapshot must carry it too.
  mkdir -p "$ex/proj/.claude2"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md","handoff":"docs/WSS.HANDOFF.md"}}}\n' \
    > "$ex/proj/.claude/WSS.WORKFLOW.json"
  printf 'HANDOFF\n' > "$ex/proj/docs/WSS.HANDOFF.md"
  printf 'HAZARDS\n' > "$ex/proj/docs/WSS.HAZARDS.md"
  (cd "$ex/proj" && bash "$ER" --all -o hz.tar.gz >/dev/null 2>&1)
  tar tzf "$ex/proj/hz.tar.gz" 2>/dev/null | grep -qx 'docs/WSS.HAZARDS.md' \
    && ok "--all carries a relocated handoff's hazards sibling" \
    || bad "--all missed the hazards sibling the deletion takes"
fi

head_ "wss-retire-workflow.sh removes tiers, not everything"

# The tidy exit. Same threat model as wss-reset-records.sh — it reads paths from a
# manifest, which is data, and it deletes — plus one of its own: the records
# tier holds the project's knowledge and must survive the default.
RW="$_root/wss-retire-workflow.sh"
if [ ! -x "$RW" ]; then
  bad "wss-retire-workflow.sh missing or not executable at $RW"
else
  rw=$(mktemp -d); mkdir -p "$rw/proj/.claude" "$rw/proj/docs" "$rw/outside"
  mkfix() {
    printf '{"WSS":{"record":{"todo":"WSS.TODO.md","changelog":"CHANGELOG.md","reference":["README.md"],
             "decisions":"docs/WSS.DECISIONS.md","handoff":"CLAUDE.md"},
             "sweeps":".claude/WSS.SWEEPS.json"}}\n' > "$rw/proj/.claude/WSS.WORKFLOW.json"
    for f in WSS.TODO.md CHANGELOG.md README.md CLAUDE.md docs/WSS.DECISIONS.md .claude/WSS.SWEEPS.json .claude/WSS.LANE; do
      printf 'x\n' > "$rw/proj/$f"
    done
  }
  mkfix
  bash "$RW" --dir "$rw/proj" >/dev/null 2>&1
  [ -f "$rw/proj/.claude/WSS.WORKFLOW.json" ] && [ -f "$rw/proj/.claude/WSS.SWEEPS.json" ] \
    && ok "dry run removes nothing" \
    || bad "wss-retire-workflow.sh deleted without --write"

  bash "$RW" --write --dir "$rw/proj" >/dev/null 2>&1
  [ ! -f "$rw/proj/.claude/WSS.WORKFLOW.json" ] && [ ! -f "$rw/proj/.claude/WSS.SWEEPS.json" ] \
    && [ ! -f "$rw/proj/.claude/WSS.LANE" ] \
    && ok "--write removes the machinery tier" \
    || bad "machinery survived --write"
  [ -f "$rw/proj/WSS.TODO.md" ] && [ -f "$rw/proj/docs/WSS.DECISIONS.md" ] \
    && ok "records survive a machinery-only retire" \
    || bad "--write without --records deleted a record"

  mkfix
  bash "$RW" --write --records --dir "$rw/proj" >/dev/null 2>&1
  [ ! -f "$rw/proj/WSS.TODO.md" ] && [ ! -f "$rw/proj/docs/WSS.DECISIONS.md" ] \
    && ok "--records removes the workflow-shaped records" \
    || bad "--records left a workflow-shaped record behind"
  [ -f "$rw/proj/CHANGELOG.md" ] && [ -f "$rw/proj/README.md" ] && [ -f "$rw/proj/CLAUDE.md" ] \
    && ok "changelog, reference and a CLAUDE.md handoff always survive" \
    || bad "a file that exists beyond the workflow was deleted"

  # Containment: a record symlinked out of the project is refused, not deleted
  # through, and refusing is fatal.
  mkfix
  printf 'PRECIOUS\n' > "$rw/outside/notes.md"
  rm -f "$rw/proj/WSS.TODO.md"; ln -s "$rw/outside/notes.md" "$rw/proj/WSS.TODO.md"
  bash "$RW" --write --records --dir "$rw/proj" >/dev/null 2>&1; rc=$?
  [ -f "$rw/outside/notes.md" ] \
    && ok "a symlinked record is refused rather than followed" \
    || bad "wss-retire-workflow.sh followed a symlink out of the project"
  [ "$rc" -ne 0 ] && ok "and refusing is fatal" \
                  || bad "refused a path and still exited 0"

  # An absolute manifest path used to be silently KEPT: the existence probe
  # prepended $DIR unconditionally, so contained()'s absolute arm — and the
  # loud refusal behind it — was unreachable. Outside must refuse, fatally.
  mkfix
  printf 'PRECIOUS SWEEPS\n' > "$rw/outside/WSS.SWEEPS.json"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md"},"sweeps":"%s"}}\n' "$rw/outside/WSS.SWEEPS.json" \
    > "$rw/proj/.claude/WSS.WORKFLOW.json"
  bash "$RW" --write --dir "$rw/proj" >/dev/null 2>&1; rc=$?
  grep -q 'PRECIOUS' "$rw/outside/WSS.SWEEPS.json" 2>/dev/null \
    && ok "an absolute manifest path outside the project is refused, not silently kept" \
    || bad "wss-retire-workflow.sh deleted through an absolute manifest path"
  [ "$rc" -ne 0 ] && ok "and the absolute refusal is fatal" \
                  || bad "an absolute path outside the project passed with exit 0"

  # The suite's own tree is never a valid target.
  suite=$(mktemp -d); mkdir -p "$suite/.claude-plugin" "$suite/.claude"
  printf '{"name": "workflow-secretary-suite"}\n' > "$suite/.claude-plugin/plugin.json"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md"}}}\n' > "$suite/.claude/WSS.WORKFLOW.json"
  printf 'x\n' > "$suite/WSS.TODO.md"
  bash "$RW" --write --records --dir "$suite" >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] && [ -f "$suite/WSS.TODO.md" ] \
    && ok "the suite's own tree is refused outright" \
    || bad "wss-retire-workflow.sh ran against the suite itself"
fi

# ------------------------------------------------------- the pre-rename tree

head_ "A pre-rename tree is detected, never read as cleanly absent"

# Issue #16's first two bites, measured on a real workflow/v1→v2 migration: the
# legacy FILENAME (.claude/workflow.json) was simply never looked for — the
# doctor called a five-lane pre-rename project "unsplit" and green — and the
# exit path (retire, export) refused exactly the trees that need migrating.
# Every assertion here defends the loud path: legacy is a state with a name and
# a route (--wss-update), not an absence.
pre="$TMP/pre-rename"
drun_pre() { (cd "$pre" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
                bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); }
rm -rf "$pre"; mkdir -p "$pre/.claude" "$pre/docs"
cat > "$pre/.claude/workflow.json" <<'JSON'
{ "manifest": "workflow/v1",
  "record": { "todo": "TODO.md", "audits": "docs/audits.md" },
  "lanes": { "named": { "design": { "scope": ["d/**"],
                                    "records": { "todo": "TODO.design.md" } } } } }
JSON
printf 'x\n' > "$pre/TODO.md"; printf 'x\n' > "$pre/docs/audits.md"
printf 'x\n' > "$pre/TODO.design.md"; printf 'design\n' > "$pre/.claude/lane"

out=$(drun_pre)
case $out in
  *"pre-rename manifest found"*)
    ok "the legacy filename alone is a FAILURE, not a fallback pass" ;;
  *) bad "a .claude/workflow.json tree read as cleanly absent — the silent case issue #16 measured" ;;
esac
printf '%s' "$out" | grep -q 'fall back to conventional filenames' \
  && bad "the legacy tree ALSO printed the no-manifest pass line — two verdicts on one fact" \
  || ok "the no-manifest pass line stays silent when the legacy file exists"

# Both files at once: a migration that never finished, not a healthy v2 tree.
printf '{"WSS":{"manifest":"workflow/v2"}}\n' > "$pre/.claude/WSS.WORKFLOW.json"
out=$(drun_pre)
case $out in
  *"migration that never finished"*)
    ok "legacy beside current is a FAILURE naming the unfinished migration" ;;
  *) bad "a half-migrated tree (both manifests) passed" ;;
esac
rm -f "$pre/.claude/WSS.WORKFLOW.json"

# Retire refuses the legacy tree LOUDLY, naming the route — not "nothing to
# retire", which reads as an unadopted project.
if [ -x "$RW" ]; then
  err=$(bash "$RW" --dir "$pre" 2>&1); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$err" | grep -q 'PRE-RENAME' \
    && ok "retire refuses a legacy tree by name, with the migration route" \
    || bad "retire's refusal did not name the pre-rename manifest: $err"
fi

# Export READS the legacy manifest — the snapshot must be takeable BEFORE the
# migration that could lose it, which is the one moment that audience exists.
if [ -x "$ER" ]; then
  (cd "$pre" && bash "$ER" -o pre.tar.gz >/dev/null 2>&1)
  if [ -f "$pre/pre.tar.gz" ]; then
    miss=""
    for f in TODO.md docs/audits.md TODO.design.md .claude/lane; do
      tar tzf "$pre/pre.tar.gz" | grep -qx "$f" || miss="$miss $f"
    done
    [ -z "$miss" ] \
      && ok "export reads the legacy manifest: records, lane records and the old selector travel" \
      || bad "export missed from the legacy tree:$miss"
    (cd "$pre" && bash "$ER" -o note.tar.gz 2>&1 | grep -q 'PRE-RENAME') \
      && ok "and says which manifest it read, with the migration route" \
      || bad "a legacy export looks identical to a current one — nothing says migrate"
  else
    bad "export produced no archive from a legacy tree — the snapshot path is still closed"
  fi
fi

# The migration stamp: a well-formed WSS.suite is a documented key that passes;
# a malformed one warns rather than fails (detection overrides it anyway).
st="$TMP/stamp-proj"
rm -rf "$st"; mkdir -p "$st/.claude"
printf '{"WSS":{"manifest":"workflow/v2","suite":{"version":"0.9.0","commit":"abc1234"}}}\n' \
  > "$st/.claude/WSS.WORKFLOW.json"
out=$(cd "$st" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
        bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
printf '%s' "$out" | grep -q 'stamp carries a version and a commit' \
  && ok "a well-formed WSS.suite stamp passes" \
  || bad "a well-formed stamp did not get its pass line"
printf '%s' "$out" | grep -q "sets 'WSS.suite'" \
  && bad "WSS.suite warned as a key nothing reads — KNOWN_KEYS missed it" \
  || ok "WSS.suite is a documented key, not an unknown one"
printf '{"WSS":{"manifest":"workflow/v2","suite":{"version":"0.9.0"}}}\n' \
  > "$st/.claude/WSS.WORKFLOW.json"
out=$(cd "$st" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
        bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
printf '%s' "$out" | grep -q 'buys nothing' \
  && ok "a stamp missing its commit WARNS — it anchors nothing" \
  || bad "a malformed stamp passed silently"

head_ "The alert hook cues only when asked to"

ALERT="$(dirname "$HOOK")/wss-alert.sh"
if [ ! -f "$ALERT" ]; then
  bad "no alert hook beside $HOOK — the sound cue shipped without its script"
else
  acfg="$TMP/alerts-cfg"; atmp="$TMP/alerts-tmp"
  mkdir -p "$acfg" "$atmp"
  # The stamp lives in the config dir beside WSS.ALERTS-ON, not the shared temp
  # dir — a fixed /tmp name is another user's to own or pre-link.
  stamp="$acfg/.wss-alert.stamp"

  # The toggle, through the flag hook itself. CLAUDE_CONFIG_DIR scopes the
  # state file to this test, exactly as it scopes the doctor elsewhere.
  aflag() { # prompt
    printf '%s' "$(jq -nc --arg p "$1" '{prompt:$p}')" \
      | CLAUDE_CONFIG_DIR="$acfg" HOME="$TMP/home" bash "$HOOK" 2>/dev/null \
      | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
  }

  out=$(aflag "--wss-alerts on")
  [ -f "$acfg/WSS.ALERTS-ON" ] && printf '%s' "$out" | grep -q 'now ON' \
    && ok "--wss-alerts on writes the state file and says so" \
    || bad "--wss-alerts on did not create the state file or did not report ON"

  out=$(aflag "--wss-alerts")
  [ -f "$acfg/WSS.ALERTS-ON" ] && printf '%s' "$out" | grep -q 'currently ON' \
    && ok "bare --wss-alerts reports the state without toggling it" \
    || bad "bare --wss-alerts toggled or misreported the state"

  out=$(aflag "--wss-alerts off")
  [ ! -f "$acfg/WSS.ALERTS-ON" ] && printf '%s' "$out" | grep -q 'now OFF' \
    && ok "--wss-alerts off removes the state file and says so" \
    || bad "--wss-alerts off left the state file or did not report OFF"

  # The cue itself. WS_ALERTS_CMD=: keeps the suite from chiming at whoever
  # runs it; the stamp is the observable half of the cue path.
  arun() { CLAUDE_CONFIG_DIR="$acfg" WS_ALERTS_CMD=: \
             bash "$ALERT" </dev/null 2>/dev/null; }

  rm -f "$stamp"
  out=$(arun); rc=$?
  [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -f "$stamp" ] \
    && ok "with alerts off the hook exits 0, silent, and cues nothing" \
    || bad "alerts-off run cued anyway (rc=$rc, stamp=$([ -f "$stamp" ] && echo yes || echo no))"

  # Proven against a broken copy during development: strip the state-file
  # gate and the assertion above fails on the stamp it then writes.
  : > "$acfg/WSS.ALERTS-ON"
  out=$(arun); rc=$?
  [ "$rc" -eq 0 ] && [ -z "$out" ] && [ -f "$stamp" ] \
    && ok "with alerts on the hook cues once, still silent on stdout" \
    || bad "WSS.ALERTS-ON run did not cue or was not silent (rc=$rc)"

  s1=$(cat "$stamp" 2>/dev/null)
  arun >/dev/null
  s2=$(cat "$stamp" 2>/dev/null)
  [ "$s1" = "$s2" ] && ok "a burst of events cues once, not per event" \
                    || bad "the dedupe stamp moved on an immediate second event"

  # The override genuinely replaces the cue rather than being decoration.
  rm -f "$stamp" "$atmp/cue-ran"
  CLAUDE_CONFIG_DIR="$acfg" \
    WS_ALERTS_CMD="touch '$atmp/cue-ran'" bash "$ALERT" </dev/null 2>/dev/null
  cue=0
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [ -f "$atmp/cue-ran" ] && { cue=1; break; }
    sleep 0.05
  done
  [ "$cue" -eq 1 ] && ok "WS_ALERTS_CMD runs in place of the built-in chime" \
                   || bad "WS_ALERTS_CMD was set and never ran"
  rm -f "$acfg/WSS.ALERTS-ON"
fi

head_ "The decisions index is generated, checked, and refuses to guess"

# wss-index-decisions.sh resolves both paths from the manifest; decisionsIndex has
# deliberately no fallback, so undeclared must be an error, not a default name.
IDX="$_root/skills/wss-record/assets/wss-index-decisions.sh"
if [ ! -f "$IDX" ]; then
  bad "wss-index-decisions.sh missing at $IDX"
else
  itmp="$TMP/index-proj"; mkdir -p "$itmp/.claude" "$itmp/docs"
  printf '# Log\n\n## 2026-01-01 — first\n\nbody\n\n## 2026-01-02 — second\n\nbody\n' \
    > "$itmp/docs/WSS.DECISIONS.md"
  cat > "$itmp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "decisions": "docs/WSS.DECISIONS.md",
              "decisionsIndex": "docs/WSS.DECISIONS-INDEX.md" } }
}
JSON

  # Regen writes one row per `## ` entry, with its line number.
  (cd "$itmp" && bash "$IDX" >/dev/null 2>&1) \
    && grep -q '^- L3 — 2026-01-01 — first$' "$itmp/docs/WSS.DECISIONS-INDEX.md" \
    && grep -q '^- L7 — 2026-01-02 — second$' "$itmp/docs/WSS.DECISIONS-INDEX.md" \
    && ok "regen writes a row per entry with its line number" \
    || bad "regen did not produce the expected rows"

  # Check passes on a current index, fails on a stale one, and writes nothing.
  (cd "$itmp" && bash "$IDX" --check >/dev/null 2>&1) \
    && ok "check passes on a current index" \
    || bad "check failed on an index regen just wrote"
  printf '\n## 2026-01-03 — third\n\nbody\n' >> "$itmp/docs/WSS.DECISIONS.md"
  before=$(cat "$itmp/docs/WSS.DECISIONS-INDEX.md")
  if (cd "$itmp" && bash "$IDX" --check >/dev/null 2>&1); then
    bad "check passed against a log with an unindexed entry"
  else
    ok "check fails once the log has an unindexed entry"
  fi
  [ "$before" = "$(cat "$itmp/docs/WSS.DECISIONS-INDEX.md")" ] \
    && ok "check wrote nothing" \
    || bad "check modified the index"

  # Undeclared index: refuse rather than invent a filename.
  jq 'del(.WSS.record.decisionsIndex)' "$itmp/.claude/WSS.WORKFLOW.json" > "$itmp/.claude/wf2" \
    && mv "$itmp/.claude/wf2" "$itmp/.claude/WSS.WORKFLOW.json"
  if (cd "$itmp" && bash "$IDX" >/dev/null 2>&1); then
    bad "regen ran with WSS.record.decisionsIndex undeclared"
  else
    ok "regen refuses when WSS.record.decisionsIndex is undeclared"
  fi
fi

# ------------------------------------------------------------------ wss-publish.sh

head_ "wss-publish.sh refuses to run without an outdir"

# Its first act past the guards is `rm -rf $OUT`, so the argument check is the
# last thing between a bare invocation and a deletion. This half runs the REAL
# script: the guard fires before anything is touched. wss-publish.sh does not
# travel — the assembly removes it — so in a published tree this whole file's
# publish coverage skips rather than failing the assembly's own Gate 3.
PUB="$_root/wss-publish.sh"
if [ ! -f "$PUB" ]; then
  printf '  \033[33mskip\033[0m  no wss-publish.sh here — it does not ship; its gates are testable only in the source repo\n'
else
  uerr="$TMP/publish-usage-err"
  bash "$PUB" </dev/null >/dev/null 2>"$uerr"; urc=$?
  [ "$urc" -eq 2 ] && ok "no argument exits 2" \
                   || bad "no argument exited $urc, not 2 — one slip from an unguarded rm -rf"
  grep -q '^usage: wss-publish.sh <outdir>' "$uerr" \
    && ok "and prints a usage line on stderr" \
    || bad "no usage line on stderr: $(head -1 "$uerr" 2>/dev/null)"

  head_ "wss-publish.sh's gates, each proven against a fixture assembly"

  # The gates run on the ASSEMBLED tree, so they are tested on one: a minimal
  # repo shaped like what Gate 2 admits, a copy of wss-publish.sh dropped in (SRC
  # resolves from BASH_SOURCE), and an outdir beside it, never inside it. The
  # fixture's wss-doctor.sh and tests/wss-hook-contract.sh are STUBS on purpose —
  # Gate 3 runs the assembly's own doctor and suite, and a real copy here
  # would recurse into this file forever. The wss-publish.sh copy stays UNTRACKED
  # so its own needle list never reaches the archive. Note wss-publish.sh writes
  # its two gate logs to fixed /tmp paths; that is its behaviour, not this
  # suite's temp dir.
  #
  # Every needle is BUILT AT RUNTIME, never a literal: this file travels
  # (Gate 2 admits tests/) and Gate 1 scans tracked file content, so a fixture
  # literally naming the owner is the 2b695a5 regression — the gate failing on
  # its own test suite.
  OWNER=$(printf 'qu%s%s' pun to)
  PRIVREPO=$(printf 'claude%s' -config)

  pubfix() { # dir — the minimum that reaches Gate 3 green
    local d=$1
    rm -rf "$d"; mkdir -p "$d/tests" "$d/docs"
    printf '.credentials.json\n.env\nid_rsa\n*.pem\n*.key\n' > "$d/.gitignore"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/wss-reset-records.sh"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/wss-doctor.sh"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/tests/wss-hook-contract.sh"
    chmod +x "$d/wss-reset-records.sh" "$d/wss-doctor.sh" "$d/tests/wss-hook-contract.sh"
    git init -q "$d" 2>/dev/null
    git -C "$d" config user.email t@test; git -C "$d" config user.name t
    git -C "$d" config commit.gpgsign false
    git -C "$d" add -A >/dev/null 2>&1
    git -C "$d" commit -q -m shape >/dev/null 2>&1 \
      || bad "pubfix: the fixture commit failed in $d — every gate below tests nothing"
    cp "$PUB" "$d/wss-publish.sh"
  }
  pubrun() { # fixture-dir, outdir — combined output; exit status is publish's
    bash "$1/wss-publish.sh" "$2" </dev/null 2>&1
  }

  # Green first: gates that pass on a clean assembly are what make every
  # refusal below a refusal rather than a script that always fails.
  pg="$TMP/pub-green"; pubfix "$pg"
  out=$(pubrun "$pg" "$TMP/out-pub-green"); rc=$?
  [ "$rc" -eq 0 ] && ok "a clean fixture passes every gate with exit 0" \
    || bad "a clean fixture failed: $(printf '%s' "$out" | grep -a FAIL | head -2)"
  case $out in
    *"ALL GATES PASS"*) ok "and says so" ;;
    *) bad "exit 0 without the ALL GATES PASS line" ;;
  esac

  # Gate 1, fixed-needle half: the private repo's name, planted in a
  # whitelisted path so nothing but Gate 1 can be what refuses.
  p1="$TMP/pub-needle"; pubfix "$p1"
  printf 'imported from the %s repo\n' "$PRIVREPO" > "$p1/docs/history.md"
  git -C "$p1" add docs/history.md >/dev/null 2>&1
  git -C "$p1" commit -q -m docs >/dev/null 2>&1
  out=$(pubrun "$p1" "$TMP/out-pub-needle"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "in the working tree" \
    && ok "Gate 1 refuses a private identifier in the assembly" \
    || bad "a private identifier sailed through Gate 1 (rc=$rc)"

  # Gate 1, subtraction half: the owner handle in a form no sanctioning
  # covers. Subtracting sanctioned SUBSTRINGS rather than whole lines is the
  # demonstrated fix this pins.
  p2="$TMP/pub-handle"; pubfix "$p2"
  printf 'notes live at /home/%s/private\n' "$OWNER" > "$p2/docs/where.md"
  git -C "$p2" add docs/where.md >/dev/null 2>&1
  git -C "$p2" commit -q -m docs >/dev/null 2>&1
  out=$(pubrun "$p2" "$TMP/out-pub-handle"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "outside its sanctioned forms" \
    && ok "Gate 1 refuses the owner handle outside its sanctioned forms" \
    || bad "an unsanctioned handle passed Gate 1 (rc=$rc)"

  # Gate 2: a tracked path the whitelist does not admit. The premise of the
  # inverted .gitignore is that the dangerous set is open-ended, so admission
  # is explicit and everything else refuses.
  p3="$TMP/pub-stray"; pubfix "$p3"
  printf 'x\n' > "$p3/stray.txt"
  git -C "$p3" add stray.txt >/dev/null 2>&1
  git -C "$p3" commit -q -m stray >/dev/null 2>&1
  out=$(pubrun "$p3" "$TMP/out-pub-stray"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "not one this script admits" \
    && ok "Gate 2 refuses a tracked path outside the whitelist" \
    || bad "a non-whitelisted file passed Gate 2 (rc=$rc)"

  # Gate 3, both halves: a failing doctor and a failing test run in the
  # assembly must each surface as a non-zero publish — the gate people skip
  # must not be skippable by the script itself.
  p4="$TMP/pub-docfail"; pubfix "$p4"
  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$p4/wss-doctor.sh"
  git -C "$p4" add wss-doctor.sh >/dev/null 2>&1
  git -C "$p4" commit -q -m doc >/dev/null 2>&1
  out=$(pubrun "$p4" "$TMP/out-pub-docfail"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "wss-doctor.sh non-zero" \
    && ok "Gate 3 propagates the assembly's failing doctor" \
    || bad "the assembly's doctor failed and publish did not (rc=$rc)"

  p5="$TMP/pub-testfail"; pubfix "$p5"
  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$p5/tests/wss-hook-contract.sh"
  git -C "$p5" add tests/wss-hook-contract.sh >/dev/null 2>&1
  git -C "$p5" commit -q -m tests >/dev/null 2>&1
  out=$(pubrun "$p5" "$TMP/out-pub-testfail"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "wss-hook-contract.sh non-zero" \
    && ok "Gate 3 propagates the assembly's failing test suite" \
    || bad "the assembly's tests failed and publish did not (rc=$rc)"
fi

# ------------------------------------------------------- wss-overview wss-probe.sh

head_ "wss-probe.sh emits the overview's countable lines"

# The skill quotes this block rather than re-deriving the counts, so a line
# that drifts here misreports every --wss-overview at once. Asserted on the
# exact lines the report leans on. A bare config dir keeps the doctor line
# hermetic — its content is not asserted, only that probe survives it.
PROBE="$_root/skills/wss-overview/assets/wss-probe.sh"
if [ ! -f "$PROBE" ]; then
  bad "wss-probe.sh missing at $PROBE"
else
  prun() { # dir
    (cd "$1" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" bash "$PROBE" 2>/dev/null)
  }

  # No manifest: conventional names apply, and probe must say that is why.
  pnm="$TMP/probe-noman"
  rm -rf "$pnm"; mkdir -p "$pnm/docs"
  git init -q "$pnm" 2>/dev/null
  git -C "$pnm" config user.email t@test; git -C "$pnm" config user.name t
  git -C "$pnm" config commit.gpgsign false
  printf '# Backlog\n\n- [ ] **One.**\n- [ ] **Two.**\n' > "$pnm/WSS.TODO.md"
  printf '# Open decisions\n\n## Whether to X\n' > "$pnm/docs/WSS.OPEN-DECISIONS.md"
  git -C "$pnm" add -A >/dev/null 2>&1
  git -C "$pnm" commit -q -m records >/dev/null 2>&1
  out=$(prun "$pnm")
  case $out in
    *"note: no manifest — conventional fallback names in use"*)
      ok "no manifest is announced, not papered over" ;;
    *) bad "the no-manifest note is gone" ;;
  esac
  case $out in
    *"worktree: clean"*) ok "a committed tree reads clean" ;;
    *) bad "the worktree line is wrong or absent on a clean tree" ;;
  esac
  case $out in
    *"todo: WSS.TODO.md — 2 open"*) ok "the conventional backlog is counted" ;;
    *) bad "WSS.TODO.md's open count is wrong or absent" ;;
  esac
  case $out in
    *"no checkpoint file at .claude/WSS.SWEEPS.json"*)
      ok "no sweep ever run is said in words" ;;
    *) bad "the no-checkpoint message is gone — freshness reads as silence" ;;
  esac
  case $out in
    *"roadmap: WSS.ROADMAP.md — missing"*)
      ok "a missing conventional roadmap is named" ;;
    *) bad "the missing-roadmap line is gone" ;;
  esac

  printf 'x\n' > "$pnm/scratch.txt"
  out=$(prun "$pnm")
  case $out in
    *"worktree: dirty (1 paths)"*) ok "one untracked path reads dirty" ;;
    *) bad "a dirty tree did not read dirty" ;;
  esac

  # With a manifest: declared names only — an undeclared key must never fall
  # back — and the sweeps block reads each entry's baseline, stamp and
  # distance, which is the freshness half of the whole report.
  pman="$TMP/probe-man"
  rm -rf "$pman"; mkdir -p "$pman/.claude"
  git init -q "$pman" 2>/dev/null
  git -C "$pman" config user.email t@test; git -C "$pman" config user.name t
  git -C "$pman" config commit.gpgsign false
  printf '{"WSS":{"record":{"todo":"BACKLOG.md","roadmap":"PLAN.md","releases":"SHIP.md"},"sweeps":".claude/WSS.SWEEPS.json"}}\n' \
    > "$pman/.claude/WSS.WORKFLOW.json"
  printf '# Backlog\n\n- [ ] **One.**\n' > "$pman/BACKLOG.md"
  printf '# Roadmap\n\n## M1 — first\n\n- [ ] **Block A.**\n\n## M2 — second\n' > "$pman/PLAN.md"
  # The release list is a separate record and is never lane-resolved.
  printf '# Release list\n\n## `0.1.0` — shipped it — *completed*\n\n## `0.2.0` — next\n' \
    > "$pman/SHIP.md"
  git -C "$pman" add -A >/dev/null 2>&1
  git -C "$pman" commit -q -m records >/dev/null 2>&1
  base=$(git -C "$pman" rev-parse HEAD)
  jq -n --arg b "$base" \
    '{entries:{stocktake:{baseline:$b,at:"2026-01-05",method:"full",result:"clean"}}}' \
    > "$pman/.claude/WSS.SWEEPS.json"
  for _ in 1 2 3; do
    git -C "$pman" commit -q --allow-empty -m c >/dev/null 2>&1
  done
  out=$(prun "$pman")
  case $out in
    *"todo: BACKLOG.md — 1 open"*) ok "a declared backlog is counted where declared" ;;
    *) bad "WSS.record.todo's declared path was not counted" ;;
  esac
  case $out in
    *"open-decisions: undeclared"*)
      ok "an undeclared key reads undeclared, never a fallback" ;;
    *) bad "an undeclared key fell back despite the manifest" ;;
  esac
  case $out in
    *"stocktake: baseline $base (2026-01-05, full, result clean) — 3 commits behind HEAD"*)
      ok "a sweep entry reports baseline, stamp and distance" ;;
    *) bad "the sweeps block lost baseline/at/distance: $(printf '%s' "$out" | grep stocktake)" ;;
  esac
  # Goals and milestones are two records and two questions. The roadmap knows
  # nothing about completion marks — its position is the first goal that still
  # has open blocks — and the release list is where a mark is read from.
  case $out in
    *"current (first goal with open blocks): M1 — first"*)
      ok "the roadmap block names the current goal" ;;
    *) bad "the roadmap position line is gone" ;;
  esac
  case $out in
    *'current (first not marked completed): `0.2.0` — next'*)
      ok "the releases block names the current milestone" ;;
    *) bad "the release-list position line is gone: $(printf '%s' "$out" | grep -A4 '== releases ==')" ;;
  esac

  # A version or a completion mark in a ROADMAP heading is a release checkpoint
  # in the wrong file — under lanes, one worktree's. The probe warns; wss-doctor.sh
  # fails. Both matter: the probe is what a session sees without asking.
  printf '# Roadmap\n\n## M1 — first — *completed*\n\n- [ ] **Block A.**\n' > "$pman/PLAN.md"
  out=$(prun "$pman")
  case $out in
    *"a heading here carries a version or a completion mark"*)
      ok "a completion mark in a roadmap heading is warned about" ;;
    *) bad "a roadmap heading carrying a mark passed silently" ;;
  esac
  printf '# Roadmap\n\n## M1 — first\n\n- [ ] **Block A.**\n\n## M2 — second\n' > "$pman/PLAN.md"

  # A baseline git cannot resolve is a sweep owed in full, not a crash and not
  # a silent skip.
  jq -n '{entries:{stocktake:{baseline:"notacommit",at:"2026-01-05"}}}' \
    > "$pman/.claude/WSS.SWEEPS.json"
  out=$(prun "$pman")
  case $out in
    *"baseline notacommit is not a commit in this repository — sweep in full"*)
      ok "an unresolvable baseline says sweep-in-full" ;;
    *) bad "an unresolvable baseline was not reported" ;;
  esac
fi

# --------------------------------------------------------- wss-docs wss-scaffold.sh

head_ "wss-scaffold.sh builds the site shell once and refuses an existing one"

# The shell is three files; the refusal is the contract — an existing site is
# the authority on its own conventions and must never be overwritten.
SCAF="$_root/skills/wss-docs/assets/wss-scaffold.sh"
if [ ! -f "$SCAF" ]; then
  bad "wss-scaffold.sh missing at $SCAF"
else
  sc="$TMP/scaf"; rm -rf "$sc"; mkdir -p "$sc"
  (cd "$sc" && bash "$SCAF" docs "Demo Project" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sc/docs/index.html" ] && [ -f "$sc/docs/_sidebar.md" ] \
    && [ -f "$sc/docs/index.md" ] \
    && ok "an empty target gets the shell: index.html, _sidebar.md, index.md" \
    || bad "the monolingual shell did not scaffold (rc=$rc)"
  [ ! -f "$sc/docs/_navbar.md" ] \
    && ok "one language means no language switcher" \
    || bad "a monolingual site grew a _navbar.md"
  grep -q 'Demo Project' "$sc/docs/index.html" 2>/dev/null \
    && ok "the project name reaches the shell" \
    || bad "the project name never made it into index.html"

  printf 'HANDS OFF\n' > "$sc/docs/keep.md"
  out=$(cd "$sc" && bash "$SCAF" docs "Demo Project" 2>&1); rc=$?
  [ "$rc" -eq 1 ] && ok "an existing docs dir exits 1" \
                  || bad "an existing docs dir exited $rc, not 1"
  printf '%s' "$out" | grep -q 'refusing to scaffold' \
    && ok "and says it is refusing" \
    || bad "the refusal carried no message"
  [ "$(cat "$sc/docs/keep.md" 2>/dev/null)" = "HANDS OFF" ] \
    && ok "and touched nothing in the existing site" \
    || bad "the refused run still wrote into the existing dir"

  (cd "$sc" && bash "$SCAF" docs2 "Demo Project" en ca >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sc/docs2/ca/index.md" ] \
    && grep -q 'Català' "$sc/docs2/_navbar.md" 2>/dev/null \
    && ok "translations get their folder and an endonym-labelled navbar" \
    || bad "the multilingual shell lost a language folder or its navbar (rc=$rc)"
fi

head_ "Result"
if [ $fail -gt 0 ]; then
  printf '  \033[31m%d failed\033[0m, %d passed\n\n' "$fail" "$pass"; exit 1
fi
printf '  \033[32mall %d passed\033[0m\n\n' "$pass"
