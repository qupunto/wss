#!/usr/bin/env bash
# Diagnose this machine's Claude Code configuration. Read-only: it reports and
# changes nothing, so it is safe to run anywhere, any time.
#
#   ~/.claude/wss-doctor.sh          # checks the config, and the project in $PWD
#   ~/.claude/wss-doctor.sh --strict # ...and exit 1 on warnings too
#
# Exit 0 if everything passed, 1 if anything FAILED. Warnings do not fail a run
# unless --strict is given, which CI does give.
#
# Why --strict is CI-only and not the default. The warn class exists for things
# that are not always wrong — a dirty working tree, a flag whose skill this
# particular project does not have — so making it fatal locally would train
# people to stop reading the output. But in CI the warn class also carries the
# real drift: "flag maps to a skill that resolves nowhere", and "grants disagree
# between the hook and WSS.OWNERSHIP.md". Those landed GREEN until 2026-08-01,
# which made the grant check decorative.
#
# Why this exists. Three failures cost real time before it did, and none of them
# had a symptom:
#
#   1. This repo was never adopted on the second machine, so wss-shorthand-flags.sh
#      was simply absent and every --flag silently degraded to model judgement.
#      The flags mostly still worked, so nothing looked wrong.
#   2. Two skills cited `track` as an authority while it resolved
#      to nothing in that project. A dangling reference reads exactly like a
#      live one.
#   3. The repo's own .gitignore ignored README.md and docs/, so documentation
#      written for it could not be committed at all — and `git add` said nothing.
#
# All three are one-line checks. None is findable by reading the file that is
# wrong, which is why reading did not find them.

set -u

STRICT=0
for arg in "$@"; do
  case $arg in
    --strict) STRICT=1 ;;
    *) echo "wss-doctor.sh: unknown argument '$arg' (only --strict)" >&2; exit 2 ;;
  esac
done

# CLAUDE_CONFIG_DIR is Claude Code's OWN variable and the one wss-session-check.sh
# reads; CLAUDE_DIR was this script's private invention. Reading only the latter
# meant `CLAUDE_CONFIG_DIR=/x claude` ran /x/wss-doctor.sh, which then inspected
# $HOME/.claude and reported clean on a directory that was not the one under
# inspection. Accept both, Claude Code's name first, and keep CLAUDE_DIR working
# because CI passes it.
#
# TWO directories, and they coincide in a checkout — which is exactly why one
# variable did both jobs unnoticed until 2026-08-01:
#
#   CONFIG_DIR  the user's ~/.claude. Cross-project state lives here and must
#               SURVIVE a plugin update, so nothing under it may be resolved
#               against the plugin root.
#   CLAUDE_DIR  the installation being inspected — skills/, workflow/, hooks/,
#               agents/. Under a plugin install that is CLAUDE_PLUGIN_ROOT, a
#               path like ~/.claude/plugins/<marketplace>/<plugin>/ that CHANGES
#               on every update.
#
# Installed as a plugin with these conflated, every check below looked for the
# installation inside ~/.claude, found no skills/ and no hooks/, and reported on
# a directory that holds none of what it was inspecting.
#
# The fix separated the two directories and then left CLAUDE_DIR's FALLBACK
# pointing the old way — at CONFIG_DIR — which is wrong wherever the two
# differ, and they differ in every plugin install. $CLAUDE_PLUGIN_ROOT is set
# for hook processes but is EMPTY in a model-run Bash command, and running the
# doctor by hand is exactly that. So the resolver every skill prescribes would
# launch the doctor FROM the plugin root, and the doctor would then inspect the
# adopter's own ~/.claude, find no skills/ and no hooks/, and report three
# failures and an empty skill enumeration on a perfectly good install. Measured
# 2026-08-02 on a simulated adopter, against the tree published that day.
#
# So the doctor asks where IT lives. It ships with the installation it inspects
# — that is why it stays at the root rather than moving into hooks/ — and its
# own path needs no environment to be known.
#
# But only when that location is a PLUGIN root, never merely because it is where
# the file sits. `CLAUDE_CONFIG_DIR` pointing the doctor at a whole synthetic
# installation is how tests/wss-hook-contract.sh drives it, and an unconditional
# self-preference would silently ignore that and read the real tree instead —
# every fixture would then be reported clean by a doctor that never looked at it,
# which is this file's own most-feared failure.
# `pwd -P`, not `pwd`: a checkout reached through a symlink reports the LOGICAL
# path, which matches nothing it should match. That alone made a real checkout
# announce "installed as a plugin" and silently drop the credentials and
# settings.json checks — the precise failure the paragraph above exists to
# prevent, reintroduced by the fix for it.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"

# An installed plugin is identified by WHERE IT LIVES, not by whether it happens
# to carry a `.git`. The first version of this test asked "am I not the toplevel
# of a checkout", which is not a property of being a plugin at all: a plugin
# fetched from a git-hosted marketplace over SSH IS a clone and IS its own
# toplevel, so it answered no and the doctor went back to inspecting the
# adopter's config directory. Measured on a real cached install.
#
# The cache layout — `plugins/cache/<marketplace>/<plugin>/<version>/` — is
# documented and has been measured on every install shape observed, and
# `$CLAUDE_PLUGIN_ROOT` overrides this whenever the harness supplies it. If the
# platform ever moves the cache, this returns 0 and the doctor falls back to the
# config directory: loud failures on a plugin install rather than a silent wrong
# answer, which is the correct direction to fail in.
is_plugin_root() { # dir
  [ -n "$1" ] && [ -f "$1/.claude-plugin/plugin.json" ] &&
  case "$1" in */plugins/cache/*) true ;; *) false ;; esac
}
SELF_IS_PLUGIN=0
is_plugin_root "$SELF_DIR" && SELF_IS_PLUGIN=1

# Precedence, highest first, and each level exists because the one below it is
# a guess:
#
#   $CLAUDE_PLUGIN_ROOT  the harness knows; it is never wrong when set.
#   $CLAUDE_DIR          the CALLER knows, and said so explicitly.
#   SELF_IS_PLUGIN       this script's own location, when that is a plugin root.
#   $CONFIG_DIR          the last resort.
#
# The $CLAUDE_DIR level is what lets a caller inspect an installation that is
# not the one this script sits in. Without it, running the SHIPPED tests from
# inside a plugin cache failed 21 of 162: every fixture says "inspect this
# directory" via CLAUDE_CONFIG_DIR, and the cached doctor correctly preferred
# itself, so the fixtures were never read. A stranger's most obvious diagnostic
# reported a healthy install as broken — which is worse than no test at all,
# because it is a confident wrong answer.
CLAUDE_DIR_ENV="${CLAUDE_DIR:-}"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${CLAUDE_DIR_ENV:-$HOME/.claude}}"
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  CLAUDE_DIR="$CLAUDE_PLUGIN_ROOT"
elif [ -n "$CLAUDE_DIR_ENV" ]; then
  CLAUDE_DIR="$CLAUDE_DIR_ENV"
elif [ $SELF_IS_PLUGIN -eq 1 ]; then
  CLAUDE_DIR="$SELF_DIR"
else
  CLAUDE_DIR="$CONFIG_DIR"
fi
fails=0
warns=0

# The same configuration runs in two layouts: as ~/.claude, and as an installed
# plugin. Two checks below apply only to the first — a plugin is not a git
# checkout and does not own settings.json — so running them either way reports
# failures that are not failures, and a doctor that cries wolf stops being run.
#
# Detecting it by the presence of `.claude-plugin/plugin.json` ALONE was correct
# only while this repo had no such file. Adding the manifest on 2026-08-01 made
# the source repository detect itself as an installed plugin, which silently
# switched off the credentials check and the settings.json hook-wiring check in
# the one checkout that must never lose them — a check that disappears reports
# nothing, so the doctor would have gone on printing "all checks passed".
#
# So ask the harness first: CLAUDE_PLUGIN_ROOT is set by Claude Code only when
# actually running from a plugin install, and is the authority when it is
# talking about the directory being inspected.
#
# **"Fall back to the manifest where this is NOT a git checkout" was the rule
# here and it was wrong**, twice over, which is why the test below asks about
# the cache path instead. A plugin fetched from a git-hosted marketplace over
# SSH *is* a clone and *is* its own toplevel; and a checkout reached through a
# symlink reports a logical path that matches no toplevel, so it read as a
# plugin and dropped the very credentials check the paragraph above is about.
# Both were measured, not argued.
# Keyed on CLAUDE_DIR — the installation being INSPECTED — never on where this
# script happens to sit. Those are the same place in every real use and differ
# in exactly one: a caller pointing the doctor at another installation, which is
# what the whole test suite does. Keying it on the script's location meant a
# cached doctor applied plugin-shaped checks to a checkout-shaped fixture and
# demanded a hooks.json the fixture had no business having.
#
# The CLAUDE_PLUGIN_ROOT clause is not redundant with is_plugin_root(): a
# local-directory marketplace resolves the root to the source folder, which
# carries no `plugins/cache/` segment. It is the documented outlier, and the
# harness saying so is the authority when it is talking about the same directory.
PLUGIN_MODE=0
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ "$CLAUDE_DIR" = "$CLAUDE_PLUGIN_ROOT" ]; then
  PLUGIN_MODE=1
elif is_plugin_root "$CLAUDE_DIR"; then
  # The same test, for the case where CLAUDE_DIR was pointed at an install by
  # path rather than being where this script sits. Deliberately the SAME
  # function: two different answers to "is this a plugin" is how the credentials
  # check gets switched off in one place and left on in another.
  PLUGIN_MODE=1
fi

pass()  { printf '  \033[32mok\033[0m    %s\n' "$1"; }
fail()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails + 1)); }
warn()  { printf '  \033[33mwarn\033[0m  %s\n' "$1"; warns=$((warns + 1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# "FAIL" is load-bearing in this string, not decoration: wss-session-check.sh greps
# the doctor's output for that literal to decide whether a SessionStart is worth
# interrupting. Without it, a machine missing jq had a silent doctor AND a silent
# session hook — two nets down at once, and no symptom.
command -v jq >/dev/null 2>&1 || { echo "  FAIL  wss-doctor.sh needs jq — no other check below ran"; exit 1; }

# Resolve a `file#anchor` pointer: does that file contain a heading whose
# GitHub slug is that anchor? Keyed hazard pointers in WSS.WORKFLOW.json are only
# worth having if the anchor half is real, and checking the filename alone
# reports success for a pointer that lands nowhere.
#
# These regexes are copied deliberately, not reinvented. Note the last one is
# `\s` and NOT `\s+`: GitHub replaces each space with its own hyphen rather than
# collapsing runs, so a heading with a dropped character between two spaces
# ("JWT + rotating") yields a DOUBLE hyphen. Collapsing produces anchors that
# look right and 404.
ANCHOR_PY='
import re, sys
def slug(t):
    a = t.lower()
    a = re.sub(r"[`*_\[\]()]", "", a)
    a = re.sub(r"[^\w\s-]", "", a)
    return re.sub(r"\s", "-", a.strip())
want = sys.argv[2]
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if line.startswith("#") and slug(line.lstrip("#").strip()) == want:
        sys.exit(0)
sys.exit(1)
'

# ---------------------------------------------------------------- the checkout

head_ "Configuration directory"

[ -d "$CLAUDE_DIR" ] || { fail "$CLAUDE_DIR does not exist"; exit 1; }
pass "$CLAUDE_DIR exists"

if [ $PLUGIN_MODE -eq 1 ]; then
  # jq on an absent or unreadable file writes nothing to stdout, so the // here
  # never fires and the line rendered "installed as a plugin ()". The name is
  # the one thing this line exists to report; empty must say so.
  plugin_name=$(jq -r '.name // empty' "$CLAUDE_DIR/.claude-plugin/plugin.json" 2>/dev/null)
  pass "installed as a plugin (${plugin_name:-unnamed}) — not a checkout, as expected"
elif git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  pass "tracked by git, origin: $(git -C "$CLAUDE_DIR" remote get-url origin 2>/dev/null || echo '(none)')"
  [ -n "$(git -C "$CLAUDE_DIR" status --porcelain 2>/dev/null)" ] &&
    warn "working tree dirty — this machine has config not yet committed"
else
  fail "not a git checkout. This machine is not running the configuration repo,
        so whatever passes below does so by coincidence rather than by being in
        sync with any other machine. See README.md."
fi

# ------------------------------------------------- plugin/checkout coexistence

# Both install forms on one machine means both copies of the hooks fire on every
# prompt — measured on a real install, not predicted. The checkout half of the
# evidence is the config directory itself carrying the suite's plugin manifest
# at its root, which is the source repository's own shape; the plugin half is a
# cached wss install, or enabledPlugins naming one. Keyed on
# CONFIG_DIR throughout: coexistence is a property of the MACHINE, never of
# whichever installation this particular run was pointed at.
coexist_checkout=0
if [ -f "$CONFIG_DIR/.claude-plugin/plugin.json" ] && ! is_plugin_root "$CONFIG_DIR" &&
   git -C "$CONFIG_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  coexist_checkout=1
fi
coexist_plugin=0
if ls -d "$CONFIG_DIR"/plugins/cache/*/wss/ >/dev/null 2>&1; then
  coexist_plugin=1
elif jq -e '(.enabledPlugins // {}) | keys[] | select((split("@") | .[0]) == "wss")' \
       "$CONFIG_DIR/settings.json" >/dev/null 2>&1; then
  # Matched on the id's name half, not a substring: `wss` is short enough that a
  # bare grep also claims any unrelated `wssprobe@…` the user has enabled.
  coexist_plugin=1
fi
if [ $coexist_checkout -eq 1 ] && [ $coexist_plugin -eq 1 ]; then
  fail "the suite is installed TWICE — this config directory is the checkout
        form, and a wss plugin is installed beside it. The hooks
        double-fire, once from each form, on every prompt.
        Remove one. \`claude plugin uninstall\` DEFAULTS TO --scope user, so the
        bare command is wrong for a project-scope install: run
        \`wss-retire-workflow.sh --suite\` for the exact command per install."
else
  pass "the suite is installed at most once — no plugin/checkout coexistence"
fi

# What an uninstall leaves behind: empty enabledPlugins / extraKnownMarketplaces
# in settings.json. In the checkout form that file is TRACKED, so the residue
# does not stay local — it becomes a commit every other machine pulls.
if [ $PLUGIN_MODE -eq 0 ] &&
   git -C "$CLAUDE_DIR" ls-files --error-unmatch settings.json >/dev/null 2>&1; then
  residue=$(jq -r '[to_entries[]
      | select(.key == "enabledPlugins" or .key == "extraKnownMarketplaces")
      | select(.value | length == 0) | .key] | join(", ")' \
    "$CLAUDE_DIR/settings.json" 2>/dev/null)
  [ -n "$residue" ] &&
    warn "uninstall residue in tracked settings.json: empty $residue — a plugin
        teardown left them; delete the keys rather than committing them"
fi

# ------------------------------------------------------------------ credentials

# The whole premise of publishing this directory is that ONE file never leaves
# the machine. Until 2026-08-01 the only thing enforcing that was a sentence in
# README.md — no check here, none in CI, none in the suite. A .gitignore that
# re-includes seven directories wholesale is one careless edit from dropping the
# single line that protects it, and `git add` would say nothing.
#
# Two separate failures, because being ignored and being untracked are not the
# same thing and only one of them is recoverable quietly.
if [ $PLUGIN_MODE -eq 0 ] && git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  head_ "Credentials"

  # --no-index deliberately. Without it check-ignore consults the index too, so
  # a file that is BOTH correctly ignored and wrongly tracked reports as "not
  # ignored" — collapsing two different faults, with two different fixes, into
  # one message that describes the wrong one. This asks only about the rules;
  # the tracked question is the separate check below.
  if git -C "$CLAUDE_DIR" check-ignore --no-index -q .credentials.json 2>/dev/null; then
    pass ".credentials.json is ignored by the .gitignore rules"
  else
    fail ".credentials.json is NOT git-ignored. One \`git add -A\` publishes this
        machine's credentials. .gitignore ignores \`*\` and re-includes what
        travels, so this means something below that catch-all re-included it —
        find the re-inclusion rather than appending another deny line."
  fi

  # Ignored and tracked at once is possible and worse: .gitignore has no effect
  # on a path already in the index, so the check above passes while every commit
  # carries the file.
  if git -C "$CLAUDE_DIR" ls-files --error-unmatch .credentials.json >/dev/null 2>&1; then
    fail ".credentials.json is TRACKED. .gitignore does not apply to a path
        already in the index, so it is in every commit from here on and in the
        history already. \`git rm --cached .credentials.json\` stops the bleeding;
        the history needs rewriting separately."
  else
    pass ".credentials.json is not tracked"
  fi
fi

# ---------------------------------------------------------------- hook wiring

head_ "Hook wiring"

settings="$CLAUDE_DIR/settings.json"
if [ $PLUGIN_MODE -eq 1 ]; then
  # A plugin declares its hooks in hooks/hooks.json and never owns settings.json,
  # which belongs to the user or the project installing it.
  if [ ! -f "$CLAUDE_DIR/hooks/hooks.json" ]; then
    fail "plugin has no hooks/hooks.json — every --flag falls back to being
        matched from a skill description, which is reliable in practice and not
        guaranteed."
  elif ! jq -e . "$CLAUDE_DIR/hooks/hooks.json" >/dev/null 2>&1; then
    fail "hooks/hooks.json is not valid JSON — every hook in it is dead"
  # The events sit UNDER a top-level `hooks` key. This selector read them at the
  # top level until 2026-08-01, and that is not a nitpick: the first hooks.json
  # written here had exactly that flat shape, this check passed it, and
  # `claude plugin validate` rejected it with "expected record, received
  # undefined". A doctor that certifies a file the platform will not load is
  # worse than no check, because it is the reason nobody runs the validator.
  elif jq -e '.hooks.UserPromptSubmit' "$CLAUDE_DIR/hooks/hooks.json" >/dev/null 2>&1; then
    pass "hooks/hooks.json wires UserPromptSubmit — shorthand flags are deterministic"
  elif jq -e '.UserPromptSubmit' "$CLAUDE_DIR/hooks/hooks.json" >/dev/null 2>&1; then
    fail "hooks/hooks.json declares UserPromptSubmit at the TOP level. The events
        belong under a \`hooks\` key; as written the platform loads no hook at all.
        Confirm with \`claude plugin validate\`."
  else
    fail "hooks/hooks.json declares no UserPromptSubmit hook"
  fi
elif [ ! -f "$settings" ]; then
  fail "settings.json missing"
elif ! jq -e . "$settings" >/dev/null 2>&1; then
  fail "settings.json is not valid JSON — every hook in it is dead"
else
  pass "settings.json parses"

  # A hook pointing at a missing or non-executable script fails silently: the
  # event fires, the command is not found, Claude Code carries on.
  # Hook commands are COUNTED for the same reason the grant loop counts flags.
  # The jq selector below walks a shape this script does not own: settings.json's
  # hook layout is Claude Code's, and it has changed before. Restructure it and
  # the selector matches nothing, the loop body never runs, and this section
  # prints no failure — the resolution check disappears without saying so, which
  # is indistinguishable from every hook being fine.
  hook_cmds=0
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    hook_cmds=$((hook_cmds + 1))
    # Hook commands are written `~/.claude/x.sh`, because that is where they live
    # on a real machine. But CLAUDE_DIR exists so a config can be inspected
    # somewhere else — a CI checkout, a clone, another user's copy — and there
    # `~/.claude` is not it. Resolve against the directory actually under
    # inspection, falling back to $HOME for any other `~` path.
    #
    # Found by this repo's own CI on its first run: every hook command was
    # reported missing because `~` expanded to the runner's home while the
    # checkout sat under /home/runner/work. The failure was real — CLAUDE_DIR was
    # only half honoured — rather than an artefact of running in CI.
    r="${cmd/#\~\/.claude/$CLAUDE_DIR}"
    r="${r/#\~/$HOME}"
    r="${r%% *}"
    case $r in
      */*)
        if   [ ! -f "$r" ]; then fail "hook command not found: $r"
        elif [ ! -x "$r" ]; then fail "hook command not executable: $r  (chmod +x)"
        else pass "hook ok: ${r#"$HOME"/}"
        fi ;;
    esac
  done < <(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty' \
             "$settings" 2>/dev/null | sort -u)

  # Distinguishes "this config has no hooks" from "this config has hooks and the
  # selector could not read them". Only the second is a fault, and without the
  # count they look identical from here.
  if [ $hook_cmds -eq 0 ] && jq -e '(.hooks // {}) | length > 0' "$settings" >/dev/null 2>&1; then
    warn "settings.json defines hooks but no command could be read out of them.
        Either the layout changed or the selector is wrong — either way nothing
        below was verified, and that is not the same as every hook being fine."
  fi

  if jq -e '.hooks.UserPromptSubmit' "$settings" >/dev/null 2>&1; then
    pass "UserPromptSubmit wired — shorthand flags are deterministic"
  else
    fail "no UserPromptSubmit hook. Every --flag falls back to being matched
        from a skill description, which is reliable in practice and not
        guaranteed. Failure (1) in this script's header."
  fi
fi

# ------------------------------------------------------------- flags vs skills

head_ "Shorthand flags"

# `hooks/` first: that is where both scripts live since 2026-08-01, in a checkout
# as well as in a plugin. The root path is kept as a fallback for a checkout made
# before the move, where it is still the only one that resolves.
hook="$CLAUDE_DIR/hooks/wss-shorthand-flags.sh"
[ -f "$hook" ] || hook="$CLAUDE_DIR/wss-shorthand-flags.sh"   # pre-2026-08-01 layout
if [ ! -f "$hook" ]; then
  fail "wss-shorthand-flags.sh missing"
elif ! bash -n "$hook" 2>/dev/null; then
  fail "wss-shorthand-flags.sh has a syntax error — this breaks EVERY flag, not one"
else
  pass "wss-shorthand-flags.sh parses"
  flags=$(sed -n 's/^FLAGS=(\(.*\))$/\1/p' "$hook")
  if [ -z "$flags" ]; then
    fail "could not parse the FLAGS array"
  else
    # No flag may be a prefix of another. Where that holds, decomposition can
    # never split a token into a shorter flag plus junk, and the array's order
    # stops mattering. The hook's comment asserts this; here it is checked.
    prefix_clash=0
    for a in $flags; do
      for b in $flags; do
        [ "$a" = "$b" ] && continue
        case $b in "$a"*)
          fail "'$a' is a prefix of '$b'. Decomposition can split a token into
        the shorter flag plus junk, so one of them must be renamed."
          prefix_clash=$((prefix_clash + 1)) ;;
        esac
      done
    done
    [ $prefix_clash -eq 0 ] && pass "no flag is a prefix of another"

    for f in $flags; do
      # A flag may appear anywhere in a case alternation — `--wss-stocktake | --wss-full-stocktake)`
      # maps both — so split the alternatives and test membership rather than
      # pattern-matching the line. Matching only `^ *FLAG)` reported --wss-full-stocktake
      # as unmapped when it was mapped as the second alternative.
      skill=$(awk -v flag="$f" '
        /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*echo/ {
          alts = $0; sub(/\).*/, "", alts); gsub(/[[:space:]]/, "", alts)
          n = split(alts, a, "|")
          for (i = 1; i <= n; i++) if (a[i] == flag) {
            t = $0
            sub(/.*echo[[:space:]]+/, "", t); sub(/[[:space:]]*;;.*/, "", t)
            print t; exit
          }
        }' "$hook")
      if [ -z "$skill" ]; then
        fail "$f is in FLAGS but has no skill_for() mapping"
        continue
      fi
      # A block_for() label may be an alternation — `--wss-flags | --wss-help)` covers
      # both — so split the alternatives rather than matching the line start.
      # `^  FLAG)` alone reported --wss-help as blockless when it was the second
      # alternative of a live case, the same defect the skill_for() reader above
      # already carries a comment about.
      awk -v flag="$f" '
        /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*$/ {
          alts = $0; sub(/\).*/, "", alts); gsub(/[[:space:]]/, "", alts)
          n = split(alts, a, "|")
          for (i = 1; i <= n; i++) if (a[i] == flag) { found = 1; exit }
        } END { exit !found }' "$hook" ||
        warn "$f maps to '$skill' but has no block_for() case — it injects nothing"
      # `-` is the hook serving the flag itself rather than a missing mapping.
      # There is no skills/ directory to look in and its absence is not a fault.
      if   [ "$skill" = "-" ]; then pass "$f -> served by the hook, no skill needed"
      elif [ -f "$CLAUDE_DIR/skills/$skill/SKILL.md" ]; then pass "$f -> $skill (user)"
      elif [ -f "$PWD/.claude/skills/$skill/SKILL.md" ]; then pass "$f -> $skill (project)"
      else warn "$f -> $skill, which resolves in neither $CLAUDE_DIR/skills nor this
        project. skill_exists() gates it, so the flag is inert here rather than
        broken — but if this is the project that should have it, it does nothing."
      fi
    done

    # A flag's grant is written by hand in two authorities: the block this hook
    # injects, and the matrix in workflow/WSS.OWNERSHIP.md. Nothing compared them
    # until a review found the grant restated in four places with two of them
    # checked by nothing. Prose cannot be diffed, so both sides are reduced to
    # the pair that actually matters — does this flag grant a commit, and does
    # it grant a push — and a disagreement is reported for a human to read.
    #
    # DELIBERATELY BLUNT about one distinction: "not push" and "push needs a
    # fresh OK in that turn" both reduce to push=no, because both mean the flag
    # alone does not authorize publishing. --wss-start and --wss-release therefore look
    # identical here and are not. What this catches is a flag silently gaining
    # or losing push, which is the drift that would matter.
    own="$CLAUDE_DIR/workflow/WSS.OWNERSHIP.md"
    if [ ! -f "$own" ]; then
      warn "workflow/WSS.OWNERSHIP.md not found — grants were checked in the hook only,
        so nothing verified that the two authorities still agree"
    else
      grant_sig() {
        s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '*`')
        case $s in ''|-|—*|none*) printf 'none'; return ;; esac
        c=no; p=no
        case $s in *commit*) c=yes ;; esac
        case $s in
          *"not push"*|*"not covered"*|*"needs a fresh"*) p=no ;;
          *push*) p=yes ;;
        esac
        printf 'commit=%s push=%s' "$c" "$p"
      }
      # A flag whose grant cannot be EXTRACTED is counted, never skipped — the
      # same rule as the section-citation check below, and for the same reason.
      # This loop reads a shape it does not own: `Authorization:` at column 0
      # inside the block's heredoc. Reword that line, indent it, or drop it, and
      # the awk returns nothing for every flag at once — which read as "no drift"
      # and printed the pass line, so the check went blind and said it agreed.
      grant_drift=0; grant_seen=0; grant_blind=0
      for f in $flags; do
        hook_auth=$(awk -v flag="$f" '
          # A case label may be an alternation, and matching only its first
          # alternative left --wss-help unreadable while --wss-flags silently picked up
          # the NEXT block\047s grant. Split the alternatives, and reset at every
          # label so a scan can never run past the end of its own arm.
          /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*$/ {
            alts = $0; sub(/\).*/, "", alts); gsub(/[[:space:]]/, "", alts)
            n = split(alts, a, "|"); inblk = 0; grab = 0
            for (i = 1; i <= n; i++) if (a[i] == flag) inblk = 1
            next
          }
          inblk && /^EOF$/ && grab { exit }
          inblk && /^Authorization:/ { grab = 1 }
          inblk && grab && NF == 0 { exit }
          inblk && grab { sub(/^Authorization:[[:space:]]*/, ""); print }
        ' "$hook")
        matrix_auth=$(awk -F'|' -v flag="$f" '
          /^\|/ && index($3, "`" flag "`") {
            a = $(NF - 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", a); print a; exit
          }' "$own")
        if [ -z "$hook_auth" ]; then
          grant_blind=$((grant_blind + 1))
          continue
        fi
        grant_seen=$((grant_seen + 1))
        if [ -z "$matrix_auth" ]; then
          warn "$f has a stated authorization in the hook but no row in
        WSS.OWNERSHIP.md's matrix — the matrix is the authority, so either the row is
        missing or the flag should not exist"
          grant_drift=$((grant_drift + 1))
          continue
        fi
        hs=$(grant_sig "$hook_auth")
        ms=$(grant_sig "$matrix_auth")
        if [ "$hs" != "$ms" ]; then
          warn "$f grants disagree. hook says '$hs', WSS.OWNERSHIP.md says '$ms'.
        One of the two authorities is wrong, and the hook is what actually fires."
          grant_drift=$((grant_drift + 1))
        fi
      done
      if [ $grant_blind -gt 0 ]; then
        warn "$grant_blind flag(s) state no \`Authorization:\` line this check could
        read, so their grants were compared against nothing. That is not a pass:
        either those blocks lost their authorization, or the line's shape moved
        and the comparison above now sees none of them."
      fi
      [ $grant_drift -eq 0 ] && [ $grant_seen -gt 0 ] &&
        pass "every flag's grant matches between the hook and WSS.OWNERSHIP.md ($grant_seen checked)"
    fi

    # The checks above all run flag -> skill: does what the hook serves resolve
    # to something. Nothing ran the other way, and that direction is the one a
    # READER travels — a description advertising `SHORTHAND: --wss-x` is a
    # promise to the user, and if the hook does not serve it the flag reaches
    # the model as ordinary prose. The skill then fires only where the model
    # happens to read the description and infer it, which is the founding
    # failure this whole script exists for: mostly working, nothing looking
    # wrong. Only `--wss-`-prefixed tokens are read, so a description quoting
    # `--strict` or another tool's flag is not a claim about this hook.
    adv=0; adv_bad=0
    for sd in "$CLAUDE_DIR"/skills/*/; do
      [ -f "$sd/SKILL.md" ] || continue
      sn=$(basename "$sd")
      sdesc=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$sd/SKILL.md" |
              awk '/^description:/{p=1;print;next} p&&/^[a-zA-Z_-]+:/{p=0} p')
      [ -n "$sdesc" ] || continue
      for adf in $(printf '%s' "$sdesc" | grep -oE '\-\-wss-[a-z-]+' | sort -u); do
        adv=$((adv + 1))
        case " $flags " in
          *" $adf "*) ;;
          *) fail "'$sn' advertises $adf, which wss-shorthand-flags.sh does not serve.
        A user who types it gets no flag block and no error — the skill fires
        only if the model reads the description and infers it."
             adv_bad=$((adv_bad + 1)) ;;
        esac
      done
    done
    if [ $adv -eq 0 ]; then
      pass "no skill description advertises a --wss- shorthand"
    elif [ $adv_bad -eq 0 ]; then
      pass "every advertised shorthand is served by the hook ($adv checked)"
    fi
  fi
fi

# ------------------------------------------------------------------- shadowing

head_ "Skill shadowing"

if [ -d "$PWD/.claude/skills" ] && [ -d "$CLAUDE_DIR/skills" ]; then
  n=0
  for d in "$PWD"/.claude/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if [ -f "$CLAUDE_DIR/skills/$name/SKILL.md" ]; then
      warn "'$name' exists in BOTH this project and at user level. The project
        copy wins, silently, with no warning anywhere. Correct when a project
        deliberately overrides the global skill; a bug otherwise."
      n=$((n + 1))
    fi
  done
  [ $n -eq 0 ] && pass "no project skill shadows a user-level skill"
else
  pass "nothing to compare"
fi

# ------------------------------------------- dispatch-only skills vs overrides

head_ "Dispatch-only skills"

# A skill no flag maps to is reached only by dispatch from another skill, so its
# frontmatter `description` is never used as a trigger — and yet it loads into
# every session of every project, which is the one cost this configuration
# actually measures. `skillOverrides: name-only` is what stops that.
#
# Silent by construction without this check: a missing entry looks exactly like
# a skill nobody has decided about yet, and the cost lands where nobody is
# looking. Four primitives were added at once on 2026-08-01 and all four were
# forgotten together, which is what this exists to catch next time.
if [ -z "${flags:-}" ] || [ ! -f "$settings" ]; then
  pass "no flag list or no settings to compare against"
else
  mapped=$(for f in $flags; do
      awk -v flag="$f" '
        /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*echo/ {
          alts = $0; sub(/\).*/, "", alts); gsub(/[[:space:]]/, "", alts)
          n = split(alts, a, "|")
          for (i = 1; i <= n; i++) if (a[i] == flag) {
            t = $0; sub(/.*echo[[:space:]]+/, "", t); sub(/[[:space:]]*;;.*/, "", t)
            print t; exit
          }
        }' "$hook"
    done | sort -u)
  overrides=$(jq -r '.skillOverrides // {} | keys[]' "$settings" 2>/dev/null | sort -u)
  n=0; seen=0
  for d in "$CLAUDE_DIR"/skills/*/; do
    [ -f "$d/SKILL.md" ] || continue
    name=$(basename "$d")
    seen=$((seen + 1))
    printf '%s\n' "$mapped"    | grep -qx "$name" && continue
    printf '%s\n' "$overrides" | grep -qx "$name" && continue
    warn "'$name' is reached only by dispatch — no flag maps to it — but has no
        skillOverrides entry, so its description loads in every session of every
        project. Set it to 'name-only'. Never 'off': that blocks model
        invocation, which is the only kind a dispatched skill ever gets."
    n=$((n + 1))
  done
  if [ $seen -eq 0 ]; then
    warn "no skills could be enumerated, so no override was checked"
  elif [ $n -eq 0 ]; then
    pass "every dispatch-only skill is set to name-only ($seen skills checked)"
  fi
fi

# ------------------------------------------------------- skill description size

head_ "Description budget"

# The one cost this configuration pays whether or not anything is used. A
# skill's frontmatter `description` is loaded into EVERY session of EVERY
# project so the model can decide whether the skill applies; the body is loaded
# only when it does. Nothing bounded that, and it grew the way prose grows —
# every disambiguation against a neighbouring skill added a sentence, and none
# was ever removed. An audit on 2026-08-01 measured 11,839 B across 24 skills.
#
# A warning, not a failure: 40 bytes over is not a defect, and a check that
# fails a run for it stops being read. --strict makes CI enforce it, which is
# where a budget belongs.
DESC_CAP=400
n=0; seen=0; total=0
for d in "$CLAUDE_DIR"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  name=$(basename "$d")
  seen=$((seen + 1))
  # The description field only: from `description:` to the next top-level key
  # or the end of the frontmatter. A description may be folded across lines,
  # so counting the first line alone would under-report exactly the ones that
  # have grown longest.
  b=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$d/SKILL.md" |
      awk '/^description:/{p=1;print;next} p&&/^[a-zA-Z_-]+:/{p=0} p' | wc -c)
  total=$((total + b))
  if [ "$b" -gt $DESC_CAP ]; then
    warn "'$name' description is ${b}B, over the ${DESC_CAP}B budget. This loads in
        every session of every project. Negative routing — \"not X, that is Y\" —
        is usually what grew: it is cheaper to stop two skills overlapping than
        to describe the overlap forever."
    n=$((n + 1))
  fi
done
if [ $seen -eq 0 ]; then
  warn "no skills could be enumerated, so no description was measured"
elif [ $n -eq 0 ]; then
  pass "every description is within ${DESC_CAP}B ($seen skills, ${total}B always-on)"
else
  warn "$n of $seen descriptions are over budget; ${total}B loads in every session"
fi

head_ "Trigger phrases a session would hit by accident"

# A description is how the MODEL decides to invoke a skill, so a trigger listed
# there is a claim about ordinary language. `wrap` listed `"done"` and
# `release` listed `"ship it"` — both hold a push grant, so "ok that's done"
# could commit and push work nobody asked to publish. `stocktake`
# listed `"where are we"`, the most expensive skill in the suite answering a
# question a sentence would.
#
# The signature is structural rather than semantic, which is what makes it
# checkable: a ONE-WORD quoted trigger. Every phrase that survived review is
# three or more words ("wrap this up", "cut a release") because that length is
# what makes a phrase an instruction rather than a remark.
#
# A single word is allowed only where the description also NEGATES it — the
# fix for this class is to name the tempting word and refuse it, so a check
# that forbade the word outright would forbid its own remedy.
SUSPECT=0; checked=0
for d in "$CLAUDE_DIR"/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  name=$(basename "$d")
  desc=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$d/SKILL.md" |
         awk '/^description:/{p=1;print;next} p&&/^[a-zA-Z_-]+:/{p=0} p')
  [ -n "$desc" ] || continue
  checked=$((checked + 1))

  # Normalise before reading: YAML escaping puts a backslash before the quote,
  # so `\"ship it\"` does not contain the literal `"ship it"` and the first
  # version of this check matched nothing and reported clean. Curly quotes are
  # what a description picks up from being drafted anywhere but an editor.
  # The curly quotes are written LITERALLY. Byte escapes were tried first and
  # were silently catastrophic: `tr '\xe2\x80\x98...'` inside single quotes
  # receives the characters backslash, x, e, 2 — so it replaced every `e`, `2`
  # and `8` in the description, mangling it into text no pattern could match,
  # and the check went quiet on every fixture including the ones it had caught
  # a minute earlier. A normaliser that destroys its input reports clean.
  descn=$(printf '%s' "$desc" | sed 's/\\"/"/g; s/[“”]/"/g')

  # Only the TRIGGER CLAUSE is read — the run beginning at "trigger on", "also
  # on" or "invoke on" and ending at that sentence. Scanning the whole
  # description was wrong twice over. It fired on `"main"` in a sentence about
  # branch names, which is a false positive, and a false positive is how a check
  # gets weakened rather than obeyed. And the escape for it — any negation
  # anywhere in the description — let `Also trigger on "done". Not for release
  # notes.` pass, because the negation was about something else entirely.
  #
  # Reading only the clause needs no escape at all: the sentence that names a
  # word in order to REFUSE it ("never infer it from \"done\"") is not a trigger
  # clause, so it is never scanned. The remedy stops being a special case.
  clauses=$(printf '%s' "$descn" | grep -oiE '(also trigger on|trigger on|also on|invoke on)[^.]*' || true)
  [ -n "$clauses" ] || continue

  singles=$(printf '%s' "$clauses" | grep -oE '"[A-Za-z][A-Za-z'"'"'-]*"' |
            tr -d '"' | sort -u | tr '\n' ' ')
  # Plus multi-word phrases already observed to misfire. NOT a theory of
  # ordinary language and it must not grow into one — it is the list of phrases
  # that actually shipped as triggers and had to be removed.
  for phrase in "ship it" "looks good" "where are we" "that works" "sounds good"; do
    printf '%s' "$clauses" | grep -qiF "\"$phrase\"" && singles="$singles$phrase, "
  done
  [ -n "${singles// /}" ] || continue

  fail "'$name' offers one-word trigger(s) [ ${singles}] in its trigger clause.
        A description decides invocation from ordinary language, so a bare word
        fires on conversation about the work rather than a request for it. Use a
        phrase long enough to be an instruction, or move the word into a sentence
        that refuses it."
  SUSPECT=$((SUSPECT + 1))
done
if [ $checked -eq 0 ]; then
  # Not a warning. A skill with no frontmatter description cannot be invoked
  # from ordinary language at all, so there is nothing here to misfire — and
  # the budget check above already reports the case where no skill was found.
  # Warning here made a clean fixture fail under --strict, which is a check
  # inventing work rather than finding it.
  pass "no skill declares a description, so none can trigger on a stray word"
elif [ $SUSPECT -eq 0 ]; then
  pass "no trigger clause invites invocation on a single ordinary word ($checked checked)"
fi

# --------------------------------------------------------- dangling references

head_ "Cross-references"

# A dispatch target is a skill, an agent, OR a procedure file under
# workflow/writers/. The third kind arrived on 2026-08-02, when the eight
# flagless writers stopped being skills — they are dispatched to exactly as
# before and are still named in the same prose, so leaving them out of this list
# turned every one of those citations into a FAIL at once. What this check is
# for is a dispatch to something that does not exist; where the target lives is
# not what it is asking.
known=$(
  { ls "$CLAUDE_DIR/skills" 2>/dev/null
    ls "$PWD/.claude/skills" 2>/dev/null
    ls "$CLAUDE_DIR/agents" 2>/dev/null | sed 's/\.md$//'
    ls "$PWD/.claude/agents" 2>/dev/null | sed 's/\.md$//'
    # A procedure is CITED by its name (`git-writer`) and STORED under the
    # suite's file convention (`WSS.GIT-WRITER.md`). Derive the one from the
    # other rather than making every skill cite a filename: the citation names
    # an authority, not a path, and prose that carries paths rots on every move.
    ls "$CLAUDE_DIR/workflow/writers" 2>/dev/null | sed 's/\.md$//; s/^WSS\.//' | tr 'A-Z' 'a-z'
    ls "$PWD/.claude/workflow/writers" 2>/dev/null | sed 's/\.md$//; s/^WSS\.//' | tr 'A-Z' 'a-z'
  } | sort -u
)
if [ -z "$known" ]; then
  pass "no skills, agents or procedures to cross-check"
else
  # Only a backticked slug immediately following a phrase that cites it as an
  # authority. Anything looser drowns in false positives from filenames and
  # package names, and a check nobody trusts is a check nobody runs.
  # Citations are COUNTED, not just failed on. This loop reads a shape it does
  # not own — the prose phrasings below, written by hand in every skill file. Add
  # a way of citing an authority that this alternation does not list, or reword
  # the ones it does, and the grep returns nothing for every file at once. That
  # read as "no bad citations" and printed the pass line, so the check went blind
  # and said it agreed. Same defect as the grant loop above, same fix.
  n=0; seen=0
  for f in "$PWD"/.claude/skills/*/SKILL.md "$PWD"/.claude/agents/*.md \
           "$CLAUDE_DIR"/skills/*/SKILL.md "$CLAUDE_DIR"/agents/*.md; do
    [ -f "$f" ] || continue
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      seen=$((seen + 1))
      printf '%s\n' "$known" | grep -qx "$ref" && continue
      fail "${f#"$HOME"/}
        cites \`$ref\` as a skill or agent, and it resolves to neither"
      n=$((n + 1))
    done < <(grep -ohiE '(per|via|see|use|invoke|through|follow|hand[a-z]* (it |them |off )?to|that is|thats) (the )?`[a-z]+(-[a-z]+)+`' "$f" 2>/dev/null |
             grep -oE '`[a-z-]+`' | tr -d '`' | sort -u)
  done
  if [ $n -eq 0 ] && [ $seen -gt 0 ]; then
    pass "every cited skill/agent/procedure resolves ($seen checked)"
  elif [ $n -eq 0 ]; then
    pass "no skill/agent/procedure citations to check"
  fi
fi

# ------------------------------------------------------------ section citations

head_ "Section citations"

# A skill that hands another skill's SECTION to an agent — "the brief is
# `--wss-check`'s \"What to look for\" section". The check above proves the cited
# SKILL resolves; it says nothing about the heading inside it. A renamed or
# deleted heading then leaves a citation that reads exactly like a live one, and
# whatever depended on that brief silently dispatches with nothing.
#
# Only lines that both cite a skill possessively and contain the word "section"
# are considered, which is how these citations are actually written. Anything
# looser matches ordinary quoted prose.

skill_path_() {
  if   [ -f "$PWD/.claude/skills/$1/SKILL.md" ]; then printf '%s' "$PWD/.claude/skills/$1/SKILL.md"
  elif [ -f "$CLAUDE_DIR/skills/$1/SKILL.md" ]; then printf '%s' "$CLAUDE_DIR/skills/$1/SKILL.md"
  fi
}

flag_skill_() {
  [ -f "$hook" ] || return 0
  awk -v want="$1" '
    /echo/ {
      line = $0; sub(/\).*/, "", line); gsub(/[ \t]/, "", line)
      n = split(line, a, "|")
      for (i = 1; i <= n; i++) if (a[i] == want) {
        if (match($0, /echo [a-z-]+/)) print substr($0, RSTART + 5, RLENGTH - 5)
        exit
      }
    }' "$hook"
}

n=0; seen=0; skipped=0
for f in "$PWD"/.claude/skills/*/SKILL.md "$CLAUDE_DIR"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    case "$line" in *section*|*Section*) ;; *) continue ;; esac
    all_cited=$(printf '%s\n' "$line" | grep -oE '`(--)?[a-z][a-z-]*`'\''s' |
                sed "s/'s\$//" | tr -d '`' | sort -u)
    cited=$(printf '%s\n' "$all_cited" | head -1)
    [ -n "$cited" ] || continue
    # The section NAMES are gathered from the whole line below, so one skill per
    # line is what makes the pairing sound. Two citations on one line used to
    # take the first and check every name on the line against it — the second
    # skill's sections checked against the wrong file, which fails a correct
    # line as readily as it passes a wrong one. Ambiguous is not checkable:
    # count it, so the warning below says the run could not see everything.
    if [ "$(printf '%s\n' "$all_cited" | grep -c .)" -gt 1 ]; then
      skipped=$((skipped + 1)); continue
    fi
    # A citation we cannot follow is COUNTED, never skipped. Silently dropping
    # one turns "could not check" into "nothing to check", which reads as a
    # pass — the failure this whole section exists to catch, one level up.
    case "$cited" in --*)
      resolved=$(flag_skill_ "$cited")
      if [ -z "$resolved" ]; then
        skipped=$((skipped + 1)); continue
      fi
      cited=$resolved ;;
    esac
    target=$(skill_path_ "$cited")
    if [ -z "$target" ]; then
      skipped=$((skipped + 1)); continue
    fi
    [ "$target" = "$f" ] && continue          # a skill citing its own sections
    headings=$(grep -E '^#+ ' "$target" | sed 's/^#\+ *//' | tr 'A-Z' 'a-z')
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      seen=$((seen + 1))
      printf '%s\n' "$headings" |
        grep -qF "$(printf '%s' "$name" | tr 'A-Z' 'a-z')" && continue
      fail "${f#"$HOME"/}
        cites a \"$name\" section in '$cited', which has no such heading"
      n=$((n + 1))
    done < <(printf '%s\n' "$line" | grep -oE '"[^"]+"' | tr -d '"')
  done < "$f"
done
if [ $skipped -gt 0 ]; then
  warn "$skipped section citation(s) could not be checked — the skill or flag they
        cite did not resolve from here. That is not a pass: either the citation is
        wrong, or this run cannot see the whole configuration."
fi
if [ $n -eq 0 ] && [ $seen -gt 0 ]; then
  pass "every cited section heading resolves ($seen checked)"
elif [ $n -eq 0 ] && [ $seen -eq 0 ] && [ $skipped -eq 0 ]; then
  pass "no cross-skill section citations to check"
fi

# ------------------------------------------------------- link targets, anchors

# An ordinary markdown link can carry a heading fragment. The citation check
# above only covers the possessive "X's \"Y\" section" shape, and the manifest
# check below only covers keyed pointers inside WSS.WORKFLOW.json — so a plain link
# whose target heading gets renamed is verified by nothing and reads exactly
# like a live one. That is the failure both of those exist to catch, in the one
# form neither of them sees.
#
# Narrow on the same grounds CI's cross-link step is narrow, and for the same
# reason: a check nobody trusts is a check nobody runs.
#
#   - Links inside fenced code blocks are examples rather than pointers.
#   - A leading slash is site-root-relative inside a rendered docs site, not a
#     filesystem path.
#   - Angle brackets or a shell expansion mark a template placeholder.
#
# Tracked files only where this is a checkout, which is what keeps ~/.claude's
# ~100 MB of transcripts, caches and plugin trees out of the walk. A plugin
# install has no git index and no machine state, so there it is the whole tree.

# `audits/` is excluded, and it is the only exclusion.
#
# Those files are agent audit reports kept VERBATIM: their own index says the
# line citations in them are stale and that they are a record of what was found
# and argued, not a description of the current tree. Policing them offers two
# outcomes and both are bad — edit a frozen record so a checker goes quiet, or
# carry permanent failures that train everyone to skim this output. A report
# citing `types.md` from an example that no longer exists is correct as written.
#
# The distinction is FROZEN vs MAINTAINED, not "ours vs theirs". Anything else
# tracked here is maintained and stays in scope; if a second frozen archive ever
# appears, it goes on this line with the same argument or it does not go at all.
# `audits/README.md` is deliberately NOT excluded. The distinction is FROZEN vs
# MAINTAINED, and that file is maintained: it was the index of the reports until
# 2026-08-07 and is the pointer to the index's new home since — the
# `WSS.record.audits` record under docs/, in ordinary scope like any other
# record. Excluding the whole directory once took the index out with the
# reports, which is how it came to say "four" for three passes after there were
# more — a stale claim inside the index of the audits that exist to catch stale
# claims.
md_files_() {
  if git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    {
      git -C "$CLAUDE_DIR" ls-files -z '*.md' ':(exclude)audits/**'
      git -C "$CLAUDE_DIR" ls-files -z 'audits/README.md'
    } | while IFS= read -r -d '' p; do printf '%s\0' "$CLAUDE_DIR/$p"; done
  else
    find "$CLAUDE_DIR" -name '*.md' -not -path '*/.git/*' \
      \( -not -path '*/audits/*' -o -path '*/audits/README.md' \) -print0
  fi
}

# The PATH half of a relative link, which nothing here checked until 2026-08-02.
# The anchor check below needs a `#` to fire, so a link to a file that has been
# moved or deleted was verified by CI alone — and on 2026-08-02 that is exactly
# what happened: eight skill files moved to workflow/writers/, six links to them
# were sibling-relative (`../manifest-writer/SKILL.md`, no `skills/` segment to
# grep for), three commits went out saying "wss-doctor.sh all-clear", and CI was red
# the whole time. The claim was true and useless: the doctor did not cover what
# the gate covered.
#
# Same exemptions as CI's step, deliberately, so the two agree rather than each
# being narrow in its own way — fenced blocks and inline backticks are how a
# document that explains link syntax has to quote it, and a leading slash is
# site-root-relative inside a rendered docs site rather than a filesystem path.
link_targets_() {
  md_files_ | xargs -0 -r awk '
    FNR == 1 { fence = 0 }
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      while (match(line, /`[^`]*`/))
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      while (match(line, /\]\([^)#][^)]*\)/)) {
        l = substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
        sub(/#.*/, "", l)
        if (l == "" || l ~ /^(https?:|mailto:|\/)/ || l ~ /[<$]/) continue
        printf "%s\t%s\n", FILENAME, l
      }
    }'
}

head_ "Link targets"

n=0; seen=0
while IFS=$'\t' read -r f l; do
  [ -n "$l" ] || continue
  seen=$((seen + 1))
  [ -e "$(dirname "$f")/$l" ] && continue
  fail "${f#"$CLAUDE_DIR"/}
        links to $l, which does not exist. A moved or deleted target reads
        exactly like a live link to whoever follows it."
  n=$((n + 1))
done < <(link_targets_)
if [ $seen -eq 0 ]; then
  warn "no relative links were extracted, so none was checked"
elif [ $n -eq 0 ]; then
  pass "every relative link resolves ($seen checked)"
fi

head_ "Link anchors"

anchor_links_() {
  md_files_ |
    xargs -0 -r awk '
      FNR == 1 { fence = 0 }
      /^[[:space:]]*```/ { fence = !fence; next }
      fence { next }
      {
        line = $0
        while (match(line, /\]\([^)]*#[^)]*\)/)) {
          l = substr(line, RSTART + 2, RLENGTH - 3)
          line = substr(line, RSTART + RLENGTH)
          if (l ~ /^http/ || l ~ /^\// || l ~ /[<$]/) continue
          printf "%s\t%s\n", FILENAME, l
        }
      }'
}

if ! command -v python3 >/dev/null 2>&1; then
  warn "link anchors unverified (needs python3) — a renamed heading passes silently here"
else
  checked=0; broken=0
  # Emitted as file-and-whole-link rather than as three fields on purpose. A
  # same-file fragment has an empty path half, and tab is IFS whitespace, so a
  # three-field read collapses the empty field and shifts the fragment into the
  # path — which reports every same-file anchor as a missing file. Split here
  # instead, where an empty half stays empty.
  while IFS=$'\t' read -r src link; do
    [ -n "$link" ] || continue
    target=${link%%#*}
    frag=${link#*#}
    if [ -z "$target" ]; then t=$src; else t="$(dirname "$src")/$target"; fi
    checked=$((checked + 1))
    if [ ! -f "$t" ]; then
      broken=$((broken + 1))
      fail "${src#"$HOME"/}
        links to '$link', whose file does not exist — so the anchor half is
        unverifiable rather than merely wrong"
    elif ! python3 -c "$ANCHOR_PY" "$t" "$frag" 2>/dev/null; then
      broken=$((broken + 1))
      fail "${src#"$HOME"/}
        links to '$link', but nothing there is anchored #$frag — the link opens
        the top of the file instead, silently"
    fi
  done < <(anchor_links_)
  if [ $broken -eq 0 ] && [ $checked -gt 0 ]; then
    pass "every link anchor resolves ($checked checked)"
  elif [ $checked -eq 0 ]; then
    pass "no link anchors to check"
  fi
fi

# ------------------------------------------------- home paths in runnable blocks

head_ "Installation paths in runnable blocks"

# `~/.claude` is two different directories depending on install form, and only
# one of them moves. As the CONFIG directory it is correct in both — the bug
# inbox, `projects/` and `settings.json` genuinely live there whichever way the
# suite was installed. As the INSTALLATION it is correct only in a checkout:
# under a plugin the suite is at $CLAUDE_PLUGIN_ROOT and ~/.claude belongs to the
# adopter, so `~/.claude/wss-doctor.sh` resolves to nothing.
#
# Only fenced blocks are checked, because those are the lines that get run. A
# prose mention is a wrong label and a judgement call; a command is a failure.
#
# This check exists because the class recurred inside the very commit that
# claimed to close it: the fix grepped for the inline-backtick form and every
# surviving instance was in a fenced block, so the grep reported clean over
# three live faults. That is the same shape as the link-target gap above.
home_in_fences_() {
  md_files_ | xargs -0 -r awk '
    FNR == 1 { fence = 0 }
    /^[[:space:]]*```/ { fence = !fence; next }
    !fence { next }
    # One genuine exemption: a block whose subject IS the checkout — the
    # adoption procedure creates ~/.claude, so a plugin-root fallback there
    # would imply a case that cannot arise mid-clone. Marked per line so the
    # exemption is visible to the reader of the document too, and so it cannot
    # silently cover a block it was not meant to.
    /doctor:checkout-only/ { next }
    # $CLAUDE_PLUGIN_ROOT is right for a hook and useless here: measured
    # 2026-08-02 from a real git-hosted install, it is EMPTY in a model-run Bash
    # command. A fenced block keyed on it silently becomes the adopter own
    # config directory. Hooks are .sh and are never scanned by this.
    /\$\{?CLAUDE_PLUGIN_ROOT/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      printf "var\t%s\t%d\t%s\n", FILENAME, FNR, line
      next
    }
    /~\/\.claude\/(wss-doctor\.sh|skills|workflow|hooks|tests|README\.md)/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      printf "home\t%s\t%d\t%s\n", FILENAME, FNR, line
    }'
}

n=0
while IFS=$'\t' read -r kind f ln body; do
  [ -n "$f" ] || continue
  if [ "$kind" = "var" ]; then
    fail "${f#"$CLAUDE_DIR"/}:$ln
        keys a runnable block on \$CLAUDE_PLUGIN_ROOT, which is EMPTY in a
        model-run Bash command — measured 2026-08-02 from a real git-hosted
        install. It reaches hook processes only, so this silently becomes the
        adopter's own config directory:
          $body
        Resolve the root instead, checkout first:
          S=\"\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}\"
          [ -x \"\$S/wss-doctor.sh\" ] || S=\$(ls -d \"\$S\"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)"
  else
    fail "${f#"$CLAUDE_DIR"/}:$ln
        runs an installation path that only exists in a checkout:
          $body
        Resolve the root instead, checkout first — see the \`contracts\`
        skill. Config-directory paths (WSS.BUG-REPORTS.md, projects/, settings.json)
        are correct as they are and are not flagged."
  fi
  n=$((n + 1))
done < <(home_in_fences_)
[ $n -eq 0 ] && pass "no runnable block hard-codes an installation path"

# ----------------------------------------------- history in the rule files

head_ "History stays in the log"

# A rule file states behavior; the decision log explains it — the pattern rule
# in workflow/WSS.RECORD-CONTRACT.md. A date-shaped string in prose is the
# greppable proxy for history (an incident, a measurement, a
# what-this-file-used-to-say) that belongs in the log instead. Fenced blocks
# and inline code spans are exempt: examples and templates legitimately carry
# timestamps. Warn rather than fail so a local run stays navigable; CI passes
# --strict, which is what makes the warning binding.
rule_files_() {
  if git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$CLAUDE_DIR" ls-files -z 'skills/*/SKILL.md' 'skills/*/references/*.md' \
      'workflow/*.md' 'workflow/writers/*.md' 'workflow/checks/*.md' \
      'workflow/providers/*.md' |
      while IFS= read -r -d '' p; do printf '%s\0' "$CLAUDE_DIR/$p"; done
  else
    find "$CLAUDE_DIR/skills" "$CLAUDE_DIR/workflow" -name '*.md' \
      -not -path '*/.git/*' -print0 2>/dev/null
  fi
}
prose_dates_() {
  rule_files_ | xargs -0 -r awk '
    FNR == 1 { fence = 0 }
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      while (match(line, /`[^`]*`/))
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      if (line ~ /20[0-9][0-9]-[01][0-9](-[0-3][0-9])?/)
        printf "%s:%d\n", FILENAME, FNR
    }'
}
dh=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  warn "history in a rule file: ${hit#"$CLAUDE_DIR"/}
        A date in prose is an incident citation or a measurement — it belongs
        in the decision log; the file keeps the rule and its mechanism.
        WSS.RECORD-CONTRACT.md, the pattern rule."
  dh=$((dh + 1))
done < <(prose_dates_)
[ $dh -eq 0 ] && pass "no date-shaped prose in any rule file"

# ------------------------------------------------ command wrappers match flags

head_ "Command wrappers"

# A wrapper's name is its contract: commands/<name>.md autocompletes as /<name>
# and its body fires a flag, so the name and the flag must be the same token and
# the flag must exist in the hook — a mismatch routes a menu entry somewhere its
# name does not say, silently. The hook does not fire on a wrapper's expanded
# body, so the body's flag token is the only routing signal there is; that is
# why the wrapper set stays limited to flags whose skill carries its own rules.
if [ -d "$CLAUDE_DIR/commands" ]; then
  wflags=$(sed -n 's/^FLAGS=(\(.*\))$/\1/p' "$hook" 2>/dev/null)
  wn=0; wbad=0
  for c in "$CLAUDE_DIR"/commands/*.md; do
    [ -f "$c" ] || continue
    wn=$((wn + 1))
    wbase=$(basename "$c" .md)
    wbody=$(awk 'c == 2 && /^--[a-z]/ { print $1; exit } /^---$/ { c++ }' "$c")
    # TWO FORMS, one rule. The checkout keeps the prefix on both sides
    # (`log.md` fires `--wss-log`); the published plugin strips it from the
    # wrapper NAME and never from the FLAG (`log.md` fires `--wss-log`), because
    # plugin form namespaces the wrapper as `/wss:log` while the flags are the
    # same string in both forms. Accepting both is not a loosening: a wrapper
    # still has exactly one legal flag, and `todo.md` firing `--wss-log` fails
    # against both spellings.
    if [ "$wbody" != "--$wbase" ] && [ "$wbody" != "--wss-$wbase" ]; then
      fail "commands/$wbase.md fires '${wbody:-nothing}' — a wrapper's body must fire
        the flag its own name promises: --$wbase or --wss-$wbase"
      wbad=$((wbad + 1))
    elif ! printf '%s\n' $wflags | grep -qx -- "$wbody"; then
      # The flag actually in the body, not one rebuilt from the filename: those
      # are the same token in checkout form and differ by the prefix in plugin
      # form, and it is the fired one the hook either serves or does not.
      fail "commands/$wbase.md fires $wbody, which is not in the hook's FLAGS —
        the menu offers a flag the hook does not serve"
      wbad=$((wbad + 1))
    fi
  done
  if [ $wn -eq 0 ]; then
    pass "commands/ exists and holds no wrappers"
  elif [ $wbad -eq 0 ]; then
    pass "every command wrapper fires the flag its name promises ($wn checked)"
  fi
else
  pass "no commands/ directory — nothing to check"
fi

# ------------------------------------------------ the cadence table, hand-copied

head_ "Cadence tables"

# The cadence a user is told to keep exists twice: as the card --wss-adopt reads
# out at the end of an adoption, and as README.md's "How often" table. Same
# class as CI's two markdown walks below — two hand-copies of one list, no way
# to source it once, so what is asserted is that they agree. Only the FLAG
# column: the two tables address different readers, so their wording and their
# third column are free to differ, and forcing those into step would collapse
# two documents into one.
#
# Drift here is silent in the worst direction — an adopter is handed a cadence
# missing the flag added last week, and the card is the one surface that ever
# gets read aloud.
cadence_flags_() { # file — the flag column of the "| When | Flag |" table
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
cad_card="$CLAUDE_DIR/skills/adopt/SKILL.md"
cad_readme="$CLAUDE_DIR/README.md"
if [ -f "$cad_card" ] && [ -f "$cad_readme" ]; then
  cad_a=$(cadence_flags_ "$cad_card")
  cad_b=$(cadence_flags_ "$cad_readme")
  if [ -z "$cad_a" ] || [ -z "$cad_b" ]; then
    # Reading nothing is the failure mode that matters: a parser that has gone
    # blind agrees with everything, and an empty-vs-empty pass is what the
    # agreement was supposed to rule out.
    cad_blind=""
    [ -z "$cad_a" ] && cad_blind="skills/adopt/SKILL.md"
    [ -z "$cad_b" ] && cad_blind="${cad_blind:+$cad_blind and }README.md"
    fail "no cadence table found in $cad_blind — the comparison needs a
        '| When | Flag |' table in both files, and two tables that cannot be
        read compare equal"
  elif [ "$cad_a" = "$cad_b" ]; then
    pass "both cadence tables name the same flags ($(printf '%s\n' "$cad_a" | grep -c .) checked)"
  else
    cad_only_a=$(comm -23 <(printf '%s\n' "$cad_a") <(printf '%s\n' "$cad_b") | tr '\n' ' ')
    cad_only_b=$(comm -13 <(printf '%s\n' "$cad_a") <(printf '%s\n' "$cad_b") | tr '\n' ' ')
    fail "the two cadence tables name different flags.
        Only in skills/adopt/SKILL.md's card: ${cad_only_a:-none}
        Only in README.md's 'How often' table: ${cad_only_b:-none}
        Wording and the 'Why then' column may differ; the flag column may not."
  fi
else
  pass "no cadence table pair to compare"
fi

# ---------------------------------------------- the check-method table, twice

head_ "Check-method tables"

# The catalog's "shared check methods" table and workflow/checks/WSS.CHECKS.md's
# "Method and runner" table are the same rows written twice. Single-sourcing is
# the wrong answer here and was considered: the catalog exists so a reader sees
# the whole tooling at a glance, and a row saying "see workflow/checks/WSS.CHECKS.md"
# defeats the only reason it is there. So what is asserted is that the two
# hand-copies agree — the same shape as the cadence tables above and CI's two
# markdown walks below, both of which compare rather than single-source.
#
# Unlike the cadence pair, ALL of the columns must agree. Those two tables
# address different readers, so their wording is free to differ; these two
# address the same reader and say the same thing, which makes any difference
# drift rather than register. They had already diverged once in exactly that
# way — "page accuracy" against "page-level accuracy", and "deleted rather than
# corrected" against "which are deleted rather than corrected" — with nothing
# reporting it, and the realignment that fixed it was done by hand.
#
# The link target is the one thing free to differ: the two files sit at
# different depths, so the catalog's href carries a ../workflow/checks/ prefix
# the README's does not. The method is therefore compared by the name in its
# backticks rather than by where it points.
method_rows_() { # file — the "| Method | What it finds | Run by |" table, href normalised away
  awk '
    /^\|[[:space:]]*Method[[:space:]]*\|[[:space:]]*What it finds[[:space:]]*\|[[:space:]]*Run by[[:space:]]*\|/ { t = 1; next }
    t && /^\|[[:space:]]*[-:]/ { next }
    t && /^\|/ {
      n = split($0, f, "|")
      if (n >= 5) {
        m = f[2]; w = f[3]; r = f[4]
        if (match(m, /`[^`]+`/)) m = substr(m, RSTART + 1, RLENGTH - 2)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", m)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", w)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", r)
        print m "|" w "|" r
      }
      next
    }
    t { t = 0 }
  ' "$1" | sort
}
mt_cat="$CLAUDE_DIR/.claude/WSS.TOOLING.md"
mt_readme="$CLAUDE_DIR/workflow/checks/WSS.CHECKS.md"
if [ -f "$mt_cat" ] && [ -f "$mt_readme" ]; then
  mt_a=$(method_rows_ "$mt_cat")
  mt_b=$(method_rows_ "$mt_readme")
  if [ -z "$mt_a" ] || [ -z "$mt_b" ]; then
    # Same blind-parser failure the cadence check guards: a reader that has gone
    # blind agrees with everything, and an empty-vs-empty pass is precisely what
    # this comparison exists to rule out.
    mt_blind=""
    [ -z "$mt_a" ] && mt_blind=".claude/WSS.TOOLING.md"
    [ -z "$mt_b" ] && mt_blind="${mt_blind:+$mt_blind and }workflow/checks/WSS.CHECKS.md"
    fail "no check-method table found in $mt_blind — the comparison needs a
        '| Method | What it finds | Run by |' table in both files, and two
        tables that cannot be read compare equal"
  elif [ "$mt_a" = "$mt_b" ]; then
    pass "both check-method tables carry the same rows ($(printf '%s\n' "$mt_a" | grep -c .) checked)"
  else
    mt_only_a=$(comm -23 <(printf '%s\n' "$mt_a") <(printf '%s\n' "$mt_b") | cut -d'|' -f1 | sort -u | tr '\n' ' ')
    mt_only_b=$(comm -13 <(printf '%s\n' "$mt_a") <(printf '%s\n' "$mt_b") | cut -d'|' -f1 | sort -u | tr '\n' ' ')
    fail "the two check-method tables disagree.
        Differing rows in .claude/WSS.TOOLING.md: ${mt_only_a:-none}
        Differing rows in workflow/checks/WSS.CHECKS.md: ${mt_only_b:-none}
        A method named on one side only is a missing row; one named on both is a
        wording drift in 'What it finds' or 'Run by'. Only the link target may
        differ between the two files."
  fi
else
  pass "no check-method table pair to compare"
fi

# The pair above compares the two tables against EACH OTHER, and two tables that
# never learned about a third method agree perfectly — a method file added
# without a row is invisible to both, and stays invisible because nothing else
# enumerates the directory. The reverse costs as little: a row naming a file
# that has been renamed or removed reads exactly like a live method, which is
# the failure the cross-reference checks exist for everywhere else. So the pair
# is anchored to the directory it describes, in both directions. WSS.CHECKS.md
# is the index rather than a method and is never a row.
if [ -d "$CLAUDE_DIR/workflow/checks" ] && [ -n "${mt_b:-}" ]; then
  mt_named=$(printf '%s\n' "$mt_b" | cut -d'|' -f1 | sort -u)
  mt_ondisk=$(find "$CLAUDE_DIR/workflow/checks" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
              grep -vx 'WSS.CHECKS.md' | sort)
  mt_unlisted=$(comm -13 <(printf '%s\n' "$mt_named") <(printf '%s\n' "$mt_ondisk") | tr '\n' ' ')
  mt_ghost=$(comm -23 <(printf '%s\n' "$mt_named") <(printf '%s\n' "$mt_ondisk") | tr '\n' ' ')
  if [ -n "$mt_unlisted" ]; then
    fail "method file with no row in either check-method table: $mt_unlisted
        Both tables compare clean, because neither knows it exists. Add the row
        to workflow/checks/WSS.CHECKS.md and .claude/WSS.TOOLING.md."
  fi
  if [ -n "$mt_ghost" ]; then
    fail "check-method table names a file that is not in workflow/checks/: $mt_ghost
        A row for a method that moved or was retired reads as a live one."
  fi
  [ -z "$mt_unlisted" ] && [ -z "$mt_ghost" ] &&
    pass "every method file has a row, and every row a file ($(printf '%s\n' "$mt_ondisk" | grep -c .) methods)"
fi

# The same table exists a THIRD time, in docs/annex/WSS.CLAUDE-TOOLING.md, and the
# pair above guards only the first two — which is how that copy silently carried a
# false cell until 641fa66 found it by hand.
#
# The ruling on it is the one the record-vs-queue pair above already carries for
# docs/annex/lane-synching.md: the annex is the docs-site reader's CONDENSED copy,
# so its cells are free to differ — a shorter "what it finds", a runner named
# rather than linked, no href at all — and forcing them into step would collapse
# two documents into one. What may not diverge is the row labels. Every method
# the annex teaches must still be one workflow/checks/WSS.CHECKS.md asserts, or
# the docs page is teaching a method the authority renamed or dropped. A method
# the annex skips is condensation, not drift, and stays free.
mt_annex="$CLAUDE_DIR/docs/annex/WSS.CLAUDE-TOOLING.md"
if [ -f "$mt_annex" ] && [ -n "${mt_b:-}" ]; then
  mt_auth=$(printf '%s\n' "$mt_b" | cut -d'|' -f1 | sort -u)
  mt_anx=$(method_rows_ "$mt_annex" | cut -d'|' -f1 | sort -u)
  if [ -z "$mt_anx" ]; then
    fail "no check-method table found in docs/annex/WSS.CLAUDE-TOOLING.md — the
        licence to condense is over the CELLS, not over the header, and a table
        the parser cannot find agrees with everything. It needs a
        '| Method | What it finds | Run by |' table like the other two."
  else
    mt_anx_extra=$(comm -13 <(printf '%s\n' "$mt_auth") <(printf '%s\n' "$mt_anx") | tr '\n' ' ')
    if [ -z "$mt_anx_extra" ]; then
      pass "the annex's check-method rows all exist in workflow/checks/WSS.CHECKS.md ($(printf '%s\n' "$mt_anx" | grep -c .) checked)"
    else
      fail "docs/annex/WSS.CLAUDE-TOOLING.md's check-method table carries methods
        workflow/checks/WSS.CHECKS.md's does not: ${mt_anx_extra}
        The annex condenses the authority's table, so the authority may hold
        rows the annex skips — never the reverse. A method only the annex names
        is one the authority renamed or dropped."
    fi
  fi
else
  pass "no check-method annex to compare"
fi

# ------------------------------------------------------------- who invokes whom

head_ "Who invokes whom"

# The catalog's caller->invokes table is the diagram of the whole suite in table
# form, and until now nothing read it at all: `grep -n "Invokes\|Caller" wss-doctor.sh`
# returned empty while the table carried 15 rows naming skills, writers, scripts,
# check-method files and manifest roles. Two of its rows were repaired by hand in
# one batch, which is the maintenance mode this check exists to end.
#
# What it does NOT assert, and cannot: that the caller actually invokes what its
# row names. That fact lives in the caller's own procedure prose, which no parser
# reads. There is a second hand-copy of the table in docs/annex/WSS.CLAUDE-TOOLING.md,
# but it is licensed to condense on the ruling above, so it can only be compared
# at label level and never settles a cell. So the assertion is the narrower one
# that is still worth having: every referent the table names must RESOLVE — the
# flag to a live flag, the writer to a writers/ file, the script to a script, the
# method to a file in workflow/checks/, the role to a documented manifest role —
# and every writer procedure on disk must be named by somebody. A renamed skill
# or a retired script leaves a row that reads exactly like a live edge, and a new
# writer with no row is the missing-row drift itself.
invokes_cell_() { # file, column (2 = Caller, 3 = Invokes) — the backticked tokens
  awk -v col="$2" '
    /^\|[[:space:]]*Caller[[:space:]]*\|[[:space:]]*Invokes[[:space:]]*\|/ { t = 1; next }
    t && /^\|[[:space:]]*[-:]/ { next }
    t && /^\|/ {
      n = split($0, f, "|")
      if (n >= 5) {
        s = f[col]
        while (match(s, /`[^`]+`/)) {
          tok = substr(s, RSTART + 1, RLENGTH - 2)
          s = substr(s, RSTART + RLENGTH)
          # A span may carry arguments for the referent — `wss-export-records.sh --all`
          # — and the referent is the first word of it.
          sub(/[[:space:]].*/, "", tok)
          if (tok != "") print tok
        }
      }
      next
    }
    t { t = 0 }
  ' "$1" | sort -u
}
iw_cat="$CLAUDE_DIR/.claude/WSS.TOOLING.md"
if [ -f "$iw_cat" ]; then
  iw_callers=$(invokes_cell_ "$iw_cat" 2)
  iw_targets=$(invokes_cell_ "$iw_cat" 3)
  if [ -z "$iw_callers" ] || [ -z "$iw_targets" ]; then
    # The blind-parser guard every table check here carries: a reader that has
    # gone blind resolves nothing and therefore reports nothing wrong.
    fail "no caller->invokes table found in .claude/WSS.TOOLING.md — the check
        needs a '| Caller | Invokes | For |' table with backticked referents,
        and a table that cannot be read resolves perfectly."
  else
    # Which `--` tokens are flags and which are a script's own arguments — `--all`,
    # `--dir`, `--suite` all appear here — is decided by the flag namespace rather
    # than by a hardcoded prefix: the longest prefix every entry of the hook's
    # FLAGS array shares. An installation whose flags share nothing beyond the
    # leading `--` gives no namespace to test against, and this one assertion is
    # skipped rather than guessed at.
    iw_ns=""
    for f in ${flags:-}; do
      if [ -z "$iw_ns" ]; then iw_ns="$f"
      else while [ -n "$iw_ns" ] && [ "${f#"$iw_ns"}" = "$f" ]; do iw_ns="${iw_ns%?}"; done
      fi
    done
    [ "${#iw_ns}" -le 2 ] && iw_ns=""
    iw_scripts=$(find "$CLAUDE_DIR" -name '*.sh' -not -path '*/.git/*' -printf '%f\n' 2>/dev/null | sort -u)
    iw_bad=""
    iw_seen=0
    for tok in $iw_callers $iw_targets; do
      case $tok in
        --*)
          [ -z "$iw_ns" ] && continue
          case $tok in "$iw_ns"*) ;; *) continue ;; esac
          iw_seen=$((iw_seen + 1))
          printf '%s\n' ${flags:-} | grep -qxF -- "$tok" ||
            iw_bad="$iw_bad $tok(no such flag)" ;;
        *.sh)
          iw_seen=$((iw_seen + 1))
          printf '%s\n' "$iw_scripts" | grep -qxF -- "$tok" ||
            iw_bad="$iw_bad $tok(no such script)" ;;
        *-writer|*-tracker)
          iw_seen=$((iw_seen + 1))
          iw_w="WSS.$(printf '%s' "$tok" | tr '[:lower:]' '[:upper:]').md"
          [ -f "$CLAUDE_DIR/workflow/writers/$iw_w" ] ||
            iw_bad="$iw_bad $tok(no workflow/writers/$iw_w)" ;;
        WSS.agents.*)
          iw_seen=$((iw_seen + 1))
          iw_role=${tok#WSS.agents.}
          grep -qF -- "\`$iw_role\`" "$CLAUDE_DIR/workflow/WSS.MANIFEST.md" 2>/dev/null ||
            iw_bad="$iw_bad $tok(no such role in WSS.MANIFEST.md)" ;;
        */*.md)
          iw_seen=$((iw_seen + 1))
          [ -f "$CLAUDE_DIR/$tok" ] || iw_bad="$iw_bad $tok(no such file)" ;;
        wss-*)
          iw_seen=$((iw_seen + 1))
          [ -f "$CLAUDE_DIR/skills/$tok/SKILL.md" ] ||
            iw_bad="$iw_bad $tok(no such skill)" ;;
      esac
    done
    if [ -n "$iw_bad" ]; then
      fail "the caller->invokes table names referents that resolve nowhere:${iw_bad}
        Every edge in that table is a hand-written claim about a file. One that
        no longer resolves reads exactly like a live edge, which is what the
        table is read for."
    else
      pass "every referent in the caller->invokes table resolves ($iw_seen checked)"
    fi

    # The direction the table cannot fail in on its own: a writer procedure added
    # without an edge is invisible, and stays invisible, because nothing else
    # enumerates workflow/writers/. WSS.WRITERS.md is the index rather than a
    # procedure and is never a referent — the same exemption WSS.CHECKS.md has above.
    if [ -d "$CLAUDE_DIR/workflow/writers" ]; then
      iw_named=$(printf '%s\n' $iw_targets | grep -e '-writer$' -e '-tracker$' |
                 tr '[:lower:]' '[:upper:]' | sed 's/^/WSS./;s/$/.md/' | sort -u)
      iw_ondisk=$(find "$CLAUDE_DIR/workflow/writers" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
                  grep -vx 'WSS.WRITERS.md' | sort)
      iw_orphan=$(comm -13 <(printf '%s\n' "$iw_named") <(printf '%s\n' "$iw_ondisk") | tr '\n' ' ')
      if [ -n "$iw_orphan" ]; then
        fail "writer procedure that no caller->invokes row names: $iw_orphan
        The table compares clean because it does not know it exists. Add the
        edge to .claude/WSS.TOOLING.md's 'Who invokes whom'."
      else
        pass "every writer procedure is named by a caller ($(printf '%s\n' "$iw_ondisk" | grep -c .) procedures)"
      fi
    fi

    # And the annex's copy of the same table, on the condensation ruling above:
    # its callers must all be callers the catalog names, never the reverse.
    iw_annex="$CLAUDE_DIR/docs/annex/WSS.CLAUDE-TOOLING.md"
    if [ -f "$iw_annex" ]; then
      iw_anx=$(invokes_cell_ "$iw_annex" 2)
      if [ -z "$iw_anx" ]; then
        fail "no caller->invokes table found in docs/annex/WSS.CLAUDE-TOOLING.md —
        the annex may condense its cells and skip rows, but the table itself is
        one the docs site teaches from, and one that cannot be read agrees with
        everything."
      else
        iw_anx_extra=$(comm -13 <(printf '%s\n' "$iw_callers") <(printf '%s\n' "$iw_anx") | tr '\n' ' ')
        if [ -z "$iw_anx_extra" ]; then
          pass "the annex's callers all exist in the catalog's table ($(printf '%s\n' "$iw_anx" | grep -c .) checked)"
        else
          fail "docs/annex/WSS.CLAUDE-TOOLING.md names callers .claude/WSS.TOOLING.md
        does not: ${iw_anx_extra}
        The annex condenses the catalog, so the catalog may hold rows the annex
        skips — never the reverse. A caller only the annex has is one the
        catalog renamed or dropped."
        fi
      fi
    fi
  fi
else
  pass "no caller->invokes table to compare"
fi

# ------------------------------------------------------- the lane tables, twice

head_ "Lane tables"

# Two lane tables each exist as a pair of hand-copies, filed by audit pass 11's
# F8 and given a check on the owner's ruling. Single-sourcing is the wrong
# answer for the same reason as the check-method tables above: each copy exists
# so its own reader sees the rule in place.
#
# The four-rulings table (skills/lane-record-sync/SKILL.md and
# docs/annex/lane-synching.md) addresses the same reader on both sides, so ALL
# columns must agree — the shape of the check-method comparison. What is free
# to differ is a trailing "— see below" pointer: it is intra-document
# navigation, this pair's analogue of the method tables' link target, and is
# normalised away before comparing.
rulings_rows_() { # file — the "| Ruling | Files to the queue | Next run |" table
  awk '
    /^\|[[:space:]]*Ruling[[:space:]]*\|[[:space:]]*Files to the queue[[:space:]]*\|[[:space:]]*Next run[[:space:]]*\|/ { t = 1; next }
    t && /^\|[[:space:]]*[-:]/ { next }
    t && /^\|/ {
      n = split($0, f, "|")
      if (n >= 5) {
        r = f[2]; q = f[3]; x = f[4]
        sub(/[[:space:]]*—[[:space:]]*see below[[:space:]]*$/, "", q)
        sub(/[[:space:]]*—[[:space:]]*see below[[:space:]]*$/, "", x)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", r)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", q)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", x)
        print r "|" q "|" x
      }
      next
    }
    t { t = 0 }
  ' "$1" | sort
}
rl_skill="$CLAUDE_DIR/skills/lane-record-sync/SKILL.md"
rl_annex="$CLAUDE_DIR/docs/annex/lane-synching.md"
if [ -f "$rl_skill" ] && [ -f "$rl_annex" ]; then
  rl_a=$(rulings_rows_ "$rl_skill")
  rl_b=$(rulings_rows_ "$rl_annex")
  if [ -z "$rl_a" ] || [ -z "$rl_b" ]; then
    # The blind-parser guard both siblings carry: two tables that cannot be
    # read compare equal, and empty-vs-empty is what the agreement rules out.
    rl_blind=""
    [ -z "$rl_a" ] && rl_blind="skills/lane-record-sync/SKILL.md"
    [ -z "$rl_b" ] && rl_blind="${rl_blind:+$rl_blind and }docs/annex/lane-synching.md"
    fail "no four-rulings table found in $rl_blind — the comparison needs a
        '| Ruling | Files to the queue | Next run |' table in both files, and
        two tables that cannot be read compare equal"
  elif [ "$rl_a" = "$rl_b" ]; then
    pass "both four-rulings tables carry the same rows ($(printf '%s\n' "$rl_a" | grep -c .) checked)"
  else
    rl_only_a=$(comm -23 <(printf '%s\n' "$rl_a") <(printf '%s\n' "$rl_b") | cut -d'|' -f1 | sort -u | tr '\n' ' ')
    rl_only_b=$(comm -13 <(printf '%s\n' "$rl_a") <(printf '%s\n' "$rl_b") | cut -d'|' -f1 | sort -u | tr '\n' ' ')
    fail "the two four-rulings tables disagree.
        Differing rows in skills/lane-record-sync/SKILL.md: ${rl_only_a:-none}
        Differing rows in docs/annex/lane-synching.md: ${rl_only_b:-none}
        A ruling named on one side only is a missing row; one named on both is
        a wording drift in its cells. Only a trailing '— see below' pointer may
        differ between the two files."
  fi
else
  pass "no four-rulings table pair to compare"
fi

# The record-vs-queue table (workflow/WSS.LANE-CONTRACT.md and
# docs/annex/lane-synching.md) is the cadence pair's shape instead: the
# contract is the authority with the full wording, the annex a condensed copy
# for the docs-site reader — both born that way in 8b28491, so forcing the
# cells into step would collapse two documents into one. What may not diverge
# is the row labels: every property the annex teaches must still be one the
# contract asserts, or the docs page is teaching a rule the authority renamed
# or dropped. A contract-only row (Write mode, today) is condensation, not
# drift, and stays free.
rvq_labels_() { # file — the label column of the "| | A record | A transfer queue |" table
  awk '
    /^\|[[:space:]]*\|[[:space:]]*A record[[:space:]]*\|[[:space:]]*A transfer queue[[:space:]]*\|/ { t = 1; next }
    t && /^\|[[:space:]]*[-:]/ { next }
    t && /^\|/ {
      n = split($0, f, "|")
      if (n >= 4) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[2])
        if (f[2] != "") print f[2]
      }
      next
    }
    t { t = 0 }
  ' "$1" | sort
}
rvq_contract="$CLAUDE_DIR/workflow/WSS.LANE-CONTRACT.md"
if [ -f "$rvq_contract" ] && [ -f "$rl_annex" ]; then
  rvq_a=$(rvq_labels_ "$rvq_contract")
  rvq_b=$(rvq_labels_ "$rl_annex")
  if [ -z "$rvq_a" ] || [ -z "$rvq_b" ]; then
    rvq_blind=""
    [ -z "$rvq_a" ] && rvq_blind="workflow/WSS.LANE-CONTRACT.md"
    [ -z "$rvq_b" ] && rvq_blind="${rvq_blind:+$rvq_blind and }docs/annex/lane-synching.md"
    fail "no record-vs-queue table found in $rvq_blind — the comparison needs a
        '| | A record | A transfer queue |' table in both files, and two
        tables that cannot be read compare equal"
  else
    rvq_extra=$(comm -13 <(printf '%s\n' "$rvq_a") <(printf '%s\n' "$rvq_b") | tr '\n' ' ')
    if [ -z "$rvq_extra" ]; then
      pass "the annex's record-vs-queue rows all exist in the contract ($(printf '%s\n' "$rvq_b" | grep -c .) checked)"
    else
      fail "docs/annex/lane-synching.md's record-vs-queue table carries rows
        workflow/WSS.LANE-CONTRACT.md's does not: ${rvq_extra}
        The annex condenses the contract's table, so the contract may hold
        rows the annex skips — never the reverse. A label only the annex has
        is a property the authority renamed or dropped."
    fi
  fi
else
  pass "no record-vs-queue table pair to compare"
fi

# ------------------------------------------------- the splittable set, restated

head_ "Splittable set"

# workflow/WSS.LANE-CONTRACT.md names which records may split by lane and says
# the resolution rule is stated once, there. It is not: eight sites restate the
# key list, each one a local read that saves a dispatching skill a lookup. The
# ruling was to keep the copies and make the drift loud rather than cut them to
# a pointer, so this is that check — gaining or losing a splittable key now
# fails here instead of drifting silently through every copy at once.
#
# DISCOVERY BY MARKER, NOT A FILE LIST. Both the canon and its restatements are
# found by their own wording, over md_files_(). A hardcoded list has to be right
# about where the files live, and the tree is under a reorg that moves workflow/
# and skills/ wholesale; it also has to be right about how many there are, and
# the list this check was specified from was already two sites short of what the
# tree held. A marker survives both, and the count below turns a walk that stops
# matching into a FAILURE rather than a green run over an empty set.
#
# What discovery costs is a false-positive risk, so the exclusions are stated
# rather than incidental. Scripts are out because md_files_() reads only *.md —
# which is also what stops this check matching its own source and the test
# fixtures. Records are out because they QUOTE the set rather than dispatch from
# it: docs/ narrates the decision, WSS.TODO.md carried the entry this check came
# from, WSS.CHANGELOG.md logs the change, .claude/ is per-checkout state, and
# audits/ md_files_() already drops. The cost of the *.md line is that
# hooks/wss-session-check.sh and wss-remove-lanes.sh are unchecked; neither
# carries a marker, and neither restates the set — both cite
# workflow/WSS.LANE-CONTRACT.md for it — so neither would match anyway.
#
# The three-key subsets elsewhere (`todo`, `openDecisions`, `roadmap` — the
# transfer queue's targets) carry neither marker: they are a different claim
# about a different thing, and flagging them as drift is the mistake that would
# get this check weakened rather than obeyed.
sp_files_() {
  md_files_ | while IFS= read -r -d '' p; do
    case ${p#"$CLAUDE_DIR"/} in
      docs/* | .claude/* | audits/* | WSS.TODO.md | WSS.CHANGELOG.md) continue ;;
    esac
    printf '%s\0' "$p"
  done
}

# Three of the eight sites wrap the key list across a line break, and one wraps
# between "overrides" and "`WSS.record.X`". A line-based grep sees `todo` and
# `openDecisions` and reports drift on a file that is perfectly correct, so the
# whole file is whitespace-normalised first and the line number recovered from
# an offset map afterwards — the citation still has to point at a real line.
SPLITTABLE_PL='
my $kl = qr/(?:`[A-Za-z]+`(?:,? (?:and )?)?)+/;
for my $f (@ARGV) {
  open(my $fh, "<", $f) or next;
  my $t = ""; my @map; my $ln = 0;
  while (my $l = <$fh>) {
    $ln++;
    $l =~ s/\s+/ /g; $l =~ s/^ //; $l =~ s/ $//;
    push @map, [length($t), $ln];
    $t .= $l . " ";
  }
  close $fh;
  my @hit;
  while ($t =~ /\*\*Splittable: ($kl)\*\*/g)            { push @hit, [$-[0], "canon", $1]; }
  while ($t =~ /overrides `WSS\.record\.X` for ($kl)/g) { push @hit, [$-[0], "site",  $1]; }
  while ($t =~ /only the splittable keys \(($kl)\)/gi)  { push @hit, [$-[0], "site",  $1]; }
  for my $h (@hit) {
    my $line = 1;
    for my $m (@map) { last if $m->[0] > $h->[0]; $line = $m->[1]; }
    my @k = ($h->[2] =~ /`([A-Za-z]+)`/g);
    print join("\t", $h->[1], $f, $line, join(",", @k)), "\n";
  }
}
'

# The one site entitled to name fewer keys than the canon, and exactly which
# ones. --wss-todo writes two records and states the resolution rule for those
# two; the other two are not its business. Matched by path SUFFIX so the reorg
# does not silently promote it back to a full-set site — and if the suffix ever
# stops matching, the site fails as an unexplained subset rather than passing.
# Every key it names is still checked against the canon below, so this list
# grants a shorter list, never a stale one.
#
# BOTH spellings are required and neither is redundant. This doctor runs in two
# trees: the source tree, where the skill is `skills/record/`, and the
# published assembly, where wss-publish.sh has stripped the `wss-` prefix and
# the same file is `skills/record/`. Listing only the source spelling does not
# make the check lenient in the assembly — it makes it FAIL there, because an
# unrecognised subset is reported as drift, which then also trips the suite's
# blind-parser guard. That is a Gate 3 failure on a tree with nothing wrong
# with it, and it is how v0.10.2's publication broke: the check landed in
# 6c2c088, after the last green publish, so no gate ever ran it post-strip.
# Same class as the Gate 2 backstop at wss-publish.sh:297 — read that comment
# before touching either.
sp_declared_subset_() { # rel-path, comma-joined keys
  case $1 in
    */wss:record/SKILL.md | record/SKILL.md \
    | */record/SKILL.md | record/SKILL.md) [ "$2" = "todo,openDecisions" ] ;;
    *) false ;;
  esac
}

sp_rows=$(sp_files_ | xargs -0 -r perl -e "$SPLITTABLE_PL" 2>/dev/null || true)
sp_canon_rows=$(printf '%s\n' "$sp_rows" | grep '^canon' || true)
sp_site_rows=$(printf '%s\n' "$sp_rows" | grep '^site' || true)
sp_canon_n=$(printf '%s' "$sp_canon_rows" | grep -c . || true)
sp_n=$(printf '%s' "$sp_site_rows" | grep -c . || true)

if [ "$sp_canon_n" -eq 0 ] && [ "$sp_n" -eq 0 ]; then
  # Not a suite tree — an adopted project carries neither the contract nor
  # anything restating it, and has nothing here to disagree about.
  pass "no splittable-set contract here, and nothing restating one"
elif [ "$sp_canon_n" -eq 0 ]; then
  fail "$sp_n site(s) restate the splittable set and no contract states it.
        The authority is the line reading '**Splittable: \`todo\`, ...**' in
        workflow/WSS.LANE-CONTRACT.md. Either it moved somewhere this walk does
        not reach, or its wording changed — and the copies are now the only
        statement of the rule, which is what the contract exists to prevent."
elif [ "$sp_canon_n" -gt 1 ]; then
  fail "the splittable set is declared as canon in more than one place:
        $(printf '%s\n' "$sp_canon_rows" | while IFS=$'\t' read -r _ f l _; do
              printf '%s:%s ' "${f#"$CLAUDE_DIR"/}" "$l"; done)
        One authority, or the restatements have two things to agree with.
        workflow/WSS.LANE-CONTRACT.md owns it."
elif [ "$sp_n" -eq 0 ]; then
  # The whole safety of this check. Every site is found by wording, so a
  # wording change makes the walk match nothing and report green forever while
  # checking nothing at all.
  fail "the splittable set is stated in $(printf '%s' "$sp_canon_rows" |
          cut -f2 | sed "s|^$CLAUDE_DIR/||") and NOTHING restates it.
        Every dispatching skill used to carry the key list so its reader need
        not follow a link. Zero sites means the markers this walk looks for
        ('overrides \`WSS.record.X\` for', 'only the splittable keys') have been
        reworded or the files moved out of md_files_()'s reach — either way
        this check is now walking an empty set and passing."
else
  sp_canon=$(printf '%s' "$sp_canon_rows" | cut -f4)
  sp_canon_at="$(printf '%s' "$sp_canon_rows" | cut -f2 | sed "s|^$CLAUDE_DIR/||"):$(printf '%s' "$sp_canon_rows" | cut -f3)"
  sp_full=0
  sp_sub=0
  sp_bad=0
  while IFS=$'\t' read -r _ f ln keys; do
    [ -n "$f" ] || continue
    rel=${f#"$CLAUDE_DIR"/}
    if [ "$keys" = "$sp_canon" ]; then
      sp_full=$((sp_full + 1))
      continue
    fi
    # A shorter list is allowed only where it is declared, and only if every
    # key it names is still one the canon carries — otherwise a canon that
    # dropped a key would leave the exemption pinning a key that no longer
    # splits, which is the drift this check exists for wearing a permit.
    sp_stale=0
    for k in $(printf '%s' "$keys" | tr ',' ' '); do
      case ",$sp_canon," in *",$k,"*) ;; *) sp_stale=1 ;; esac
    done
    if [ "$sp_stale" -eq 0 ] && sp_declared_subset_ "$rel" "$keys"; then
      sp_sub=$((sp_sub + 1))
      continue
    fi
    fail "$rel:$ln restates the splittable set as
        '$keys' where $sp_canon_at states '$sp_canon'.
        Either the contract gained or lost a key and this copy was not
        followed, or this copy was edited alone. The contract is the authority;
        a site that means to name a SUBSET has to be declared as one in
        wss-doctor.sh's sp_declared_subset_, with which keys and why."
    sp_bad=$((sp_bad + 1))
  done < <(printf '%s\n' "$sp_site_rows")
  [ "$sp_bad" -eq 0 ] &&
    pass "every splittable-set restatement matches $sp_canon_at ($sp_full full, $sp_sub declared subset)"
fi

# ------------------------------------------------------------- one writer each

head_ "Sole writers"

# One record, one writer is the invariant the whole ownership matrix exists to
# state, and until now nothing asserted it — the matrix was 30-odd rows of dense
# prose checked by reading. A second row quietly claiming a record another row
# already owns produces exactly the drift the invariant forbids: two procedures
# each maintaining the half they know about, neither of them wrong about it.
#
# Two normalisations keep this from needing exceptions, and both follow the
# matrix's own wording rather than working around it. A cell beginning "nothing"
# disclaims ownership, so its prose may name records freely. And a row whose
# skill dispatches to a `writers/` procedure is attributed to that procedure,
# because the cell already says the record is the writer's and the skill "writes
# nothing" — attributing it to the skill is what would make the writer's own row
# read as a second claim.
sole_writers_() { # file — "record<TAB>writer" for every row that claims one
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
          while (match(own, /WSS\.(record|lanes)\.[a-zA-Z]+|WSS\.sweeps/)) {
            print substr(own, RSTART, RLENGTH) "\t" who
            own = substr(own, RSTART + RLENGTH)
          }
      }
      next
    }
    t { t = 0 }
  ' "$1" | sort -u
}
own_matrix="$CLAUDE_DIR/workflow/WSS.OWNERSHIP.md"
if [ -f "$own_matrix" ]; then
  sw=$(sole_writers_ "$own_matrix")
  # The blind-parser guard every comparison here carries, and it has to be the
  # HEADER rather than the row count: a matrix in which every row disclaims
  # ownership legitimately yields no claims, and treating that as blindness
  # would fail a correct file. A renamed header is the failure worth catching,
  # because it leaves a parser reporting no conflicts over a table full of them.
  if ! grep -qE '^\|[[:space:]]*Verb[[:space:]]*\|.*\|[[:space:]]*Sole writer of[[:space:]]*\|' "$own_matrix"; then
    fail "no ownership matrix found in workflow/WSS.OWNERSHIP.md — the check needs
        a '| Verb | Flag | ... | Sole writer of | ...' table, and a matrix that
        cannot be read has no duplicate writers by construction"
  elif [ -z "$sw" ]; then
    pass "the ownership matrix is readable and no row claims a record"
  else
    sw_dup=$(printf '%s\n' "$sw" | cut -f1 | uniq -d)
    if [ -z "$sw_dup" ]; then
      pass "every record has exactly one writer ($(printf '%s\n' "$sw" | grep -c .) claims)"
    else
      for k in $sw_dup; do
        fail "two writers claim $k: $(printf '%s\n' "$sw" | awk -F'\t' -v k="$k" '$1==k{printf "%s ", $2}')
        One record, one writer. Whichever row is wrong, both currently read as
        authoritative and each will maintain the half it knows about."
      done
    fi
  fi
else
  pass "no ownership matrix to check"
fi

# --------------------------------------------------------------- audit reports

head_ "Audit reports"

# The reports under audits/ are frozen and excluded from every markdown check
# above; the maintained index of them is `WSS.record.audits` — since 2026-08-07
# `docs/WSS.AUDITS.md`, resolved from the tree's own manifest below, with
# `audits/README.md` (now a pointer stub, still where the index lives in a tree
# that declares no key) as the fallback. Two things about the old arrangement
# had already failed silently, and each gets a check.
#
# 1. The index skipped a report: the file landed, the table row did not, and the
#    index's own warning about stale counts sat one section above the gap. It
#    said "four" once after there were more, and skipped pass 6 entirely on
#    2026-08-02 — nothing compared rows against the directory until this did.
a_idx_rel=$(jq -r '.WSS.record.audits // empty | if type == "string" then . else empty end' \
  "$CLAUDE_DIR/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
[ -n "$a_idx_rel" ] || a_idx_rel="audits/README.md"
a_idx="$CLAUDE_DIR/$a_idx_rel"
if [ -f "$a_idx" ]; then
  a_missing=0 a_total=0
  for a_f in "$CLAUDE_DIR"/audits/*.md; do
    [ -e "$a_f" ] || continue
    a_b=$(basename "$a_f")
    [ "$a_b" = "README.md" ] && continue
    a_total=$((a_total + 1))
    if ! grep -qF "| \`$a_b\` |" "$a_idx"; then
      fail "$a_idx_rel has no index row for $a_b — the index of the audit
        reports is in scope precisely because it is maintained, and a report
        without a row is invisible to everyone who trusts the table"
      a_missing=$((a_missing + 1))
    fi
  done
  if [ "$a_total" -eq 0 ]; then
    pass "audits/ holds no reports beyond the index"
  elif [ "$a_missing" -eq 0 ]; then
    pass "every audit report has an index row ($a_total checked)"
  fi
else
  pass "no $a_idx_rel — no audit index to check"
fi

# 2. The frozen-reports exemption exists in two places — md_files_ above, and
#    CI's two markdown-walking steps — and it once landed in one and not the
#    other, leaving CI red for eleven commits on a report that is frozen by
#    design. A workflow step cannot call a function here, so the walk cannot be
#    sourced once; this asserts the hand-copies agree instead. The needles are
#    md_files_'s own pathspecs: change them there and this fails until
#    verify.yml follows, which is the point. The credential scan is asserted
#    the OTHER way — it must keep walking every tracked file, because a
#    credential in a frozen report is still a credential.
verify_yml="$CLAUDE_DIR/.github/workflows/verify.yml"
if [ -f "$verify_yml" ]; then
  v_ex=$(grep -cF ":(exclude)audits/**" "$verify_yml" || true)
  v_re=$(grep -cF "git ls-files -z 'audits/README.md'" "$verify_yml" || true)
  v_bare=$(grep -cF "< <(git ls-files -z)" "$verify_yml" || true)
  if [ "$v_ex" -eq 2 ] && [ "$v_re" -eq 2 ]; then
    pass "CI's two markdown walks carry md_files_'s exemption pair"
  else
    fail "verify.yml's markdown walks disagree with md_files_: expected the
        audits exclusion and the README re-add twice each, found $v_ex and $v_re.
        The walks are hand-copied and must stay identical — the last drift left
        CI red for eleven commits (WSS.HAZARDS.md, 'Reading CI')"
  fi
  if [ "$v_bare" -ge 1 ]; then
    pass "CI's credential scan still walks every tracked file"
  else
    fail "verify.yml's credential scan no longer walks bare 'git ls-files -z' —
        excluding audits/ there would exempt frozen files from the one check
        that must never exempt anything"
  fi
else
  pass "no .github/workflows/verify.yml — no CI walk to compare"
fi

# -------------------------------------------------------------------- manifest

head_ "Project workflow manifest"

manifest="$PWD/.claude/WSS.WORKFLOW.json"
SUPPORTED="workflow/v2"

# The PRE-RENAME manifest filename is its own case, checked before the current
# one — and independently of it. A `.claude/workflow.json` tree is not an
# unadopted tree: nothing reads that filename any more, so without this check a
# five-lane pre-rename project reports "all checks passed … project is unsplit"
# while every section below runs against fallbacks (issue #16's first bite —
# the old *schema* under the new filename was already rejected; the old
# *filename* was simply never looked for).
if [ -f "$PWD/.claude/workflow.json" ]; then
  if [ -f "$manifest" ]; then
    fail "both .claude/WSS.WORKFLOW.json and the pre-rename .claude/workflow.json
        exist. The legacy file is dead to every reader, so this reads as a
        migration that never finished — finish it with --wss-update, or remove
        the legacy file if the migration is in fact complete."
  else
    fail "pre-rename manifest found: .claude/workflow.json. No current reader
        looks for that filename, so this project's records, lanes and commands
        all silently fall back to defaults. Snapshot first (wss-export-records.sh
        --all reads the legacy manifest), then migrate with --wss-update."
  fi
fi

if [ ! -f "$manifest" ]; then
  [ -f "$PWD/.claude/workflow.json" ] || \
  pass "no .claude/WSS.WORKFLOW.json — skills fall back to conventional filenames"
elif ! jq -e . "$manifest" >/dev/null 2>&1; then
  fail "WSS.WORKFLOW.json is not valid JSON"
else
  v=$(jq -r '.WSS.manifest // empty' "$manifest")
  if [ -z "$v" ]; then
    fail "WSS.WORKFLOW.json has no \"manifest\" version. A global skill then cannot
        tell which shape it is holding, so a renamed key reads as absent rather
        than as an error — and absent is the dangerous answer, because it looks
        like 'no value configured'."
  elif ! printf '%s\n' $SUPPORTED | grep -qx "$v"; then
    fail "WSS.WORKFLOW.json declares '$v'; this checkout understands: $SUPPORTED"
  else
    pass "WSS.WORKFLOW.json declares $v"
  fi

  # Key names, against workflow/WSS.MANIFEST.md. The drift this catches is a key
  # that reads as configured and is read by nothing — two names for one concept
  # (`indexCheck` where every consumer wants `indexRegen`), or a key invented
  # for a skill that never looked it up. Warn rather than fail: an unknown key
  # is dead config, not a broken one.
  #
  # Containers with project-chosen sub-keys — hazards, gate.coverage,
  # audit.invalidates, WSS.lanes.named — are deliberately not descended into.
  KNOWN_KEYS='WSS.manifest WSS.branch WSS.record WSS.commands WSS.gate WSS.agents WSS.lanes WSS.audit
WSS.onSchemaChange WSS.hazards WSS.commitTrailer WSS.sweeps WSS.localCI
WSS.suite WSS.suite.version WSS.suite.commit
WSS.docs WSS.docs.root WSS.docs.languages WSS.docs.devCommand
WSS.branch.integration WSS.branch.publish WSS.branch.mergeMethod
WSS.record.todo WSS.record.roadmap WSS.record.releases WSS.record.changelog WSS.record.handoff WSS.record.decisions
WSS.record.decisionsIndex WSS.record.openDecisions WSS.record.behaviour WSS.record.reference
WSS.record.stocktake WSS.record.audits WSS.record.toolbelt WSS.record.tooling
WSS.record.tooling.catalog WSS.record.tooling.sources
WSS.commands.typecheck WSS.commands.test WSS.commands.indexRegen WSS.commands.indexCheck
WSS.commands.testConsentEnv WSS.commands.ci
WSS.agents.architecture WSS.agents.implement WSS.agents.infra WSS.agents.test WSS.agents.exploit
WSS.agents.audit WSS.agents.roadmap WSS.agents.release
WSS.lanes.exclusive WSS.lanes.serialize WSS.lanes.generated WSS.lanes.named WSS.lanes.conflicts
WSS.audit.dimensions WSS.audit.invalidates
WSS.gate.coverage'

  # Counted, like every other loop here that reads a shape it does not own. The
  # container list in the jq below is hardcoded, so keys nested under a container
  # it does not name are never enumerated at all — they are invisible rather than
  # unknown, and the pass line printed anyway. The count is what makes that
  # visible: a manifest always has at least `manifest`, so zero means the
  # enumeration failed, not that the file is empty.
  unknown=0; keys_seen=0
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    keys_seen=$((keys_seen + 1))
    printf '%s\n' $KNOWN_KEYS | grep -qx "$k" && continue
    warn "WSS.WORKFLOW.json sets '$k', which no global skill reads.
        See ~/.claude/workflow/WSS.MANIFEST.md for the keys that exist."
    unknown=$((unknown + 1))
  done < <(jq -r '
      (.WSS // empty | keys[] | "WSS.\(.)"),
      (["branch","record","commands","agents","lanes","audit","suite","docs"][] as $k
         | (.WSS[$k] // empty | keys[]? | "WSS.\($k).\(.)")),
      (.WSS.record.tooling // empty | keys[]? | "WSS.record.tooling.\(.)")
    ' "$manifest" 2>/dev/null | sort -u)
  if [ $keys_seen -eq 0 ]; then
    warn "no keys could be enumerated out of WSS.WORKFLOW.json, though it parsed as
        JSON and declares a version. Nothing was checked against WSS.MANIFEST.md."
  elif [ $unknown -eq 0 ]; then
    pass "every key is one WSS.MANIFEST.md documents ($keys_seen checked)"
  fi

  # The migration stamp. Detection overrides a wrong stamp, so a malformed one
  # cannot corrupt a migration — but it silently buys nothing: update
  # ignores it and re-derives everything from the tree. Warn, not fail.
  if jq -e '.WSS.suite != null' "$manifest" >/dev/null 2>&1; then
    if jq -e '.WSS.suite | (type == "object")
                and (.version | type == "string" and length > 0)
                and (.commit  | type == "string" and length > 0)' \
          "$manifest" >/dev/null 2>&1; then
      pass "WSS.suite stamp carries a version and a commit"
    else
      warn "WSS.suite is declared but is not an object with non-empty string
        \"version\" and \"commit\". update ignores a malformed stamp and
        detects from the tree — the stamp as written buys nothing."
    fi
  fi

  # The docs block. workflow/checks/WSS.DOCS-AUDIT.md resolves every one of its
  # shell blocks from these three values, so a wrong one is silent in the worst
  # way an audit can be: a root that resolves to nothing makes every check walk
  # an empty set and report a clean site. Fail rather than warn — unlike the
  # suite stamp, nothing here re-derives the truth from the tree once the key
  # is present, because the key exists precisely to override the fallback.
  if jq -e '.WSS.docs != null' "$manifest" >/dev/null 2>&1; then
    docs_bad=0
    droot=""
    if ! jq -e '.WSS.docs | type == "object"' "$manifest" >/dev/null 2>&1; then
      fail "WSS.docs is not an object. It carries \"root\", \"languages\" and
        \"devCommand\" — see workflow/WSS.MANIFEST.md."
      docs_bad=1
    else
      if jq -e '.WSS.docs | has("root")' "$manifest" >/dev/null 2>&1; then
        if ! jq -e '.WSS.docs.root | type == "string" and length > 0' \
              "$manifest" >/dev/null 2>&1; then
          fail "WSS.docs.root is not a non-empty string. It names the directory
        the site's markdown lives in, relative to the project root."
          docs_bad=1
        else
          droot=$(jq -r '.WSS.docs.root' "$manifest")
          if [ ! -d "$PWD/$droot" ]; then
            fail "WSS.docs.root declares '$droot', which is not a directory here.
        Every docs check then walks an empty set and reports a clean site —
        the one failure an audit cannot survive. Fix the path, or drop the key
        and let the fallback (docs/, doc/, documentation/, website/) resolve it."
            docs_bad=1
          fi
        fi
      fi
      if jq -e '.WSS.docs | has("languages")' "$manifest" >/dev/null 2>&1; then
        if ! jq -e '.WSS.docs.languages
                      | type == "array" and length > 0
                        and (map(type == "string" and length > 0) | all)' \
              "$manifest" >/dev/null 2>&1; then
          fail "WSS.docs.languages is not a non-empty array of non-empty strings.
        Its first element is the ROOT language, whose pages sit at the docs
        root; every later one is a subdirectory under it. Absent means
        monolingual, which is what an empty list was trying to say."
          docs_bad=1
        else
          # Every element AFTER the first is a translation living at
          # <root>/<lang>/; the first IS the root language and lives at <root>
          # itself. A declared translation whose directory does not exist is the
          # same silent green the root check above exists to prevent —
          # WSS.DOCS-AUDIT.md section 5 loops $TRANSLATIONS[], finds no pages to
          # compare, and reports parity for a language that is not there.
          #
          # warn, never fail, and deliberately NOT setting docs_bad: a language
          # declared before its first page is written is a legitimate
          # intermediate state, and the pass line below claims only that the
          # shape is declared rather than guessed, which stays true. That is the
          # whole difference from a bad root, which nothing re-derives.
          dlroot="$droot"
          # Same fallback order as workflow/WSS.MANIFEST.md's for a root left
          # undeclared — checking <lang>/ against a root this resolves
          # differently from the audit would report on a tree neither walks.
          # Only where the key is absent, though: a "root" that is present and
          # malformed has already failed above, and falling back there would
          # report the languages against a directory the audit will never walk.
          if [ -z "$dlroot" ] &&
             ! jq -e '.WSS.docs | has("root")' "$manifest" >/dev/null 2>&1; then
            for d in docs doc documentation website; do
              [ -d "$PWD/$d" ] && { dlroot=$d; break; }
            done
          fi
          if [ -n "$dlroot" ] && [ -d "$PWD/$dlroot" ]; then
            while IFS= read -r dlang; do
              [ -n "$dlang" ] || continue
              [ -d "$PWD/$dlroot/$dlang" ] && continue
              warn "WSS.docs.languages declares '$dlang', but $dlroot/$dlang/ does not
        exist. Only the FIRST element lives at the docs root; every later one is
        a translation with its own directory, so the parity check in
        workflow/checks/WSS.DOCS-AUDIT.md walks an empty set for this one and
        reports parity for a language that is not there. Expected while the
        pages are still to be written — otherwise the name or the order is wrong."
            done < <(jq -r '.WSS.docs.languages | .[1:] | .[]' "$manifest" 2>/dev/null)
          fi
        fi
      fi
      if jq -e '.WSS.docs | has("devCommand")' "$manifest" >/dev/null 2>&1; then
        if ! jq -e '.WSS.docs.devCommand | type == "string" and length > 0' \
              "$manifest" >/dev/null 2>&1; then
          fail "WSS.docs.devCommand is not a non-empty string. It is the shell
        command that starts the site's dev server, for the render step no grep
        replaces; absent means that step is skipped."
          docs_bad=1
        fi
      fi
    fi
    [ "$docs_bad" -eq 0 ] && pass "WSS.docs resolves: the site shape is declared, not guessed"
  fi

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    file=${p%%#*}
    frag=""
    case $p in *\#*) frag=${p#*\#} ;; esac

    # A declared value may be a glob — WSS.record.tooling.sources is one — in which
    # case "exists" means it matches at least one file today.
    case $file in
      *[*?]*)
        shopt -s nullglob
        # $file is deliberately unquoted — it is the glob. $PWD is NOT: a project
        # path with a space word-split into two array entries and the check
        # reported "matches nothing" on a healthy manifest.
        # shellcheck disable=SC2206
        m=( "$PWD"/$file )
        shopt -u nullglob
        if [ ${#m[@]} -gt 0 ]; then pass "glob matches ${#m[@]}: $file"
        else fail "glob in WSS.WORKFLOW.json matches nothing: $file"
        fi
        continue ;;
    esac

    if [ ! -e "$PWD/$file" ]; then
      fail "declared in WSS.WORKFLOW.json but missing: $file"
    elif [ -z "$frag" ]; then
      pass "path exists: $file"
    elif ! command -v python3 >/dev/null 2>&1; then
      warn "$file exists; anchor #$frag unverified (needs python3)"
    elif python3 -c "$ANCHOR_PY" "$PWD/$file" "$frag" 2>/dev/null; then
      pass "path + anchor resolve: $p"
    else
      fail "$file exists but contains no heading anchored #$frag —
        the pointer resolves to the top of the file, silently"
    fi
  # A provider object under WSS.record.* is NOT a set of paths. Walking it with
  # `.. | strings` yielded its provider name, its repo slug and its label, and
  # reported all three as declared-but-missing files — three failures for one
  # correct manifest. Skip any record entry that carries a `provider` key, and
  # let the provider section below check it instead. `WSS.record.tooling` is an
  # object too and has no such key, so it still walks.
  done < <(jq -r '[(.WSS.record // {}
                     | to_entries[]
                     | select((.value | type) != "object" or ((.value | has("provider")) | not))
                     | .value | .. | strings),
                   (.WSS.hazards // {} | .. | strings)] | .[]' \
             "$manifest" 2>/dev/null | sort -u)
fi

# -------------------------------------------------------------- worktree lanes

head_ "Worktree lanes"

# `WSS.lanes.named` splits the four forward-looking records into per-lane files —
# the resolution rule and the splittable set are workflow/WSS.LANE-CONTRACT.md's.
# Everything that can go wrong with a split is silent
# from inside a session: a selector naming a lane nobody declared resolves to
# the unsplit records, so two worktrees quietly share one file; a half-split
# does the same for whichever lane was left out; a lane redirecting a record
# that must never split fragments a single timeline across files nobody reads
# together. Each has to surface here or it surfaces as a merge conflict — or
# worse, as a silent overwrite that never conflicts at all.
selector="$PWD/.claude/WSS.LANE"
lane_names=""
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  lane_names=$(jq -r '.WSS.lanes.named // {} | keys[]' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
fi

if [ -z "$lane_names" ]; then
  if [ -f "$selector" ]; then
    fail ".claude/WSS.LANE exists but the manifest declares no WSS.lanes.named, so the
        selector resolves to nothing and every reader falls back to the
        unsplit records, silently. Declare the lanes or delete the selector."
  else
    pass "no WSS.lanes.named — project is unsplit"
  fi
  # Declaring the inbox with no lanes is dead config: a contradiction BETWEEN
  # lanes needs lanes to exist, and lane-record-sync refuses to run below
  # two, so nothing writes it and nothing would consume it.
  if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ] &&
     jq -e '.WSS.lanes.conflicts != null' "$PWD/.claude/WSS.WORKFLOW.json" >/dev/null 2>&1; then
    warn "WSS.lanes.conflicts is declared but no lanes are named, so nothing can
        file a cross-lane contradiction and lane-record-sync refuses to
        run. Declare the lanes or drop the key."
  fi
else
  n_lanes=$(printf '%s\n' "$lane_names" | grep -c . || true)

  # Only the splittable records may be redirected, and every declared path
  # must exist — the same contract the WSS.record.* walk above holds paths to.
  lane_bad=0
  while IFS=$'\t' read -r lname key val; do
    [ -n "$lname" ] || continue
    case $key in
      todo | openDecisions | handoff | roadmap) ;;
      transfer)
        fail "WSS.lanes.named.$lname.records.transfer — the transfer queue is a
        SIBLING of records, not a key inside it. Everything under records has
        exactly one writer and a queue has many, which is what the nesting
        says. Move it to WSS.lanes.named.$lname.transfer.
        workflow/WSS.LANE-CONTRACT.md."
        lane_bad=$((lane_bad + 1))
        continue ;;
      releases)
        fail "WSS.lanes.named.$lname.records.releases — the release list never
        splits. It holds the milestones, their versions and their marks, and
        --wss-release reads it and no other planning record; a per-lane copy
        is a release checkpoint one worktree cut for the whole project. Goals
        split by lane, in roadmap. workflow/WSS.LANE-CONTRACT.md."
        lane_bad=$((lane_bad + 1))
        continue ;;
      *)
        fail "WSS.lanes.named.$lname.records.$key — '$key' is not a splittable
        record. Only todo, openDecisions, handoff and roadmap may split by
        lane: the append-only logs are single timelines, releases must be
        singular to stay a release checkpoint, and behaviour and reference
        describe one system. workflow/WSS.LANE-CONTRACT.md."
        lane_bad=$((lane_bad + 1))
        continue ;;
    esac
    if [ ! -e "$PWD/$val" ]; then
      fail "declared in WSS.lanes.named.$lname.records but missing: $val"
      lane_bad=$((lane_bad + 1))
    fi
  done < <(jq -r '.WSS.lanes.named | to_entries[] | .key as $l
                    | (.value.records // {}) | to_entries[]
                    | "\($l)\t\(.key)\t\(.value)"' \
             "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null)
  [ "$lane_bad" -eq 0 ] &&
    pass "every lane record is splittable and its path exists ($n_lanes lane(s))"

  # All lanes or none, per record. A record split for only some lanes leaves
  # the rest sharing the unsplit file — two writers on one path, the exact
  # collision lanes exist to remove, reintroduced one lane at a time.
  half_split=0
  for k in todo openDecisions handoff roadmap; do
    c=$(jq -r --arg k "$k" \
          '[.WSS.lanes.named[] | select(.records[$k] != null)] | length' \
          "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || echo 0)
    if [ "${c:-0}" -ne 0 ] && [ "${c:-0}" -ne "$n_lanes" ]; then
      fail "record '$k' is split for $c of $n_lanes lanes. A splittable record
        splits for ALL named lanes or NONE — the lanes left out share the
        unsplit file, which is two writers on one path."
      half_split=$((half_split + 1))
    fi
  done
  [ "$half_split" -eq 0 ] &&
    pass "no half-split records — each splits for all lanes or none"

  # The transfer queue: one inbox per lane, where every OTHER lane files work it
  # believes this lane owns. Declared for all lanes or none — a lane with no
  # queue is a lane nothing can file to, which reads as "nobody needs anything
  # from them" and is almost never true. Tracked, unlike the selector, because
  # an entry has to travel to the worktree it is addressed to.
  n_tr=$(jq -r '[.WSS.lanes.named[] | select(.transfer != null)] | length' \
           "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || echo 0)
  if [ "${n_tr:-0}" -eq 0 ]; then
    pass "no transfer queues declared — lanes cannot file work to each other"
  elif [ "${n_tr:-0}" -ne "$n_lanes" ]; then
    fail "a transfer queue is declared for $n_tr of $n_lanes lanes. Declare one
        for every named lane or none: a lane without a queue is one no sibling
        can file to, and the request goes into that lane's records by hand
        instead — which is the second writer the queue exists to prevent."
  else
    tr_bad=0
    while IFS=$'\t' read -r lname val; do
      [ -n "$lname" ] || continue
      if [ ! -e "$PWD/$val" ]; then
        fail "WSS.lanes.named.$lname.transfer is missing: $val. An absent queue is
        not an empty one — a sibling appending to it creates a file nothing
        was told to read."
        tr_bad=$((tr_bad + 1))
      fi
    done < <(jq -r '.WSS.lanes.named | to_entries[]
                      | select(.value.transfer != null)
                      | "\(.key)\t\(.value.transfer)"' \
               "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null)
    [ "$tr_bad" -eq 0 ] &&
      pass "every lane declares a transfer queue and its path exists ($n_lanes lane(s))"
  fi

  # The second queue: ONE per project, consumed by lane-record-sync. A
  # contradiction between two lanes belongs to neither, so it is not a per-lane
  # key — filing it to one of the two would pick a side before anyone has ruled.
  # Absent is legal (nothing has been filed and the skill derives its own), but a
  # declared path that does not exist is the silent case: a session appends and
  # creates a file nothing was told to read.
  confl=$(jq -r '.WSS.lanes.conflicts // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
  if [ -z "$confl" ]; then
    pass "no conflict inbox declared — synch derives its own conflicts only"
  elif [ ! -e "$PWD/$confl" ]; then
    fail "WSS.lanes.conflicts is missing: $confl. A session filing a contradiction
        would create a file nothing reads, and the only consumer is
        lane-record-sync."
  else
    pass "conflict inbox declared and present: $confl"
  fi

  # The selector, where this checkout carries one. Its absence is normal — the
  # main checkout of a split project legitimately reads the unsplit records.
  if [ -f "$selector" ]; then
    sel=$(tr -d '[:space:]' < "$selector" 2>/dev/null || true)
    if [ -z "$sel" ]; then
      fail ".claude/WSS.LANE is empty — it must hold exactly one declared lane name"
    elif printf '%s\n' "$lane_names" | grep -qx "$sel"; then
      pass "selector: this worktree is lane '$sel'"
    else
      fail ".claude/WSS.LANE names '$sel', which WSS.lanes.named does not declare.
        Every reader would fall back to the unsplit records, silently —
        declare the lane or fix the selector."
    fi
  else
    pass "no .claude/WSS.LANE selector — this checkout reads the unsplit records"
  fi
fi

# ------------------------------------------------------------ roadmap purity

head_ "Roadmap purity"

# A roadmap holds goals; WSS.record.releases holds the milestones, their versions
# and their marks. That prohibition is the ONLY thing keeping a release
# checkpoint singular once roadmaps split by lane — --wss-release reads
# WSS.record.releases and no other planning record, so a version or a mark written
# into a lane's roadmap is a checkpoint one worktree cut for the whole project,
# and nothing downstream would ever notice it. WSS.RECORD-CONTRACT.md states the
# rule; this is what makes it a mechanism.
#
# Heading-anchored on purpose. A roadmap block may legitimately mention a
# version in prose ("blocked until the auth rewrite ships in 2.x"); a version
# or a *completed* mark in a HEADING is the milestone shape and nothing else.
roadmap_paths=""
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  roadmap_paths=$(jq -r '[.WSS.record.roadmap // empty]
                          + [(.WSS.lanes.named // {})[] | .records.roadmap // empty]
                          | .[]' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
elif [ -f "$PWD/WSS.ROADMAP.md" ]; then
  roadmap_paths="WSS.ROADMAP.md"
fi

if [ -z "$roadmap_paths" ]; then
  pass "no roadmap declared — nothing to check"
else
  roadmap_dirty=0; roadmap_seen=0
  while IFS= read -r rp; do
    [ -n "$rp" ] || continue
    [ -f "$PWD/$rp" ] || continue
    roadmap_seen=$((roadmap_seen + 1))
    hit=$(grep -nE '^#{1,6} .*(\*completed\*|v?[0-9]+\.[0-9]+\.[0-9]+)' \
            "$PWD/$rp" 2>/dev/null | head -3 || true)
    if [ -n "$hit" ]; then
      fail "$rp carries a version number or a completion mark in a heading:
$(printf '%s\n' "$hit" | sed 's/^/          /')
        Those belong in WSS.record.releases. A roadmap holds goals only — it is
        what may split by lane, and a mark in a lane's copy is a release
        checkpoint one worktree cut for the whole project.
        workflow/WSS.RECORD-CONTRACT.md."
      roadmap_dirty=$((roadmap_dirty + 1))
    fi
  done <<EOF
$roadmap_paths
EOF
  if [ "$roadmap_seen" -eq 0 ]; then
    pass "no roadmap file present — nothing to check"
  elif [ "$roadmap_dirty" -eq 0 ]; then
    pass "no roadmap carries a version or a completion mark ($roadmap_seen file(s))"
  fi
fi

# ---------------------------------------------------------------- bug reports

head_ "Bug reports against this config"

# Filed by sessions working in OTHER projects, which may not edit a global skill
# and so append here instead. Nothing else ever surfaces them: the session that
# wrote one is long cleared, and the file is gitignored so it never shows up in
# a git status either. Unsurfaced, the inbox is the same lost finding it was
# built to prevent — one indirection further along.
# CONFIG_DIR, deliberately, not CLAUDE_DIR. The inbox is CROSS-PROJECT state and
# the one file here whose loss is unrecoverable — a lost sweep checkpoint costs a
# re-sweep, a lost inbox discards findings filed from projects nobody will revisit.
# Resolved against the plugin root it would sit in a directory that changes on
# every update, so each update would silently empty it.
inbox="$CONFIG_DIR/WSS.BUG-REPORTS.md"
if [ ! -f "$inbox" ]; then
  pass "no WSS.BUG-REPORTS.md — nothing filed from another project"
else
  # Where the file carries the append marker, count only BELOW it: the entry
  # template above it is a literal `## [open] <one-line summary>` inside a
  # fence, so a naive grep reports one open report on a completely empty inbox
  # — forever, and a warning that is always there is one nobody reads.
  # A file WITHOUT the marker counts in full. No filing template mentions the
  # marker, so a fresh machine's first filing creates the file bare — and
  # requiring it made every entry on every such machine invisible to both
  # counters (audit pass 9, F1: proven against a well-formed marker-less inbox).
  MARKER='<!-- Append new entries below this line. -->'
  open_list=$(awk -v m="$MARKER" '
    index($0, m) { seen = 1; next }
    /^## \[open\]/ { if (seen) print NR ": " $0; else pre = pre NR ": " $0 "\n" }
    END { if (!seen) printf "%s", pre }' "$inbox")
  open_n=$(printf '%s' "$open_list" | grep -c . || true)
  if [ "$open_n" -eq 0 ]; then
    pass "WSS.BUG-REPORTS.md has no open entries"
  else
    warn "$open_n open bug report(s) filed against this config:"
    printf '%s\n' "$open_list" | sed 's/^/        /' | head -10
    printf '        %s\n' "Triage from a session in $CONFIG_DIR. Re-verify each before" \
      "acting — a finding already fixed reads exactly like a live one."
  fi
fi

# ---------------------------------------------------------- backlog provider

head_ "Backlog provider"

# WSS.record.todo may name a provider instead of a file. Everything that can go
# wrong with one is silent from inside a session: gh missing, gh unauthorized,
# a repo slug that no longer resolves. Each makes --wss-todo unable to file the item
# it was asked to file, and the provider contract forbids falling back to a
# local WSS.TODO.md — so the failure has to surface HERE or it surfaces as a parked
# task that was never parked.
prov=""
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  prov=$(jq -r '.WSS.record.todo | if type == "object" then .provider // empty else empty end' \
           "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
fi

if [ -z "$prov" ]; then
  pass "WSS.record.todo is a file — no provider to check"
elif [ "$prov" != "github-issues" ]; then
  fail "WSS.record.todo declares provider '$prov', which nothing implements.
        workflow/providers/ holds the ones that exist. A declared provider is
        never a silent fallback to a file — --wss-todo would write nowhere."
else
  prov_repo=$(jq -r '.WSS.record.todo.repo // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
  prov_label=$(jq -r '.WSS.record.todo.label // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
  if [ -z "$prov_repo" ]; then
    fail "WSS.record.todo declares github-issues but no 'repo'. It is required —
        workflow/providers/WSS.GITHUB-ISSUES.md."
  elif ! command -v gh >/dev/null 2>&1; then
    warn "WSS.record.todo is github-issues but gh is not installed, so --wss-todo cannot
        file anything on this machine. The manifest is fine; this box is not."
  elif ! gh auth status >/dev/null 2>&1; then
    warn "WSS.record.todo is github-issues and gh is not authorized here, so --wss-todo
        cannot file anything. Run: gh auth login"
  elif ! gh repo view "$prov_repo" >/dev/null 2>&1; then
    fail "WSS.record.todo names repo '$prov_repo', which does not resolve. That is a
        manifest fault rather than a transient one — fix it through --wss-adopt in
        amendment mode."
  else
    if [ -z "$prov_label" ]; then
      warn "WSS.record.todo is github-issues on '$prov_repo' with NO label, so the
        backlog is every open issue in the repository — including bug reports
        filed by users. Declare a label unless that is genuinely meant."
    else
      # A label that does not exist is not an error to gh — the list comes back
      # empty and every reader concludes the backlog is empty. Nothing else in
      # the suite can tell that apart from a genuinely finished backlog, so it
      # has to fail here.
      real=$(gh label list --repo "$prov_repo" --limit 200 --json name 2>/dev/null \
               | jq -r --arg L "$prov_label" \
                   '.[] | select((.name | ascii_downcase) == ($L | ascii_downcase)) | .name' \
               | head -1)
      if [ -z "$real" ]; then
        fail "WSS.record.todo names label '$prov_label', which does not exist on
        $prov_repo. gh returns an empty list rather than an error, so --wss-todo
        would read an empty backlog and --wss-start would find nothing to do —
        indistinguishable from having finished the work."
      elif [ "$real" != "$prov_label" ]; then
        warn "WSS.record.todo says label '$prov_label' but the label is '$real'.
        GitHub matches case-insensitively and the readers now downcase both
        sides, so this works — but the manifest should say what the label
        actually is."
      else
        pass "backlog provider github-issues -> $prov_repo (label: $prov_label)"
      fi
    fi
  fi
fi

# ------------------------------------------------------------ sweep checkpoint

head_ "Sweep checkpoint"

# The cache that lets --wss-check, --wss-docs and --wss-tools re-read only what moved. It is
# the one file here whose being WRONG is silent by construction: a bad baseline
# or a covered glob nobody earned produces a clean report on files nothing read,
# and every incremental sweep after it inherits that. Shape and rules:
# ~/.claude/workflow/WSS.SWEEP-CHECKPOINT.md
sweeps="$PWD/.claude/WSS.SWEEPS.json"
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  declared=$(jq -r '.WSS.sweeps // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null)
  # An absolute declared path is used as given. Prefixing $PWD to one produced
  # a path that cannot exist, and the branch below reads that as "no checkpoint"
  # — the safe-looking answer, on a checkpoint that is really there.
  case $declared in
    "") ;;
    /*) sweeps=$declared ;;
    *)  sweeps="$PWD/$declared" ;;
  esac
fi

if [ ! -f "$sweeps" ]; then
  # Absence is the SAFE state, not a fault. No checkpoint means every sweep runs
  # in full, which is exactly the behaviour that existed before checkpoints did.
  pass "no sweep checkpoint — every sweep runs in full"
elif ! jq -e . "$sweeps" >/dev/null 2>&1; then
  fail "${sweeps#"$PWD"/} is not valid JSON. A sweep cannot read it, so every
        sweep silently runs in full — correct, but slow for a reason nobody sees."
else
  SWEEP_SUPPORTED="sweeps/v1"
  sv=$(jq -r '.sweep // empty' "$sweeps")
  if [ -z "$sv" ]; then
    fail "${sweeps#"$PWD"/} has no \"sweep\" version, so a skill cannot tell which
        shape it is holding and a renamed field reads as absent rather than wrong."
  elif ! printf '%s\n' $SWEEP_SUPPORTED | grep -qx "$sv"; then
    warn "${sweeps#"$PWD"/} declares '$sv'; this checkout understands:
        $SWEEP_SUPPORTED. Every sweep falls back to full scope."
  else
    pass "checkpoint declares $sv"
  fi

  # A committed checkpoint is the failure this cannot detect about itself: it is
  # read as authoritative on a machine that never ran the sweep it describes.
  if git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$PWD" ls-files --error-unmatch "${sweeps#"$PWD"/}" >/dev/null 2>&1; then
      fail "${sweeps#"$PWD"/} is TRACKED by git. It records what THIS machine
        verified; shared, one person's half-finished sweep licenses everyone
        else's skip, and they have no way to find out. Untrack and ignore it."
    else
      pass "checkpoint is untracked, as it must be"
    fi
  fi

  # A baseline that is not a reachable commit cannot be diffed against, so the
  # narrowing it licenses is computed from nothing.
  bad=0; n=0
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    n=$((n + 1))
    sha=${b%+dirty}
    git -C "$PWD" cat-file -e "$sha^{commit}" 2>/dev/null && continue
    fail "checkpoint baseline '$b' is not a commit in this repository. Anything
        it claims as covered is unverifiable — that entry must be re-swept."
    bad=$((bad + 1))
  done < <(jq -r '.entries // {} | .[] | .baseline // empty' "$sweeps" 2>/dev/null)
  [ $bad -eq 0 ] && [ $n -gt 0 ] && pass "every baseline resolves to a commit ($n checked)"
  [ $n -eq 0 ] && warn "checkpoint has no entries — nothing has stamped one yet"

  # complete:true asserts every path in scope is in exactly one list. An entry
  # claiming that while listing no coverage at all is claiming its whole scope by
  # omission, which is rule 3 inverted.
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    warn "checkpoint entry '$k' is complete:true but names no covered path.
        Either it covered nothing — in which case complete is false — or it is
        claiming its whole scope by saying nothing, which is what rule 3 forbids."
  done < <(jq -r '
      .entries // {} | to_entries[]
      | select(.value.complete == true)
      | select(((.value.scopes // []) | map(.covered // []) | flatten | length) == 0)
      | select(.key != "test-run")
      | .key' "$sweeps" 2>/dev/null)
fi

# ------------------------------------------------------ plugin manifest version

head_ "Plugin manifest version"

# The plugin cache path is plugins/cache/<marketplace>/<plugin>/<version>/, so
# plugin.json's `version` is what keeps two published vintages from
# overwriting one directory — and nothing owned the field: audit pass 10 found
# it two tags behind, with the release procedure bumping the changelog and the
# tag but never this file. --wss-release now bumps it before the tag; this
# check is what notices when that step was skipped. A version AHEAD of the
# newest tag is a release in flight (bump lands before the tag by design), so
# only a trailing version warns — and CI runs --strict, where a warn is red.
pj="$CLAUDE_DIR/.claude-plugin/plugin.json"
if [ ! -f "$pj" ]; then
  pass "no .claude-plugin/plugin.json — not a plugin tree, nothing to trail"
else
  pv=$(jq -r '.version // empty' "$pj" 2>/dev/null || true)
  newest_tag=$(git -C "$CLAUDE_DIR" tag -l 'v*' --sort=-v:refname 2>/dev/null | head -1 || true)
  if [ -z "$newest_tag" ]; then
    pass "no release tag resolves here — nothing for plugin.json's version to trail"
  elif [ -z "$pv" ]; then
    fail "plugin.json declares no version. The plugin cache path keys on that
        field, so installs of different vintages would collide on one
        directory — set it to the newest tag's number."
  elif [ "v$pv" = "$newest_tag" ]; then
    pass "plugin.json version $pv matches the newest tag $newest_tag"
  elif [ "$(printf 'v%s\n%s\n' "$pv" "$newest_tag" | sort -V | tail -1)" = "v$pv" ]; then
    pass "plugin.json version $pv leads the newest tag $newest_tag — a release in flight"
  else
    warn "plugin.json says $pv while the newest tag is $newest_tag.
        Two published vintages under one version overwrite one plugin cache
        directory. --wss-release bumps this file beside the changelog entry,
        before the tag — do that now and the next tag ships consistent."
  fi
fi

# ---------------------------------------------------------------------- result

head_ "Result"
if [ $fails -gt 0 ]; then
  printf '  \033[31m%d failed\033[0m, %d warnings\n\n' "$fails" "$warns"
  exit 1
fi
if [ $STRICT -eq 1 ] && [ $warns -gt 0 ]; then
  printf '  \033[31mall checks passed, but %d warnings and --strict\033[0m\n\n' "$warns"
  exit 1
fi
printf '  \033[32mall checks passed\033[0m, %d warnings\n\n' "$warns"
