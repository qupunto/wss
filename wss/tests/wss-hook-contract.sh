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
_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
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

# A PATH replicating every real executable EXCEPT the named one — proves a
# "tool not installed" branch for real rather than assuming it from a stub's
# exit code. The symlink farm is built once and each exclusion derived from it
# by bulk copy: the previous shape rebuilt it per test with a basename+ln fork
# per executable, and on WSL — where PATH carries the Windows mounts, so every
# stat crosses the 9p filesystem — each rebuild cost ~25s. /mnt/* dirs are
# skipped outright for the same reason: the scripts under test call POSIX
# tools, and a Windows .exe can never satisfy a `command -v` probe.
path_without() { # excluded-binary, stub-dir
  local base="$TMP/path-stubs-all"
  if [ ! -d "$base" ]; then
    mkdir -p "$base"
    ( IFS=':'; for d in $PATH; do
        case $d in /mnt/*) continue ;; esac
        [ -d "$d" ] || continue
        cp -sn "$d"/* "$base"/ 2>/dev/null
      done )
  fi
  rm -rf "$2"; mkdir -p "$2"
  cp -a "$base"/. "$2"/ && rm -f "$2/$1"
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

# The five retired flags (--wss-check, --wss-full-check, --wss-tidy,
# --wss-stocktake, --wss-full-stocktake) share one deliberate exception: their
# combined stub grants nothing at all — it redirects to `--wss-health-check`
# rather than authorizing anything itself — so it carries no Authorization
# line by design. Requiring one there would mean inventing a grant the stub
# never makes.
for f in $FLAGS; do
  out=$(run "$f")
  case $out in
    *"That flag is RETIRED"*) ok "$f is the retired stub — states no grant by design" ;;
    *"Authorization:"*) ok "$f states its grant" ;;
    "") bad "$f injected nothing even with its skill present" ;;
    *) bad "$f injects a block with no Authorization line" ;;
  esac
done

head_ "The filing template resolves end-to-end, not just in a static fence"

# bugtpl_() in the hook reads wss/workflow/WSS.OWNERSHIP.md's `## [open]` fence at
# RUNTIME, and only the one arm that calls it (--wss-catalog) ever emits it.
# --wss-tidy used to be a second caller, but it is one of the five retired
# flags now (2026-08-19, eighty-second decision): it serves the shared
# RETIRED stub and no longer touches bugtpl_() at all, so it dropped out of
# this loop — testing it here would only prove the stub, which the
# Authorization-line section above already covers. A static check that the
# fence merely EXISTS is a proxy: it proves awk would find something, not
# that the running hook actually emitted it — a SUITE_ROOT resolution failure
# (a moved suite root, a broken install layout) would pass a static fence
# check clean while every real invocation quietly fails closed to the
# fallback pointer instead. Only running the hook for real catches that
# class. The other failure class -- a THIRD block hardcoding the template
# instead of calling bugtpl_() -- is not this test's job: a hardcoded block
# still emits `## [open]` and passes this end-to-end grep clean.
# wss-doctor.sh's own static call-site check covers that one instead.
for tf in --wss-catalog; do
  out=$(run "$tf")
  case $out in
    *"## [open]"*)
      ok "$tf's live block resolves the filing template ('## [open]' fence present)" ;;
    *"entry format could not be read"*)
      bad "$tf fell back to the fail-closed pointer -- bugtpl_() could not read wss/workflow/WSS.OWNERSHIP.md's fence from the RUNNING hook, not a fixture" ;;
    *)
      bad "$tf's block contained neither the template nor the fail-closed pointer: $(printf '%s' "$out" | head -c 200)" ;;
  esac
done

# Negative control: force a COPY of the real hook's SUITE_ROOT to a temp tree
# whose wss/workflow/WSS.OWNERSHIP.md carries no `## [open]` fence, and confirm
# bugtpl_() falls back to the pointer there. Without this, the case statement
# above could pass by construction -- nothing has ever made it fail -- and
# nobody would know. Located by grepping the real hook's own SUITE_ROOT= line
# rather than hardcoding its right-hand side, so this control survives that
# line being reworded exactly as the rest of this file's spirit requires.
tplbroken_dir="$TMP/tplbroken"
rm -rf "$tplbroken_dir"
mkdir -p "$tplbroken_dir/wss/workflow"
printf '# ownership stub -- deliberately has no "## [open]" fence\n' > "$tplbroken_dir/wss/workflow/WSS.OWNERSHIP.md"

tplbroken_hook="$TMP/tplbroken-hook.sh"
tplbroken_line=$(grep -n '^SUITE_ROOT=' "$HOOK" | head -1 | cut -d: -f1)
if [ -z "$tplbroken_line" ]; then
  bad "could not locate the hook's SUITE_ROOT= assignment -- the negative control below cannot be built, so the end-to-end pass above is unproven"
else
  sed "${tplbroken_line}s#.*#SUITE_ROOT=\"$tplbroken_dir\"#" "$HOOK" > "$tplbroken_hook"
  chmod +x "$tplbroken_hook"
  oldhook="$HOOK"; HOOK="$tplbroken_hook"
  bout=$(run "--wss-catalog")
  HOOK="$oldhook"
  case $bout in
    *"entry format could not be read"*)
      ok "proven: a hook copy whose SUITE_ROOT points at a fenceless WSS.OWNERSHIP.md falls back to the pointer -- the end-to-end pass above is not vacuous" ;;
    *"## [open]"*)
      bad "the broken copy still emitted the template -- the SUITE_ROOT override did not take, so the end-to-end pass above proves nothing" ;;
    *)
      bad "the broken copy's fallback pointer is missing entirely: $(printf '%s' "$bout" | head -c 200)" ;;
  esac
fi

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
#
# --wss-stocktake, --wss-full-stocktake and --wss-check are all retired now
# and share one identical combined stub, which no longer says "included the
# `X` flag" per flag — that phrasing belonged to the individual skill blocks
# the retirement deleted. The absorption signal that survives is structural:
# with absorption working, only one of the two flags stays in `claimed`, so
# the stub is emitted exactly once and no multi-flag preamble appears; with
# absorption broken, both flags would survive into `claimed` and the
# identical stub would print twice back to back.
for wide in --wss-stocktake --wss-full-stocktake; do
  out=$(run "$wide --wss-check")
  n=$(printf '%s' "$out" | grep -c "That flag is RETIRED")
  if [ "$n" = 1 ] && ! printf '%s' "$out" | grep -q "included several flags"; then
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
# Same structural signal as the loop above — both flags are retired and share
# the one combined stub, so "included the `X` flag" no longer distinguishes
# them.
out=$(run "--wss-full-check --wss-check")
n=$(printf '%s' "$out" | grep -c "That flag is RETIRED")
if [ "$n" = 1 ] && ! printf '%s' "$out" | grep -q "included several flags"; then
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
    jq -nc --arg l "$2" '{skillOverrides:{"wrap":$l}}' > "$dir/settings.json"
  fi
}

for level in off user-invocable-only; do
  overrides user "$level"
  out=$(run "--wss-wrap")
  [ -z "$out" ] && ok "--wss-wrap inert while wrap is \"$level\"" \
                || bad "--wss-wrap fired for a skill the harness will refuse (\"$level\")"
done

for level in on name-only; do
  overrides user "$level"
  out=$(run "--wss-wrap")
  printf '%s' "$out" | grep -q -- 'included the `--wss-wrap` flag' \
    && ok "--wss-wrap still fires while wrap is \"$level\"" \
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

# ------------------------------------------------ absorption behind the gates

# "A gated-out absorber does not eat the flag it absorbs" (audit pass 14 F1)
# lived here: a settings-disabled `--wss-stocktake` used to swallow a live
# `--wss-check`, absorbing before the resolve/disabled gates ran. That whole
# scenario is now unreachable rather than merely untested, so the section is
# deleted rather than rewritten. flag_fires() is called from exactly three
# sites in the hook — the --wss-full-stocktake, --wss-full-check and
# --wss-stocktake absorption arms — and skill_for() maps all three of those
# flags to `-` since the eighty-second decision retired them. flag_fires()
# short-circuits `[ "$fs" = "-" ] && return 0` before it ever reaches the
# skill_exists/skill_disabled calls the old defect lived in, so a
# skillOverrides entry for "wss-stocktake" (or any absorber) can no longer
# gate these flags at all: there is no live call site left where the
# disabled-check branch of flag_fires() executes. Nothing succeeds this
# coverage because nothing can currently trigger the code path it guarded.
# The "enabled absorber still absorbs" half that followed it is not rewritten
# either — the rewritten absorption tests above (search "A record sweep does
# not run twice") already pin that same invariant, more robustly, with no
# overrides file involved.

# ---------------------------------------------------- task-notification guard

head_ "A task-notification is not the user"

# The harness routes a background task's completion notice back through
# UserPromptSubmit, with its `<task-notification>` banner at position 0 of
# `.prompt` and a subagent report — which legitimately quotes flag names as
# data — inside it. On 2026-08-10 one such payload decomposed and injected
# ~10.3 KB of unconditional instruction, --wss-start's commit grant included,
# with no user input (audit pass 13, F2). The hook refuses any prompt that
# BEGINS with the banner, and only that: the refusal must not cost a real
# prompt, which is the other direction asserted here.

notif=$'<task-notification>\n<task-id>t0test123</task-id>\n<tool-use-id>toolu_00TESTONLY</tool-use-id>\n<output-file>/tmp/none.output</output-file>\n<status>completed</status>\n<summary>Agent "reader" finished</summary>\n<result>Findings: the report quotes --wss-wrap and --wss-start and --wss-release as data.\n--wss-wrap\n</result>'
out=$(run "$notif")
if [ -z "$out" ]; then
  ok "notification-shaped payload quoting flags injects nothing"
else
  bad "a task-notification fired flags: injected $(printf '%s' "$out" | wc -c) bytes on text no user wrote"
fi

# The guard must not dull the hook: the same flags, typed by a user, still fire.
fires "--wss-wrap --wss-start" "--wss-wrap"

# And the refusal is anchored to the START of the prompt, not a substring scan:
# a user pasting a transcript that merely contains the banner mid-message is
# still a user asking for the flag they typed.
fires "here is the transcript: <task-notification> fired earlier --wss-wrap" "--wss-wrap"

# ------------------------------------------------ cross-session-message guard

head_ "A peer session is not the user"

# The second ingress into UserPromptSubmit: a peer session's message arrives as
# `.prompt`, prose banner at position 0 and `<cross-session-message ...>` on the
# line after it. On 2026-08-20 a peer's boundary report naming `--wss-tidy` in
# prose fired that flag's whole block, COMMIT authority included, with no user
# input. Same both-directions shape as the notification guard above.

peer=$'Another Claude session sent a message:\n<cross-session-message from="uds:/run/user/1000/cc-socks/0000.sock" from-name="claude-t0" from-mode="prompting">\nBoundary report: three live pointers route findings to --wss-tidy, a flag that is retiring, and --wss-start is the runner.\n</cross-session-message>\n\nThis came from another Claude session — not typed by your user.'
out=$(run "$peer")
if [ -z "$out" ]; then
  ok "peer-message payload quoting flags injects nothing"
else
  bad "a cross-session message fired flags: injected $(printf '%s' "$out" | wc -c) bytes on text no user wrote"
fi

# A harness that ever drops the prose line must not reopen the ingress.
out=$(run $'<cross-session-message from-name="claude-t0">\nroute findings to --wss-tidy\n</cross-session-message>')
if [ -z "$out" ]; then
  ok "bare open tag at position 0 injects nothing"
else
  bad "a bare <cross-session-message payload fired flags"
fi

# And the guard stays start-anchored: a user quoting a peer's message inside a
# prompt of their own is still a user asking for the flag they typed.
fires "the peer said <cross-session-message> route to --wss-tidy </cross-session-message> — do it: --wss-wrap" "--wss-wrap"

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
  mkdir -p "$hoproj/wss/records"
  printf 'SENTINEL-FALLBACK-HANDOFF\n' > "$hoproj/wss/records/WSS.HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-FALLBACK-HANDOFF*)
        ok "an undeclared handoff key falls back to wss/records/WSS.HANDOFF.md and injects it" ;;
                 *) bad "manifest without a handoff key left wss/records/WSS.HANDOFF.md unread" ;;
  esac

  rm -f "$hoproj/.claude/WSS.WORKFLOW.json"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in *SENTINEL-FALLBACK-HANDOFF*)
        ok "a project with no manifest still gets its wss/records/WSS.HANDOFF.md injected" ;;
                 *) bad "no manifest left WSS.HANDOFF.md unread — the fallback is dead" ;;
  esac

  rm -f "$hoproj/wss/records/WSS.HANDOFF.md"
  out=$(cd "$hoproj" && CLAUDE_CONFIG_DIR="$TMP/bare" bash "$CHECK" </dev/null 2>/dev/null)
  [ -z "$out" ] && ok "silent where no manifest and no WSS.HANDOFF.md exist" \
                || bad "spoke in a project with nothing to inject: $out"

  # The lane selector. A worktree of a lane-split project carries .claude/WSS.LANE,
  # and WSS.lanes.named.<lane>.records.handoff then overrides WSS.record.handoff —
  # WSS.LANE-CONTRACT.md's resolution rule. Both directions matter: the selected lane
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
  printf '%s' "$out" | grep -q -- '--wss-health-check' \
    && ok "the backlog nudge names --wss-health-check" \
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
  printf '{"name":"wss","version":"0.0.1","description":"d"}\n' \
    > "$upc/.claude-plugin/plugin.json"
  printf '#!/usr/bin/env bash\necho 3\n' > "$upc/stubs/gh"; chmod +x "$upc/stubs/gh"
  out=$(cd "$upc" && CLAUDE_CONFIG_DIR="$upc" PATH="$upc/stubs:$PATH" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"3 open issue(s) on qupunto/wss"*) ok "open upstream issues are counted in the nudge" ;;
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
    *"qupunto/wss"*) bad "zero upstream issues still produced a nudge: $out" ;;
    *) ok "zero upstream issues stay silent" ;;
  esac

  printf '#!/usr/bin/env bash\necho 3\n' > "$upc/stubs/gh"; chmod +x "$upc/stubs/gh"
  out=$(cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$upc" PATH="$upc/stubs:$PATH" bash "$CHECK" </dev/null 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$out" in
    *"qupunto/wss"*) bad "the upstream check fired outside the suite checkout" ;;
    *) ok "no upstream check outside the suite's own checkout" ;;
  esac
fi

# --------------------------------------------------- PostToolUse: tools-inventory

head_ "PostToolUse hook regenerates tools inventory on tooling edits"

# The tools-inventory-hook fires when tooling files are edited and regenerates
# .claude/WSS.TOOLS.json. The prefilter is deliberately over-broad: false
# positives cost one 4.2-second regeneration, false negatives cost nothing
# because wss-doctor.sh --check is the real guarantee. Test that it fires on
# tooling paths and is silent on non-tooling ones.

INVENTORY_HOOK="${INVENTORY_HOOK:-$_root/hooks/wss-tools-inventory-hook.sh}"
if [ ! -x "$INVENTORY_HOOK" ]; then
  bad "wss-tools-inventory-hook.sh is missing or not executable"
else
  ok "wss-tools-inventory-hook.sh is executable"
  bash -n "$INVENTORY_HOOK" 2>/dev/null && ok "wss-tools-inventory-hook.sh parses" \
    || bad "wss-tools-inventory-hook.sh has a syntax error"

  # Create a minimal test fixture with a dummy wss-tools-inventory.sh.
  # The real script is ~2200 lines; for testing, a marker file suffices.
  inv_test="$TMP/inv-test"
  rm -rf "$inv_test"
  mkdir -p "$inv_test/.claude/skills/test-skill" \
           "$inv_test/agents" \
           "$inv_test/wss/workflow" \
           "$inv_test/hooks" \
           "$inv_test/commands" \
           "$inv_test/wss/tests" \
           "$inv_test/wss/scripts"

  # Marker script that logs when it runs. A stand-in on purpose: this section
  # tests the hook's routing, not the inventory walk, which the chain-budget
  # fixtures below exercise against the real script.
  marker="$inv_test/wss/scripts/wss-tools-inventory.sh"
  printf '#!/usr/bin/env bash\necho "REGEN_FIRED" > "%s/.regen-mark"\n' "$inv_test" > "$marker"
  chmod +x "$marker"

  # Helper to run the inventory hook on a given file_path from the test fixture.
  # Returns the output and sets mark_exists to 0 or 1.
  run_inv() { # file_path
    rm -f "$inv_test/.regen-mark"
    local fp=$1
    (
      cd "$inv_test"
      export CLAUDE_PLUGIN_ROOT="$inv_test"
      printf '%s' "$(jq -nc --arg fp "$fp" '{tool_input:{file_path:$fp}}')" \
        | bash "$INVENTORY_HOOK" 2>/dev/null
    )
    # The hook's OWN exit code, captured before anything else runs — the
    # subshell above is the last command, so $? here is still its status.
    inv_rc=$?
    if [ -f "$inv_test/.regen-mark" ]; then
      mark_exists=1
    else
      mark_exists=0
    fi
  }

  # Test 1: non-tooling path should not fire the regeneration
  run_inv "some/random/file.txt"
  if [ $mark_exists -eq 0 ]; then
    ok "hook is silent on non-tooling path"
  else
    bad "hook fired on non-tooling path (should stay silent)"
  fi

  # Test 2: tooling path (skills/) should fire
  run_inv "$inv_test/skills/test-skill/SKILL.md"
  if [ $mark_exists -eq 1 ]; then
    ok "hook regenerates on skills/ path"
  else
    bad "hook did not fire on skills/ path"
  fi

  # Test 3: tooling path (agents/) should fire
  run_inv "$inv_test/agents/test-agent.md"
  if [ $mark_exists -eq 1 ]; then
    ok "hook regenerates on agents/ path"
  else
    bad "hook did not fire on agents/ path"
  fi

  # Test 4: tooling path (wss/workflow/) should fire
  run_inv "$inv_test/wss/workflow/test.md"
  if [ $mark_exists -eq 1 ]; then
    ok "hook regenerates on wss/workflow/ path"
  else
    bad "hook did not fire on wss/workflow/ path"
  fi

  # Test 5: root wss-*.sh should fire
  run_inv "$inv_test/wss-example.sh"
  if [ $mark_exists -eq 1 ]; then
    ok "hook regenerates on root wss-*.sh path"
  else
    bad "hook did not fire on root wss-*.sh path"
  fi

  # Test 6: hook always exits 0. Asserts on the hook's own status via
  # $inv_rc — a bare `$?` after run_inv reads the helper's trailing `if`,
  # which is 0 whatever the hook did, so the assertion would be vacuous.
  run_inv "nonexistent/path"
  if [ "$inv_rc" -eq 0 ]; then
    ok "hook exits 0 unconditionally"
  else
    bad "hook exited non-zero ($inv_rc)"
  fi

  # Test 7: a path OUTSIDE this installation must not fire, however it is
  # named. `wss/tests/` and `hooks/` occur in most projects, so an unanchored
  # prefilter would put a multi-second regeneration on unrelated work.
  run_inv "/somewhere/else/entirely/wss/tests/foo.test.js"
  if [ "$mark_exists" -eq 0 ]; then
    ok "hook is silent on a tooling-shaped path outside the installation"
  else
    bad "hook fired on a path outside the installation — prefilter is not anchored"
  fi
fi

# Verify hooks.json is still valid JSON and contains all expected registrations
if jq empty "$_root/hooks/hooks.json" 2>/dev/null; then
  ok "hooks.json is valid JSON"

  # Count hook registrations
  hook_count=$(jq '.hooks | keys | length' "$_root/hooks/hooks.json")
  if [ "$hook_count" -eq 6 ]; then
    ok "hooks.json registers 6 hook types (UserPromptSubmit, SessionStart, Notification, Stop, PreToolUse, PostToolUse)"
  else
    bad "hooks.json has $hook_count hook types, expected 6"
  fi

  # Verify PostToolUse exists and has the matcher
  post_tool=$(jq '.hooks.PostToolUse' "$_root/hooks/hooks.json")
  if [ "$post_tool" != "null" ] && echo "$post_tool" | jq -e '.[0].matcher' >/dev/null 2>&1; then
    matcher=$(jq -r '.hooks.PostToolUse[0].matcher' "$_root/hooks/hooks.json")
    if [ "$matcher" = "Write|Edit" ]; then
      ok "PostToolUse has correct matcher (Write|Edit)"
    else
      bad "PostToolUse matcher is '$matcher', expected 'Write|Edit'"
    fi
  else
    bad "PostToolUse hook not found in hooks.json"
  fi
else
  bad "hooks.json is not valid JSON"
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
# wss-doctor.sh moved to wss/tests/ in the reorg's tier 3; it is still run by
# hand as often as by the SessionStart hook.
DOCTOR="${DOCTOR:-$_root/wss/tests/wss-doctor.sh}"

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
    mkdir -p "$d/skills/alpha-skill" "$d/skills/beta-skill" "$d/wss/workflow"
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

SUITE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
grant_() {
  local own="${SUITE_ROOT:-}/wss/workflow/WSS.OWNERSHIP.md" cell=''
  [ -n "${SUITE_ROOT:-}" ] && [ -f "$own" ] && cell=$(awk -F'|' -v flag="$1" '
    /^\|/ && index($3, "`" flag "`") {
      a = $(NF - 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", a); print a; exit
    }' "$own" 2>/dev/null)
  case ${cell:-—} in
    —|-|'') printf '\nAuthorization: none — unreadable\n\n'; return 0 ;;
  esac
  printf '\nAuthorization: %s\n\n' "$cell"
}

block_for() {
  case $1 in
  --alpha)
    cat <<'EOF'
The user included the `--alpha` flag.
EOF
    grant_ --alpha
    cat <<'EOF'
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

    cat > "$d/wss/workflow/WSS.OWNERSHIP.md" <<'OWNFIX'
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
    printf '# Fixture\n\nSee [the matrix](wss/workflow/WSS.OWNERSHIP.md#the-matrix).\n' > "$d/README.md"

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
    # --notes because notice() is quiet by default now: several needles below
    # are note-class lines, and passing the flag only ADDS lines to the output,
    # so every fail/warn needle still matches exactly as it did.
    printf '%s' "$(doc "$1" --notes)" | grep -q -- "$2" \
      && ok "$3" || bad "$3 — the doctor said nothing about it"
  }

  clean="$TMP/doc-clean"
  docfix "$clean"
  out=$(doc "$clean" --notes); st=$?

  [ $st -eq 0 ] && ok "clean fixture: exit 0" \
    || bad "clean fixture reported a fault: $(printf '%s' "$out" | grep -aE 'FAIL|warn' | head -2)"
  printf '%s' "$out" | grep -q 'all checks passed' \
    && ok "clean fixture: all checks passed" \
    || bad "clean fixture never reached a clean result"

  # A vacuous-pass branch reads as green when its file simply MOVED. These four
  # assertions are the guard that closing those branches was itself missing:
  # (1) the notice fires when a file the clean fixture lacks is absent, (2) it
  # discriminates — a file the fixture DOES carry produces no absence notice,
  # (3) is already covered above (a notice does not gate), and (4) the one
  # conditional `fail` among the ten still fires when it should.
  says "$clean" "no wss-gen-lane-rulings.sh to run" \
    "a missing lane-rulings generator is announced, not passed over"

  says "$clean" "no wss-gen-cadence-flags.sh to run" \
    "a missing cadence generator is announced, not passed over"

  # Needle is the stem, not the whole sentence: this assertion proves a NEGATIVE,
  # so a needle carrying wording that later changes stops matching and the test
  # passes for the wrong reason. The positive assertion below is what keeps this
  # one honest — it pins the same stem against a tree that really lacks the file.
  printf '%s' "$out" | grep -q 'no ownership matrix' \
    && bad "the ownership absence report fired on a fixture that has the matrix" \
    || ok "a present matrix produces no absence report"

  # The matrix is mandatory, so its absence FAILS rather than being noted. Two
  # sites already disagreed about that before the ruling, which is why the
  # severity is asserted here and not just the wording.
  noown="$TMP/doc-no-ownership"; rm -rf "$noown"; cp -r "$clean" "$noown"
  rm -f "$noown/wss/workflow/WSS.OWNERSHIP.md"
  noown_out=$(doc "$noown"); noown_st=$?
  printf '%s' "$noown_out" | grep -q 'no ownership matrix' \
    && ok "a missing ownership matrix is reported" \
    || bad "a missing ownership matrix was passed over silently"
  printf '%s' "$noown_out" | grep -qE 'FAIL[^\n]*no ownership matrix' \
    && ok "and it fails rather than notices — the matrix is mandatory" \
    || bad "a missing ownership matrix did not FAIL: $(printf '%s' "$noown_out" | grep -a 'ownership' | head -2)"
  [ "$noown_st" -ne 0 ] && ok "the ownership fail exits non-zero" \
    || bad "the ownership fail did not change the exit code"

  aud="$TMP/doc-audit-orphan"; rm -rf "$aud"; cp -r "$clean" "$aud"
  mkdir -p "$aud/wss/logs/audits"
  printf '# x\n' > "$aud/wss/logs/audits/2026-01-01-x.md"
  aud_out=$(doc "$aud"); aud_st=$?
  printf '%s' "$aud_out" | grep -q -- 'but wss/logs/audits/ holds 1 report(s)' \
    && ok "an orphaned audit report with no index fails" \
    || bad "an orphaned audit report with no index did not fail: $aud_out"
  [ "$aud_st" -ne 0 ] && ok "the audit-index fail exits non-zero" \
    || bad "the audit-index fail did not change the exit code"

  # Each of these is a parser reporting that it matched. Without them a doctor
  # whose awk has gone blind passes this whole section: it says nothing about
  # every planted fault below, and saying nothing is what those tests read as
  # the fault being absent.
  printf '%s' "$out" | grep -q -- '`--alpha` -> alpha-skill' \
    && ok "the flag->skill parser resolved a mapping" \
    || bad "flag->skill parser matched nothing on a hook shaped like the real one"
  printf '%s' "$out" | grep -q "no flag is a prefix of another" \
    && ok "the prefix-clash check ran over a parsed FLAGS array" \
    || bad "prefix-clash check reached no verdict — the FLAGS array parsed as empty"
  # The count is the assertion, not the sentence. A check that read nothing
  # would print a confident pass line, so the numbers are what make it mean anything.
  printf '%s' "$out" | grep -q "every grant_ call in block_for() names its own arm's flag, and every granting row in WSS.OWNERSHIP.md's matrix has a call site (2 arms walked, 1 granting rows)" \
    && ok "the grants check reached a verdict on both arms and the one granting row" \
    || bad "grants check reached no verdict, or claimed one over the wrong counts"
  # THE COUNT, not the sentence — the doctor states this one the same way as the
  # grant and wrapper lines above, and for the same reason: this check only
  # warns, so a walk that has gone blind prints nothing and reads exactly like a
  # clean tree. A verdict over zero files is the failure the number catches.
  printf '%s' "$out" | grep -qE "no date-shaped prose in any rule file \([1-9][0-9]* walked\)" \
    && ok "the prose-date check reached a verdict over a non-empty rule-file walk" \
    || bad "prose-date check reached no verdict on a clean fixture, or walked 0 files"

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

  # The walk's REACH, one directory per assertion. rule_files_() copies
  # WSS.record.tooling.sources' glob list by hand, and it copied six of the eight
  # until 2026-08-11: agents/*.md and commands/*.md were unread while the check
  # claimed to cover every rule file. Nothing said so — a root that is never
  # walked is indistinguishable from a root with nothing wrong in it, which is
  # why each declared root needs a planted date rather than a count.
  reach="$TMP/doc-reach"
  docfix "$reach"
  mkdir -p "$reach/agents"
  printf '# an agent\n\nDoes the thing. Reworked on 2026-08-01 after an incident.\n' \
    > "$reach/agents/x.md"
  printf -- '---\ndescription: y wrapper\n---\n\nAdded 2026-08-01.\n--alpha $ARGUMENTS\n' \
    > "$reach/commands/y.md"
  docommit "$reach"
  says "$reach" "history in a rule file: agents/x.md" \
    "the rule-file walk reaches agents/, which WSS.record.tooling.sources declares"
  says "$reach" "history in a rule file: commands/y.md" \
    "the rule-file walk reaches commands/, which WSS.record.tooling.sources declares"

  # A walk that matches nothing must FAIL, not pass. Proven against a doctor
  # whose globs have been moved out from under it — a reorg's effect on a
  # hardcoded list — in a fixture that still holds the markdown those globs are
  # meant to find. Mutating the copy is the only way to reach this branch: the
  # real globs match, and a fixture with no rule files at all would be the
  # legitimately-empty tree the check deliberately does not fail.
  blind="$TMP/doc-blind.sh"
  sed "/^rule_files_() {/,/^}/{
         s|'skills/|'moved-skills/|g;    s|'agents/|'moved-agents/|g
         s|'wss/workflow/|'moved-wss/workflow/|g; s|'commands/|'moved-commands/|g
         s|/skills\"|/moved-skills\"|g;   s|/agents\"|/moved-agents\"|g
         s|/workflow\"|/moved-workflow\"|g; s|/commands\"|/moved-commands\"|g }" \
      "$DOCTOR" > "$blind"
  bout=$( (cd "$TMP/bare" && CLAUDE_CONFIG_DIR="$clean" CLAUDE_DIR="$clean" \
             bash "$blind" 2>&1) ); brc=$?
  [ "$brc" -ne 0 ] && printf '%s' "$bout" | grep -q "the rule-file walk matched nothing" \
    && ok "a rule-file walk that matches nothing is a FAILURE, not a clean tree" \
    || bad "a blind rule-file walk still reported a clean tree (rc=$brc)"

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
  # agreement between two. A fixture carrying adopt draws an unrelated
  # dispatch-only warn, so these assert on the needle rather than on exit 0.
  cadfix() { # dir, adopt-flags, readme-flags — canon card + derived README copy
    docfix "$1"
    mkdir -p "$1/skills/adopt" "$1/wss/scripts"
    cp "$_root/wss/scripts/wss-gen-cadence-flags.sh" "$1/wss/scripts/wss-gen-cadence-flags.sh"
    { printf '# adopt\n\nThe cadence card:\n\n| When | Flag |\n|---|---|\n'
      for f in $2; do printf '| Some moment | `%s` |\n' "$f"; done
    } > "$1/skills/adopt/SKILL.md"
    { printf '# Fixture\n\nSee [the matrix](wss/workflow/WSS.OWNERSHIP.md#the-matrix).\n'
      printf '\n### How often\n\nDerived copy of `skills/adopt/SKILL.md`. Regenerate with `bash wss-gen-cadence-flags.sh`.\n'
      printf '\n| When | Flag | Why then |\n|---|---|---|\n'
      for f in $3; do printf '| A different wording | `%s` | because |\n' "$f"; done
    } > "$1/README.md"
    docommit "$1"
  }
  cadok="$TMP/doc-cadence-agree"
  cadfix "$cadok" "--wss-track --wss-wrap" "--wss-track --wss-wrap"
  printf '%s' "$(doc "$cadok")" | grep -q "README.md's cadence flag column current, matches skills/adopt/SKILL.md" \
    && ok "the cadence comparison reached a verdict by delegating to wss-gen-cadence-flags.sh" \
    || bad "cadence comparison reached no verdict, or the delegated generator check failed"
  printf '%s' "$(doc "$cadok")" | grep -q "README.md carries a derived-copy marker naming the canon and generator" \
    && ok "the derived-copy marker is recognised" \
    || bad "a present derived-copy marker was not recognised"
  cadrift="$TMP/doc-cadence-drift"
  cadfix "$cadrift" "--wss-track --wss-wrap" "--wss-track --wss-wrap --wss-scout"
  says "$cadrift" "cadence flag column is stale" \
    "a flag in one cadence table and not the other is a FAILURE"
  printf '%s' "$(doc "$cadrift")" | grep -A1 -F "Flags in README but not in card:" | grep -q -- '--wss-scout' \
    && ok "the cadence failure names the flag that drifted, and which side has it" \
    || bad "cadence failure did not name --wss-scout as README-only"
  cadblind="$TMP/doc-cadence-unreadable"
  cadfix "$cadblind" "--wss-track" "--wss-track"
  edit_ "$cadblind/README.md" 's/^| When | Flag | Why then |$/| Moment | Shorthand | Why then |/'
  docommit "$cadblind"
  says "$cadblind" "cadence flag column is stale" \
    "a README table the generator cannot parse still fails as stale — there is no separate not-found branch for this pair any more"

  cadnomark="$TMP/doc-cadence-no-marker"
  cadfix "$cadnomark" "--wss-track" "--wss-track"
  sed -i '/Derived copy of/d; /Regenerate with/d' "$cadnomark/README.md"
  docommit "$cadnomark"
  says "$cadnomark" "How often' table has no derived-copy marker" \
    "a README missing the derived-copy marker is a FAILURE even when the flags agree"

  out_write=$(bash "$_root/wss/scripts/wss-gen-cadence-flags.sh" --write 2>&1); rc_write=$?
  [ "$rc_write" -eq 2 ] && printf '%s' "$out_write" | grep -q "README.md is a declared record" \
    && ok "wss-gen-cadence-flags.sh --write refuses at exit 2, naming the sole writer" \
    || bad "wss-gen-cadence-flags.sh --write did not refuse as documented (rc=$rc_write): $out_write"

  head_ "Citation proximity flags the bare restatement and not the cited one"

  # The doctor's "Citation proximity" section derives which rule names are
  # citable at all from the tree it is walking, rather than from a hand-kept
  # list, so a fixture has to ESTABLISH a name before it can test a
  # restatement of it. Line 3 states `sole-writer rule` with an anchor-shaped
  # link on the next line, which is what pass one records; line 10 repeats it
  # with nothing near it, far enough down to fall outside the two-line window
  # pass two allows. Both halves are asserted: a check that flagged
  # everything would satisfy the first assertion on its own.
  cprox="$TMP/doc-cprox"
  docfix "$cprox"
  printf '%s\n' \
    '# alpha-skill' '' \
    'Does the alpha thing. Mind the sole-writer rule' \
    '([the matrix](../../wss/workflow/WSS.OWNERSHIP.md#the-matrix)).' '' \
    'Filler one.' 'Filler two.' 'Filler three.' '' \
    'Elsewhere, the sole-writer rule applies again with nothing pointing at it.' \
    > "$cprox/skills/alpha-skill/SKILL.md"
  docommit "$cprox"
  says "$cprox" "restatement(s) of an already-cited rule name" \
    "a rule name established beside a citation and then repeated bare is flagged"
  printf '%s' "$(doc "$cprox" --notes)" | grep -q 'alpha-skill/SKILL.md:10' \
    && ok "the bare restatement is named at its own line" \
    || bad "the bare restatement was not named at line 10 — the window or the phrase scan is wrong"
  printf '%s' "$(doc "$cprox" --notes)" | grep -q 'alpha-skill/SKILL.md:3:' \
    && bad "the instance sitting beside its own citation was flagged too — the check is not reading the anchor" \
    || ok "the instance beside its citation stays clean"

  # The catalog's method table and wss/tests/WSS.CHECKS.md's are the same rows
  # written twice. Unlike the cadence pair EVERY column must agree — those two
  # address different readers, these two address the same one — so the fixture
  # drifts a description rather than a row. What stays free to differ is the
  # link target, the files sitting at different depths, so the two sides here
  # carry deliberately different hrefs: an agreeing verdict then proves the
  # normalisation rather than merely proving the fixture is a copy of itself.
  mtfix() { # dir, catalog-finds, readme-finds — one row differs, one always agrees
    docfix "$1"
    mkdir -p "$1/.claude" "$1/wss/tests"
    printf '# record-drift\n' > "$1/wss/tests/WSS.RECORD-DRIFT.md"
    printf '# docs-audit\n'   > "$1/wss/tests/WSS.DOCS-AUDIT.md"
    { printf '# Tooling\n\n## The shared check methods\n\n'
      printf '| Method | What it finds | Run by |\n|---|---|---|\n'
      printf '| [`WSS.RECORD-DRIFT.md`](../wss/tests/WSS.RECORD-DRIFT.md) | %s | `--alpha` |\n' "$2"
      printf '| [`WSS.DOCS-AUDIT.md`](../wss/tests/WSS.DOCS-AUDIT.md) | a docs site | `--beta` |\n'
    } > "$1/.claude/WSS.TOOLING.md"
    { printf '# The checks\n\n## Method and runner\n\n'
      printf '| Method | What it finds | Run by |\n|---|---|---|\n'
      printf '| [`WSS.RECORD-DRIFT.md`](WSS.RECORD-DRIFT.md) | %s | `--alpha` |\n' "$3"
      printf '| [`WSS.DOCS-AUDIT.md`](WSS.DOCS-AUDIT.md) | a docs site | `--beta` |\n'
    } > "$1/wss/tests/WSS.CHECKS.md"
    docommit "$1"
  }
  mtptrfix() { # dir — WSS.CHECKS.md is canon, WSS.TOOLING.md only points at it
    docfix "$1"
    mkdir -p "$1/.claude" "$1/wss/tests"
    printf '# record-drift\n' > "$1/wss/tests/WSS.RECORD-DRIFT.md"
    printf '# docs-audit\n'   > "$1/wss/tests/WSS.DOCS-AUDIT.md"
    { printf '# The checks\n\n## Method and runner\n\n'
      printf '| Method | What it finds | Run by |\n|---|---|---|\n'
      printf '| [`WSS.RECORD-DRIFT.md`](WSS.RECORD-DRIFT.md) | the classes of drift | `--alpha` |\n'
      printf '| [`WSS.DOCS-AUDIT.md`](WSS.DOCS-AUDIT.md) | a docs site | `--beta` |\n'
    } > "$1/wss/tests/WSS.CHECKS.md"
    { printf '# Tooling\n\n## The shared check methods\n\n'
      printf 'See [wss/tests/WSS.CHECKS.md](../wss/tests/WSS.CHECKS.md) for the method/runner table.\n'
    } > "$1/.claude/WSS.TOOLING.md"
    docommit "$1"
  }
  mtptr="$TMP/doc-methods-pointer"
  mtptrfix "$mtptr"
  printf '%s' "$(doc "$mtptr")" | grep -q "the catalog points at wss/tests/WSS.CHECKS.md instead of restating its check-method table (2 methods)" \
    && ok "a catalog that only points at WSS.CHECKS.md is clean" \
    || bad "the pointer-form catalog reached no verdict, or was misread as still restating"

  mtstill="$TMP/doc-methods-still-restated"
  mtptrfix "$mtstill"
  { printf '# Tooling\n\n## The shared check methods\n\n'
    printf '| Method | What it finds | Run by |\n|---|---|---|\n'
    printf '| [`WSS.RECORD-DRIFT.md`](../wss/tests/WSS.RECORD-DRIFT.md) | the classes of drift | `--alpha` |\n'
    printf '| [`WSS.DOCS-AUDIT.md`](../wss/tests/WSS.DOCS-AUDIT.md) | a docs site | `--beta` |\n'
  } > "$mtstill/.claude/WSS.TOOLING.md"
  docommit "$mtstill"
  says "$mtstill" ".claude/WSS.TOOLING.md still carries a Method/What it finds/Run by" \
    "a catalog that still restates the check-method table is a FAILURE now that it must point instead"

  mtnoptr="$TMP/doc-methods-no-pointer"
  mtptrfix "$mtnoptr"
  printf '# Tooling\n\n## The shared check methods\n\nSee the checks directory.\n' > "$mtnoptr/.claude/WSS.TOOLING.md"
  docommit "$mtnoptr"
  says "$mtnoptr" "longer points at wss/tests/WSS.CHECKS.md" \
    "a catalog with neither the table nor the pointer is a FAILURE"
  mtblind="$TMP/doc-methods-unreadable"
  mtfix "$mtblind" "the classes of drift" "the classes of drift"
  edit_ "$mtblind/wss/tests/WSS.CHECKS.md" 's/^| Method | What it finds | Run by |$/| Check | What it finds | Run by |/'
  docommit "$mtblind"
  says "$mtblind" "no check-method table found in wss/tests/WSS.CHECKS.md" \
    "a method table the parser cannot find is a FAILURE, not a silent agreement"

  # The comparison above is between the two tables, so it is blind in the one
  # direction that matters most: a method neither table lists makes them agree
  # perfectly. Both fixtures below leave the pair in agreement and change only
  # the directory, so an agreeing verdict cannot carry either assertion.
  mtorphan="$TMP/doc-methods-orphan"
  mtfix "$mtorphan" "the classes of drift" "the classes of drift"
  printf '# unlisted\n' > "$mtorphan/wss/tests/WSS.PROSE-PRUNE.md"
  docommit "$mtorphan"
  says "$mtorphan" "method file with no row in either check-method table: WSS.PROSE-PRUNE.md" \
    "a method file neither table lists is a FAILURE, though the two tables agree"
  mtghost="$TMP/doc-methods-ghost"
  mtfix "$mtghost" "the classes of drift" "the classes of drift"
  rm "$mtghost/wss/tests/WSS.DOCS-AUDIT.md"
  docommit "$mtghost"
  says "$mtghost" "check-method table names a file that is not in wss/tests/: WSS.DOCS-AUDIT.md" \
    "a row for a method file that is gone is a FAILURE, not a live method"

  # The same table a THIRD time, in the docs annex, on the condensation ruling:
  # cells free, labels not. The agreeing fixture below therefore differs from the
  # authority in EVERY cell it keeps — a shorter description, no href, a runner
  # named rather than linked — and drops a row as well, so an agreeing verdict
  # proves the licence rather than proving the annex is a copy.
  mtanx() { # dir, annex method name
    mtfix "$1" "the classes of drift" "the classes of drift"
    mkdir -p "$1/wss/docs/annex"
    { printf '# Claude tooling\n\n## The shared check methods\n\n'
      printf 'A condensed copy of the canon table in `wss/tests/WSS.CHECKS.md`, sanctioned under `wss/workflow/WSS.RECORD-CONTRACT.md'"'"'s exception 2: this table'"'"'s cells are free to shorten, but every row label must still be one the canon carries.\n\n'
      printf '| Method | What it finds | Run by |\n|---|---|---|\n'
      printf '| `%s` | drift | alpha |\n' "$2"
    } > "$1/wss/docs/annex/WSS.CLAUDE-TOOLING.md"
    docommit "$1"
  }
  mtanxok="$TMP/doc-methods-annex-ok"
  mtanx "$mtanxok" "WSS.RECORD-DRIFT.md"
  printf '%s' "$(doc "$mtanxok")" | grep -q "the annex's check-method rows all exist in wss/tests/WSS.CHECKS.md (1 checked)" \
    && ok "the annex may condense a method's cells and skip a row entirely" \
    || bad "the annex comparison reached no verdict, or it read condensation as drift"
  mtanxnonote="$TMP/doc-methods-annex-nonote"
  mtanx "$mtanxnonote" "WSS.RECORD-DRIFT.md"
  sed -i '/sanctioned under/d' "$mtanxnonote/wss/docs/annex/WSS.CLAUDE-TOOLING.md"
  docommit "$mtanxnonote"
  says "$mtanxnonote" "no exception-2 note naming it" \
    "wss/docs/annex/WSS.CLAUDE-TOOLING.md's check-method table condenses wss/tests/WSS.CHECKS.md with no exception-2 note naming it — exception 2 requires the note at the copy"
  mtanxdrift="$TMP/doc-methods-annex-drift"
  mtanx "$mtanxdrift" "WSS.PROSE-PRUNE.md"
  says "$mtanxdrift" "check-method table carries methods" \
    "a method only the annex names is a FAILURE — the authority renamed or dropped it"
  mtanxblind="$TMP/doc-methods-annex-blind"
  mtanx "$mtanxblind" "WSS.RECORD-DRIFT.md"
  edit_ "$mtanxblind/wss/docs/annex/WSS.CLAUDE-TOOLING.md" 's/^| Method | What it finds | Run by |$/| Check | What it finds | Run by |/'
  docommit "$mtanxblind"
  says "$mtanxblind" "no check-method table found in wss/docs/annex/WSS.CLAUDE-TOOLING.md" \
    "the licence covers the cells, not the header — an unreadable annex table is a FAILURE"

  # The caller->invokes table, which nothing read at all until this check. It
  # names five KINDS of referent and each resolves through its own rule, so each
  # gets its own deliberately-broken fixture below — a shared one would leave
  # four of the five rules asserted by nothing. The base fixture renames the
  # hook's flags into a namespace, because which `--` token is a flag and which
  # is a script's own argument is decided by the longest prefix the FLAGS array
  # shares, and `--alpha`/`--beta` share nothing to decide with.
  iwfix() { # dir, invokes-cell of the first row, second row's caller
    docfix "$1"
    mkdir -p "$1/.claude" "$1/wss/workflow/writers" "$1/wss/tests" "$1/skills/wss-gamma"
    edit_ "$1/wss-shorthand-flags.sh" 's/--alpha/--wss-alpha/g; s/--beta/--wss-beta/g'
    edit_ "$1/wss/workflow/WSS.OWNERSHIP.md" 's/--alpha/--wss-alpha/g; s/--beta/--wss-beta/g'
    edit_ "$1/commands/alpha.md" 's/--alpha/--wss-alpha/g'
    printf '# gamma\n'   > "$1/wss/workflow/writers/WSS.GAMMA-WRITER.md"
    printf '# delta\n'   > "$1/wss/workflow/writers/WSS.DELTA-TRACKER.md"
    printf '# index\n'   > "$1/wss/workflow/writers/WSS.WRITERS.md"
    printf '# thing\n'   > "$1/wss/tests/WSS.THING.md"
    printf '# manifest\n\nRoles: `audit`, `release`.\n' > "$1/wss/workflow/WSS.MANIFEST.md"
    printf '# wss-gamma\n\nDoes the gamma thing.\n' > "$1/skills/wss-gamma/SKILL.md"
    printf '#!/usr/bin/env bash\ntrue\n' > "$1/wss-thing.sh"
    { printf '# Tooling\n\n### Who invokes whom\n\n'
      printf '| Caller | Invokes | For |\n|---|---|---|\n'
      printf '| `--wss-alpha` | %s | reasons |\n' "$2"
      printf '| `%s` | `delta-tracker`, `WSS.agents.audit` | reasons |\n' "$3"
    } > "$1/.claude/WSS.TOOLING.md"
    docommit "$1"
  }
  iwrow='`gamma-writer`, `--wss-beta`, `wss-thing.sh --all` (`--dir`), `wss/tests/WSS.THING.md`'
  iwok="$TMP/doc-invokes-ok"
  iwfix "$iwok" "$iwrow" "wss-gamma"
  printf '%s' "$(doc "$iwok")" | grep -q "every referent in the caller->invokes table resolves (8 checked)" \
    && ok "the invokes table resolves a flag, a writer, a script, a method file and a skill" \
    || bad "the invokes resolver reached no verdict, or counted a kind it should have skipped"
  printf '%s' "$(doc "$iwok")" | grep -q "every writer procedure is named by a caller (2 procedures)" \
    && ok "the writers/ anchor counts the procedures and exempts the index" \
    || bad "the writers/ anchor reached no verdict, or counted WSS.WRITERS.md as a procedure"

  # `--all` in the script's own span must stay an argument. If the resolver ever
  # treats it as a flag this fixture fails, which is the only thing asserting
  # that arguments and flags are told apart at all.
  iwflag="$TMP/doc-invokes-flag"
  iwfix "$iwflag" '`gamma-writer`, `--wss-delta`, `wss-thing.sh --all` (`--dir`), `wss/tests/WSS.THING.md`' "wss-gamma"
  says "$iwflag" "--wss-delta(no such flag)" \
    "a row naming a flag the hook does not carry is a FAILURE"
  iwscript="$TMP/doc-invokes-script"
  iwfix "$iwscript" "$iwrow" "wss-gamma"
  rm "$iwscript/wss-thing.sh"; docommit "$iwscript"
  says "$iwscript" "wss-thing.sh(no such script)" \
    "a row naming a script that is gone is a FAILURE"
  iwwriter="$TMP/doc-invokes-writer"
  iwfix "$iwwriter" "$iwrow" "wss-gamma"
  rm "$iwwriter/wss/workflow/writers/WSS.GAMMA-WRITER.md"; docommit "$iwwriter"
  says "$iwwriter" "gamma-writer(no wss/workflow/writers/WSS.GAMMA-WRITER.md)" \
    "a row naming a writer procedure that is gone is a FAILURE"
  iwpath="$TMP/doc-invokes-path"
  iwfix "$iwpath" "$iwrow" "wss-gamma"
  rm "$iwpath/wss/tests/WSS.THING.md"; docommit "$iwpath"
  says "$iwpath" "wss/tests/WSS.THING.md(no such file)" \
    "a row naming a check method that is gone is a FAILURE"
  iwskill="$TMP/doc-invokes-skill"
  iwfix "$iwskill" "$iwrow" "wss-gamma"
  rm -r "$iwskill/skills/wss-gamma"; docommit "$iwskill"
  says "$iwskill" "wss-gamma(no such skill or agent)" \
    "a CALLER that resolves to neither skill nor agent is a FAILURE, not just a callee"
  # A bare wss- name resolves against skills/ OR agents/, since 2026-08-13.
  # This assertion read `(no such skill)` when written and that was correct
  # then: the resolver searched skills/ alone, so the table could not name an
  # agent at all — `--wss-stocktake` -> `wss-survey` was inexpressible and read
  # as an absence of delegation. The fixture above builds no agents/ directory,
  # so it still fails; only the message moved. The pair below is what stops the
  # widening from being a hole — the agent form must resolve, and a name that is
  # neither must still fail.
  iwagent="$TMP/doc-invokes-agent"
  iwfix "$iwagent" "$iwrow" "wss-gamma"
  rm -r "$iwagent/skills/wss-gamma"
  mkdir -p "$iwagent/agents"
  printf -- '---\nname: wss-gamma\ntools: Read\n---\n\n# gamma\n' > "$iwagent/agents/wss-gamma.md"
  docommit "$iwagent"
  printf '%s' "$(doc "$iwagent")" | grep -q -- 'wss-gamma(no such skill or agent)' \
    && bad "a CALLER naming an agent was rejected — the table cannot express an agent edge" \
    || ok "a CALLER that resolves to an agent rather than a skill is accepted"
  iwrole="$TMP/doc-invokes-role"
  iwfix "$iwrole" "$iwrow" "wss-gamma"
  edit_ "$iwrole/.claude/WSS.TOOLING.md" 's/WSS.agents.audit/WSS.agents.nosuch/'
  docommit "$iwrole"
  says "$iwrole" "WSS.agents.nosuch(no such role" \
    "a row naming a manifest role WSS.MANIFEST.md does not document is a FAILURE"

  # The direction the table cannot fail in on its own: this fixture leaves every
  # row resolving and adds only the file, so the verdict can come from nothing
  # but the writers/ anchor.
  iworphan="$TMP/doc-invokes-orphan"
  iwfix "$iworphan" "$iwrow" "wss-gamma"
  printf '# epsilon\n' > "$iworphan/wss/workflow/writers/WSS.EPSILON-WRITER.md"
  docommit "$iworphan"
  says "$iworphan" "writer procedure that no caller->invokes row names: WSS.EPSILON-WRITER.md" \
    "a writer procedure no row names is a FAILURE, though every row resolves"
  iwblind="$TMP/doc-invokes-blind"
  iwfix "$iwblind" "$iwrow" "wss-gamma"
  edit_ "$iwblind/.claude/WSS.TOOLING.md" 's/^| Caller | Invokes | For |$/| Caller | Calls | For |/'
  docommit "$iwblind"
  says "$iwblind" "no caller->invokes table found in .claude/WSS.TOOLING.md" \
    "a table the resolver cannot find is a FAILURE, not a table that resolves perfectly"

  # And the annex's copy of it, on the same condensation ruling as the methods:
  # a caller the annex skips is fine, one only the annex has is not.
  iwanx() { # dir, annex caller
    iwfix "$1" "$iwrow" "wss-gamma"
    mkdir -p "$1/wss/docs/annex"
    { printf '# Claude tooling\n\n## Who invokes whom\n\n'
      printf 'A condensed copy of the canon table in `.claude/WSS.TOOLING.md'"'"'s "Who invokes whom", sanctioned under `wss/workflow/WSS.RECORD-CONTRACT.md'"'"'s exception 2: this table'"'"'s cells are free to shorten, but every caller must be one the catalog carries.\n\n'
      printf '| Caller | Invokes | For |\n|---|---|---|\n'
      printf '| `%s` | `gamma-writer` | reasons |\n' "$2"
    } > "$1/wss/docs/annex/WSS.CLAUDE-TOOLING.md"
    docommit "$1"
  }
  iwanxok="$TMP/doc-invokes-annex-ok"
  iwanx "$iwanxok" "--wss-alpha"
  printf '%s' "$(doc "$iwanxok")" | grep -q "the annex's callers all exist in the catalog's table (1 checked)" \
    && ok "the annex may skip a caller row the catalog carries" \
    || bad "the annex caller comparison reached no verdict, or read condensation as drift"
  iwanxnonote="$TMP/doc-invokes-annex-nonote"
  iwanx "$iwanxnonote" "--wss-alpha"
  sed -n 'p; /canon table in `.claude/{/sanctioned under/d;}' "$iwanxnonote/wss/docs/annex/WSS.CLAUDE-TOOLING.md" > "$iwanxnonote/wss/docs/annex/WSS.CLAUDE-TOOLING.md.tmp" \
    && mv "$iwanxnonote/wss/docs/annex/WSS.CLAUDE-TOOLING.md.tmp" "$iwanxnonote/wss/docs/annex/WSS.CLAUDE-TOOLING.md"
  docommit "$iwanxnonote"
  says "$iwanxnonote" "no exception-2 note naming it" \
    "wss/docs/annex/WSS.CLAUDE-TOOLING.md's caller->invokes table condenses .claude/WSS.TOOLING.md with no exception-2 note naming it — exception 2 requires the note at the copy"
  iwanxdrift="$TMP/doc-invokes-annex-drift"
  iwanx "$iwanxdrift" "--wss-epsilon"
  says "$iwanxdrift" "does not: --wss-epsilon" \
    "a caller only the annex names is a FAILURE — the catalog renamed or dropped it"

  # Row completeness: a row can UNDER-count as easily as it can cite something
  # dead, and nothing above reads in that direction. wss-gamma's own SKILL.md
  # is the base fixture's unedited "Does the gamma thing." — no dispatch verbs
  # — so both fixtures below differ only in one appended sentence.
  iwrcok="$TMP/doc-invokes-rowcomplete-ok"
  iwfix "$iwrcok" "$iwrow" "wss-gamma"
  printf '# wss-gamma\n\nDoes the gamma thing. Reasoning is filed through `delta-tracker`.\n' \
    > "$iwrcok/skills/wss-gamma/SKILL.md"
  docommit "$iwrcok"
  printf '%s' "$(doc "$iwrcok")" | grep -q "no dispatch a skill's own prose claims is missing from its row (1 checked)" \
    && ok "a dispatch the row already carries is not a false alarm" \
    || bad "a genuine, already-covered dispatch was reported as missing, or nothing was checked"
  iwrcbad="$TMP/doc-invokes-rowcomplete-bad"
  iwfix "$iwrcbad" "$iwrow" "wss-gamma"
  printf '# wss-gamma\n\nDoes the gamma thing. Reasoning is filed through `delta-tracker`. Filed per `--wss-beta`.\n' \
    > "$iwrcbad/skills/wss-gamma/SKILL.md"
  docommit "$iwrcbad"
  says "$iwrcbad" "wss-gamma->--wss-beta" \
    "a dispatch a skill's own prose claims, and the row omits, is a WARNING"

  # One record, one writer — the invariant the whole matrix exists to state.
  # Every fixture below differs only in the second row's "Sole writer of" cell,
  # so a verdict can come from nothing else.
  swfix() { # dir, second row's sole-writer cell
    docfix "$1"
    { printf '# Ownership\n\n## The matrix\n\n'
      printf '| Verb | Flag | Skill | Tier | Sole writer of | Authorization the flag grants |\n'
      printf '|---|---|---|---|---|---|\n'
      printf '| alpha | `--alpha` | `alpha-skill` | primitive | `WSS.record.todo` | commit, **not** push |\n'
      printf '| beta | `--beta` | `beta-skill` | primitive | %s | — |\n' "$2"
    } > "$1/wss/workflow/WSS.OWNERSHIP.md"
    docommit "$1"
  }
  swok="$TMP/doc-writers-distinct"
  swfix "$swok" '`WSS.record.roadmap`'
  printf '%s' "$(doc "$swok")" | grep -q "every record has exactly one writer" \
    && ok "two rows claiming different records is clean" \
    || bad "the sole-writer check reached no verdict on a matrix with two distinct claims"
  swdup="$TMP/doc-writers-collide"
  swfix "$swdup" '`WSS.record.todo`'
  says "$swdup" "two writers claim WSS.record.todo: alpha-skill beta-skill" \
    "two rows claiming one record is a FAILURE, and it names both writers"
  swnil="$TMP/doc-writers-disclaim"
  swfix "$swnil" '**nothing** — it dispatches to `--alpha`, which writes `WSS.record.todo`'
  printf '%s' "$(doc "$swnil")" | grep -q "every record has exactly one writer" \
    && ok "a row that disclaims ownership may name another skill's record in its prose" \
    || bad "a nothing-with-an-owner cell was counted as a second claim"
  swblind="$TMP/doc-writers-unreadable"
  swfix "$swblind" '`WSS.record.roadmap`'
  edit_ "$swblind/wss/workflow/WSS.OWNERSHIP.md" 's/| Sole writer of |/| Writes |/'
  docommit "$swblind"
  says "$swblind" "no ownership matrix found in wss/workflow/WSS.OWNERSHIP.md" \
    "a matrix header the parser cannot find is a FAILURE, not an absence of conflicts"

  # A description advertising a shorthand the hook does not serve. Every other
  # flag check runs flag -> skill; this is the direction a reader travels, and
  # the failure is silent — the flag reaches the model as prose.
  advfix() { # dir, alpha-skill description
    docfix "$1"
    printf -- '---\ndescription: "%s"\n---\n\n# alpha-skill\n\nDoes the alpha thing.\n' \
      "$2" > "$1/skills/alpha-skill/SKILL.md"
    docommit "$1"
  }
  advbad="$TMP/doc-shorthand-unserved"
  advfix "$advbad" 'Does the alpha thing. SHORTHAND: --wss-nope. Also trigger on \"do the alpha thing\".'
  says "$advbad" "'alpha-skill' advertises --wss-nope, which wss-shorthand-flags.sh does not serve" \
    "a description advertising a shorthand the hook does not serve is a FAILURE"
  # The filter reads only --wss- tokens, so a description quoting another tool's
  # flag is not a claim about this hook. Without this the check becomes a
  # false-positive generator and gets weakened rather than obeyed.
  advok="$TMP/doc-shorthand-foreign"
  advfix "$advok" 'Does the alpha thing, passing --strict and --alpha along.'
  printf '%s' "$(doc "$advok")" | grep -q "advertises --" \
    && bad "a non---wss- flag in a description was read as an advertised shorthand" \
    || ok "a description quoting another tool's flag is not read as a shorthand claim"

  # The two lane-table pairs, one comparison each. The four-rulings pair must
  # agree in every cell except a trailing "— see below" pointer, so the clean
  # fixture carries the pointer on one side only: an agreeing verdict proves
  # the normalisation, as the method fixture's differing hrefs do. The
  # record-vs-queue pair compares labels one way — the fixture's contract
  # holds a row the annex skips, and must still agree.
  lanefix() { # dir, skill-decline-cell, annex-decline-cell, annex-extra-row
    docfix "$1"
    mkdir -p "$1/skills/lane-record-sync" "$1/wss/docs/annex" "$1/wss/scripts"
    cp "$_root/wss/scripts/wss-gen-lane-rulings.sh" "$1/wss/scripts/wss-gen-lane-rulings.sh"
    { printf '# lane-record-sync\n\n### The four rulings\n\n'
      printf '| Ruling | Files to the queue | Next run |\n|---|---|---|\n'
      printf '| **Accept** | yes, unmarked | — |\n'
      printf '| **Decline** | no | %s |\n' "$2"
    } > "$1/skills/lane-record-sync/SKILL.md"
    { printf '# The lane contract\n\n'
      printf '| | A record | A transfer queue |\n|---|---|---|\n'
      printf '| Writers | exactly one | **any lane** |\n'
      printf '| Write mode | append-only or rewritten in place | append-only, always |\n'
    } > "$1/wss/workflow/WSS.LANE-CONTRACT.md"
    { printf '# Lane synching\n\n'
      printf 'A condensed copy of the canon table in `wss/workflow/WSS.LANE-CONTRACT.md`, sanctioned under `wss/workflow/WSS.RECORD-CONTRACT.md'"'"'s exception 2: this table'"'"'s cells are free to shorten, but every row label must still be one the contract carries.\n\n'
      printf '| | A record | A transfer queue |\n|---|---|---|\n'
      printf '| Writers | exactly one | any lane |\n'
      [ -n "$4" ] && printf '| %s | something | something |\n' "$4"
      printf '\n### The four rulings\n\n'
      printf '<!-- BEGIN GENERATED by wss-gen-lane-rulings.sh — do not edit by hand -->\n'
      printf '| Ruling | Files to the queue | Next run |\n|---|---|---|\n'
      printf '| **Accept** | yes, unmarked | — |\n'
      printf '| **Decline** | no | %s |\n' "$3"
      printf '<!-- END GENERATED -->\n'
    } > "$1/wss/docs/annex/WSS.LANE-SYNCHING.md"
    docommit "$1"
  }
  lnok="$TMP/doc-lanes-agree"
  lanefix "$lnok" "**does not ask** — see below" "**does not ask**" ""
  printf '%s' "$(doc "$lnok")" | grep -q "WSS.LANE-SYNCHING.md's four-rulings table current, matches skills/lane-record-sync/SKILL.md" \
    && ok "the rulings comparison agrees across the '— see below' pointer" \
    || bad "rulings comparison reached no verdict, or the pointer broke it"
  printf '%s' "$(doc "$lnok")" | grep -q "record-vs-queue rows all exist in the contract (1 checked)" \
    && ok "a contract-only row stays free in the record-vs-queue comparison" \
    || bad "record-vs-queue comparison reached no verdict, or flagged the contract's extra row"
  lnnonote="$TMP/doc-lanes-annex-nonote"
  lanefix "$lnnonote" "**does not ask** — see below" "**does not ask**" ""
  sed -i '/sanctioned under/d' "$lnnonote/wss/docs/annex/WSS.LANE-SYNCHING.md"
  docommit "$lnnonote"
  says "$lnnonote" "no exception-2 note naming it" \
    "wss/docs/annex/WSS.LANE-SYNCHING.md's record-vs-queue table condenses wss/workflow/WSS.LANE-CONTRACT.md with no exception-2 note naming it — exception 2 requires the note at the copy"
  printf '%s' "$(doc "$lnnonote")" | grep -q "record-vs-queue rows all exist in the contract (1 checked)" \
    && ok "the unrelated four-rulings check still passes when the record-vs-queue note is stripped" \
    || bad "stripping the note broke the unrelated four-rulings comparison"
  lndrift="$TMP/doc-lanes-drift"
  lanefix "$lndrift" "**does not ask**" "**asks again**" ""
  says "$lndrift" "four-rulings table is stale" \
    "a ruling cell worded differently on the two sides is a FAILURE"
  says "$lndrift" "Regenerate with \`bash wss/scripts/wss-gen-lane-rulings.sh\`" \
    "a stale four-rulings table names the regenerate command, even though it no longer names which row drifted"
  lnextra="$TMP/doc-lanes-annex-extra"
  lanefix "$lnextra" "**does not ask**" "**does not ask**" "Steady state"
  says "$lnextra" "carries rows" \
    "an annex-only record-vs-queue row is a FAILURE"
  lnblind="$TMP/doc-lanes-unreadable"
  lanefix "$lnblind" "**does not ask**" "**does not ask**" ""
  sed -i '/BEGIN GENERATED/d; /END GENERATED/d' "$lnblind/wss/docs/annex/WSS.LANE-SYNCHING.md"
  docommit "$lnblind"
  says "$lnblind" "carries no generated block to replace" \
    "an annex with no BEGIN/END GENERATED markers is a FAILURE, not a silent agreement"

  # The splittable set: one contract line, and every site that restates the key
  # list for a reader who would otherwise follow a link. EVERY site in this
  # fixture wraps across a line break, and each wraps somewhere different — the
  # anchor split in one, the key list split in another, the parenthesis split in
  # the third. A line-based grep sees `todo` and `openDecisions` and calls three
  # correct files drift, so an agreeing verdict here is the whole proof that the
  # walk normalises newlines before it compares.
  spfix() { # dir, canon list, full list, subset list
    docfix "$1"
    mkdir -p "$1/skills/record" "$1/skills/gamma-skill"
    { printf '# The lane contract\n\n## Which records may split\n\n'
      printf -- '**Splittable: %s** — forward-looking records.\n' "$2"
    } > "$1/wss/workflow/WSS.LANE-CONTRACT.md"
    { printf '# alpha-skill\n\nDoes the alpha thing. Where a selector names a lane,\n'
      printf 'the manifest overrides\n'
      printf -- '`WSS.record.X` for %s — the resolution rule.\n' "$3"
    } > "$1/skills/alpha-skill/SKILL.md"
    { printf '# beta-skill\n\nDoes the beta thing. The manifest overrides\n'
      printf -- '`WSS.record.X` for %s\n%s — the resolution rule.\n' "${3% *}" "${3##* }"
    } > "$1/skills/beta-skill/SKILL.md"
    { printf '# gamma-skill\n\nWrites the manifest. Only the splittable keys\n'
      printf -- '(%s) may appear in a lane map.\n' "$3"
    } > "$1/skills/gamma-skill/SKILL.md"
    { printf '# record\n\nWrites two records, and overrides\n'
      printf -- '`WSS.record.X` for %s — the resolution rule.\n' "$4"
    } > "$1/skills/record/SKILL.md"
    docommit "$1"
  }
  spcanon='`todo`, `openDecisions`, `handoff`, `roadmap`'
  spfull='`todo`, `openDecisions`, `handoff` and `roadmap`'
  spsub='`todo` and `openDecisions`'

  # The new happy path: a real contract, and NOTHING restates it — pointers
  # only. wss/workflow/WSS.LANE-CONTRACT.md's own marker must still resolve.
  spclean="$TMP/doc-split-clean"
  docfix "$spclean"
  { printf '# The lane contract\n\n## Which records may split\n\n'
    printf -- '**Splittable: %s** — forward-looking records.\n' "$spcanon"
  } > "$spclean/wss/workflow/WSS.LANE-CONTRACT.md"
  mkdir -p "$spclean/skills/alpha-skill"
  printf '# alpha-skill\n\nDoes the alpha thing. See wss/workflow/WSS.LANE-CONTRACT.md for which records may split.\n' \
    > "$spclean/skills/alpha-skill/SKILL.md"
  docommit "$spclean"
  printf '%s' "$(doc "$spclean")" | grep -q "nothing restates the splittable set — wss/workflow/WSS.LANE-CONTRACT.md:5 is still its only statement" \
    && ok "a contract with no restatement site reaches the new happy path" \
    || bad "the splittable-set check reached no verdict on a contract with nothing restating it"

  # Any restatement is now a FAILURE regardless of whether its keys agree with
  # canon — the tolerance for a "correct" restatement is gone. Reuses spfix()'s
  # multi-site, multi-line-wrap fixture (three different wrap styles) to prove
  # the walk still finds and names every site under the new rule.
  spok="$TMP/doc-split-agree"
  spfix "$spok" "$spcanon" "$spfull" "$spsub"
  says "$spok" "restate the splittable set by hand" \
    "a restatement site is a FAILURE now even when its keys agree with canon"
  # File and line are the load-bearing half and are asserted; the key list the
  # message prints alongside them is not, because which keys a site happens to
  # restate is no longer what makes it a finding — restating at all is.
  printf '%s' "$(doc "$spok")" | grep -q "skills/alpha-skill/SKILL.md:4" \
    && ok "the failure names the site that restates, file and line" \
    || bad "the splittable-set failure did not name a specific restatement site"

  spdrift="$TMP/doc-split-drift"
  spfix "$spdrift" "$spcanon" "$spfull" "$spsub"
  edit_ "$spdrift/skills/beta-skill/SKILL.md" 's/`handoff`/`behaviour`/'
  docommit "$spdrift"
  says "$spdrift" "skills/beta-skill/SKILL.md:3" \
    "a restatement that also drifted from canon is still just a restatement failure, named the same way"

  # And the mirror: copies with no authority left to agree with, which is what a
  # contract moved out of the walk's reach looks like from here.
  spnocanon="$TMP/doc-split-nocanon"
  spfix "$spnocanon" "$spcanon" "$spfull" "$spsub"
  edit_ "$spnocanon/wss/workflow/WSS.LANE-CONTRACT.md" 's/\*\*Splittable:/**Splits into:/'
  docommit "$spnocanon"
  says "$spnocanon" "name a splittable-key list and no contract states one" \
    "restatements with no contract to check against is a FAILURE"

  spdual="$TMP/doc-split-two-canons"
  spfix "$spdual" "$spcanon" "$spfull" "$spsub"
  printf -- '\n**Splittable: `todo`, `openDecisions`** — a second authority.\n' \
    >> "$spdual/skills/gamma-skill/SKILL.md"
  docommit "$spdual"
  says "$spdual" "declared as canon in more than one place" \
    "two files claiming to be the authority is a FAILURE"

  # A config directory with neither the contract nor a copy of it is an adopted
  # project, not a broken suite, and the check must stay quiet there.
  printf '%s' "$out" | grep -q "no splittable-set contract here, and nothing restating one" \
    && ok "a tree with no splittable-set contract and no restatement is clean" \
    || bad "the splittable-set check fired on a config directory that has no lane contract"

  # The new guard: a suite tree whose canon marker broke reaches zero canon AND
  # zero sites, which is the same arithmetic as an adopted tree with no contract
  # at all. The contract file's presence is what now tells them apart.
  #
  # Built the spclean way — a contract plus docfix()'s pointer-only skills — and
  # NOT from spfix(), which writes four restatement sites. With sites present the
  # fixture lands in the no-canon branch above (spnocanon's case) and never
  # reaches the zero/zero branch this is here to cover, so the assertion would
  # pass or fail for the wrong reason.
  spbroken="$TMP/doc-split-canon-broken"
  docfix "$spbroken"
  { printf '# The lane contract\n\n## Which records may split\n\n'
    printf -- '**Sets: %s** — forward-looking records.\n' "$spcanon"
  } > "$spbroken/wss/workflow/WSS.LANE-CONTRACT.md"
  docommit "$spbroken"
  says "$spbroken" "wss/workflow/WSS.LANE-CONTRACT.md is present but states no splittable set" \
    "a suite tree whose canon marker broke is a FAILURE, not a vacuous pass"

  # The control for case 1 is the assertion above rather than a second fixture:
  # docfix() builds `wss/workflow/` with WSS.OWNERSHIP.md and nothing else, so
  # `$clean` IS the no-contract tree, and it is already asserted to pass. A
  # duplicate fixture here would restate that and drift from it separately.

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

  # 4. Wrong flag in a grant_ call. The arm is named --alpha but it calls
  #    grant_ --beta, which is not one of its own case labels.
  dfix="$TMP/doc-grant"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" 's/^    grant_ --alpha$/    grant_ --beta/'
  docommit "$dfix"
  says "$dfix" "block_for()'s '--alpha' arm calls grant_ --beta, which is not one of its own case labels" "a grant_ call with the wrong flag token is reported"

  # 4b. Missing grant_ call. The --alpha flag grants something in the matrix,
  #     but its block_for() arm does not call grant_ --alpha.
  dfix="$TMP/doc-wording"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" '/^    grant_ --alpha$/d'
  docommit "$dfix"
  says "$dfix" '--alpha grants something in WSS.OWNERSHIP.md' "a block_for() arm missing its grant_ call is reported"

  # 5. Row deleted from the matrix. The --alpha flag calls grant_ --alpha, but
  #    that flag's row has been deleted from WSS.OWNERSHIP.md's matrix, so it
  #    grants nothing — a call whose backing row is gone.
  dfix="$TMP/doc-norow"; docfix "$dfix"
  edit_ "$dfix/wss/workflow/WSS.OWNERSHIP.md" '/^| alpha |/d'; docommit "$dfix"
  says "$dfix" "whose row in WSS.OWNERSHIP.md's matrix grants nothing" "a grant_ call whose matrix row is missing is reported"

  # 6. Arms unparseable. Rename block_for() so the parser cannot find the
  #    function at all, and the check reads nothing from the hook's side.
  dfix="$TMP/doc-noauth"; docfix "$dfix"
  edit_ "$dfix/wss-shorthand-flags.sh" 's/^block_for() {$/block_for_renamed() {/'; docommit "$dfix"
  says "$dfix" "block_for()'s case arms could not be parsed at all" "an unparseable block_for() function withholds the pass line"
  printf '%s' "$(doc "$dfix")" | grep -q "every grant_ call in block_for()" \
    && bad "the grant check passed while block_for() was unparseable — no pass line should be claimed" \
    || ok "an unparseable block_for() withholds the entire check instead of claiming one"

  # 6b. THE NAMING CHECK MUST NOT FIRE ON A COMMAND WRAPPER, in either install
  #     form. A wrapper's filename IS its invocation, and which spelling is
  #     correct depends on the form: a checkout keeps the prefix
  #     (`log.md`), the published plugin strips it because the namespace
  #     supplies it (`log.md` -> `/wss:log`). wss-publish.sh performs that strip
  #     deliberately, so asserting the prefixed form over the assembly demands a
  #     prefix the assembly exists to remove. That is not hypothetical: the
  #     check shipped without this exemption and failed a real publish assembly
  #     at Gate 3 the next day, on commands/log.md and commands/todo.md.
  #     docfix() already writes commands/alpha.md — the unprefixed, published
  #     form — so the fixture needs only the naming contract present to make the
  #     check run at all.
  dfix="$TMP/doc-naming"; docfix "$dfix"
  printf '# Naming (fixture)\n\nThe suite names its files `wss-<name>` or `WSS.<...>`.\n' \
    > "$dfix/wss/workflow/WSS.NAMING.md"
  mv "$dfix/skills/alpha-skill" "$dfix/skills/wss-alpha"
  mv "$dfix/skills/beta-skill"  "$dfix/skills/wss-beta"
  edit_ "$dfix/wss/workflow/WSS.OWNERSHIP.md" 's/`alpha-skill`/`wss-alpha`/; s/`beta-skill`/`wss-beta`/'
  docommit "$dfix"
  printf '%s' "$(doc "$dfix" --notes)" | grep -q 'commands/alpha.md' \
    && bad "the naming check fired on a command wrapper — the published form can never satisfy it" \
    || ok "a command wrapper is exempt from the naming convention, in either install form"

  #     THE CONTROL, without which the assertion above passes on a dead check:
  #     a file the suite DID name, in a directory with no exemption, must still
  #     be reported. If this stops firing, the exemption above proves nothing.
  printf '# stray\n' > "$dfix/wss/workflow/badname.md"
  docommit "$dfix"
  says "$dfix" 'do not follow wss/workflow/WSS.NAMING.md' \
    "a suite-named file that breaks the convention is still reported — the exemption did not disable the check"

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
    printf 'Also [gone](wss/workflow/WSS.OWNERSHIP.md#no-such-heading).\n' >> "$dfix/README.md"
    docommit "$dfix"
    says "$dfix" 'no-such-heading' "a link to a heading that does not exist is reported"
  fi

  # 9. --strict, in the direction that matters. The warn class carries the real
  #    drift — "resolves nowhere", "the row that should back this call is gone" — and only fails set exit 1,
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

  # 10b. Saying it is not enough — it must not be GREEN while it says it.
  #      wss-doctor.sh's notice() carries its own definition: "a cost or a
  #      coverage gap, not a fault", counted every run but only printed with
  #      --notes — never counted toward --strict's exit code either way. That is exactly what an empty
  #      input set is. Reported as ok instead, a run of nothing but empty walks
  #      reads as fully verified, and the Result line's "all checks passed"
  #      counts it — the false green ruled worse than a missing check.
  #      Test 10 above asserts the WORDING; this asserts the CLASS, which is
  #      the half that survives someone rewording the message. Both are needed:
  #      the wording without the class is what shipped until 2026-08-15.
  out_plain=$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')
  printf '%s' "$out_plain" | grep -qE '^  ok +no skill/agent/procedure citations to check' \
    && bad "the empty-set arm still reports a green ok — a check that examined nothing reads as one that passed" \
    || ok "the empty-set arm does not report green"
  printf '%s' "$out_plain" | grep -qE '^  note +no skill/agent/procedure citations to check' \
    && ok "it is a note instead — the coverage-gap class, never counted toward --strict" \
    || bad "the empty-set arm is neither ok nor note — the notice class was lost, not merely renamed"

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

  # 16. The Cross-references known-procedure set used to be `ls
  #     wss/workflow/writers`, which lists every directory entry — files AND
  #     subdirectories alike — not just the *.md ones a procedure actually is.
  #     A non-.md subdirectory (an `assets/` folder landed under
  #     wss/workflow/writers/ in the same batch that added this test) then joined
  #     the allowlist as if its bare name were a citable procedure. This
  #     fixture stands a directory in for it — `notes-cache` names no .md file,
  #     so a citation to it must resolve to nothing, not silently pass.
  dfix="$TMP/doc-writers-nonmd"; docfix "$dfix"
  mkdir -p "$dfix/wss/workflow/writers/notes-cache"
  printf 'Dispatch via `notes-cache`.\n' >> "$dfix/skills/alpha-skill/SKILL.md"
  docommit "$dfix"
  says "$dfix" 'cites `notes-cache` as a skill or agent, and it resolves to neither' \
    "a bare directory under wss/workflow/writers/ is not a citable procedure"

  # 17. Chain budgets (A1, WSS.TODO.md's Annex A1; WSS.ROADMAP.md's "Make the
  #     cost visible before it grows"). The check walks each SKILL.md's
  #     mandated-read citations, sums the same-window chain against a
  #     per-tier budget read from wss/tests/WSS.TOKEN-ECONOMY.md, and
  #     warns — never fails — over budget, folding every over-budget skill
  #     into ONE warn rather than one per skill (19 near-identical warns,
  #     each repeating the same trailing sentence, is the defect this
  #     collapses): a count line, one short line per over-budget skill, then
  #     the shared explanation stated once. A skill whose chain pulls in a
  #     large contract file it unconditionally cites must be named in that
  #     one warn, with its measured size and the tier it was measured
  #     against.
  dfix="$TMP/doc-chain-over"; docfix "$dfix"
  # The tier lookup only recognises a `wss-`-prefixed slug in
  # WSS.OWNERSHIP.md's Skill column (that file is this suite's own matrix, so
  # only its own skills carry the prefix) — rename docfix()'s generic
  # alpha-skill/beta-skill so this fixture actually reaches the walk instead
  # of "no ownership-tier row" and a false-clean "no skills to chain-budget".
  # Local to this fixture: docfix() itself, and every other case that calls
  # it, is untouched.
  mv "$dfix/skills/alpha-skill" "$dfix/skills/wss-alpha"
  mv "$dfix/skills/beta-skill" "$dfix/skills/wss-beta"
  edit_ "$dfix/wss/workflow/WSS.OWNERSHIP.md" 's/`alpha-skill`/`wss-alpha`/; s/`beta-skill`/`wss-beta`/'
  mkdir -p "$dfix/wss/tests"
  cat > "$dfix/wss/tests/WSS.TOKEN-ECONOMY.md" <<'BUDGETFIX'
# Token economy (fixture)

## Chain budget figures

| Tier | Budget | A skill is this tier when |
|---|---|---|
| primitive | 1 KB | test fixture |
| runner | 1 KB | test fixture |
| orchestrator | 1 KB | test fixture |
BUDGETFIX
  # ~2 KB of filler — comfortably over the fixture's 1 KB primitive budget
  # once wss-alpha's own bytes are added, comfortably under it if the
  # citation is not walked at all.
  awk 'BEGIN { for (i = 0; i < 30; i++) print "This line pads the fixture past its tiny budget." }' \
    > "$dfix/wss/workflow/WSS.BIG-CONTRACT.md"
  printf '\nSee [`WSS.BIG-CONTRACT.md`](../../wss/workflow/WSS.BIG-CONTRACT.md) for the rule.\n' \
    >> "$dfix/skills/wss-alpha/SKILL.md"
  # The doctor now reads chainBytes from .claude/WSS.TOOLS.json rather than
  # walking it itself (wss-doctor.sh's own "Chain budgets" section), and
  # docfix() copies no root script into the tree it builds — so this fixture
  # carries the REAL, unedited wss-tools-inventory.sh (never a stand-in: one
  # implementation, exercised here too) and runs it after every mutation
  # above, right before commit, so the JSON reflects wss-alpha's final shape.
  mkdir -p "$dfix/wss/scripts"
  cp "$_root/wss/scripts/wss-tools-inventory.sh" "$dfix/wss/scripts/wss-tools-inventory.sh"
  chmod +x "$dfix/wss/scripts/wss-tools-inventory.sh"
  ( cd "$dfix" && bash wss/scripts/wss-tools-inventory.sh >/dev/null )
  docommit "$dfix"
  says "$dfix" '1 of 2 skill(s) exceed' \
    "the summary states how many of how many skills are over budget, once"
  says "$dfix" 'wss-alpha: same-window chain' \
    "a skill whose chain exceeds its tier's fixture budget is named"
  says "$dfix" 'exceeds its primitive' \
    "the over-budget line names the tier it was measured against"
  out17=$(doc "$dfix" --notes)
  shared_n=$(printf '%s' "$out17" | grep -c "Not a failure: this check reports the cost")
  [ "$shared_n" -eq 1 ] && ok "the shared explanation sentence appears once, not once per skill" \
    || bad "the shared explanation sentence appeared $shared_n time(s) — the summary is not compact"
  over_n=$(printf '%s' "$out17" | grep -c 'same-window chain ~[0-9]* KB exceeds its')
  [ "$over_n" -eq 1 ] && ok "exactly one over-budget skill line, matching the fixture" \
    || bad "expected exactly 1 over-budget skill line, found $over_n"

  # 18. The check's own self-test: a citation format the regex does not match
  #     (prose naming a file instead of a markdown link) must not read as a
  #     clean, well-under-budget tree — it must warn loudly that the walk
  #     found nothing, which is what citation-format drift looks like from
  #     inside the check. This is the check's self-test and stays its own
  #     loud warn — job 3 does not fold it into the over-budget summary.
  dfix="$TMP/doc-chain-zero"; docfix "$dfix"
  mv "$dfix/skills/alpha-skill" "$dfix/skills/wss-alpha"
  mv "$dfix/skills/beta-skill" "$dfix/skills/wss-beta"
  edit_ "$dfix/wss/workflow/WSS.OWNERSHIP.md" 's/`alpha-skill`/`wss-alpha`/; s/`beta-skill`/`wss-beta`/'
  mkdir -p "$dfix/wss/tests"
  cat > "$dfix/wss/tests/WSS.TOKEN-ECONOMY.md" <<'BUDGETFIX2'
# Token economy (fixture)

## Chain budget figures

| Tier | Budget | A skill is this tier when |
|---|---|---|
| primitive | 8 KB | test fixture |
| runner | 40 KB | test fixture |
| orchestrator | 80 KB | test fixture |
BUDGETFIX2
  printf '\nWho owns what is WSS.OWNERSHIP.md, wss/workflow/WSS.OWNERSHIP.md on disk.\nRead that file first. No markdown link, on purpose.\n' \
    >> "$dfix/skills/wss-alpha/SKILL.md"
  printf '\nSame here: see wss/workflow/WSS.OWNERSHIP.md for who owns what.\n' \
    >> "$dfix/skills/wss-beta/SKILL.md"
  # Same reason as case 17: the doctor reads chainBytes from
  # .claude/WSS.TOOLS.json, so this fixture needs the real
  # wss-tools-inventory.sh run against its own (citation-free-on-purpose)
  # final tree before the doctor ever sees it.
  mkdir -p "$dfix/wss/scripts"
  cp "$_root/wss/scripts/wss-tools-inventory.sh" "$dfix/wss/scripts/wss-tools-inventory.sh"
  chmod +x "$dfix/wss/scripts/wss-tools-inventory.sh"
  ( cd "$dfix" && bash wss/scripts/wss-tools-inventory.sh >/dev/null )
  docommit "$dfix"
  says "$dfix" 'found ZERO mandated-read citations' \
    "a tree whose citations are all prose, not markdown links, warns loudly rather than passing clean"

  # 19. A project-local skill (one under $PWD/.claude/skills/, not this
  #     installation's own $CLAUDE_DIR/skills/) used to get a "not measured"
  #     notice unconditionally: wss-tools-inventory.sh only ever walked its
  #     own tree. It now takes a --root, and wss-doctor.sh uses it to measure
  #     the project-local skill on the spot — the citations it makes into
  #     wss/workflow/ are still classified against $CLAUDE_DIR (a project rarely
  #     carries its own wss/workflow/; its contracts are the suite's). Fixture:
  #     $dfix plays the suite ($CLAUDE_DIR), $dfix/proj plays the project
  #     ($PWD), and proj/.claude/skills/wss-demo/SKILL.md cites $dfix's own
  #     oversized contract by a relative link that crosses from one to the
  #     other, the way an adopting project's would.
  dfix="$TMP/doc-chain-project-local"; docfix "$dfix"
  printf '| demo | — | `wss-demo` | primitive | nothing | — |\n' >> "$dfix/wss/workflow/WSS.OWNERSHIP.md"
  mkdir -p "$dfix/wss/tests"
  cat > "$dfix/wss/tests/WSS.TOKEN-ECONOMY.md" <<'BUDGETFIX3'
# Token economy (fixture)

## Chain budget figures

| Tier | Budget | A skill is this tier when |
|---|---|---|
| primitive | 1 KB | test fixture |
| runner | 1 KB | test fixture |
| orchestrator | 1 KB | test fixture |
BUDGETFIX3
  # ~1.4 KB of filler — over the fixture's 1 KB primitive budget once
  # wss-demo's own bytes are added, comfortably under it if the citation
  # crossing into $dfix's wss/workflow/ is not walked at all (the pre-fix
  # behaviour: the notice never even reaches a KB figure to compare).
  awk 'BEGIN { for (i = 0; i < 30; i++) print "This line pads the fixture past its tiny budget." }' \
    > "$dfix/wss/workflow/WSS.BIG-CONTRACT.md"
  mkdir -p "$dfix/proj/.claude/skills/wss-demo"
  printf -- '---\ndescription: project-local demo skill\n---\n# wss-demo\n\nSee [`WSS.BIG-CONTRACT.md`](../../../../wss/workflow/WSS.BIG-CONTRACT.md) for the rule.\n' \
    > "$dfix/proj/.claude/skills/wss-demo/SKILL.md"
  mkdir -p "$dfix/wss/scripts"
  cp "$_root/wss/scripts/wss-tools-inventory.sh" "$dfix/wss/scripts/wss-tools-inventory.sh"
  chmod +x "$dfix/wss/scripts/wss-tools-inventory.sh"
  docommit "$dfix"
  doc_pl() { # runs the doctor from INSIDE the project fixture, CLAUDE_DIR
             # pointed at the suite fixture — the same split drun_tq() etc.
             # use elsewhere in this file, never the real installation
             # (CLAUDE_DIR always pinned explicitly, per WSS.HAZARDS.md).
    (cd "$dfix/proj" && CLAUDE_CONFIG_DIR="$dfix" CLAUDE_DIR="$dfix" bash "$DOCTOR" --notes 2>&1)
  }
  out19=$(doc_pl)
  case $out19 in
    *'wss-demo: same-window chain'*'exceeds its primitive'*)
      ok "a project-local skill's chain is measured via --root and compared to its tier's budget" ;;
    *) bad "a project-local skill's chain was not measured — expected a 'wss-demo: same-window chain ... exceeds its primitive' line, got: $(printf '%s' "$out19" | grep -i 'wss-demo\|project-local')" ;;
  esac
  case $out19 in
    *'a project-local skill under'*'not budget-checked'*)
      bad "the old 'not measured' notice still fires for a project-local skill even though --root now measures it" ;;
    *) ok "the old unconditional 'not measured' notice is gone for a project-local skill --root can reach" ;;
  esac

  # 20. The guard on the flag itself, direct — not through the doctor. A
  #     --root that does not resolve must fail loudly (non-zero exit), never
  #     report a chain of 0 bytes and exit 0: a silent 0 for a skill that was
  #     never found reads as measured, and it is not — worse than the notice
  #     this entry replaces. Proven broken first (this session, by hand,
  #     against a disposable copy with the guard neutered): with the check
  #     removed, the same bad --root fell back to $SUITE_ROOT and measured
  #     the wrong tree instead of failing, so this assertion is not vacuous.
  if bash "$dfix/wss/scripts/wss-tools-inventory.sh" --root "$dfix/does-not-exist" >/dev/null 2>&1; then
    bad "wss-tools-inventory.sh --root <nonexistent dir> exited 0 — it must fail loudly rather than silently measure nothing"
  else
    ok "wss-tools-inventory.sh --root <nonexistent dir> exits non-zero rather than reporting a silent, wrong figure"
  fi

  # 21. wss-doctor.sh's --root call now captures stdout and stderr
  #     separately rather than folding them together (the fix for the
  #     silent-downgrade fragility: a stray stderr byte on a successful run
  #     used to land inside the JSON, jq would return empty, and the branch
  #     fell through to "ran but reported no chainBytes"). The invariant that
  #     fix depends on lives here, next to the script it constrains: a
  #     successful --root run writes nothing to stderr at all.
  ti_err="$TMP/ti-root-stderr"
  bash "$dfix/wss/scripts/wss-tools-inventory.sh" --root "$dfix/proj/.claude" >/dev/null 2>"$ti_err"; ti_rc=$?
  [ "$ti_rc" -eq 0 ] && ok "a valid wss-tools-inventory.sh --root run exits 0" \
    || bad "wss-tools-inventory.sh --root $dfix/proj/.claude exited $ti_rc, not 0"
  [ ! -s "$ti_err" ] && ok "and a successful --root run writes nothing to stderr" \
    || bad "a successful --root run wrote to stderr: $(cat "$ti_err")"

  # 22. Enumeration reaches a script seeded under wss/workflow/writers/assets/ (the
  #     only wss/workflow/*/assets/ path the globs cover) — no test exercised what
  #     the enumeration itself produces, only that the script runs.
  dfix="$TMP/ti-enum-assets"; rm -rf "$dfix"; mkdir -p "$dfix/wss/workflow/writers/assets" "$dfix/wss/scripts"
  cp "$_root/wss/scripts/wss-tools-inventory.sh" "$dfix/wss/scripts/wss-tools-inventory.sh"
  chmod +x "$dfix/wss/scripts/wss-tools-inventory.sh"
  printf '#!/usr/bin/env bash\necho seed\n' > "$dfix/wss/workflow/writers/assets/wss-seed-script.sh"
  chmod +x "$dfix/wss/workflow/writers/assets/wss-seed-script.sh"
  ( cd "$dfix" && bash wss/scripts/wss-tools-inventory.sh >/dev/null )
  ti_kind=$(jq -r '.entries[] | select(.name=="wss-seed-script.sh") | .kind' "$dfix/.claude/WSS.TOOLS.json")
  [ "$ti_kind" = script ] && ok "a seeded .sh under wss/workflow/writers/assets/ is enumerated with kind==\"script\"" \
    || bad "a seeded .sh under wss/workflow/writers/assets/ was not enumerated as kind==\"script\" (got: '$ti_kind')"

  # 23. The catalog-vs-inventory Scripts/hook pairing (wss-doctor.sh's
  #     "Catalog rows vs tools inventory", matched on `path`) had only a
  #     clean-tree pass to lean on — neither direction of the diff was proven
  #     to fire. wss/workflow/writers/assets/wss-second.sh is the extra real
  #     script; wss-shorthand-flags.sh is docfix()'s own root wss-*.sh, and
  #     must be carried in every catalog variant below or it reads as drift.
  dfix="$TMP/doc-civ-scripts"; docfix "$dfix"
  mkdir -p "$dfix/wss/workflow/writers/assets" "$dfix/wss/scripts"
  cp "$_root/wss/scripts/wss-tools-inventory.sh" "$dfix/wss/scripts/wss-tools-inventory.sh"
  chmod +x "$dfix/wss/scripts/wss-tools-inventory.sh"
  printf '#!/usr/bin/env bash\necho second\n' > "$dfix/wss/workflow/writers/assets/wss-second.sh"
  chmod +x "$dfix/wss/workflow/writers/assets/wss-second.sh"
  ( cd "$dfix" && bash wss/scripts/wss-tools-inventory.sh >/dev/null )

  # (a) a catalog row naming no real file — the direction a catalog-side rename
  #     produces.
  cat > "$dfix/.claude/WSS.TOOLING.md" <<'CIVCATA'
## Global skills

| Skill | Flag | What it does |
|---|---|---|

## Agents

| Agent | What it does |
|---|---|

## Scripts

| Script | What it does |
|---|---|
| `wss/scripts/wss-tools-inventory.sh` | test fixture |
| `wss-shorthand-flags.sh` | test fixture |
| `wss/workflow/writers/assets/wss-second.sh` | test fixture |
| `wss-ghost-script.sh` | test fixture — deliberately names no real file |
CIVCATA
  out23a=$(doc "$dfix")
  printf '%s' "$out23a" | grep -q 'Catalog row with no inventory entry: wss-ghost-script.sh' \
    && ok "a catalog Scripts row naming no real file is caught" \
    || bad "a catalog Scripts row with no inventory entry was not caught"

  # (b) the reverse — a real script with no catalog row.
  cat > "$dfix/.claude/WSS.TOOLING.md" <<'CIVCATB'
## Global skills

| Skill | Flag | What it does |
|---|---|---|

## Agents

| Agent | What it does |
|---|---|

## Scripts

| Script | What it does |
|---|---|
| `wss-shorthand-flags.sh` | test fixture |
| `wss/workflow/writers/assets/wss-second.sh` | test fixture |
CIVCATB
  out23b=$(doc "$dfix")
  printf '%s' "$out23b" | grep -q 'Inventory entry with no catalog row: wss/scripts/wss-tools-inventory.sh' \
    && ok "an inventory script entry with no catalog row is caught" \
    || bad "an inventory entry with no catalog row was not caught"

  # A matching catalog passes cleanly — the fixture is not just miswired to fail.
  cat > "$dfix/.claude/WSS.TOOLING.md" <<'CIVCATC'
## Global skills

| Skill | Flag | What it does |
|---|---|---|

## Agents

| Agent | What it does |
|---|---|

## Scripts

| Script | What it does |
|---|---|
| `wss/scripts/wss-tools-inventory.sh` | test fixture |
| `wss-shorthand-flags.sh` | test fixture |
| `wss/workflow/writers/assets/wss-second.sh` | test fixture |
CIVCATC
  printf '%s' "$(doc "$dfix")" | grep -q 'every script and hook has both a catalog row and an inventory entry' \
    && ok "a matching catalog and inventory pass cleanly" \
    || bad "a matching catalog and inventory did not pass"

  # bugtpl_ static call-site check. Deliberately a standalone fixture, never a
  # mutation of $clean: $clean's block_for() has no arm mentioning
  # WSS.BUG-REPORTS.md at all, and the grants check above already pins
  # $clean's exact arm count ("2 arms walked, 1 granting rows", asserted a
  # few hundred lines up) -- adding a third arm there to serve this test
  # would silently break that pinned number instead of proving anything here.
  bugtplfix() { # dir — a config dir whose only job is to carry a block_for()
                # arm shaped for the bugtpl_ static check.
    local d=$1
    rm -rf "$d"
    mkdir -p "$d/wss/workflow"
    cat > "$d/wss-shorthand-flags.sh" <<'BUGTPLFIX'
#!/usr/bin/env bash
FLAGS=(--report-finding)

skill_for() {
  case $1 in
    --report-finding) echo - ;;
  esac
}

bugtpl_() {
  printf '\n      ## [open] stub\n\n'
}

block_for() {
  case $1 in
  --report-finding)
    cat <<'EOF'
The user included the `--report-finding` flag.
- Instead, APPEND the finding to WSS.BUG-REPORTS.md in the config directory
EOF
    bugtpl_
    ;;
  esac
}
BUGTPLFIX
    chmod +x "$d/wss-shorthand-flags.sh"
  }

  btclean="$TMP/doc-bugtpl-clean"
  bugtplfix "$btclean"
  bt_out=$(doc "$btclean")
  printf '%s' "$bt_out" | grep -q -- "every block_for() arm that files into WSS.BUG-REPORTS.md calls bugtpl_ for its entry format (1 arm(s) checked)" \
    && ok "the bugtpl_ call-site check passes when the only bug-report arm calls bugtpl_" \
    || bad "the bugtpl_ call-site check did not pass a clean fixture: $(printf '%s' "$bt_out" | grep -a 'bugtpl_' | head -2)"

  # Negative control: the same fixture with the bugtpl_ call deleted from the
  # arm, leaving the WSS.BUG-REPORTS.md mention behind. A block that hardcoded
  # the template instead of calling bugtpl_ looks exactly like this at the
  # source level -- still mentioning WSS.BUG-REPORTS.md, no bugtpl_ call.
  btbroken="$TMP/doc-bugtpl-broken"
  cp -r "$btclean" "$btbroken"
  edit_ "$btbroken/wss-shorthand-flags.sh" '/^    bugtpl_$/d'
  bt_broken_out=$(doc "$btbroken")
  printf '%s' "$bt_broken_out" | grep -q -- "block_for()'s '--report-finding' arm tells the model to file into WSS.BUG-REPORTS.md but never calls bugtpl_" \
    && ok "proven: an arm that mentions WSS.BUG-REPORTS.md without calling bugtpl_ is caught -- the pass above is not vacuous" \
    || bad "an arm with the bugtpl_ call deleted was not caught: $(printf '%s' "$bt_broken_out" | grep -a 'bugtpl_\|BUG-REPORTS' | head -2)"

fi

# ------------------------------------------------------- the transfer queue

head_ "lane-record-sync is reachable only by slash"

# No flag, no wrapper, and both are design constraints rather than omissions:
# the run is expensive and it writes into every lane's inbox, so it must never
# fire from a phrase in a sentence or from another skill's dispatch. A flag
# added later would remove that property silently — nothing else would fail.
synch="$_root/skills/lane-record-sync/SKILL.md"
[ -f "$synch" ] && ok "the skill exists" || bad "skills/lane-record-sync/SKILL.md is missing"
# The skill became a thin router plus per-step references on 2026-08-13, so a
# rule it must state now lives in whichever file carries that step. These
# assertions are about the SKILL stating the rule, never about which file holds
# it — search the skill as the unit it is. Assertions that are genuinely about
# the router (a precondition a reader must meet before opening anything) keep
# reading "$synch" directly.
synch_dir="$_root/skills/lane-record-sync"
synch_text() { cat "$synch_dir/SKILL.md" "$synch_dir"/references/*.md 2>/dev/null; }
case " $FLAGS " in
  *lane-record-sync*)
    bad "lane-record-sync has a FLAGS entry — it is slash-only by design" ;;
  *) ok "no flag serves it" ;;
esac
if [ -e "$_root/commands/lane-record-sync.md" ]; then
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
  synch_text | grep -q "\*\*$r\*\*" \
    && ok "the '$r' ruling is offered" \
    || bad "the '$r' ruling is gone from the gate"
done
synch_text | grep -q 'WSS.record.decisionsIndex' \
  && ok "a previous run's declines are read back, so they are not re-asked" \
  || bad "the decline lookup is gone — the skill is stateless and re-litigates every rejection"
synch_text | grep -qi 'remembered nowhere' \
  && ok "a deferral is deliberately not remembered" \
  || bad "the defer semantics are gone — if a deferral is remembered it is just a decline"

# The router split (2026-08-13) turned each numbered step into its own
# references/step*.md file — the breakage class it introduces silently is
# invisible from reading the router alone: a step link that stops resolving,
# or a references/ file the router stopped linking to.
slr_linked=$(grep -oE '\]\(references/WSS\.STEP[0-9]+-[A-Z-]+\.md\)' "$synch" \
  | sed -E 's/^\]\(//; s/\)$//' | sort -u)
slr_n=0; slr_dead=""
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  slr_n=$((slr_n + 1))
  [ -f "$synch_dir/$rel" ] || slr_dead="$slr_dead $rel"
done <<< "$slr_linked"
if [ "$slr_n" -eq 0 ]; then
  bad "no references/step*.md links found in skills/lane-record-sync/SKILL.md — the link pattern went stale"
elif [ -n "$slr_dead" ]; then
  bad "skills/lane-record-sync/SKILL.md links a references/step*.md file that does not exist:$slr_dead"
else
  ok "all $slr_n references/step*.md links in skills/lane-record-sync/SKILL.md resolve"
fi
slr_ondisk=$(cd "$synch_dir/references" 2>/dev/null && ls WSS.STEP*.md 2>/dev/null | sort -u)
slr_orphan=$(comm -13 <(printf '%s\n' "$slr_linked") <(printf '%s\n' "$slr_ondisk" | sed 's#^#references/#'))
[ -z "$slr_orphan" ] \
  && ok "no skills/lane-record-sync/references/step*.md file is orphaned (unlinked from SKILL.md)" \
  || bad "orphaned reference file(s) under skills/lane-record-sync/references/, linked from no step in SKILL.md:$slr_orphan"

head_ "track links wss/workflow/WSS.WORK-ORDER.md, whose own citations resolve"

wo_skill="$_root/skills/track/SKILL.md"
wo_file="$_root/wss/workflow/WSS.WORK-ORDER.md"
grep -qE '\]\(\.\./\.\./wss/workflow/WSS\.WORK-ORDER\.md\)' "$wo_skill" \
  && ok "skills/track/SKILL.md links wss/workflow/WSS.WORK-ORDER.md" \
  || bad "skills/track/SKILL.md no longer links wss/workflow/WSS.WORK-ORDER.md"
[ -f "$wo_file" ] \
  && ok "wss/workflow/WSS.WORK-ORDER.md exists" \
  || bad "wss/workflow/WSS.WORK-ORDER.md is missing — track's link is dead"

wo_linked=$(grep -oE '\]\([A-Za-z0-9_.-]+\.md\)' "$wo_file" | sed -E 's/^\]\(//; s/\)$//' | sort -u)
wo_n=0; wo_dead=""
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  wo_n=$((wo_n + 1))
  [ -f "$_root/wss/workflow/$rel" ] || wo_dead="$wo_dead $rel"
done <<< "$wo_linked"
if [ "$wo_n" -eq 0 ]; then
  bad "no citations found in wss/workflow/WSS.WORK-ORDER.md — the link pattern went stale"
elif [ -n "$wo_dead" ]; then
  bad "wss/workflow/WSS.WORK-ORDER.md cites a file that does not exist:$wo_dead"
else
  ok "all $wo_n of wss/workflow/WSS.WORK-ORDER.md's own citations resolve"
fi

head_ "A lane's transfer queue is a sibling of records, not one of them"

# The queue is how a lane files work into another lane WITHOUT writing its
# records, which is what keeps one-writer-per-record intact. Every assertion
# here defends that: put it under `records` and it becomes a record with many
# writers; declare it for some lanes only and the rest get their requests
# written by hand into their records instead, which is the second writer the
# queue exists to prevent.
tq="$TMP/transfer-queue"
drun_tq() { (cd "$tq" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
                bash "$DOCTOR" --notes 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); }
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
# `named` rather than a key inside a lane. lane-record-sync is its only
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
synch_text | grep -q 'a claim, not a conflict' \
  && ok "the inbox's entries are claims to be re-verified" \
  || bad "the re-verification rule is gone — synch would act on unchecked reports"
synch_text | grep -q 'deleted as not reproducing' \
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

# 2.5. backlog may NOT split — it is one pool a person cherry-picks from.
cat > "$rvp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": "WSS.TODO.md", "backlog": "WSS.BACKLOG.md" },
  "lanes": { "named": { "backend": { "scope": ["b/**"],
    "records": { "todo": "TODO.backend.md", "backlog": "B.backend.md" } } } } }
}
JSON
printf '# Backlog\n' > "$rvp/WSS.BACKLOG.md"
printf '# Backlog\n' > "$rvp/B.backend.md"
out=$(drun_rvp)
case $out in
  *"'backlog' is not a splittable"*)
    ok "a per-lane backlog is refused — backlog is one pool a person cherry-picks from" ;;
  *) bad "WSS.lanes.named.<lane>.records.backlog was accepted — backlog must never split" ;;
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

# -------------------------------------------------- deferral pointers resolve

head_ "A deferral pointer names an entry the decisions index carries"

# .claude/WSS.HAZARDS.md makes "Deferred (owner)" / "Deferred (session)" the
# whole eligibility test --wss-start Phase 2 applies. A pointer that only says
# "see the decision log" cites nothing falsifiable; these fixtures prove the
# doctor tells a resolving citation from a bare one, from one whose entry does
# not exist, and correctly exempts a checkpoint's non-claim.
dpp="$TMP/deferral-pointers"
drun_dpp() { (cd "$dpp" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
                bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'); }
rm -rf "$dpp"; mkdir -p "$dpp/.claude" "$dpp/docs"
cat > "$dpp/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "todo": "WSS.TODO.md", "decisionsIndex": "docs/WSS.DECISIONS-INDEX.md" } }
}
JSON
printf '# Decisions index\n\n- L10 — 2026-08-14 (first) — Something ruled\n' \
  > "$dpp/docs/WSS.DECISIONS-INDEX.md"

cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **Resolves.**
      Deferred (owner) — see the decision log's 2026-08-14 (first) entry.
TODO
out=$(drun_dpp)
case $out in
  *"every deferral pointer citing the decision log names an entry that resolves (1 checked, each against its own '- [ ] ' entry)"*)
    ok "a pointer naming the index's own citation form resolves clean" ;;
  *) bad "a resolving citation was not recognised" ;;
esac

cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **Bare.**
      Deferred (owner) — see the decision log.
TODO
out=$(drun_dpp)
case $out in
  *"WSS.TODO.md:4 names no resolvable decision-log entry"*)
    ok "a bare 'see the decision log' pointer is warned about, not passed" ;;
  *) bad "a bare pointer passed silently" ;;
esac

cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **Unresolved.**
      Deferred (owner) — see the decision log's 2026-08-14 (ninth) entry.
TODO
out=$(drun_dpp)
case $out in
  *"cites '2026-08-14 (ninth)', which docs/WSS.DECISIONS-INDEX.md carries no row for"*)
    ok "a citation the index does not carry is a named FAILURE mode, not a pass" ;;
  *) bad "a nonexistent decision-log entry resolved anyway" ;;
esac

cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **Checkpoint.**
      Deferred (session) — a mechanical wait, not a ruling: needs no gate.
TODO
out=$(drun_dpp)
case $out in
  *"names no resolvable decision-log entry"*)
    bad "a checkpoint pointer, which cites no decision-log entry, was flagged anyway" ;;
  *"checkpoint-only"*) ok "a checkpoint pointer is exempt — it makes no claim about the log" ;;
  *) bad "the checkpoint fixture reached no verdict at all" ;;
esac

# The swallow's root cause is gone: the unit is now a `- [ ] ` entry, not a
# blank-line-delimited blob, and the capture re-arms on every real marker
# rather than only once per blob. This fixture is the one thing that proves
# it — a second marker with NO blank line before it, which the old capture
# swallowed as text and reported clean. Against this design it must be
# checked on its own, with no warning at all.
cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **A register with sub-entries and no blank line inside it.**
      Deferred (owner) — see the decision log's 2026-08-14 (first) entry.
      **A sub-entry that arrived with its own authority.**
      Deferred (session) — see the decision log's 2026-08-14 (first) entry.
TODO
out=$(drun_dpp)
case $out in
  *"opens a blank-line-delimited blob"*)
    bad "the old blank-line capture is back — a second marker with no blank line before it should never be absorbed as text" ;;
  *"outside any '- [ ] ' entry"*)
    bad "a marker inside a recognised '- [ ] ' unit was reported as orphaned" ;;
  *"resolves (2 checked, each against its own '- [ ] ' entry)"*)
    ok "a second marker with no blank line before it is still checked on its own — the swallow is closed at its root" ;;
  *) bad "two markers with no blank line between them reached neither the swallow warning nor the two-checked pass" ;;
esac

cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **A register with sub-entries and a blank line inside it.**
      Deferred (owner) — see the decision log's 2026-08-14 (first) entry.

      **A sub-entry that arrived with its own authority.**
      Deferred (session) — see the decision log's 2026-08-14 (first) entry.
TODO
out=$(drun_dpp)
case $out in
  *"opens a blank-line-delimited blob"*)
    bad "a blank line inside the unit should be inert now, not a trigger" ;;
  *"resolves (2 checked, each against its own '- [ ] ' entry)"*)
    ok "a blank line inside the unit changes nothing — the boundary is '- [ ] ', not blank lines" ;;
  *) bad "the blank-line variant reached neither the warning nor the two-checked pass" ;;
esac

# Backtick-quoted mentions still open no span of their own, even now that the
# capture re-arms — the anchor rule is unchanged by the redesign.
cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **A unit with a real marker and a quoted mention of one.**
      Deferred (owner) — see the decision log's 2026-08-14 (first) entry.
      This entry's authority is `Deferred (owner)`, quoted rather than live.
TODO
out=$(drun_dpp)
case $out in
  *"resolves (1 checked, each against its own '- [ ] ' entry)"*)
    ok "a backtick-quoted mention opens no span of its own under the new capture either" ;;
  *) bad "a backtick-quoted 'Deferred' was miscounted as a live marker" ;;
esac

# The one shape re-arming cannot split: two markers sharing one physical
# line. The strip that isolates a marker's own text keeps only the last, so
# this must still be named, with its count, and the all-clear still withheld
# — the residual of the old swallow warning.
cat > "$dpp/WSS.TODO.md" <<'TODO'
# Backlog

- [ ] **Two markers on one line.**
      Deferred (owner) — see the decision log. Deferred (session) — see the decision log's 2026-08-14 (first) entry.
TODO
out=$(drun_dpp)
case $out in
  *"WSS.TODO.md:4 holds 2 'Deferred' markers on one line"*)
    ok "two markers sharing a physical line are named, with the count, rather than one silently dropped" ;;
  *"resolves"*)
    bad "two markers on one line reported clean — a marker was silently dropped" ;;
  *) bad "the same-line fixture reached no recognisable verdict" ;;
esac

# GENERALITY: a record with no '- [ ] ' line anywhere is not this check's
# assumed shape, and a Deferred marker in one must not pass silently — it is
# orphaned and named, the same non-negotiable slot the swallow held.
cat > "$dpp/WSS.TODO.md" <<'TODO'
# Notes

Deferred (owner) — see the decision log's 2026-08-14 (first) entry.
TODO
out=$(drun_dpp)
case $out in
  *"WSS.TODO.md:3 has a 'Deferred' marker outside any '- [ ] ' entry"*)
    ok "a marker in a record with no '- [ ] ' shape is named as orphaned, not silently passed" ;;
  *"resolves"*)
    bad "a non-checklist record read its lone marker as scoped and passed it — the false OK is back for a different shape" ;;
  *) bad "the orphan fixture reached no recognisable verdict" ;;
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
printf '# Demo\n\n```bash\nS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"\n[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)\n"$S"/wss/tests/wss-doctor.sh\n```\n' \
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
mkdir -p "$pdir/.claude-plugin" "$pdir/skills/demo" "$pdir/hooks" "$pdir/wss/workflow" "$pdir/wss/tests"
printf '{"name":"x","version":"0.0.1","description":"d"}\n' > "$pdir/.claude-plugin/plugin.json"
printf -- '---\nname: demo\ndescription: d\n---\n\nBody.\n' > "$pdir/skills/demo/SKILL.md"
cp "$HOOK" "$pdir/hooks/wss-shorthand-flags.sh" 2>/dev/null || : > "$pdir/hooks/wss-shorthand-flags.sh"
cp "$CHECK" "$pdir/hooks/wss-session-check.sh" 2>/dev/null || : > "$pdir/hooks/wss-session-check.sh"
printf '.credentials.json\n' > "$pdir/.gitignore"
cp "$DOCTOR" "$pdir/wss/tests/wss-doctor.sh"; chmod +x "$pdir/wss/tests/wss-doctor.sh"
# The doctor resolves its sole-writer parser from SELF_DIR — the installation it
# was RUN FROM, never the tree it is checking — so a fixture that models an
# installation carries both files or the doctor fails on a missing parser it was
# never supposed to own. Every fixture below inherits this one by cp -r.
mkdir -p "$pdir/wss/scripts"
cp "$_root/wss/scripts/wss-commit-provenance.sh" "$pdir/wss/scripts/wss-commit-provenance.sh"
chmod +x "$pdir/wss/scripts/wss-commit-provenance.sh"

bare=$(mktemp -d)   # the adopter's own config dir: no skills, no hooks, no repo
printf '{"permissions":{"defaultMode":"auto"}}\n' > "$bare/settings.json"

out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$bare" bash "$pdir/wss/tests/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
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
out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$bare" bash "$gdir/wss/tests/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
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
out=$(cd "$sdir" && CLAUDE_CONFIG_DIR="$sdir" bash "$sdir/wss/tests/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
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
#
# RUN IT FROM A NEUTRAL CWD, as the coexistence case below already does. The
# doctor deliberately mixes two trees: it scans `$PWD/.claude/skills/` for the
# PROJECT's skills and resolves their citations against the INSTALLATION at
# $CLAUDE_DIR — correct in real use, where a project skill citing `git-writer`
# should resolve against the suite. Left in this repository's own cwd, that
# mixing pointed the real tree's project-local skills at docfix()'s synthetic
# installation, which has two stub skills and an empty wss/workflow/ and so resolves
# no writer at all. The assertion then reported a defect in the doctor that was
# really an artifact of where the test stood. This carried no assumption anyone
# had written down; it simply held while `.claude/skills/` was empty here.
out=$(cd "$bare" && CLAUDE_CONFIG_DIR="$TMP/doc-clean" CLAUDE_DIR="$TMP/doc-clean" \
      bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
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
printf '{"name":"wss","version":"0.0.1","description":"d"}\n' \
  > "$co/.claude-plugin/plugin.json"
docommit "$co"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'installed at most once' \
  && ok "the checkout form alone is not coexistence" \
  || bad "checkout form alone: the coexistence check reached no verdict"

mkdir -p "$co/plugins/cache/mk/wss/0.0.1"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'installed TWICE' \
  && ok "a cached plugin install beside the checkout FAILs as coexistence" \
  || bad "a cached wss install beside the checkout passed silently"

rm -rf "$co/plugins"
edit_ "$co/settings.json" 's/{"hooks"/{"enabledPlugins":{"wss@mk":true},"hooks"/'
out=$(doc "$co")
printf '%s' "$out" | grep -q 'installed TWICE' \
  && ok "enabledPlugins naming the suite FAILs as coexistence" \
  || bad "enabledPlugins naming wss passed silently"

edit_ "$co/settings.json" 's/"enabledPlugins":{"wss@mk":true}/"enabledPlugins":{}/'
docommit "$co"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'uninstall residue' \
  && ok "empty enabledPlugins in tracked settings.json warns as residue" \
  || bad "uninstall residue in tracked settings.json went unmentioned"
printf '%s' "$out" | grep -q 'installed TWICE' \
  && bad "residue alone was reported as coexistence" \
  || ok "residue alone is not coexistence"

# The remnant `claude plugin marketplace remove` is for — a registration and its
# clone, neither under plugins/cache/, so the cache-keyed evidence above cannot
# see either. Warn-grade and silent while an install exists; the four cases are
# fire, key-on-the-source-repo, unrelated-marketplace, and install-present.
mkdir -p "$co/plugins"
printf '{"wss":{"source":{"source":"github","repo":"qupunto/wss"}}}\n' \
  > "$co/plugins/known_marketplaces.json"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'marketplace remnant: wss' \
  && ok "a wss marketplace registration with no install warns as a remnant" \
  || bad "a leftover wss marketplace registration passed the doctor clean"
printf '%s' "$out" | grep -q 'installed TWICE' \
  && bad "a marketplace registration alone was reported as coexistence" \
  || ok "a marketplace registration alone is not coexistence"

# Named anything, sourced from the suite: the pre-rename population is the one
# most likely to be carrying residue, and it registered under the old name.
printf '{"anything":{"source":{"source":"github","repo":"qupunto/workflow-secretary-suite"}}}\n' \
  > "$co/plugins/known_marketplaces.json"
printf '%s' "$(doc "$co")" | grep -q 'marketplace remnant: anything' \
  && ok "the remnant check keys on the source repo, not on the marketplace name" \
  || bad "a suite marketplace registered under another name went unflagged"

printf '{"claude-plugins-official":{"source":{"source":"github","repo":"anthropics/claude-plugins-official"}}}\n' \
  > "$co/plugins/known_marketplaces.json"
printf '%s' "$(doc "$co")" | grep -q 'marketplace remnant' \
  && bad "an unrelated marketplace was reported as a wss remnant" \
  || ok "an unrelated marketplace is not a remnant"

# A clone directory with no registration at all — the other half of the pair.
mkdir -p "$co/plugins/marketplaces/wss"
printf '%s' "$(doc "$co")" | grep -q 'marketplace remnant: wss' \
  && ok "a marketplace clone directory alone warns as a remnant" \
  || bad "a leftover plugins/marketplaces/wss clone passed the doctor clean"

# With an install present the registration is that install's own, and the
# coexistence FAIL already describes the machine — two remedies for one state is
# the noise this silence prevents.
mkdir -p "$co/plugins/cache/mk/wss/0.0.1"
out=$(doc "$co")
printf '%s' "$out" | grep -q 'marketplace remnant' \
  && bad "the remnant warned while an install was present" \
  || ok "the remnant stays silent while a wss install is present"
printf '%s' "$out" | grep -q 'installed TWICE' \
  && ok "an install beside the checkout still FAILs with a remnant present" \
  || bad "a remnant plus an install stopped reporting coexistence"
rm -rf "$co/plugins"

# An adopter's machine: a cached install present, config dir NOT the suite's
# checkout. The normal plugin case must not be reported as coexistence.
ad=$(mktemp -d)
printf '{"permissions":{"defaultMode":"auto"}}\n' > "$ad/settings.json"
mkdir -p "$ad/plugins/cache/mk/wss/0.0.1"
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
      bash "$pdir/wss/tests/wss-doctor.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"plugin has no hooks/hooks.json"*|*"installed as a plugin"*)
    bad "a cached doctor applied plugin checks to the checkout it was pointed at" ;;
  *"all checks passed"*)
    ok "an explicit CLAUDE_DIR overrides the doctor's own location" ;;
  *) bad "explicit CLAUDE_DIR: no result line, so this proved nothing" ;;
esac

head_ "A description cannot invite invocation on an ordinary word"

# `wrap` listed `"done"` and `release` listed `"ship it"` — both hold a push
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
# verify.yml holding the exemption pair ONCE and the bare credential walk once.
#
# Once, not twice, since 2026-08-16. The second copy lived in verify.yml's
# "Cross-links between our own files resolve" step, which was deleted as a
# duplicate of wss-doctor.sh's own Link targets check — so the surviving walk is
# the home-path one, and its `'*.md' '*.sh'` pathspec is mirrored here for that
# reason rather than arbitrarily. The assertion below tracks the new count; it
# was NOT loosened, and a fixture carrying the pair twice must still fail.
ax=$(mktemp -d)
mkdir -p "$ax/wss/logs/audits" "$ax/.github/workflows"
printf '# Index\n\n| `2026-01-01-pass1.md` | first | ok | tree |\n' > "$ax/wss/logs/audits/README.md"
printf '# Report one\n' > "$ax/wss/logs/audits/2026-01-01-pass1.md"
cat > "$ax/.github/workflows/verify.yml" <<'YML'
      # VERBATIM COPY of md_files_()'s pathspecs (see wss-doctor.sh)
      run: |
        done < <({ git ls-files -z '*.md' '*.sh' ':(exclude)wss/logs/audits/**'
                   git ls-files -z 'wss/logs/audits/README.md'
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
  *"CI's markdown walk carries md_files_'s pathspecs verbatim"*)
    ok "a verify.yml carrying the pair once, with the say-so note, passes" ;;
  *) bad "walk-agreement check reached no verdict on an agreeing verify.yml" ;;
esac
case $out in
  *"CI's credential scan still walks every tracked file"*)
    ok "the bare credential walk is recognised" ;;
  *) bad "credential-walk check reached no verdict on a bare walk" ;;
esac

# A report with no row must be named. This is the pass-6 shape exactly.
printf '# Report two\n' > "$ax/wss/logs/audits/2026-01-02-pass2.md"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"no index row for 2026-01-02-pass2.md"*)
    ok "an unindexed report is named as a failure" ;;
  *) bad "a report with no index row went unreported — the pass-6 gap again" ;;
esac
rm -f "$ax/wss/logs/audits/2026-01-02-pass2.md"

# One exemption dropped from one walk is the eleven-red-commits drift.
sed '0,/:(exclude)wss\/logs\/audits/s/ '\'':(exclude)wss\/logs\/audits\/\*\*'\''//' \
  "$ax/.github/workflows/verify.yml" > "$ax/.github/workflows/verify.yml.new" \
  && mv "$ax/.github/workflows/verify.yml.new" "$ax/.github/workflows/verify.yml"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"markdown walk has drifted from md_files_()"*)
    ok "a walk missing the exclusion is reported as disagreement" ;;
  *) bad "verify.yml lost an exclusion and the doctor said nothing" ;;
esac

# The credential scan acquiring the exclusion is the failure in the OTHER
# direction: a walk that must never narrow, narrowed.
sed 's|done < <(git ls-files -z)|done < <(git ls-files -z ":(exclude)wss/logs/audits/**" "wss/logs/audits/README.md-no")|' \
  "$ax/.github/workflows/verify.yml" > "$ax/.github/workflows/verify.yml.new" \
  && mv "$ax/.github/workflows/verify.yml.new" "$ax/.github/workflows/verify.yml"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"credential scan no longer walks"*)
    ok "a narrowed credential walk is reported" ;;
  *) bad "the credential walk narrowed and the doctor said nothing" ;;
esac

# The exception SHRANK on 2026-08-16 — one sanctioned verbatim copy, not two —
# so a second walk coming back is drift in the direction nothing watched before.
# Without this, the count could be widened again with only the doctor's own
# comment objecting, which is how a shrunk exception quietly regrows.
cat > "$ax/.github/workflows/verify.yml" <<'YML'
      # VERBATIM COPY of md_files_()'s pathspecs (see wss-doctor.sh)
      run: |
        done < <({ git ls-files -z '*.md' '*.sh' ':(exclude)wss/logs/audits/**'
                   git ls-files -z 'wss/logs/audits/README.md'
                 })
      # VERBATIM COPY of md_files_()'s pathspecs (see wss-doctor.sh)
      run: |
        done < <({ git ls-files -z '*.md' ':(exclude)wss/logs/audits/**'
                   git ls-files -z 'wss/logs/audits/README.md'
                 })
      run: |
        done < <(git ls-files -z)
YML
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"markdown walk has drifted from md_files_()"*)
    ok "a second sanctioned copy coming back is reported as drift" ;;
  *) bad "verify.yml regrew a second walk and the doctor said nothing" ;;
esac

# Since 2026-08-07 the index is `WSS.record.audits`, resolved from the tree's
# own manifest; every fixture above declares no key and exercises the
# `audits/README.md` fallback. A declared key must MOVE the check — BOTH halves
# of it. The row is required in the declared file, a missing row names that file
# rather than the fallback, and THE REPORTS ARE LOOKED FOR BESIDE THAT INDEX, in
# an `audits/` directory alongside it, rather than at this repo's own
# `wss/logs/audits/`. That last half is what makes the check work in a tree that
# is not this one: `skills/audit/SKILL.md` states the same rule in words, and
# a hardcoded reports path would leave every adopter's audits unchecked while
# still reporting a confident pass here.
mkdir -p "$ax/.claude" "$ax/docs/audits"
printf '{"WSS":{"manifest":"workflow/v2","record":{"audits":"docs/WSS.AUDITS.md"}}}\n' \
  > "$ax/.claude/WSS.WORKFLOW.json"
printf '# Audit index\n\n| `2026-01-01-pass1.md` | first | ok | tree |\n' \
  > "$ax/docs/WSS.AUDITS.md"
printf '# Report one\n' > "$ax/docs/audits/2026-01-01-pass1.md"
printf '# Index moved\n' > "$ax/wss/logs/audits/README.md"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"every audit report has an index row (1 checked)"*)
    ok "a declared WSS.record.audits is where the row is looked for" ;;
  *) bad "the index check ignored a declared WSS.record.audits" ;;
esac
printf '# Report two\n' > "$ax/docs/audits/2026-01-02-pass2.md"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"docs/WSS.AUDITS.md has no index row for 2026-01-02-pass2.md"*)
    ok "a missing row names the declared index, not the fallback" ;;
  *) bad "a report with no row in the declared index went unreported" ;;
esac
rm -f "$ax/docs/audits/2026-01-02-pass2.md"
# A report left at THIS repo's hardcoded path must now be invisible to a tree
# that declared its index elsewhere — the discriminator for the derivation, and
# the assertion that fails if the old hardcoded glob ever comes back.
printf '# Stray\n' > "$ax/wss/logs/audits/2026-01-03-pass3.md"
out=$(CLAUDE_DIR="$ax" CLAUDE_CONFIG_DIR="$ax" bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
case $out in
  *"no index row for 2026-01-03-pass3.md"*)
    bad "the reports path is still hardcoded — a stray report outside the declared index's directory was read" ;;
  *) ok "reports are read beside the declared index, not from this repo's own path" ;;
esac
rm -f "$ax/wss/logs/audits/2026-01-03-pass3.md"

head_ "wss-reset-records.sh cannot write outside the project"

# It ships, it truncates files, and it reads its list from a manifest — which is
# data. A `../` path was followed and blanked, and a symlinked record was written
# through onto its target. Both landed outside the project, so outside its git,
# so unrecoverable.
RR="$_root/wss/scripts/wss-reset-records.sh"
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
  hz=$(mktemp -d); mkdir -p "$hz/proj/.claude" "$hz/proj/wss/records" "$hz/outside"
  printf '{"WSS":{"record":{}}}\n' > "$hz/proj/.claude/WSS.WORKFLOW.json"
  printf 'PRECIOUS HAZARDS\n' > "$hz/outside/haz.md"
  ln -s "$hz/outside/haz.md" "$hz/proj/wss/records/WSS.HAZARDS.md"
  bash "$RR" --write --dir "$hz/proj" >/dev/null 2>&1; rc=$?
  [ "$(cat "$hz/outside/haz.md")" = "PRECIOUS HAZARDS" ] \
    && ok "a symlinked WSS.HAZARDS.md is refused like any other record" \
    || bad "wss-reset-records.sh wrote through wss/records/WSS.HAZARDS.md onto an external file"
  [ "$rc" -ne 0 ] || bad "a symlinked WSS.HAZARDS.md was refused but the exit code was 0"

  # And it must still do its job, or the guards above are satisfied by a script
  # that refuses everything.
  mkdir -p "$rr/ok/.claude"
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md","backlog":"WSS.BACKLOG.md","roadmap":"WSS.ROADMAP.md","releases":"WSS.RELEASES.md"}}}\n' \
    > "$rr/ok/.claude/WSS.WORKFLOW.json"
  printf '# Backlog\n\nsomeone else content\n' > "$rr/ok/WSS.TODO.md"
  # The top-level records are enumerated here rather than derived, so a record
  # added to the contract and forgotten in this list ships someone's goals and
  # unreleased plans into the assembled tree — silently, since nothing else
  # reads the list against the manifest.
  printf '# Roadmap\n\nsomeone else goals\n' > "$rr/ok/WSS.ROADMAP.md"
  printf '# Release list\n\nsomeone else milestones\n' > "$rr/ok/WSS.RELEASES.md"
  printf '# Backlog\n\nsomeone else findings\n' > "$rr/ok/WSS.BACKLOG.md"
  bash "$RR" --write --dir "$rr/ok" >/dev/null 2>&1
  [ "$(cat "$rr/ok/WSS.TODO.md")" = "# Todo list" ] \
    && ok "a record inside the project is still blanked to its heading" \
    || bad "wss-reset-records.sh refused a legitimate record"
  [ "$(cat "$rr/ok/WSS.ROADMAP.md")" = "# Roadmap" ] \
    && ok "WSS.record.roadmap is blanked" \
    || bad "wss-reset-records.sh left WSS.ROADMAP.md carrying content"
  [ "$(cat "$rr/ok/WSS.RELEASES.md")" = "# Release list" ] \
    && ok "WSS.record.releases is blanked — it is in the enumerated list" \
    || bad "wss-reset-records.sh left WSS.RELEASES.md carrying content: a new record missing from RECORDS"

  [ "$(cat "$rr/ok/WSS.BACKLOG.md")" = "# Backlog" ] \
    && ok "WSS.record.backlog is blanked — it is in the enumerated list" \
    || bad "wss-reset-records.sh left WSS.BACKLOG.md carrying content: a new record missing from RECORDS"

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
  [ "$(cat "$lp/proj/TODO.backend.md")" = "# Todo list" ] \
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
ER="$_root/wss/scripts/wss-export-records.sh"
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
  # no manifest key names — travels by the same docs/ convention docs uses.
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
RW="$_root/wss/scripts/wss-retire-workflow.sh"
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
  printf '{"name": "wss"}\n' > "$suite/.claude-plugin/plugin.json"
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

# ------------------------------------------------------------- the docs block

head_ "WSS.docs declares a site shape, or is refused"

# wss/tests/WSS.DOCS-AUDIT.md resolves every shell block it runs from
# these three keys. A wrong one is the worst failure an audit has: a root that
# resolves to nothing makes every check walk an empty set and report a clean
# site. So unlike the WSS.suite stamp — which update re-derives from the
# tree and therefore only warns about — a malformed docs block FAILS.
dp="$TMP/docs-proj"
rm -rf "$dp"; mkdir -p "$dp/.claude" "$dp/website" "$dp/website/ca"
: > "$dp/notadir"
: > "$dp/website/index.md"

# Run the doctor over $dp with the given manifest body, ANSI stripped.
drun_docs() {
  printf '%s\n' "$1" > "$dp/.claude/WSS.WORKFLOW.json"
  (cd "$dp" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
     bash "$DOCTOR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
}

out=$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":{"root":"website","languages":["en","ca"],"devCommand":"npm run docs:dev"}}}')
printf '%s' "$out" | grep -q 'WSS.docs resolves' \
  && ok "a complete, resolving docs block passes" \
  || bad "a valid WSS.docs block did not get its pass line"
printf '%s' "$out" | grep -q "sets 'WSS.docs" \
  && bad "WSS.docs warned as a key nothing reads — KNOWN_KEYS missed it or a sub-key" \
  || ok "WSS.docs and its three sub-keys are documented keys, not unknown ones"

# The root is a DIRECTORY. `-e` would pass a file and every later check would
# then walk nothing, which is exactly the silent shape being guarded.
for body in \
  '{"WSS":{"manifest":"workflow/v2","docs":{"root":42}}}' \
  '{"WSS":{"manifest":"workflow/v2","docs":{"root":""}}}' ; do
  printf '%s' "$(drun_docs "$body")" | grep -q 'WSS.docs.root is not a non-empty string' \
    && ok "a non-string WSS.docs.root is refused" \
    || bad "a non-string WSS.docs.root passed: $body"
done
for body in \
  '{"WSS":{"manifest":"workflow/v2","docs":{"root":"nope"}}}' \
  '{"WSS":{"manifest":"workflow/v2","docs":{"root":"notadir"}}}' ; do
  printf '%s' "$(drun_docs "$body")" | grep -q 'which is not a directory here' \
    && ok "a WSS.docs.root that is not a directory is refused" \
    || bad "a root resolving to nothing (or to a file) passed: $body"
done

# The directory can exist and still not be the site: an empty tree (or one
# with only non-markdown files) makes every docs check walk an empty set
# exactly like a wrong path does, so this is the same FAIL tier, not a warn.
mkdir -p "$dp/empty-of-md"
: > "$dp/empty-of-md/notes.txt"
printf '%s' "$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":{"root":"empty-of-md"}}}')" \
  | grep -q "FAIL  WSS.docs.root declares 'empty-of-md', which exists but holds no" \
  && ok "a docs root with zero markdown files anywhere under it is refused" \
  || bad "an empty (of markdown) docs root passed silently"

# "Anywhere under it" means recursive — a markdown file two levels down must
# still satisfy the check, not just one directly inside the root.
mkdir -p "$dp/nested-md/sub/deep"
: > "$dp/nested-md/sub/deep/page.md"
printf '%s' "$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":{"root":"nested-md"}}}')" \
  | grep -q 'WSS.docs resolves' \
  && ok "a markdown file found at any depth (not just directly under root) still resolves" \
  || bad "the zero-markdown check only looked at the top level of the docs root"

# The happy-path root above (website/) carries a markdown file precisely so
# this new check does not turn the existing pass fixture into a failure.
printf '%s' "$out" | grep -q 'WSS.docs resolves' \
  && ok "a docs root that DOES hold markdown still resolves" \
  || bad "the zero-markdown check false-positived on a root that has markdown"

# The list is ordered — first element is the root language — so an empty list
# has no root language to name and is refused rather than read as monolingual.
for body in \
  '{"WSS":{"manifest":"workflow/v2","docs":{"languages":"en"}}}' \
  '{"WSS":{"manifest":"workflow/v2","docs":{"languages":["en",3]}}}' \
  '{"WSS":{"manifest":"workflow/v2","docs":{"languages":[]}}}' ; do
  printf '%s' "$(drun_docs "$body")" | grep -q 'WSS.docs.languages is not a non-empty array' \
    && ok "a malformed WSS.docs.languages is refused" \
    || bad "a malformed languages list passed: $body"
done

# A declared translation needs its directory, or section 5 of the docs audit
# compares against nothing and reports parity for a language that is not there.
# Both directions are asserted: the happy-path block above declares ["en","ca"]
# with website/ca/ present and must stay silent, and the same block warns once
# the directory is taken away.
printf '%s' "$out" | grep -q "WSS.docs.languages declares" \
  && bad "a translation whose directory EXISTS was warned about" \
  || ok "a declared translation with its directory present raises nothing"

rmdir "$dp/website/ca"
out=$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":{"root":"website","languages":["en","ca"]}}}')
printf '%s' "$out" | grep -q "warn  WSS.docs.languages declares 'ca', but website/ca/ does not" \
  && ok "a declared translation with no directory warns" \
  || bad "a missing translation directory passed silently — the docs audit would report parity for it"
printf '%s' "$out" | grep -q "FAIL  WSS.docs.languages declares" \
  && bad "the missing-translation complaint is a FAIL; declaring a language before its pages exist is legitimate" \
  || ok "a missing translation directory is a warn, never a FAIL"
printf '%s' "$out" | grep -q 'WSS.docs resolves' \
  && ok "the warn does not gate the WSS.docs pass line — the shape is still declared, not guessed" \
  || bad "a missing translation directory suppressed the pass line, so it set docs_bad"

# The FIRST element is the root language and lives at the docs root itself, so
# it is the one element that must NOT be looked for in a subdirectory. Here
# neither website/ca/ nor website/en/ exists and only 'en' — the second — may
# be named.
out=$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":{"root":"website","languages":["ca","en"]}}}')
printf '%s' "$out" | grep -q "declares 'en', but website/en/" \
  && ok "the second language is checked for its own subdirectory" \
  || bad "a missing translation directory went unreported when it was second in the list"
printf '%s' "$out" | grep -q "declares 'ca'" \
  && bad "the FIRST language was checked for website/ca/ — it is the root language and lives at the docs root" \
  || ok "the root language is exempt: its pages sit at the docs root, not in a subdirectory"
mkdir -p "$dp/website/ca"

printf '%s' "$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":{"devCommand":5}}}')" \
  | grep -q 'WSS.docs.devCommand is not a non-empty string' \
  && ok "a non-string WSS.docs.devCommand is refused" \
  || bad "a non-string devCommand passed"

printf '%s' "$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":"docs"}}')" \
  | grep -q 'WSS.docs is not an object' \
  && ok "a scalar WSS.docs is refused before its sub-keys are read" \
  || bad "a scalar WSS.docs passed, or crashed the sub-key checks"

# FAIL, not warn — and asserted on the marker rather than on the exit code,
# which a bare temp project already moves for its missing records. An exit-code
# assertion here would pass against a doctor that only warned.
printf '%s' "$(drun_docs '{"WSS":{"manifest":"workflow/v2","docs":{"root":"nope"}}}')" \
  | grep -q 'FAIL  WSS.docs.root declares' \
  && ok "an unresolvable docs root is a FAIL, not a warn — nothing re-derives it" \
  || bad "the docs root complaint is not carrying the FAIL marker wss-session-check greps for"

# Absence is the contract, not a fault: the fallbacks in WSS.MANIFEST.md cover
# every key, so a manifest with no docs block must say nothing about docs.
out=$(drun_docs '{"WSS":{"manifest":"workflow/v2"}}')
printf '%s' "$out" | grep -q 'WSS.docs' \
  && bad "a manifest with no docs block still produced a WSS.docs line" \
  || ok "no docs block is silent — the declared fallbacks cover it"

# ------------------------------------------------------- the record-mode map

head_ "WSS.recordMode is complete or absent, and never partial"

# The map tags every declared record `log`, `register` or `generated`, and
# wss-append-only.sh enforces off the tag. That makes the DEGRADATION direction
# the whole design: absent inherits WSS.RECORD-CONTRACT.md's table and only
# warns, so a tree adopted before the key classifies exactly as one adopted
# after it; a map naming some records and not others FAILS, because the ones it
# names are enforced and the omitted one is silently exempt. A half-derived map
# must therefore land on absent rather than on partial.
#
# The config dir is the clean doctor fixture, not $TMP/bare: these are the only
# assertions here that turn on the doctor's EXIT CODE, and a config that fails
# for its own reasons would make every "exits non-zero" below pass without the
# manifest being read at all.
rm="$TMP/rmode-proj"
rm -rf "$rm"; mkdir -p "$rm/.claude" "$rm/docs"
printf '# Todo list\n'   > "$rm/WSS.TODO.md"
printf '# Backlog\n'     > "$rm/WSS.BACKLOG.md"
printf '# Decisions\n' > "$rm/docs/D.md"
printf '# Catalog\n'   > "$rm/WSS.TOOLING.md"
printf '# A source\n'  > "$rm/docs/src.md"

# `record` is fixed; only the recordMode half varies, so a fixture that drifts
# cannot make one case disagree with another about which records exist.
RM_RECORD='"record": { "todo": "WSS.TODO.md", "backlog": "WSS.BACKLOG.md", "decisions": "docs/D.md",
               "tooling": { "sources": ["docs/*.md"], "catalog": "WSS.TOOLING.md" } }'
rmrun() { # recordMode fragment, or empty for a manifest that declares none
  { printf '{ "WSS": { "manifest": "workflow/v2", %s' "$RM_RECORD"
    [ -z "$1" ] || printf ', "recordMode": %s' "$1"
    printf ' } }\n'
  } > "$rm/.claude/WSS.WORKFLOW.json"
  # No pipe: the exit status has to be the doctor's, not a filter's.
  (cd "$rm" && CLAUDE_CONFIG_DIR="$TMP/doc-clean" CLAUDE_DIR="$TMP/doc-clean" \
     bash "$DOCTOR" 2>&1)
}

out=$(rmrun ''); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'no WSS.recordMode' \
  && ok "a manifest with no recordMode WARNS and still exits 0" \
  || bad "an absent recordMode must warn, not fail — the contract table is the fallback and failing every pre-key tree is a migration wearing a check's clothes (rc=$rc)"

# Every key RM_RECORD declares must appear here, or this stops being the
# complete map it is named for. `backlog` joined RM_RECORD when the record was
# split off the TODO list on 2026-08-16 and belongs here for that reason — the
# assertion was true when written and the rule under it changed, so it moves
# rather than loosening.
RM_FULL='{"todo":"register","backlog":"register","decisions":"log","tooling.catalog":"generated"}'
out=$(rmrun "$RM_FULL"); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'every declared record carries exactly one write mode' \
  && ! printf '%s' "$out" | grep -q 'FAIL' \
  && ok "a complete map clears the warning and adds no failure" \
  || bad "a complete map must clear the warning (rc=$rc): $(printf '%s' "$out" | grep -a FAIL | head -1)"

out=$(rmrun '{"todo":"register","tooling.catalog":"generated"}'); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'gives it no mode' \
  && ok "a map that omits one declared record is a FAILURE" \
  || bad "a partial recordMode map must FAIL — the records it names are enforced and the omitted one is silently exempt (rc=$rc)"

out=$(rmrun '{"todo":"register","decisions":"log","tooling.catalog":"generated"}'); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'WSS.record.backlog is declared but WSS.recordMode gives it no mode' \
  && ok "a backlog record without a recordMode entry is a FAILURE" \
  || bad "a backlog record undeclared in recordMode must FAIL (rc=$rc)"

out=$(rmrun '{"todo":"register","backlog":"register","decisions":"log","tooling.catalog":"generated"}'); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'WSS.record.backlog is declared but WSS.recordMode gives it no mode' \
  && ok "adding backlog to recordMode clears the failure" \
  || bad "a complete recordMode including backlog must pass (rc=$rc)"

out=$(rmrun '{"todo":"register","decisions":"log","tooling.catalog":"generated","ghost":"log"}'); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'which WSS.record does not declare' \
  && ok "a tag for a record the manifest does not declare is a FAILURE" \
  || bad "a tag for an undeclared record guards nothing (rc=$rc)"

# `tooling.sources` is a glob LIST, not a record — the one sub-key of
# `WSS.record.tooling` the enumeration drops. Tagging it is how a map built by
# walking the manifest blindly announces itself.
out=$(rmrun '{"todo":"register","decisions":"log","tooling.catalog":"generated","tooling.sources":"generated"}'); rc=$?
[ "$rc" -ne 0 ] \
  && ok "tagging tooling.sources is a FAILURE" \
  || bad "tooling.sources is a glob list, not a record, and must not be tagged (rc=$rc)"

# The classification itself lives in WSS.RECORD-CONTRACT.md's table and nowhere
# else. Adoption and update BUILD the map, so a table restated in either skill
# would be a second copy of it — and the copy is what drifts, silently, because
# nothing compares a skill's prose to the contract. A mode word beside a record
# key name on one line is what a restated table looks like; the words appear
# separately in both files today, and neither pairs them.
for f in "$_root/skills/adopt/SKILL.md" "$_root/skills/update/SKILL.md"; do
  if [ ! -f "$f" ]; then
    bad "${f#"$_root"/} is missing — the no-second-copy rule went unchecked"
  elif grep -nEi '\b(log|register|generated)\b' "$f" |
         grep -qEi '\b(todo|decisions|decisionsIndex|roadmap|releases|audits|stocktake|handoff|behaviour|reference|changelog|catalog)\b'; then
    bad "${f#"$_root"/} pairs a write mode with a record key — the classification lives in WSS.RECORD-CONTRACT.md only; a second copy in a skill drifts"
  else
    ok "${f#"$_root"/} restates no part of the mode table"
  fi
done

head_ "Every agents/*.md grant matches a row in the per-grant spawn floor table"

# wss/tests/WSS.TOKEN-ECONOMY.md's "## Per-grant spawn floor" table is
# what keeps a new agent from shipping a grant nobody priced —
# agents/wss-execute.md did exactly that until a person caught it. Matched as
# a SET: the table's row order and the frontmatter's tool order differ.
agk_grant_table_sets_() { # file -> one Grant-column backtick span per line
  awk '
    /^## Per-grant spawn floor/ { f=1; next }
    f && /^## / { exit }
    f && /^\|/ {
      n = split($0, c, "|")
      if (n < 3) next
      cell = c[2]
      while (match(cell, /`[^`]+`/)) {
        print substr(cell, RSTART+1, RLENGTH-2)
        cell = substr(cell, RSTART+RLENGTH)
      }
    }
  ' "$1"
}
agk_norm_() { printf '%s' "$1" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort | paste -sd, -; }

agk_known=""
while IFS= read -r agk_span; do
  [ "$agk_span" = "Tools: *" ] && continue
  case "$agk_span" in *,*) ;; *) continue ;; esac
  agk_known="$agk_known
$(agk_norm_ "$agk_span")"
done < <(agk_grant_table_sets_ "$_root/wss/tests/WSS.TOKEN-ECONOMY.md")

for f in "$_root"/agents/*.md; do
  [ -f "$f" ] || continue
  agk_toolsline=$(awk -F': *' '/^tools:/{print $2; exit}' "$f")
  agk_norm=$(agk_norm_ "$agk_toolsline")
  if printf '%s\n' "$agk_known" | grep -qxF "$agk_norm"; then
    ok "${f#"$_root"/}'s tool grant ($agk_toolsline) matches a per-grant spawn floor row"
  else
    bad "${f#"$_root"/}'s tool grant ($agk_toolsline) matches no row in wss/tests/WSS.TOKEN-ECONOMY.md's per-grant spawn floor table — a new or changed agent grant must be priced there too"
  fi
done

# ------------------------------------------- the per-clone half of the guard

head_ "The doctor reports whether the append-only pre-commit hook is installed"

# The guard has two halves and only one of them travels. The CI step sees every
# commit on a branch; the pre-commit hook is written into the git dir by
# `--install-hook`, so it is per-clone and untracked, and a clone that never ran
# it was guarded by CI alone with nothing saying so. The doctor warns — CI is
# the enforcement, the hook is the early warning — and its gates matter as much
# as the check: the CI gate especially, because the workflow runs this doctor
# with --strict, where a warn is an exit 1.

aoi="$TMP/ao-inst"     # an installation: the clean config fixture, plus the one
docfix "$aoi"          # script the check gates on and the message names
mkdir -p "$aoi/wss/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$aoi/wss/scripts/wss-append-only.sh"
chmod +x "$aoi/wss/scripts/wss-append-only.sh"
docommit "$aoi"

aop="$TMP/ao-hookproj"
rm -rf "$aop"; mkdir -p "$aop/.claude" "$aop/docs"
git init -q "$aop" 2>/dev/null
printf '# Decisions\n' > "$aop/docs/D.md"
printf '# Backlog\n'   > "$aop/T.md"
aoproj() { # recordMode fragment — the gate turns on there being a `log` in it
  printf '%s\n' "{\"WSS\":{\"manifest\":\"workflow/v2\",
    \"record\":{\"decisions\":\"docs/D.md\",\"todo\":\"T.md\"},
    \"recordMode\":$1}}" > "$aop/.claude/WSS.WORKFLOW.json"
}
aorun() { # value for CI — both env names are set here rather than inherited,
          # because this suite itself runs in CI and would otherwise gate its
          # own fixture off and assert nothing.
  (cd "$aop" && CI="$1" GITHUB_ACTIONS= \
     CLAUDE_CONFIG_DIR="$aoi" CLAUDE_DIR="$aoi" bash "$DOCTOR" 2>&1 \
     | sed 's/\x1b\[[0-9;]*m//g')
}
aohook="$aop/.git/hooks/pre-commit"
aoproj '{"decisions":"log","todo":"register"}'

rm -f "$aohook"
out=$(aorun '')
printf '%s' "$out" | grep -q 'no append-only pre-commit hook in this clone' \
  && printf '%s' "$out" | grep -q -- '--install-hook' \
  && ok "an uninstalled hook warns, and the warning names the command that installs it" \
  || bad "a clone with no pre-commit hook is guarded by CI alone and the doctor said nothing"

# The marker, not the script's name: the installer writes an explicit one
# because the quoting around an absolute path is what a "does it mention us"
# grep gets wrong. A hook belonging to someone else is not this one.
mkdir -p "$aop/.git/hooks"
printf '#!/usr/bin/env sh\n# somebody else, mentioning wss-append-only.sh in passing\nexit 0\n' \
  > "$aohook"
chmod +x "$aohook"
printf '%s' "$(aorun '')" | grep -q 'no append-only pre-commit hook in this clone' \
  && ok "a foreign pre-commit hook that merely mentions the script is not it" \
  || bad "a hook without the installer's marker was counted as installed"

# Installed by the REAL installer, so the doctor's detection is proven against
# what actually writes the file rather than against a hand-made copy of it.
rm -f "$aohook"
(cd "$aop" && bash "$_root/wss/scripts/wss-append-only.sh" --install-hook >/dev/null 2>&1)
printf '%s' "$(aorun '')" | grep -q 'append-only pre-commit hook is installed' \
  && ok "the hook the installer writes is the hook the doctor recognises" \
  || bad "wss-append-only.sh --install-hook ran and the doctor still called it missing"

# Gate one: CI. The checkout commits nothing and runs the guard as its own step,
# and this doctor runs there with --strict, so an ungated warn reddens builds.
rm -f "$aohook"
printf '%s' "$(aorun 1)" | grep -q 'append-only pre-commit' \
  && bad "the hook check fired in CI, where --strict turns its warn into a failed build" \
  || ok "in CI the check is silent — the guard runs there as a step of its own"

# Gate two: a manifest whose records are all `register` declares no log, so the
# guard would resolve nothing and the hook would have nothing to protect.
aoproj '{"decisions":"register","todo":"register"}'
printf '%s' "$(aorun '')" | grep -q 'append-only pre-commit' \
  && bad "the hook check fired for a manifest that tags no record as a log" \
  || ok "no log-mode record means no hook check — there is nothing for it to guard"
aoproj '{"decisions":"log","todo":"register"}'

head_ "Figure-source citations skip a log/generated-mode record's own file"

# Reuses $aoi/$aop/aorun from the section above: $aop's manifest already tags
# `decisions` (docs/D.md) `log` and `todo` (T.md) `register` (the last aoproj
# call above). wss-doctor.sh's "Figure-source citations" section resolves what
# to skip from WSS.recordMode rather than a second hand-kept list — this is
# the half of that resolution with no coverage at all.
printf '# Decisions\n\nSomething happened, count 11,839 with no source nearby.\n' > "$aop/docs/D.md"
printf '# Backlog\n\nA clean line, then a stray number 22,948 with no source nearby either.\n' > "$aop/T.md"
git -C "$aop" add -A >/dev/null 2>&1
figout=$(aorun '')
printf '%s' "$figout" | grep -q '1 figure(s) in 1 record/doc file(s)' \
  && ok "the figure-source check flags only the register-mode record's uncited figure" \
  || bad "the figure-source check's file count was not exactly 1 of 1 — got: $(printf '%s' "$figout" | grep -A1 'Figure-source citations' | tail -1)"
printf '%s' "$figout" | grep -q '11,839' \
  && bad "an uncited figure inside docs/D.md, whose WSS.recordMode is log, was flagged — the manifest-driven skip did not apply" \
  || ok "an uncited figure inside a log-mode record is not flagged"
printf '%s' "$figout" | grep -q 'T.md:3: A clean line, then a stray number 22,948' \
  && ok "the equivalent uncited figure in the register-mode record is still flagged" \
  || bad "the figure-source check did not flag T.md's uncited figure — it may have gone blind rather than exempting only the log-mode file"

head_ "The alert hook cues only when asked to"

ALERT="$(dirname "$HOOK")/wss-alert.sh"
if [ ! -f "$ALERT" ]; then
  bad "no alert hook beside $HOOK — the sound cue shipped without its script"
else
  acfg="$TMP/alerts-cfg"; atmp="$TMP/alerts-tmp"
  mkdir -p "$acfg/wss/flags" "$atmp"
  # The stamp lives in the config dir beside WSS.ALERTS-ON, not the shared temp
  # dir — a fixed /tmp name is another user's to own or pre-link.
  stamp="$acfg/wss/flags/.wss-alert.stamp"

  # The toggle, through the flag hook itself. CLAUDE_CONFIG_DIR scopes the
  # state file to this test, exactly as it scopes the doctor elsewhere.
  aflag() { # prompt
    printf '%s' "$(jq -nc --arg p "$1" '{prompt:$p}')" \
      | CLAUDE_CONFIG_DIR="$acfg" HOME="$TMP/home" bash "$HOOK" 2>/dev/null \
      | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
  }

  out=$(aflag "--wss-alerts on")
  [ -f "$acfg/wss/flags/WSS.ALERTS-ON" ] && printf '%s' "$out" | grep -q 'now ON' \
    && ok "--wss-alerts on writes the state file and says so" \
    || bad "--wss-alerts on did not create the state file or did not report ON"

  out=$(aflag "--wss-alerts")
  [ -f "$acfg/wss/flags/WSS.ALERTS-ON" ] && printf '%s' "$out" | grep -q 'currently ON' \
    && ok "bare --wss-alerts reports the state without toggling it" \
    || bad "bare --wss-alerts toggled or misreported the state"

  out=$(aflag "--wss-alerts off")
  [ ! -f "$acfg/wss/flags/WSS.ALERTS-ON" ] && printf '%s' "$out" | grep -q 'now OFF' \
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
  : > "$acfg/wss/flags/WSS.ALERTS-ON"
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
  rm -f "$acfg/wss/flags/WSS.ALERTS-ON"
fi

head_ "The decisions index is generated, checked, and refuses to guess"

# wss-index-decisions.sh resolves both paths from the manifest; decisionsIndex has
# deliberately no fallback, so undeclared must be an error, not a default name.
IDX="$_root/skills/record/assets/wss-index-decisions.sh"
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

  # ---- an entry-less log is an ordinary state, and a read failure is not -----
  #
  # render() ended in `grep -n '^## ' | sed`, and is called plainly at
  # `render >"$index"`: a log with no entries made grep exit 1, pipefail handed
  # that to the pipeline and errexit killed the run — with the index ALREADY
  # truncated by the redirect. Exit 1, no rows, no message. An emptied log is
  # not hypothetical either: it is exactly what wss-reset-records.sh and
  # wss-publish.sh leave behind, so the failure sat on the publication path.
  iempty="$TMP/index-empty"; rm -rf "$iempty"; mkdir -p "$iempty/.claude" "$iempty/docs"
  printf '# Decisions\n\nOne per entry, appended.\n' > "$iempty/docs/WSS.DECISIONS.md"
  cat > "$iempty/.claude/WSS.WORKFLOW.json" <<'JSON'
{ "WSS":
{ "manifest": "workflow/v2",
  "record": { "decisions": "docs/WSS.DECISIONS.md",
              "decisionsIndex": "docs/WSS.DECISIONS-INDEX.md" } }
}
JSON
  iout=$(cd "$iempty" && bash "$IDX" 2>/dev/null); irc=$?
  [ "$irc" -eq 0 ] && printf '%s' "$iout" | grep -q '(0 entries)' \
    && ok "a log with no entries regenerates to a header-only index, at exit 0" \
    || bad "an emptied decisions log is an ordinary state — grep's no-match must not kill indexRegen (rc=$irc)"

  # --check reads through the same render(), and read it through a process
  # substitution — a subshell, where render's failure reached nothing and diff
  # simply reported a difference. "STALE" for a log that is not stale at all.
  iout=$(cd "$iempty" && bash "$IDX" --check 2>/dev/null); irc=$?
  [ "$irc" -eq 0 ] && printf '%s' "$iout" | grep -q 'index current' \
    && ok "and --check agrees the header-only index is current" \
    || bad "--check must not report STALE for a log that is not stale (rc=$irc)"

  # Both assertions above are satisfied by a --check that only ever agrees with
  # itself. Against the LITERAL pre-fix code they pass: regen had already
  # truncated the index to the header its dying render printed, so diff compared
  # two truncations and called them current — the same coincidence as the bug.
  # What separates "the two renders agree" from "the index is RIGHT" is a tree
  # where the two sides must disagree, so the entry-less log grows real entries
  # and then its index is made wrong by hand.
  iidx="$iempty/docs/WSS.DECISIONS-INDEX.md"
  printf '\n## 2026-02-01 — grown\n\nbody\n\n## 2026-02-02 — again\n\nbody\n' \
    >> "$iempty/docs/WSS.DECISIONS.md"
  (cd "$iempty" && bash "$IDX" >/dev/null 2>&1)
  irows=$(grep -c '^- L' "$iidx")
  [ "$irows" = 2 ] \
    && grep -q '^- L5 — 2026-02-01 — grown$' "$iidx" \
    && grep -q '^- L9 — 2026-02-02 — again$' "$iidx" \
    && ok "a formerly entry-less log indexes its new entries by content, row per entry" \
    || bad "regen must write one row per entry naming that entry's own line, not merely a file diff agrees with (rows=$irows)"

  # The discriminator. The log is untouched and correct and ONE row of the index
  # names the wrong line, so the two sides cannot be equal by coincidence: a
  # --check that still reports current here is a rubber stamp, whatever its exit
  # code was on the cases above. `sed -i` is not portable and `mv` is.
  sed 's/^- L5 /- L4 /' "$iidx" > "$iidx.new" && mv "$iidx.new" "$iidx"
  ierr=$(cd "$iempty" && bash "$IDX" --check 2>&1 >/dev/null); irc=$?
  [ "$irc" -ne 0 ] && printf '%s' "$ierr" | grep -q 'index STALE' \
    && ok "an index row naming the wrong line is STALE, at a non-zero exit" \
    || bad "--check agreed with an index whose row names a line the entry is not on (rc=$irc)"

  # The other half: a REAL read failure must be loud and must cost nothing.
  # grep exits 1 on no match and 2 or more on an unreadable file, so the two are
  # distinguishable — and only the second is worth dying for.
  ifail="$TMP/index-unreadable"; rm -rf "$ifail"; mkdir -p "$ifail/.claude" "$ifail/docs"
  printf '# Decisions\n\n## 2026-01-01 — first\n\nb\n\n## 2026-01-02 — second\n\nb\n' \
    > "$ifail/docs/WSS.DECISIONS.md"
  cp "$iempty/.claude/WSS.WORKFLOW.json" "$ifail/.claude/WSS.WORKFLOW.json"
  (cd "$ifail" && bash "$IDX" >/dev/null 2>&1)
  chmod 644 "$ifail/docs/WSS.DECISIONS-INDEX.md"
  if [ "$(id -u)" = 0 ]; then
    printf '  \033[33mskip\033[0m  running as root: chmod 000 cannot make a file unreadable, so the grep-exited-2 path is unreachable\n'
  else
    chmod 000 "$ifail/docs/WSS.DECISIONS.md"
    ierr=$(cd "$ifail" && bash "$IDX" 2>&1 >/dev/null); irc=$?
    chmod 644 "$ifail/docs/WSS.DECISIONS.md"
    [ "$irc" -eq 1 ] && printf '%s' "$ierr" | grep -qE 'cannot read .*grep exited 2' \
      && [ "$(grep -c '^- L' "$ifail/docs/WSS.DECISIONS-INDEX.md")" = 2 ] \
      && ok "an unreadable log fails by name and leaves the existing index whole" \
      || bad "a genuine grep failure must be reported by name and must not truncate the index (rc=$irc, rows=$(grep -c '^- L' "$ifail/docs/WSS.DECISIONS-INDEX.md"))"
  fi

  # Rendering aside is what makes the failure above cost nothing — and the copy
  # back is a `cat`, not a `mv`, so mktemp's 0600 does not follow the temp file
  # onto a record that is meant to be world-readable like every other.
  imode_() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null; }
  (cd "$ifail" && bash "$IDX" >/dev/null 2>&1)
  [ "$(imode_ "$ifail/docs/WSS.DECISIONS-INDEX.md")" = 644 ] \
    && ok "regen leaves the index's mode alone" \
    || bad "rendering aside must not carry mktemp's 0600 onto the record (now $(imode_ "$ifail/docs/WSS.DECISIONS-INDEX.md"))"

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
PUB="$_root/wss/scripts/wss-publish.sh"
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
  # fixture's wss/tests/wss-doctor.sh and wss/tests/wss-hook-contract.sh are STUBS on purpose —
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
    rm -rf "$d"; mkdir -p "$d/wss/tests" "$d/docs" "$d/wss/scripts"
    printf '.credentials.json\n.env\nid_rsa\n*.pem\n*.key\n' > "$d/.gitignore"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/wss/scripts/wss-reset-records.sh"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/wss/tests/wss-doctor.sh"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$d/wss/tests/wss-hook-contract.sh"
    chmod +x "$d/wss/scripts/wss-reset-records.sh" "$d/wss/tests/wss-doctor.sh" "$d/wss/tests/wss-hook-contract.sh"
    git init -q "$d" 2>/dev/null
    git -C "$d" config user.email t@test; git -C "$d" config user.name t
    git -C "$d" config commit.gpgsign false
    git -C "$d" add -A >/dev/null 2>&1
    git -C "$d" commit -q -m shape >/dev/null 2>&1 \
      || bad "pubfix: the fixture commit failed in $d — every gate below tests nothing"
    cp "$PUB" "$d/wss-publish.sh"
  }
  pubrun() { # fixture-dir, outdir — combined output; exit status is publish's
    # WSS_PUBLISH_FIXTURE declares these synthetic trees for what they are.
    # Gate 4 compares the shipping set against a tracked lock that only the
    # real repository has; without this the gate fails every fixture, and
    # inferring "fixture" from the lock's absence would make a real repo that
    # never seeded one indistinguishable from a test.
    WSS_PUBLISH_FIXTURE=1 bash "$1/wss-publish.sh" "$2" </dev/null 2>&1
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
  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$p4/wss/tests/wss-doctor.sh"
  git -C "$p4" add wss/tests/wss-doctor.sh >/dev/null 2>&1
  git -C "$p4" commit -q -m doc >/dev/null 2>&1
  out=$(pubrun "$p4" "$TMP/out-pub-docfail"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "wss-doctor.sh non-zero" \
    && ok "Gate 3 propagates the assembly's failing doctor" \
    || bad "the assembly's doctor failed and publish did not (rc=$rc)"

  p5="$TMP/pub-testfail"; pubfix "$p5"
  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$p5/wss/tests/wss-hook-contract.sh"
  git -C "$p5" add wss/tests/wss-hook-contract.sh >/dev/null 2>&1
  git -C "$p5" commit -q -m tests >/dev/null 2>&1
  out=$(pubrun "$p5" "$TMP/out-pub-testfail"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "wss-hook-contract.sh non-zero" \
    && ok "Gate 3 propagates the assembly's failing test suite" \
    || bad "the assembly's tests failed and publish did not (rc=$rc)"

  head_ "The strip tells a shell glob from a slash command"

  # An INVOCATION gains the namespace (`/wss:retire` -> `/wss:retire`); a PATH
  # loses the prefix (`skills/record/` -> `skills/record/`). The
  # discriminator used to be the lookbehind alone, and a glob defeats it: in
  # `*/record/SKILL.md` the character before the `/` is `*`, neither a word
  # character nor a dot, so the strip read a path as an invocation and emitted
  # `*/wss:record/SKILL.md` — a pattern matching nothing. That is what failed
  # v0.10.2 at Gate 3. An invocation is a leaf token and is never followed by
  # `/`, which is the lookahead that separates the two, and all three spellings
  # below have to come out right at once: widening the lookbehind instead would
  # have fixed the glob and broken the italicised prose form.
  pgl="$TMP/pub-strip"; pubfix "$pgl"
  mkdir -p "$pgl/skills/record" "$pgl/hooks" "$pgl/wss/docs"
  printf '# record\n\nThe record skill.\n' > "$pgl/skills/record/SKILL.md"
  { printf '#!/usr/bin/env bash\n'
    printf 'case $1 in */record/SKILL.md) echo "the record skill" ;; esac\n'
    printf 'printf "run /wss:retire when you are done\\n"\n'
  } > "$pgl/hooks/probe.sh"
  chmod +x "$pgl/hooks/probe.sh"
  printf 'The italicised invocation is written */wss:start* in prose.\n' > "$pgl/wss/docs/prose.md"
  # Named files only, never -A: pubfix()'s own wss-publish.sh copy sits
  # untracked at $pgl's root so its own needle list never reaches the
  # archive (its rm target is wss/scripts/wss-publish.sh, not the root) —
  # an -A add here would sweep it in at the wrong path and contaminate $pout.
  git -C "$pgl" add skills/record/SKILL.md hooks/probe.sh wss/docs/prose.md >/dev/null 2>&1
  git -C "$pgl" commit -q -m strip >/dev/null 2>&1
  pout="$TMP/out-pub-strip"
  out=$(pubrun "$pgl" "$pout"); rc=$?
  if grep -qF '*/record/SKILL.md' "$pout/hooks/probe.sh" 2>/dev/null \
     && ! grep -qF '*/wss:record/' "$pout/hooks/probe.sh" 2>/dev/null; then
    ok "a shell glob over a skill directory is stripped, not namespaced"
  else
    bad "the strip read a shell glob as a slash command — an invocation is never followed by '/' (wss-publish.sh's first substitution)"
  fi
  grep -qF '/wss:retire' "$pout/hooks/probe.sh" 2>/dev/null \
    && ok "and a real invocation in the same file still gains the namespace" \
    || bad "a printed slash command lost its namespace — the lookahead went too wide"
  grep -qF '*/wss:start*' "$pout/wss/docs/prose.md" 2>/dev/null \
    && ok "and the italicised prose form stays namespaced" \
    || bad "the italicised invocation was stripped as if it were a path (rc=$rc)"

  # The residual the lookahead cannot see, asserted BEFORE the strip rather than
  # after: `*/wss:record` as a whole pattern — a glob with no trailing segment —
  # is read as an invocation and corrupted either way, and it is the one input
  # shape with no right answer. Checked on the input because the damaged OUTPUT
  # is also how every file narrating this bug spells it.
  pgb="$TMP/pub-strip-bare"; pubfix "$pgb"
  mkdir -p "$pgb/hooks"
  { printf '#!/usr/bin/env bash\n'
    printf 'case $1 in */wss:record) echo "the record dir" ;; esac\n'
  } > "$pgb/hooks/glob.sh"
  chmod +x "$pgb/hooks/glob.sh"
  git -C "$pgb" add hooks/glob.sh >/dev/null 2>&1
  git -C "$pgb" commit -q -m glob >/dev/null 2>&1
  out=$(pubrun "$pgb" "$TMP/out-pub-strip-bare"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qE 'glob\.sh:[0-9]+:' \
    && ok "a glob with no trailing segment fails the assembly, naming file and line" \
    || bad "a glob with no trailing segment was allowed through — the pre-strip assertion did not fire (rc=$rc)"

  head_ "Gate 2's whitelist and the pre-strip glob assertion, two more corners"

  # Gate 2's whitelist names no script individually any more (`grep -n
  # 'Gate 2' wss-publish.sh`) — wss-doctor.sh moved under wss/tests/ in the
  # same reorg, so every script now sits under wss/, admitted wholesale by
  # the wss/ line, and a tracked copy under wss/scripts/ must pass while a
  # root script the list does not name still fails
  p6="$TMP/pub-append-only"; pubfix "$p6"
  mkdir -p "$p6/wss/scripts"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$p6/wss/scripts/wss-append-only.sh"
  chmod +x "$p6/wss/scripts/wss-append-only.sh"
  git -C "$p6" add wss/scripts/wss-append-only.sh >/dev/null 2>&1
  git -C "$p6" commit -q -m ao >/dev/null 2>&1
  out=$(pubrun "$p6" "$TMP/out-pub-append-only"); rc=$?
  [ "$rc" -eq 0 ] && ok "Gate 2 admits a tracked wss-append-only.sh under wss/scripts/" \
    || bad "wss-append-only.sh under wss/scripts/ failed Gate 2 (rc=$rc): $(printf '%s' "$out" | grep -a FAIL | head -2)"

  p6b="$TMP/pub-append-only-stray-root"; pubfix "$p6b"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$p6b/wss-append-only.sh"
  chmod +x "$p6b/wss-append-only.sh"
  git -C "$p6b" add wss-append-only.sh >/dev/null 2>&1
  git -C "$p6b" commit -q -m ao-stray >/dev/null 2>&1
  out=$(pubrun "$p6b" "$TMP/out-pub-append-only-stray-root"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "not one this script admits" \
    && ok "Gate 2 refuses a wss-append-only.sh that strayed back to the root — proves the per-script whitelist entry is really gone, not just redundant" \
    || bad "a root-level wss-append-only.sh sailed through Gate 2 after the move (rc=$rc)"

  p7="$TMP/pub-unlisted-root"; pubfix "$p7"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$p7/wss-mystery.sh"
  chmod +x "$p7/wss-mystery.sh"
  git -C "$p7" add wss-mystery.sh >/dev/null 2>&1
  git -C "$p7" commit -q -m mystery >/dev/null 2>&1
  out=$(pubrun "$p7" "$TMP/out-pub-unlisted-root"); rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "not one this script admits" \
    && ok "Gate 2 still refuses an unlisted root-level script" \
    || bad "an unlisted root script sailed through Gate 2 (rc=$rc)"

  # The pre-strip glob assertion is scoped OUT of tests/ by an anchored awk
  # compare rather than grep's own --exclude-dir, because ugrep — grep on at
  # least one machine this runs on — silently ignores --exclude-dir instead of
  # erroring on it (a filter that quietly stops filtering is the failure this
  # scoping exists to avoid). The bare, no-right-answer shape above (pgb) is
  # proven to fire outside wss/tests/; here it is planted inside wss/tests/
  # instead, where the same fixture-carrying convention this suite itself relies
  # on (pubfix ships wss/tests/wss-hook-contract.sh) means it must never trip.
  #
  # THE PATH IS wss/tests/ AND NOT tests/. It was `tests/` until 2026-08-19,
  # which pubfix has not created since the reorg, so the redirect below failed,
  # nothing was planted, and the assertion passed against a fixture with no glob
  # in it at all — green for the absence of the thing under test. Keep this path
  # equal to pubfix's own `mkdir -p` list; a redirect into a directory that does
  # not exist is silent here because only its stderr says so.
  p8="$TMP/pub-strip-bare-intests"; pubfix "$p8"
  { printf '#!/usr/bin/env bash\n'
    printf 'case $1 in */wss:record) echo "the record dir" ;; esac\n'
  } > "$p8/wss/tests/glob-fixture.sh"
  chmod +x "$p8/wss/tests/glob-fixture.sh"
  git -C "$p8" add wss/tests/glob-fixture.sh >/dev/null 2>&1
  git -C "$p8" commit -q -m glob-in-tests >/dev/null 2>&1
  out=$(pubrun "$p8" "$TMP/out-pub-strip-bare-intests"); rc=$?
  [ "$rc" -eq 0 ] && ok "the same bare, no-trailing-segment glob inside tests/ does not trip the pre-strip assertion" \
    || bad "a bare glob inside tests/ failed the assembly (rc=$rc): $(printf '%s' "$out" | grep -a FAIL | head -2)"

  # And the two shapes that must always resolve cleanly: a wildcard path
  # segment (`*/record/*`) and the italicised prose form (`*/wss:start*`)
  # both end the pattern with a character the assertion already allows, so
  # neither is what SKILL_NAMES/CMD_NAMES additions would ever break — worth
  # pinning anyway, since a narrower future alternation could still catch them.
  p9="$TMP/pub-strip-wildcard"; pubfix "$p9"
  mkdir -p "$p9/hooks"
  { printf '#!/usr/bin/env bash\n'
    printf 'case $1 in */record/*) echo "under the record dir" ;; esac\n'
    printf 'printf "*/wss:start* is how it reads in prose\\n"\n'
  } > "$p9/hooks/wild.sh"
  chmod +x "$p9/hooks/wild.sh"
  git -C "$p9" add hooks/wild.sh >/dev/null 2>&1
  git -C "$p9" commit -q -m wildcard >/dev/null 2>&1
  out=$(pubrun "$p9" "$TMP/out-pub-strip-wildcard"); rc=$?
  [ "$rc" -eq 0 ] && ok "*/record/* and */wss:start* both pass the pre-strip assertion" \
    || bad "a trailing-wildcard glob or the italicised prose form failed the assembly (rc=$rc): $(printf '%s' "$out" | grep -a FAIL | head -2)"
fi

# ------------------------------------------------------- overview wss-probe.sh

head_ "wss-probe.sh emits the overview's countable lines"

# The skill quotes this block rather than re-deriving the counts, so a line
# that drifts here misreports every --wss-overview at once. Asserted on the
# exact lines the report leans on. A bare config dir keeps the doctor line
# hermetic — its content is not asserted, only that probe survives it.
PROBE="$_root/skills/overview/assets/wss-probe.sh"
if [ ! -f "$PROBE" ]; then
  bad "wss-probe.sh missing at $PROBE"
else
  prun() { # dir
    (cd "$1" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" bash "$PROBE" 2>/dev/null)
  }

  # No manifest: conventional names apply, and probe must say that is why.
  pnm="$TMP/probe-noman"
  rm -rf "$pnm"; mkdir -p "$pnm/wss/records"
  git init -q "$pnm" 2>/dev/null
  git -C "$pnm" config user.email t@test; git -C "$pnm" config user.name t
  git -C "$pnm" config commit.gpgsign false
  printf '# Backlog\n\n- [ ] **One.**\n- [ ] **Two.**\n' > "$pnm/wss/records/WSS.TODO.md"
  printf '# Open decisions\n\n## Whether to X\n' > "$pnm/wss/records/WSS.OPEN-DECISIONS.md"
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
    *"todo: wss/records/WSS.TODO.md — 2 open"*) ok "the conventional backlog is counted" ;;
    *) bad "WSS.TODO.md's open count is wrong or absent" ;;
  esac
  case $out in
    *"no checkpoint file at .claude/WSS.SWEEPS.json"*)
      ok "no sweep ever run is said in words" ;;
    *) bad "the no-checkpoint message is gone — freshness reads as silence" ;;
  esac
  case $out in
    *"roadmap: wss/records/WSS.ROADMAP.md — missing"*)
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

  # The probe reports release-in-flight status: plugin.json version vs newest
  # tag. Against the real suite only the matching branch is reachable, and a
  # two-armed assertion over it proved the LINE fired rather than which of the
  # six states produced it — the in-flight branch, the one the line exists for,
  # was never reached.
  out=$(prun "$pman")
  # THE TREE DECIDES WHICH STATE IS CORRECT, so the expectation is derived
  # rather than fixed. The probe compares plugin.json's version against the
  # newest tag; the published assembly is a fresh tree with no ancestry and no
  # tags, so it reports the tagless state and a fixed pattern for the matching
  # state fails there. Accepting both unconditionally would restore exactly the
  # defect the comment above records removing — a line that proves it fired
  # rather than which of the six states produced it.
  # The derivation must include the IN-FLIGHT state, because `release` §4
  # mandates bumping .claude-plugin/plugin.json to the confirmed version BEFORE
  # the tag is cut. Between that commit and the tag push this tree is genuinely
  # mid-release, the probe correctly says so, and an expectation fixed at `no`
  # fails — on the one commit a release always produces, and in CI, which is
  # where it is most expensive. Derived per state rather than widened to accept
  # any of them, so the assertion still says WHICH of the six fired.
  _ptag=$(git -C "$_root" tag -l 'v*' --sort=-v:refname 2>/dev/null | head -1)
  _pver=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$_root/.claude-plugin/plugin.json" 2>/dev/null | head -1)
  if [ -z "$_ptag" ]; then
    want='release in flight: no tag — '
  elif [ -z "$_pver" ]; then
    want='release in flight: no version in plugin.json'
  elif [ "v$_pver" = "$_ptag" ]; then
    want='release in flight: no — '
  elif [ "$(printf '%s\nv%s\n' "$_ptag" "$_pver" | sort -V | tail -1)" = "v$_pver" ]; then
    want='release in flight: yes — '
  else
    want='release in flight: trailing — '
  fi
  case $out in
    *"$want"*)
      ok "the probe reports release-in-flight status against the real suite" ;;
    *) bad "the probe's release-in-flight line is absent or reports the wrong state here" ;;
  esac

  # THE OBSTACLE IS NOT TAG OWNERSHIP, it is that wss-probe.sh derives
  # INSTALL_ROOT from its own BASH_SOURCE — so no fixture DIRECTORY redirects
  # it and a fixture carrying its own git repo and plugin.json would still read
  # the real suite's. Copying the probe to skills/overview/assets/ inside
  # the fixture is what makes `../../..` land on the fixture root, and that is
  # the whole cost: the fixture is small, which is the opposite of what the
  # backlog entry that parked this assumed.
  pfl="$TMP/probe-inflight"
  rm -rf "$pfl"; mkdir -p "$pfl/skills/overview/assets" "$pfl/.claude-plugin"
  cp "$PROBE" "$pfl/skills/overview/assets/wss-probe.sh"
  git init -q "$pfl" 2>/dev/null
  git -C "$pfl" config user.email t@test; git -C "$pfl" config user.name t
  git -C "$pfl" config commit.gpgsign false
  printf '# Backlog\n\n- [ ] **One.**\n' > "$pfl/WSS.TODO.md"
  # Run the fixture's OWN copy, never $PROBE — the point is where BASH_SOURCE
  # resolves, so invoking the real one here would silently re-test the suite.
  pflrun() { (cd "$pfl" && CLAUDE_CONFIG_DIR="$TMP/bare" CLAUDE_DIR="$TMP/bare" \
                bash "$pfl/skills/overview/assets/wss-probe.sh" 2>/dev/null); }
  pflsays() { # needle, label
    case $(pflrun) in
      *"$1"*) ok "$2" ;;
      *) bad "$2 — the probe said something else" ;;
    esac
  }

  # No plugin.json at all, before one is written: the outermost branch.
  pflsays 'release in flight: no plugin.json' \
    "a tree with no plugin.json says so rather than comparing nothing"

  printf '{"name":"x","version":"0.2.0"}\n' > "$pfl/.claude-plugin/plugin.json"
  git -C "$pfl" add -A >/dev/null 2>&1
  git -C "$pfl" commit -q -m fixture >/dev/null 2>&1
  # Committed but untagged: a version with nothing to compare against.
  pflsays 'release in flight: no tag — nothing to compare' \
    "an untagged repo says there is nothing to compare, not that nothing is in flight"

  git -C "$pfl" tag v0.2.0
  # ORDER IS LOAD-BEARING: the probe tests the tag before the version, so the
  # missing-version branch is only reachable once a tag exists. Asserted before
  # tagging it silently re-passes on the no-tag message instead.
  printf '{"name":"x"}\n' > "$pfl/.claude-plugin/plugin.json"
  pflsays 'release in flight: no version in plugin.json' \
    "a plugin.json carrying no version is named, not read as a mismatch"

  printf '{"name":"x","version":"0.2.0"}\n' > "$pfl/.claude-plugin/plugin.json"
  pflsays 'release in flight: no — 0.2.0 matches tag v0.2.0' \
    "a version matching the newest tag is no release in flight"

  # THE BRANCH THIS FIXTURE EXISTS FOR. The release procedure bumps before it
  # tags, so a version ahead of the newest tag is a release mid-flight.
  printf '{"name":"x","version":"0.3.0"}\n' > "$pfl/.claude-plugin/plugin.json"
  pflsays 'release in flight: yes — version 0.3.0 ahead of tag v0.2.0' \
    "a version leading the newest tag IS reported as a release in flight"

  # And the direction that is a real fault rather than a state: the plugin
  # cache path keys on this field, so a trailing version means two published
  # vintages overwrite one directory.
  printf '{"name":"x","version":"0.1.0"}\n' > "$pfl/.claude-plugin/plugin.json"
  pflsays 'release in flight: trailing — version 0.1.0 behind tag v0.2.0' \
    "a version behind the newest tag is called trailing, not in flight"

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

# -------------------------------------------------- overview wss-sweep-distance.sh

head_ "wss-sweep-distance.sh is the one sweep-distance implementation"

# --wss-overview quotes it --verbose through wss-probe.sh; --wss-wrap step 7 runs
# it --compact for its closing line. It exists BECAUSE those were two copies of
# the same nine lines, one of them living in prose nothing executed, free to
# disagree with nothing noticing. So the assertions here are of two kinds: the
# states themselves, and that both renderings report the same distance for the
# same entry. Every path must exit 0 — the line is a report and not a gate, and a
# non-zero exit is the first thing that turns a report into one.
DIST="$_root/skills/overview/assets/wss-sweep-distance.sh"
if [ ! -f "$DIST" ]; then
  bad "wss-sweep-distance.sh missing at $DIST — both callers now depend on it"
else
  sd="$TMP/sweepdist"
  rm -rf "$sd"; mkdir -p "$sd/.claude"
  git init -q "$sd" 2>/dev/null
  git -C "$sd" config user.email t@test; git -C "$sd" config user.name t
  git -C "$sd" config commit.gpgsign false
  printf 'x\n' > "$sd/f.txt"
  git -C "$sd" add -A >/dev/null 2>&1
  git -C "$sd" commit -q -m first >/dev/null 2>&1
  sdbase=$(git -C "$sd" rev-parse HEAD)
  sdbranch=$(git -C "$sd" rev-parse --abbrev-ref HEAD)

  # A commit on another branch: a real sha, resolvable, that HEAD does not
  # descend from — a force-push or a stamp made on a lane worktree.
  git -C "$sd" checkout -q -b sidebranch
  git -C "$sd" commit -q --allow-empty -m side >/dev/null 2>&1
  sdoff=$(git -C "$sd" rev-parse HEAD)
  git -C "$sd" checkout -q "$sdbranch"
  for _ in 1 2 3; do git -C "$sd" commit -q --allow-empty -m c >/dev/null 2>&1; done

  drun() { # mode — prints output, sets drc
    out=$(cd "$sd" && bash "$DIST" "$1" 2>/dev/null); drc=$?
    printf '%s' "$out"
  }

  # No checkpoint at all. The verbose form says so in words; the compact one
  # stays silent, because a project that has never swept has no distance and a
  # zero would claim freshness it has not earned.
  drc=0; out=$(drun --verbose)
  case $out in
    *"no sweep has ever run here"*) ok "no checkpoint is said in words, verbose" ;;
    *) bad "the no-checkpoint message is gone from --verbose" ;;
  esac
  [ "$drc" = 0 ] && ok "no checkpoint still exits 0 — a report, not a gate" \
                 || bad "no checkpoint exited $drc, which makes the line a gate"
  drc=0; out=$(drun --compact)
  [ -z "$out" ] && ok "no checkpoint prints nothing at all, compact" \
                || bad "the compact form invented a line with no checkpoint: $out"
  [ "$drc" = 0 ] || bad "no checkpoint exited $drc in compact mode"

  # A checkpoint whose entries map is empty is the same fact, said differently.
  jq -n '{entries:{}}' > "$sd/.claude/WSS.SWEEPS.json"
  out=$(drun --verbose)
  case $out in
    *"checkpoint exists but holds no entries"*) ok "an empty entries map is named" ;;
    *) bad "an empty entries map went silent instead of saying so" ;;
  esac
  out=$(drun --compact)
  [ -z "$out" ] && ok "an empty entries map prints nothing, compact" \
                || bad "the compact form invented a line from no entries: $out"

  # The four per-entry states, in one checkpoint, in one pass. `plain` is three
  # commits behind; `dirty` is the SAME sha carrying the +dirty suffix a sweep
  # over an unclean tree stamps, and must report the same three; `gone`, `off`
  # and `none` are the three that are not a number and must never render as one.
  jq -n --arg b "$sdbase" --arg o "$sdoff" '{entries:{
      plain: {baseline:$b, at:"2026-02-01", method:"full", result:"green"},
      dirty: {baseline:($b + "+dirty"), at:"2026-02-02", method:"incremental"},
      gone:  {baseline:"notacommitatall", at:"2026-02-03"},
      off:   {baseline:$o, at:"2026-02-04"},
      none:  {at:"2026-02-05"}}}' > "$sd/.claude/WSS.SWEEPS.json"

  drc=0; comp=$(drun --compact)
  [ "$drc" = 0 ] && ok "a checkpoint full of broken baselines still exits 0" \
                 || bad "broken baselines exited $drc — that is a gate"
  case $comp in
    *"plain: 3"*) ok "compact reports the distance as a bare number" ;;
    *) bad "compact lost the distance: $comp" ;;
  esac
  # THE +dirty assertion. Without the strip git resolves nothing and this entry
  # reads `no such commit` — a swept tree reported as unswept, every session.
  case $comp in
    *"dirty: 3"*) ok "a +dirty baseline is stripped and counts the same as the bare sha" ;;
    *) bad "the +dirty suffix was not stripped: $comp" ;;
  esac
  case $comp in
    *"gone: no such commit"*) ok "a sha that resolves to nothing says so" ;;
    *) bad "an unresolvable sha did not say 'no such commit': $comp" ;;
  esac
  # THE ancestry assertion. rev-list would happily count from a divergent sha,
  # and what it counts is everything on HEAD's side of the split — catastrophic
  # drift reported when the only fact is that the sha sits elsewhere.
  case $comp in
    *"off: off this history"*) ok "a baseline HEAD does not descend from is named, not counted" ;;
    *) bad "a non-ancestor baseline was counted instead of named: $comp" ;;
  esac
  case $comp in
    *"off: "[0-9]*) bad "a non-ancestor baseline rendered as a number: $comp" ;;
    *) ok "and no number appears against it" ;;
  esac
  # An absent baseline field is the trap: `git rev-list --count ..HEAD` counts
  # ZERO, so a missing baseline would report perfect freshness.
  case $comp in
    *"none: no baseline"*) ok "an entry with no baseline says so rather than reporting 0" ;;
    *) bad "a missing baseline did not say 'no baseline': $comp" ;;
  esac
  case $comp in
    *"none: 0"*) bad "a missing baseline rendered as 0 commits behind — false freshness" ;;
    *) ok "and it never renders as 0" ;;
  esac
  # One line, entries joined — this is what the wrap prints, whole.
  [ "$(printf '%s\n' "$comp" | wc -l)" = 1 ] && ok "compact is exactly one line" \
    || bad "compact spread over $(printf '%s\n' "$comp" | wc -l) lines"
  case $comp in
    *", "*) ok "and its entries are comma-joined" ;;
    *) bad "the compact line lost its separator: $comp" ;;
  esac

  verb=$(drun --verbose)
  case $verb in
    *"plain: baseline $sdbase (2026-02-01, full, result green) — 3 commits behind HEAD"*)
      ok "verbose carries baseline, stamp, method, result and distance" ;;
    *) bad "the verbose entry line drifted: $(printf '%s' "$verb" | grep '^plain')" ;;
  esac
  case $verb in
    *"dirty at stamp"*) ok "verbose marks a +dirty baseline as dirty at stamp" ;;
    *) bad "the dirty-at-stamp marker is gone from verbose" ;;
  esac
  case $verb in
    *"off: baseline $sdoff is off this history"*)
      ok "verbose names the off-history case too, rather than counting it" ;;
    *) bad "verbose counted a non-ancestor baseline: $(printf '%s' "$verb" | grep '^off')" ;;
  esac

  # The whole point of the file. Two renderings, one computation: every number
  # the compact line reports must be the number the verbose block reports for
  # that same entry. This is the assertion the two hand-written copies could not
  # have, and it is what would go red if either rendering re-derived anything.
  agree=1
  for k in plain dirty; do
    cn=$(printf '%s' "$comp" | tr ',' '\n' | sed -n "s/^ *$k: //p")
    vn=$(printf '%s\n' "$verb" | sed -n "s/^$k: .* — \([0-9]*\) commits behind HEAD$/\1/p")
    [ -n "$cn" ] && [ "$cn" = "$vn" ] || { agree=0; bad "$k: compact says '$cn', verbose says '$vn'"; }
  done
  [ "$agree" = 1 ] && ok "both renderings report the same distance for the same entry"

  # WSS.sweeps is honoured where declared, and the conventional path is the
  # fallback — the same rule wss-session-check.sh and wss-doctor.sh follow. An
  # UNDECLARED key is not the absent case: a project that swept without
  # declaring it still gets its line.
  mv "$sd/.claude/WSS.SWEEPS.json" "$sd/.claude/elsewhere.json"
  printf '{"WSS":{"sweeps":".claude/elsewhere.json"}}\n' > "$sd/.claude/WSS.WORKFLOW.json"
  out=$(drun --compact)
  case $out in
    *"plain: 3"*) ok "a declared WSS.sweeps path is read where it points" ;;
    *) bad "the declared checkpoint path was ignored: $out" ;;
  esac
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md"}}}\n' > "$sd/.claude/WSS.WORKFLOW.json"
  mv "$sd/.claude/elsewhere.json" "$sd/.claude/WSS.SWEEPS.json"
  out=$(drun --compact)
  case $out in
    *"plain: 3"*) ok "an undeclared WSS.sweeps falls back to the conventional path" ;;
    *) bad "an undeclared key was treated as no checkpoint: $out" ;;
  esac

  # Only `entries` is read, matching what sweep-tracker resolves. A reporter
  # that saw further than the writer would report freshness the machinery has not.
  jq -n --arg b "$sdbase" '{plain:{baseline:$b}, entries:{}}' \
    > "$sd/.claude/WSS.SWEEPS.json"
  out=$(drun --compact)
  [ -z "$out" ] && ok "a stamp outside entries is invisible here, as it is to the tracker" \
                || bad "a root-level stamp was read: $out"

  # An unknown mode is the one non-zero exit: a caller's mistake, not a finding
  # about the sweeps.
  (cd "$sd" && bash "$DIST" --whatever >/dev/null 2>&1)
  [ $? -eq 2 ] && ok "an unknown mode exits 2 rather than guessing a rendering" \
               || bad "an unknown mode did not exit 2"
fi

# --------------------------------------------------------- docs wss-scaffold.sh

head_ "wss-scaffold.sh builds the site shell once and refuses an existing one"

# The shell is three files; the refusal is the contract — an existing site is
# the authority on its own conventions and must never be overwritten.
# The docs root is NOT a positional: it is resolved from WSS.docs.root and that
# key's declared fallback chain, so no invocation below passes one. The project
# name is the first positional, and `--root` is the only override.
SCAF="$_root/skills/docs/assets/wss-scaffold.sh"
if [ ! -f "$SCAF" ]; then
  bad "wss-scaffold.sh missing at $SCAF"
else
  sc="$TMP/scaf"; rm -rf "$sc"; mkdir -p "$sc"
  out=$(cd "$sc" && bash "$SCAF" "Demo Project" 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sc/docs/index.html" ] && [ -f "$sc/docs/_sidebar.md" ] \
    && [ -f "$sc/docs/index.md" ] \
    && ok "no manifest and nothing existing: the fallback chain lands on docs/" \
    || bad "the monolingual shell did not scaffold (rc=$rc)"
  printf '%s' "$out" | grep -q 'docs root: docs' \
    && ok "and the resolved root is announced, never silent" \
    || bad "the run never said which root it resolved"
  [ ! -f "$sc/docs/_navbar.md" ] \
    && ok "one language means no language switcher" \
    || bad "a monolingual site grew a _navbar.md"
  grep -q 'Demo Project' "$sc/docs/index.html" 2>/dev/null \
    && ok "the project name reaches the shell" \
    || bad "the project name never made it into index.html"

  printf 'HANDS OFF\n' > "$sc/docs/keep.md"
  out=$(cd "$sc" && bash "$SCAF" "Demo Project" 2>&1); rc=$?
  [ "$rc" -eq 1 ] && ok "an existing docs dir exits 1" \
                  || bad "an existing docs dir exited $rc, not 1"
  printf '%s' "$out" | grep -q 'refusing to scaffold' \
    && ok "and says it is refusing" \
    || bad "the refusal carried no message"
  [ "$(cat "$sc/docs/keep.md" 2>/dev/null)" = "HANDS OFF" ] \
    && ok "and touched nothing in the existing site" \
    || bad "the refused run still wrote into the existing dir"

  (cd "$sc" && bash "$SCAF" --root docs2 "Demo Project" en ca >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sc/docs2/ca/index.md" ] \
    && grep -q 'Català' "$sc/docs2/_navbar.md" 2>/dev/null \
    && ok "translations get their folder and an endonym-labelled navbar" \
    || bad "the multilingual shell lost a language folder or its navbar (rc=$rc)"

  # A declared root and the scaffolder disagreeing in silence is the defect this
  # resolution exists to prevent: both invocations "succeed" when they diverge.
  sm="$TMP/scaf-manifest"; rm -rf "$sm"; mkdir -p "$sm/.claude"
  printf '{"WSS":{"docs":{"root":"website"}}}\n' > "$sm/.claude/WSS.WORKFLOW.json"
  (cd "$sm" && bash "$SCAF" "Demo Project" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sm/website/index.html" ] && [ ! -d "$sm/docs" ] \
    && ok "a manifest-declared root is scaffolded into, with no argument at all" \
    || bad "WSS.docs.root: website did not reach the scaffolder (rc=$rc)"

  (cd "$sm" && bash "$SCAF" --root elsewhere "Demo Project" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sm/elsewhere/index.html" ] \
    && ok "--root overrides the manifest" \
    || bad "--root did not override WSS.docs.root (rc=$rc)"

  out=$(cd "$sm" && bash "$SCAF" --nope "Demo Project" 2>&1); rc=$?
  [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'unknown option' \
    && ok "an unknown flag exits 2 rather than becoming a project name" \
    || bad "an unknown flag exited $rc, not 2"

  # A manifest the scaffolder cannot parse must be a loud fallback, never a dead
  # run: jq exits non-zero on a parse error, and letting that reach the `$(...)`
  # assignment under `set -e` killed the script with an empty screen and a bare
  # exit code. Scaffolding does not require a well-formed manifest — it requires
  # being told the manifest could not be consulted.
  sb="$TMP/scaf-broken"; rm -rf "$sb"; mkdir -p "$sb/.claude"
  printf '{ "WSS": { "docs": { "root": "website" ' > "$sb/.claude/WSS.WORKFLOW.json"
  out=$(cd "$sb" && bash "$SCAF" "Demo Project" 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sb/docs/index.html" ] \
    && ok "an unparseable manifest still scaffolds, down the fallback chain" \
    || bad "an unparseable manifest broke the run (rc=$rc)"
  printf '%s' "$out" | grep -q 'not valid JSON' \
    && ok "and says so, rather than failing to an empty screen" \
    || bad "an unparseable manifest was ignored in silence"

  # ---- the LANGUAGES resolve from the manifest too, or refuse ----------------
  #
  # `WSS.docs.root` was resolved from the manifest and its sibling key was not,
  # so a project could declare its languages and scaffold a site that disagreed
  # with them — the same silent divergence the root's resolution exists to
  # prevent, one key over. Precedence is positional over declared over the
  # documented fallback, and every case below asserts on the TREE, not only on
  # the announcement: a resolution that is announced and not acted on is the
  # same divergence wearing a report.
  scmk() { # dir, manifest-body — a fresh project with nothing scaffolded yet
    rm -rf "$1"; mkdir -p "$1/.claude"
    printf '%s\n' "$2" > "$1/.claude/WSS.WORKFLOW.json"
  }
  scerr() { # dir, [args…] — STDERR only, so an announcement cannot be confused
            # with the next-steps list the run prints on stdout
    local d=$1; shift; (cd "$d" && bash "$SCAF" "$@" 2>&1 >/dev/null)
  }
  SC_LANGS='{"WSS":{"docs":{"languages":["en","ca"]}}}'

  sl="$TMP/scaf-langs"; scmk "$sl" "$SC_LANGS"
  (cd "$sl" && bash "$SCAF" "Demo Project" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sl/docs/ca/index.md" ] \
    && grep -q 'Català' "$sl/docs/_navbar.md" 2>/dev/null \
    && ok "a declared language list scaffolds its folder and navbar, with no argument at all" \
    || bad "WSS.docs.languages did not reach the scaffolder (rc=$rc)"
  # The announcement is the other half: an unannounced resolution is exactly the
  # silence this exists to end, and it is what makes a wrong one findable.
  scmk "$sl" "$SC_LANGS"
  printf '%s' "$(scerr "$sl" "Demo Project")" | grep -q 'languages: en ca' \
    && ok "and the resolved languages and their origin are announced" \
    || bad "the run never said which languages it resolved"

  # Positionals override the declaration outright, exactly as --root overrides
  # WSS.docs.root. The absent folder is the assertion: an override that merely
  # ADDS leaves the declared language scaffolded and unwanted.
  so="$TMP/scaf-langs-override"; scmk "$so" "$SC_LANGS"
  (cd "$so" && bash "$SCAF" "Demo Project" fr de >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -d "$so/docs/de" ] && [ ! -d "$so/docs/ca" ] \
    && ok "positional languages override the declared list rather than joining it" \
    || bad "the positional override did not replace WSS.docs.languages (rc=$rc)"

  # Absent means monolingual — the fallback the key's row already declares.
  sn="$TMP/scaf-langs-none"; scmk "$sn" '{"WSS":{"docs":{"root":"site"}}}'
  (cd "$sn" && bash "$SCAF" "Demo Project" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -f "$sn/site/index.md" ] && [ ! -f "$sn/site/_navbar.md" ] \
    && [ ! -d "$sn/site/en" ] \
    && ok "a manifest declaring no languages scaffolds monolingual" \
    || bad "an undeclared language list did not fall back to monolingual (rc=$rc)"

  # Declared and WRONG is not undeclared: falling back here would scaffold a
  # monolingual site under a manifest that asks for something else. It exits
  # before anything is created — a half-made site is the state with no owner.
  for body in '{"WSS":{"docs":{"languages":"en"}}}' '{"WSS":{"docs":{"languages":[]}}}'; do
    sw="$TMP/scaf-langs-bad"; scmk "$sw" "$body"
    out=$(cd "$sw" && bash "$SCAF" "Demo Project" 2>&1); rc=$?
    [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'is not a non-empty array of non-empty strings' \
      && [ ! -e "$sw/docs" ] \
      && ok "a malformed languages declaration exits 2 and creates nothing: $body" \
      || bad "a malformed languages declaration did not stop the run (rc=$rc): $body"
  done

  # …and the override proceeds through it, LOUDLY. Being able to scaffold while
  # the manifest is being fixed is the point; doing it silently is not.
  sv="$TMP/scaf-langs-bad-override"; scmk "$sv" '{"WSS":{"docs":{"languages":"en"}}}'
  (cd "$sv" && bash "$SCAF" "Demo Project" en ca >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && [ -d "$sv/docs/ca" ] \
    && ok "positional languages override a malformed declaration instead of failing" \
    || bad "an explicit override could not get past a malformed declaration (rc=$rc)"
  scmk "$sv" '{"WSS":{"docs":{"languages":"en"}}}'
  printf '%s' "$(scerr "$sv" "Demo Project" en ca)" | grep -q 'warning: WSS.docs.languages' \
    && ok "and warns about the key it overrode" \
    || bad "the override was silent about the malformed key it stepped over"

  # ---- and all of it again with no jq on PATH --------------------------------
  #
  # The hand parser is the branch a missing `|| true` kills silently: `grep -o`
  # exits 1 on no match, `pipefail` hands that to the caller, and the failure is
  # invisible because the function is called plainly. jq is present wherever this
  # suite runs, so the jq-less half is unreachable without taking it away.
  njq="$TMP/scaf-nojq-bin"; rm -rf "$njq"; mkdir -p "$njq"
  nj_ok=1
  for c in bash cat find grep head ls mkdir rm sed sort tr; do
    p=$(command -v "$c" 2>/dev/null) && ln -s "$p" "$njq/$c" || nj_ok=0
  done
  if [ "$nj_ok" -ne 1 ]; then
    bad "could not build a jq-less PATH — the hand parser went untested"
  else
    # Anti-vacuity: every case below passes trivially if jq is still reachable.
    PATH="$njq" command -v jq >/dev/null 2>&1 \
      && bad "jq is still on the stripped PATH — the three cases below prove nothing" \
      || ok "the stripped PATH really has no jq, so the hand parser is what runs"

    sj="$TMP/scaf-nojq"; scmk "$sj" "$SC_LANGS"
    (cd "$sj" && PATH="$njq" bash "$SCAF" "Demo Project" >/dev/null 2>&1); rc=$?
    [ "$rc" -eq 0 ] && [ -f "$sj/docs/ca/index.md" ] \
      && grep -q 'Català' "$sj/docs/_navbar.md" 2>/dev/null \
      && ok "without jq, the hand parser still reads the declared list" \
      || bad "the jq-less parser lost WSS.docs.languages (rc=$rc)"

    # No docs block AT ALL, deliberately: that is the input where the hand
    # parser's `grep -o` matches nothing, exits 1, and — without the `|| true` —
    # takes the run down under pipefail with an empty screen and a bare status.
    scmk "$sj" '{"WSS":{"manifest":"workflow/v2"}}'
    (cd "$sj" && PATH="$njq" bash "$SCAF" "Demo Project" >/dev/null 2>&1); rc=$?
    [ "$rc" -eq 0 ] && [ -f "$sj/docs/index.md" ] && [ ! -f "$sj/docs/_navbar.md" ] \
      && ok "without jq, a manifest with no docs block is monolingual, not a dead run" \
      || bad "the jq-less run died or went multilingual where nothing was declared (rc=$rc)"

    scmk "$sj" '{"WSS":{"docs":{"languages":"en"}}}'
    out=$(cd "$sj" && PATH="$njq" bash "$SCAF" "Demo Project" 2>&1); rc=$?
    [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'is not a non-empty array of non-empty strings' \
      && [ ! -e "$sj/docs" ] \
      && ok "without jq, a malformed list still exits 2 and creates nothing" \
      || bad "the jq-less parser let a malformed languages list through (rc=$rc)"
  fi
fi

# ------------------------------------------------------------ the lane-mode gate

head_ "Worktree-lane paragraphs are injected only where lane mode is on"

# lanes_named_() gates the worktree-lane paragraphs of an injected block. What it
# saves is small; what it could BREAK is not, which is why the OR is tested in
# both directions. A checkout carrying a selector while the manifest stays silent
# is a real lane — a worktree made by hand, or a manifest not yet amended — and
# the skills key their lane paths on the SELECTOR. Gating on the manifest alone
# would withhold the lane instructions from the one tree that actually needs them.
lg=$(mktemp -d)
mklane() { # dir, manifest-json, [selector]
  mkdir -p "$lg/$1/.claude/skills/plan" "$lg/$1/.claude/skills/wrap"
  : > "$lg/$1/.claude/skills/plan/SKILL.md"
  : > "$lg/$1/.claude/skills/wrap/SKILL.md"
  printf '%s\n' "$2" > "$lg/$1/.claude/WSS.WORKFLOW.json"
  [ -n "${3:-}" ] && printf '%s\n' "$3" > "$lg/$1/.claude/WSS.LANE"
  return 0
}
_named='{"WSS":{"branch":{"integration":"dev"},"lanes":{"named":{"api":{"scope":["api/**"]}}}}}'
_bare='{"WSS":{"branch":{"integration":"dev"}}}'
mklane off      "$_bare"
mklane named    "$_named"
mklane selector "$_bare"  api
mklane both     "$_named" api
mklane empty    '{"WSS":{"lanes":{"named":{},"exclusive":["a/**"]}}}'
mklane broken   'not json at all'

lanebullet() { run --wss-plan "$lg/$1" | grep -q 'WSS.LANE` FIRST'; }

lanebullet off \
  && bad "the lane paragraph was injected into a project with no lanes at all" \
  || ok "no lanes: the worktree-lane paragraph is not injected"
lanebullet named \
  && ok "a declared WSS.lanes.named injects the paragraph" \
  || bad "a project declaring named lanes lost its lane paragraph"
lanebullet selector \
  && ok "a selector alone injects it, even with the manifest silent" \
  || bad "a .claude/WSS.LANE checkout lost its lane paragraph — the OR is broken"
lanebullet both \
  && ok "both signals present injects it" \
  || bad "a fully declared lane lost its lane paragraph"

# `"named": {}` is what a project that has retired its lanes is left with, so
# length>0 rather than mere presence is what makes that read as off.
lanebullet empty \
  && bad "an empty named map read as lane mode ON" \
  || ok "an empty named map is off, not on"

# A gate that crashes on bad data would take every flag with it.
run --wss-plan "$lg/broken" | grep -q 'included the `--wss-plan` flag' \
  && ok "a malformed manifest still fires the flag" \
  || bad "a malformed manifest broke the flag through the lane gate"

# The gate must never reach --wss-wrap's landing rules. Since the worktree
# machinery moved into skills/wrap/references/WSS.LANES.md — read only under
# lane mode — this block is the ONLY unconditional statement of the no-force
# refspec left anywhere in wrap's path. Gating it would leave a force-push guard
# that appears exactly where it is least needed.
for _m in off named; do
  run --wss-wrap "$lg/$_m" | grep -q 'NO leading `+`' \
    && ok "[$_m] --wss-wrap states the no-leading-plus rule unconditionally" \
    || bad "[$_m] --wss-wrap lost the no-force rule to the lane gate"
done
rm -rf "$lg"

# -------------------------------------------------------- wss-remove-lanes.sh

head_ "wss-remove-lanes.sh removes signals, never a record"

RL="$_root/wss/scripts/wss-remove-lanes.sh"
if [ ! -x "$RL" ]; then
  bad "wss-remove-lanes.sh missing or not executable at $RL"
else
  # --help prints the header comment block, and the block is found rather than
  # hardcoded as a line range. A range fails this in both directions: too short
  # and the help stops before the last header line, too long and `set -euo
  # pipefail` and the code below it spill into the help text. The expected last
  # line is derived here by a different route than the script uses, so this
  # checks the contract rather than re-running the implementation.
  rl_end=$(tail -n +2 "$RL" | grep -n -m1 -v '^#' | cut -d: -f1)
  rl_last=$(tail -n +2 "$RL" | head -n $((rl_end - 1)) | tail -1 | sed 's/^# \{0,1\}//')
  rl_help=$(bash "$RL" --help 2>/dev/null)
  [ -n "$rl_last" ] && [ "$(printf '%s\n' "$rl_help" | tail -1)" = "$rl_last" ] \
    && ! printf '%s\n' "$rl_help" | grep -q 'set -euo pipefail' \
    && ok "--help ends at the last header comment and never spills into the code" \
    || bad "--help does not end at the last header line, or leaked the code below it"

  rl=$(mktemp -d)
  mkrl() {
    rm -rf "$rl/proj"; mkdir -p "$rl/proj/.claude" "$rl/proj/docs"
    git -C "$rl/proj" init -q .
    git -C "$rl/proj" config user.email t@t
    git -C "$rl/proj" config user.name t
    printf '%s\n' '{"WSS":{"lanes":{"exclusive":["db/schema.prisma"],"serialize":["src/lib/**"],
      "generated":["src/gen/**"],"conflicts":"WSS.LANE.CONFLICTS.md",
      "named":{"api":{"records":{"todo":"WSS.TODO.api.md"},"transfer":"docs/WSS.TRANSFER.api.md"}}}}}' \
      > "$rl/proj/.claude/WSS.WORKFLOW.json"
    printf 'api\n' > "$rl/proj/.claude/WSS.LANE"
    printf '# Backlog\n\n- [ ] a real unfinished task\n' > "$rl/proj/WSS.TODO.api.md"
    : > "$rl/proj/docs/WSS.TRANSFER.api.md"
    git -C "$rl/proj" add -A >/dev/null 2>&1
    git -C "$rl/proj" commit -qm init >/dev/null 2>&1
  }
  MF="$rl/proj/.claude/WSS.WORKFLOW.json"

  mkrl
  bash "$RL" --dir "$rl/proj" >/dev/null 2>&1
  [ -f "$rl/proj/.claude/WSS.LANE" ] && jq -e '.WSS.lanes.named' "$MF" >/dev/null 2>&1 \
    && ok "dry run changes nothing" \
    || bad "wss-remove-lanes.sh wrote without --write"

  # Turning the mode off orphans rather than deletes, so a lane file still
  # holding a backlog item is the one thing that must stop the write: nothing
  # would ever read it again.
  bash "$RL" --write --dir "$rl/proj" >/dev/null 2>&1
  [ $? -ne 0 ] && [ -f "$rl/proj/.claude/WSS.LANE" ] \
    && ok "--write refuses while a lane file still holds content" \
    || bad "--write proceeded over a lane record with content"

  bash "$RL" --write --allow-orphans --dir "$rl/proj" >/dev/null 2>&1
  [ -f "$rl/proj/.claude/WSS.LANE" ] \
    && bad "the selector survived --allow-orphans" \
    || ok "--allow-orphans removes the .claude/WSS.LANE selector"
  jq -e '.WSS.lanes.named' "$MF" >/dev/null 2>&1 \
    && bad "WSS.lanes.named survived the write" \
    || ok "WSS.lanes.named is dropped from the manifest"
  jq -e '.WSS.lanes.conflicts' "$MF" >/dev/null 2>&1 \
    && bad "WSS.lanes.conflicts survived the write" \
    || ok "WSS.lanes.conflicts is dropped from the manifest"

  # THE reason this script exists. exclusive/serialize/generated share a prefix
  # with the worktree machinery and are not it: they drive --wss-start's batch
  # partitioning inside ONE checkout and work with no worktrees at all. Deleting
  # the lanes block wholesale reads as tidying while removing the guard that
  # stops two parallel agents writing one schema.
  jq -e '(.WSS.lanes.exclusive|length)==1 and (.WSS.lanes.serialize|length)==1
         and (.WSS.lanes.generated|length)==1' "$MF" >/dev/null 2>&1 \
    && ok "the collision paths survive — they are not worktree machinery" \
    || bad "wss-remove-lanes.sh deleted the in-checkout collision paths"

  [ -f "$rl/proj/WSS.TODO.api.md" ] && grep -q 'a real unfinished task' "$rl/proj/WSS.TODO.api.md" \
    && ok "the lane record is left on disk, content intact, under every flag" \
    || bad "a lane record was deleted or truncated"

  # git is the only route back from the rewrite, so a manifest git could not
  # restore is refused rather than backed up to a .bak nobody prunes.
  mkrl
  jq '.WSS.branch={"integration":"dev"}' "$MF" > "$MF.tmp" && mv "$MF.tmp" "$MF"
  bash "$RL" --write --allow-orphans --dir "$rl/proj" >/dev/null 2>&1
  [ $? -ne 0 ] && jq -e '.WSS.lanes.named' "$MF" >/dev/null 2>&1 \
    && ok "an uncommitted manifest is refused, so the rewrite stays revertible" \
    || bad "rewrote a manifest whose previous state git could not restore"

  mkdir -p "$rl/already/.claude"
  printf '%s\n' '{"WSS":{"lanes":{"exclusive":["a/**"]}}}' > "$rl/already/.claude/WSS.WORKFLOW.json"
  bash "$RL" --dir "$rl/already" >/dev/null 2>&1 \
    && ok "a project already off exits 0 rather than erroring" \
    || bad "a project with no lanes exited non-zero"
  rm -rf "$rl"
fi


# -------------------------------------------------------- wss-append-only.sh

head_ "An append-only record loses no line, and the set comes from the tag"

AO="$_root/wss/scripts/wss-append-only.sh"
if [ ! -x "$AO" ]; then
  bad "wss-append-only.sh missing or not executable at $AO"
else
  ao_end=$(tail -n +2 "$AO" | grep -n -m1 -v '^#' | cut -d: -f1)
  ao_last=$(tail -n +2 "$AO" | head -n $((ao_end - 1)) | tail -1 | sed 's/^# \{0,1\}//')
  ao_help=$(bash "$AO" --help 2>/dev/null)
  [ -n "$ao_last" ] && [ "$(printf '%s\n' "$ao_help" | tail -1)" = "$ao_last" ] \
    && ! printf '%s\n' "$ao_help" | grep -q 'set -euo pipefail' \
    && ok "--help ends at the last header comment and never spills into the code" \
    || bad "--help does not end at the last header line, or leaked the code below it"

  ao=$(mktemp -d)
  P="$ao/proj"

  # Three entries, because the rule distinguishes the two boundary entries — the
  # draft still being written — from everything between them. A fixture with one
  # entry cannot tell the two apart and would pass a check that guards nothing.
  mkao() {
    rm -rf "$P"; mkdir -p "$P/.claude" "$P/docs"
    git -C "$P" init -q .
    git -C "$P" config user.email t@t
    git -C "$P" config user.name t
    printf '%s\n' '{"WSS":{"branch":{"publish":"main"},
      "record":{"decisions":"docs/D.md","todo":"T.md","decisionsIndex":"docs/IDX.md"},
      "recordMode":{"decisions":"log","todo":"register","decisionsIndex":"generated"}}}' \
      > "$P/.claude/WSS.WORKFLOW.json"
    cat > "$P/docs/D.md" <<'EOD'
# Decisions

Header prose, which describes the record now and is rewritten in place.
A second header line.

## 2026-01-01 — first

body a1
body a2

## 2026-01-02 — second

body b1
body b2

**Outcome:** logged
and the rest of the outcome block

## 2026-01-03 — third

body c1
body c2
EOD
    printf '# Backlog\n\n- [ ] one\n- [ ] two\n' > "$P/T.md"
    printf '# Index\n\n- L6 first\n- L11 second\n- L18 third\n' > "$P/docs/IDX.md"
    git -C "$P" add -A >/dev/null 2>&1
    git -C "$P" commit -qm init >/dev/null 2>&1
  }

  # Stage the worktree and report the check's exit status, nothing else.
  aorun() { git -C "$P" add -A >/dev/null 2>&1; bash "$AO" --dir "$P" >/dev/null 2>&1; }

  mkao
  aorun && ok "an unchanged tree passes" || bad "an unchanged tree failed"

  # THE assertion. Everything else here is a carve-out or a degenerate case;
  # this is the line the whole script exists to refuse, and it was proven by
  # deleting it from the real docs/WSS.DECISIONS.md before it was written down.
  mkao
  sed -i '/^body b1$/d' "$P/docs/D.md"
  aorun && bad "a deleted line inside an entry body PASSED — the guard is inert" \
        || ok "a deleted line inside an entry body fails"

  mkao
  sed -i '/^body b1$/s/.*/body b1, reflowed/' "$P/docs/D.md"
  aorun && bad "an entry body was rewritten in place and passed" \
        || ok "rewriting an entry body in place fails, reflow included"

  # The header is not one of the entries: it is the record's instructions and it
  # describes the record now. WSS.RECORD-CONTRACT.md, "A record's header is not
  # one of its entries."
  mkao
  sed -i '/^A second header line.$/d' "$P/docs/D.md"
  aorun && ok "a deletion above the first entry passes — the header is a register" \
        || bad "the header carve-out is missing; every header fix would be refused"

  # The one mutable field the contract's status table names — and it names it
  # PER RECORD, so a record that declares none does not get the exemption.
  mkao
  sed -i 's/^\*\*Outcome:\*\* logged$/**Outcome:** fixed this session/' "$P/docs/D.md"
  aorun && bad "an Outcome update passed in a record declaring no mutable field" \
        || ok "a record declaring no mutable field gets no Outcome exemption"

  # ...and the record that DOES declare one keeps it, so remediation stays
  # recordable. This pair asserted "in any entry" of any log until the guard was
  # scoped: it built the exemption without reference to which record it was
  # reading, while the contract's status-field table gives WSS.record.decisions
  # no mutable field at all. Absent declaration now means none.
  mkao
  sed -i 's/"decisions":"log"/"decisions":{"mode":"log","mutable":"outcome"}/' "$P/.claude/WSS.WORKFLOW.json"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm mutable >/dev/null 2>&1
  sed -i 's/^\*\*Outcome:\*\* logged$/**Outcome:** fixed this session/' "$P/docs/D.md"
  aorun && ok "a record declaring mutable:outcome may update an Outcome block" \
        || bad "mutable:outcome was declared and the update was still refused"

  # The draft at either end, rewritten. The changelog's unreleased entry becoming
  # a released one is this case, and it recurs at every release.
  mkao
  sed -i '/^body c2$/s/.*/body c2, still being written\nand a further line/' "$P/docs/D.md"
  aorun && ok "the last entry may be rewritten where the same hunk adds lines" \
        || bad "the draft entry allowance is missing; every release cut would be refused"

  # The draft is the entry at the record's DECLARED growing end, and only that
  # one. This pair read the other way until 2026-08-18 — it asserted that BOTH
  # ends were drafts, which was true when written, because nothing told the
  # guard which end grew and it had to allow either. The owner then ruled
  # direction a property of the record rather than an exemption in the guard:
  # add without modifying what is there, always at the same end, and prepend and
  # append become one rule. See the decision log's 2026-08-18 (twenty-fourth).
  #
  # With no declaration a record grows at the tail, so its FIRST entry is sealed.
  mkao
  sed -i '/^body a1$/s/.*/body a1, extended\nwith more/' "$P/docs/D.md"
  aorun && bad "the head entry was a draft under a tail-growing record — the sealed end is not sealed" \
        || ok "the sealed end refuses a rewrite; only the growing end is the draft"

  # ...and the very same mutation passes once the record declares it grows there.
  # This is the changelog's case: newest first, by the convention its readers
  # expect, declared rather than carved out.
  mkao
  sed -i 's/"decisions":"log"/"decisions":{"mode":"log","grows":"head"}/' "$P/.claude/WSS.WORKFLOW.json"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm decl >/dev/null 2>&1
  sed -i '/^body a1$/s/.*/body a1, extended\nwith more/' "$P/docs/D.md"
  aorun && ok "a head-growing record makes its FIRST entry the draft" \
        || bad "grows:head was declared and the head entry was still sealed"

  # ...and only where it is a rewrite. A hunk that only removes is an excision
  # wherever it lands, including in the draft.
  mkao
  sed -i '/^body c2$/d' "$P/docs/D.md"
  aorun && bad "a pure excision from the last entry passed" \
        || ok "a hunk that only deletes fails even in the draft entry"

  # THE SECOND assertion, and it was invisible until 2026-08-15. Everything above
  # judges DELETIONS, so history could be rewritten by ADDITION with no symptom:
  # a line smuggled into a settled entry's body adds one line, removes none, and
  # a --numstat predicate reports that green. Proven by opening the hole on the
  # real record before the fix was written, exactly as the deletion case above was.
  mkao
  sed -i '/^body b1$/a SMUGGLED INTO A SETTLED ENTRY' "$P/docs/D.md"
  aorun && bad "a line inserted into a settled entry body PASSED — addition rewrites history unchecked" \
        || ok "a line inserted into a settled entry body fails"

  # ...and the three places an insertion is legitimate, or the check above would
  # refuse every ordinary append. These are the controls: without them the
  # assertion could be satisfied by a guard that simply refuses all additions.
  mkao
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n' >> "$P/docs/D.md"
  aorun && ok "a whole new entry appended at the end passes — the ordinary case" \
        || bad "appending a new entry was refused; the log could never grow"

  mkao
  sed -i '/^body c1$/a a further line in the draft' "$P/docs/D.md"
  aorun && ok "an insertion into the last entry passes — the draft stays editable" \
        || bad "the draft exemption does not cover insertion, only rewriting"

  mkao
  sed -i '/^A second header line.$/a A third header line.' "$P/docs/D.md"
  aorun && ok "an insertion into the header passes — it is a register, not an entry" \
        || bad "the header carve-out covers deletion but not insertion"

  # Line counts are not the test. A rewrite that adds more than it removes still
  # loses an entry, and --numstat alone would report that green.
  mkao
  sed -i '/^## 2026-01-02 — second$/,/^and the rest of the outcome block$/d' "$P/docs/D.md"
  printf 'more\nand more\nand more again\nand still more\n' >> "$P/docs/D.md"
  aorun && bad "an entry disappeared while the file grew, and it passed" \
        || ok "a drop in the entry count fails however the line counts move"

  mkao
  git -C "$P" rm -q docs/D.md
  aorun && bad "a log record was deleted outright and passed" \
        || ok "deleting a log record fails"

  # Scope, both directions. The index is excluded by carrying `generated`, never
  # by its name — an exemption by name is a rule with a hole that nothing
  # re-examines — and a register is excluded by being a register.
  mkao
  sed -i '/^- L11 second$/d' "$P/docs/IDX.md"
  aorun && ok "the generated index is out of scope by its tag, not by its path" \
        || bad 'a record tagged generated was guarded as a log'

  mkao
  printf '# Backlog\n\n- [ ] rewritten wholesale\n' > "$P/T.md"
  aorun && ok "a register may be rewritten wholesale" \
        || bad "a register was guarded as a log"

  # Counting discipline, from the twenty-sixth decision entry: a parser that
  # stops matching must fail rather than report a clean run over an empty set.
  mkao
  jq '.WSS.recordMode.decisions = "register"' "$P/.claude/WSS.WORKFLOW.json" > "$ao/m" \
    && mv "$ao/m" "$P/.claude/WSS.WORKFLOW.json"
  aorun && bad "resolved no log record at all and reported success" \
        || ok "zero log records is a failure, not a clean run"

  mkao
  jq 'del(.WSS.record.decisions)' "$P/.claude/WSS.WORKFLOW.json" > "$ao/m" \
    && mv "$ao/m" "$P/.claude/WSS.WORKFLOW.json"
  aorun && bad "a log tag with no declared path passed" \
        || ok "a mode tagging a record WSS.record does not declare fails"

  # Absent WSS.recordMode inherits the contract's log set rather than guarding
  # nothing — the same fallback wss-doctor.sh warns about.
  mkao
  jq 'del(.WSS.recordMode)' "$P/.claude/WSS.WORKFLOW.json" > "$ao/m" \
    && mv "$ao/m" "$P/.claude/WSS.WORKFLOW.json"
  sed -i '/^body b1$/d' "$P/docs/D.md"
  aorun && bad "no WSS.recordMode meant no guard at all" \
        || ok "an absent WSS.recordMode inherits the contract's log set"

  # A record that MOVES is the deferred reorg's whole shape, and it is where a
  # path-driven check goes blind: a pathspec is applied before rename detection,
  # so the moved file reads as new and anything cut out of it travels free.
  mkao
  git -C "$P" mv docs/D.md docs/moved.md >/dev/null 2>&1
  jq '.WSS.record.decisions = "docs/moved.md"' "$P/.claude/WSS.WORKFLOW.json" > "$ao/m" \
    && mv "$ao/m" "$P/.claude/WSS.WORKFLOW.json"
  aorun && ok "a record that only moves passes" || bad "a pure rename was refused"

  mkao
  git -C "$P" mv docs/D.md docs/moved.md >/dev/null 2>&1
  jq '.WSS.record.decisions = "docs/moved.md"' "$P/.claude/WSS.WORKFLOW.json" > "$ao/m" \
    && mv "$ao/m" "$P/.claude/WSS.WORKFLOW.json"
  sed -i '/^body b1$/d' "$P/docs/moved.md"
  aorun && bad "a rename carried an excision through unseen" \
        || ok "a record cut down while moving still fails"

  mkdir -p "$ao/bare2"
  git -C "$ao/bare2" init -q . 2>/dev/null
  bash "$AO" --dir "$ao/bare2" >/dev/null 2>&1 \
    && ok "a directory with no manifest declares no record and exits 0" \
    || bad "a non-project directory was treated as a failure"

  # A range that cannot be computed — a force-push, a deleted branch, the
  # all-zero before-sha of a new branch — must not silently pass.
  mkao
  bash "$AO" --dir "$P" --base origin/nowhere >/dev/null 2>&1 \
    && bad "an unresolvable base passed" \
    || ok "an unresolvable base fails rather than passing over nothing"
  bash "$AO" --dir "$P" --range "$(printf '0%.0s' {1..40})..HEAD" >/dev/null 2>&1 \
    && bad "an all-zero before-sha passed" \
    || ok "an all-zero before-sha fails rather than passing over nothing"

  mkao
  git -C "$P" branch -q -m main
  git -C "$P" checkout -q -b work
  sed -i '/^body b1$/d' "$P/docs/D.md"
  git -C "$P" commit -qam "delete a line" >/dev/null 2>&1
  bash "$AO" --dir "$P" --base main >/dev/null 2>&1 \
    && bad "the range half missed a deletion the branch already committed" \
    || ok "the range half catches what was committed before any hook existed"

  # The install half. The hook lives in the git dir, so it is per-clone and
  # untracked by design; CI is what makes the rule enforcement rather than
  # advice.
  mkao
  bash "$AO" --dir "$P" --install-hook >/dev/null 2>&1
  hk="$P/.git/hooks/pre-commit"
  [ -x "$hk" ] && ok "--install-hook writes an executable pre-commit hook" \
                || bad "--install-hook did not write an executable hook"
  bash "$AO" --dir "$P" --install-hook >/dev/null 2>&1 \
    && ok "--install-hook is idempotent over its own hook" \
    || bad "re-running --install-hook over its own hook failed"
  printf '#!/bin/sh\necho someone elses hook\n' > "$hk"
  bash "$AO" --dir "$P" --install-hook >/dev/null 2>&1 \
    && bad "--install-hook overwrote a hook it did not write" \
    || ok "--install-hook refuses to clobber a foreign pre-commit hook"

  # End to end: the commit is what has to stop, not just the script's exit code.
  mkao
  bash "$AO" --dir "$P" --install-hook >/dev/null 2>&1
  sed -i '/^body b1$/d' "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "eats a line" >/dev/null 2>&1 \
    && bad "the hook is installed and the commit went through anyway" \
    || ok "the installed hook stops the commit itself"
  git -C "$P" reset -q --hard >/dev/null 2>&1
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "appends an entry" >/dev/null 2>&1 \
    && ok "an appended entry commits with the hook installed" \
    || bad "the hook blocked a plain append"

  # `--amend-base` was DELETED on 2026-08-16 and this asserts it is gone rather
  # than silently ignored. Measurement is why: it was never stricter than
  # `--staged` — its pre-image was `<sha>^`, and since the commit under
  # amendment only ever appends, a deletion inside content that commit itself
  # created had nothing to delete from and registered as a pure insertion,
  # which the draft clause exempts. An unknown argument must exit 2, not 0:
  # a flag that vanishes into a no-op is how a caller keeps "checking" nothing.
  mkao
  bash "$AO" --dir "$P" --amend-base HEAD >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && ok "--amend-base is refused as an unknown argument (rc 2), not silently accepted" \
        || bad "--amend-base returned rc $rc — expected 2; the flag is still parsed, or an unknown argument no longer exits 2"

  # The case that used to discriminate the two baselines, kept for `--staged`
  # alone — it is the one that matters now that `--staged` is the only baseline
  # any caller uses. "fourth" is genuinely MIDDLE: "fifth" was appended after it
  # in the same commit, so no first-or-last draft exemption is in play.
  mkao
  printf '\n## 2026-01-04 — fourth\n\nbody d1\nbody d2\n\n## 2026-01-05 — fifth\n\nbody e1\nbody e2\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "append fourth and fifth" >/dev/null 2>&1
  sed -i '/^body d1$/d' "$P/docs/D.md"
  aorun && bad "--staged missed a deletion inside a genuine middle entry" \
        || ok "--staged catches the deletion — HEAD already has 'fourth' in full, and it is not first or last there"

  # The pre-commit half of the amend guarantee. This held BEFORE the 2026-08-16
  # deletion too — git runs pre-commit on --amend — so it pins existing
  # behaviour rather than proving the change. The half that DID change is
  # asserted in the wss-commit-provenance.sh section below, against a clone
  # carrying the provenance hooks WITHOUT this one, which was the exposure.
  # It is end-to-end rather than a direct script call because the defect being
  # guarded lives in git's prepare-commit-msg argument contract, not in the
  # script: `--amend -m` and `--amend -F` arrive as SOURCE=message with an
  # EMPTY sha, which no unit-level call would have revealed.
  mkao
  printf '\n## 2026-01-04 — fourth\n\nbody d1\nbody d2\n\n## 2026-01-05 — fifth\n\nbody e1\nbody e2\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "append fourth and fifth" >/dev/null 2>&1
  bash "$AO" --dir "$P" --install-hook >/dev/null 2>&1
  sed -i '/^body d1$/d' "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -q --amend -m "amend that deletes from a settled entry" >/dev/null 2>&1 \
    && bad "an --amend -m deleting from a middle entry was allowed through" \
    || ok "an --amend -m deleting from a middle entry is refused"

  # Prepend a whole new entry at the top. The exemption applies to the
  # newly-grown end, so an insertion at the top that is the new entry's
  # own body (between its heading and the old first entry's heading) is
  # exempt — a control against reading this as a permission to insert
  # into a settled entry.
  mkao
  # `/re/i\`, not `1,/re/i\`. The range form inserts before EVERY line in the
  # range and GNU sed rejects the expression outright — it did, silently, from
  # the day this was written: the sed failed, nothing was prepended, and the
  # guard then ran against an UNMODIFIED file and passed. A control that asserts
  # nothing is worse than a missing one, because it reads as coverage.
  sed -i '/^## 2026-01-01/i\
## 2026-01-00 — zeroth\
\
body z1\
' "$P/docs/D.md"
  aorun && ok "a whole new entry prepended at the top passes — the ordinary case" \
        || bad "prepending a new entry was refused; the log could never grow upward"

  # The residual: append a new entry in one commit, then amend to edit
  # the previous entry's body while appending yet another entry past it.
  # The first append makes the previous entry no longer first/last; the
  # second append makes it middle. An edit to a middle entry inside the
  # same hunk as the append is never exempt — the append's smuggled
  # insertion into the old entry's body must fail.
  mkao
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "append fourth" >/dev/null 2>&1
  sed -i '/^body d1$/s/.*/body d1, quietly edited/' "$P/docs/D.md"
  printf '\n## 2026-01-05 — fifth\n\nbody e1\n' >> "$P/docs/D.md"
  aorun && bad "an amend that edits a demoted draft while appending past it PASSED — the guard is inert" \
        || ok "an amend that edits a demoted draft while appending past it fails"

  # Control: same setup but without the second append — fourth stays
  # genuinely last, and the identical edit to its body must pass, proving
  # the guard is the growth-aware exemption, not a blanket rejection of
  # fourth's body edits.
  mkao
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "append fourth" >/dev/null 2>&1
  sed -i '/^body d1$/s/.*/body d1, quietly edited/' "$P/docs/D.md"
  aorun && ok "the same edit passes when fourth stays genuinely last — the draft exemption itself is untouched" \
        || bad "editing a genuine last entry was refused when no growth happened"

  # Append and delete from a first entry. Growth at one end does not
  # loosen the excision (not rewrite) prohibition at the other.
  mkao
  sed -i '/^body a2$/d' "$P/docs/D.md"
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n' >> "$P/docs/D.md"
  aorun && bad "an excision from the first entry while appending PASSED — the guard is inert" \
        || ok "an excision from a non-last entry still fails even with growth at the far end"

  rm -rf "$ao"
fi


# -------------------------------------------------- wss-commit-provenance.sh

head_ "A record-touching commit declares which records and whose authority"

CP="$_root/wss/scripts/wss-commit-provenance.sh"
if [ ! -x "$CP" ]; then
  bad "wss-commit-provenance.sh missing or not executable at $CP"
else
  # Build fixtures with three entries, plus manifest and ownership matrix
  mkcp() {
    # docs/ is in this list because the record file below lives there: without
    # it the heredoc fails, nothing is staged, and the commit is refused for
    # being empty — which reads exactly like the guard rejecting a valid commit.
    rm -rf "$P"; mkdir -p "$P/.claude" "$P/wss/workflow" "$P/docs"
    git -C "$P" init -q .
    git -C "$P" config user.email t@t
    git -C "$P" config user.name t
    printf '%s\n' '{"WSS":{"record":{"decisions":"docs/D.md"}}}' \
      > "$P/.claude/WSS.WORKFLOW.json"
    cat > "$P/wss/workflow/WSS.OWNERSHIP.md" <<'EOW'
| Verb | Flag | Skill or procedure | Tier | Sole writer of | notes |
|---|---|---|---|---|---|
| approve | --wss-release | writers/WSS.RELEASE-WRITER.md | expert | WSS.record.decisions | — |
EOW
    cat > "$P/docs/D.md" <<'EOD'
# Decisions
## 2026-01-01 — first
body a1
## 2026-01-02 — second
body b1
## 2026-01-03 — third
body c1
EOD
    git -C "$P" add -A >/dev/null 2>&1
    git -C "$P" commit -qm "initial" >/dev/null 2>&1
  }

  cp_end=$(tail -n +2 "$CP" | grep -n -m1 -v '^#' | cut -d: -f1)
  cp_last=$(tail -n +2 "$CP" | head -n $((cp_end - 1)) | tail -1 | sed 's/^# \{0,1\}//')
  cp_help=$(bash "$CP" --help 2>/dev/null)
  [ -n "$cp_last" ] && [ "$(printf '%s\n' "$cp_help" | tail -1)" = "$cp_last" ] \
    && ! printf '%s\n' "$cp_help" | grep -q 'set -euo pipefail' \
    && ok "--help ends at the last header comment and never spills into the code" \
    || bad "--help does not end at the last header line, or leaked the code below it"

  cp=$(mktemp -d)
  P="$cp/proj"

  mkcp
  bash "$CP" --dir "$P" --install-hook >/dev/null 2>&1
  hk_prep="$P/.git/hooks/prepare-commit-msg"
  hk_commit="$P/.git/hooks/commit-msg"
  [ -x "$hk_prep" ] && [ -x "$hk_commit" ] && \
    ok "--install-hook writes executable prepare-commit-msg and commit-msg hooks" \
    || bad "--install-hook did not write executable hooks"
  bash "$CP" --dir "$P" --install-hook >/dev/null 2>&1 && \
    ok "--install-hook is idempotent over its own hooks" \
    || bad "re-running --install-hook over its own hooks failed"
  printf '#!/bin/sh\necho someone elses hook\n' > "$hk_prep"
  bash "$CP" --dir "$P" --install-hook >/dev/null 2>&1 && \
    bad "--install-hook overwrote a hook it did not write" \
    || ok "--install-hook refuses to clobber a foreign prepare-commit-msg hook"

  mkcp
  bash "$CP" --dir "$P" --install-hook >/dev/null 2>&1
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "appends an entry" >/dev/null 2>&1 && \
    ok "a record-touching commit carries the block when hooks are installed" \
    || bad "the commit was refused when it should have been allowed"

  # THE EXPOSURE CLOSED ON 2026-08-16, and the fixture is deliberately a clone
  # carrying the PROVENANCE hooks WITHOUT wss-append-only.sh's pre-commit hook —
  # the two are installed by different scripts and neither implies the other, so
  # this combination is a real clone shape rather than a contrived one. Until
  # 2026-08-16 `--emit` ran `--amend-base "$SHA"` behind
  # `[ "$SOURCE" = "commit" ] && [ -n "$SHA" ]`, and BOTH halves were wrong:
  # `--amend -m` arrives as SOURCE=message with an empty sha so the guard never
  # fired, and `--amend-base` was in any case more lenient than `--staged`.
  # Every commit shape now runs `--staged` unconditionally.
  #
  # The append-only script is copied IN because --emit resolves it under
  # ${CLAUDE_DIR:-.}, and an absent script makes the check silently skip — so
  # without this copy the assertion would pass while testing nothing.
  mkcp
  mkdir -p "$P/wss/scripts"
  cp "$_root/wss/scripts/wss-append-only.sh" "$P/wss/scripts/wss-append-only.sh"
  chmod +x "$P/wss/scripts/wss-append-only.sh"
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n\n## 2026-01-05 — fifth\n\nbody e1\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -qm "append fourth and fifth" >/dev/null 2>&1
  bash "$CP" --dir "$P" --install-hook >/dev/null 2>&1
  [ -e "$P/.git/hooks/pre-commit" ] \
    && bad "the provenance-only fixture grew a pre-commit hook — it no longer isolates the exposure" \
    || ok "the provenance-only fixture carries no pre-commit hook, so --emit is the only guard in play"
  sed -i '/^body d1$/d' "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  ( cd "$P" && git commit -q --amend -m "amend deleting from a settled entry" ) >/dev/null 2>&1 \
    && bad "a provenance-only clone let an --amend -m delete from a settled entry — the pre-2026-08-16 exposure is back" \
    || ok "a provenance-only clone refuses an --amend -m that deletes from a settled entry"

  # THE BLOCK MUST SIT ABOVE THE TRAILER PARAGRAPH. Git recognises trailers
  # only in the LAST paragraph, so a block appended after them silently
  # destroys every trailer in the message. wss-git-commit.sh verifies the
  # session trailer through %(trailers:key=...) and is the only sanctioned
  # route to a commit here, so that failure took the form of every record
  # commit being refused a push — with the trailer plainly visible in the
  # message text, which is what made it read as a verification bug rather
  # than a placement one. Both halves are asserted: what git PARSES, which is
  # what actually matters, and the textual ordering, which is what a reader
  # diagnosing it will look at.
  mkcp
  bash "$CP" --dir "$P" --install-hook >/dev/null 2>&1
  printf '\n## 2026-01-04 — fourth\n\nbody d1\n' >> "$P/docs/D.md"
  git -C "$P" add -A >/dev/null 2>&1
  git -C "$P" commit -q -F - >/dev/null 2>&1 <<'EOCP'
appends an entry with a trailer

A body paragraph, so the trailer paragraph is genuinely the last one and
not also the subject.

Claude-Session: deadbeef
EOCP
  cp_tr=$(git -C "$P" log -1 --format='%(trailers:key=Claude-Session,valueonly)' 2>/dev/null)
  [ "$cp_tr" = "deadbeef" ] \
    && ok "the block leaves the session trailer parseable, so it is placed before the trailer paragraph" \
    || bad "the block broke the session trailer — git parsed '$cp_tr', so the block landed after the trailer paragraph"
  git -C "$P" log -1 --format='%B' \
    | awk '/^WSS-RECORDS-END$/ { seen = 1 } /^Claude-Session:/ { if (seen) hit = 1 } END { exit !hit }' \
    && ok "and the block's END marker precedes the trailer line in the message text" \
    || bad "the block's END marker does not precede the trailer line"

  rm -rf "$cp"
fi


# --------------------------------------------------------- the dispatch ladder

head_ "The dispatch ladder is the one place the tier rule is stated"

# wss/workflow/WSS.DISPATCH-LADDER.md is the single source of truth for
# model-tier and dispatch decisions; four callers had their own tier prose
# deleted and now cite it instead. Two ways that consolidation rots: the
# table itself losing its shape, and a citing surface losing its link or
# regrowing the rule it was supposed to only point at. Every check below
# takes a root dir, so it can be proven red against a broken COPY without
# touching the real files, which are outside this file's ownership.

dl=$(mktemp -d)
mkdir -p "$dl/real/wss"
cp -R "$_root/wss/workflow" "$dl/real/wss/workflow"
cp -R "$_root/wss/tests"    "$dl/real/wss/tests"
cp -R "$_root/skills"       "$dl/real/skills"

# Copy the real tree again, run a mutator over the copy, hand back its root.
dl_break() { local b; b="$dl/broke-$RANDOM$RANDOM"; cp -R "$dl/real" "$b"; "$1" "$b"; printf '%s' "$b"; }

LADDER_REL="wss/workflow/WSS.DISPATCH-LADDER.md"
START_REL="skills/start/SKILL.md"
HEALTHCHECK_REL="skills/health-check/SKILL.md"
AUDITPASS_REL="wss/tests/WSS.AUDIT-PASS.md"
TOKENECON_REL="wss/tests/WSS.TOKEN-ECONOMY.md"

# --- 1. the table's shape: five rungs, in order, Design last, three columns set

ladder_table_rows() { # root -> the ladder's header/sep/5 data lines, in file order
  local f="$1/$LADDER_REL"
  [ -f "$f" ] || return 1
  awk '
    /^## The ladder/ { insec=1; next }
    insec && /^## / { exit }
    insec && /^\|/ { print }
  ' "$f"
}

ladder_rung_names() { ladder_table_rows "$1" | tail -n +3 \
  | grep -oE '^\| \*\*[A-Za-z]+\*\*' | sed -E 's/^\| \*\*//; s/\*\*$//'; }

ladder_order_ok() { # root — the five rungs, in this order, Design last
  [ "$(ladder_rung_names "$1" | tr '\n' ' ' | sed 's/ $//')" \
    = "Keep Survey Execute Analyze Design" ]
}

ladder_columns_ok() { # root — the header names Rung/Matches/Where/Tier/Effort,
  local rows header bad             # and every data row sets all five
  rows=$(ladder_table_rows "$1") || return 1
  header=$(printf '%s\n' "$rows" | head -1 | tr -s ' ')
  [ "$header" = "| Rung | Matches when | Where | Tier | Effort |" ] || return 1
  bad=$(printf '%s\n' "$rows" | tail -n +3 | awk -F'|' 'NF != 7')
  [ -z "$bad" ]
}

ladder_order_ok "$dl/real" \
  && ok "the ladder's five rungs are present, in order, with Design last" \
  || bad "the ladder's rung order is not Keep, Survey, Execute, Analyze, Design"

mut_reorder_design() { # root — move Design's row above Keep's, breaking order and "last"
  awk '
    /^## The ladder/ { print; insec=1; next }
    insec && /^## / { insec=0 }
    insec && /^\| \*\*Design\*\*/ { design=$0; next }
    insec && /^\| \*\*Keep\*\*/ { print design; print; next }
    { print }
  ' "$1/$LADDER_REL" > "$1/$LADDER_REL.new" && mv "$1/$LADDER_REL.new" "$1/$LADDER_REL"
}
broke=$(dl_break mut_reorder_design)
ladder_order_ok "$broke" \
  && bad "moving Design off the bottom of a COPY was not caught" \
  || ok "moving Design off the bottom of a COPY is caught"

ladder_columns_ok "$dl/real" \
  && ok "every rung sets where, tier and effort — no column is missing" \
  || bad "the ladder table is missing a column somewhere"

mut_drop_column() { # root — collapse Execute's Tier cell into Where, dropping a column
  sed -i 's/| \*\*Execute\*\* | \(.*\) | agent | bottom | low |/| **Execute** | \1 | agent | low |/' \
    "$1/$LADDER_REL"
}
broke=$(dl_break mut_drop_column)
ladder_columns_ok "$broke" \
  && bad "dropping Execute's Tier column in a COPY was not caught" \
  || ok "dropping Execute's Tier column in a COPY is caught"

# --- 2. every citing surface still points at a file that actually exists

citation_targets() { grep -oE '\]\([^)]*DISPATCH-LADDER\.md\)' "$1" 2>/dev/null \
  | sed -E 's/^\]\(//; s/\)$//'; }

citation_resolves() { # citing-file, link-target — resolves relative to the file's own dir
  local dir target
  dir=$(dirname "$1")
  target=$(cd "$dir" 2>/dev/null && realpath -m -- "$2" 2>/dev/null)
  [ -n "$target" ] && [ -f "$target" ]
}

surface_cites_ladder() { # root, surface-rel-path — at least one link, every link resolves
  local f="$1/$2" links link n=0
  links=$(citation_targets "$f")
  [ -n "$links" ] || return 1
  while IFS= read -r link; do
    citation_resolves "$f" "$link" || return 1
    n=$((n + 1))
  done <<< "$links"
  [ "$n" -gt 0 ]
}

surface_cites_ladder "$dl/real" "$START_REL" \
  && ok "skills/start/SKILL.md cites the ladder with a link that resolves" \
  || bad "skills/start/SKILL.md's ladder citation is missing or dead"

mut_break_start_link() { sed -i \
  's#(\.\./\.\./wss/workflow/WSS\.DISPATCH-LADDER\.md)#(../../wss/workflow/WSS.NO-SUCH-LADDER.md)#g' \
  "$1/$START_REL"; }
broke=$(dl_break mut_break_start_link)
surface_cites_ladder "$broke" "$START_REL" \
  && bad "retargeting start's ladder link at a missing file in a COPY was not caught" \
  || ok "retargeting start's ladder link at a missing file in a COPY is caught"

start_citation_count() { citation_targets "$1/$START_REL" | grep -c .; }
start_cites_real=$(start_citation_count "$dl/real")
[ "$start_cites_real" -ge 2 ] \
  && ok "skills/start/SKILL.md cites the ladder at least twice — Phase 3 and Phase 4" \
  || bad "skills/start/SKILL.md's second ladder citation is missing"

# Compare the mutated count against the real one rather than against a fixed
# threshold. The fixed `-ge 2` went vacuous on 2026-08-13, when the
# undeclared-role fallback added a THIRD ladder citation: dropping one still
# left two, so the mutation stopped proving anything while still reporting a
# pass. A guard that cannot fail is worse than no guard, and this one was one
# citation away from that for as long as the count sat at exactly two.
mut_drop_one_start_citation() { sed -i '/Its rung from \[the dispatch ladder\]/d' "$1/$START_REL"; }
broke=$(dl_break mut_drop_one_start_citation)
[ "$(start_citation_count "$broke")" -lt "$start_cites_real" ] \
  && ok "deleting one of start's ladder citations in a COPY is caught" \
  || bad "deleting one of start's ladder citations in a COPY was not caught"

surface_cites_ladder "$dl/real" "$HEALTHCHECK_REL" \
  && ok "skills/health-check/SKILL.md cites the ladder with a link that resolves" \
  || bad "skills/health-check/SKILL.md's ladder citation is missing or dead"

mut_delete_healthcheck_citation() { sed -i '/dispatch ladder.*DISPATCH-LADDER\.md/d' "$1/$HEALTHCHECK_REL"; }
broke=$(dl_break mut_delete_healthcheck_citation)
surface_cites_ladder "$broke" "$HEALTHCHECK_REL" \
  && bad "deleting health-check's ladder citation in a COPY was not caught" \
  || ok "deleting health-check's ladder citation in a COPY is caught"

surface_cites_ladder "$dl/real" "$AUDITPASS_REL" \
  && ok "wss/tests/WSS.AUDIT-PASS.md cites the ladder with a link that resolves" \
  || bad "wss/tests/WSS.AUDIT-PASS.md's ladder citation is missing or dead"

mut_deepen_auditpass_link() { sed -i \
  's#(\.\./workflow/WSS\.DISPATCH-LADDER\.md)#(../../workflow/WSS.DISPATCH-LADDER.md)#' "$1/$AUDITPASS_REL"; }
broke=$(dl_break mut_deepen_auditpass_link)
surface_cites_ladder "$broke" "$AUDITPASS_REL" \
  && bad "breaking WSS.AUDIT-PASS.md's relative link depth in a COPY was not caught" \
  || ok "breaking WSS.AUDIT-PASS.md's relative link depth in a COPY is caught"

surface_cites_ladder "$dl/real" "$TOKENECON_REL" \
  && ok "wss/tests/WSS.TOKEN-ECONOMY.md cites the ladder with a link that resolves" \
  || bad "wss/tests/WSS.TOKEN-ECONOMY.md's ladder citation is missing or dead"

mut_typo_tokeneconomy_link() { sed -i 's/DISPATCH-LADDER\.md/DISPATCH-LADER.md/' "$1/$TOKENECON_REL"; }
broke=$(dl_break mut_typo_tokeneconomy_link)
surface_cites_ladder "$broke" "$TOKENECON_REL" \
  && bad "typoing WSS.TOKEN-ECONOMY.md's ladder filename in a COPY was not caught" \
  || ok "typoing WSS.TOKEN-ECONOMY.md's ladder filename in a COPY is caught"

# --- 3. no surface grew its own tier rule back (the anti-fifth-rule guard)

# wss/tests/WSS.TOKEN-ECONOMY.md's lens 13 records a probe MEASUREMENT
# (three tier launches, tokens counted, with its own recompute command) —
# WSS.RECORD-CONTRACT.md's "a figure carries what recomputes it" sanctions
# that passage by name, so it is stripped before this file is checked.
strip_probe_passage() { awk '
  /Measured by three probes/ { skip=1 }
  skip { if (/brief-field list/) skip=0; next }
  { print }
' "$1"; }

surface_regrowth_free() { # root, surface-rel-path — no rule-stating phrase reappears
  local f="$1/$2" content
  if [ "$2" = "$TOKENECON_REL" ]; then content=$(strip_probe_passage "$f")
  else content=$(cat "$f" 2>/dev/null); fi
  ! printf '%s' "$content" | grep -qF \
    -e "highest model tier" -e "smallest capable model tier" \
    -e "standard tier is the default" -e "model: 'haiku'" -e "model: 'sonnet'"
}

surface_regrowth_free "$dl/real" "$START_REL" \
  && ok "skills/start/SKILL.md states no tier rule of its own" \
  || bad "skills/start/SKILL.md has a tier-rule phrase outside the ladder"

mut_regrow_start() { printf '\n\nUse the highest model tier for this phase.\n' >> "$1/$START_REL"; }
broke=$(dl_break mut_regrow_start)
surface_regrowth_free "$broke" "$START_REL" \
  && bad "regrowing 'highest model tier' in a COPY of start was not caught" \
  || ok "regrowing 'highest model tier' in a COPY of start is caught"

surface_regrowth_free "$dl/real" "$HEALTHCHECK_REL" \
  && ok "skills/health-check/SKILL.md states no tier rule of its own" \
  || bad "skills/health-check/SKILL.md has a tier-rule phrase outside the ladder"

mut_regrow_healthcheck() {
  printf '\n\nThe smallest capable model tier runs each auditor.\n' >> "$1/$HEALTHCHECK_REL"
}
broke=$(dl_break mut_regrow_healthcheck)

# Check that regrowth in SKILL.md or references is caught. wss-stocktake had
# a references/ dir (the audit lenses); health-check, its successor, does
# not as of the retirement (2026-08-19, eighty-second decision) — the glob
# below matches nothing there and the loop's `[ -f ]` guard skips it, same as
# it always did for a skill with no references/ dir.
hc_regrowth_free=0
for hc_c in "$broke/skills/health-check/SKILL.md" "$broke/skills/health-check"/references/*.md; do
  [ -f "$hc_c" ] || continue
  content=$(cat "$hc_c" 2>/dev/null)
  if printf '%s' "$content" | grep -qF \
    -e "highest model tier" -e "smallest capable model tier" \
    -e "standard tier is the default" -e "model: 'haiku'" -e "model: 'sonnet'"; then
    hc_regrowth_free=1
    break
  fi
done

[ "$hc_regrowth_free" -eq 0 ] \
  && bad "regrowing 'smallest capable model tier' in a COPY of health-check was not caught" \
  || ok "regrowing 'smallest capable model tier' in a COPY of health-check is caught"

surface_regrowth_free "$dl/real" "$AUDITPASS_REL" \
  && ok "wss/tests/WSS.AUDIT-PASS.md states no tier rule of its own" \
  || bad "wss/tests/WSS.AUDIT-PASS.md has a tier-rule phrase outside the ladder"

mut_regrow_auditpass() {
  printf '\n\nThe standard tier is the default when nothing else matches.\n' >> "$1/$AUDITPASS_REL"
}
broke=$(dl_break mut_regrow_auditpass)
surface_regrowth_free "$broke" "$AUDITPASS_REL" \
  && bad "regrowing 'standard tier is the default' in a COPY of WSS.AUDIT-PASS.md was not caught" \
  || ok "regrowing 'standard tier is the default' in a COPY of WSS.AUDIT-PASS.md is caught"

surface_regrowth_free "$dl/real" "$TOKENECON_REL" \
  && ok "wss/tests/WSS.TOKEN-ECONOMY.md states no tier rule outside the probe passage" \
  || bad "wss/tests/WSS.TOKEN-ECONOMY.md has a tier-rule phrase outside the ladder and the probe"

mut_regrow_tokeneconomy() { # root — restate a mapping OUTSIDE the sanctioned probe passage
  printf '\n\nAs a rule, model: '"'"'haiku'"'"' is what a Survey rung launch overrides to.\n' \
    >> "$1/$TOKENECON_REL"
}
broke=$(dl_break mut_regrow_tokeneconomy)
surface_regrowth_free "$broke" "$TOKENECON_REL" \
  && bad "regrowing a model: 'haiku' mapping in a COPY of WSS.TOKEN-ECONOMY.md was not caught" \
  || ok "regrowing a model: 'haiku' mapping in a COPY of WSS.TOKEN-ECONOMY.md is caught"

rm -rf "$dl"

# ------------------------------------------------------ wrap wss-wrap-status.sh

head_ "wss-wrap-status.sh replaces --wss-wrap step 6's read and step 7 entirely"

# A single read-only call: dirty files, unpushed commits, ahead-of-publish, the
# four record counts, open-decision titles, the roadmap position, and the sweep
# line. Its one write is its own .claude/WSS.ALWAYS-ON-STAMP.json — it never
# stages, commits, pushes or advances anything else — so unlike
# wss-git-commit.sh below every fixture here is still disposable: the one file
# it writes lands inside the fixture itself, not a real project's state.
WRAPSTATUS="$_root/skills/wrap/assets/wss-wrap-status.sh"
if [ ! -f "$WRAPSTATUS" ]; then
  bad "wss-wrap-status.sh missing at $WRAPSTATUS"
else
  wrun() { (cd "$1" && bash "$WRAPSTATUS" 2>&1); }

  ws1="$TMP/wrapstat-basic"; rm -rf "$ws1"; mkdir -p "$ws1/wss/records"
  git init -q "$ws1" 2>/dev/null
  git -C "$ws1" config user.email t@test; git -C "$ws1" config user.name t
  git -C "$ws1" config commit.gpgsign false
  printf '# Backlog\n\n- [ ] **One.**\n- [ ] **Two.**\n- [x] **Done.**\n' > "$ws1/wss/records/WSS.TODO.md"
  printf '# Open decisions\n\n## Whether to X\n\n## Whether to Y\n' > "$ws1/wss/records/WSS.OPEN-DECISIONS.md"
  printf '# Roadmap\n\n## M1 — first\n\n- [ ] **Block A.**\n\n## M2 — second\n' > "$ws1/wss/records/WSS.ROADMAP.md"
  printf '# Release list\n\n## `0.1.0` — shipped it — *completed*\n\n## `0.2.0` — next\n' > "$ws1/wss/records/WSS.RELEASES.md"
  docommit "$ws1"

  out=$(wrun "$ws1"); rc=$?
  [ "$rc" -eq 0 ] && ok "always exits 0, whatever it finds — a report, never a gate" \
    || bad "a clean fixture exited $rc, not 0"

  miss=""
  for blk in "== wss-wrap-status ==" "== tree ==" "== counts ==" \
             "== open-decision titles ==" "== roadmap ==" "== sweep =="; do
    case $out in *"$blk"*) ;; *) miss="$miss [$blk]" ;; esac
  done
  [ -z "$miss" ] && ok "all six report blocks are present" \
    || bad "missing report block(s):$miss"

  case $out in
    *"note: no manifest — conventional fallback names in use"*)
      ok "no manifest is announced, not papered over" ;;
    *) bad "the no-manifest note is gone" ;;
  esac
  case $out in
    *"lane: none"*) ok "no lane selector reads as 'lane: none'" ;;
    *) bad "the lane line is gone or wrong with no selector" ;;
  esac
  case $out in
    *"todo=2 decisions=2 roadmap-open=1 milestones=1"*)
      ok "the counts line reports todo/decisions/roadmap-open/milestones together" ;;
    *) bad "the counts line drifted: $(printf '%s' "$out" | grep '^todo=')" ;;
  esac
  case $out in
    *"goal-closed: none"*)
      ok "no goal closed reads 'goal-closed: none', not blank" ;;
    *) bad "the goal-closed line is gone when the current goal is the first one"
  esac

  # goal-closed names the PREVIOUS goal only once it closes — the whole reason
  # this line exists is to tell a session it can strike a goal off the roadmap
  # in the same wrap that closes it.
  printf '# Roadmap\n\n## M1 — first\n\n- [x] **Block A.**\n\n## M2 — second\n\n- [ ] **Block B.**\n' \
    > "$ws1/wss/records/WSS.ROADMAP.md"
  docommit "$ws1"
  out=$(wrun "$ws1")
  case $out in
    *"goal-closed: M1 — first"*)
      ok "the goal that just closed is named once its blocks are all checked" ;;
    *) bad "a fully-closed goal was not reported: $(printf '%s' "$out" | grep 'goal-closed')" ;;
  esac
  # restore for the fixtures below
  printf '# Roadmap\n\n## M1 — first\n\n- [ ] **Block A.**\n\n## M2 — second\n' > "$ws1/wss/records/WSS.ROADMAP.md"
  docommit "$ws1"

  # end-of-milestones marker test: a release list with completed milestone and
  # explicit end-of-milestones marker should count as 0 open milestones and
  # report the marker as declared
  ws2="$TMP/wrapstat-end-of-milestones"; rm -rf "$ws2"; mkdir -p "$ws2/wss/records"
  git init -q "$ws2" 2>/dev/null
  git -C "$ws2" config user.email t@test; git -C "$ws2" config user.name t
  git -C "$ws2" config commit.gpgsign false
  printf '# Backlog\n\n- [ ] **One.**\n- [ ] **Two.**\n- [x] **Done.**\n' > "$ws2/wss/records/WSS.TODO.md"
  printf '# Open decisions\n\n## Whether to X\n\n## Whether to Y\n' > "$ws2/wss/records/WSS.OPEN-DECISIONS.md"
  printf '# Roadmap\n\n## M1 — first\n\n- [ ] **Block A.**\n\n## M2 — second\n' > "$ws2/wss/records/WSS.ROADMAP.md"
  printf '# Release list\n\n## `0.1.0` — shipped it — *completed*\n\n## After `0.1.0` — maintenance — *end of milestones*\n' > "$ws2/wss/records/WSS.RELEASES.md"
  docommit "$ws2"
  out=$(wrun "$ws2"); rc=$?
  [ "$rc" -eq 0 ] && ok "end-of-milestones case exits 0" \
    || bad "end-of-milestones case exited $rc, not 0"
  case $out in
    *"milestones=0 (end-of-milestones declared)"*)
      ok "end-of-milestones declared is reported when marker is present" ;;
    *) bad "end-of-milestones not reported: $(printf '%s' "$out" | grep '^milestones=')" ;;
  esac

  # Record paths resolve through the manifest, and a `.claude/WSS.LANE`
  # selector overrides them per WSS.MANIFEST.json's lane contract — the same
  # resolution rule record and wss-probe.sh already follow.
  ws3="$TMP/wrapstat-lane"; rm -rf "$ws3"; mkdir -p "$ws3/.claude"
  git init -q "$ws3" 2>/dev/null
  git -C "$ws3" config user.email t@test; git -C "$ws3" config user.name t
  git -C "$ws3" config commit.gpgsign false
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md"},"lanes":{"named":{"alpha":{"records":{"todo":"WSS.TODO.ALPHA.md"}}}}}}\n' \
    > "$ws3/.claude/WSS.WORKFLOW.json"
  printf '# Backlog\n\n- [ ] **Base one.**\n' > "$ws3/WSS.TODO.md"
  printf '# Backlog alpha\n\n- [ ] **Alpha one.**\n- [ ] **Alpha two.**\n' > "$ws3/WSS.TODO.ALPHA.md"
  docommit "$ws3"
  out=$(wrun "$ws3")
  case $out in
    *"todo=1"*) ok "with no lane selector, the base manifest path applies" ;;
    *) bad "the base todo path was not used: $(printf '%s' "$out" | grep '^todo=')" ;;
  esac
  printf 'alpha\n' > "$ws3/.claude/WSS.LANE"
  out=$(wrun "$ws3")
  case $out in
    *"lane: alpha"*) ok "an active lane selector is announced by name" ;;
    *) bad "the lane line did not name the active selector" ;;
  esac
  case $out in
    *"todo=2"*)
      ok "a lane's WSS.lanes.named.<lane>.records override redirects the record it names" ;;
    *) bad "the lane override was not honoured: $(printf '%s' "$out" | grep '^todo=')" ;;
  esac

  # The offline guard: a provider-backed backlog whose `gh` call fails must be
  # reported as NOT COUNTED, never folded into a zero that reads as a clean
  # backlog. Proven by pointing `gh` at a script that always fails, first on
  # PATH.
  ws4="$TMP/wrapstat-provider"; rm -rf "$ws4"; mkdir -p "$ws4/.claude"
  git init -q "$ws4" 2>/dev/null
  git -C "$ws4" config user.email t@test; git -C "$ws4" config user.name t
  git -C "$ws4" config commit.gpgsign false
  printf '{"WSS":{"record":{"todo":{"provider":"github-issues","repo":"acme/demo","label":"backlog"}}}}\n' \
    > "$ws4/.claude/WSS.WORKFLOW.json"
  docommit "$ws4"
  fakebin="$TMP/wrapstat-fakebin"; rm -rf "$fakebin"; mkdir -p "$fakebin"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fakebin/gh"
  chmod +x "$fakebin/gh"
  out=$(cd "$ws4" && PATH="$fakebin:$PATH" bash "$WRAPSTATUS" 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "an unreachable gh still exits 0 — a report, not a gate" \
    || bad "an unreachable gh made wss-wrap-status.sh exit $rc"
  case $out in
    *"todo=?(github-issues provider (acme/demo) — gh call failed, not counted)"*)
      ok "a failed gh call is reported as not-counted, never folded into a zero" ;;
    *) bad "the offline guard did not fire: $(printf '%s' "$out" | grep '^todo=')" ;;
  esac
  case $out in
    *"todo=0"*) bad "a failed gh call read as todo=0 — false freshness, the exact defect this guards" ;;
    *) ok "and it never silently renders as zero" ;;
  esac

  # --- gated on the measuring tool being present -----------------------------
  # wss-wrap-status.sh computes the always-on basis by shelling out to
  # wss-audit-assets.sh beside the installation, and writes NO stamp when that
  # script is absent. That is correct rather than a gap: a basis it could not
  # measure would be differenced against a real one on the next run, which is a
  # false delta rather than a missing one — the same principle
  # WSS.SWEEP-CHECKPOINT.md states as a stamp no run earned being worse than
  # none. And wss-publish.sh deletes that script from every assembly on the
  # recorded "it does not travel" ruling (grep -n 'wss-audit-assets' on it), so
  # in an assembly these assertions demand a stamp the tree is deliberately
  # built not to produce. That is the whole of Gate 3's 8-failure set: one
  # cause, eight assertions, and nothing wrong on the shipped side of it.
  # Gate on the tool's presence — a detectable property of the tree — never on
  # a list of test names, which is where a real regression would hide.
  # The guarded body below is deliberately NOT re-indented, so this reads as
  # the one-line gate it is rather than as a 125-line rewrite.
  if [ ! -f "$_root/wss/scripts/wss-audit-assets.sh" ]; then
    ok "always-on assertions skipped — wss-audit-assets.sh is absent, so this tree cannot measure a basis and correctly writes no stamp"
  else
  # always-on delta (A2): CLAUDE.md + visible skill descriptions + handoff
  # card, stamped in .claude/WSS.ALWAYS-ON-STAMP.json — a sibling of the
  # sweep checkpoint this script now owns outright, the one write it makes.
  # Unlike ws1-ws4 above, this fixture's stamp file persists between the
  # calls below on purpose, so each case is run against the same $ws5.
  ws5="$TMP/wrapstat-alwayson-first"; rm -rf "$ws5"; mkdir -p "$ws5/.claude" "$ws5/wss/records"
  git init -q "$ws5" 2>/dev/null
  git -C "$ws5" config user.email t@test; git -C "$ws5" config user.name t
  git -C "$ws5" config commit.gpgsign false
  printf '# Claude config\n\nSome instructions here.\n' > "$ws5/CLAUDE.md"
  printf '# Handoff\n\nCard body.\n<!-- handoff:card-ends -->\n\nRest not counted.\n' \
    > "$ws5/wss/records/WSS.HANDOFF.md"
  docommit "$ws5"
  expect_claude=$(wc -c < "$ws5/CLAUDE.md")
  expect_card=$(awk '/<!-- handoff:card-ends -->/{exit} {n+=length($0)+1} END{print n+0}' \
    "$ws5/wss/records/WSS.HANDOFF.md")
  expect_total=$((expect_claude + expect_card))

  out=$(wrun "$ws5"); rc=$?
  [ "$rc" -eq 0 ] && ok "always-on first run exits 0" \
    || bad "first run with no prior stamp exited $rc, not 0"
  case $out in
    *"always-on: ${expect_total} B (no prior stamp — baseline written)"*)
      ok "first run with no stamp reports a byte total and says so honestly, not a false zero delta" ;;
    *) bad "first-run always-on line missing or wrong: $(printf '%s' "$out" | grep '^always-on:')" ;;
  esac
  case $out in
    *"== always-on =="*)
      bad "a separate '== always-on ==' section header appeared — the entry wants one line inside == sweep ==, not a new section" ;;
    *) ok "no new section header was introduced for the always-on line" ;;
  esac
  [ -f "$ws5/.claude/WSS.ALWAYS-ON-STAMP.json" ] \
    && ok "the stamp file is written on first run" \
    || bad "no stamp file written at $ws5/.claude/WSS.ALWAYS-ON-STAMP.json"
  grep -q "\"bytes\": ${expect_total}" "$ws5/.claude/WSS.ALWAYS-ON-STAMP.json" \
    && ok "the stamp records the same byte total just reported" \
    || bad "the stamp's bytes field does not match the reported total"

  out=$(wrun "$ws5")
  case $out in
    *"always-on: ${expect_total} B (no change since"*" stamp)"*)
      ok "an unchanged tree reports 'no change since ... stamp' against the now-written stamp" ;;
    *) bad "unchanged-tree delta missing or wrong: $(printf '%s' "$out" | grep '^always-on:')" ;;
  esac

  printf 'more instructions\n' >> "$ws5/CLAUDE.md"
  docommit "$ws5"
  new_claude=$(wc -c < "$ws5/CLAUDE.md")
  new_total=$((new_claude + expect_card))
  growth=$((new_total - expect_total))
  out=$(wrun "$ws5")
  case $out in
    *"always-on: ${new_total} B (+${growth} B since"*" stamp)"*)
      ok "growth since the last stamp is reported as a signed positive delta" ;;
    *) bad "growth delta missing or wrong: $(printf '%s' "$out" | grep '^always-on:')" ;;
  esac

  printf '# Claude config\n' > "$ws5/CLAUDE.md"
  docommit "$ws5"
  shrink_claude=$(wc -c < "$ws5/CLAUDE.md")
  shrink_total=$((shrink_claude + expect_card))
  shrink_delta=$((shrink_total - new_total))
  out=$(wrun "$ws5")
  case $out in
    *"always-on: ${shrink_total} B (${shrink_delta} B since"*" stamp)"*)
      ok "shrinkage since the last stamp is reported as a signed negative delta" ;;
    *) bad "shrink delta missing or wrong: $(printf '%s' "$out" | grep '^always-on:')" ;;
  esac

  # A stamp file that exists but is not the shape this script wrote (corrupt,
  # or from something else entirely) must read as no-prior-stamp, not crash
  # and not silently misread a field into a bogus delta.
  ws7="$TMP/wrapstat-alwayson-corrupt"; rm -rf "$ws7"; mkdir -p "$ws7/.claude" "$ws7/wss/records"
  git init -q "$ws7" 2>/dev/null
  git -C "$ws7" config user.email t@test; git -C "$ws7" config user.name t
  git -C "$ws7" config commit.gpgsign false
  printf '# Claude config\n' > "$ws7/CLAUDE.md"
  printf 'Card.\n<!-- handoff:card-ends -->\n' > "$ws7/wss/records/WSS.HANDOFF.md"
  printf 'not even json' > "$ws7/.claude/WSS.ALWAYS-ON-STAMP.json"
  docommit "$ws7"
  out=$(wrun "$ws7"); rc=$?
  [ "$rc" -eq 0 ] && ok "a corrupt stamp file still exits 0" \
    || bad "a corrupt stamp file made the script exit $rc, not 0"
  case $out in
    *"always-on:"*"(no prior stamp — baseline written)"*)
      ok "an unreadable stamp file is treated as no prior stamp, not a crash or a bogus delta" ;;
    *) bad "a corrupt stamp file was not handled gracefully: $(printf '%s' "$out" | grep '^always-on:')" ;;
  esac

  # Visible skill descriptions count; a hidden skill (disable-model-invocation)
  # and one turned off via settings.json skillOverrides do not — the same
  # rule wss-audit-assets.sh's "Per-skill sizes" section applies, mirrored
  # here rather than reimplemented differently. bar and qux hide via the two
  # spellings wss-audit-assets.sh's own hidden-skill grep accepts
  # (`disable-model-invocation` and `disableModelInvocation`,
  # wss-audit-assets.sh:114) — both must be excluded, proving the parser
  # this always-on total relies on is not spelling-specific.
  ws6="$TMP/wrapstat-alwayson-skills"; rm -rf "$ws6"
  mkdir -p "$ws6/.claude" "$ws6/wss/records" "$ws6/skills/foo" "$ws6/skills/bar" "$ws6/skills/baz" "$ws6/skills/qux"
  git init -q "$ws6" 2>/dev/null
  git -C "$ws6" config user.email t@test; git -C "$ws6" config user.name t
  git -C "$ws6" config commit.gpgsign false
  printf '# Claude config\n' > "$ws6/CLAUDE.md"
  printf 'Card.\n<!-- handoff:card-ends -->\n' > "$ws6/wss/records/WSS.HANDOFF.md"
  printf -- '---\nname: foo\ndescription: A short foo description for the always-on byte test.\n---\nBody.\n' \
    > "$ws6/skills/foo/SKILL.md"
  printf -- '---\nname: bar\ndescription: A hidden bar description that must not be counted.\ndisable-model-invocation: true\n---\nBody.\n' \
    > "$ws6/skills/bar/SKILL.md"
  printf -- '---\nname: baz\ndescription: An overridden-off baz description that must not be counted.\n---\nBody.\n' \
    > "$ws6/skills/baz/SKILL.md"
  printf -- '---\nname: qux\ndescription: A hidden qux description that must not be counted.\ndisableModelInvocation: true\n---\nBody.\n' \
    > "$ws6/skills/qux/SKILL.md"
  printf '{"skillOverrides": {"baz": "off"}}\n' > "$ws6/.claude/settings.json"
  docommit "$ws6"

  sk_claude=$(wc -c < "$ws6/CLAUDE.md")
  sk_card=$(awk '/<!-- handoff:card-ends -->/{exit} {n+=length($0)+1} END{print n+0}' \
    "$ws6/wss/records/WSS.HANDOFF.md")
  sk_foo_desc=$(awk 'NR==1 && /^---$/{fm=1; next}
              fm && /^---$/{exit}
              fm && cap && /^[^ ]/{cap=0}
              fm && /^description:/{cap=1; sub(/^description:[ ]*/,""); n+=length($0)+1; next}
              fm && cap{n+=length($0)+1} END{print n+0}' "$ws6/skills/foo/SKILL.md")
  sk_expect=$((sk_claude + sk_card + sk_foo_desc))

  out=$(wrun "$ws6")
  case $out in
    *"always-on: ${sk_expect} B "*)
      ok "always-on bytes count a visible skill's description, skipping hidden (either spelling) and overridden-off ones" ;;
    *) bad "always-on total did not match visible-only description bytes: $(printf '%s' "$out" | grep '^always-on:')" ;;
  esac
  fi
fi

# ---------------------------------------------------- wrap wss-handoff-state.sh

head_ "wss-handoff-state.sh splices the handoff's State section and hazard entries"

# Three operations, none of which reads the body it is replacing — this
# section proves that, the anchor-count/order refusals (byte-identical file on
# any violation), the 4096B card-cap check, permission bits surviving the
# atomic write, and the card-marker-as-boundary fix in section_end() that a
# break-on-purpose pass found: hazard-append against a card-bounded section
# used to insert AFTER the marker, silently escaping the card.
HANDOFFSTATE="$_root/skills/wrap/assets/wss-handoff-state.sh"
if [ ! -f "$HANDOFFSTATE" ]; then
  bad "wss-handoff-state.sh missing at $HANDOFFSTATE"
else
  hs_fixture() { # dir — a synthetic handoff, never the real project's
    local d=$1
    rm -rf "$d"; mkdir -p "$d"
    { printf '# Handoff\n\n## !important\n\n'
      printf 'Short intro.\n\n'
      printf '## Known hazards\n\n'
      printf -- '- existing hazard one\n\n'
      printf '<!-- handoff:card-ends -->\n\n'
      printf '## State\n\n'
      printf 'OLD STATE BODY, should vanish entirely — SENTINEL_OLD.\n\n'
      printf '## Where everything else is\n\n'
      printf 'Pointers here.\n'
    } > "$d/HANDOFF.md"
  }

  # --- state: wholesale replace, old body never read ------------------------
  hs1="$TMP/handoff-state"; hs_fixture "$hs1"
  printf 'NEW STATE BODY — SENTINEL_NEW.\n' > "$hs1/content.txt"
  out=$(bash "$HANDOFFSTATE" state "$hs1/HANDOFF.md" "$hs1/content.txt" 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "state exits 0 on a well-formed handoff" \
    || bad "state failed on a well-formed handoff: $out"
  grep -q "SENTINEL_NEW" "$hs1/HANDOFF.md" \
    && ok "the new body lands in the file" \
    || bad "the new body never landed"
  grep -q "SENTINEL_OLD" "$hs1/HANDOFF.md" \
    && bad "the old State body survived — this is an edit, not a supersession" \
    || ok "the old State body is gone entirely, never merged with the new one"
  grep -qF '## Where everything else is' "$hs1/HANDOFF.md" \
    && grep -qF 'Pointers here.' "$hs1/HANDOFF.md" \
    && ok "everything past the heading anchor is untouched" \
    || bad "the splice ate into the section past its own end anchor"
  grep -qF 'Short intro.' "$hs1/HANDOFF.md" \
    && ok "everything before the card marker is untouched by 'state'" \
    || bad "'state' touched the card — it must stop at the marker"
  # The duplicate-heading regression this class of bug produces: a content
  # file that itself opens with '## State' used to land under a SECOND
  # '## State' heading emitted by the splice. Caught on the record itself
  # (WSS.HANDOFF.md carried two consecutive '## State' headings from an
  # earlier wrap) — this assertion is the one of the three fixes that
  # catches a file already written wrong, not just a future mistake.
  hcount=$(grep -c '^## State$' "$hs1/HANDOFF.md")
  [ "$hcount" -eq 1 ] && ok "exactly one '## State' heading survives a normal splice" \
    || bad "'## State' appears $hcount times after a normal splice — want exactly 1"

  # --- anchor violations: refuse, and leave the file byte-identical ---------
  hs_expect_refuse() { # dir, label, args...
    local d=$1 label=$2; shift 2
    local before after
    before=$(md5sum "$d/HANDOFF.md" | cut -d' ' -f1)
    err=$(bash "$HANDOFFSTATE" "$@" 2>&1); rc=$?
    after=$(md5sum "$d/HANDOFF.md" | cut -d' ' -f1)
    if [ "$rc" -eq 0 ]; then
      bad "$label: exited 0 instead of refusing"
    elif [ "$before" != "$after" ]; then
      bad "$label: refused but still wrote — the file changed"
    else
      ok "$label: refused (exit $rc), file byte-identical"
    fi
  }

  hs2="$TMP/handoff-nomarker"; hs_fixture "$hs2"
  sed -i 's/<!-- handoff:card-ends -->//' "$hs2/HANDOFF.md"
  printf 'x\n' > "$hs2/c.txt"
  hs_expect_refuse "$hs2" "zero occurrences of the card marker" \
    state "$hs2/HANDOFF.md" "$hs2/c.txt"

  hs3="$TMP/handoff-twomarker"; hs_fixture "$hs3"
  printf '\n<!-- handoff:card-ends -->\n' >> "$hs3/HANDOFF.md"
  printf 'x\n' > "$hs3/c.txt"
  hs_expect_refuse "$hs3" "two occurrences of the card marker" \
    state "$hs3/HANDOFF.md" "$hs3/c.txt"

  hs4="$TMP/handoff-noheading"; hs_fixture "$hs4"
  sed -i 's/## Where everything else is/## Somewhere else entirely/' "$hs4/HANDOFF.md"
  printf 'x\n' > "$hs4/c.txt"
  hs_expect_refuse "$hs4" "the closing heading renamed away" \
    state "$hs4/HANDOFF.md" "$hs4/c.txt"

  hs5="$TMP/handoff-outoforder"; rm -rf "$hs5"; mkdir -p "$hs5"
  # the closing heading appears BEFORE the card marker — anchors out of order
  { printf '# Handoff\n\n## !important\n\n'
    printf 'Short intro.\n\n'
    printf '## Where everything else is\n\n'
    printf 'Pointers here.\n\n'
    printf '## State\n\n'
    printf 'OLD STATE BODY — SENTINEL_OLD.\n\n'
    printf '<!-- handoff:card-ends -->\n'
  } > "$hs5/HANDOFF.md"
  printf 'x\n' > "$hs5/c.txt"
  hs_expect_refuse "$hs5" "the marker and heading out of order" \
    state "$hs5/HANDOFF.md" "$hs5/c.txt"

  hs6="$TMP/handoff-emptybody"; hs_fixture "$hs6"
  printf '' > "$hs6/c.txt"
  hs_expect_refuse "$hs6" "an empty new-state body" \
    state "$hs6/HANDOFF.md" "$hs6/c.txt"

  hs6b="$TMP/handoff-selfheaded"; hs_fixture "$hs6b"
  printf '## State\n\nSome body text.\n' > "$hs6b/c.txt"
  hs_expect_refuse "$hs6b" "a content file whose first non-blank line is '## State' itself" \
    state "$hs6b/HANDOFF.md" "$hs6b/c.txt"

  # --- the 4096B card cap -----------------------------------------------------
  hs7="$TMP/handoff-cap"; hs_fixture "$hs7"
  python3 -c "print('x' * 4200)" > "$hs7/big.txt" 2>/dev/null \
    || yes x | head -c 4200 | tr -d '\n' > "$hs7/big.txt"
  hs_expect_refuse "$hs7" "an append that would push the card past 4096B" \
    hazard-append "$hs7/HANDOFF.md" "## Known hazards" "$hs7/big.txt"
  printf '%s' "$err" | grep -q "4096" \
    && ok "the refusal names the 4096B budget" \
    || bad "the cap refusal did not name the budget: $err"

  # --- the pinned regression: the card marker is a section boundary ---------
  # section_end() used to stop only at the next `## ` heading, so
  # hazard-append against a heading whose section is bounded below by the
  # marker (not by another heading) inserted AFTER the marker — silently
  # outside the card. It must land BEFORE the marker line now.
  hs8="$TMP/handoff-hazardappend"; hs_fixture "$hs8"
  printf 'NEW HAZARD ENTRY — must stay inside the card.\n' > "$hs8/entry.txt"
  out=$(bash "$HANDOFFSTATE" hazard-append "$hs8/HANDOFF.md" "## Known hazards" "$hs8/entry.txt" 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "hazard-append exits 0 against a card-bounded section" \
    || bad "hazard-append failed against a card-bounded section: $out"
  entry_line=$(grep -n "NEW HAZARD ENTRY" "$hs8/HANDOFF.md" | head -1 | cut -d: -f1)
  marker_line=$(grep -n -- '<!-- handoff:card-ends -->' "$hs8/HANDOFF.md" | head -1 | cut -d: -f1)
  if [ -n "$entry_line" ] && [ -n "$marker_line" ] && [ "$entry_line" -lt "$marker_line" ]; then
    ok "the new hazard entry landed before the card marker, inside the card"
  else
    bad "the new hazard entry landed at or after the card marker — the pinned regression is back (entry=$entry_line marker=$marker_line)"
  fi

  # --- atomic write and permission bits --------------------------------------
  hs9="$TMP/handoff-perms"; hs_fixture "$hs9"
  chmod 640 "$hs9/HANDOFF.md"
  printf 'perm test body.\n' > "$hs9/c.txt"
  bash "$HANDOFFSTATE" state "$hs9/HANDOFF.md" "$hs9/c.txt" >/dev/null 2>&1
  mode=$(stat -c '%a' "$hs9/HANDOFF.md")
  [ "$mode" = "640" ] && ok "the atomic write preserves the file's existing permission bits" \
    || bad "permission bits drifted after the write: got $mode, wanted 640"
  leftover=$(find "$hs9" -maxdepth 1 -name '.wss-handoff-state.*' 2>/dev/null)
  [ -z "$leftover" ] && ok "no temp file is left behind after a successful write" \
    || bad "a temp file was left in the target directory: $leftover"
fi

# ---------------------------------------------------- git-writer wss-git-commit.sh

head_ "wss-git-commit.sh is the sole stage/commit/push mechanism, by exact name"

GITCOMMIT="$_root/wss/workflow/writers/assets/wss-git-commit.sh"
if [ ! -f "$GITCOMMIT" ]; then
  bad "wss-git-commit.sh missing at $GITCOMMIT"
else
  # No default trailer key and no model name anywhere in a live assignment —
  # the header comment names "Claude-Session" as an EXAMPLE of what never to
  # hardcode, so the assertion below is on the DEFAULT VALUES actually
  # assigned, not on the word appearing in prose.
  grep -qE '^(coauthor|trailer_key|session)=$' "$GITCOMMIT" >/dev/null \
    && ok "session/coauthor/trailer_key all start with no default value" \
    || bad "one of session/coauthor/trailer_key carries a non-empty default"
  ! grep -qE '(coauthor|trailer_key|session)=.*([Cc]laude|[Aa]nthropic|[Ss]onnet|[Oo]pus|[Hh]aiku)' "$GITCOMMIT" \
    && ok "no default assignment carries a model name" \
    || bad "a default assignment carries a model name"

  gc="$TMP/gitcommit-fix"; rm -rf "$gc"; mkdir -p "$gc"
  git init -q "$gc" 2>/dev/null
  git -C "$gc" config user.email t@test; git -C "$gc" config user.name t
  git -C "$gc" config commit.gpgsign false
  printf 'base\n' > "$gc/base.txt"
  git -C "$gc" add base.txt >/dev/null 2>&1
  git -C "$gc" commit -q -m base >/dev/null 2>&1

  grun() { # dir, args... — sets gout, grc
    local d=$1; shift
    gout=$(cd "$d" && bash "$GITCOMMIT" "$@" 2>&1); grc=$?
  }

  grun "$gc"
  [ "$grc" -eq 2 ] && ok "no arguments exits 2" || bad "no arguments exited $grc"
  grun "$gc" --message m --session s --coauthor "A <a@x>" --trailer-key K
  [ "$grc" -eq 2 ] && ok "missing --files exits 2 — this script never stages by any other means" \
    || bad "missing --files exited $grc"
  grun "$gc" --files base.txt --session s --coauthor "A <a@x>" --trailer-key K
  [ "$grc" -eq 2 ] && ok "missing --message exits 2" || bad "missing --message exited $grc"
  grun "$gc" --files base.txt --message m --coauthor "A <a@x>" --trailer-key K
  [ "$grc" -eq 2 ] && ok "missing --session exits 2" || bad "missing --session exited $grc"
  grun "$gc" --files base.txt --message m --session s --trailer-key K
  [ "$grc" -eq 2 ] && ok "missing --coauthor exits 2" || bad "missing --coauthor exited $grc"
  grun "$gc" --files base.txt --message m --session s --coauthor "A <a@x>"
  [ "$grc" -eq 2 ] && ok "missing --trailer-key exits 2" || bad "missing --trailer-key exited $grc"

  # --- staging by exact name, never `git add -A` -----------------------------
  printf 'one\n'   > "$gc/file with space.txt"
  printf 'two\n'   > "$gc/[glob].txt"
  printf 'three\n' > "$gc/-dash-named.txt"
  printf 'should never be staged\n' > "$gc/untouched.txt"
  grun "$gc" --files "file with space.txt" --files "[glob].txt" --files "-dash-named.txt" \
    --message "add three oddly-named files" --session sess1 --coauthor "A <a@x>" --trailer-key Wss-Test-Session
  [ "$grc" -eq 0 ] && ok "three oddly-named --files arguments stage and commit" \
    || bad "the commit failed (rc=$grc): $gout"
  staged=$(git -C "$gc" diff-tree --no-commit-id --name-only -r HEAD)
  printf '%s\n' "$staged" | grep -qxF "file with space.txt" \
    && ok "a filename with a space staged correctly" \
    || bad "the space-named file did not land in the commit: $staged"
  printf '%s\n' "$staged" | grep -qxF "[glob].txt" \
    && ok "a filename shaped like a glob staged literally, not expanded" \
    || bad "the glob-shaped filename did not land in the commit: $staged"
  printf '%s\n' "$staged" | grep -qxF -- "-dash-named.txt" \
    && ok "a filename starting with '-' staged as a pathspec, not read as a flag" \
    || bad "the dash-led filename did not land in the commit: $staged"
  printf '%s\n' "$staged" | grep -qxF "untouched.txt" \
    && bad "untouched.txt was swept into the commit — staging fell back to git add -A" \
    || ok "the untracked file beside them was left alone — never git add -A"
  git -C "$gc" status --porcelain | grep -q '?? untouched.txt' \
    && ok "and it is still untracked afterward" \
    || bad "untouched.txt is no longer showing as untracked"

  # --- the readback catches an unparseable trailer ---------------------------
  # Git only recognises a token without a space as a trailer key, so a
  # trailer-key containing one makes the whole last paragraph read as
  # ordinary prose — no trailer at all, which is exactly the state the
  # readback exists to catch before a push.
  printf 'x\n' > "$gc/badkey.txt"
  grun "$gc" --files badkey.txt --message "bad trailer key" --session sess2 \
    --coauthor "A <a@x>" --trailer-key "Not Valid"
  [ "$grc" -eq 1 ] && ok "a trailer key git cannot parse as a trailer exits 1" \
    || bad "an unparseable trailer key exited $grc, not 1"
  case $gout in
    *"did not parse"*) ok "the readback failure is reported by name, not a silent commit" ;;
    *) bad "no readback-failure message: $gout" ;;
  esac

  # --- a leading '+' is refused before git is ever touched -------------------
  # No origin remote exists in this fixture at all — if the guard below did
  # not fire first, `git push origin +main` would still fail, but with a
  # DIFFERENT message ("push rejected", exit 1) rather than the refusal
  # below (exit 2), which is what tells the two failure modes apart.
  printf 'y\n' > "$gc/pushguard.txt"
  grun "$gc" --files pushguard.txt --message "push guard" --session sess3 \
    --coauthor "A <a@x>" --trailer-key Wss-Test-Session --push "+main"
  [ "$grc" -eq 2 ] && ok "a refspec with a leading '+' exits 2, refused before any push" \
    || bad "a leading '+' refspec exited $grc, not 2 — the guard did not fire first"
  case $gout in
    *"refusing a push refspec with a leading '+'"*)
      ok "and the refusal names the leading '+' as the reason" ;;
    *) bad "no leading-'+' refusal message: $gout" ;;
  esac
  git -C "$gc" log -1 --format=%s | grep -q "push guard" \
    && ok "the commit still landed locally — only the push was refused" \
    || bad "the commit did not land even though only the push should have been refused"

  # --- a rejected push is handed back, never retried or forced ---------------
  gremote="$TMP/gitcommit-remote.git"; rm -rf "$gremote"; git init -q --bare "$gremote" 2>/dev/null
  git -C "$gremote" symbolic-ref HEAD refs/heads/main 2>/dev/null
  gp="$TMP/gitcommit-push"; rm -rf "$gp"; mkdir -p "$gp"
  git init -q -b main "$gp" 2>/dev/null
  git -C "$gp" config user.email t@test; git -C "$gp" config user.name t
  git -C "$gp" config commit.gpgsign false
  printf 'base\n' > "$gp/base.txt"; git -C "$gp" add -A >/dev/null 2>&1
  git -C "$gp" commit -q -m base >/dev/null 2>&1
  git -C "$gp" remote add origin "$gremote"
  git -C "$gp" push -q origin HEAD:refs/heads/main >/dev/null 2>&1
  # diverge the remote out from under this checkout
  gother="$TMP/gitcommit-other"; rm -rf "$gother"
  git clone -q -b main "$gremote" "$gother" >/dev/null 2>&1
  git -C "$gother" config user.email t2@test; git -C "$gother" config user.name t2
  git -C "$gother" config commit.gpgsign false
  printf 'other\n' > "$gother/other.txt"; git -C "$gother" add -A >/dev/null 2>&1
  git -C "$gother" commit -q -m other >/dev/null 2>&1
  git -C "$gother" push -q origin HEAD:refs/heads/main >/dev/null 2>&1
  printf 'more\n' > "$gp/more.txt"
  grun "$gp" --files more.txt --message "will be rejected" --session sess4 \
    --coauthor "A <a@x>" --trailer-key Wss-Test-Session --push main
  [ "$grc" -eq 1 ] && ok "a non-fast-forward push exits 1" \
    || bad "a rejected push exited $grc, not 1"
  case $gout in
    *"push rejected (origin main)"*"Not retried and not forced"*)
      ok "the rejection is handed back by name, never retried or forced" ;;
    *) bad "no 'handed back, not retried' message on a rejected push: $gout" ;;
  esac
  git -C "$gp" log -1 --format=%s | grep -q "will be rejected" \
    && ok "the commit landed locally even though the push was rejected" \
    || bad "the local commit did not land despite only the push being rejected"
fi

# ------------------------------------------------- wss-mechanical-gauntlet.sh

head_ "wss-mechanical-gauntlet.sh: verdict block, flag handling, and the doctor it must never lose"

# Wave-1 script. SUITE_ROOT resolves from the script's own BASH_SOURCE with no
# override, so every invocation below runs a COPY of it planted in a
# disposable fixture beside a fake wss-doctor.sh — never the real one, never
# this repository. --test-consent and --carry-forward are exercised entirely
# with synthetic WSS.commands.test strings (counters and sentinels, never a
# real test suite), which is what keeps this block from ever recursing into
# the contract suite it is testing membership for.
GAUNT="$_root/wss/scripts/wss-mechanical-gauntlet.sh"
if [ ! -f "$GAUNT" ]; then
  bad "wss-mechanical-gauntlet.sh missing at $GAUNT"
else
  bash -n "$GAUNT" 2>/dev/null && ok "wss-mechanical-gauntlet.sh parses" \
    || bad "wss-mechanical-gauntlet.sh has a syntax error"

  # The synthetic doctors below sit at wss/tests/, not at the suite root. They
  # sat at the root until 2026-08-16 and the assertions were true when written —
  # that is where wss-doctor.sh lived. The reorg moved it and left the gauntlet
  # resolving the old path, so the gauntlet found no doctor at all and its own
  # else-branch reported that instead of running one. Fixing the gauntlet is
  # what moved these fixtures; the assertions themselves are unchanged.
  ggdir="$TMP/gauntlet"; rm -rf "$ggdir"; mkdir -p "$ggdir/proj/.claude" "$ggdir/wss/scripts" "$ggdir/wss/tests"
  cp "$GAUNT" "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh"; chmod +x "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh"
  gproj="$ggdir/proj"
  git init -q "$gproj" 2>/dev/null
  git -C "$gproj" config user.email t@test; git -C "$gproj" config user.name t
  git -C "$gproj" config commit.gpgsign false
  printf 'x\n' > "$gproj/f.txt"; git -C "$gproj" add -A >/dev/null 2>&1
  git -C "$gproj" commit -q -m first >/dev/null 2>&1
  gsha=$(git -C "$gproj" rev-parse HEAD)

  gmanifest() { printf '%s' "$1" > "$gproj/.claude/WSS.WORKFLOW.json"; }

  grun() { # args... — sets gout, grc; always the fixture copy, never this repo
    gout=$(cd "$gproj" && bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" "$@" 2>&1); grc=$?
  }

  # --- flag handling ----------------------------------------------------
  printf '#!/usr/bin/env bash\necho "  OK  synthetic"\nexit 0\n' > "$ggdir/wss/tests/wss-doctor.sh"
  chmod +x "$ggdir/wss/tests/wss-doctor.sh"
  gmanifest '{}'
  grun --bogus
  [ "$grc" -eq 2 ] && ok "an unknown flag exits 2" || bad "an unknown flag exited $grc, not 2"
  case $gout in
    *"unknown argument: --bogus"*) ok "and names the bad argument" ;;
    *) bad "no 'unknown argument' message: $gout" ;;
  esac

  # --- the doctor: always runs, no checkpoint covers it -------------------
  rm -f "$ggdir/wss/tests/wss-doctor.sh"
  grun
  [ "$grc" -eq 1 ] && ok "a missing doctor exits 1" || bad "a missing doctor exited $grc, not 1"
  case $gout in
    *"doctor: missing"*) ok "verdict block names the missing doctor" ;;
    *) bad "verdict block silent on a missing doctor: $gout" ;;
  esac

  printf '#!/usr/bin/env bash\necho "  FAIL  synthetic"\nexit 1\n' > "$ggdir/wss/tests/wss-doctor.sh"
  chmod +x "$ggdir/wss/tests/wss-doctor.sh"
  grun
  [ "$grc" -eq 1 ] && ok "a failing doctor exits 1" || bad "a failing doctor exited $grc, not 1"
  case $gout in
    *"doctor: fail"*) ok "verdict block names the failing doctor" ;;
    *) bad "verdict block silent on a failing doctor: $gout" ;;
  esac

  printf '#!/usr/bin/env bash\necho "  OK  synthetic"\nexit 0\n' > "$ggdir/wss/tests/wss-doctor.sh"
  chmod +x "$ggdir/wss/tests/wss-doctor.sh"
  grun
  [ "$grc" -eq 0 ] && ok "a passing doctor with nothing else declared exits 0" \
    || bad "a clean run with nothing declared exited $grc"
  case $gout in
    *"doctor: pass"*"typecheck: undeclared"*"test: undeclared"*)
      ok "verdict block reports all four keys for an undeclared manifest" ;;
    *) bad "verdict block missing a key on an undeclared manifest: $gout" ;;
  esac

  # --- the doctor resolves BESIDE ITSELF, never via $HOME ------------------
  # The header's central claim: wss-doctor.sh "is found next to this script,
  # not via $HOME/.claude". $HOME here points at a second fake doctor that
  # must never run — if it did, a real user's $HOME/.claude (this repository)
  # would have its real doctor run over the real tree, exactly what this lane
  # was told never to do.
  ghome="$TMP/gauntlet-home"; rm -rf "$ghome"; mkdir -p "$ghome/.claude/wss/tests"
  printf '#!/usr/bin/env bash\necho "HOME-DOCTOR-RAN"\nexit 0\n' > "$ghome/.claude/wss/tests/wss-doctor.sh"
  chmod +x "$ghome/.claude/wss/tests/wss-doctor.sh"
  printf '#!/usr/bin/env bash\necho "SIBLING-DOCTOR-RAN"\nexit 0\n' > "$ggdir/wss/tests/wss-doctor.sh"
  chmod +x "$ggdir/wss/tests/wss-doctor.sh"
  out=$(cd "$gproj" && HOME="$ghome" bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1)
  case $out in
    *SIBLING-DOCTOR-RAN*) ok "the sibling doctor beside the script runs" ;;
    *) bad "the sibling doctor never ran: $out" ;;
  esac
  case $out in
    *HOME-DOCTOR-RAN*) bad "a doctor at \$HOME/.claude ran instead of the sibling one" ;;
    *) ok "and \$HOME/.claude's doctor never runs" ;;
  esac
  # Proof the assertion above is not vacuous: a copy with SUITE_ROOT forced to
  # $HOME/.claude must make HOME-DOCTOR-RAN appear. If it did not, the
  # assertion above would be proving nothing.
  gbroken="$ggdir/broken-suiteroot.sh"
  sed 's#SUITE_ROOT="\$(cd -- "\$(dirname -- "\${BASH_SOURCE\[0\]}")/\.\./\.\." && pwd -P)"#SUITE_ROOT="$HOME/.claude"#' \
    "$GAUNT" > "$gbroken"
  chmod +x "$gbroken"
  bout=$(cd "$gproj" && HOME="$ghome" bash "$gbroken" 2>&1)
  case $bout in
    *HOME-DOCTOR-RAN*)
      ok "proven: a copy with SUITE_ROOT forced to \$HOME/.claude DOES run the \$HOME doctor — the guard above is not vacuous" ;;
    *) bad "the broken copy failed to reproduce the \$HOME-doctor bug — the guard above proves nothing" ;;
  esac

  # --- typecheck -----------------------------------------------------------
  gmanifest '{"WSS":{"commands":{"typecheck":"exit 0"}}}'
  grun
  case $gout in *"typecheck: pass"*) ok "a passing typecheck command reports pass" ;;
                *) bad "a passing typecheck command did not report pass: $gout" ;;
  esac
  gmanifest '{"WSS":{"commands":{"typecheck":"exit 9"}}}'
  grun
  [ "$grc" -eq 1 ] && ok "a failing typecheck command exits 1" || bad "a failing typecheck exited $grc"
  case $gout in *"typecheck: fail"*) ok "and reports fail in the verdict" ;;
                *) bad "a failing typecheck did not report fail: $gout" ;;
  esac

  # --- test: consent gate, and the command genuinely does not run ----------
  gsentinel="$gproj/sentinel"
  gmanifest "{\"WSS\":{\"commands\":{\"test\":\"echo ran >> $gsentinel; exit 0\",\"testConsentEnv\":\"WSS_TEST_CONSENT\"}}}"
  rm -f "$gsentinel"
  grun
  case $gout in *"test: not-covered"*) ok "an undeclared consent token is not-covered without --test-consent" ;;
                *) bad "consent gate did not report not-covered: $gout" ;;
  esac
  [ -f "$gsentinel" ] && bad "the test command ran despite the consent gate not being satisfied" \
    || ok "and the test command itself never ran — the gate is not cosmetic"

  grun --test-consent
  [ -f "$gsentinel" ] && ok "--test-consent satisfies the gate and the command runs" \
    || bad "--test-consent was passed but the test command never ran"
  case $gout in *"test: pass"*) ok "a passing test run under consent reports pass" ;;
                *) bad "a passing consented test run did not report pass: $gout" ;;
  esac

  # A carry-forward is licensed by the TRACKER, not by the caller saying so.
  # This block used to assert the opposite: it passed the reason "sweep-tracker
  # licensed a skip" with no stamp existing anywhere and asserted the run was
  # carried. The reason string WAS the gate and these assertions encoded that,
  # which is why they had to change with the fix rather than confirm it.
  gstamp() { # <baseline> <result> — the tracker entry the gauntlet must consult
    printf '{"sweep":{},"entries":{"test-run":{"baseline":"%s","at":"2026-01-01","result":"%s","test-count":7}}}' \
      "$1" "$2" > "$gproj/.claude/WSS.SWEEPS.json"
  }

  rm -f "$gsentinel" "$gproj/.claude/WSS.SWEEPS.json"
  grun --test-consent --carry-forward "sweep-tracker licensed a skip"
  case $gout in *"test: not-covered"*) ok "a carry-forward with no test-run stamp is refused" ;;
                *) bad "an unlicensed carry-forward was not refused: $gout" ;;
  esac
  case $gout in *"carry-forward REFUSED"*) ok "and the refusal is reported, with the reason offered" ;;
                *) bad "the refusal was not reported: $gout" ;;
  esac
  [ -f "$gsentinel" ] && bad "a refused carry-forward ran the test command" \
    || ok "and a refused carry-forward does not quietly run the suite instead"

  gstamp "$gsha" green
  rm -f "$gsentinel"
  grun --test-consent --carry-forward "sweep-tracker licensed a skip"
  case $gout in *"test: carried"*) ok "a carry-forward the tracker licenses reports carried" ;;
                *) bad "a licensed carry-forward did not report carried: $gout" ;;
  esac
  case $gout in *"carried forward: sweep-tracker licensed a skip"*) ok "and echoes the reason verbatim" ;;
                *) bad "the carry-forward reason was not echoed: $gout" ;;
  esac
  [ -f "$gsentinel" ] && bad "carry-forward still ran the test command — it must skip the run entirely" \
    || ok "and --carry-forward outranks --test-consent: the test command never runs"

  gstamp "$gsha" red
  grun --test-consent --carry-forward "sweep-tracker licensed a skip"
  case $gout in *"test: not-covered"*) ok "a red test-run stamp does not license a carry-forward" ;;
                *) bad "a red stamp carried anyway: $gout" ;;
  esac

  gstamp "${gsha}+dirty" green
  grun --test-consent --carry-forward "sweep-tracker licensed a skip"
  case $gout in *"test: not-covered"*) ok "a +dirty baseline does not license a carry-forward" ;;
                *) bad "a dirty stamp carried anyway: $gout" ;;
  esac
  rm -f "$gproj/.claude/WSS.SWEEPS.json"

  # --- a failing test is re-run exactly once before being reported ---------
  gcounter="$gproj/counter"; rm -f "$gcounter"
  gmanifest "{\"WSS\":{\"commands\":{\"test\":\"echo run >> $gcounter; exit 1\"}}}"
  grun
  [ "$grc" -eq 1 ] && ok "a test command that fails twice exits 1" || bad "exited $grc, not 1"
  case $gout in *"test: fail"*) ok "and reports fail" ;; *) bad "did not report fail: $gout" ;; esac
  case $gout in *"re-running in full before treating it as a finding"*) ok "the re-run is announced" ;;
                *) bad "no re-run announcement: $gout" ;;
  esac
  [ "$(wc -l < "$gcounter")" = 2 ] && ok "the command ran exactly twice, not once and not three times" \
    || bad "the command ran $(wc -l < "$gcounter") times, not twice"

  # A command that fails once then passes on retry: the re-run must change
  # the reported verdict, not just narrate itself.
  gflaky="$gproj/flaky-state"; rm -f "$gflaky"
  gmanifest "{\"WSS\":{\"commands\":{\"test\":\"test -f $gflaky && exit 0 || { touch $gflaky; exit 1; }\"}}}"
  grun
  [ "$grc" -eq 0 ] && ok "a test failing once then passing on retry exits 0" \
    || bad "a retry-recovered test still exited $grc"
  case $gout in *"test: pass"*) ok "and the verdict reports pass — the retry outcome is what counts" ;;
                *) bad "a retry-recovered test did not report pass: $gout" ;;
  esac

  # --- the dirty-tree note: three states, never via exit code (the note is
  # the only place a plausible-but-wrong "clean" answer at exit 0 could be
  # caught). Never pinned before this: the old behaviour (dirty reported
  # outside a git checkout too, for an unrelated reason) was deliberately
  # left unasserted so a fix would not have to fight its own test. -------
  gnonrepo="$ggdir/proj-nonrepo"; rm -rf "$gnonrepo"; mkdir -p "$gnonrepo/.claude"
  printf '{"WSS":{"commands":{"test":"true"}}}' > "$gnonrepo/.claude/WSS.WORKFLOW.json"
  if ( cd "$gnonrepo" && git rev-parse --is-inside-work-tree >/dev/null 2>&1 ); then
    bad "fixture check: $gnonrepo is unexpectedly inside a git work tree — the non-repo case below proves nothing"
  else
    ok "fixture check: $gnonrepo is confirmed outside any git work tree"
  fi
  out=$(cd "$gnonrepo" && bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1)
  case $out in *"note: not a git checkout — dirty-tree state unknown (+not-a-repo) — this run cannot license a carry-forward stamp"*)
      ok "outside a git checkout, the test section notes dirty-tree state unknown, not a silent clean" ;;
    *) bad "the not-a-repo dirty-tree note is missing: $out" ;;
  esac

  gmanifest '{"WSS":{"commands":{"test":"true"}}}'
  grun
  case $gout in *"note: tree is dirty"*|*"note: not a git checkout"*)
      bad "a clean git tree produced a dirty-tree note where none is due: $gout" ;;
    *) ok "a clean git tree prints no dirty-tree note at all" ;;
  esac

  printf 'dirty\n' >> "$gproj/f.txt"
  grun
  case $gout in *"note: tree is dirty (+dirty) — this run cannot license a carry-forward stamp"*)
      ok "a dirty git tree notes it and that it cannot license a carry-forward stamp" ;;
    *) bad "the dirty-tree note is missing on a dirty tree: $gout" ;;
  esac
  git -C "$gproj" checkout -q -- f.txt

  # --- CI resolution --------------------------------------------------------
  gmanifest '{}'
  gnongit="$ggdir/proj-nongit"; rm -rf "$gnongit"; mkdir -p "$gnongit/.claude"
  cp "$gproj/.claude/WSS.WORKFLOW.json" "$gnongit/.claude/" 2>/dev/null
  out=$(cd "$gnongit" && bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1)
  case $out in *"ci: unknown (sha unknown)"*) ok "outside a git checkout, ci reports unknown with no sha" ;;
               *) bad "a non-git directory did not report ci: unknown: $out" ;;
  esac

  gmanifest '{"WSS":{"commands":{"ci":{"tool":"gh"}}}}'
  gstubs="$ggdir/stubs-nogh"; path_without gh "$gstubs"
  out=$(cd "$gproj" && PATH="$gstubs" bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1)
  case $out in *"gh is not installed"*) ok "gh named but not on PATH is reported by name" ;;
               *) bad "a missing gh silently produced no message: $out" ;;
  esac
  case $out in *"ci: unknown"*) ok "and ci resolves as unknown, not a guess" ;;
               *) bad "a missing gh did not resolve ci as unknown: $out" ;;
  esac

  gstubgh="$ggdir/stubs-gh"; rm -rf "$gstubgh"; cp -r "$gstubs" "$gstubgh"
  cat > "$gstubgh/gh" <<GHEOF
#!/usr/bin/env bash
echo '[{"headSha":"$gsha","conclusion":"success","workflowName":"CI","createdAt":"2026-01-01T00:00:00Z"}]'
GHEOF
  chmod +x "$gstubgh/gh"
  out=$(cd "$gproj" && PATH="$gstubgh" bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1); rc=$?
  case $out in *"ci: green"*) ok "a successful run for HEAD's sha reports green" ;;
               *) bad "a successful CI run did not report green: $out" ;;
  esac
  [ "$rc" -eq 0 ] && ok "a green CI leaves the exit code untouched by CI" || bad "green CI still exited $rc"

  cat > "$gstubgh/gh" <<GHEOF
#!/usr/bin/env bash
echo '[{"headSha":"$gsha","conclusion":"failure","workflowName":"CI","createdAt":"2026-01-01T00:00:00Z"}]'
GHEOF
  chmod +x "$gstubgh/gh"
  out=$(cd "$gproj" && PATH="$gstubgh" bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1); rc=$?
  case $out in *"ci: red"*) ok "a failed run for HEAD's sha reports red" ;;
               *) bad "a red CI run did not report red: $out" ;;
  esac
  [ "$rc" -eq 1 ] && ok "and red CI is itself gate-worthy — exits 1" || bad "red CI exited $rc, not 1"

  cat > "$gstubgh/gh" <<'GHEOF'
#!/usr/bin/env bash
echo '[]'
GHEOF
  chmod +x "$gstubgh/gh"
  out=$(cd "$gproj" && PATH="$gstubgh" bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1)
  case $out in *"ci: no-ci"*) ok "zero CI runs ever reports no-ci, a standing finding" ;;
               *) bad "zero CI runs did not report no-ci: $out" ;;
  esac

  cat > "$gstubgh/gh" <<'GHEOF'
#!/usr/bin/env bash
echo '[{"headSha":"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef","conclusion":"success","workflowName":"CI","createdAt":"2026-01-01T00:00:00Z"}]'
GHEOF
  chmod +x "$gstubgh/gh"
  out=$(cd "$gproj" && PATH="$gstubgh" bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1); rc=$?
  case $out in *"ci: no-run-for-sha"*) ok "a run for a different sha reports no-run-for-sha, not a false pass" ;;
               *) bad "CI for a different sha was misreported: $out" ;;
  esac
  [ "$rc" -eq 0 ] && ok "no-run-for-sha is not itself a gate" || bad "no-run-for-sha exited $rc"

  gmanifest '{"WSS":{"commands":{"ci":{"tool":"circleci"}}}}'
  out=$(cd "$gproj" && bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1)
  case $out in *"ci: undeclared"*) ok "an unrecognised ci.tool value is treated as undeclared, not guessed at" ;;
               *) bad "an unrecognised ci.tool value was not treated as undeclared: $out" ;;
  esac

  gmanifest '{"WSS":{"commands":{"ci":"echo CI-RAW-MARKER"}}}'
  out=$(cd "$gproj" && bash "$ggdir/wss/scripts/wss-mechanical-gauntlet.sh" 2>&1)
  case $out in *CI-RAW-MARKER*) ok "a declared raw shell command for ci actually runs" ;;
               *) bad "the declared raw ci command never ran: $out" ;;
  esac
  case $out in *"ci: see-output"*) ok "and the verdict names it see-output rather than inventing green/red" ;;
               *) bad "a raw ci command's verdict was not see-output: $out" ;;
  esac
fi

# -------------------------------------------------------------- wss-sweep-stamp.sh

head_ "wss-sweep-stamp.sh: the self-computed baseline, and every named refusal"

STAMP="$_root/wss/scripts/wss-sweep-stamp.sh"
if [ ! -f "$STAMP" ]; then
  bad "wss-sweep-stamp.sh missing at $STAMP"
else
  bash -n "$STAMP" 2>/dev/null && ok "wss-sweep-stamp.sh parses" \
    || bad "wss-sweep-stamp.sh has a syntax error"

  ssdir="$TMP/sweepstamp"; rm -rf "$ssdir"; mkdir -p "$ssdir"
  git init -q "$ssdir" 2>/dev/null
  git -C "$ssdir" config user.email t@test; git -C "$ssdir" config user.name t
  git -C "$ssdir" config commit.gpgsign false
  printf 'x\n' > "$ssdir/f.txt"; git -C "$ssdir" add -A >/dev/null 2>&1
  git -C "$ssdir" commit -q -m first >/dev/null 2>&1
  printf '.claude/WSS.SWEEPS.json\n.claude/elsewhere.json\n' > "$ssdir/.gitignore"
  git -C "$ssdir" add .gitignore >/dev/null 2>&1
  git -C "$ssdir" commit -q -m gitignore >/dev/null 2>&1
  mkdir -p "$ssdir/.claude"
  ssha=$(git -C "$ssdir" rev-parse --short HEAD)

  srun() { # args... — sets sout, src; run from $ssdir
    sout=$(cd "$ssdir" && bash "$STAMP" "$@" 2>&1); src=$?
  }

  # --- usage --------------------------------------------------------------
  srun
  [ "$src" -eq 2 ] && ok "no arguments exits 2" || bad "no arguments exited $src"
  case $sout in *"<entry> --freshness"*"<entry> --test-run"*"<entry> --method"*)
      ok "usage prints all three invocation shapes" ;;
    *) bad "usage is missing one of the three shapes: $sout" ;;
  esac

  # --- THE property: baseline is self-computed, never accepted -------------
  srun entry1 --freshness
  [ "$src" -eq 0 ] && ok "freshness on a clean tree stamps" || bad "freshness stamp failed: $sout"
  recorded=$(jq -r '.entries.entry1.baseline' "$ssdir/.claude/WSS.SWEEPS.json")
  [ "$recorded" = "$ssha" ] && ok "the clean-tree baseline equals git rev-parse --short HEAD, independently computed" \
    || bad "baseline drifted from HEAD: recorded '$recorded', HEAD is '$ssha'"

  printf 'dirty\n' >> "$ssdir/f.txt"
  srun entry2 --freshness
  recorded=$(jq -r '.entries.entry2.baseline' "$ssdir/.claude/WSS.SWEEPS.json")
  [ "$recorded" = "${ssha}+dirty" ] && ok "a dirty tree suffixes the same sha with +dirty" \
    || bad "the +dirty baseline drifted: recorded '$recorded', expected '${ssha}+dirty'"

  # Proof the +dirty assertion is not vacuous: a copy whose dirty check is
  # forced to 0 must record the bare sha even on a dirty tree — this is the
  # exact defect the decision log's baseline-drift entry describes, made
  # reproducible on demand.
  sbroken="$ssdir/../broken-stamp.sh"
  sed 's/\[ -n "\$(git status --porcelain 2>\/dev\/null)" \] \&\& DIRTY=1/DIRTY=0/' "$STAMP" > "$sbroken"
  chmod +x "$sbroken"
  bout=$(cd "$ssdir" && bash "$sbroken" brokenentry --freshness 2>&1)
  brecorded=$(jq -r '.entries.brokenentry.baseline' "$ssdir/.claude/WSS.SWEEPS.json")
  [ "$brecorded" = "$ssha" ] && ok "proven: a copy with the dirty check forced off DOES lose the +dirty suffix — the guard above is not vacuous" \
    || bad "the broken copy failed to reproduce the lost-dirty-suffix bug: $brecorded"
  git -C "$ssdir" checkout -q -- f.txt

  srun entry3 --freshness --baseline deadbeef
  [ "$src" -eq 2 ] && ok "--baseline is not an accepted flag — rejected before any write" \
    || bad "--baseline was accepted (exit $src) instead of rejected"

  # --- refusals -------------------------------------------------------------
  ssnogit="$TMP/sweepstamp-nogit"; rm -rf "$ssnogit"; mkdir -p "$ssnogit"
  out=$(cd "$ssnogit" && bash "$STAMP" e --freshness 2>&1); rc=$?
  [ "$rc" -eq 1 ] && ok "outside a git work tree, refuses with exit 1" || bad "non-git dir exited $rc, not 1"
  case $out in *"not inside a git work tree"*) ok "and names why" ;; *) bad "no work-tree message: $out" ;; esac

  ssnoignore="$TMP/sweepstamp-noignore"; rm -rf "$ssnoignore"; mkdir -p "$ssnoignore"
  git init -q "$ssnoignore" 2>/dev/null
  git -C "$ssnoignore" config user.email t@test; git -C "$ssnoignore" config user.name t
  git -C "$ssnoignore" config commit.gpgsign false
  printf 'x\n' > "$ssnoignore/f.txt"; git -C "$ssnoignore" add -A >/dev/null 2>&1
  git -C "$ssnoignore" commit -q -m first >/dev/null 2>&1
  out=$(cd "$ssnoignore" && bash "$STAMP" e --freshness 2>&1); rc=$?
  [ "$rc" -eq 1 ] && ok "an ungitignored checkpoint path refuses, exit 1" || bad "ungitignored path exited $rc, not 1"
  case $out in *"is not gitignored"*) ok "and names the gitignore refusal" ;; *) bad "no gitignore refusal message: $out" ;; esac

  srun e --freshness --method full
  [ "$src" -eq 1 ] && ok "--freshness with a mode-exclusive flag is refused" || bad "mode conflict exited $src, not 1"
  case $sout in *"carries only baseline and at"*) ok "and names why" ;; *) bad "no mode-exclusivity message: $sout" ;; esac

  srun e --test-run --result green --scopes-file whatever
  [ "$src" -eq 1 ] && ok "--test-run with --scopes-file is refused — a suite is whole or not covered" \
    || bad "test-run+scopes-file exited $src, not 1"

  srun e --method full --complete true
  [ "$src" -eq 1 ] && ok "a scoped stamp with no --scopes-file is refused" || bad "missing scopes-file exited $src, not 1"
  case $sout in *"refusing a stamp with no coverage"*) ok "and cites Stamp step 1" ;; *) bad "no coverage-refusal message: $sout" ;; esac

  jq -n '[]' > "$ssdir/empty-scopes.json"
  srun e --method full --complete true --scopes-file empty-scopes.json
  [ "$src" -eq 1 ] && ok "an empty scopes array is refused the same way as a missing file" \
    || bad "empty scopes array exited $src, not 1"

  jq -n '[{"name":"a","covered":["x"]}]' > "$ssdir/bad-shape.json"
  srun e --method full --complete true --scopes-file bad-shape.json
  [ "$src" -eq 1 ] && ok "a scope missing 'not-covered' is refused" || bad "malformed scope exited $src, not 1"

  jq -n '[{"name":"dup","covered":[],"not-covered":[]},{"name":"dup","covered":[],"not-covered":[]}]' \
    > "$ssdir/dup-scopes.json"
  srun e --method full --complete true --scopes-file dup-scopes.json
  [ "$src" -eq 1 ] && ok "a duplicate scope name is refused" || bad "duplicate scope name exited $src, not 1"
  case $sout in *"duplicate scope name: dup"*) ok "and names the duplicate" ;; *) bad "duplicate not named: $sout" ;; esac

  srun e --test-run --result maybe
  [ "$src" -eq 1 ] && ok "--result outside green|red is refused" || bad "bad --result exited $src, not 1"

  srun e --method bogus --complete true --scopes-file "$ssdir/empty-scopes.json"
  [ "$src" -eq 1 ] && ok "--method outside incremental|full is refused" || bad "bad --method exited $src, not 1"

  jq -n '[{"name":"a","covered":[],"not-covered":[]}]' > "$ssdir/one-scope.json"
  srun e --method full --complete perhaps --scopes-file one-scope.json
  [ "$src" -eq 1 ] && ok "--complete outside true|false is refused" || bad "bad --complete exited $src, not 1"

  srun e --test-run --result green --test-count notanumber
  [ "$src" -eq 1 ] && ok "a non-numeric --test-count is refused" || bad "bad --test-count exited $src, not 1"

  srun e --test-run --result green --method incremental
  [ "$src" -eq 1 ] && ok "--test-run only accepts --method full, never incremental" \
    || bad "--test-run with --method incremental exited $src, not 1"

  # --- scoped and test-run stamps actually write the shape they claim ------
  srun scopedok --method incremental --complete false --scopes-file one-scope.json
  [ "$src" -eq 0 ] && ok "a valid scoped stamp writes" || bad "a valid scoped stamp failed: $sout"
  scopeout=$(jq -c '.entries.scopedok.scopes' "$ssdir/.claude/WSS.SWEEPS.json")
  [ "$scopeout" = '[{"name":"a","covered":[],"not-covered":[]}]' ] && ok "and carries the scopes file through unchanged" \
    || bad "the written scopes drifted from the input: $scopeout"

  srun trentry --test-run --result green --test-count 7
  [ "$src" -eq 0 ] && ok "a valid test-run stamp writes" || bad "a valid test-run stamp failed: $sout"
  trshape=$(jq -c '{method: .entries.trentry.method, complete: .entries.trentry.complete, result: .entries.trentry.result, tc: .entries.trentry."test-count"}' \
    "$ssdir/.claude/WSS.SWEEPS.json")
  [ "$trshape" = '{"method":"full","complete":true,"result":"green","tc":7}' ] \
    && ok "test-run defaults method to full and complete to true, and carries test-count" \
    || bad "the test-run shape drifted: $trshape"

  # --- existing-file guards --------------------------------------------------
  printf 'not json' > "$ssdir/.claude/WSS.SWEEPS.json"
  srun e --freshness
  [ "$src" -eq 1 ] && ok "an existing non-JSON checkpoint is refused, never overwritten blind" \
    || bad "invalid-JSON checkpoint exited $src, not 1"
  [ "$(cat "$ssdir/.claude/WSS.SWEEPS.json")" = "not json" ] && ok "and the bad file is left untouched" \
    || bad "the invalid checkpoint was overwritten despite the refusal"

  jq -n '{"sweep":"sweeps/v2","entries":{}}' > "$ssdir/.claude/WSS.SWEEPS.json"
  srun e --freshness
  [ "$src" -eq 1 ] && ok "an unrecognised sweep version is refused" || bad "wrong sweep version exited $src, not 1"

  # --- jq absent --------------------------------------------------------
  sstubs="$TMP/sweepstamp-stubs-nojq"; path_without jq "$sstubs"
  rm -f "$ssdir/.claude/WSS.SWEEPS.json"
  out=$(cd "$ssdir" && PATH="$sstubs" bash "$STAMP" e --freshness 2>&1); rc=$?
  [ "$rc" -eq 1 ] && ok "jq absent is refused rather than half-writing" || bad "jq-absent exited $rc, not 1"
  case $out in *"jq is required"*) ok "and names jq by name" ;; *) bad "no jq-required message: $out" ;; esac

  # --- declared checkpoint path, and the merge preserves other entries -----
  rm -f "$ssdir/.claude/WSS.SWEEPS.json" "$ssdir/.claude/elsewhere.json"
  printf '{"WSS":{"sweeps":".claude/elsewhere.json"}}\n' > "$ssdir/.claude/WSS.WORKFLOW.json"
  srun declaredentry --freshness
  [ -f "$ssdir/.claude/elsewhere.json" ] && ok "a declared WSS.sweeps path is written where it points" \
    || bad "the declared checkpoint path was not used: $sout"
  [ ! -f "$ssdir/.claude/WSS.SWEEPS.json" ] && ok "and the conventional path is left alone" \
    || bad "both the declared and conventional paths were written"
  rm -f "$ssdir/.claude/WSS.WORKFLOW.json"

  jq -n '{"sweep":"sweeps/v1","entries":{"preexisting":{"baseline":"abc1234","at":"2020-01-01"}}}' \
    > "$ssdir/.claude/WSS.SWEEPS.json"
  srun freshone --freshness
  keys=$(jq -c '.entries | keys' "$ssdir/.claude/WSS.SWEEPS.json")
  [ "$keys" = '["freshone","preexisting"]' ] && ok "stamping one entry leaves every other entry in place" \
    || bad "the merge disturbed entries it was not asked to touch: $keys"
fi

# ------------------------------------------------------------------- wss-orient.sh

head_ "wss-orient.sh: read-only, and it reports even with a broken manifest — never swallowed"

ORIENT="$_root/skills/start/assets/wss-orient.sh"
if [ ! -f "$ORIENT" ]; then
  bad "wss-orient.sh missing at $ORIENT"
else
  bash -n "$ORIENT" 2>/dev/null && ok "wss-orient.sh parses" \
    || bad "wss-orient.sh has a syntax error"

  odir="$TMP/orient"; rm -rf "$odir"; mkdir -p "$odir/.claude"
  git init -q "$odir" 2>/dev/null
  git -C "$odir" config user.email t@test; git -C "$odir" config user.name t
  git -C "$odir" config commit.gpgsign false
  printf 'x\n' > "$odir/f.txt"; git -C "$odir" add -A >/dev/null 2>&1
  git -C "$odir" commit -q -m first >/dev/null 2>&1

  orun() { out=$(cd "$odir" && bash "$ORIENT" 2>&1); orc=$?; }

  # --- no manifest at all: conventional names, and it is read-only ---------
  orun
  [ "$orc" -eq 0 ] && ok "no manifest at all still exits 0" || bad "no-manifest run exited $orc"
  case $out in *"note: no manifest — conventional fallback names in use"*)
      ok "and says so in words" ;;
    *) bad "the no-manifest note is missing: $out" ;;
  esac
  case $out in *"todo: wss/records/WSS.TODO.md — missing"*) ok "and the conventional todo name is what gets reported" ;;
               *) bad "the conventional todo fallback name did not appear: $out" ;;
  esac
  [ ! -f "$odir/.claude/WSS.SWEEPS.json" ] && ok "and it wrote nothing — read-only, as documented" \
    || bad "wss-orient.sh wrote a file it should never touch"

  # --- a malformed (not valid JSON) manifest: MUST still exit 0 and MUST
  # still print every section — the property this block exists to pin. It is
  # asserted on stdout CONTENT, not on $?, because a swallowed section would
  # still exit 0 under `set -u` alone.
  printf 'not valid json {{{' > "$odir/.claude/WSS.WORKFLOW.json"
  orun
  [ "$orc" -eq 0 ] && ok "a malformed manifest still exits 0" || bad "a malformed manifest exited $orc, not 0"
  for section in "== tree ==" "== CI ==" "== planning records ==" "== sweeps =="; do
    case $out in *"$section"*) ok "malformed manifest: '$section' still printed, not swallowed" ;;
                 *) bad "malformed manifest: '$section' is MISSING — output was swallowed: $out" ;;
    esac
  done
  # Proof the loop above is not vacuous: a copy where the malformed-JSON
  # branch aborts the script (a plausible regression of the "never swallowed"
  # claim this block exists to pin) must make every section above disappear
  # AND the exit-0 assertion fail. If it did not, the loop would be proving
  # nothing.
  obroken="$TMP/orient-broken-exit1.sh"
  sed 's/^  MANIFEST_INVALID=1$/  MANIFEST_INVALID=1\n  exit 1/' "$ORIENT" > "$obroken"
  bout=$(cd "$odir" && bash "$obroken" 2>&1); borc=$?
  [ "$borc" -ne 0 ] && ok "proven: a copy that aborts on malformed JSON does NOT exit 0 — the exit-0 assertion above is not vacuous" \
    || bad "the broken copy still exited 0 — the malformed-manifest exit-0 assertion proves nothing"
  case $bout in *"== sweeps =="*)
      bad "the broken copy still printed '== sweeps ==' — the swallow-detection loop above proves nothing" ;;
    *) ok "proven: the broken copy swallows every section below the note — the loop above is not vacuous" ;;
  esac

  # A present-but-invalid manifest used to differ from an absent one with no
  # note explaining the gap (previously a DISCREPANCY between the header's
  # claim and observed behavior). The note below is the fix: mget() still
  # resolves every key to "undeclared" for a malformed manifest — that part
  # of the old behavior is unchanged and still pinned here — but it is no
  # longer silent about doing so.
  case $out in *"todo: undeclared"*) ok "a malformed manifest still reads todo as undeclared, same as before" ;;
               *) bad "malformed-manifest todo resolution changed: $out" ;;
  esac
  omanifest=$(sed -n 's/^MANIFEST="\(.*\)"$/\1/p' "$ORIENT")
  case $out in *"note: $omanifest is not valid JSON — manifest unreadable, every key reads as undeclared"*)
      ok "and a malformed manifest now explains itself, closing the gap with the absent-manifest case" ;;
    *) bad "the malformed-manifest note is missing: $out" ;;
  esac

  # --- jq absent: DOES explain itself, unlike the malformed-manifest case --
  printf '{}\n' > "$odir/.claude/WSS.WORKFLOW.json"
  ostubs="$TMP/orient-stubs-nojq"; path_without jq "$ostubs"
  out=$(cd "$odir" && PATH="$ostubs" bash "$ORIENT" 2>&1); orc=$?
  [ "$orc" -eq 0 ] && ok "jq absent still exits 0" || bad "jq-absent run exited $orc, not 0"
  case $out in *"note: jq unavailable"*) ok "and jq's absence IS explained in a note" ;;
               *) bad "jq-absent note is missing: $out" ;;
  esac

  # --- CI: undeclared vs gh unreachable, never silent -----------------------
  rm -f "$odir/.claude/WSS.WORKFLOW.json"
  orun
  case $out in *"ci: undeclared — nothing to check"*) ok "no ci.workflow declared reads as undeclared" ;;
               *) bad "undeclared CI did not say so: $out" ;;
  esac

  # --- delegates sweep distance rather than recomputing it -------------------
  gsha_o=$(git -C "$odir" rev-parse --short HEAD)
  jq -n --arg b "$gsha_o" '{entries:{demo:{baseline:$b, at:"2026-01-01"}}}' > "$odir/.claude/WSS.SWEEPS.json"
  orun
  case $out in *"demo: baseline $gsha_o"*"0 commits behind HEAD"*)
      ok "sweep freshness for a fresh entry is composed via wss-sweep-distance.sh, not recomputed" ;;
    *) bad "sweep freshness output drifted from wss-sweep-distance.sh's own shape: $out" ;;
  esac

  # --- lane override on the todo record --------------------------------------
  printf '{"WSS":{"record":{"todo":"WSS.TODO.md"},"lanes":{"named":{"mylane":{"records":{"todo":"WSS.TODO.mylane.md"}}}}}}\n' \
    > "$odir/.claude/WSS.WORKFLOW.json"
  printf 'mylane\n' > "$odir/.claude/WSS.LANE"
  printf 'x\n' > "$odir/WSS.TODO.mylane.md"
  orun
  case $out in *"lane: mylane"*) ok "the active lane is read from .claude/WSS.LANE" ;;
               *) bad "lane was not read: $out" ;;
  esac
  case $out in *"todo: WSS.TODO.mylane.md"*) ok "and the lane's record override is used, not the base record" ;;
               *) bad "the lane override did not apply: $out" ;;
  esac
  rm -f "$odir/.claude/WSS.LANE" "$odir/.claude/WSS.WORKFLOW.json" "$odir/WSS.TODO.mylane.md"

  # --- a provider-backed todo has no file, and it is reported that way ------
  printf '{"WSS":{"record":{"todo":{"provider":"github"}}}}\n' > "$odir/.claude/WSS.WORKFLOW.json"
  orun
  case $out in *"todo: github provider — no file to measure"*) ok "a provider-backed todo names the provider, not a missing file" ;;
               *) bad "provider-backed todo was not reported correctly: $out" ;;
  esac
fi

# --------------------------------------------------------------- wss-docs-audit.sh

head_ "wss-docs-audit.sh: the mechanical half's resolve step, declared vs fallback"

DOCSAUDIT="$_root/wss/scripts/wss-docs-audit.sh"
if [ ! -f "$DOCSAUDIT" ]; then
  bad "wss-docs-audit.sh missing at $DOCSAUDIT"
else
  bash -n "$DOCSAUDIT" 2>/dev/null && ok "wss-docs-audit.sh parses" \
    || bad "wss-docs-audit.sh has a syntax error"

  dadir="$TMP/docsaudit"; rm -rf "$dadir"; mkdir -p "$dadir"
  git init -q "$dadir" 2>/dev/null

  darun() { out=$(cd "$dadir" && bash "$DOCSAUDIT" "$@" 2>&1); drc=$?; }

  # --- no docs root resolves: every check is skipped, not silently clean ----
  darun resolve
  [ "$drc" -eq 0 ] && ok "resolve with no docs root exits 0" || bad "no-root resolve exited $drc"
  case $out in *"no docs root resolves — this project has no site"*)
      ok "and says so, rather than a false-clean pass" ;;
    *) bad "no-root NOTE missing: $out" ;;
  esac
  darun dead-paths
  case $out in *"SKIPPED: no docs root"*) ok "a section short-circuits to SKIPPED with no root, via require_docs" ;;
               *) bad "dead-paths did not skip cleanly with no root: $out" ;;
  esac

  # --- directory fallback: first of wss/docs/ docs/ doc/ documentation/ website/
  mkdir -p "$dadir/documentation"
  darun resolve
  case $out in *"docs root: documentation   (fallback: first existing of wss/docs/ docs/ doc/ documentation/ website/)"*)
      ok "the directory fallback picks the first existing conventional name" ;;
    *) bad "directory fallback drifted: $out" ;;
  esac
  rm -rf "$dadir/documentation"

  # --- declared root wins over a directory that would also fall back --------
  mkdir -p "$dadir/.claude" "$dadir/docs" "$dadir/customroot"
  printf '{"WSS":{"docs":{"root":"customroot"}}}\n' > "$dadir/.claude/WSS.WORKFLOW.json"
  darun resolve
  case $out in *"docs root: customroot   (WSS.docs.root in .claude/WSS.WORKFLOW.json)"*)
      ok "a declared WSS.docs.root wins over an existing docs/ directory" ;;
    *) bad "declared root did not win over the directory fallback: $out" ;;
  esac
  # Proof the assertion above is not vacuous: a copy where the directory scan
  # always runs (even when a declared root already resolved) must let docs/
  # win instead. If it did not, the "declared root wins" assertion above
  # would be proving nothing.
  dabroken="$TMP/docsaudit-broken-priority.sh"
  sed 's/^if \[ -z "\$DOCS" \]; then$/if true; then/' "$DOCSAUDIT" > "$dabroken"
  bout=$(cd "$dadir" && bash "$dabroken" resolve 2>&1)
  case $bout in *"docs root: docs   (fallback:"*)
      ok "proven: a copy that always rescans directories DOES let docs/ win over the declared root — the guard above is not vacuous" ;;
    *) bad "the broken copy failed to reproduce lost declared-root priority — the guard above proves nothing: $bout" ;;
  esac

  # --- declared languages: first is root language, rest are translations ----
  printf '{"WSS":{"docs":{"root":"customroot","languages":["en","fr","es"],"devCommand":"npm run dev"}}}\n' \
    > "$dadir/.claude/WSS.WORKFLOW.json"
  darun resolve
  case $out in *"languages: en fr es   (WSS.docs.languages in .claude/WSS.WORKFLOW.json)"*)
      ok "declared languages are read, root language first" ;;
    *) bad "declared languages did not resolve: $out" ;;
  esac
  case $out in *"devCommand: npm run dev"*) ok "and the declared devCommand is read" ;;
               *) bad "declared devCommand did not resolve: $out" ;;
  esac
  rm -f "$dadir/.claude/WSS.WORKFLOW.json"

  # --- monolingual fallback: absent languages means no translation check ----
  darun resolve
  case $out in *"NOTE: monolingual — the translation-parity check (translations) is skipped."*)
      ok "no declared languages falls back to monolingual" ;;
    *) bad "monolingual fallback missing: $out" ;;
  esac
  case $out in *"NOTE: no WSS.docs.devCommand — the live-render step (inside mechanics) is skipped."*)
      ok "no declared devCommand skips the live-render step, named" ;;
    *) bad "devCommand skip note missing: $out" ;;
  esac

  # --- an undeclared WSS_MANIFEST override still resolves the declared root -
  printf '{"WSS":{"docs":{"root":"customroot"}}}\n' > "$dadir/alt-manifest.json"
  out=$(cd "$dadir" && WSS_MANIFEST=alt-manifest.json bash "$DOCSAUDIT" resolve 2>&1)
  case $out in *"docs root: customroot   (WSS.docs.root in alt-manifest.json)"*)
      ok "WSS_MANIFEST overrides which manifest file is read" ;;
    *) bad "WSS_MANIFEST override did not take effect: $out" ;;
  esac
  rm -f "$dadir/alt-manifest.json"

  # --- a malformed manifest DOES warn and fall back — unlike wss-orient.sh's
  # equivalent case above, which silently reads every key as undeclared with
  # no note at all. Documented here as the contrast, not a defect in this
  # script.
  printf 'not valid json {{{' > "$dadir/.claude/WSS.WORKFLOW.json"
  darun resolve
  case $out in *"WSS.docs cannot be read"*"Falling back to directory/monolingual defaults"*)
      ok "a malformed manifest is named as unreadable, and the fallback is announced" ;;
    *) bad "malformed-manifest warning missing: $out" ;;
  esac
  case $out in *"docs root: docs"*) ok "and the directory fallback actually applies (docs/ still exists)" ;;
               *) bad "the fallback did not apply after the malformed-manifest warning: $out" ;;
  esac
  rm -f "$dadir/.claude/WSS.WORKFLOW.json"

  # --- jq absent: same shape of warning as the malformed-manifest case ------
  dastubs="$TMP/docsaudit-stubs-nojq"; path_without jq "$dastubs"
  printf '{"WSS":{"docs":{"root":"customroot"}}}\n' > "$dadir/.claude/WSS.WORKFLOW.json"
  out=$(cd "$dadir" && PATH="$dastubs" bash "$DOCSAUDIT" resolve 2>&1)
  case $out in *"jq is not installed"*"WSS.docs cannot be read"*) ok "jq absent is named, distinct from a malformed manifest" ;;
               *) bad "jq-absent warning missing: $out" ;;
  esac
  case $out in *"docs root: docs"*) ok "and still falls back to the directory convention rather than crashing" ;;
               *) bad "jq-absent did not fall back cleanly: $out" ;;
  esac
  rm -f "$dadir/.claude/WSS.WORKFLOW.json"

  # --- an unknown section name exits 2, after resolve has already run -------
  darun bogus-section-name
  [ "$drc" -eq 2 ] && ok "an unknown section name exits 2" || bad "unknown section exited $drc, not 2"
  case $out in *"== resolve =="*"unknown section 'bogus-section-name'"*)
      ok "resolve still ran first, then the unknown-section error was reported" ;;
    *) bad "resolve did not run before the unknown-section error: $out" ;;
  esac

  # --- dead-paths: a real check against a real fixture, not just a skip -----
  mkdir -p "$dadir/docs" "$dadir/src"
  printf 'See `src/thing.js`, but `src/missing.js` does not exist.\n' > "$dadir/docs/page.md"
  printf 'x\n' > "$dadir/src/thing.js"
  git -C "$dadir" add -A >/dev/null 2>&1
  darun dead-paths
  case $out in *"MISSING: src/missing.js"*) ok "dead-paths finds a backticked path that does not exist on disk" ;;
               *) bad "dead-paths did not catch a real missing path: $out" ;;
  esac
  case $out in *"MISSING: src/thing.js"*) bad "dead-paths flagged a path that DOES exist" ;;
               *) ok "and does not flag the path that does exist" ;;
  esac
fi

# ------------------------------------------------------------ wss-skill-levels.sh

head_ "wss-skill-levels.sh: skill-toggle step 1's level table, per-skill settings precedence"

LEVELS="$_root/skills/skill-toggle/assets/wss-skill-levels.sh"
if [ ! -f "$LEVELS" ]; then
  bad "wss-skill-levels.sh missing at $LEVELS"
else
  bash -n "$LEVELS" 2>/dev/null && ok "wss-skill-levels.sh parses" \
    || bad "wss-skill-levels.sh has a syntax error"

  # Fixture: a "user" tree (levels-conf, playing CLAUDE_CONFIG_DIR) carrying
  # alpha/beta/gamma — gamma's frontmatter hides it — with alpha and beta
  # overridden in its settings.json; a "project" tree (levels-proj, playing
  # $PWD) carrying delta, with its own settings.json overriding alpha again,
  # which must win over the user file for the same skill. HOME and
  # CLAUDE_CONFIG_DIR are both set away from the real ~/.claude on every run
  # below — without both, this repo's own dirty settings.json is what gets
  # rendered and every assertion below passes for the wrong reason.
  lconf="$TMP/levels-conf"; lproj="$TMP/levels-proj"
  rm -rf "$lconf" "$lproj"
  mkdir -p "$lconf/skills/alpha" "$lconf/skills/beta" "$lconf/skills/gamma"
  printf -- '---\nname: alpha\n---\nbody\n' > "$lconf/skills/alpha/SKILL.md"
  printf -- '---\nname: beta\n---\nbody\n' > "$lconf/skills/beta/SKILL.md"
  printf -- '---\nname: gamma\ndisable-model-invocation: true\n---\nbody\n' > "$lconf/skills/gamma/SKILL.md"
  printf '{"skillOverrides":{"alpha":"name-only","beta":"off"}}\n' > "$lconf/settings.json"
  mkdir -p "$lproj/.claude/skills/delta"
  printf -- '---\nname: delta\n---\nbody\n' > "$lproj/.claude/skills/delta/SKILL.md"
  printf '{"skillOverrides":{"alpha":"user-invocable-only"}}\n' > "$lproj/.claude/settings.json"
  lconf_before=$(cat "$lconf/settings.json")

  lrun() { out=$(cd "$lproj" && HOME="$TMP/home" CLAUDE_CONFIG_DIR="$lconf" bash "$LEVELS" "$@" 2>&1); lrc=$?; }

  # --- basic shape ------------------------------------------------------
  lrun
  [ "$lrc" -eq 0 ] && ok "exits 0 on the fixture" || bad "fixture run exited $lrc: $out"
  case $out in "") bad "output is empty" ;;
               *) ok "output is non-empty" ;;
  esac
  case $out in *"== skill-toggle: effective skill levels =="*) ok "and carries the header line" ;;
               *) bad "header line missing: $out" ;;
  esac
  case $out in *"skill"*"level"*"set by"*"tree"*"frontmatter"*) ok "the header row's five columns print" ;;
               *) bad "header row columns missing: $out" ;;
  esac

  # --- each fixture skill appears as its own row — four separate assertions,
  # so a partial render (e.g. only the first tree scanned) cannot pass -------
  case $out in *"alpha "*) ok "fixture skill 'alpha' appears as a row" ;;
               *) bad "fixture skill 'alpha' is MISSING from the output: $out" ;;
  esac
  case $out in *"beta "*) ok "fixture skill 'beta' appears as a row" ;;
               *) bad "fixture skill 'beta' is MISSING from the output: $out" ;;
  esac
  case $out in *"gamma "*) ok "fixture skill 'gamma' appears as a row" ;;
               *) bad "fixture skill 'gamma' is MISSING from the output: $out" ;;
  esac
  case $out in *"delta "*) ok "fixture skill 'delta' appears as a row" ;;
               *) bad "fixture skill 'delta' is MISSING from the output: $out" ;;
  esac

  # --- per-skill precedence and the columns that prove it ------------------
  case $out in *"alpha "*"user-invocable-only"*"project"*)
      ok "alpha reads user-invocable-only, set by project — project outranks user for the same skill" ;;
    *) bad "alpha's project-wins precedence did not hold: $out" ;;
  esac
  case $out in *"beta "*"off"*"user"*) ok "beta reads off, set by user" ;;
               *) bad "beta did not read off, set by user: $out" ;;
  esac
  case $out in *"gamma "*"(no entry)"*"hidden"*) ok "gamma reads (no entry) with frontmatter hidden" ;;
               *) bad "gamma's (no entry)/hidden reading did not hold: $out" ;;
  esac
  case $out in *"delta "*"project"*) ok "delta reads tree project" ;;
               *) bad "delta's tree did not read project: $out" ;;
  esac

  # The design brief for this fixture asserted "4 skills, 3 with an override".
  # The fixture as specified overrides only alpha (project settings.json) and
  # beta (user settings.json) — gamma and delta carry no settings entry at
  # all — so the verified figure against this exact fixture is 2, not 3. That
  # is a discrepancy in the brief, not in this script; asserted here against
  # the actual fixture rather than the brief's arithmetic.
  case $out in *"4 skills, 2 with an override"*) ok "summary line reads 4 skills, 2 with an override, against the fixture only" ;;
               *) bad "summary line drifted from the fixture: $out" ;;
  esac

  # --- non-vacuity: prove the row/summary assertions above are not passing
  # on an empty read, the same proof-copy technique as wss-orient.sh's block.
  # A copy whose tree enumeration is neutered must make the alpha row vanish
  # AND must not exit 0 — printing no table is this script's own refusal
  # contract for an enumeration that turns up nothing.
  lbroken="$TMP/levels-broken-empty-tree.sh"
  sed 's#for d in "\$TREE"/\*/; do#for d in "/nonexistent-neutered-tree"/*/; do#' "$LEVELS" > "$lbroken"
  bout=$(cd "$lproj" && HOME="$TMP/home" CLAUDE_CONFIG_DIR="$lconf" bash "$lbroken" 2>&1); brc=$?
  case $bout in *"alpha "*) bad "the neutered copy still shows an alpha row — the row assertions above prove nothing" ;;
                *) ok "proven: a copy whose tree enumeration is neutered shows no alpha row" ;;
  esac
  [ "$brc" -ne 0 ] && ok "proven: and its exit is not 0 — the row assertions above are not vacuous" \
                   || bad "the neutered copy still exited 0 — the row assertions above prove nothing"

  # --- settings.local.json is never read ------------------------------------
  printf '{"skillOverrides":{"beta":"name-only"}}\n' > "$lproj/.claude/settings.local.json"
  lrun
  case $out in *"beta "*"off"*) ok "settings.local.json is not read — beta still reads off" ;;
               *) bad "a settings.local.json entry changed beta's reading: $out" ;;
  esac
  rm -f "$lproj/.claude/settings.local.json"

  # --- no jq on PATH: refuses, prints no table ------------------------------
  lstubs="$TMP/levels-stubs-nojq"; path_without jq "$lstubs"
  out=$(cd "$lproj" && HOME="$TMP/home" CLAUDE_CONFIG_DIR="$lconf" PATH="$lstubs" bash "$LEVELS" 2>&1); lrc=$?
  [ "$lrc" -eq 1 ] && ok "no jq on PATH exits 1" || bad "jq-absent run exited $lrc, not 1"
  case $out in *"alpha "*) bad "jq-absent output still shows an alpha row — a table was rendered" ;;
               *) ok "and no alpha row appears — no table rendered" ;;
  esac

  # --- no skills tree at all: exits 1, table absent -------------------------
  out=$(cd "$TMP/bare" && HOME="$TMP/home" CLAUDE_CONFIG_DIR="$TMP/bare" bash "$LEVELS" 2>&1); lrc=$?
  [ "$lrc" -eq 1 ] && ok "no skills tree at all exits 1" || bad "no-tree run exited $lrc, not 1"
  case $out in *"== skill-toggle: effective skill levels =="*) bad "no-tree run still printed a table" ;;
               *) ok "and the table is absent" ;;
  esac

  # --- usage --------------------------------------------------------------
  lrun --bogus-flag
  [ "$lrc" -eq 2 ] && ok "an unknown argument exits 2" || bad "unknown argument exited $lrc, not 2"
  lrun --help
  [ "$lrc" -eq 0 ] && ok "--help exits 0" || bad "--help exited $lrc, not 0"
  case $out in *"wss-skill-levels.sh"*) ok "and --help prints the usage" ;;
               *) bad "--help printed no usage: $out" ;;
  esac

  # --- read-only, after every run above -------------------------------------
  lconf_after=$(cat "$lconf/settings.json")
  [ "$lconf_before" = "$lconf_after" ] && ok "the user settings.json is byte-identical after every run above" \
    || bad "the user settings.json changed — wss-skill-levels.sh is documented read-only"
  lnew=$(find "$lproj/.claude" -type f ! -name SKILL.md ! -name settings.json 2>/dev/null)
  [ -z "$lnew" ] && ok "no new file exists under the project .claude/ after every run above" \
    || bad "a new file appeared under $lproj/.claude: $lnew"

  # --- plugin skills: listed separately, never merged into the main table --
  lplugin="$TMP/levels-plugin"; rm -rf "$lplugin"
  mkdir -p "$lplugin/skills/epsilon"
  printf -- '---\nname: epsilon\n---\nbody\n' > "$lplugin/skills/epsilon/SKILL.md"
  out=$(cd "$lproj" && HOME="$TMP/home" CLAUDE_CONFIG_DIR="$lconf" CLAUDE_PLUGIN_ROOT="$lplugin" bash "$LEVELS" 2>&1); lrc=$?
  case $out in *"== plugin skills (not controllable here) =="*) ok "plugin skills print their own section header" ;;
               *) bad "plugin section header missing: $out" ;;
  esac
  case $out in *"epsilon"*) ok "and epsilon appears in the plugin section" ;;
               *) bad "epsilon is missing from the plugin section: $out" ;;
  esac
  main_table=$(printf '%s\n' "$out" | sed -n '/^== skill-toggle: effective skill levels ==$/,/^$/p')
  case $main_table in *"epsilon"*) bad "epsilon leaked into the main skill-levels table" ;;
                      *) ok "and epsilon does NOT appear in the main table" ;;
  esac
fi

head_ "Result"
if [ $fail -gt 0 ]; then
  printf '  \033[31m%d failed\033[0m, %d passed\n\n' "$fail" "$pass"; exit 1
fi
printf '  \033[32mall %d passed\033[0m\n\n' "$pass"
