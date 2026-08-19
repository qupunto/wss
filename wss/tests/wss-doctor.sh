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
# real drift: "flag maps to a skill that resolves nowhere", and a block_for()
# arm whose grant_ call names a flag that is not its own case label, or a
# matrix row that grants something with no block_for() arm calling grant_ for
# it at all. Those landed GREEN until 2026-08-01,
# which made the grant check decorative.
#
# So most warns MUST be red in CI, and a check that silences itself there needs
# a reason narrower than "it is noisy". The one that qualifies: the warned-about
# condition is not a defect in a CI checkout — per-clone or machine-local state
# a throwaway checkout structurally cannot have and does not need. The installed
# pre-commit hook is the instance, and the only one; a CI checkout commits
# nothing and runs that guard as a step of its own. Anything else stays loud.
#
# A second, narrower exemption exists for a check that measures a cost rather
# than a fault: the chain-budget walk (search "notice()") reports how heavy a
# skill's mandated-read chain is against a tier budget, and A1 (WSS.TODO.md's
# Annex A; WSS.ROADMAP.md's "Make the cost visible before it grows") specifies
# that it must warn, never fail — the tree being over budget is a decision for
# the roadmap to make, not a thing this script may gate on by accident. The
# same walk also has two coverage gaps that are not defects either: a skill
# outside this suite's own WSS.OWNERSHIP.md matrix (any adopted project's own
# skills) has no tier to check against, and a tree with no
# WSS.TOKEN-ECONOMY.md has no budget figures to compare to — both report
# "nothing to compare against", not "something is wrong". `notice()` is that
# exemption, made structural rather than another one-off warn-to-pass rewrite:
# counted on its own, printed only with --notes, and never promoted by --strict.
# What stays a plain warn in that same check: the citation walk finding ZERO
# mandated-read citations across every skill checked, which is the check's own
# self-test — a citation-format change it cannot parse reads as a suspiciously
# clean tree, and that is a real regression in the tool, not a cost to report.
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
CHECK_ASSEMBLY=0
NOTES=0
QUIET=0

# TOGGLES SET THE DEFAULTS; A TYPED FLAG STILL WINS. Both are read in ONE call
# and parsed here — this script is forked about 144 times by the contract suite,
# so a lookup per toggle would be paid per toggle per fork. An absent toggle, an
# absent table and an absent script all mean off, which is why nothing below
# treats a missing value as an error.
_tg=$( [ -x "$(dirname "${BASH_SOURCE[0]}")/../scripts/wss-toggle.sh" ] \
       && bash "$(dirname "${BASH_SOURCE[0]}")/../scripts/wss-toggle.sh" 2>/dev/null || true )
case $(printf '%s\n' "$_tg" | awk -F'\t' '$1=="doctor-strict"{print $2}') in on) STRICT=1 ;; esac
case $(printf '%s\n' "$_tg" | awk -F'\t' '$1=="doctor-quiet"{print $2}') in on) QUIET=1 ;; esac

for arg in "$@"; do
  case $arg in
    --strict) STRICT=1 ;;
    --check-assembly) CHECK_ASSEMBLY=1 ;;
    --notes) NOTES=1; QUIET=0 ;;
    *) echo "wss-doctor.sh: unknown argument '$arg' (only --strict, --check-assembly, --notes)" >&2; exit 2 ;;
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
#   CLAUDE_DIR  the installation being inspected — skills/, wss/workflow/, hooks/,
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
SELF_DIR="$(dirname "$(dirname "$SELF_DIR")")"   # wss-doctor.sh sits at wss/tests/, two levels under the install root this variable names

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
notices=0

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
# QUIET SUPPRESSES THE PRINTING AND NEVER THE COUNTING. A warn still counts, so
# --strict still turns the exit red on one; only the line is withheld. A toggle
# that changed what a run CONCLUDED rather than what it showed would be a
# different feature, and a dangerous one.
warn()  { [ "$QUIET" -eq 1 ] || printf '  \033[33mwarn\033[0m  %s\n' "$1"; warns=$((warns + 1)); }
# A cost or a coverage gap, not a fault: counted every run, but only PRINTED
# when --notes is passed — a clean adopter's tree would otherwise fill with
# notes for every optional key it does not declare. Never counted toward
# --strict's exit code either way. See the "second, narrower exemption"
# paragraph above this script's header comment for what qualifies.
notice() { [ "$NOTES" -eq 1 ] && printf '  \033[36mnote\033[0m  %s\n' "$1"; notices=$((notices + 1)); }
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
        \`wss/scripts/wss-retire-workflow.sh --suite\` for the exact command per install."
else
  pass "the suite is installed at most once — no plugin/checkout coexistence"
fi

# The half the check above cannot see, measured rather than predicted: a teardown
# that skips `claude plugin marketplace remove` leaves a registration in
# plugins/known_marketplaces.json and a clone under plugins/marketplaces/, and
# neither sits under plugins/cache/ (`wss/logs/WSS.DECISIONS.md`'s 2026-08-18
# (thirteenth) entry, where exactly that residue passed this section clean).
#
# WARN, not FAIL, and only while nothing is installed. A marketplace clone is
# fetched source that no hook event reaches, so it cannot double-fire anything —
# it is residue of the same grade as the empty settings.json keys below. Where an
# install IS present the registration belongs to it, and the failure above
# already describes that state, so this stays silent to avoid naming the same
# machine twice with two different remedies.
#
# Keyed on the SOURCE repository as well as the name, because the name is chosen
# when the marketplace is added and this suite has shipped under two of them:
# matching `wss` alone would miss every machine that added it before the
# 2026-08-10 rename, which is the population most likely to be carrying residue.
if [ $coexist_plugin -eq 0 ]; then
  mkt=$(jq -r '(to_entries // [])[]
      | select([.key, ((.value.source.repo // "") | split("/") | last)]
               | map(ascii_downcase)
               | any(. == "wss" or . == "workflow-secretary-suite"))
      | .key' "$CONFIG_DIR/plugins/known_marketplaces.json" 2>/dev/null)
  for mkt_name in wss workflow-secretary-suite; do
    [ -d "$CONFIG_DIR/plugins/marketplaces/$mkt_name" ] &&
      mkt="$mkt
$mkt_name"
  done
  mkt=$(printf '%s\n' "$mkt" | sed '/^$/d' | sort -u | paste -sd, -)
  if [ -n "$mkt" ]; then
    warn "marketplace remnant: $mkt — registered in
        plugins/known_marketplaces.json, or cloned under plugins/marketplaces/,
        with no wss plugin installed from it. That is a teardown that skipped
        \`claude plugin marketplace remove\`; neither location is under
        plugins/cache/, so the coexistence check above cannot see it. Remove the
        marketplace, then delete the clone directory."
  fi
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

  # `declare -A` is bash 4 and fails at RUNTIME, not at parse time, so the
  # version guard is only worth anything if it runs FIRST. The hook pinned that
  # ordering to a line number in a comment; the number drifted by ten and
  # asserted nothing. Check it against the construct instead.
  guard_ln=$(grep -n 'BASH_VERSINFO' "$hook" | head -1 | cut -d: -f1)
  decl_ln=$(grep -n '^[[:space:]]*declare -A' "$hook" | head -1 | cut -d: -f1)
  if [ -z "$decl_ln" ]; then
    pass "no declare -A in the shorthand hook, so no bash-4 ordering to enforce"
  elif [ -z "$guard_ln" ]; then
    fail "wss-shorthand-flags.sh uses declare -A at line $decl_ln with no
        BASH_VERSINFO guard above it. On bash 3.2 that fails at runtime and
        leaves an indexed array, whose next subscript evaluates a flag name as
        arithmetic — stock macOS still ships 3.2 and no CI job covers it."
  elif [ "$guard_ln" -ge "$decl_ln" ]; then
    fail "the bash-4 guard (line $guard_ln) is not above the first declare -A
        (line $decl_ln) in wss-shorthand-flags.sh. A guard below the construct
        it protects never runs on the one shell it exists for."
  else
    pass "the bash-4 guard precedes the first declare -A ($guard_ln < $decl_ln)"
  fi

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
        warn "\`$f\` maps to '$skill' but has no block_for() case — it injects nothing"
      # `-` is the hook serving the flag itself rather than a missing mapping.
      # There is no skills/ directory to look in and its absence is not a fault.
      if   [ "$skill" = "-" ]; then pass "\`$f\` -> served by the hook, no skill needed"
      elif [ -f "$CLAUDE_DIR/skills/$skill/SKILL.md" ]; then pass "\`$f\` -> $skill (user)"
      elif [ -f "$PWD/.claude/skills/$skill/SKILL.md" ]; then pass "\`$f\` -> $skill (project)"
      else warn "\`$f\` -> $skill, which resolves in neither $CLAUDE_DIR/skills nor this
        project. skill_exists() gates it, so the flag is inert here rather than
        broken — but if this is the project that should have it, it does nothing."
      fi
    done

    # A flag's grant used to be written by hand in two places -- the block
    # this hook injects, and the matrix in wss/workflow/WSS.OWNERSHIP.md -- and
    # nothing compared them until a review found the grant restated in four
    # places with two of them checked by nothing. That pair is gone: grant_()
    # in hooks/wss-shorthand-flags.sh (search "grant_()") now reads the
    # matrix's last column AT RUNTIME and prints it, so eleven block_for()
    # arms carry a `grant_ --wss-x` call instead of a written-out
    # Authorization: line. There is no second copy left to diff -- the hook's
    # text IS the matrix cell -- so a byte comparison would pass by
    # construction and verify nothing.
    #
    # What CAN still drift, because it is still hand-written, is the CALL
    # SITE: which token an arm passes to grant_(). Three ways that goes wrong:
    #   - an arm calls grant_ with a flag that is not its own case label,
    #     which injects ANOTHER flag's authorization into this block;
    #   - a flag the matrix grants something to has no grant_ call in its arm
    #     at all, so it injects no Authorization: line and fires unauthorized;
    #   - an arm calls grant_ with a flag whose matrix cell is `—`, which
    #     grant_() denies safely but which means the row backing it is gone.
    # This check reads block_for()'s arms and every grant_ call inside them,
    # never any text grant_() would print, because printed text is exactly
    # the thing that can no longer disagree with itself.
    own="$CLAUDE_DIR/wss/workflow/WSS.OWNERSHIP.md"
    if [ ! -f "$own" ]; then
      warn "wss/workflow/WSS.OWNERSHIP.md not found -- grant_() calls in the hook
        were not checked against anything"
    else
      # Every matrix row whose last column is not `—` grants SOMETHING, and
      # every flag named in that row's Flag column should have a grant_ call
      # for it somewhere in block_for(). Reuses the same field-slicing idiom
      # grant_() itself uses to read a matrix cell, so this and grant_() can
      # never disagree about what a row says -- only about whether an arm
      # called it.
      derive_flags=$(awk -F'|' '
        /^\|/ {
          auth = $(NF - 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", auth)
          if (auth != "—" && auth != "") print $3
        }
      ' "$own" | grep -oE '`--[a-z-]+`' | tr -d '`' | sort -u)
      derive_count=$(printf '%s\n' $derive_flags | grep -c .)

      # Walk block_for()'s case arms once. Each arm is bounded by its own
      # label line -- reusing the alternation-splitting idiom the
      # flags-vs-skills loop above already relies on, the only thing here
      # that correctly reads a `--x|--y)` case label -- and by its closing
      # `;;`. Emits one line per arm: its own flag labels, a tab, and every
      # flag token any grant_ call inside it named.
      grant_wrong=0; grant_missing=0; grant_spurious=0; arms_seen=0
      called_flags=""
      while IFS=$'\t' read -r arm_flags arm_calls; do
        arms_seen=$((arms_seen + 1))
        for tok in $arm_calls; do
          called_flags="$called_flags $tok"
          case " $arm_flags " in
            *" $tok "*) : ;;
            *)
              fail "block_for()'s '$arm_flags' arm calls grant_ $tok, which is not one of its own case labels -- that injects $tok's authorization into this block instead of its own."
              grant_wrong=$((grant_wrong + 1)) ;;
          esac
          cell=$(awk -F'|' -v flag="$tok" '
            /^\|/ && index($3, "`" flag "`") {
              a = $(NF - 1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", a); print a; exit
            }' "$own")
          if [ "$cell" = "—" ] || [ "$cell" = "-" ] || [ -z "$cell" ]; then
            warn "block_for()'s '$arm_flags' arm calls grant_ $tok, whose row in WSS.OWNERSHIP.md's matrix grants nothing (\`—\` or missing) -- grant_ denies it safely, but the row that should back this call is gone."
            grant_spurious=$((grant_spurious + 1))
          fi
        done
      done < <(awk '
        /^block_for\(\) \{/ { inblock = 1; next }
        inblock && /^}$/ { inblock = 0 }
        !inblock { next }
        /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*$/ {
          if (arm != "") print arm "\t" calls
          alts = $0; sub(/\).*/, "", alts); gsub(/[[:space:]]/, "", alts)
          gsub(/\|/, " ", alts)
          arm = alts; calls = ""
          next
        }
        arm != "" && /grant_[[:space:]]+--/ {
          line = $0
          sub(/.*grant_[[:space:]]+/, "", line); sub(/[[:space:]].*/, "", line)
          calls = calls " " line
          next
        }
        arm != "" && /^[[:space:]]*;;[[:space:]]*$/ { print arm "\t" calls; arm = ""; calls = "" }
        END { if (arm != "") print arm "\t" calls }
      ' "$hook")

      # Skipped entirely when arms_seen is 0: with no arm walked, EVERY derive
      # flag would look "missing" from here, which is not a finding about
      # eleven flags -- it is one finding about the walker, and the blindness
      # warn below is what states it once rather than eleven confident-sounding
      # false individual FAILs.
      if [ $arms_seen -gt 0 ]; then
        for f in $derive_flags; do
          case " $called_flags " in
            *" $f "*) : ;;
            *)
              fail "$f grants something in WSS.OWNERSHIP.md's matrix but no block_for() arm calls grant_ $f -- it injects no Authorization: line at all."
              grant_missing=$((grant_missing + 1)) ;;
          esac
        done
      fi

      if [ $arms_seen -eq 0 ]; then
        warn "block_for()'s case arms could not be parsed at all -- 0 arms walked, so none of the grant_ checks above verified anything."
      elif [ $grant_wrong -eq 0 ] && [ $grant_missing -eq 0 ]; then
        pass "every grant_ call in block_for() names its own arm's flag, and every granting row in WSS.OWNERSHIP.md's matrix has a call site ($arms_seen arms walked, $derive_count granting rows)"
      fi
    fi

    # A block whose heredoc tells the model to file into WSS.BUG-REPORTS.md
    # promises a specific entry format -- the fenced one in
    # wss/workflow/WSS.OWNERSHIP.md's "A file belonging to the installation is
    # never edited from a project session" section -- and bugtpl_() is the
    # only thing in this hook that reads that fence and prints it. The
    # end-to-end contract test (tests/wss-hook-contract.sh) proves bugtpl_()
    # itself resolves; it cannot prove every arm that OWES the template
    # actually calls it, because a THIRD arm that hardcoded the fenced text
    # instead of calling bugtpl_() would still print `## [open]` today and
    # pass that live-output test clean -- it would just silently stop
    # tracking the canon the moment the canon's fence text next changed. This
    # check reads SOURCE, not output, so it catches that class instead: every
    # block_for() arm whose heredoc mentions WSS.BUG-REPORTS.md must call
    # bugtpl_ somewhere inside its own arm. Reuses the same arm-walking awk
    # idiom as the grant_ check above -- bounded by block_for()'s braces, each
    # arm bounded by its own case label and closing `;;` -- so the two checks
    # can never disagree about where one arm ends and the next begins.
    bugtpl_missing=0; bugtpl_seen=0
    while IFS=$'\t' read -r arm_flags arm_mentions arm_calls; do
      [ "$arm_mentions" = "1" ] || continue
      bugtpl_seen=$((bugtpl_seen + 1))
      if [ "$arm_calls" != "1" ]; then
        fail "block_for()'s '$arm_flags' arm tells the model to file into WSS.BUG-REPORTS.md but never calls bugtpl_ -- it either hardcodes the entry format, which will silently stop matching wss/workflow/WSS.OWNERSHIP.md's fence the day that fence's text changes, or emits no format at all."
        bugtpl_missing=$((bugtpl_missing + 1))
      fi
    done < <(awk '
      /^block_for\(\) \{/ { inblock = 1; next }
      inblock && /^}$/ { inblock = 0 }
      !inblock { next }
      /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*$/ {
        if (arm != "") print arm "\t" mentions "\t" calls
        alts = $0; sub(/\).*/, "", alts); gsub(/[[:space:]]/, "", alts)
        gsub(/\|/, " ", alts)
        arm = alts; mentions = 0; calls = 0
        next
      }
      arm != "" && /WSS\.BUG-REPORTS\.md/ { mentions = 1 }
      arm != "" && /bugtpl_/ { calls = 1 }
      arm != "" && /^[[:space:]]*;;[[:space:]]*$/ { print arm "\t" mentions "\t" calls; arm = "" }
      END { if (arm != "") print arm "\t" mentions "\t" calls }
    ' "$hook")

    if [ $bugtpl_seen -eq 0 ]; then
      notice "no block_for() arm mentions WSS.BUG-REPORTS.md -- nothing for the bugtpl_ call-site check to verify"
    elif [ $bugtpl_missing -eq 0 ]; then
      pass "every block_for() arm that files into WSS.BUG-REPORTS.md calls bugtpl_ for its entry format ($bugtpl_seen arm(s) checked)"
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
      notice "no skill description advertises a --wss- shorthand"
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
  [ $n -eq 0 ] && notice "no project skill shadows a user-level skill"
else
  notice "nothing to compare"
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
  notice "no flag list or no settings to compare against"
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
  notice "no skill declares a description, so none can trigger on a stray word"
elif [ $SUSPECT -eq 0 ]; then
  pass "no trigger clause invites invocation on a single ordinary word ($checked checked)"
fi

# --------------------------------------------------- assembly description budget

head_ "Description budget (assembly)"

# The "Description budget" section above measures what THIS CHECKOUT carries —
# every skill still spelled `wss-<name>`. That is not what a plugin consumer's
# session pays: wss-publish.sh strips the `wss-` prefix from every skill and
# command identifier, including inside a SKILL.md's own frontmatter
# `description`, before it ships (see wss-publish.sh's "plugin-form skill
# names" section — read there, never edited here). The strip only ever
# SHORTENS a token, so the checkout figure above can only ever over-report a
# consumer's true always-on cost, never under-report it — but "can only ever"
# is a claim about the mechanism, not a measurement, and this section is what
# turns it into one: it runs the real assembly and re-measures the same
# DESC_CAP budget against what actually ships.
#
# OFF BY DEFAULT (`--check-assembly` to run it), because it is genuinely slow
# — measured at several minutes, dominated by wss-publish.sh's own Gates 1-4
# (Gate 4 runs the full contract-test suite), none of which changes a
# description byte. There is no flag to stop wss-publish.sh early, and it is
# not this doctor's file to add one to, so the cost is accepted rather than
# raced: this waits for the whole run under a bounded `timeout` rather than
# polling a log line and killing the process, which would trade a real
# reliability risk (an orphaned child, a torn assembly read half written) for
# time this check is not spent on by default anyway.
#
# STRUCTURALLY IMMUNE TO RECURSION rather than guarded by one: wss-publish.sh
# deletes itself from every assembly it produces (its own header: "Does not
# ship"), so gating on the file's presence means a doctor run against an
# assembly — Gate 3 above already runs one via `CLAUDE_CONFIG_DIR` — finds no
# wss-publish.sh and this section is a one-line notice, never a second
# assembly.
if [ "$CHECK_ASSEMBLY" -ne 1 ]; then
  notice "skipped — pass --check-assembly to build the real assembly and
      measure what a plugin consumer's session actually pays. Slow (several
      minutes): it runs wss-publish.sh's own gates, none of which this
      section reads, because there is no cheaper way to reach the same
      renamed, substituted files without a second implementation of the
      rename this doctor does not own"
elif [ ! -f "$CLAUDE_DIR/wss/scripts/wss-publish.sh" ]; then
  notice "no wss-publish.sh in $CLAUDE_DIR — this instance does not travel
      with it (an assembly never does, by design), so there is nothing to
      assemble and nothing recurses"
else
  ag_out=$(mktemp -d)
  ag_log=$(mktemp)
  ag_run="bash"
  command -v timeout >/dev/null 2>&1 && ag_run="timeout 900 bash"
  $ag_run "$CLAUDE_DIR/wss/scripts/wss-publish.sh" "$ag_out" >"$ag_log" 2>&1
  ag_rc=$?

  # A gate failing later (credentials, the hook-contract suite) does not
  # invalidate what this section measures: every rewrite that touches a
  # description byte happens before Gate 1 even starts, at the "stripped to
  # their plugin-form names" line. Absence of that line is what actually means
  # "nothing to measure" — not the script's own exit code.
  if ! grep -qF 'ok   skills and commands stripped to their plugin-form names' "$ag_log"; then
    notice "wss-publish.sh did not reach the plugin-form rename (exit $ag_rc) —
        see $ag_log; the assembly's description budget was not measured this
        run"
  else
    ag_n=0; ag_seen=0; ag_total=0
    for d in "$ag_out"/skills/*/; do
      [ -f "$d/SKILL.md" ] || continue
      ag_name=$(basename "$d")
      ag_seen=$((ag_seen + 1))
      ag_b=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$d/SKILL.md" |
             awk '/^description:/{p=1;print;next} p&&/^[a-zA-Z_-]+:/{p=0} p' | wc -c)
      ag_total=$((ag_total + ag_b))
      if [ "$ag_b" -gt $DESC_CAP ]; then
        warn "assembled skill '$ag_name' ships a ${ag_b}B description, over
            the ${DESC_CAP}B budget — this is what a plugin consumer actually
            loads every session, measured after the wss- prefix strip, not
            the checkout figure above."
        ag_n=$((ag_n + 1))
      fi
    done
    if [ $ag_seen -eq 0 ]; then
      notice "no skill directories in the assembly — nothing to measure"
    elif [ $ag_n -eq 0 ]; then
      pass "every assembled description is within ${DESC_CAP}B ($ag_seen skills, ${ag_total}B always-on to a plugin consumer)"
    else
      warn "$ag_n of $ag_seen assembled descriptions are over budget;
          ${ag_total}B loads in every plugin consumer's session"
    fi
  fi
  rm -rf "$ag_out"; rm -f "$ag_log"
fi

# --------------------------------------------------------- dangling references

head_ "Cross-references"

# A dispatch target is a skill, an agent, OR a procedure file under
# wss/workflow/writers/. The third kind arrived on 2026-08-02, when the eight
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
    find "$CLAUDE_DIR/wss/workflow/writers" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
      sed 's/\.md$//; s/^WSS\.//' | tr 'A-Z' 'a-z'
    find "$PWD/.claude/wss/workflow/writers" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
      sed 's/\.md$//; s/^WSS\.//' | tr 'A-Z' 'a-z'
    find "$PWD/.claude/workflow/writers" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
      sed 's/\.md$//; s/^WSS\.//' | tr 'A-Z' 'a-z'
  } | sort -u
)
if [ -z "$known" ]; then
  notice "no skills, agents or procedures to cross-check"
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
    notice "no skill/agent/procedure citations to check"
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
  notice "no cross-skill section citations to check"
fi

# ------------------------------------------------------- link targets, anchors

# An ordinary markdown link can carry a heading fragment. The citation check
# above only covers the possessive "X's \"Y\" section" shape, and the manifest
# check below only covers keyed pointers inside WSS.WORKFLOW.json — so a plain link
# whose target heading gets renamed is verified by nothing and reads exactly
# like a live one. That is the failure both of those exist to catch, in the one
# form neither of them sees.
#
# Narrow on the grounds CI's own markdown walks are narrow, and for the same
# reason: a check nobody trusts is a check nobody runs. A first attempt at a
# general link checker produced ~60 findings of which almost none were real.
#
#   - Links inside fenced code blocks are examples rather than pointers.
#   - A leading slash is site-root-relative inside a rendered docs site, not a
#     filesystem path.
#   - Angle brackets or a shell expansion mark a template placeholder.
#
# Tracked files only where this is a checkout, which is what keeps ~/.claude's
# ~100 MB of transcripts, caches and plugin trees out of the walk. A plugin
# install has no git index and no machine state, so there it is the whole tree.

# `wss/logs/audits/` is excluded, and it is the only exclusion.
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
# `wss/logs/audits/README.md` is deliberately NOT excluded. The distinction is FROZEN vs
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
      git -C "$CLAUDE_DIR" ls-files -z '*.md' ':(exclude)wss/logs/audits/**'
      git -C "$CLAUDE_DIR" ls-files -z 'wss/logs/audits/README.md'
    } | while IFS= read -r -d '' p; do printf '%s\0' "$CLAUDE_DIR/$p"; done
  else
    find "$CLAUDE_DIR" -name '*.md' -not -path '*/.git/*' \
      \( -not -path '*/audits/*' -o -path '*/audits/README.md' \) -print0
  fi
}

# The PATH half of a relative link, which nothing here checked until 2026-08-02.
# The anchor check below needs a `#` to fire, so a link to a file that has been
# moved or deleted was verified by CI alone — and on 2026-08-02 that is exactly
# what happened: eight skill files moved to wss/workflow/writers/, six links to them
# were sibling-relative (`../manifest-writer/SKILL.md`, no `skills/` segment to
# grep for), three commits went out saying "wss-doctor.sh all-clear", and CI was red
# the whole time. The claim was true and useless: the doctor did not cover what
# the gate covered.
#
# This walk is now the ONLY one: CI carried a hand-copied duplicate of it under
# "Cross-links between our own files resolve", which was deleted once the log
# exemption below landed, rather than maintained in two places — the two doctor
# steps in that job run this check with `--strict` two steps earlier, so the
# copy caught nothing this did not. The exemptions are why the walk stays
# narrow: fenced blocks and inline backticks are how a document that explains
# link syntax has to quote it, and a leading slash is site-root-relative inside
# a rendered docs site rather than a filesystem path.
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

# A link inside an append-only log is a HISTORICAL claim, not a live pointer:
# it records where a file was on the date the entry was written. So when a tier
# of a reorg moves the target, rewriting the link turns a true sentence false —
# and `wss/scripts/wss-append-only.sh` mechanically refuses the edit anyway, so
# it cannot be done without disabling the guard. Neither can it just fail
# forever: a permanently red doctor is how the fifth failure gets read as "the
# usual four".
#
# Keyed off `WSS.recordMode`, which already distinguishes `log` from `register`,
# rather than off a path — so this states the actual rule instead of carving out
# a directory, and it holds for any project whose log cites a file that later
# moves. Deliberately NOT silent: a `notice` still shows a path written wrong
# TODAY, which is the only class this would otherwise hide.
#
# CLAUDE_DIR's manifest, not $PWD's: md_files_() walks CLAUDE_DIR alone, so a
# project's own records are never in scope here, and CI runs the wider of the
# two doctor steps from a directory with no project at all. No jq or no manifest
# yields an empty set, which is exactly today's behaviour.
log_records_() {
  local m="$CLAUDE_DIR/.claude/WSS.WORKFLOW.json"
  [ -r "$m" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '
    (.WSS.recordMode // {}) | to_entries[]
    | select((.value == "log")
             or ((.value | type == "object") and .value.mode == "log"))
    | .key
  ' "$m" 2>/dev/null | while IFS= read -r k; do
    [ -n "$k" ] || continue
    jq -r --arg k "$k" '
      (.WSS.record // {}) | getpath($k | split(".")) | select(type == "string")
    ' "$m" 2>/dev/null
  done
}

head_ "Link targets"

logset=$(log_records_)

n=0; seen=0; historical=0
while IFS=$'\t' read -r f l; do
  [ -n "$l" ] || continue
  seen=$((seen + 1))
  [ -e "$(dirname "$f")/$l" ] && continue
  rel=${f#"$CLAUDE_DIR"/}
  if [ -n "$logset" ] && printf '%s\n' "$logset" | grep -qxF "$rel"; then
    notice "$rel
        links to $l, which does not exist. That record is append-only, so the
        link states where the file WAS when the entry was written — reported,
        not failed. Check it is history rather than a path written wrong today."
    historical=$((historical + 1))
    continue
  fi
  fail "$rel
        links to $l, which does not exist. A moved or deleted target reads
        exactly like a live link to whoever follows it."
  n=$((n + 1))
done < <(link_targets_)
if [ $seen -eq 0 ]; then
  warn "no relative links were extracted, so none was checked"
elif [ $n -eq 0 ] && [ $historical -eq 0 ]; then
  pass "every relative link resolves ($seen checked)"
elif [ $n -eq 0 ]; then
  pass "every live relative link resolves ($seen checked, $historical dangling
        inside append-only logs and reported as notices)"
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
    notice "no link anchors to check"
  fi
fi

# --------------------------------------------- set-scoped anchor uniqueness

# A REFERENCE FILE HAS NO ADDRESS OF ITS OWN — the owning skill's key reaches it,
# and a fragment resolves against the skill's WHOLE SET: `SKILL.md` plus its
# references. The owner's ruling (`wss/logs/WSS.DECISIONS.md`, the
# `2026-08-18 (twenty-fifth)` entry) made two conditions part of it rather than
# advice: resolution is EXACTLY ONE MATCH, and a fragment matching zero or more
# than one heading in the set is a finding here — never settled by a precedence
# order, because a SKILL.md-wins rule would let a citation bind silently to the
# wrong section.
#
# WARN-GRADE, and the condition it promotes to fail under: once the whole tree
# has been clean across two consecutive releases. The named residual is why it
# starts here — conventional section names recurring inside one skill's set will
# keep tripping it, and that is the check working rather than a false positive.
#
# FENCES ARE SKIPPED. A `#` inside a fenced block is sample text, not a heading;
# a scan that counts it invents a collision no anchor can reach.
#
# THE SLUG RULE IS ANCHOR_PY'S, reused below rather than restated — two slug
# functions that drift is the failure this check exists to catch.
AU_PY='
import os, re, sys
def slug(t):
    a = t.lower()
    a = re.sub(r"[`*_\[\]()]", "", a)
    a = re.sub(r"[^\w\s-]", "", a)
    return re.sub(r"\s", "-", a.strip())
for d in sys.argv[1:]:
  files = [os.path.join(d, "SKILL.md")]
  refs = os.path.join(d, "references")
  if os.path.isdir(refs):
    files += sorted(os.path.join(refs, f) for f in os.listdir(refs) if f.endswith(".md"))
  seen = {}
  for f in files:
    fence = False
    try:
        lines = open(f, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        continue
    for n, line in enumerate(lines, 1):
        st = line.lstrip()
        if st.startswith("```") or st.startswith("~~~"):
            fence = not fence
            continue
        if fence or not line.startswith("#"):
            continue
        a = slug(line.lstrip("#").strip())
        if a:
            seen.setdefault(a, []).append("%s:%d" % (f, n))
  for a, where in sorted(seen.items()):
    if len(where) > 1:
        print("%s\t%s\t%s" % (d, a, " and ".join(where)))
'

head_ "Anchor uniqueness within a skill's set"

if ! command -v python3 >/dev/null 2>&1; then
  warn "anchor uniqueness unverified (needs python3) — a set with two identical
        headings passes silently here"
else
  # ONE python process for every set, not one per set. The doctor is forked ~144
  # times by the contract suite, so a per-set spawn is paid 144 times over — it
  # cost the suite 4.7s of its 79s measured, for a check that reads 26 small
  # directories. Collect the set list first, hand it over once.
  # An ARRAY, not a space-joined string: $CLAUDE_DIR may contain a space, and a
  # word-split string would hand python half a path and silently check nothing.
  au_sets=0 au_dupes=0; au_dirs=()
  for skdir in "$CLAUDE_DIR"/skills/*/ "$CLAUDE_DIR"/.claude/skills/*/; do
    [ -f "$skdir/SKILL.md" ] || continue
    au_sets=$((au_sets + 1))
    au_dirs+=("$skdir")
  done
  if [ "$au_sets" -gt 0 ]; then
    while IFS=$'\t' read -r au_dir au_slug au_where; do
      [ -n "$au_slug" ] || continue
      au_dupes=$((au_dupes + 1))
      warn "${au_dir#"$CLAUDE_DIR"/}'#$au_slug' resolves to more than one heading:
        ${au_where//$CLAUDE_DIR\//}
        A fragment must match exactly one heading in a skill's set. Rename one
        of them — a precedence order is not the fix (2026-08-18 twenty-fifth)."
    done < <(python3 -c "$AU_PY" "${au_dirs[@]}" 2>/dev/null)
  fi
  if [ "$au_dupes" -eq 0 ]; then
    pass "every fragment resolves to exactly one heading in its skill's set ($au_sets set(s) checked)"
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
    /~\/\.claude\/(wss-doctor\.sh|skills|wss|hooks|README\.md)/ {
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
          [ -x \"\$S/wss/tests/wss-doctor.sh\" ] || S=\$(ls -d \"\$S\"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)"
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
# in wss/workflow/WSS.RECORD-CONTRACT.md. A date-shaped string in prose is the
# greppable proxy for history (an incident, a measurement, a
# what-this-file-used-to-say) that belongs in the log instead. Fenced blocks
# and inline code spans are exempt: examples and templates legitimately carry
# timestamps. Warn rather than fail so a local run stays navigable; CI passes
# --strict, which is what makes the warning binding.
# THE GLOB LIST IS `WSS.record.tooling.sources`, IN THAT ORDER, so the two can be
# compared by eye. It is copied rather than read: this walk covers the SUITE
# INSTALL under $CLAUDE_DIR, while the manifest is a PROJECT file at
# $PWD/.claude/WSS.WORKFLOW.json whose globs are relative to the project — in an
# adopted tree those are two different directories, and feeding one's globs to
# the other's walk would silently rescope this check. Keep them equal by hand;
# the count on the pass line below is what says the walk still reaches files.
#
# `agents/*.md` and `commands/*.md` were missing until 2026-08-11, so the
# prose-date proxy never ran over the agent or the two wrappers while claiming
# to cover every rule file.
rule_files_() {
  if git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$CLAUDE_DIR" ls-files -z 'skills/*/SKILL.md' 'skills/*/references/*.md' \
      'agents/*.md' 'wss/workflow/*.md' 'wss/workflow/providers/*.md' \
      'wss/workflow/writers/*.md' 'wss/rules/*.md' \
      'wss/tests/*.md' 'commands/*.md' \
      '.claude/skills/*/SKILL.md' |
      while IFS= read -r -d '' p; do printf '%s\0' "$CLAUDE_DIR/$p"; done
  else
    find "$CLAUDE_DIR/skills" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/wss/workflow" \
      "$CLAUDE_DIR/wss/tests" "$CLAUDE_DIR/commands" \
      "$CLAUDE_DIR/.claude/skills" -name '*.md' \
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
# THE COUNT IS THE ASSERTION, NOT THE SENTENCE — the idiom the grant and wrapper
# checks above already use. This check warns, so a walk that has gone blind
# reports nothing and reads exactly like a clean tree. Zero files walked is a
# FAILURE wherever the declared roots hold any markdown at all: it means the
# globs stopped matching, which is what a reorg does to a hardcoded list.
rf_n=$(rule_files_ | tr '\0' '\n' | grep -c . || true)
rf_have=$(md_files_ | tr '\0' '\n' | sed "s|^$CLAUDE_DIR/||" |
            grep -cE '^(skills|agents|commands|wss/workflow|wss/tests)/' || true)
if [ "$rf_n" -eq 0 ] && [ "$rf_have" -gt 0 ]; then
  fail "the rule-file walk matched nothing, though $rf_have markdown file(s) live
        under skills/, agents/, commands/ or wss/workflow/. rule_files_() copies
        WSS.record.tooling.sources by hand, so a directory that moved leaves this
        check walking an empty set and reporting a clean tree forever."
elif [ $dh -eq 0 ]; then
  pass "no date-shaped prose in any rule file ($rf_n walked)"
fi

# --------------------------------- suite paths against the tools inventory

head_ "Suite paths in runnable blocks"

# The fenced-block class above (`home_in_fences_`) catches two fixed literals:
# `$CLAUDE_PLUGIN_ROOT` and `~/.claude/...`. A `$S`-relative or
# `$SUITE_ROOT`-relative path is neither — it is the CORRECT idiom, and so was
# invisible to a check built to catch the wrong idiom. The 2026-08-16 reorg
# moved scripts and left files naming their old locations this way, unnoticed
# for a day (`WSS.DECISIONS.md`, 2026-08-16 "third").
#
# This does not add a second fixed literal. It extracts whatever script-shaped
# path follows a `$S`/`$SUITE_ROOT` anchor in a fenced block and asks
# `.claude/WSS.TOOLS.json` — the measured inventory of where every script,
# skill, contract and hook actually lives — whether that path names anything.
# A moved file stops matching the day it moves; a fixed literal here would
# only ever stop matching the day someone remembers to update it, which is
# the exact failure this exists to catch.
#
# THE ANCHOR REQUIREMENT IS THE WHOLE MECHANISM, not an exclusion list keyed
# to a directory. `$S`/`$SUITE_ROOT` mean "this installation's own root"
# everywhere they appear in this suite's own docs — nothing else in this tree
# is written that way. The two false-positive classes ruled out by that same
# test:
#   - a deliberate template (`skills/docs/references/` describes an
#     ADOPTER's own docs site and never anchors a path to `$S`/`$SUITE_ROOT`,
#     because the site being described is not part of this suite's tree).
#   - a path into the ADOPTER's project rather than the suite: `$S`/
#     `$SUITE_ROOT` is never how a skill spells "the project I am running
#     in" — that is `$PWD`, or no anchor at all, which this pattern excludes.
# A directory-keyed allow-list would rot exactly like the bug this check
# exists to catch, once that directory moved.
#
# Extensions are hand-listed (sh|md|json) rather than derived from the JSON,
# because that is the closed set wss-tools-inventory.sh's own ENUMERATE globs
# can ever produce — a widened generator is a source change, and missing a
# fourth extension here only under-covers; it does not mis-report an existing
# one, which is a safer failure than the one being fixed.
suite_script_paths_() {
  rule_files_ | xargs -0 -r awk '
    FNR == 1 { fence = 0 }
    /^[[:space:]]*```/ { fence = !fence; next }
    !fence { next }
    {
      line = $0
      while (match(line, /\$\{?S(UITE_ROOT)?\}?"?\/[A-Za-z0-9_.\/-]+\.(sh|md|json)/)) {
        tok = substr(line, RSTART, RLENGTH)
        rel = tok
        sub(/^\$\{?S(UITE_ROOT)?\}?"?\//, "", rel)
        printf "%s\t%d\t%s\t%s\n", FILENAME, FNR, rel, tok
        line = substr(line, RSTART + RLENGTH)
      }
    }'
}

ssp_tools_inv="$CLAUDE_DIR/wss/scripts/wss-tools-inventory.sh"
ssp_tools_json="$CLAUDE_DIR/.claude/WSS.TOOLS.json"
ssp_inv_ok=0
if [ -f "$ssp_tools_inv" ]; then
  if ssp_inv_msg=$(bash "$ssp_tools_inv" --check 2>&1); then
    ssp_inv_ok=1
  else
    fail "the tools inventory is stale or missing: $ssp_inv_msg
        This check compares every \$S- or \$SUITE_ROOT-relative path in a
        runnable block against .claude/WSS.TOOLS.json, so a stale JSON here
        means every verdict below would be untrustworthy — regenerate with
        \`bash wss/scripts/wss-tools-inventory.sh\` and re-run."
  fi
fi

ssp_n=0; ssp_bad=0
if [ "$ssp_inv_ok" -eq 1 ]; then
  ssp_inv_paths=$(jq -r '.entries[].path' "$ssp_tools_json" | sort -u)
  while IFS=$'\t' read -r f ln rel tok; do
    [ -n "$f" ] || continue
    ssp_n=$((ssp_n + 1))
    if ! printf '%s\n' "$ssp_inv_paths" | grep -qFx -- "$rel"; then
      ssp_bad=$((ssp_bad + 1))
      fail "${f#"$CLAUDE_DIR"/}:$ln
        runs a path the tools inventory has no entry for — either the script
        moved and this reference did not, or it never named a real file:
          $tok
        Regenerate the inventory first if this looks wrong
        (\`bash wss/scripts/wss-tools-inventory.sh --check\`), then point this
        line at wherever \`${rel##*/}\` actually lives, or remove the line."
    fi
  done < <(suite_script_paths_)
  if [ $ssp_bad -eq 0 ] && [ $ssp_n -gt 0 ]; then
    pass "every \$S-/\$SUITE_ROOT-relative path in a runnable block matches the tools inventory ($ssp_n checked)"
  elif [ $ssp_n -eq 0 ]; then
    notice "no \$S- or \$SUITE_ROOT-relative script paths in any runnable block"
  fi
fi

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
    notice "commands/ exists and holds no wrappers"
  elif [ $wbad -eq 0 ]; then
    pass "every command wrapper fires the flag its name promises ($wn checked)"
  fi
else
  notice "no commands/ directory — nothing to check"
fi

# ------------------------------------------------ the cadence table, derived copy

head_ "Cadence tables"

# The flag column of README.md's "How often" table is a derived copy of the
# "| When | Flag |" table from skills/adopt/SKILL.md's cadence card.
# wss/workflow/WSS.RECORD-CONTRACT.md form 2 requires a derived copy be marked at
# the copy, naming the canon and the regenerating command. This check delegates
# to wss-gen-cadence-flags.sh to extract and compare the two flag lists (the
# generator reproduces the copy for comparison and must never write it, because
# README.md is a declared record with a sole writer), and additionally verifies
# the derived-copy marker is present, which the sole writer adds.
cad_gen="$CLAUDE_DIR/wss/scripts/wss-gen-cadence-flags.sh"
cad_readme="$CLAUDE_DIR/README.md"
if [ -f "$cad_gen" ]; then
  if cad_msg=$(bash "$cad_gen" --check 2>&1); then
    pass "$cad_msg"
    # Check for the derived-copy marker near the "How often" table
    if grep -qF 'wss-gen-cadence-flags.sh' "$cad_readme"; then
      pass "README.md carries a derived-copy marker naming the canon and generator"
    else
      fail "README.md's 'How often' table has no derived-copy marker. Add a note
          near the table naming skills/adopt/SKILL.md as the canon and
          wss/scripts/wss-gen-cadence-flags.sh as the command that regenerates it, per
          wss/workflow/WSS.RECORD-CONTRACT.md form 2."
    fi
  else
    fail "README.md's cadence flag column is stale: $cad_msg
        Regenerate with \`bash wss/scripts/wss-gen-cadence-flags.sh\` and commit the result."
  fi
else
  notice "no wss-gen-cadence-flags.sh to run — the cadence flag column's derived
        copy in README.md was never checked against its canon. It ships in
        every install; a file that MOVED reads exactly like a tree that never
        had one."
fi

# -------------------------------------- agent model assignments, derived copy

head_ "Agent model assignments"

# wss/workflow/WSS.DISPATCH-LADDER.md's assignment table is the CANON. It resolves
# each agent's model from that agent's rung, and every agents/*.md `model:`
# line is a derived copy of its row — wss/workflow/WSS.RECORD-CONTRACT.md form 2.
# An agent never decides its own model, so a disagreement here is the table
# being ignored rather than a preference being expressed, which is why this
# fails rather than warns.
#
# Checked BOTH ways deliberately. A row whose agent file disagrees is the drift
# everyone expects. An agents/*.md with no row at all is the one that actually
# ships broken: it inherits whatever model the caller passes, silently, and
# nothing else in the tree would ever say so.
am_ladder="$CLAUDE_DIR/wss/workflow/WSS.DISPATCH-LADDER.md"
am_dir="$CLAUDE_DIR/agents"
if [ ! -f "$am_ladder" ]; then
  notice "no wss/workflow/WSS.DISPATCH-LADDER.md — agent model assignments were not
        checked against any canon. Nothing else in the tree resolves an agent's
        tier, so every agents/*.md model: line is unverified."
elif [ ! -d "$am_dir" ]; then
  notice "no agents/ directory — the assignment table had nothing to check."
else
  am_rows=$(awk -F'|' '/^\| `wss-[a-z-]+` \|/ {
              n = $2; w = $5
              gsub(/[ `]/, "", n); gsub(/[ `]/, "", w)
              print n "\t" w
            }' "$am_ladder")
  if [ -z "$am_rows" ]; then
    fail "wss/workflow/WSS.DISPATCH-LADDER.md carries no agent assignment rows.
        Expected rows shaped '| <agent> | Rung | tier | <model> |' with the
        agent and model backtick-quoted, under the assignment table heading.
        Without them every agent model: line is an unchecked hand-written
        value, which is the state this check exists to end."
  else
    am_bad=0
    while IFS="$(printf '\t')" read -r am_name am_want; do
      [ -n "$am_name" ] || continue
      am_file="$am_dir/$am_name.md"
      if [ ! -f "$am_file" ]; then
        fail "the assignment table names $am_name, but agents/$am_name.md does
        not exist. Remove the row, or add the agent it promises."
        am_bad=1
        continue
      fi
      am_have=$(awk 'NR==1 && $0=="---" {infm=1; next}
                     infm && $0=="---" {exit}
                     infm && /^model:[[:space:]]/ {
                       sub(/^model:[[:space:]]*/, ""); print; exit
                     }' "$am_file")
      am_have=${am_have//\'/}
      am_have=${am_have//\"/}
      am_have=${am_have// /}
      if [ "$am_want" = "*(none)*" ]; then
        if [ -n "$am_have" ]; then
          fail "agents/$am_name.md sets model: $am_have, but the assignment
        table puts it at the top tier, where the key is ABSENT and the absence
        IS the assignment. Delete the line, or change the table first."
          am_bad=1
        fi
      elif [ "$am_have" != "$am_want" ]; then
        fail "agents/$am_name.md sets model: ${am_have:-<none>}, but the
        assignment table in wss/workflow/WSS.DISPATCH-LADDER.md says $am_want. The
        table is the canon and the agent file is the copy: change the table
        first, then bring this file to it."
        am_bad=1
      fi
      if ! grep -qF 'WSS.DISPATCH-LADDER.md' "$am_file"; then
        fail "agents/$am_name.md never names its canon. A derived copy has to
        say so at the copy — wss/workflow/WSS.RECORD-CONTRACT.md form 2 — so name
        wss/workflow/WSS.DISPATCH-LADDER.md's assignment table in the body."
        am_bad=1
      fi
    done <<AGENTMODELS
$am_rows
AGENTMODELS
    for am_file in "$am_dir"/*.md; do
      [ -f "$am_file" ] || continue
      am_base=$(basename "$am_file" .md)
      if ! printf '%s\n' "$am_rows" | cut -f1 | grep -qx "$am_base"; then
        fail "agents/$am_base.md has no row in the assignment table of
        wss/workflow/WSS.DISPATCH-LADDER.md, so nothing resolves which model it
        runs at and it silently inherits the caller's. Add a row — expanding
        the ladder is the remedy the ladder itself names for a task type no
        agent covers."
        am_bad=1
      fi
    done
    if [ "$am_bad" -eq 0 ]; then
      pass "every agents/*.md model: matches its row in the dispatch ladder's
        assignment table, every agent has a row, and every copy names its canon"
    fi
  fi
fi

# ------------------------------------ a caller told to pass a tier of its own

head_ "Model-override instructions"

# wss/records/WSS.HAZARDS.md's "One model-tier rule is live, and it is the
# ladder's" already names the drift this section mechanizes, in its own words:
# "A skill that restates a tier rather than citing the ladder is the drift to
# watch for — re-locate by grep, since line numbers move." That watch-for had no
# mechanism until this section, so the grep it asks for was run by hand or not at
# all. Re-locate the paragraph by its lead, not by a line number.
#
# THE DEFECT IS AN AFFIRMATIVE INSTRUCTION, NOT A VOCABULARY. The motivating
# instance: wss/workflow/WSS.FAN-OUT.md's brief list told a caller a shard's
# "tier passed as the launch's model override", while
# wss/workflow/WSS.DISPATCH-LADDER.md says a caller "passes no model override,
# because the resolution already happened here". Both were live text and a
# dispatching skill could follow neither safely. It was filed to
# wss/records/WSS.BACKLOG.md ("The tooling contracts") rather than queued, and a
# full-scope wss-survey reader had the file in its read set and did not report it
# — wss/logs/WSS.DECISIONS.md's "The full check's readers were not reliable".
# That is the cost this section is priced against: not a hypothetical.
#
# WHY THE CITATION-PROXIMITY SECTION BELOW DOES NOT COVER IT. The offending line
# LINKED to the ladder while contradicting it, so proximity passes it. A citation
# proves provenance, never agreement — and that gap is the whole reason a
# separate assertion is needed rather than a wider window there.
#
# WHAT IT DOES NOT ASSERT, AND CANNOT. It does not compare the two contracts'
# meaning; nothing here reads for agreement. It asserts only that no file in
# scope carries the forbidden instruction SHAPE. A paraphrase that avoids the
# words — "hand the tier to the launch" — is invisible to it, a deliberate
# false-negative in the same direction the row-completeness and citation
# proximity checks already favour: the expensive side to be wrong on is flagging
# prose that was never restating anything. The ladder itself is excluded by name,
# because it owns the term and states both the rule and the measured-override
# figure it is entitled to discuss.
#
# SCOPE IS THE TOOLING SOURCES, WHICH DELIBERATELY EXCLUDES wss/records/ AND
# wss/logs/. The log is append-only history and must keep its original wording
# even where that wording is the defect being recorded; WSS.HAZARDS.md states the
# rule correctly today and is the handoff's overflow sibling, so a hit there
# would be handoff-writer's to fix rather than a shard's.
#
# NEGATION IS THE ENTIRE DISCRIMINATOR, so it is guarded rather than assumed.
# "passes no model override" and "must not pass a model override" are the rule
# stated CORRECTLY and must stay silent; verified against both, against
# "never pass the resolved model override", and against the measurement sense in
# wss/tests/WSS.TOKEN-ECONOMY.md ("three model overrides against one grant"),
# which carries no passing verb. The negator is accepted only within three words
# of the term, so a "not" elsewhere in the window cannot mask a real hit.
#
# The verb may sit on the line ABOVE the term, as the motivating instance had it,
# so the window is two lines and the report anchors on the line carrying the term
# — without that, one occurrence reports twice. No `\b` in the awk: gawk reads it
# as a literal backspace rather than a word boundary, the live defect the
# figure-source check's own size-unit pattern still carries. No {n,m} intervals
# either, which mawk need not support.
#
# FAILS RATHER THAN WARNS, and lands green the day it ships. Its sibling
# assertion above — an agents/*.md model: against the ladder's assignment table —
# already fails, and the prose half of one invariant should not be softer than
# the frontmatter half.
if ! git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  notice "not a git checkout — the model-override check walks
      WSS.record.tooling.sources and has nothing to walk"
else
  mo_hits=$(rule_files_ |
    while IFS= read -r -d '' p; do
      case "$p" in */wss/workflow/WSS.DISPATCH-LADDER.md) continue ;; esac
      printf '%s\0' "$p"
    done |
    xargs -0 -r awk '
      FNR == 1 { fence = 0; prev = "" }
      /^[[:space:]]*(```|~~~)/ { fence = !fence; prev = ""; next }
      fence { next }
      {
        cur = tolower($0)
        cidx = index(cur, "model override")
        if (cidx > 0) {
          pre = tolower(prev) " " substr(cur, 1, cidx - 1)
          if (pre ~ /pass(es|ed|ing)?[[:space:]]/ &&
              pre !~ /(^|[[:space:]])(no|not|never)([[:space:]]+[^[:space:]]+)?([[:space:]]+[^[:space:]]+)?([[:space:]]+[^[:space:]]+)?[[:space:]]*$/)
            printf "%s:%d\n", FILENAME, FNR
        }
        prev = $0
      }
    ' 2>/dev/null | sed "s|^$CLAUDE_DIR/||")
  mo_n=$(printf '%s\n' "$mo_hits" | grep -c . || true)
  if [ "$mo_n" -eq 0 ]; then
    pass "no tooling-source file instructs a caller to pass a model override —
        the ladder's rule is stated once, in the file that owns it"
  else
    fail "these lines instruct a caller to pass a model override, which
        wss/workflow/WSS.DISPATCH-LADDER.md forbids — resolution happens in its
        assignment table, so an override either duplicates a row or silently
        overrules it: ${mo_hits}
        Point at the ladder's \"Which model runs a task\" rather than restating
        it. A citation nearby does not settle this: the instance that motivated
        this check linked to the ladder in the same sentence that contradicted it."
  fi
fi

# ------------------------------------------ the supervision ladder's coverage

head_ "Supervision ladder coverage"

# wss/workflow/WSS.SUPERVISION-LADDER.md is the canon for how supervised each
# record write is; its assignment table was set by the owner and a session
# never reassigns a cell. This section keeps the TABLE and the MANIFEST from
# drifting apart, in both directions, the same shape as the agent-model check
# above: a declared record key with no row is a surface whose supervision is
# undefined — the exact gap the ladder exists to close — and a row naming a key
# the manifest vocabulary does not know is a row that silently stopped meaning
# anything when a key was renamed.
#
# WHAT IT DOES NOT ASSERT, AND CANNOT: that a writer honoured its row. The gate
# that would refuse a prompted-level write with no cited ruling deliberately
# does not exist yet — structure before enforcement, the owner's rule in
# CLAUDE.md, reasoning at wss/logs/WSS.DECISIONS.md's 2026-08-17 (sixteenth)
# entry. This section polices the structure only, which is why it can land in
# the same change that creates the file.
#
# SURFACE TOKENS ARE READ FROM THE TABLE, NOT HAND-KEPT HERE: backticked,
# key-shaped tokens in the first column of "## The assignment table". Tokens
# that are not key-shaped — section names like `## State`, file paths like the
# hazard overflow's — are the named non-key surfaces and are not validated
# against the manifest. The out-of-scope set is read from the ladder's own
# "## Out of scope" section rather than restated: tooling.sources lives there
# today, and this code deliberately does not know that.
#
# KEY VOCABULARY COMES FROM wss/workflow/WSS.MANIFEST.md — every WSS.record.*
# it documents — so a row for a key THIS project does not declare (behaviour,
# toolbelt) is legal: the table is one table for every project on the suite.
# Declared keys come from the manifest with all-string paths joined, which
# recurses into object values, because .WSS.record.tooling is an OBJECT and a
# jq walk that skips non-string values is exactly how wss-commit-provenance.sh
# went blind to three of its own records (wss/logs/WSS.DECISIONS.md,
# 2026-08-17 (fifteenth)).
sl_file="$CLAUDE_DIR/wss/workflow/WSS.SUPERVISION-LADDER.md"
sl_manifest="$CLAUDE_DIR/.claude/WSS.WORKFLOW.json"
sl_vocabfile="$CLAUDE_DIR/wss/workflow/WSS.MANIFEST.md"
if [ ! -f "$sl_file" ]; then
  notice "no wss/workflow/WSS.SUPERVISION-LADDER.md — supervision coverage was
      not checked, so no surface here has a defined supervision level"
elif [ ! -f "$sl_manifest" ] || [ ! -f "$sl_vocabfile" ]; then
  notice "supervision ladder present but the manifest or WSS.MANIFEST.md is
      missing — the table had nothing to be checked against"
else
  sl_rows=$(awk '
      /^## The assignment table/ { t = 1; next }
      t && /^## /                { exit }
      t && /^\|/ {
        split($0, c, "|"); cell = c[2]
        while (match(cell, /`[^`]+`/)) {
          print substr(cell, RSTART + 1, RLENGTH - 2)
          cell = substr(cell, RSTART + RLENGTH)
        }
      }
    ' "$sl_file" | grep -E '^[a-zA-Z]+(\.[a-zA-Z]+)*$' | sort -u)
  sl_oos=$(awk '
      /^## Out of scope/ { t = 1; next }
      t && /^## /        { exit }
      t {
        while (match($0, /`[^`]+`/)) {
          print substr($0, RSTART + 1, RLENGTH - 2)
          $0 = substr($0, RSTART + RLENGTH)
        }
      }
    ' "$sl_file" | grep -E '^[a-zA-Z]+(\.[a-zA-Z]+)*$' | sort -u)
  sl_declared=$(jq -r '[.WSS.record | paths(type=="string" or type=="array")]
      | .[] | select(all(.[]; type=="string")) | join(".")' "$sl_manifest" \
      2>/dev/null | sort -u)
  sl_vocab=$(grep -o 'WSS\.record\.[a-zA-Z]*\(\.[a-zA-Z]*\)*' "$sl_vocabfile" |
      sed 's/^WSS\.record\.//' | sort -u)
  sl_missing=""
  for k in $sl_declared; do
    printf '%s\n' "$sl_oos" | grep -qxF "$k" && continue
    printf '%s\n' "$sl_rows" | grep -qxF "$k" || sl_missing="$sl_missing $k"
  done
  sl_unknown=""
  for k in $sl_rows; do
    printf '%s\n' "$sl_vocab" | grep -qxF "$k" || sl_unknown="$sl_unknown $k"
  done
  if [ -n "$sl_missing" ]; then
    fail "these declared record keys have no row in
        wss/workflow/WSS.SUPERVISION-LADDER.md's assignment table:${sl_missing}
        A surface with no row has an UNDEFINED supervision level, which is the
        gap the ladder exists to close. The assignment is the owner's — obtain
        it rather than inventing a default, and never widen the out-of-scope
        section to make this pass."
  fi
  if [ -n "$sl_unknown" ]; then
    fail "these supervision-ladder rows name keys wss/workflow/WSS.MANIFEST.md
        does not document:${sl_unknown}
        A row for an unknown key stopped meaning anything — usually a key was
        renamed and the table was not. Fix the table against the manifest
        vocabulary; do not add vocabulary to make a row true."
  fi
  if [ -z "$sl_missing" ] && [ -z "$sl_unknown" ]; then
    pass "every declared record key has a supervision row ($(printf '%s\n' "$sl_declared" | grep -c .) keys checked
        against $(printf '%s\n' "$sl_rows" | grep -c .) table tokens), and every row key is manifest vocabulary"
  fi
fi

# ---------------------------------------------- the check-method table, twice

head_ "Check-method tables"

# .claude/WSS.TOOLING.md's "shared check methods" table and
# wss/tests/WSS.CHECKS.md's "Method and runner" table used to be the
# same rows written twice, policed for agreement. wss/workflow/WSS.RECORD-CONTRACT.md's
# "A concept is stated once" forbids that now — `wss/logs/WSS.DECISIONS.md`'s
# `2026-08-14 (first)` entry. Neither file sits behind the docs/ site's
# docsify router, so a pointer costs nothing. wss/tests/WSS.CHECKS.md
# is canon — it alone carries the method/runner framing and the exceptions
# section — and the catalog now points at it instead of restating its rows.
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
mt_readme="$CLAUDE_DIR/wss/tests/WSS.CHECKS.md"
if [ -f "$mt_cat" ] && [ -f "$mt_readme" ]; then
  mt_b=$(method_rows_ "$mt_readme")
  if [ -z "$mt_b" ]; then
    fail "no check-method table found in wss/tests/WSS.CHECKS.md — its
        'Method and runner' table is the only place these rows are written
        now, and a table that cannot be read agrees with everything."
  elif grep -qE '^\|[[:space:]]*Method[[:space:]]*\|[[:space:]]*What it finds[[:space:]]*\|[[:space:]]*Run by[[:space:]]*\|' "$mt_cat"; then
    fail ".claude/WSS.TOOLING.md still carries a Method/What it finds/Run by
        table — those rows live once, in wss/tests/WSS.CHECKS.md. Drop
        the table and point at it instead of restating it."
  elif ! grep -q 'wss/tests/WSS.CHECKS.md' "$mt_cat"; then
    fail ".claude/WSS.TOOLING.md's 'The shared check methods' section no
        longer points at wss/tests/WSS.CHECKS.md — without the pointer
        a reader has nowhere to go for what a method finds or runs."
  else
    pass "the catalog points at wss/tests/WSS.CHECKS.md instead of restating its check-method table ($(printf '%s\n' "$mt_b" | grep -c .) methods)"
  fi
else
  mt_gone=""
  [ -f "$mt_cat" ] || mt_gone=".claude/WSS.TOOLING.md"
  [ -f "$mt_readme" ] || mt_gone="${mt_gone:+$mt_gone and }wss/tests/WSS.CHECKS.md"
  notice "no check-method table pair to compare — $mt_gone is not under
        $CLAUDE_DIR, so the two tables were never read. Both ship in every
        install; a file that MOVED reads exactly like a tree that never had one."
fi

# The pair above compares the two tables against EACH OTHER, and two tables that
# never learned about a third method agree perfectly — a method file added
# without a row is invisible to both, and stays invisible because nothing else
# enumerates the directory. The reverse costs as little: a row naming a file
# that has been renamed or removed reads exactly like a live method, which is
# the failure the cross-reference checks exist for everywhere else. So the pair
# is anchored to the directory it describes, in both directions. WSS.CHECKS.md
# is the index rather than a method and is never a row.
if [ -d "$CLAUDE_DIR/wss/tests" ] && [ -n "${mt_b:-}" ]; then
  mt_named=$(printf '%s\n' "$mt_b" | cut -d'|' -f1 | sort -u)
  mt_ondisk=$(find "$CLAUDE_DIR/wss/tests" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
              grep -vx 'WSS.CHECKS.md' | sort)
  mt_unlisted=$(comm -13 <(printf '%s\n' "$mt_named") <(printf '%s\n' "$mt_ondisk") | tr '\n' ' ')
  mt_ghost=$(comm -23 <(printf '%s\n' "$mt_named") <(printf '%s\n' "$mt_ondisk") | tr '\n' ' ')
  if [ -n "$mt_unlisted" ]; then
    fail "method file with no row in either check-method table: $mt_unlisted
        Both tables compare clean, because neither knows it exists. Add the row
        to wss/tests/WSS.CHECKS.md and .claude/WSS.TOOLING.md."
  fi
  if [ -n "$mt_ghost" ]; then
    fail "check-method table names a file that is not in wss/tests/: $mt_ghost
        A row for a method that moved or was retired reads as a live one."
  fi
  [ -z "$mt_unlisted" ] && [ -z "$mt_ghost" ] &&
    pass "every method file has a row, and every row a file ($(printf '%s\n' "$mt_ondisk" | grep -c .) methods)"
fi

# The same table exists a THIRD time, in wss/docs/annex/WSS.CLAUDE-TOOLING.md, and the
# pair above guards only the first two — which is how that copy silently carried a
# false cell until 641fa66 found it by hand.
#
# The ruling on it is the one the record-vs-queue pair above already carries for
# wss/docs/annex/WSS.LANE-SYNCHING.md: the annex is the docs-site reader's CONDENSED copy,
# so its cells are free to differ — a shorter "what it finds", a runner named
# rather than linked, no href at all — and forcing them into step would collapse
# two documents into one. What may not diverge is the row labels. Every method
# the annex teaches must still be one wss/tests/WSS.CHECKS.md asserts, or
# the docs page is teaching a method the authority renamed or dropped. A method
# the annex skips is condensation, not drift, and stays free.
mt_annex="$CLAUDE_DIR/wss/docs/annex/WSS.CLAUDE-TOOLING.md"
if [ -f "$mt_annex" ] && [ -n "${mt_b:-}" ]; then
  mt_auth=$(printf '%s\n' "$mt_b" | cut -d'|' -f1 | sort -u)
  mt_anx=$(method_rows_ "$mt_annex" | cut -d'|' -f1 | sort -u)
  if [ -z "$mt_anx" ]; then
    fail "no check-method table found in wss/docs/annex/WSS.CLAUDE-TOOLING.md — the
        licence to condense is over the CELLS, not over the header, and a table
        the parser cannot find agrees with everything. It needs a
        '| Method | What it finds | Run by |' table like the other two."
  else
    mt_anx_extra=$(comm -13 <(printf '%s\n' "$mt_auth") <(printf '%s\n' "$mt_anx") | tr '\n' ' ')
    if [ -z "$mt_anx_extra" ]; then
      pass "the annex's check-method rows all exist in wss/tests/WSS.CHECKS.md ($(printf '%s\n' "$mt_anx" | grep -c .) checked)"
    else
      fail "wss/docs/annex/WSS.CLAUDE-TOOLING.md's check-method table carries methods
        wss/tests/WSS.CHECKS.md's does not: ${mt_anx_extra}
        The annex condenses the authority's table, so the authority may hold
        rows the annex skips — never the reverse. A method only the annex names
        is one the authority renamed or dropped."
    fi
  fi
else
  if [ ! -f "$mt_annex" ]; then
    notice "no check-method annex to compare — wss/docs/annex/WSS.CLAUDE-TOOLING.md
        is not under $CLAUDE_DIR, so nothing checked the annex's rows against
        the authority's. It ships in every install; a file that MOVED reads
        exactly like a tree that never had one."
  else
    notice "no check-method annex to compare — the authority's table did not
        resolve above, so the annex had nothing to be checked against"
  fi
fi

if [ -f "$mt_annex" ]; then
  if grep -qF 'canon table in `wss/tests/WSS.CHECKS.md`, sanctioned' "$mt_annex"; then
    pass "wss/docs/annex/WSS.CLAUDE-TOOLING.md's check-method table names its exception-2 note"
  else
    fail "wss/docs/annex/WSS.CLAUDE-TOOLING.md's check-method table condenses
        wss/tests/WSS.CHECKS.md with no exception-2 note naming it — exception 2
        requires the note at the copy, and a condensation carrying none is an
        unsanctioned hand-copy, not a licensed one."
  fi
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
# reads. There is a second hand-copy of the table in wss/docs/annex/WSS.CLAUDE-TOOLING.md,
# but it is licensed to condense on the ruling above, so it can only be compared
# at label level and never settles a cell. So the assertion is the narrower one
# that is still worth having: every referent the table names must RESOLVE — the
# flag to a live flag, the writer to a writers/ file, the script to a script, the
# method to a file in wss/tests/, the role to a documented manifest role —
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
          [ -f "$CLAUDE_DIR/wss/workflow/writers/$iw_w" ] ||
            iw_bad="$iw_bad $tok(no wss/workflow/writers/$iw_w)" ;;
        WSS.agents.*)
          iw_seen=$((iw_seen + 1))
          iw_role=${tok#WSS.agents.}
          grep -qF -- "\`$iw_role\`" "$CLAUDE_DIR/wss/workflow/WSS.MANIFEST.md" 2>/dev/null ||
            iw_bad="$iw_bad $tok(no such role in WSS.MANIFEST.md)" ;;
        */*.md)
          iw_seen=$((iw_seen + 1))
          [ -f "$CLAUDE_DIR/$tok" ] || iw_bad="$iw_bad $tok(no such file)" ;;
        wss-*)
          # A bare wss- name is a skill OR an agent. Agents are invoked and so
          # are edges in this table — `--wss-release` -> `wss-release-prep`,
          # `--wss-stocktake` -> `wss-survey` — but until 2026-08-13 only
          # skills/ was searched, so naming an agent here failed as "no such
          # skill" and the table simply could not express an agent edge. The
          # missing arrows read as an absence of delegation rather than as an
          # inexpressible one, which is the opposite of what this table is for.
          iw_seen=$((iw_seen + 1))
          [ -f "$CLAUDE_DIR/skills/$tok/SKILL.md" ] ||
            [ -f "$CLAUDE_DIR/agents/$tok.md" ] ||
            iw_bad="$iw_bad $tok(no such skill or agent)" ;;
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
    # enumerates wss/workflow/writers/. WSS.WRITERS.md is the index rather than a
    # procedure and is never a referent — the same exemption WSS.CHECKS.md has above.
    if [ -d "$CLAUDE_DIR/wss/workflow/writers" ]; then
      iw_named=$(printf '%s\n' $iw_targets | grep -e '-writer$' -e '-tracker$' |
                 tr '[:lower:]' '[:upper:]' | sed 's/^/WSS./;s/$/.md/' | sort -u)
      iw_ondisk=$(find "$CLAUDE_DIR/wss/workflow/writers" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null |
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
    iw_annex="$CLAUDE_DIR/wss/docs/annex/WSS.CLAUDE-TOOLING.md"
    if [ -f "$iw_annex" ]; then
      iw_anx=$(invokes_cell_ "$iw_annex" 2)
      if [ -z "$iw_anx" ]; then
        fail "no caller->invokes table found in wss/docs/annex/WSS.CLAUDE-TOOLING.md —
        the annex may condense its cells and skip rows, but the table itself is
        one the docs site teaches from, and one that cannot be read agrees with
        everything."
      else
        iw_anx_extra=$(comm -13 <(printf '%s\n' "$iw_callers") <(printf '%s\n' "$iw_anx") | tr '\n' ' ')
        if [ -z "$iw_anx_extra" ]; then
          pass "the annex's callers all exist in the catalog's table ($(printf '%s\n' "$iw_anx" | grep -c .) checked)"
        else
          fail "wss/docs/annex/WSS.CLAUDE-TOOLING.md names callers .claude/WSS.TOOLING.md
        does not: ${iw_anx_extra}
        The annex condenses the catalog, so the catalog may hold rows the annex
        skips — never the reverse. A caller only the annex has is one the
        catalog renamed or dropped."
        fi
      fi
    else
      notice "no caller->invokes annex to compare — wss/docs/annex/WSS.CLAUDE-TOOLING.md
        is not under $CLAUDE_DIR, so the annex's callers were never checked
        against the catalog's. It ships in every install; a file that MOVED
        reads exactly like a tree that never had one."
    fi

if [ -f "$iw_annex" ]; then
  if grep -qF 'canon table in `.claude/WSS.TOOLING.md`' "$iw_annex"; then
    pass "wss/docs/annex/WSS.CLAUDE-TOOLING.md's caller->invokes table names its exception-2 note"
  else
    fail "wss/docs/annex/WSS.CLAUDE-TOOLING.md's caller->invokes table condenses
        .claude/WSS.TOOLING.md with no exception-2 note naming it — exception 2
        requires the note at the copy, and a condensation carrying none is an
        unsanctioned hand-copy, not a licensed one."
  fi
fi

    # ---- row completeness: nothing above reads in the direction that catches
    # an UNDER-count. Every referent the table names is checked to RESOLVE, and
    # every writer procedure on disk is checked to be NAMED somewhere — but a
    # row simply missing a real edge, because a skill's own prose already
    # claims it and nobody carried the sentence into the table, reads exactly
    # like a complete row to both of those checks. This derives the edges a
    # row SHOULD carry, mechanically, from the CALLER's own SKILL.md and
    # references/ — never a sibling's.
    #
    # An edge is a backticked `--wss-x` flag, `WSS.agents.x` role, or
    # `x-writer`/`x-tracker` name, in the SAME SENTENCE as — immediately
    # preceded by — one of six dispatch verbs: per, via, see, invoke, through,
    # follow, or "hand ... to". Two verbs that read as dispatch in isolation
    # are deliberately left out; both reproduce a false edge on this suite's
    # own prose without the exclusion — reproduce either with the greps below
    # rather than trusting this comment:
    #
    #   "use"             grep -n 'that will use `--wss-start`' skills/adopt/references/WSS.STEP7-ASK.md
    #                      — describes what an ADOPTED PROJECT does later, not
    #                      what --wss-adopt itself invokes.
    #   "that is"/"thats" grep -n 'that is `--wss-full-stocktake`' skills/full-check/SKILL.md
    #                      — this suite's own idiom for a BOUNDARY statement
    #                      ("that is X's [job]"), the opposite of a dispatch:
    #                      it says a neighbour owns something so THIS skill
    #                      does not have to. `--wss-plan` names `--wss-release`
    #                      throughout its own file this same way and never
    #                      invokes it.
    #
    # Reading only the CALLER's own files (never a sibling's) is what keeps a
    # row from being marked incomplete by prose that merely cites the same
    # flag from elsewhere.
    #
    # Warn, never fail. This is a heuristic reading of natural-language verbs,
    # not a structural fact like a broken link — a verb outside the six above,
    # or a genuine dispatch phrased without one, is a MISS this check cannot
    # see, and that is the safe direction to miss in: the risk that matters is
    # the other one, a phrase this six-verb list has not been checked against
    # yet reading as a dispatch when it is a boundary statement, the same
    # shape as the two traps above. That asymmetry holds even on a tree where
    # this finds nothing today.
    iw_row_targets_() { # file, caller name -> that row's backticked cells only
      awk -v want="$2" '
        /^\|[[:space:]]*Caller[[:space:]]*\|[[:space:]]*Invokes[[:space:]]*\|/ { t = 1; next }
        t && /^\|[[:space:]]*[-:]/ { next }
        t && /^\|/ {
          n = split($0, f, "|")
          if (n >= 5) {
            c = f[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", c); gsub(/`/, "", c)
            if (c == want) {
              s = f[3]
              while (match(s, /`[^`]+`/)) {
                tok = substr(s, RSTART + 1, RLENGTH - 2)
                s = substr(s, RSTART + RLENGTH)
                sub(/[[:space:]].*/, "", tok)
                if (tok != "") print tok
              }
            }
          }
          next
        }
        t { t = 0 }
      ' "$1" | sort -u
    }
    iw_skill_for_flag_() { # flag -> skill, the same read as the Shorthand-flags section above
      awk -v flag="$1" '
        /^[[:space:]]*--[-a-z|[:space:]]*\)[[:space:]]*echo/ {
          alts = $0; sub(/\).*/, "", alts); gsub(/[[:space:]]/, "", alts)
          n = split(alts, a, "|")
          for (i = 1; i <= n; i++) if (a[i] == flag) {
            t = $0; sub(/.*echo[[:space:]]+/, "", t); sub(/[[:space:]]*;;.*/, "", t)
            print t; exit
          }
        }' "$hook"
    }
    IW_VERBS='(per|via|see|invoke|through|follow|hand[a-z]* (it |them |off )?to)'
    iw_rc_bad=""; iw_rc_seen=0
    for iwc in $iw_callers; do
      case $iwc in
        --*) iwsk=$(iw_skill_for_flag_ "$iwc") ;;
        *)   iwsk=$iwc ;;
      esac
      [ -n "$iwsk" ] || continue
      iwd="$CLAUDE_DIR/skills/$iwsk"
      [ -f "$iwd/SKILL.md" ] || continue
      iw_derived=$(grep -ohiE "$IW_VERBS (the )?\`(--wss-[a-z-]+|WSS\.agents\.[a-zA-Z]+|[a-z]+-writer|[a-z]+-tracker)\`" \
                     "$iwd"/SKILL.md "$iwd"/references/*.md 2>/dev/null |
                   grep -oE '`(--wss-[a-z-]+|WSS\.agents\.[a-zA-Z]+|[a-z]+-writer|[a-z]+-tracker)`' |
                   tr -d '`' | sort -u)
      [ -n "$iw_derived" ] || continue
      iw_row=$(iw_row_targets_ "$iw_cat" "$iwc")
      for iwt in $iw_derived; do
        iw_rc_seen=$((iw_rc_seen + 1))
        printf '%s\n' "$iw_row" | grep -qxF -- "$iwt" ||
          iw_rc_bad="$iw_rc_bad $iwc->$iwt"
      done
    done
    if [ -n "$iw_rc_bad" ]; then
      warn "the caller->invokes table under-counts what a skill's own prose claims
        to dispatch:${iw_rc_bad}
        Each pair is CALLER->EDGE: the caller's row in .claude/WSS.TOOLING.md
        has no cell for that edge, though the caller's own SKILL.md or
        references/ names it as a dispatch. Add the edge, or if the prose is
        not actually a dispatch, that is itself worth a second look — see the
        six-verb list in this check's own comment for what does and does not
        read as one."
    elif [ $iw_rc_seen -gt 0 ]; then
      pass "no dispatch a skill's own prose claims is missing from its row ($iw_rc_seen checked)"
    else
      notice "no skill prose matched the row-completeness dispatch pattern at all —
        not a fault by itself on a small or synthetic tree, but if this ever
        prints against this suite's own skills/ the six-verb list may have
        gone blind rather than the tree having gone clean"
    fi
  fi
else
  notice "no caller->invokes table to compare — .claude/WSS.TOOLING.md is not
        under $CLAUDE_DIR, so no caller table was read. It ships in every
        install; a file that MOVED reads exactly like a tree that never had one."
fi

# ------------------------------------------------------- the lane tables, twice

head_ "Lane tables"

# The four-rulings table used to be a hand-copy pair — the same table in
# skills/lane-record-sync/{SKILL.md,references/*.md} and in
# wss/docs/annex/WSS.LANE-SYNCHING.md, policed for agreement. wss/docs/annex/ sits behind
# the wss/docs/ site's docsify router (wss/docs/_sidebar.md names no wss/workflow/ or
# skills/ page, and wss/docs/index.html's docsify root is wss/docs/), so a bare
# pointer from the annex into skills/ would leave the site — the site-exit
# cost wss/workflow/WSS.RECORD-CONTRACT.md's "A concept is stated once" licenses
# form 2 for (`wss/logs/WSS.DECISIONS.md`'s `2026-08-14 (first)` entry).
# wss-gen-lane-rulings.sh now derives the annex's copy from the skill's own
# table; a derived copy is checked by regenerating and comparing, never by a
# reader asserting the two agree, so this check delegates to the generator's
# own --check rather than reading both tables itself.
rl_gen="$CLAUDE_DIR/wss/scripts/wss-gen-lane-rulings.sh"
rl_annex="$CLAUDE_DIR/wss/docs/annex/WSS.LANE-SYNCHING.md"
if [ -f "$rl_gen" ]; then
  if rl_msg=$(bash "$rl_gen" --check 2>&1); then
    pass "$rl_msg"
  else
    fail "wss/docs/annex/WSS.LANE-SYNCHING.md's four-rulings table is stale: $rl_msg
        Regenerate with \`bash wss/scripts/wss-gen-lane-rulings.sh\` and commit the result."
  fi
else
  notice "no wss-gen-lane-rulings.sh to run — the four-rulings table's derived
        copy in wss/docs/annex/WSS.LANE-SYNCHING.md was never checked against its
        canon. It ships in every install; a file that MOVED reads exactly
        like a tree that never had one."
fi

# The record-vs-queue table (wss/workflow/WSS.LANE-CONTRACT.md and
# wss/docs/annex/WSS.LANE-SYNCHING.md) is the cadence pair's shape instead: the
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
rvq_contract="$CLAUDE_DIR/wss/workflow/WSS.LANE-CONTRACT.md"
if [ -f "$rvq_contract" ] && [ -f "$rl_annex" ]; then
  rvq_a=$(rvq_labels_ "$rvq_contract")
  rvq_b=$(rvq_labels_ "$rl_annex")
  if [ -z "$rvq_a" ] || [ -z "$rvq_b" ]; then
    rvq_blind=""
    [ -z "$rvq_a" ] && rvq_blind="wss/workflow/WSS.LANE-CONTRACT.md"
    [ -z "$rvq_b" ] && rvq_blind="${rvq_blind:+$rvq_blind and }wss/docs/annex/WSS.LANE-SYNCHING.md"
    fail "no record-vs-queue table found in $rvq_blind — the comparison needs a
        '| | A record | A transfer queue |' table in both files, and two
        tables that cannot be read compare equal"
  else
    rvq_extra=$(comm -13 <(printf '%s\n' "$rvq_a") <(printf '%s\n' "$rvq_b") | tr '\n' ' ')
    if [ -z "$rvq_extra" ]; then
      pass "the annex's record-vs-queue rows all exist in the contract ($(printf '%s\n' "$rvq_b" | grep -c .) checked)"
    else
      fail "wss/docs/annex/WSS.LANE-SYNCHING.md's record-vs-queue table carries rows
        wss/workflow/WSS.LANE-CONTRACT.md's does not: ${rvq_extra}
        The annex condenses the contract's table, so the contract may hold
        rows the annex skips — never the reverse. A label only the annex has
        is a property the authority renamed or dropped."
    fi
  fi
else
  rvq_gone=""
  [ -f "$rvq_contract" ] || rvq_gone="wss/workflow/WSS.LANE-CONTRACT.md"
  [ -f "$rl_annex" ] || rvq_gone="${rvq_gone:+$rvq_gone and }wss/docs/annex/WSS.LANE-SYNCHING.md"
  notice "no record-vs-queue table pair to compare — $rvq_gone is not under
        $CLAUDE_DIR, so the two tables were never read. Both ship in every
        install; a file that MOVED reads exactly like a tree that never had one."
fi

if [ -f "$rl_annex" ]; then
  if grep -qF 'canon table in `wss/workflow/WSS.LANE-CONTRACT.md`' "$rl_annex"; then
    pass "wss/docs/annex/WSS.LANE-SYNCHING.md's record-vs-queue table names its exception-2 note"
  else
    fail "wss/docs/annex/WSS.LANE-SYNCHING.md's record-vs-queue table condenses
        wss/workflow/WSS.LANE-CONTRACT.md with no exception-2 note naming it — exception 2
        requires the note at the copy, and a condensation carrying none is an
        unsanctioned hand-copy, not a licensed one."
  fi
fi

# ------------------------------------------------- the splittable set, restated

head_ "Splittable set"

# wss/workflow/WSS.LANE-CONTRACT.md names which records may split by lane, in its
# "Which records may split, and which must never" section. Eight sites used to
# restate the key list by hand so a dispatching skill's reader would not have
# to follow a link — the copies wss/workflow/WSS.RECORD-CONTRACT.md's "A concept
# is stated once" now forbids (`wss/logs/WSS.DECISIONS.md`'s `2026-08-14 (first)`
# entry). None of the eight sites sits behind the docs/ site's docsify router,
# so a pointer costs nothing: each now points at the contract instead of
# naming the keys, and this check asserts the restatement stays gone rather
# than comparing copies for agreement.
#
# DISCOVERY BY MARKER, NOT A FILE LIST — unchanged from before. Both the canon
# and any site attempting to restate it are found by their own wording, over
# md_files_(). A hardcoded list has to be right about where the files live,
# and the tree is under a reorg that moves wss/workflow/ and skills/ wholesale. A
# marker survives that, and the canon count below turns a walk whose own
# wording changed into a FAILURE rather than a green run over an empty set.
#
# What discovery costs is a false-positive risk, so the exclusions are stated
# rather than incidental. Scripts are out because md_files_() reads only *.md —
# which is also what stops this check matching its own source and the test
# fixtures. Records are out because they QUOTE the set rather than dispatch from
# it: wss/logs/ narrates the decision, wss/records/WSS.TODO.md carried the entry
# this check came from, wss/logs/WSS.CHANGELOG.md logs the change, and .claude/ is
# per-checkout state. wss/generated/ is a derived index, quoting rather than
# dispatching same as the records it indexes, and wss/docs/ is the docs site's
# own condensed copy. Each of those is named individually rather than
# excluding the whole of wss/ wholesale (true from 2026-08-15 to reorg tier 3,
# when wss/ held nothing else): tier 3 moved wss/workflow/ and wss/tests/ under
# the same prefix, and a blanket wss/* exclusion went blind to its own canon
# file, wss/workflow/WSS.LANE-CONTRACT.md, along with every restatement site
# that might now live under wss/workflow/ or wss/tests/.
#
# The three-key subsets elsewhere (`todo`, `openDecisions`, `roadmap` — the
# transfer queue's targets) carry neither marker: they are a different claim
# about a different thing, and flagging them as drift is the mistake that would
# get this check weakened rather than obeyed.
sp_files_() {
  md_files_ | while IFS= read -r -d '' p; do
    case ${p#"$CLAUDE_DIR"/} in
      .claude/* | wss/logs/* | wss/records/* | wss/generated/* | wss/docs/*) continue ;;
    esac
    printf '%s\0' "$p"
  done
}

# Three of the eight sites used to wrap the key list across a line break, and
# one wrapped between "overrides" and "`WSS.record.X`". A line-based grep sees
# `todo` and `openDecisions` and misreads a wrapped-but-correct line, so the
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

sp_rows=$(sp_files_ | xargs -0 -r perl -e "$SPLITTABLE_PL" 2>/dev/null || true)
sp_canon_rows=$(printf '%s\n' "$sp_rows" | grep '^canon' || true)
sp_site_rows=$(printf '%s\n' "$sp_rows" | grep '^site' || true)
sp_canon_n=$(printf '%s' "$sp_canon_rows" | grep -c . || true)
sp_n=$(printf '%s' "$sp_site_rows" | grep -c . || true)

sp_contract="$CLAUDE_DIR/wss/workflow/WSS.LANE-CONTRACT.md"
if [ "$sp_canon_n" -eq 0 ] && [ "$sp_n" -eq 0 ]; then
  # Two different states used to share this pass. An adopted project carries
  # neither the contract nor anything restating it, and has nothing here to
  # disagree about — that is health. A SUITE tree reaching zero/zero is not:
  # it means the canon marker stopped matching. Before the eight restatement
  # sites became pointers a healthy suite tree had a non-zero site count and
  # THAT was what told the two apart; nothing replaced it, so the presence of
  # the contract file does. An adopted tree keeps its copy under
  # .claude/wss/workflow/, which sp_files_() already excludes, so it does not
  # resolve here and still passes.
  if [ -f "$sp_contract" ]; then
    fail "wss/workflow/WSS.LANE-CONTRACT.md is present but states no splittable set
        this walk can find, and nothing restates one. The authority is the line
        reading '**Splittable: \`todo\`, ...**'. Either its wording changed, or
        it moved somewhere md_files_() does not reach. This used to be caught by
        the restatement count being non-zero; since those sites became pointers,
        the contract's presence is what tells a suite tree from an adopted one."
  else
    notice "no splittable-set contract here, and nothing restating one"
  fi
elif [ "$sp_canon_n" -gt 1 ]; then
  fail "the splittable set is declared as canon in more than one place:
        $(printf '%s\n' "$sp_canon_rows" | while IFS=$'\t' read -r _ f l _; do
              printf '%s:%s ' "${f#"$CLAUDE_DIR"/}" "$l"; done)
        One authority, or a restatement has two things to agree with.
        wss/workflow/WSS.LANE-CONTRACT.md owns it."
elif [ "$sp_canon_n" -eq 0 ]; then
  fail "$sp_n site(s) name a splittable-key list and no contract states one.
        The authority is the line reading '**Splittable: \`todo\`, ...**' in
        wss/workflow/WSS.LANE-CONTRACT.md. Either it moved somewhere this walk does
        not reach, or its wording changed."
elif [ "$sp_n" -eq 0 ]; then
  pass "nothing restates the splittable set — $(printf '%s' "$sp_canon_rows" |
          cut -f2 | sed "s|^$CLAUDE_DIR/||"):$(printf '%s' "$sp_canon_rows" | cut -f3) is still its only statement"
else
  fail "$sp_n site(s) restate the splittable set by hand, which
        wss/workflow/WSS.RECORD-CONTRACT.md's 'A concept is stated once' forbids:
        $(printf '%s\n' "$sp_site_rows" | while IFS=$'\t' read -r _ f l k; do
              printf '\n        %s:%s (%s)' "${f#"$CLAUDE_DIR"/}" "$l" "$k"; done)
        Point at wss/workflow/WSS.LANE-CONTRACT.md's 'Which records may split, and
        which must never' section instead of naming the keys again."
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
  # Parser moved to wss-commit-provenance.sh --writers to avoid duplication.
  # The commit hook and the doctor share this exact implementation so they cannot drift.
  bash "$sw_parser" --writers "$1"
}
# Resolved from SELF_DIR, never from CLAUDE_DIR. The parser belongs to the
# INSTALLATION THIS SCRIPT CAME FROM, not to the tree being checked — CLAUDE_DIR
# is frequently an adopter's own config directory, which carries no suite
# scripts at all, and resolving there made every such run fail on a missing
# parser it was never supposed to own.
sw_parser="$SELF_DIR/wss/scripts/wss-commit-provenance.sh"
if [ ! -r "$sw_parser" ]; then
  fail "the sole-writer parser is missing, so no writer was counted"
fi
own_matrix="$CLAUDE_DIR/wss/workflow/WSS.OWNERSHIP.md"
if [ -f "$own_matrix" ]; then
  sw=$(sole_writers_ "$own_matrix")
  # The blind-parser guard every comparison here carries, and it has to be the
  # HEADER rather than the row count: a matrix in which every row disclaims
  # ownership legitimately yields no claims, and treating that as blindness
  # would fail a correct file. A renamed header is the failure worth catching,
  # because it leaves a parser reporting no conflicts over a table full of them.
  if ! grep -qE '^\|[[:space:]]*Verb[[:space:]]*\|.*\|[[:space:]]*Sole writer of[[:space:]]*\|' "$own_matrix"; then
    fail "no ownership matrix found in wss/workflow/WSS.OWNERSHIP.md — the check needs
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
  # Ruled 2026-08-14: the ownership matrix is mandatory in every install, so
  # its absence fails rather than being noted. The evidence was already in this
  # script — the grant check above warns when the same file is missing, and
  # --strict gates on warns, so a tree without it has failed a strict run since
  # long before this branch existed. Three sites disagreeing about the severity
  # of one file's absence was the actual defect.
  fail "no ownership matrix — wss/workflow/WSS.OWNERSHIP.md is not under
        $CLAUDE_DIR, so no record's writers were counted and nothing here can
        tell one writer from two. It ships in every install; a file that MOVED
        reads exactly like a tree that never had one, which is why this is not
        a notice."
fi

# --------------------------------------------------------------- audit reports

head_ "Audit reports"

# The reports under wss/logs/audits/ are frozen and excluded from every markdown check
# above; the maintained index of them is `WSS.record.audits` — since 2026-08-07
# `wss/logs/WSS.AUDITS.md`, resolved from the tree's own manifest below, with
# `wss/logs/audits/README.md` (now a pointer stub, still where the index lives in a tree
# that declares no key) as the fallback. Two things about the old arrangement
# had already failed silently, and each gets a check.
#
# 1. The index skipped a report: the file landed, the table row did not, and the
#    index's own warning about stale counts sat one section above the gap. It
#    said "four" once after there were more, and skipped pass 6 entirely on
#    2026-08-02 — nothing compared rows against the directory until this did.
a_idx_rel=$(jq -r '.WSS.record.audits // empty | if type == "string" then . else empty end' \
  "$CLAUDE_DIR/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
[ -n "$a_idx_rel" ] || a_idx_rel="wss/logs/audits/README.md"
a_idx="$CLAUDE_DIR/$a_idx_rel"
if [ -f "$a_idx" ]; then
  a_missing=0 a_total=0
  for a_f in "$CLAUDE_DIR"/wss/logs/audits/*.md; do
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
    notice "wss/logs/audits/ holds no reports beyond the index"
  elif [ "$a_missing" -eq 0 ]; then
    pass "every audit report has an index row ($a_total checked)"
  fi
else
  a_orphans=0
  for a_f in "$CLAUDE_DIR"/wss/logs/audits/*.md; do
    [ -e "$a_f" ] || continue
    [ "$(basename "$a_f")" = "README.md" ] && continue
    a_orphans=$((a_orphans + 1))
  done
  if [ "$a_orphans" -gt 0 ]; then
    fail "no $a_idx_rel, but wss/logs/audits/ holds $a_orphans report(s) — every report
        needs an index row and there is no index to hold one. The path comes
        from .claude/WSS.WORKFLOW.json's WSS.record.audits, so an index that
        moved is a manifest edit, not a doctor edit"
  else
    notice "no $a_idx_rel and no reports in wss/logs/audits/ — no audit index to check"
  fi
fi

# 2. The frozen-reports exemption is stated once, in md_files_() above — the
#    canon — and had to be typed a second time into CI's markdown-walking step,
#    because a YAML `run:` block cannot source a bash function and the exemption
#    is needed at exactly the point nothing else can reach it. That is
#    exception 2 in wss/workflow/WSS.RECORD-CONTRACT.md's "The exception list":
#    a verbatim copy no command reproduces, carrying a note at the copy saying
#    so. This reads md_files_()'s own pathspec literals rather than a second
#    hardcoded copy of them, so editing md_files_() is what changes what this
#    check expects verify.yml to carry — and it also requires the say-so note
#    ("VERBATIM COPY of md_files_()") the exception's second condition demands.
#    It once landed in one place and not the other, leaving CI red for eleven
#    commits on a report that is frozen by design.
#
#    ONE copy, not two, since 2026-08-16: verify.yml's "Cross-links between our
#    own files resolve" step was the second, and it was a duplicate of the Link
#    targets check above rather than of anything only CI could do — the same
#    walk over the same file set, two steps after the job already runs this
#    script with `--strict`. Deleting it is the smaller exception, so the count
#    below is 1 and drops to 0 only if the home-path step goes too.
#
#    The credential scan is asserted the OTHER way — it must keep walking every
#    tracked file, because a credential in a frozen report is still a credential.
verify_yml="$CLAUDE_DIR/.github/workflows/verify.yml"
if [ -f "$verify_yml" ]; then
  self="$SELF_DIR/wss/tests/wss-doctor.sh"
  excl=$(awk '/^md_files_\(\) \{$/,/^}$/' "$self" 2>/dev/null |
    grep -oE "':\(exclude\)wss/logs/audits/\*\*'" | head -n1)
  reinc=$(awk '/^md_files_\(\) \{$/,/^}$/' "$self" 2>/dev/null |
    grep -oE "'wss/logs/audits/README\.md'" | head -n1)
  if [ -z "$excl" ] || [ -z "$reinc" ]; then
    warn "md_files_()'s own pathspec literals could not be read from
        $self — the shape moved, so nothing below was checked against the
        canon rather than against a stale expectation"
  else
    v_ex=$(grep -cF "$excl" "$verify_yml" || true)
    v_re=$(grep -cF "$reinc" "$verify_yml" || true)
    v_note=$(grep -cF "VERBATIM COPY of md_files_()" "$verify_yml" || true)
    if [ "$v_ex" -eq 1 ] && [ "$v_re" -eq 1 ] && [ "$v_note" -eq 1 ]; then
      pass "CI's markdown walk carries md_files_'s pathspecs verbatim, with its
        say-so note (WSS.RECORD-CONTRACT.md's exception 2)"
    else
      fail "verify.yml's markdown walk has drifted from md_files_(): expected
        the exclusion, the README re-add and the say-so note once each, found
        $v_ex, $v_re and $v_note. That copy is exception 2 in
        wss/workflow/WSS.RECORD-CONTRACT.md's exception list, which holds only
        while the copy stays verbatim and says so at the copy — the last
        drift left CI red for eleven commits (WSS.HAZARDS.md, 'Reading CI').
        A count of 2 means a second walk came back; the one deleted on
        2026-08-16 was a duplicate of this script's own Link targets check"
    fi
  fi
  v_bare=$(grep -cF "< <(git ls-files -z)" "$verify_yml" || true)
  if [ "$v_bare" -ge 1 ]; then
    pass "CI's credential scan still walks every tracked file"
  else
    fail "verify.yml's credential scan no longer walks bare 'git ls-files -z' —
        excluding wss/logs/audits/ there would exempt frozen files from the one check
        that must never exempt anything"
  fi
else
  notice "no .github/workflows/verify.yml under $CLAUDE_DIR — no CI walk to
        compare against md_files_'s exemption pair. It ships in every install;
        a workflow that MOVED reads exactly like a tree with no CI."
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
        all silently fall back to defaults. Snapshot first (wss/scripts/wss-export-records.sh
        --all reads the legacy manifest), then migrate with --wss-update."
  fi
fi

if [ -d "$PWD/.claude/workflow" ] && [ ! -d "$PWD/.claude/wss/workflow" ]; then
  warn "project-local .claude/workflow/ found at the pre-reorg path. The
      global contracts now live under ~/.claude/wss/workflow/, and this
      project's own copy (if it defines local writer or check procedures)
      has not followed. Both shapes are still read here; migrate with
      --wss-update when convenient. If this project has never populated
      .claude/workflow/, this directory is stray and may simply be removed."
fi

if [ ! -f "$manifest" ]; then
  [ -f "$PWD/.claude/workflow.json" ] || \
  notice "no .claude/WSS.WORKFLOW.json — skills fall back to conventional filenames"
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

  # Key names, against wss/workflow/WSS.MANIFEST.md. The drift this catches is a key
  # that reads as configured and is read by nothing — two names for one concept
  # (`indexCheck` where every consumer wants `indexRegen`), or a key invented
  # for a skill that never looked it up. Warn rather than fail: an unknown key
  # is dead config, not a broken one.
  #
  # Containers with project-chosen sub-keys — hazards, gate.coverage,
  # audit.invalidates, WSS.lanes.named — are deliberately not descended into.
  # WSS.recordMode is not descended into either, though its sub-keys are a fixed
  # vocabulary: the record-write-modes block below checks them against what
  # WSS.record actually declares, which is stricter than a name list.
  KNOWN_KEYS='WSS.manifest WSS.branch WSS.record WSS.recordMode WSS.commands WSS.gate WSS.agents WSS.lanes WSS.audit
WSS.onSchemaChange WSS.hazards WSS.commitTrailer WSS.sweeps WSS.localCI WSS.prChecks
WSS.pair WSS.pair.relay WSS.pair.claims
WSS.suite WSS.suite.version WSS.suite.commit
WSS.docs WSS.docs.root WSS.docs.languages WSS.docs.devCommand
WSS.branch.integration WSS.branch.publish WSS.branch.mergeMethod WSS.branch.release
WSS.record.todo WSS.record.roadmap WSS.record.releases WSS.record.changelog WSS.record.handoff WSS.record.decisions
WSS.record.decisionsIndex WSS.record.openDecisions WSS.record.behaviour WSS.record.reference WSS.record.backlog
WSS.record.stocktake WSS.record.audits WSS.record.toolbelt WSS.record.tooling WSS.record.setup
WSS.record.tooling.catalog WSS.record.tooling.inventory WSS.record.tooling.sources
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
        See ~/.claude/wss/workflow/WSS.MANIFEST.md for the keys that exist."
    unknown=$((unknown + 1))
  done < <(jq -r '
      (.WSS // empty | keys[] | "WSS.\(.)"),
      (["branch","record","commands","agents","lanes","audit","suite","docs","pair"][] as $k
         | (.WSS[$k] // empty | keys[]? | "WSS.\($k).\(.)")),
      (.WSS.record.tooling // empty | keys[]? | "WSS.record.tooling.\(.)")
    ' "$manifest" 2>/dev/null | sort -u)
  if [ $keys_seen -eq 0 ]; then
    warn "no keys could be enumerated out of WSS.WORKFLOW.json, though it parsed as
        JSON and declares a version. Nothing was checked against WSS.MANIFEST.md."
  elif [ $unknown -eq 0 ]; then
    pass "every key is one WSS.MANIFEST.md documents ($keys_seen checked)"
  fi

  # The QA/staging tier has ONE source and it is not this file: the
  # `staging-branch` toggle in WSS.record.setup. A staging key here would be a
  # second source for one fact, which is the duplication the toggle was chosen
  # over — so this FAILS rather than warning, unlike an ordinary unknown key.
  # It reads the manifest and nothing else, deliberately: no toggle state can
  # make it fire, so "toggle on, no manifest key" — the correct configuration —
  # cannot produce a drift warning from here. Ruling: the decision log's
  # 2026-08-19 (thirty-seventh) and (thirty-ninth) entries.
  stg=$(jq -r '
      (.WSS // empty | keys[]? | "WSS.\(.)"),
      (["branch","record","commands","agents","lanes","audit","suite","docs","pair"][] as $k
         | (.WSS[$k] // empty | keys[]? | "WSS.\($k).\(.)"))
    ' "$manifest" 2>/dev/null | grep -i 'staging' | tr '\n' ' ')
  if [ -n "$stg" ]; then
    fail "the manifest declares a staging key: $stg
        The QA tier's single source is the \`staging-branch\` toggle in the setup
        record. A manifest key for it is a second source for one fact, and the
        two drift the first time only one is changed. Remove the key; set the
        toggle."
  else
    pass "no staging key in the manifest — the QA tier stays the setup toggle's"
  fi

  # WSS.prChecks maps a PR checkbox to the command that ticks it, and the value
  # is a manifest KEY rather than a command string precisely so there is one
  # copy of each command. That only holds if the key still resolves: rename or
  # remove a WSS.commands.* entry and the mapping points at nothing, which would
  # tick a box from a command that no longer exists. The proposal named this as
  # the mapping's residual maintenance; this is the half that is detectable.
  if jq -e '.WSS.prChecks != null' "$manifest" >/dev/null 2>&1; then
    pc_bad=$(jq -r '
        (.WSS.prChecks // {}) | to_entries[]
        | select((.value | type) != "string" or (.value | startswith("WSS.commands.")) == false
                 or ((.value | split(".")) as $p | $p | length != 3))
        | "\(.key)=\(.value)"' "$manifest" 2>/dev/null | tr '\n' ' ')
    pc_dead=$(jq -r '
        . as $m | ($m.WSS.prChecks // {}) | to_entries[]
        | select((.value | type) == "string" and (.value | startswith("WSS.commands.")))
        | . as $e | ($e.value | split(".")[2]) as $k
        | select(($m.WSS.commands // {}) | has($k) | not)
        | "\($e.key)→\($e.value)"' "$manifest" 2>/dev/null | tr '\n' ' ')
    if [ -n "$pc_bad" ]; then
      fail "WSS.prChecks value that is not a WSS.commands.<name> key: $pc_bad
        The value names the command key, never the command itself — a command
        string here is a second copy of one the manifest already declares."
    elif [ -n "$pc_dead" ]; then
      fail "WSS.prChecks points at a command this manifest does not declare: $pc_dead
        --wss-pr would tick that box from a command that does not exist, or skip
        it silently. Declare the command or drop the mapping."
    else
      pass "every WSS.prChecks mapping resolves to a declared command ($(jq -r '.WSS.prChecks | length' "$manifest") checked)"
    fi
  fi

  # The pair claims file names which session holds which role. It is gitignored
  # and per-checkout, so it is absent in almost every tree and its absence says
  # nothing — but where it EXISTS it is read to find the designer's address, and
  # a line nobody parses is worse than no file: an unrecognised role means the
  # protocol was extended without extending `pair`, and silently skipping it
  # hides that. A claim whose socket is gone is stale rather than malformed, so
  # it is reported and not failed: sockets die with their session, which is the
  # ordinary end of a pairing.
  pair_claims=".claude/WSS/PAIR"
  if [ -f "$pair_claims" ]; then
    pc_bad=""; pc_stale=""; pc_n=0
    while IFS= read -r line; do
      [ -n "${line// /}" ] || continue
      pc_n=$((pc_n + 1))
      case ${line%%:*} in
        executor|designer) ;;
        *) pc_bad="$pc_bad'${line%%:*}' " ; continue ;;
      esac
      pc_sock=$(printf '%s\n' "$line" | awk '{print $3}')
      [ -n "$pc_sock" ] && [ ! -S "$pc_sock" ] && pc_stale="$pc_stale${line%%:*} "
    done < "$pair_claims"
    if [ -n "$pc_bad" ]; then
      fail "unrecognised role in $pair_claims: $pc_bad
        The roles are 'executor' and 'designer' and there is no third. A line
        nobody parses means the pairing protocol was extended without extending
        skills/pair/SKILL.md, which is the file of record for this format."
    elif [ "$pc_n" -eq 0 ]; then
      warn "$pair_claims exists but holds no claim. An empty claims file and no
        claims file are the same state to every consumer; delete it or claim a
        role, so its presence is not read as a pairing that is not there."
    else
      pass "the pair claims file parses ($pc_n claim(s), roles recognised)"
      [ -z "$pc_stale" ] || notice "stale pair claim(s), socket gone: $pc_stale
        A claim is live while its socket exists, and sockets die with their
        session. The line may be taken by a new session of that role."
    fi
  fi

  # Every skill must be registered in wss-publish.sh's SKILL_NAMES, which strips
  # the wss- prefix for the published tree. An unregistered skill ships as
  # `/wss:wss-thing` and the assembly aborts — so the register is enforced only
  # by running the publish, and nothing routine does. It has now bitten twice in
  # one day: skill-toggle (found while probing something else) and pair
  # (found by a release tag's Publish action failing, after the tag was cut).
  # Checked here because the doctor runs constantly and the assembly does not.
  sn_pub="$CLAUDE_DIR/wss/scripts/wss-publish.sh"
  if [ -f "$sn_pub" ] && [ -d "$CLAUDE_DIR/skills" ]; then
    sn_reg=$(sed -n '/^SKILL_NAMES=(/,/)/p' "$sn_pub" | tr -d '\n' |
             sed 's/^SKILL_NAMES=(//; s/).*//')
    sn_missing=""
    for d in "$CLAUDE_DIR"/skills/wss-*/; do
      [ -d "$d" ] || continue
      n=$(basename "$d"); n=${n#wss-}
      printf '%s\n' $sn_reg | grep -qx "$n" || sn_missing="$sn_missing$n "
    done
    if [ -z "$sn_reg" ]; then
      fail "could not read SKILL_NAMES out of wss-publish.sh, so no skill was
        checked against it. A parser that matches nothing must not report a
        clean register."
    elif [ -n "$sn_missing" ]; then
      fail "skill(s) not registered in wss-publish.sh's SKILL_NAMES: $sn_missing
        The assembly strips the wss- prefix from each registered name; an
        unregistered skill ships still prefixed and aborts the publish. The
        failure surfaces only when someone runs the assembly, which nothing
        routine does — twice in one day it surfaced at a release instead."
    else
      pass "every skill is registered in wss-publish.sh's SKILL_NAMES ($(printf '%s\n' $sn_reg | grep -c .) names)"
    fi
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

  # The docs block. wss/tests/WSS.DOCS-AUDIT.md resolves every one of its
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
        \"devCommand\" — see wss/workflow/WSS.MANIFEST.md."
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
          elif [ -z "$(find "$PWD/$droot" -name '*.md' -print -quit 2>/dev/null)" ]; then
            fail "WSS.docs.root declares '$droot', which exists but holds no *.md
        file anywhere under it. wss/tests/WSS.DOCS-AUDIT.md walks this tree
        for pages to grep, so an empty one reports the same clean site a wrong
        path does. Point root at the directory that actually holds the site's
        markdown, or drop the key and let the fallback (docs/, doc/,
        documentation/, website/) resolve it. This only counts *.md files: if
        the site generator's own convention (an index file, another extension)
        changes, a directory that still holds *.md but is no longer what the
        generator reads will keep passing here."
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
          # Same fallback order as wss/workflow/WSS.MANIFEST.md's for a root left
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
        wss/tests/WSS.DOCS-AUDIT.md walks an empty set for this one and
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

  # Record write modes. `WSS.recordMode` maps each declared record to `log`,
  # `register` or `generated` — a sibling of `WSS.record` rather than a field
  # inside it, because every skill reads those values as scalars and the walker
  # below reads every string under WSS.record as a path that must exist.
  # wss/workflow/WSS.MANIFEST.md documents the key; the modes themselves are
  # wss/workflow/WSS.RECORD-CONTRACT.md's and are deliberately not restated here.
  #
  # Both directions are checked, and the reverse one is the reason this is not
  # a single loop: a tag left behind by a record that was removed from the
  # manifest keeps claiming a mode for a record nothing resolves, and an
  # append-only check driven off the tag then guards a file that is gone while
  # the record that replaced it goes unguarded.
  #
  # The enumeration is COUNTED, like the key walk above. `WSS.record`'s shape is
  # not owned here — `tooling` is a container whose sub-keys are descended into,
  # and a jq program that stops matching yields an empty set, which without the
  # count reads as "every declared record is tagged" over nothing at all.
  # `tooling.sources` is excluded because it is a glob list, not a record; any
  # other tooling sub-key is demanded, so a new one surfaces as untagged rather
  # than as silently exempt.
  rec_declared=$(jq -r '
      (.WSS.record // {}) | to_entries[]
      | if .key == "tooling"
        then (.value | objects | keys[] | select(. != "sources") | "tooling.\(.)")
        else .key end' "$manifest" 2>/dev/null | sort -u)
  if jq -e '.WSS.recordMode != null' "$manifest" >/dev/null 2>&1; then
    mode_bad=0
    if ! jq -e '.WSS.recordMode | type == "object"' "$manifest" >/dev/null 2>&1; then
      fail "WSS.recordMode is not an object. It maps a record key — the same names
        WSS.record uses — to \"log\", \"register\" or \"generated\";
        see wss/workflow/WSS.MANIFEST.md."
      mode_bad=1
    else
      rec_seen=0; tag_seen=0
      while IFS= read -r rk; do
        [ -n "$rk" ] || continue
        rec_seen=$((rec_seen + 1))
        # Two legal value shapes, per wss/workflow/WSS.MANIFEST.md: the bare
        # string, and an object carrying `mode` plus a log record's declared
        # shape (`grows`, `entry`). Read the mode out of either — reading the
        # object as a string reports the whole JSON blob as an unknown mode.
        rmode=$(jq -r --arg k "$rk" '.WSS.recordMode[$k]
                | if type == "object" then (.mode // empty) else (. // empty) end' "$manifest" 2>/dev/null)
        rgrows=$(jq -r --arg k "$rk" '.WSS.recordMode[$k] | if type == "object" then (.grows // empty) else empty end' "$manifest" 2>/dev/null)
        rentry=$(jq -r --arg k "$rk" '.WSS.recordMode[$k] | if type == "object" then (.entry // empty) else empty end' "$manifest" 2>/dev/null)
        case "$rgrows" in ''|tail|head) ;; *)
          fail "WSS.recordMode.$rk declares grows '$rgrows'. It names the end new
        entries arrive at and is tail or head — see wss/workflow/WSS.MANIFEST.md."
          mode_bad=1 ;;
        esac
        case "$rentry" in ''|heading|table-row) ;; *)
          fail "WSS.recordMode.$rk declares entry '$rentry'. It names what an entry
        is made of and is heading or table-row — see wss/workflow/WSS.MANIFEST.md."
          mode_bad=1 ;;
        esac
        rmut=$(jq -r --arg k "$rk" '.WSS.recordMode[$k] | if type == "object" then (.mutable // empty) else empty end' "$manifest" 2>/dev/null)
        case "$rmut" in ''|outcome|none) ;; *)
          fail "WSS.recordMode.$rk declares mutable '$rmut'. It names the one status
        field the record may have rewritten in place and is outcome or none —
        see wss/workflow/WSS.RECORD-CONTRACT.md's status-field table."
          mode_bad=1 ;;
        esac
        case $rmode in
          log | register | generated) ;;
          '')
            fail "WSS.record.$rk is declared but WSS.recordMode gives it no mode.
        A partial map is worse than none: the records it does name are enforced
        and this one is silently exempt. Tag it log, register or generated —
        wss/workflow/WSS.RECORD-CONTRACT.md's table says which."
            mode_bad=1 ;;
          *)
            fail "WSS.recordMode.$rk is '$rmode'. The modes are log, register and
        generated, and nothing else — see wss/workflow/WSS.MANIFEST.md."
            mode_bad=1 ;;
        esac
      done < <(printf '%s\n' "$rec_declared")
      while IFS= read -r tk; do
        [ -n "$tk" ] || continue
        tag_seen=$((tag_seen + 1))
        printf '%s\n' "$rec_declared" | grep -qxF -- "$tk" && continue
        fail "WSS.recordMode tags '$tk', which WSS.record does not declare. A mode
        for a record that resolves to no path guards nothing — drop the tag, or
        declare the record it was written for."
        mode_bad=1
      done < <(jq -r '.WSS.recordMode | keys[]?' "$manifest" 2>/dev/null)
      if [ "$rec_seen" -eq 0 ] || [ "$tag_seen" -eq 0 ]; then
        fail "WSS.recordMode is declared, but this check enumerated $rec_seen declared
        record(s) and $tag_seen tag(s) — one of the two walks matched nothing, so
        nothing was compared. A parser that stops matching fails here rather than
        reporting a clean run over an empty set."
        mode_bad=1
      fi
      [ "$mode_bad" -eq 0 ] &&
        pass "every declared record carries exactly one write mode ($rec_seen tagged)"
    fi
  elif [ -n "$rec_declared" ]; then
    # Warn, not fail. Absent does not mean untagged: wss/workflow/WSS.MANIFEST.md
    # makes WSS.RECORD-CONTRACT.md's table the fallback, so a project adopted
    # before this key classifies exactly as one adopted after it. Failing every
    # such tree on upgrade would be a migration wearing a check's clothes.
    warn "no WSS.recordMode in WSS.WORKFLOW.json, so which records are append-only
        is inherited from wss/workflow/WSS.RECORD-CONTRACT.md rather than declared
        here. Add the map — one entry per declared record — to make it local and
        checkable; see wss/workflow/WSS.MANIFEST.md."
  fi

  # The append-only guard's other half, and the only half that is per-clone.
  # `wss-append-only.sh --install-hook` writes a pre-commit hook into the git
  # dir; a clone that never runs it is guarded by CI alone, and nothing reported
  # the difference. The marker grepped for is the installer's own
  # (wss-append-only.sh:85) rather than a second detection invented here: it
  # exists precisely because the quoting around an absolute path is what a "does
  # it mention us" grep gets wrong, and two detections drift.
  #
  # Warn, not fail, for the reason the check above it gives: CI is the
  # enforcement and the hook is the early warning, so a tree without it is
  # behind rather than broken.
  #
  # Three gates, each one a place the warning would be noise:
  #   - no wss-append-only.sh in the installation, so there is nothing to run;
  #   - nothing tagged `log` in WSS.recordMode, so the guard resolves no record
  #     and the script itself refuses that set — the hook would guard nothing.
  #     An ABSENT map is deliberately NOT gated on: it is the warn directly
  #     above, and one manifest earning two warnings reads as two problems.
  #   - CI, where the checkout commits nothing and the workflow runs the guard
  #     as a step of its own. That same workflow runs this doctor with --strict,
  #     so an ungated warn would redden every build over a hook that would guard
  #     a tree about to be thrown away.
  ao_git=$(git rev-parse --git-common-dir 2>/dev/null) || ao_git=""
  # Resolved against $PWD exactly as the installer resolves it: git prints a
  # bare `.git` in the ordinary case, and the two have to name the same file.
  case $ao_git in '' | /*) ;; *) ao_git="$PWD/$ao_git" ;; esac
  if [ -n "$ao_git" ] && [ -f "$CLAUDE_DIR/wss/scripts/wss-append-only.sh" ] &&
     [ -z "${CI:-}${GITHUB_ACTIONS:-}" ] &&
     jq -e 'any((.WSS.recordMode // {}) | .[];
                . == "log" or ((type == "object") and .mode == "log"))' "$manifest" >/dev/null 2>&1
  then
    if grep -qF 'wss-append-only-hook' "$ao_git/hooks/pre-commit" 2>/dev/null; then
      # The marker proves a hook was installed once. It does not prove the path
      # that hook execs still exists: the hook names an ABSOLUTE path on this
      # machine by design, so a moved, renamed or partially-deleted checkout
      # leaves the marker intact and the exec dead. That state passed this check
      # and guarded nothing, which is the whole reason to resolve the target.
      ao_target=$(sed -n 's/^[[:space:]]*exec[[:space:]]*"\([^"]*\)".*/\1/p' \
                  "$ao_git/hooks/pre-commit" 2>/dev/null | head -1)
      if [ -z "$ao_target" ]; then
        fail "the pre-commit hook carries the append-only marker but execs nothing
        this check can resolve: $ao_git/hooks/pre-commit
        Re-install it, which rewrites the file for this checkout:
          bash $CLAUDE_DIR/wss/scripts/wss-append-only.sh --install-hook"
      elif [ ! -x "$ao_target" ]; then
        fail "the pre-commit hook execs a path that is not executable: $ao_target
        The marker matches, so the hook reads as installed while every commit it
        should guard runs unguarded — a deletion from a log record reaches CI
        instead of being refused here.
        Re-install it, which rewrites the path for this checkout:
          bash $CLAUDE_DIR/wss/scripts/wss-append-only.sh --install-hook"
      else
        pass "the append-only pre-commit hook is installed and its target resolves"
      fi
    else
      warn "no append-only pre-commit hook in this clone, so a commit that deletes
        a line from a log record is caught by CI afterwards rather than before it
        is written. The hook is untracked by design — it lives in the git dir and
        names an absolute path on this machine, so nothing is missing from the
        repository and every clone installs its own:
          $CLAUDE_DIR/wss/scripts/wss-append-only.sh --install-hook"
    fi
  fi

  # wss-append-only.sh hardcodes a log set for a tree whose manifest declares no
  # WSS.recordMode, and its comment calls that "the contract's log set". Nothing
  # compared the two. The contract could gain or lose a log record and the
  # fallback would go on guarding yesterday's set — so a record the contract
  # calls append-only would be silently unguarded in every tree relying on it.
  rc_file="$CLAUDE_DIR/wss/workflow/WSS.RECORD-CONTRACT.md"
  ao_script="$CLAUDE_DIR/wss/scripts/wss-append-only.sh"
  if [ -f "$rc_file" ] && [ -f "$ao_script" ]; then
    rc_set=$(sed -n 's/^|[[:space:]]*\*\*Log\*\*[^|]*|\([^|]*\)|.*/\1/p' "$rc_file" |
             grep -o '`[a-zA-Z]*`' | tr -d '`' | sort -u | tr '\n' ' ')
    ao_set=$(awk '/^  printf .%s\\n. [a-z]+ .*> "\$keys"$/{
                    sub(/^  printf .%s\\n. /, ""); sub(/ > "\$keys"$/, ""); print }' \
             "$ao_script" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    if [ -z "$rc_set" ]; then
      fail "could not read the Log row of WSS.RECORD-CONTRACT.md's record-mode
        table, so the append-only fallback is compared against nothing. A parser
        that matches no rows must not report the two sides as agreeing."
    elif [ -z "$ao_set" ]; then
      fail "could not read wss-append-only.sh's hardcoded log-set fallback, so
        the contract is compared against nothing. If the fallback was renamed or
        removed, update this check with it."
    elif [ "$rc_set" != "$ao_set" ]; then
      fail "wss-append-only.sh's fallback log set and WSS.RECORD-CONTRACT.md's
        Log row disagree:
          contract: $rc_set
          fallback: $ao_set
        A tree whose manifest declares no WSS.recordMode falls back to the
        script's list, so whichever record is missing from it is append-only by
        contract and unguarded in fact."
    else
      pass "the append-only fallback matches the contract's log set ($rc_set)"
    fi
  fi

  # The commit-provenance hooks guard all records, not just logs, so they are
  # gated only on the script existing and CI. No recordMode gate.
  if [ -n "$ao_git" ] && [ -f "$CLAUDE_DIR/wss/scripts/wss-commit-provenance.sh" ] &&
     [ -z "${CI:-}${GITHUB_ACTIONS:-}" ]
  then
    if grep -qF 'wss-commit-provenance-hook' "$ao_git/hooks/prepare-commit-msg" 2>/dev/null &&
       grep -qF 'wss-commit-provenance-hook' "$ao_git/hooks/commit-msg" 2>/dev/null; then
      pass "the commit-provenance hooks are installed in this clone"
    else
      warn "no commit-provenance hooks in this clone, so a record write with a
        missing or altered authority declaration is caught by CI afterwards rather
        than before it is written. The hooks are untracked by design — they live in
        the git dir and name an absolute path on this machine, so nothing is missing
        from the repository and every clone installs its own:
          $CLAUDE_DIR/wss/scripts/wss-commit-provenance.sh --install-hook"
    fi
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
# the resolution rule and the splittable set are wss/workflow/WSS.LANE-CONTRACT.md's.
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
    notice "no WSS.lanes.named — project is unsplit"
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
        wss/workflow/WSS.LANE-CONTRACT.md."
        lane_bad=$((lane_bad + 1))
        continue ;;
      releases)
        fail "WSS.lanes.named.$lname.records.releases — the release list never
        splits. It holds the milestones, their versions and their marks, and
        --wss-release reads it and no other planning record; a per-lane copy
        is a release checkpoint one worktree cut for the whole project. Goals
        split by lane, in roadmap. wss/workflow/WSS.LANE-CONTRACT.md."
        lane_bad=$((lane_bad + 1))
        continue ;;
      *)
        fail "WSS.lanes.named.$lname.records.$key — '$key' is not a splittable
        record. Only todo, openDecisions, handoff and roadmap may split by
        lane: the append-only logs are single timelines, the backlog is one
        pool a person cherry-picks from, releases must be
        singular to stay a release checkpoint, and behaviour and reference
        describe one system. wss/workflow/WSS.LANE-CONTRACT.md."
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
    notice "no transfer queues declared — lanes cannot file work to each other"
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
    notice "no conflict inbox declared — synch derives its own conflicts only"
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
    notice "no .claude/WSS.LANE selector — this checkout reads the unsplit records"
  fi
fi

# ----------------------------------------------------------- handoff budget

head_ "Handoff budget"

# The handoff is the only record loaded WITHOUT being asked for: the SessionStart
# hook injects it, so its cost is paid by every session of every kind of work,
# including the ones that never touch a record. Two budgets, because the file has
# two halves with different readers.
#
# The card — everything up to `<!-- handoff:card-ends -->`, the same cut
# wss-session-check.sh makes — is injected verbatim. The rest is read on demand,
# but the card's trailer instructs every session to read it before writing to any
# record, so it is conditional cost rather than free.
#
# Nothing measured either until now, and it showed: this repo's handoff went
# 1,112 → 1,576 lines in two days with per-commit deletions of 0-2 lines against
# additions of 28-62. wss-audit-assets.sh stops at the marker and so only ever
# saw the card, which was in budget the whole time the file was tripling.
#
# Warnings, not failures, on the description-budget reasoning: a file 200 B over
# is not a defect, and a check that fails a run for it stops being read.
#
# CARD_CAP was 4096 until 2026-08-18, when the card was trimmed to ~1.3 KB —
# values to the setup record, hazard mechanisms to the overflow document —
# and the cap lowered to hold the trim: without that, the freed space
# silently refills, which is what the measured growth above shows it does.
CARD_CAP=1536
FILE_CAP=24576
STATE_ENTRY_CAP=1

handoff_paths=""
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  handoff_paths=$(jq -r '[.WSS.record.handoff // empty]
                          + [(.WSS.lanes.named // {})[] | .records.handoff // empty]
                          | .[]' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
elif [ -f "$PWD/wss/records/WSS.HANDOFF.md" ]; then
  handoff_paths="wss/records/WSS.HANDOFF.md"
fi

if [ -z "$handoff_paths" ]; then
  notice "no handoff declared — nothing to measure"
else
  hf_seen=0; hf_over=0
  while IFS= read -r hp; do
    [ -n "$hp" ] || continue
    [ -f "$PWD/$hp" ] || continue
    hf_seen=$((hf_seen + 1))

    total=$(wc -c <"$PWD/$hp" | tr -d ' ')
    mark=$(grep -n '^<!-- handoff:card-ends -->$' "$PWD/$hp" 2>/dev/null |
           head -1 | cut -d: -f1 || true)

    # No marker means the hook injects the whole file, so the card IS the file
    # and the card budget is the only one that applies. Saying so beats
    # reporting a 30 KB file as "card in budget, body over".
    if [ -z "$mark" ]; then
      if [ "$total" -gt "$CARD_CAP" ]; then
        warn "$hp is ${total}B with no '<!-- handoff:card-ends -->' marker, so ALL
        of it is injected into every session, against the ${CARD_CAP}B card
        budget. Split it: what must be known before touching anything stays
        above the marker, the rest goes below and is read on demand.
        wss/workflow/writers/WSS.HANDOFF-WRITER.md."
        hf_over=$((hf_over + 1))
      else
        pass "$hp is ${total}B, unsplit but within the ${CARD_CAP}B card budget"
      fi
      continue
    fi

    card=$(head -n "$mark" "$PWD/$hp" | wc -c | tr -d ' ')
    if [ "$card" -gt "$CARD_CAP" ]; then
      warn "$hp's card is ${card}B, over the ${CARD_CAP}B budget. This is injected
        into every session. The fix is never a denser state section — it is a
        warning that has been resolved, a paragraph of history that belongs in
        the decision log, or a hazard that has become conditional and belongs
        in the overflow document."
      hf_over=$((hf_over + 1))
    fi

    if [ "$total" -gt "$FILE_CAP" ]; then
      warn "$hp is ${total}B, over the ${FILE_CAP}B whole-file budget (card
        ${card}B, below the marker $((total - card))B). Below-the-marker growth is
        not free: the card tells every session to read the rest before writing
        to any record. wss/workflow/writers/WSS.HANDOFF-WRITER.md's retention table."
      hf_over=$((hf_over + 1))
    fi

    # The journal signature. `## State` is superseded, not appended — one
    # current entry, the previous deleted. A bolded date opening a line below
    # the marker is a dated entry, and more than one of them means the section
    # is being written as a log of sessions rather than as the state.
    #
    # Anchored on the BOLD date rather than any date-shaped string: a state
    # claim may legitimately cite one ("unexercised since 2026-08-02"), and a
    # check that forbade those would push writers to drop the citation, which
    # is the useful part.
    entries=$(awk -v m="$mark" 'NR>m' "$PWD/$hp" |
              grep -cE '^\*\*20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' || true)
    if [ "${entries:-0}" -gt "$STATE_ENTRY_CAP" ]; then
      warn "$hp carries ${entries} dated entries below the marker. The state
        section supersedes rather than appends — the current entry replaces the
        previous one. Before deleting an old entry, route what has no other
        home: a standing hazard to the card or the overflow document, a
        current-state fact into the new entry as the claim alone. Everything
        else is in git, the changelog and the decision log already."
      hf_over=$((hf_over + 1))
    fi
  done <<EOF
$handoff_paths
EOF

  if [ "$hf_seen" -eq 0 ]; then
    notice "no handoff file present — nothing to measure"
  elif [ "$hf_over" -eq 0 ]; then
    pass "every handoff is within budget and holds one dated state entry ($hf_seen file(s))"
  fi
fi


# The setup record is injected whole by wss-session-check.sh — the same
# per-session cost as the handoff card, so the same kind of cap. 2048 B is the
# record's launch size plus margin, because the refill pattern the card showed
# (additions 28-62 per commit against deletions of 0-2) applies to any injected
# surface. Warn rather than fail, for the reasons CARD_CAP warns. No fallback
# path: an undeclared WSS.record.setup means nothing is injected and nothing
# is measured.
SETUP_CAP=2048
setup_paths=""
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  setup_paths=$(jq -r '[.WSS.record.setup // empty]
                        + [(.WSS.lanes.named // {})[] | .records.setup // empty]
                        | .[]' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
fi
if [ -n "$setup_paths" ]; then
  while IFS= read -r spf; do
    [ -n "$spf" ] || continue
    [ -f "$PWD/$spf" ] || continue
    sbytes=$(wc -c <"$PWD/$spf" | tr -d ' ')
    if [ "$sbytes" -gt "$SETUP_CAP" ]; then
      warn "$spf is ${sbytes}B, over the ${SETUP_CAP}B setup budget — it is injected
        whole into every session. The first cut is any row failing the
        admission test in the record's own header: BOTH multi-consumer AND
        wrong-or-expensive to derive."
    else
      pass "$spf is ${sbytes}B, within the ${SETUP_CAP}B setup budget"
    fi
  done <<SETUP_EOF
$setup_paths
SETUP_EOF
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
  roadmap_paths="wss/records/WSS.ROADMAP.md"
fi

if [ -z "$roadmap_paths" ]; then
  notice "no roadmap declared — nothing to check"
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
        wss/workflow/WSS.RECORD-CONTRACT.md."
      roadmap_dirty=$((roadmap_dirty + 1))
    fi
  done <<EOF
$roadmap_paths
EOF
  if [ "$roadmap_seen" -eq 0 ]; then
    notice "no roadmap file present — nothing to check"
  elif [ "$roadmap_dirty" -eq 0 ]; then
    pass "no roadmap carries a version or a completion mark ($roadmap_seen file(s))"
  fi
fi

# ------------------------------------------- rulebook consumer reachability

# A RULE NOBODY CAN REACH IS NOT ENFORCED, AND NOTHING SAID SO.
# `wss-rules-checkup.sh` resolves a CONSUMER to its file set and checks those
# files exist. It never asks the question in the other direction — whether a
# file carrying rules is named by any consumer at all — so a judge file can hold
# rows that no consumer will ever read, and every check in the tree stays green.
#
# THE GAP IS REAL BUT NOT LIVE TODAY: the consumer table names five consumers
# resolving to eight of the fourteen files. `WSS.RULES-HOOK.md` and five of the
# six `prospective/` files are named by none — harmless while they carry no
# rows, which is exactly why this check counts ROWS rather than files. It fires
# the moment the fill writes a row into an unreachable file, which is the moment
# it matters and not before.
#
# WARN-GRADE, and the condition it promotes to fail under: once the fill is
# complete and every judge has a consumer, so an unreachable file is a mistake
# rather than a stage of the build.
#
# THE OTHER FIX WAS REJECTED. Adding a consumer row for the HOOK judge closes
# today's instance and nothing else; this closes the class as the fill adds
# files. Do not do both — a row added to satisfy a check, rather than because a
# consumer needs the file, is the check writing the record it audits.
CR_PY='
import os, re, sys
d = sys.argv[1]
idx = os.path.join(d, "WSS.RULES-INDEX.md")
named, intable = set(), False
try:
    lines = open(idx, encoding="utf-8", errors="replace").read().splitlines()
except OSError:
    sys.exit(0)
for line in lines:
    if line.startswith("## Consumer resolution table"):
        intable = True; continue
    if intable and line.startswith("## "):
        break
    if intable and line.startswith("|"):
        cells = line.split("|")
        if len(cells) > 2:
            for m in re.findall(r"`([^`]+)`", cells[2]):
                if m.endswith(".md"):
                    named.add(m)
ROW = re.compile(r"^### [A-Z]+-[A-Z]+-[0-9]{3}$")
for sub in ("", "prospective"):
    base = os.path.join(d, sub) if sub else d
    if not os.path.isdir(base):
        continue
    for fn in sorted(os.listdir(base)):
        if not fn.endswith(".md"):
            continue
        rel = os.path.join(sub, fn) if sub else fn
        if rel == "WSS.RULES-INDEX.md":
            continue
        fence, rows = False, 0
        for line in open(os.path.join(base, fn), encoding="utf-8", errors="replace").read().splitlines():
            st = line.lstrip()
            if st.startswith("```") or st.startswith("~~~"):
                fence = not fence; continue
            if not fence and ROW.match(line):
                rows += 1
        if rows and rel not in named:
            print("%s\t%d" % (rel, rows))
'

head_ "Rulebook consumer reachability"

CR_DIR="$CLAUDE_DIR/wss/rules"
if [ ! -d "$CR_DIR" ]; then
  notice "no wss/rules/ — this tree carries no rulebook"
elif ! command -v python3 >/dev/null 2>&1; then
  warn "rulebook reachability unverified (needs python3) — a judge file holding
        rules no consumer names passes silently here"
else
  cr_bad=0 cr_files=0
  while IFS=$'\t' read -r cr_f cr_n; do
    [ -n "$cr_f" ] || continue
    cr_bad=$((cr_bad + 1))
    warn "wss/rules/$cr_f holds $cr_n rule(s) and no consumer names it.
        wss-rules-checkup.sh resolves consumers to files and never the reverse,
        so nothing else can see this. Add the file to a consumer's row in
        WSS.RULES-INDEX.md's table, or move the rules to a file a consumer reads."
  done < <(python3 -c "$CR_PY" "$CR_DIR" 2>/dev/null)
  cr_files=$(find "$CR_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$cr_bad" -eq 0 ]; then
    pass "every judge file carrying rules is named by a consumer ($cr_files file(s) walked)"
  fi
fi

# ------------------------------------------- structured regions in registers

# THE REGISTER HALF OF "DECLARE, DON'T INFER". A register is prose over a
# structured body, so structure is REGIONAL rather than whole-file — which is
# why this is a marker in the file and not another `recordMode` key. Freeform is
# the safe default: an unmarked record asserts nothing and is not a finding.
#
# THE MARKER ONLY REQUESTS GOOD BEHAVIOUR; THIS IS WHAT DETECTS THE CORRUPTION.
# That is the owner's own framing of why a marker alone was not the deliverable.
#
# `entry=table-row` IS THE MANIFEST'S EXISTING VOCABULARY, not a new one —
# `WSS.recordMode` already admits `entry: "heading" | "table-row"` and
# `WSS.record.audits` declares `table-row` today. A shape this enum cannot spell
# is a ruling, not an improvisation: no value is invented here.
#
# THE COMMENT FORM IS THE TREE'S OWN. `<!-- handoff:card-ends -->` has been a
# structural marker inside a record since 2026-08-01, read by five consumers.
# This extends that convention rather than starting one.
#
# WARN-GRADE, and the condition it promotes to fail under: once every register
# that has a structured region carries a marker for it, so a missing marker and
# a conforming one stop being indistinguishable.
SR_PY='
import re, sys
OPEN = re.compile(r"^<!--\s*wss:region\s+entry=([a-z-]+)\s*-->\s*$")
CLOSE = re.compile(r"^<!--\s*wss:region-end\s*-->\s*$")
for path in sys.argv[1:]:
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        continue
    shape = None; start = 0; body = []
    for n, line in enumerate(lines, 1):
        m = OPEN.match(line)
        if m:
            if shape:
                print("%s\t%d\tregion opened inside an open region" % (path, n))
            shape, start, body = m.group(1), n, []
            continue
        if CLOSE.match(line):
            if not shape:
                print("%s\t%d\tregion-end with no open region" % (path, n))
                continue
            if shape == "table-row":
                widths = set()
                for bn, bl in body:
                    if not bl.strip():
                        continue
                    if not bl.startswith("|"):
                        print("%s\t%d\tprose inside a table-row region: %s"
                              % (path, bn, bl.strip()[:48]))
                        continue
                    # Count UNESCAPED pipes only. A cell may carry `\|` — the
                    # catalog does, inside code spans describing CLI alternation
                    # — and counting those reports a table of uniform rows as
                    # three different widths.
                    widths.add(bl.replace("\\|", "").count("|"))
                if len(widths) > 1:
                    print("%s\t%d\ttable-row region has rows of %s different widths"
                          % (path, start, len(widths)))
            elif shape == "heading":
                for bn, bl in body:
                    if bl.strip() and not bl.startswith("#"):
                        print("%s\t%d\tnon-heading line in a heading region" % (path, bn))
                        break
            else:
                print("%s\t%d\tunknown entry shape %r — not in the manifest enum"
                      % (path, start, shape))
            shape = None; body = []
            continue
        if shape:
            body.append((n, line))
    if shape:
        print("%s\t%d\tregion opened and never closed" % (path, start))
'

head_ "Structured regions in registers"

if ! command -v python3 >/dev/null 2>&1; then
  warn "structured regions unverified (needs python3) — a corrupted marked
        region passes silently here"
else
  # Every declared record path, strings and array members alike, from the
  # PROJECT manifest — so this check is silent outside a checkout rather than
  # reporting another tree's state as this one's.
  sr_marked=0 sr_bad=0; sr_files=()
  if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
    while IFS= read -r sr_rel; do
      [ -n "$sr_rel" ] && [ -f "$PWD/$sr_rel" ] || continue
      grep -q '^<!-- wss:region ' "$PWD/$sr_rel" 2>/dev/null || continue
      sr_marked=$((sr_marked + 1)); sr_files+=("$PWD/$sr_rel")
    done < <(jq -r '[.WSS.record // {} | .. | strings] | .[]' \
               "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
  fi
  if [ "$sr_marked" -eq 0 ]; then
    notice "no record declares a structured region — freeform is the default and
        asserts nothing"
  else
    while IFS=$'\t' read -r sr_f sr_n sr_why; do
      [ -n "$sr_why" ] || continue
      sr_bad=$((sr_bad + 1))
      warn "${sr_f#"$PWD"/}:$sr_n — $sr_why
        A marked region declares how its body is built; this one no longer
        matches. Fix the body, or move the marker off it."
    done < <(python3 -c "$SR_PY" "${sr_files[@]}" 2>/dev/null)
    [ "$sr_bad" -eq 0 ] && pass "every declared structured region conforms to its shape ($sr_marked record(s) marked)"
  fi
fi

# --------------------------------------------------- duplicate log ordinals

# AN ORDINAL IS POSITIONAL, SO CONCURRENT SESSIONS COMPUTE THE SAME ONE.
# `WSS.record.decisions` entries are cited as `YYYY-MM-DD (ordinal-word)`, and
# the ordinal is assigned by counting that date's existing entries — so two
# sessions appending to a shared checkout both compute the same next ordinal and
# both are right when they compute it. `wss/workflow/WSS.ADDRESSING.md` §3 holds
# the form and the re-read rule; this is the detector that rule needs.
#
# NOTHING ELSE SEES IT. The index regenerates happily with two identical rows,
# `--check` reports it current because the index does match the log, and every
# citation to that ordinal then resolves to whichever row is found first.
#
# WARN-GRADE, and the condition it promotes to fail under: once a duplicate has
# been observed and repaired at least once, so the repair path is known rather
# than theoretical. Repairing one means editing an append-only record, which is
# the owner's call and not a thing to discover mid-fix.
head_ "Decision-log ordinals"

dl_log=""
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  dl_log=$(jq -r '.WSS.record.decisions // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null)
fi
if [ -z "$dl_log" ] || [ ! -f "$PWD/$dl_log" ]; then
  notice "no decision log resolves here — nothing to check for duplicate ordinals"
else
  dl_dupes=0
  while IFS= read -r dl_line; do
    [ -n "$dl_line" ] || continue
    dl_dupes=$((dl_dupes + 1))
    warn "$dl_log carries more than one entry as '$dl_line'.
        An ordinal is positional, so two sessions appending concurrently compute
        the same one; every citation to it now resolves to whichever row is
        found first. Renumber the later entry — appending is the only way that
        record changes, so the repair is the owner's."
  done < <(grep -oE '^## [0-9]{4}-[01][0-9]-[0-3][0-9] \([a-z-]+\)' "$PWD/$dl_log" 2>/dev/null \
             | sed 's/^## //' | sort | uniq -d)
  if [ "$dl_dupes" -eq 0 ]; then
    dl_n=$(grep -cE '^## [0-9]{4}-[01][0-9]-[0-3][0-9] \([a-z-]+\)' "$PWD/$dl_log" 2>/dev/null || echo 0)
    pass "every decision-log ordinal is unique ($dl_n entry heading(s) walked)"
  fi
fi

# ----------------------------------------------------------- deferral pointers

head_ "Deferral pointers"

# .claude/WSS.HAZARDS.md makes the trailing "Deferred (owner)" / "Deferred
# (session)" label THE WHOLE ELIGIBILITY TEST --wss-start Phase 2 applies —
# read as present-tense state, never re-verified against the log entry that
# earned it. That makes the label a CACHE of an attribute the decision log
# owns, and wss/workflow/WSS.RECORD-CONTRACT.md's "A concept is stated once"
# permits exactly three second-copy forms: a pointer, a copy a command
# reproduces, or an entry on that section's own exception list. "Deferred
# (owner) -- see the decision log." is none of the three: it points at the
# WHOLE LOG rather than an entry, so nothing can tell a live ruling from one a
# later entry quietly superseded.
#
# So the rule this derives: a pointer that cites the decision log at all must
# name one entry -- a date plus its ordinal, in the index's own citation form
# (YYYY-MM-DD followed by "(ordinal word)") -- and that citation must resolve
# to a line in WSS.record.decisionsIndex. A pointer that never mentions the
# decision log at all (the Checkpoints section's "needs no gate. Nothing was
# ordered here.") is a different, unrelated shape and is never read here — it
# makes no claim about the log, so there is nothing here to verify it against.
#
# What resolving buys, and what it cannot. A citation that resolves proves the
# entry EXISTS; it cannot prove that entry is still the one deciding this
# pointer's fate, because a LATER entry can supersede an earlier ruling in
# prose the log itself never cross-links. That gap is why this stays a warn:
# a pointer can name a real, resolving, superseded entry and still pass.
#
# The ordinal is REQUIRED, not optional, even though the index leaves a day's
# first entry unlabelled on some days and labels it "(first)" on others.
# Making the ordinal optional reopens a false pass: a bare date substring
# elsewhere in the SAME pointer, unrelated to the citation (an aside naming
# when something else shipped), would then read as a citation and silently
# resolve against that day's first, unrelated entry — the sentence-scoped
# extraction below (only the sentence containing "decision log") closes most
# of that, but a same-sentence bare date would still slip through if the
# ordinal were optional. Requiring the parenthetical costs the rare
# correctly-bare citation, flagged unresolved rather than silently accepted.
#
# THE UNIT IS NOW A `- [ ] ` ENTRY, NOT A BLANK-LINE-DELIMITED BLOB — ruled at
# the gate that closed the joint above. A unit opens on a line matching
# `^- \[ \] ` and closes on the next such line or the next `^## ` heading;
# text before a file's first `- [ ] ` line opens no unit at all. This is the
# backlog's own shape (`wss/records/WSS.TODO.md`'s every entry opens
# `- [ ] **` at column 0), hard-coded on purpose — the risk taken at the gate
# that ruled it, and GENERALITY below is its mitigation.
#
# THE CAPTURE NOW RE-ARMS PER MARKER, WHICH IS WHAT CLOSES THE SWALLOW AT ITS
# ROOT. Every non-backtick-quoted `Parked (owner ruled|session judgment)` line
# — and every one in the superseded `Deferred (owner|session)` spelling, which an
# unmigrated adopter still carries — wherever
# it falls — closes whatever span was open and opens a new one of its own; a
# span runs to the next such marker, the next unit boundary, or EOF. A
# standing register can hold several markers with no blank line between them
# and every one still gets its own span and its own "decision log" sentence,
# checked independently — the blank line the old joint needed is no longer
# load-bearing anywhere this runs.
#
# "ITS OWN" DECISION-LOG SENTENCE MEANS FROM THIS MARKER TO THE NEXT — the
# first sentence containing "decision log" within THIS marker's span only,
# never a neighbour's citation. That is what stops one marker's resolution
# covering an unrelated one, which a whole-unit search would not.
#
# THE ONE SHAPE RE-ARMING DOES NOT SPLIT is two markers sharing one physical
# line: the strip that isolates a marker's own text keeps only the last, so
# an earlier one on the same line would be lost rather than checked. That
# case is still named, with its count, and the all-clear still withheld —
# the residual of the multi-marker warn this replaces, narrower now because
# re-arming closed the common case outright. It does not occur anywhere in
# this repo's own backlog today; re-derive with
# `grep -cE 'Parked \((owner ruled|session judgment)\).*Parked \(' <record>`
# rather than trusting that claim.
#
# GENERALITY: dp_todo can name any record, not only a `- [ ] ` checklist. A
# record with no `- [ ] ` line anywhere opens no unit at all, so every
# Deferred marker in it stays ORPHANED — outside any unit, from line 1 to
# EOF — and each is warned about individually rather than passing silently;
# the all-clear is withheld exactly as it is for a collision. This is the
# mitigation for hard-coding the backlog's shape into a check that also reads
# other records (`WSS.record.todo` and every named lane's `records.todo`,
# `wss-doctor.sh:3074-3076`): an unrecognised shape reports LOUD, never a
# false OK.
#
# TWO FURTHER LIMITS STAND, both the anchor rule working as intended rather
# than this joint: a backtick-quoted marker opens no span and so is never
# checked, and a sub-entry carrying no "decision log" sentence has nothing
# here to verify it against.
dp_todo=""; dp_idx=""
if [ -f "$PWD/.claude/WSS.WORKFLOW.json" ]; then
  dp_todo=$(jq -r '[.WSS.record.todo // empty]
                    + [(.WSS.lanes.named // {})[] | .records.todo // empty]
                    | .[]' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
  dp_idx=$(jq -r '.WSS.record.decisionsIndex // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null)
else
  [ -f "$PWD/wss/records/WSS.TODO.md" ] && dp_todo="wss/records/WSS.TODO.md"
fi
[ -n "$dp_idx" ] || dp_idx="wss/generated/WSS.DECISIONS-INDEX.md"

if [ -z "$dp_todo" ]; then
  notice "no WSS.record.todo declared — nothing to check"
elif [ ! -f "$PWD/$dp_idx" ]; then
  warn "$dp_idx does not exist — every deferral pointer below was read against
        nothing, which is not the same as every pointer resolving"
else
  dp_bad=0; dp_seen=0; dp_scoped=0; dp_total=0; dp_unscoped=0; dp_collide=0
  while IFS= read -r dtp; do
    [ -n "$dtp" ] || continue
    [ -f "$PWD/$dtp" ] || continue
    dp_seen=$((dp_seen + 1))
    while IFS=$'\t' read -r dp_line dp_kind dp_text; do
      [ -n "$dp_text" ] || continue
      dp_total=$((dp_total + 1))
      if [ "$dp_kind" = "collision" ]; then
        # Two or more markers share one physical line. The strip that isolates
        # a marker's own text keeps only the last, so an earlier one on the
        # same line is lost the instant it is read, not absorbed as prose —
        # the residual of the old swallow warning, narrower now that re-arming
        # closes the common blank-line-free case on its own.
        warn "$dtp:$dp_line holds $dp_text 'Deferred' markers on one line —
        only the last is ever isolated from it; put each marker on its own
        line so every one gets its own span."
        dp_collide=$((dp_collide + 1))
        continue
      fi
      if [ "$dp_kind" = "orphan" ]; then
        warn "$dtp:$dp_line has a 'Deferred' marker outside any '- [ ] ' entry —
        this record is not boundary-scoped the way the backlog is, so nothing
        here can tell this marker's own citation from a neighbour's. Wrap it in
        a '- [ ] ' entry, or extend this check for the record's real shape."
        dp_unscoped=$((dp_unscoped + 1))
        continue
      fi
      case $dp_text in
        *"decision log"*) ;;
        *) continue ;;   # a checkpoint's "needs no gate" makes no claim to verify
      esac
      dp_scoped=$((dp_scoped + 1))
      dp_sentence=$(printf '%s' "$dp_text" | grep -oiE 'decision log[^.]*\.' | head -1)
      dp_cite=$(printf '%s' "$dp_sentence" |
                grep -oE '20[0-9]{2}-[01][0-9]-[0-3][0-9] \([a-z][a-z -]*\)' | head -1)
      if [ -z "$dp_cite" ]; then
        warn "$dtp:$dp_line names no resolvable decision-log entry — it points at
        the log as a whole rather than a dated, ordinalled entry, so nothing
        distinguishes a live ruling from one a later entry superseded.
        wss/workflow/WSS.RECORD-CONTRACT.md, 'A concept is stated once'."
        dp_bad=$((dp_bad + 1))
      elif ! grep -qF -- "— $dp_cite — " "$PWD/$dp_idx"; then
        warn "$dtp:$dp_line cites '$dp_cite', which $dp_idx carries no row for —
        the entry was renamed, renumbered, or never existed under that form"
        dp_bad=$((dp_bad + 1))
      fi
    done < <(awk '
      function flush(   ) {
        if (mopen) { print mstart "\t" (capturing ? "unit" : "orphan") "\t" mblob }
        mopen = 0; mblob = ""
      }
      {
        line = $0
        if (line ~ /^- \[ \] /) { flush(); capturing = 1 }
        else if (line ~ /^## /) { flush(); capturing = 0 }
        if (line ~ /(Deferred \((owner|session)\)|Parked \((owner ruled|session judgment)\))/ \
            && line !~ /`(Deferred|Parked)/) {
          flush()
          traw = line
          n = gsub(/(Deferred \((owner|session)\)|Parked \((owner ruled|session judgment)\))/, "&", traw)
          if (n > 1) { print FNR "\tcollision\t" n; next }
          mopen = 1; mstart = FNR
          t = line
          if (t ~ /Parked \((owner ruled|session judgment)\)/) sub(/^.*Parked \(/, "Parked (", t)
          else                                                    sub(/^.*Deferred \(/, "Deferred (", t)
          mblob = t
        } else if (mopen) {
          t = line; gsub(/^[[:space:]]+/, "", t)
          mblob = mblob " " t
        }
      }
      END { flush() }
    ' "$PWD/$dtp")
  done <<EOF
$dp_todo
EOF
  if [ "$dp_seen" -eq 0 ]; then
    pass "WSS.record.todo names no file that exists — nothing to check"
  elif [ "$dp_total" -eq 0 ]; then
    notice "no 'Parked (owner ruled)'/'Parked (session judgment)' pointer found,
        and none in the superseded 'Deferred (owner|session)' spelling — nothing to check"
  elif [ "$dp_unscoped" -gt 0 ] || [ "$dp_collide" -gt 0 ]; then
    : # the warning above already said it; a pass line here would contradict it
  elif [ "$dp_scoped" -eq 0 ]; then
    pass "no deferral pointer claims a decision-log entry to verify ($dp_total checkpoint-only)"
  elif [ "$dp_bad" -eq 0 ]; then
    pass "every deferral pointer citing the decision log names an entry that resolves ($dp_scoped checked, each against its own '- [ ] ' entry)"
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
  notice "no WSS.BUG-REPORTS.md — nothing filed from another project"
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
        wss/workflow/providers/ holds the ones that exist. A declared provider is
        never a silent fallback to a file — --wss-todo would write nowhere."
else
  prov_repo=$(jq -r '.WSS.record.todo.repo // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
  prov_label=$(jq -r '.WSS.record.todo.label // empty' "$PWD/.claude/WSS.WORKFLOW.json" 2>/dev/null || true)
  if [ -z "$prov_repo" ]; then
    fail "WSS.record.todo declares github-issues but no 'repo'. It is required —
        wss/workflow/providers/WSS.GITHUB-ISSUES.md."
  elif ! command -v gh >/dev/null 2>&1; then
    warn "WSS.record.todo is github-issues but gh is not installed, so \`--wss-todo\` cannot
        file anything on this machine. The manifest is fine; this box is not."
  elif ! gh auth status >/dev/null 2>&1; then
    warn "WSS.record.todo is github-issues and gh is not authorized here, so \`--wss-todo\`
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

# The cache that lets --wss-check, --wss-docs and --wss-tidy re-read only what moved. It is
# the one file here whose being WRONG is silent by construction: a bad baseline
# or a covered glob nobody earned produces a clean report on files nothing read,
# and every incremental sweep after it inherits that. Shape and rules:
# ~/.claude/wss/workflow/WSS.SWEEP-CHECKPOINT.md
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
  notice "no sweep checkpoint — every sweep runs in full"
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

# ------------------------------------------------------------- chain budgets

head_ "Chain budgets"

# A1 (WSS.TODO.md's Annex A; WSS.ROADMAP.md's "Make the cost visible before it
# grows"): walk each SKILL.md's mandated-read citations, sum the same-window
# chain, warn over a per-tier budget — and warn loudly if the walk finds no
# citations at all, because that is what citation-format drift looks like: a
# check that keeps passing while measuring nothing.
#
# CITATION FORM: a markdown link to a .md file — `[`Text`](path.md#anchor)`
# (the dominant shape in skills/*/SKILL.md) or the same without backticks
# (README.md-style). One regex covers both, and nothing else was found: every
# [text](target.md) across the tree at design time matched one of the two.
#
# WHAT COUNTS AS THE UNCONDITIONAL SAME-WINDOW CHAIN, per WSS.AUDIT-PASS.md's
# convention:
#   - the SKILL.md's own bytes;
#   - every direct citation into wss/workflow/, wss/tests/,
#     wss/workflow/writers/ or wss/workflow/providers/ — contracts and procedures a
#     dispatch runs inline, in the caller's own context (WSS.GIT-WRITER.md:
#     "a dispatched skill runs in the caller's own context"), not a subagent
#     boundary;
#   - ONE further level, ONLY through wss/workflow/writers/*.md targets — a
#     writer's own unconditional references, the one transitivity case
#     WSS.AUDIT-PASS.md names by name and pass 14 (F2) measured by hand for
#     WSS.DOCS-WRITER.md. Nothing recurses past that second level: a contract
#     citing a contract is a cross-reference for a reader, not a second
#     mandated read, and closing that transitively pulled in the whole
#     wss/workflow/ tree for every skill when tried.
# EXCLUDED FROM THE SUM, and counted separately as citations found:
#   - a citation into the citing skill's own references/ directory: gated by
#     convention (this file's lens 6 — mode, lane, provider gates), so not
#     unconditional. Known imprecision: a gate table can mark one reference
#     "always, in practice" (docs's WSS.GUIDELINES.md row) and this walk
#     cannot read that verdict, so it excludes that file like any other and
#     undercounts docs by it.
#   - a citation into another skill's SKILL.md or into agents/: a dispatch
#     target that may run in a fresh subagent context. This walk cannot tell
#     a same-context dispatch from a subagent one by regex, so it excludes
#     every cross-skill citation rather than guess.
#   - anything else that resolves outside wss/workflow/ (README.md and similar
#     top-level docs): not a contract.
# KNOWN OVERCOUNT, the opposite direction: a citation sitting inside a prose
# mode-branch this walk cannot parse (e.g. "on full adoption, also read X")
# is still summed as unconditional — references/ is the only gate this walk
# recognises. So a skill's number is closer to a CEILING (every described
# branch summed as if all were taken) than the single heaviest-mode figure an
# audit pass hand-picks; the two are expected to disagree, and warning on the
# wider number is the safer direction for a mechanical check to err in.
#
# TIER: primitive/orchestrator is read from WSS.OWNERSHIP.md's own Tier
# column — structurally, not copied into a second list here, which would be
# exactly the drift-prone copy WSS.TOKEN-ECONOMY.md's lens 11 forbids. An
# orchestrator-tier skill further splits into "runner" or "orchestrator"
# budget by whether its SKILL.md names fanning out to parallel agents; every
# orchestrator that does not is "runner". Budget KB figures live in
# wss/tests/WSS.TOKEN-ECONOMY.md's "Chain budget figures" table and are
# read from there, never hardcoded here.

ch_ownership="$CLAUDE_DIR/wss/workflow/WSS.OWNERSHIP.md"
ch_te="$CLAUDE_DIR/wss/tests/WSS.TOKEN-ECONOMY.md"

ch_budget_of_() { # tier-name -> its KB figure from the contract table, empty if absent
  [ -f "$ch_te" ] || return 0
  awk -F'|' -v t="$1" '
    { g = $2; gsub(/^[ \t]+|[ \t]+$/, "", g) }
    g == t { b = $3; gsub(/[^0-9]/, "", b); print b; exit }
  ' "$ch_te"
}
ch_b_primitive=$(ch_budget_of_ primitive)
ch_b_runner=$(ch_budget_of_ runner)
ch_b_orchestrator=$(ch_budget_of_ orchestrator)

if [ ! -f "$ch_ownership" ] || [ ! -f "$ch_te" ] ||
   [ -z "$ch_b_primitive" ] || [ -z "$ch_b_runner" ] || [ -z "$ch_b_orchestrator" ]; then
  notice "chain-budget figures did not resolve from wss/tests/WSS.TOKEN-ECONOMY.md's
        'Chain budget figures' table, or wss/workflow/WSS.OWNERSHIP.md is missing. The
        walk below still runs and reports each skill's chain, with nothing to
        compare it against."
fi

ch_tier_map=$(awk -F'|' '
  /^\| [a-z]/ {
    skill = $4; tier = $5
    gsub(/^[ \t]+|[ \t]+$/, "", skill); gsub(/^[ \t]+|[ \t]+$/, "", tier)
    n = match(skill, /wss-[a-z-]+/)
    if (n) {
      slug = substr(skill, RSTART, RLENGTH)
      if (tier == "primitive" || tier == "orchestrator") print slug " " tier
    }
  }' "$ch_ownership" 2>/dev/null | sort -u)

ch_tier_of_() { printf '%s\n' "$ch_tier_map" | awk -v s="$1" '$1 == s { print $2; exit }'; }

ch_citations_in_() { # file — one resolved absolute path per mandated-read citation, fences excluded
  cf="$1"
  [ -f "$cf" ] || return 0
  cd_=$(dirname "$cf")
  awk '/^[[:space:]]*(```|~~~)/ { fence = !fence; next } fence { next } { print }' "$cf" |
  grep -oE '\[[^]]*\]\([^)]+\.md[^)]*\)' |
  sed -E 's/^\[[^]]*\]\(([^)]+)\)$/\1/; s/[#?].*$//' |
  while IFS= read -r cr_; do
    [ -n "$cr_" ] || continue
    case "$cr_" in http*|/*) continue ;; esac  # external, or site-root-relative — not a filesystem read
    realpath -m "$cd_/$cr_" 2>/dev/null
  done
}

ch_classify_() { # resolved-path citing-skill-dir
  case "$1" in
    # WSS.AUDIT-PASS.md's convention excludes "row-scoped authority lookups
    # ... reading one row of the ownership matrix is not reading the file",
    # and WSS.OWNERSHIP.md IS that matrix — cited near-universally across
    # skills/*/SKILL.md as "who may write what is WSS.OWNERSHIP.md", a
    # pointer to one row, not a mandate to read all ~31 KB of it. No other
    # file is given this treatment: the convention names this one file, and
    # widening the exclusion to every big reference table (WSS.MANIFEST.md is
    # a plausible second candidate) would be a guess this walk does not make.
    "$CLAUDE_DIR"/wss/workflow/WSS.OWNERSHIP.md) echo authority ;;
    "$CLAUDE_DIR"/wss/workflow/writers/*.md) echo writer ;;
    "$CLAUDE_DIR"/wss/tests/*.md|"$CLAUDE_DIR"/wss/workflow/providers/*.md|"$CLAUDE_DIR"/wss/workflow/*.md)
      echo contract ;;
    "$2"/references/*.md) echo reference ;;
    */SKILL.md|"$CLAUDE_DIR"/agents/*.md|"$PWD"/.claude/agents/*.md) echo dispatch ;;
    *) echo other ;;
  esac
}

# THE BYTE-SUM MOVED. wss-tools-inventory.sh (this installation's own root —
# never a hardcoded path, so a fixture carrying its own copy is measured by
# that exact unedited script) now owns the walk that resolves each SKILL.md's
# citations and sums the same-window chain, and writes it to
# `.claude/WSS.TOOLS.json` as `chainBytes`. This check kept doing that walk
# itself until the JSON existed to read instead — computing the same sum
# twice is exactly the drift WSS.TOKEN-ECONOMY.md's lens 11 forbids, so the
# loop below reads chainBytes rather than recomputing it.
#
# WHAT STAYS HERE: the budget figures and the tier->budget split (judgement,
# read above), and the CITATION COUNT below — the self-test guard against
# citation-format drift needs a per-skill and grand total that the JSON's
# fixed four-field contract (name, path, tier, chainBytes) has no room for,
# and this script may not add one. So `ch_citations_in_`/`ch_classify_` stay
# in use here, narrowed to counting: neither sums a byte any more.
#
# STALENESS IS CHECKED, NOT TRUSTED: before any chainBytes is read, this
# installation's own inventory script is asked to verify itself with
# `--check` — regenerate to a temp, diff against the committed JSON, fail
# loud on any difference. That is invocation layer 1 (the pattern
# WSS.commands.indexCheck already uses for docs/WSS.DECISIONS-INDEX.md); this
# doctor run is layer 2, reading a JSON layer 1 just proved current.
ch_tools_inv="$CLAUDE_DIR/wss/scripts/wss-tools-inventory.sh"
ch_tools_json="$CLAUDE_DIR/.claude/WSS.TOOLS.json"
ch_inv_ok=0
if [ -f "$ch_tools_inv" ]; then
  if ch_inv_msg=$(bash "$ch_tools_inv" --check 2>&1); then
    ch_inv_ok=1
  else
    fail "the tools inventory is stale or missing: $ch_inv_msg
        This check reads each skill's measured chain size from
        .claude/WSS.TOOLS.json instead of recomputing it, so a stale JSON
        here means every KB figure below would be untrustworthy — regenerate
        with \`bash wss/scripts/wss-tools-inventory.sh\` and re-run."
  fi
fi
# No branch fires when $ch_tools_inv is simply absent (an older or foreign
# tree that predates this): every skill below then falls through to the
# per-skill "not measured" notice rather than a blanket claim up front, so a
# tree with nothing chain-budgeted (no ownership-tier row matches at all)
# stays silent about a script it never needed.

ch_chainbytes_of_() { # skill-name -> chainBytes from the tools inventory JSON, empty if unusable
  [ "$ch_inv_ok" -eq 1 ] || return 0
  jq -r --arg n "$1" '(.entries[] | select(.name == $n) | .chainBytes) // empty' \
    "$ch_tools_json" 2>/dev/null
}

ch_grand_found=0
ch_over=0
ch_checked=0
ch_over_lines=""
for ch_f in "$PWD"/.claude/skills/*/SKILL.md "$CLAUDE_DIR"/skills/*/SKILL.md; do
  [ -f "$ch_f" ] || continue
  ch_skilldir=$(dirname "$ch_f")
  ch_name=$(basename "$ch_skilldir")
  ch_owntier=$(ch_tier_of_ "$ch_name")
  if [ -z "$ch_owntier" ]; then
    notice "no ownership-tier row for '$ch_name' in WSS.OWNERSHIP.md's matrix —
        its chain is not budget-checked"
    continue
  fi

  if [ "$ch_owntier" = orchestrator ]; then
    if grep -qiE 'in parallel|fan-out|fans out|fan out' "$ch_f"; then
      ch_budgettier=orchestrator; ch_budget_kb=$ch_b_orchestrator
    else
      ch_budgettier=runner; ch_budget_kb=$ch_b_runner
    fi
  else
    ch_budgettier=primitive; ch_budget_kb=$ch_b_primitive
  fi

  ch_found=0
  ch_seen="$ch_f
"
  ch_writers=""
  while IFS= read -r ch_cite; do
    [ -n "$ch_cite" ] || continue
    ch_found=$((ch_found + 1)); ch_grand_found=$((ch_grand_found + 1))
    ch_cls=$(ch_classify_ "$ch_cite" "$ch_skilldir")
    case "$ch_cls" in
      contract|writer)
        printf '%s' "$ch_seen" | grep -qxF "$ch_cite" && continue
        ch_seen="$ch_seen$ch_cite
"
        [ "$ch_cls" = writer ] && ch_writers="$ch_writers$ch_cite
" ;;
    esac
  done < <(ch_citations_in_ "$ch_f")

  while IFS= read -r ch_w; do
    [ -n "$ch_w" ] || continue
    while IFS= read -r ch_cite; do
      [ -n "$ch_cite" ] || continue
      ch_found=$((ch_found + 1)); ch_grand_found=$((ch_grand_found + 1))
      ch_cls=$(ch_classify_ "$ch_cite" "$ch_skilldir")
      case "$ch_cls" in
        contract|writer)
          printf '%s' "$ch_seen" | grep -qxF "$ch_cite" && continue
          ch_seen="$ch_seen$ch_cite
" ;;
      esac
    done < <(ch_citations_in_ "$ch_w")
  done <<< "$ch_writers"

  # The chain size itself: for a suite skill, read from this installation's
  # own persisted inventory (checked fresh above). A skill under
  # $PWD/.claude/skills/ is a project-local one that JSON structurally cannot
  # cover — wss-tools-inventory.sh inventories one tree per run — so it is
  # measured on the spot instead, with --root pointed at $PWD/.claude.
  # Everything that skill cites into wss/workflow/, wss/workflow/writers/ etc. is
  # still classified against $CLAUDE_DIR (the script's own SUITE_ROOT,
  # unmoved by --root): a project rarely carries its own wss/workflow/, so its
  # contracts are the suite's. --root never writes a file, so there is no
  # staleness question here the way there is for $ch_tools_json above — the
  # figure below is always freshly computed.
  case "$ch_f" in
    "$CLAUDE_DIR"/skills/*)
      ch_bytes=$(ch_chainbytes_of_ "$ch_name")
      if [ -z "$ch_bytes" ]; then
        notice "'$ch_name': no chainBytes for it in .claude/WSS.TOOLS.json —
        the tools inventory did not measure it, or is unavailable here; its
        chain is not budget-checked this run"
        continue
      fi
      ;;
    *)
      if [ ! -f "$ch_tools_inv" ]; then
        notice "'$ch_name': a project-local skill under \$PWD/.claude/skills/ —
        $ch_tools_inv is missing, so its chain is not budget-checked this run"
        continue
      fi
      ch_pl_err=$(mktemp)
      if ! ch_pl_json=$(bash "$ch_tools_inv" --root "$PWD/.claude" 2>"$ch_pl_err"); then
        fail "'$ch_name': \`wss-tools-inventory.sh --root \"\$PWD/.claude\"\`
        failed rather than measuring it: $(cat "$ch_pl_err")"
        rm -f "$ch_pl_err"
        continue
      fi
      rm -f "$ch_pl_err"
      ch_bytes=$(printf '%s' "$ch_pl_json" | jq -r --arg n "$ch_name" \
        '(.entries[] | select(.name == $n) | .chainBytes) // empty' 2>/dev/null)
      if [ -z "$ch_bytes" ]; then
        notice "'$ch_name': a project-local skill under \$PWD/.claude/skills/ —
        wss-tools-inventory.sh --root \"\$PWD/.claude\" ran but reported no
        chainBytes for it; its chain is not budget-checked this run"
        continue
      fi
      ;;
  esac

  ch_checked=$((ch_checked + 1))
  ch_kb=$(( (ch_bytes + 1023) / 1024 ))
  if [ -n "${ch_budget_kb:-}" ] && [ "$ch_kb" -gt "$ch_budget_kb" ]; then
    ch_over=$((ch_over + 1))
    ch_over_lines="${ch_over_lines}  $ch_name: same-window chain ~${ch_kb} KB exceeds its $ch_budgettier budget (${ch_budget_kb} KB) — $ch_found mandated-read citation(s) walked
"
  fi
done

if [ $ch_checked -eq 0 ]; then
  notice "no skills to chain-budget"
elif [ $ch_grand_found -eq 0 ]; then
  warn "the chain walk found ZERO mandated-read citations across $ch_checked
        skill(s). That is the check's own self-test failing, not a clean tree:
        either every SKILL.md stopped citing a contract, or the citation regex
        no longer matches how citations are written — citation-format drift
        silently shrinking the walk to nothing, which is exactly the failure
        this check exists to catch."
elif [ $ch_over -eq 0 ]; then
  pass "every skill's same-window chain fits its tier's budget ($ch_checked checked, $ch_grand_found citation(s) walked)"
else
  # One notice, not one per skill: 19 near-identical four-line notices (one
  # per over-budget skill, each repeating the same trailing sentence) took
  # this check from 1 notice to 20 and made a check nobody reads. The walk,
  # the budget figures and the tier derivation above are unchanged — this
  # only compacts how the same findings are reported. notice(), not warn():
  # A1 (see this script's header comment) specifies the tree being over
  # budget must warn, never fail a --strict run.
  notice "$ch_over of $ch_checked skill(s) exceed their tier's chain budget ($ch_grand_found citation(s) walked total):
$ch_over_lines        Not a failure: this check reports the cost; WSS.TOKEN-ECONOMY.md's
        lens 9 decides whether, and how, to act on it."
fi

# ------------------------------------------ catalog rows vs the tools inventory

head_ "Catalog rows vs tools inventory"

# .claude/WSS.TOOLS.json became WSS.record.tooling.inventory specifically so a
# check could assert the catalog and the inventory agree — every JSON entry
# has a catalog row, and every catalog row a JSON entry. Both are addressable
# by manifest key now, which is what made this expressible. It was not built
# when the inventory was invented because the catalog was being rewritten in
# the same batch, and a check written against the pre-rewrite catalog would
# have failed on landing; that rewrite landed in the same batch's Phase 6, so
# the obstacle is gone.
#
# The inventory measures nine kinds; the catalog is a clean index of only two
# of them. "check" and "command" each already have their own cross-table
# check elsewhere in this script (the check-method tables above, and the
# wrapper-vs-flag comparison). "contract" and "reference" are cited inline in
# prose, never enumerated as catalog rows, so there is no table to compare
# against. "writer" is a table too (the record procedures list) but its rows
# read `audit-writer` while the inventory names the file
# (`WSS.AUDIT-WRITER.md`) and folds one contract doc into the same kind
# (`WSS.WRITERS.md`) — no identity match without a name-mangling rule this
# check would then have to own and keep in step, so writer stays out.
#
# That leaves "skill" and "agent": one table apiece, whose first column is
# exactly the inventory's `name`, with no known exception — confirmed by
# diffing both tables against `jq` output while writing this check, not
# assumed. Those are what the first comparison below runs.
#
# "script" is a table too (Scripts), and — unlike writer — IS checked, in a
# second comparison below, matched on `path` rather than `name`: the table's
# backtick text is the repo-relative path for anything outside the root
# (`hooks/wss-alert.sh`, `wss/workflow/writers/assets/wss-git-commit.sh`), which
# is exactly the inventory's `path` field, while `name` alone is the bare
# basename and would collide or mismatch on every nested one. The catalog
# folds "hook" into the same Scripts table rather than giving it a table of
# its own, so the comparison reads both kinds from the JSON side. Four rows
# the inventory's globs structurally cannot reach stay excluded by name:
# `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` and the two
# `.github/workflows/*.yml` files sit outside wss-tools-inventory.sh's
# `$ROOT/wss-*.sh`, `$ROOT/wss/scripts/wss-*.sh`, `skills/*/assets/*`, `wss/workflow/writers/assets/*`,
# `wss/tests/*.sh` and `hooks/*` globs — a same-name comparison there would report
# four permanent false positives that name real, deliberate catalog rows.
# Confirmed empty beyond those four by diffing both sides with `jq` while
# writing this check (2026-08-13), the same way the skill/agent side was.
civ_cat="$CLAUDE_DIR/.claude/WSS.TOOLING.md"
civ_rows_() { # file, exact section-heading line -> bare names in that table's first column, until the next "## " heading
  awk -v start="$2" '
    index($0,start)==1 { f=1; next }
    f && /^## / { exit }
    f && /^\|/ {
      n = split($0, c, "|")
      if (n >= 2) {
        v = c[2]
        if (match(v, /`[^`]+`/)) print substr(v, RSTART + 1, RLENGTH - 2)
      }
      next
    }
  ' "$1"
}
if [ "$ch_inv_ok" -ne 1 ]; then
  notice "catalog-vs-inventory row check skipped — the tools inventory guard
      earlier in this run already reported why .claude/WSS.TOOLS.json cannot
      be trusted this run"
elif [ ! -f "$civ_cat" ]; then
  fail "catalog file .claude/WSS.TOOLING.md is missing — cannot compare its
      rows against the tools inventory"
else
  civ_cat_names=$( { civ_rows_ "$civ_cat" "## Global skills"
                      civ_rows_ "$civ_cat" "## Agents"
                      civ_rows_ "$civ_cat" "## Skills scoped to this repo"
                    } | sort -u)
  civ_json_names=$(jq -r '.entries[] | select(.kind=="skill" or .kind=="agent") | .name' "$ch_tools_json" | sort -u)
  if [ -z "$civ_cat_names" ] || [ -z "$civ_json_names" ]; then
    civ_blind=""
    [ -z "$civ_cat_names" ] && civ_blind=".claude/WSS.TOOLING.md's Global skills/Agents tables"
    [ -z "$civ_json_names" ] && civ_blind="${civ_blind:+$civ_blind and }.claude/WSS.TOOLS.json's skill/agent entries"
    fail "no rows found in $civ_blind — a reader that has gone blind agrees
        with everything, and an empty-vs-empty pass is precisely what this
        comparison exists to rule out"
  elif [ "$civ_cat_names" = "$civ_json_names" ]; then
    pass "every skill and agent has both a catalog row and an inventory entry ($(printf '%s\n' "$civ_cat_names" | grep -c .) checked)"
  else
    civ_cat_only=$(comm -23 <(printf '%s\n' "$civ_cat_names") <(printf '%s\n' "$civ_json_names") | tr '\n' ' ')
    civ_json_only=$(comm -13 <(printf '%s\n' "$civ_cat_names") <(printf '%s\n' "$civ_json_names") | tr '\n' ' ')
    fail "the catalog's skill/agent rows and the tools inventory's skill/agent
        entries disagree.
        Catalog row with no inventory entry: ${civ_cat_only:-none}
        Inventory entry with no catalog row: ${civ_json_only:-none}
        A name on the catalog side only is a stale or misspelled row; a name
        on the inventory side only is a skill or agent that shipped without
        one."
  fi

  # Second comparison, same file, the "script" (+ "hook") half — matched on
  # `path` rather than `name` for the reason in the comment above this block.
  # The four rows the inventory structurally cannot reach are dropped from the
  # catalog side before the diff, so they read as agreement rather than a
  # permanent false positive.
  civ_script_cat_names=$(civ_rows_ "$civ_cat" "## Scripts" | sort -u)
  civ_script_gaps='.claude-plugin/marketplace.json
.claude-plugin/plugin.json
.github/workflows/publish.yml
.github/workflows/verify.yml'
  civ_script_cat_names=$(comm -23 <(printf '%s\n' "$civ_script_cat_names") \
                                   <(printf '%s\n' "$civ_script_gaps" | sort -u))
  civ_script_json_names=$(jq -r '.entries[] | select(.kind=="script" or .kind=="hook") | .path' "$ch_tools_json" | sort -u)
  if [ -z "$civ_script_cat_names" ] || [ -z "$civ_script_json_names" ]; then
    civ_script_blind=""
    [ -z "$civ_script_cat_names" ] && civ_script_blind=".claude/WSS.TOOLING.md's Scripts table (past the four known gaps)"
    [ -z "$civ_script_json_names" ] && civ_script_blind="${civ_script_blind:+$civ_script_blind and }.claude/WSS.TOOLS.json's script/hook entries"
    fail "no rows found in $civ_script_blind — a reader that has gone blind
        agrees with everything, and an empty-vs-empty pass is precisely what
        this comparison exists to rule out"
  elif [ "$civ_script_cat_names" = "$civ_script_json_names" ]; then
    pass "every script and hook has both a catalog row and an inventory entry ($(printf '%s\n' "$civ_script_cat_names" | grep -c .) checked, 4 known-unreachable rows excluded)"
  else
    civ_script_cat_only=$(comm -23 <(printf '%s\n' "$civ_script_cat_names") <(printf '%s\n' "$civ_script_json_names") | tr '\n' ' ')
    civ_script_json_only=$(comm -13 <(printf '%s\n' "$civ_script_cat_names") <(printf '%s\n' "$civ_script_json_names") | tr '\n' ' ')
    fail "the catalog's Scripts rows and the tools inventory's script/hook
        entries disagree.
        Catalog row with no inventory entry: ${civ_script_cat_only:-none}
        Inventory entry with no catalog row: ${civ_script_json_only:-none}
        A path on the catalog side only is a stale or misspelled row (or a
        fifth structural gap — add it beside the four already excluded above
        if the inventory genuinely cannot reach it); a path on the inventory
        side only is a script that shipped without one."
  fi
fi

# ------------------------------------------- dispatch table vs ownership matrix

head_ "Dispatch table vs the ownership matrix"

# skills/check/SKILL.md carries a table mapping "finding lives in" to the
# owner it dispatches to, directly under prose calling WSS.OWNERSHIP.md "the
# table". So the two ARE a copy-set, and WSS.ROT-RESISTANCE.md lens 3 asks what
# makes a second copy agree with the first. Until this check, nothing did:
# whoever edited one remembered the other, which that lens rates as nothing.
#
# Compared on the one identity both sides address the same way — the
# `WSS.record.*` manifest keys. Not on the owner names beside them: the
# dispatch column says `--wss-todo` / `handoff-writer` where the matrix says
# `record` / `writers/WSS.HANDOFF-WRITER.md`, and reconciling those needs a
# name-mangling rule this check would then own and have to keep in step —
# the same reason the catalog check above leaves "writer" out.
#
# BOTH directions fail, because both are real defects:
#   1. A key check dispatches on that the matrix assigns to nobody is a
#      route to a non-owner — the exact failure the copy exists to prevent.
#   2. A key the matrix gives an owner but check has no row for is a
#      record that gained an owner without gaining a dispatch route, so an
#      inspector finding drift there has nowhere to send it.
#
# Three keys are excluded from direction 2 by name, because --wss-check inspects
# none of them and a row for any would be dead: `WSS.record.backlog` and
# `WSS.record.tooling.inventory` appear nowhere in skills/check/SKILL.md.
# `WSS.record.rules` joins them 2026-08-18 — the rulebook ships no rows yet,
# its writer (agents/wss-rules-writer.md) only applies rows already decided
# elsewhere, and nothing today generates the staleness finding a dispatch row
# would receive; add the row once --wss-check (or its Fourth-block successor)
# actually inspects rule content.
# A FOURTH divergence is not excluded and fails, which is the whole point.
dm_chk="$CLAUDE_DIR/skills/check/SKILL.md"
dm_own="$CLAUDE_DIR/wss/workflow/WSS.OWNERSHIP.md"
dm_keys_() { grep -oE 'WSS\.record\.[a-zA-Z]+(\.[a-zA-Z]+)*' | sed 's/\.$//' | sort -u; }
if [ ! -f "$dm_chk" ] || [ ! -f "$dm_own" ]; then
  notice "dispatch-table check skipped — an adopted tree need not carry
      skills/check/SKILL.md or wss/workflow/WSS.OWNERSHIP.md"
else
  # Anchored on each table's header row, never on line numbers: both files are
  # edited often, and a line-numbered slice would silently start reading the
  # wrong rows rather than failing.
  dm_a=$(awk '/^\| Finding lives in \| Dispatch to \|/{f=1;next}
              f && /^\|/{print;next}
              f{exit}' "$dm_chk" | dm_keys_)
  dm_b=$(awk -F'|' '/^\| Verb \| Flag \|/{f=1;next}
                    f && /^\|/{print $6;next}
                    f{exit}' "$dm_own" | dm_keys_)
  dm_only_chk=$(comm -23 <(printf '%s\n' "$dm_a") <(printf '%s\n' "$dm_b") | tr -d ' ')
  dm_only_own=$(comm -13 <(printf '%s\n' "$dm_a") <(printf '%s\n' "$dm_b") \
                | grep -vxE 'WSS\.record\.(backlog|tooling\.inventory|rules)' | tr -d ' ')
  if [ -z "$dm_a" ] || [ -z "$dm_b" ]; then
    fail "the dispatch table or the ownership matrix parsed to no record keys —
        a header row was renamed and this comparison read nothing. Re-anchor
        the awk in this section on the new heading."
  else
    if [ -n "$dm_only_chk" ]; then
      fail "check dispatches on a record the ownership matrix gives no owner:
        $(printf '%s' "$dm_only_chk" | tr '\n' ' ')
        Either add the row to WSS.OWNERSHIP.md's matrix, or drop it from the
        dispatch table in skills/check/SKILL.md."
    fi
    if [ -n "$dm_only_own" ]; then
      fail "the ownership matrix names an owner for a record check cannot
        dispatch on: $(printf '%s' "$dm_only_own" | tr '\n' ' ')
        Add a row to the dispatch table in skills/check/SKILL.md, or — if
        --wss-check genuinely never inspects it — add it to this check's named
        exclusions with the reason."
    fi
    [ -z "$dm_only_chk" ] && [ -z "$dm_only_own" ] &&
      pass "every record key in check's dispatch table has an owner in the
        matrix, and every owned record has a dispatch row ($(printf '%s\n' "$dm_a" | grep -c . ) checked, 3 known-uninspected excluded)"
  fi
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
  notice "no .claude-plugin/plugin.json — not a plugin tree, nothing to trail"
else
  pv=$(jq -r '.version // empty' "$pj" 2>/dev/null || true)
  newest_tag=$(git -C "$CLAUDE_DIR" tag -l 'v*' --sort=-v:refname 2>/dev/null | head -1 || true)
  if [ -z "$newest_tag" ]; then
    notice "no release tag resolves here — nothing for plugin.json's version to trail"
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

# ------------------------------------------------------- newest-tag route

head_ "Newest-tag route"

# ONE ROUTE, BECAUSE THE COMPARISON IS WHAT NOBODY BUILT. This tree has had
# four ways to name its newest tag and nothing checked them against each other.
# `git describe --tags --abbrev=0` walks the CURRENT BRANCH's ancestry, and
# releases are tagged on `main` merge commits `dev` cannot reach, so on `dev` it
# returned a tag three releases back and every range computed from it was wrong
# by that much. `--sort=-creatordate` orders by when a tag was made rather than
# by version, and without a `v*` filter any non-release tag wins outright.
# The route below is the one: it sorts by version and admits only release tags.
#
# THE PROSE SIDE IS NOT THIS CHECK'S. A record telling a session to run
# `git describe` is a claim, and `--wss-check` owns stale claims; this check
# reads executables, where the route is a call rather than an instruction.
#
# WARN-GRADE, and the condition it promotes to fail under: once no tracked
# script has carried a non-canonical route across two consecutive releases.
# Until then a tree mid-migration would go red on a line nobody had reached yet,
# which is what a warn ladder exists to avoid.
#
# THIS SCRIPT AND THE CONTRACT SUITE ARE EXCLUDED BY PATH, both because they
# carry route literals as data rather than as calls — the scan would match its
# own pattern. That exclusion is closed by the explicit self-check below, so
# the scanner's own route is verified rather than trusted.
tag_route_canon="--sort=-v:refname"
if ! git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  notice "not a git checkout — no tracked scripts to read a tag route from"
else
  tr_bad=0 tr_seen=0
  while IFS=: read -r trf trl trtext; do
    [ -n "$trf" ] || continue
    case $trf in wss/tests/wss-doctor.sh|wss/tests/wss-hook-contract.sh) continue ;; esac
    tr_seen=$((tr_seen + 1))
    case $trtext in
      *"$tag_route_canon"*) : ;;
      *) warn "$trf:$trl names the newest tag by a route this tree does not use.
        Sorting by anything but version, or omitting the \`v*\` filter, gives a
        different answer from wss-doctor.sh and wss-probe.sh and nothing
        compares them. Use \`tag -l 'v*' $tag_route_canon | head -1\`."
         tr_bad=$((tr_bad + 1)) ;;
    esac
  done < <(git -C "$CLAUDE_DIR" grep -nE 'git( -C [^ ]+)? tag .*--sort=' -- '*.sh' 2>/dev/null || true)
  # The scanner's own route, checked by name rather than by the scan that
  # cannot see it. `newest_tag=` is assigned exactly once in this file.
  tr_self=$(grep -c "newest_tag=.*tag -l 'v\*' $tag_route_canon" "$0" 2>/dev/null || echo 0)
  if [ "$tr_self" -ne 1 ]; then
    warn "wss-doctor.sh's own newest-tag assignment does not use the canonical
        route, or was renamed away from \`newest_tag=\`. The scan above excludes
        this file by path, so this line is the only thing verifying it."
    tr_bad=$((tr_bad + 1))
  fi
  if [ "$tr_bad" -eq 0 ]; then
    pass "every newest-tag route is \`$tag_route_canon\` ($((tr_seen + 1)) checked, including this script's own)"
  fi
fi

# ------------------------------------------------- figure-source citations

head_ "Figure-source citations"

# wss/workflow/WSS.RECORD-CONTRACT.md's "### A figure carries what recomputes it":
# every number written anywhere carries its source beside it — a citation the
# reader can open, or (preferred, because it survives the number going stale)
# the command that recomputes it. This check is the mechanical half of that
# rule. Its exceptions are NOT re-listed here: the rule's own
# "### The exception list" is the one copy, and this check's messages point at
# it rather than re-deriving it — a verbatim copy that "says so at the copy,
# naming the canon" (exception 2's own words) is read as citing that canon,
# and exception 1 (the handoff's private-identifier count) needs no special
# case because the rule is that it is never written down, so there is nothing
# here for a figure to be missing beside.
#
# SCOPE: "over the records and docs", not the whole tree. Tracked markdown,
# minus three classes that are out of scope for reasons stated where each is
# checked elsewhere rather than repeated here: `skills/`, `agents/` and
# `commands/` carry their own description-budget check above; `wss/logs/audits/*.md`
# IS "an audit pass" by construction — the rule's own second citation form —
# so every figure inside one is already cited by the file it lives in, not by
# what surrounds it; and any WSS.record.* entry WSS.recordMode tags `log` or
# `generated` is a dated log entry or a derived artifact, the rule's other
# citation form or out of scope entirely — resolved from the manifest, the
# same way wss-append-only.sh resolves what it guards, rather than a second
# hand-kept list.
#
# THE FIGURE PATTERN is deliberately narrow: a comma-grouped integer
# (`11,839`) or a bare number carrying a byte/size unit (`27,180 B`, `8 KB`).
# That is every example the rule and WSS.TODO.md's own modelling of it use —
# scanning every bare integer would also catch heading numbers, dates and
# versions, which are not the figures this rule is about.
#
# THE WINDOW is the matched line plus two lines either side, joined, checked
# for: a `recompute`/"rather than trusting" phrase (the rule's own idiom,
# confirmed live at WSS.TODO.md's three modelled instances — grep it for
# `recompute` and `rather than trusting`), a dated entry (`2026-08-13`-shaped),
# "audit pass", "canon" (exception 2's word), or a backtick span shaped like a
# `file:line` citation or a runnable command (one with a space inside). A
# number with none of those nearby is flagged.
#
# A FAILURE. Staged as a warning on the owner's ruling of 2026-08-13, because
# the records and docs this scans were not clean then and a failing gate would
# have turned CI red the day it landed. The promotion condition was written
# here rather than left to judgement: "once a run of this section reports zero
# findings". A run against eb824fb reported zero on 2026-08-17, so the
# condition was met and this now confirms a clean state rather than announcing
# a known one. Nothing watched for that condition arriving; a §0A triage found
# it, which is the argument for a currency enforcer rather than a comment.
if ! command -v jq >/dev/null 2>&1 || [ ! -f "$manifest" ]; then
  notice "no manifest to resolve which records are dated logs — the
      figure-source check needs WSS.recordMode to know what to skip, so it
      did not run this pass"
elif ! git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
  notice "not a git checkout — the figure-source check walks tracked
      markdown and has nothing to walk"
else
  fig_skip=$(jq -r '
      (.WSS.recordMode // {}) as $modes
      | [ (.WSS.record // {} | to_entries[]
            | select(.key != "tooling")
            | {k: .key, v: .value}),
          (.WSS.record.tooling // {} | to_entries[]
            | {k: ("tooling." + .key), v: .value}) ]
      | .[]
      | select(($modes[.k] // "") == "log" or ($modes[.k] // "") == "generated")
      | .v
      | if type == "array" then .[] else . end
    ' "$manifest" 2>/dev/null | sort -u)
  if [ -n "$fig_skip" ]; then
    fig_files=$(git -C "$PWD" ls-files '*.md' 2>/dev/null \
                | grep -vE '^(skills/|agents/|commands/|wss/logs/audits/)' \
                | grep -vxF -f <(printf '%s\n' "$fig_skip"))
  else
    fig_files=$(git -C "$PWD" ls-files '*.md' 2>/dev/null \
                | grep -vE '^(skills/|agents/|commands/|wss/logs/audits/)')
  fi

  fig_hits=""
  fig_files_checked=0
  while IFS= read -r ff; do
    [ -n "$ff" ] || continue
    [ -f "$PWD/$ff" ] || continue
    fig_files_checked=$((fig_files_checked + 1))
    h=$(awk '
        /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
        fence { next }
        { lines[NR] = $0 }
        END {
          for (i = 1; i <= NR; i++) {
            line = lines[i]
            if (line !~ /[0-9][0-9,]*[ ]?(B|KB|MB|bytes)\b/ && line !~ /[0-9]{1,3}(,[0-9]{3})+/) continue
            win = ""
            for (j = i-2; j <= i+2; j++) if (j >= 1 && j <= NR) win = win " " lines[j]
            if (win ~ /[Rr]ecompute/) continue
            if (win ~ /rather than trusting/) continue
            if (win ~ /[Aa]udit pass/) continue
            if (win ~ /canon/) continue
            if (win ~ /20[0-9][0-9]-[01][0-9]-[0-3][0-9]/) continue
            if (win ~ /`[^`]*:[0-9]+`/) continue
            if (win ~ /`[^`]* [^`]+`/) continue
            gsub(/^[ \t]+/, "", line)
            print FILENAME ":" i ": " line
          }
        }
      ' "$PWD/$ff" 2>/dev/null | sed "s#^$PWD/##")
    [ -n "$h" ] && fig_hits="$fig_hits$h
"
  done <<< "$fig_files"

  fig_n=$(printf '%s\n' "$fig_hits" | grep -c . || true)
  if [ "$fig_files_checked" -eq 0 ]; then
    notice "no records or docs resolved to scan — nothing checked"
  elif [ "$fig_n" -eq 0 ]; then
    pass "every figure in $fig_files_checked record/doc file(s) carries a citation or a recompute command"
  else
    fig_sample=$(printf '%s\n' "$fig_hits" | sed '/^$/d' | head -10 | sed 's/^/        /')
    fig_extra=""
    [ "$fig_n" -gt 10 ] && fig_extra="
        ...and $((fig_n - 10)) more"
    fail "$fig_n figure(s) in $fig_files_checked record/doc file(s) carry
        neither a citation nor a recompute command nearby — see
        wss/workflow/WSS.RECORD-CONTRACT.md's \"A figure carries what recomputes
        it\" and its exception list:
$fig_sample$fig_extra"
  fi
fi

# ---------------------------------------------------------- citation proximity

head_ "Citation proximity"

# wss/workflow/WSS.RECORD-CONTRACT.md's "A concept is stated once; nothing else
# restates it by hand": a rule already stated somewhere may be pointed at,
# mechanically derived, or listed as an exception — never hand-copied without
# saying where it lives. This section is the mechanical half of that for a
# NAMED RULE specifically: a `<compound> rule` phrase (the shape this suite
# already uses — `the mutable-claim rule`, `the read-inheritance rule`)
# restated with no citation nearby is a hand-copy.
#
# RULE IDS DO NOT EXIST YET (wss/records/WSS.TODO.md, Cycle 9's "The
# citation-proximity check"), so phase one accepts any ANCHOR-SHAPED citation
# — a markdown link whose target carries a `#fragment` — as the stand-in for
# the id form that lands once the index does.
#
# WHAT COUNTS AS "ALREADY CITABLE" IS DERIVED, NOT HAND-KEPT. A bare `-rule`
# mention proves nothing by itself: this tree also names plenty of small local
# conventions "the stop-and-report rule" or "the one-project rule" that were
# never meant to point anywhere else, and a first cut flagging every such
# mention found 26 of them with nothing wrong. So pass one walks every file
# once for a `<word>-<word> rule` phrase sitting on the same or an adjacent
# line (one line either side — tighter than the check below, so an unrelated
# anchor two lines off cannot falsely certify a phrase) to an anchor-shaped
# link, and records the phrase, lower-cased. Pass two re-walks looking for
# occurrences of an ALREADY-ESTABLISHED phrase with no anchor within two
# lines, the same window the figure-source check above uses. A phrase that
# never once sits near a citation anywhere in scope never enters the set pass
# two checks, so it is never flagged — a deliberate false-negative, the same
# direction the row-completeness check's own six-verb list favours: a locally
# named convention flagged for a citation nothing ever asked it to carry is
# the expensive side to be wrong on.
#
# THE FILE DEFINING A RULE IS EXEMPT FROM CITING ITS OWN HEADING. A phrase
# that is also, verbatim, a heading (`#`/`##`/`###`, `**bold**` stripped)
# somewhere in the SAME file is that file's canon — WSS.RECORD-CONTRACT.md's
# own "## The mutable-claim rule" heading and its earlier table-cell pointer
# ("see the mutable-claim rule below") are what this exists for.
#
# TWO MORE WORDS IN THE WINDOW STAND IN FOR A CITATION, matching the
# figure-source check's own use of bare words as evidence above: "canon"
# (exception 2's word, same as there) and "links the" — a sentence ABOUT
# another file's citation of a rule, offered as a worked example, is not
# itself a restatement.
#
# No `\b` anywhere in the awk below, deliberately. gawk reads `\b` as a
# literal backspace rather than a word boundary (its boundary is `\y`), which
# is a live defect in the figure-source check's own size-unit pattern above.
#
# WARN, NOT FAIL, and clean from the day it lands rather than staged dirty:
# unlike the figure-source and row-completeness checks, which shipped warning
# against a tree that was not yet clean, this one was built FIRST specifically
# so it would land green (wss/logs/WSS.DECISIONS.md, 2026-08-17 (eighth);
# wss/records/WSS.ROADMAP.md — "building it last was the first draft's
# mistake"). Promote to fail on the same condition the figure-source check
# recorded rather than left to judgement: once a run of this section reports
# zero findings.
if ! git -C "$CLAUDE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  notice "not a git checkout — the citation-proximity check walks
      WSS.record.tooling.sources and has nothing to walk"
else
  cp_files=$(rule_files_ | tr '\0' '\n')
  cp_n=$(printf '%s\n' "$cp_files" | grep -c . || true)
  if [ "$cp_n" -eq 0 ]; then
    notice "no tooling-source file resolved — nothing to check for citation
        proximity"
  else
    cp_canon=""
    while IFS= read -r cf; do
      [ -n "$cf" ] || continue
      [ -f "$cf" ] || continue
      h=$(awk '
          /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
          fence { next }
          { lines[NR] = $0 }
          END {
            for (i = 1; i <= NR; i++) {
              line = lines[i]
              while (match(line, /[a-z][a-z-]*-[a-z]+ rule/)) {
                phrase = tolower(substr(line, RSTART, RLENGTH))
                line = substr(line, RSTART + RLENGTH)
                win = ""
                for (j = i-1; j <= i+1; j++) if (j >= 1 && j <= NR) win = win " " lines[j]
                if (win ~ /\]\([^)]*#[A-Za-z0-9_-]+\)/) print phrase
              }
            }
          }
        ' "$cf" 2>/dev/null)
      [ -n "$h" ] && cp_canon="$cp_canon$h
"
    done <<< "$cp_files"
    cp_canon=$(printf '%s\n' "$cp_canon" | sed '/^$/d' | sort -u)

    cp_hits=""
    if [ -n "$cp_canon" ]; then
      while IFS= read -r cf; do
        [ -n "$cf" ] || continue
        [ -f "$cf" ] || continue
        h=$(awk -v FN="${cf#"$CLAUDE_DIR"/}" -v canon="$cp_canon" '
            BEGIN {
              n = split(canon, carr, "\n")
              for (k = 1; k <= n; k++) if (carr[k] != "") known[carr[k]] = 1
            }
            /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
            fence { next }
            { lines[NR] = $0 }
            END {
              for (i = 1; i <= NR; i++) {
                if (lines[i] ~ /^#+[[:space:]]/) {
                  hd = tolower(lines[i]); gsub(/^#+[[:space:]]*/, "", hd); gsub(/\*\*/, "", hd)
                  heads[hd] = 1
                }
              }
              for (i = 1; i <= NR; i++) {
                line = lines[i]; tmp = line
                while (match(tmp, /[a-z][a-z-]*-[a-z]+ rule/)) {
                  phrase = tolower(substr(tmp, RSTART, RLENGTH))
                  tmp = substr(tmp, RSTART + RLENGTH)
                  if (!(phrase in known)) continue
                  selfcanon = 0
                  for (hh in heads) if (index(hh, phrase) > 0) selfcanon = 1
                  if (selfcanon) continue
                  win = ""
                  for (j = i-2; j <= i+2; j++) if (j >= 1 && j <= NR) win = win " " lines[j]
                  if (win ~ /\]\([^)]*#[A-Za-z0-9_-]+\)/) continue
                  if (win ~ /canon/) continue
                  if (win ~ /[Ll]inks the/) continue
                  out = line; gsub(/^[ \t]+/, "", out)
                  print FN ":" i ": " out
                }
              }
            }
          ' "$cf" 2>/dev/null)
        [ -n "$h" ] && cp_hits="$cp_hits$h
"
      done <<< "$cp_files"
    fi

    cp_n_hits=$(printf '%s\n' "$cp_hits" | grep -c . || true)
    if [ -z "$cp_canon" ]; then
      notice "no rule name is yet established with a nearby anchor-shaped
          citation anywhere in $cp_n tooling-source file(s) — nothing for this
          check to compare a restatement against"
    elif [ "$cp_n_hits" -eq 0 ]; then
      pass "no restated rule name in $cp_n tooling-source file(s) sits more
        than two lines from an anchor-shaped citation"
    else
      cp_sample=$(printf '%s\n' "$cp_hits" | sed '/^$/d' | head -10 | sed 's/^/        /')
      cp_extra=""
      [ "$cp_n_hits" -gt 10 ] && cp_extra="
        ...and $((cp_n_hits - 10)) more"
      warn "$cp_n_hits restatement(s) of an already-cited rule name carry no
        anchor-shaped citation within two lines — see
        wss/workflow/WSS.RECORD-CONTRACT.md's \"A concept is stated once;
        nothing else restates it by hand\":
$cp_sample$cp_extra"
    fi
  fi
fi

# ---------------------------------------------------------------- file naming

head_ "File naming"

# wss/workflow/WSS.NAMING.md is the one authority on the names of files the suite
# creates, and until 2026-08-15 nothing enforced it. That is how 26 reference
# files shipped in a single afternoon as `step2-shape.md` and `phase0-scope.md`
# while their sibling split used `WSS.MODE-AUDIT.md` correctly — same day, same
# refactor, and no check to notice. A convention with no check is a suggestion.
#
# THE TEST IS THE CONTRACT'S OWN: "would this file exist if the suite were not
# installed?" If no, the suite named it and one of three forms applies —
# `wss-<name>` for anything the harness resolves as an identifier, `WSS.<...>`
# for anything a person is meant to read, `.wss-<name>` for machine bookkeeping
# with no reader. Everything else is a name somebody else owns.
#
# OWNERSHIP IS PER FILE, NOT PER DIRECTORY, and the distinction is the whole
# check. An earlier draft excluded `docs/` and `wss/logs/audits/` wholesale, which was
# wrong twice over: docsify owns three filenames, not a directory, so every page
# WE wrote under `docs/` escaped the convention behind a blanket that was never
# needed; and audit reports are our files, so they take the instance form the
# grammar already provides — `WSS.AUDIT.<date>-<pass>.md`.
#
# So there is exactly one rule here: a name this suite chose follows
# WSS.NAMING.md, and a name someone else's tool resolves BY NAME does not,
# because renaming it breaks the thing that reads it. `README.md`, `LICENSE`,
# `SKILL.md`, `plugin.json` and `settings.json` are the harness's and the
# ecosystem's; `index.md`, `index.html` and `_sidebar.md` are docsify's.
# `.github/` is one path-shaped entry and it earns that: GitHub resolves the
# directory by name and surfaces the workflow filenames in its own UI.
#
# `commands/` is another, and it is the one that made this check fail a real
# publish assembly the day after it shipped. A wrapper's filename IS its
# invocation, and which spelling is correct depends on the install form: a
# checkout keeps the prefix (`log.md` -> `/wss:log`), while the published
# plugin strips it because the namespace supplies it (`log.md` -> `/wss:log`).
# `wss-publish.sh` performs that strip deliberately, so asserting the prefixed
# form over the assembly demands a prefix the assembly exists to remove — the
# two contradict each other by construction and no spelling satisfies both.
# NOTHING IS LOST BY EXEMPTING THEM, because a stricter check already owns these
# names: the "Command wrappers" section above requires a wrapper's body to fire
# the flag its own name promises AND that flag to exist in the hook's FLAGS, and
# it accepts exactly the two legal spellings. A wrapper cannot be named freely
# there; it is pinned to a real flag. This check was the weaker of the two and
# the only one that disagreed with the strip.
#
# `wss/logs/audits/` is the second, and it is a rule rather than a blanket: each report's
# filename is a PRIMARY KEY in the index above — `WSS.record.audits` carries one
# table row per report and the "Audit reports" check matches it by exact
# basename. That index is `log`-tagged, so a row cannot be repointed: the
# basename changes, which the append-only guard's relocation exemption
# deliberately refuses. Renaming a report therefore makes the index wrong AND
# unrepairable. These names were renamed to the convention on 2026-08-15 and
# reverted the same hour on exactly this discovery. A name recorded verbatim in
# an append-only record is frozen along with the record.
# SCOPE: enforce the convention only where the convention LIVES. A tree without
# `wss/workflow/WSS.NAMING.md` has not declared this naming contract, so it has
# nothing to violate — that covers the contract suite's fixture installations,
# which build minimal trees whose filenames are chosen by the test, and an
# adopted project, whose own source files this suite never named. Shipped
# without this gate on 2026-08-15 and it reddened ten contract-suite cases
# immediately: the check was asserting the suite's convention against trees that
# had never adopted it.
if [ ! -f "$CLAUDE_DIR/wss/workflow/WSS.NAMING.md" ]; then
  notice "no wss/workflow/WSS.NAMING.md here — naming convention not declared, nothing to enforce"
else
nm_bad=0 nm_first=""
while IFS= read -r nm_f; do
  nm_b=${nm_f##*/}
  case $nm_f in
    .github/*|wss/logs/audits/*|commands/*) continue ;;
  esac
  case $nm_b in
    WSS.*|wss-*|.wss-*) continue ;;
    README.md|LICENSE|CHANGELOG.md|CLAUDE.md|SKILL.md|.gitignore) continue ;;
    hooks.json|plugin.json|marketplace.json|settings.json) continue ;;
    index.md|index.html|_sidebar.md|_navbar.md|_coverpage.md|.nojekyll) continue ;;
  esac
  nm_bad=$((nm_bad + 1))
  [ -z "$nm_first" ] && nm_first=$nm_f
done < <(git -C "$CLAUDE_DIR" ls-files 2>/dev/null)

if [ "$nm_bad" -eq 0 ]; then
  pass "every suite-authored filename follows wss/workflow/WSS.NAMING.md"
else
  fail "$nm_bad file(s) the suite named do not follow wss/workflow/WSS.NAMING.md, first: $nm_first"
fi

# The same contract row says a `.sh` IS the executable form, so the bit is part
# of the convention rather than a packaging detail: a script without it fails
# only when something invokes it directly, which is exactly the call site no
# test exercises. Two had lost it before this check existed — one to an in-place
# edit through a temp file, one silently four days earlier.
nm_noexec=$(git -C "$CLAUDE_DIR" ls-files -s '*.sh' 2>/dev/null | awk '$1 != "100755"' | wc -l)
if [ "$nm_noexec" -eq 0 ]; then
  pass "every tracked .sh carries the executable bit"
else
  fail "$nm_noexec tracked .sh file(s) are not executable — git update-index --chmod=+x <file>"
fi
fi

# ---------------------------------------------------------------------- result

head_ "Result"
notice_hint=""
[ $NOTES -eq 0 ] && [ $notices -gt 0 ] && notice_hint=" (--notes shows them)"
if [ $fails -gt 0 ]; then
  printf '  \033[31m%d failed\033[0m, %d warnings, %d notices%s\n\n' "$fails" "$warns" "$notices" "$notice_hint"
  exit 1
fi
if [ $STRICT -eq 1 ] && [ $warns -gt 0 ]; then
  printf '  \033[31mall checks passed, but %d warnings and --strict\033[0m\n\n' "$warns"
  exit 1
fi
printf '  \033[32mall checks passed\033[0m, %d warnings, %d notices%s\n\n' "$warns" "$notices" "$notice_hint"
