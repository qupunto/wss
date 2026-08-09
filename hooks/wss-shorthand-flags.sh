#!/usr/bin/env bash
# UserPromptSubmit hook: turns a `--flag` shorthand into a deterministic skill
# invocation. The FLAGS array below is the list — deliberately not restated
# here, because a second copy is a stale inventory waiting to happen, and this
# one had already fallen a flag behind.
#
# Every flag here maps to a GLOBAL skill. A flag whose skill is project-scoped
# belongs in that project's own hook, not this one — a global block guarding a
# skill only one project has is a standing warning here and a set of rules that
# project cannot edit.
#
# Skills are model-invoked — Claude decides whether a request matches the
# skill's description, so a shorthand written only into a description is
# reliable in practice but not guaranteed. This hook is the deterministic
# path: the instruction is injected whether or not Claude would have noticed.
#
# WHERE A FLAG COUNTS: anywhere in the message. A token counts when it
# decomposes ENTIRELY into flags — `--wss-stocktake --wss-release` and
# `--wss-stocktake--wss-release` fire both, mid-sentence as readily as at either
# end — and a token that decomposes with anything left over stays inert, so
# `--wss-wrapper` and `origin/dev` never fire.
#
# Position used to be the signal: flags were read only from a run at the very
# start or very end, because unprefixed flags collided with pasted commands
# (`git branch --track origin/dev` was the realistic case). The `wss-` prefix
# removed that collision — no real command carries a `--wss-*` option — so the
# positional filter only cost missed invocations mid-sentence. What remains
# deliberate: a message that QUOTES a flag as its own bare token fires it.
# With the prefix, an exact token is taken as intent, wherever it sits.
#
# Wired up from ~/.claude/settings.json. Silent (exit 0, no output) when no
# flag is present, so it costs nothing on ordinary turns.

# Two hard dependencies, both of which fail SILENTLY without a guard, and both
# of which degrade exactly the way this hook exists to prevent: every flag goes
# inert, the hook exits 0, and nothing says so for weeks.
#
#   jq  — without it the prompt parses empty, no token decomposes, and the
#         `${#ordered[@]} -eq 0` exit below looks like an ordinary flagless turn.
#   bash 4 — `declare -A` below needs bash 4, and /bin/bash on stock macOS is
#         still 3.2. CI only ever runs ubuntu-latest, so no pipeline covers it.
#         It fails at RUNTIME ("declare: -A: invalid option") rather than at
#         parse time, which is the only reason a guard ABOVE it gets to run at
#         all — leaving `seen` an indexed array, so the next subscript evaluates
#         `--wss-wrap` as arithmetic. Keep this check above line ~103.
#
# Both write to stderr and exit 0: a non-zero exit here would block the user's
# turn outright, and a broken shorthand must never cost someone their prompt.
if ! command -v jq >/dev/null 2>&1; then
  echo "wss-shorthand-flags.sh: jq not found — every --flag is inert until it is installed" >&2
  exit 0
fi
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "wss-shorthand-flags.sh: needs bash 4+ (found ${BASH_VERSION:-unknown}) — every --flag is inert" >&2
  exit 0
fi

payload=$(cat 2>/dev/null)
prompt=$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null)

# The invariant this list must keep: NO FLAG IS A PREFIX OF ANOTHER. Where that
# holds, a token can never be split into a shorter flag plus junk and the order
# below does not matter. `--wss-stocktake` and `--wss-full-stocktake` look like they collide and
# do not — the latter has its own leading dashes. wss-doctor.sh checks the invariant
# rather than trusting this comment; add a flag that violates it and it fails.
FLAGS=(--wss-full-stocktake --wss-pr --wss-full-check --wss-release --wss-stocktake --wss-report --wss-adopt --wss-flags --wss-start --wss-track --wss-docs --wss-check --wss-tools --wss-todo --wss-wrap --wss-plan --wss-help --wss-log --wss-alerts --wss-overview --wss-scout --wss-describe --wss-reference --wss-diagram --wss-update)

# Split into whitespace-separated tokens. `set -f` because an unquoted
# expansion would otherwise glob `*` in the prompt against the filesystem.
set -f
tokens=($prompt)
set +f
n=${#tokens[@]}

# Print every flag a token is built from, or fail if any part of it is not a
# flag. `continue 2` restarts the while loop after a successful match.
decompose() {
  local s=$1 f out=()
  while [ -n "$s" ]; do
    for f in "${FLAGS[@]}"; do
      if [[ $s == "$f"* ]]; then
        out+=("$f")
        s=${s#"$f"}
        continue 2
      fi
    done
    return 1
  done
  [ ${#out[@]} -gt 0 ] || return 1
  printf '%s\n' "${out[@]}"
}

# Collect in the order the user typed them, deduplicated: multiple flags fire
# together, and the order they run in should be the order they were asked for.
# Every token is scanned; collect() is a no-op on one that does not decompose,
# which is what keeps prose and pasted commands inert.
declare -A seen=()
ordered=()
collect() {
  local f
  while IFS= read -r f; do
    [ -n "${seen[$f]:-}" ] && continue
    seen[$f]=1
    ordered+=("$f")
  done < <(decompose "$1")
}
for ((i = 0; i < n; i++)); do collect "${tokens[$i]}"; done

[ ${#ordered[@]} -eq 0 ] && exit 0

# `--wss-stocktake` and `--wss-full-stocktake` are the same skill at two scopes, so they are
# mutually exclusive and the wider one wins.
if [ -n "${seen[--wss-full-stocktake]:-}" ]; then
  unset 'seen[--wss-stocktake]'
fi

# `--wss-full-check` is a different SKILL from `--wss-check` rather than a wider scope of
# it, but it runs --wss-check's method over --wss-check's files as one of its three
# areas, so firing both sweeps the record twice. The wider one wins.
#
# `--wss-docs` and `--wss-tools` are deliberately NOT dropped, even though --wss-full-check
# subsumes their SWEEPS. Both of those flags have a second, unrelated job —
# writing a page, syncing the catalog — and `--wss-full-check --wss-docs auth` is a
# health check followed by a request to document something. This hook cannot
# tell that apart from a redundant sweep, and dropping a write request to save
# one read is the wrong way to be wrong. The multi-flag preamble already tells
# Claude to do a shared step once.
if [ -n "${seen[--wss-full-check]:-}" ]; then
  unset 'seen[--wss-check]'
fi

# Either stocktake flag absorbs `--wss-check`. wss-stocktake runs --wss-check's
# method over --wss-check's files as its record dimension and says so — "invoke one
# or the other, never both" — so firing both sweeps the record twice, and the
# second sweep reports the first one's writes as fresh drift.
#
# `--wss-full-check` is deliberately NOT dropped here, on the same reasoning that
# spares --wss-docs and --wss-tools above. It is a different skill, not a wider scope:
# it also covers the docs site and the tooling files, neither of which a
# stocktake touches. Dropping it would silently narrow what the user asked for.
if [ -n "${seen[--wss-stocktake]:-}" ] || [ -n "${seen[--wss-full-stocktake]:-}" ]; then
  unset 'seen[--wss-check]'
fi

# Only claim a flag whose skill actually resolves here — at user level, or in
# this project. Injecting "follow the X skill" where X does not exist is an
# instruction Claude cannot carry out, so an unresolvable flag is left INERT
# rather than fired. That gate is what lets global and project-specific skills
# share one hook: a project simply does not get the flags it has no skill for.
# The third root is what makes this hook work when the configuration ships as a
# plugin rather than as ~/.claude. Without it every flag is INERT for a plugin
# install — the gate that makes an unresolvable flag safe becomes the thing that
# disables the whole feature, and it does so silently, which is the worst way to
# find out.
#
# The user root is CLAUDE_CONFIG_DIR when it is set, NOT $HOME/.claude. wss-doctor.sh
# and wss-session-check.sh both resolve it that way; this hook did not, so under a
# custom config dir it gated flags against a skills/ tree the harness was not
# loading — firing a flag for a skill that will not be there, or leaving one
# inert that will. Same variable, same precedence, all three scripts.
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

skill_exists() {
  [ -f "$PWD/.claude/skills/$1/SKILL.md" ] ||
    [ -f "$CONFIG_DIR/skills/$1/SKILL.md" ] ||
    { [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/skills/$1/SKILL.md" ]; }
}

# Existing on disk is not the same as runnable. Settings can disable a skill by
# name under `skillOverrides`, and an override leaves SKILL.md exactly where it
# was — so the check above passes, this hook injects "invoke the X skill now",
# and the harness then refuses. The user sees an instruction and a refusal in
# the same turn, which is worse than the flag having done nothing.
#
# The key, its four levels, and the precedence below are read off the CLI
# (2.1.220), not assumed:
#
#   - the schema is a map of skill name to one of on / name-only /
#     user-invocable-only / off;
#   - two of those block MODEL invocation, which is the only kind this hook can
#     ask for: `off`, and `user-invocable-only` — the latter is also what a
#     skill author's own `disableModelInvocation` resolves to. `name-only` trims
#     what is loaded into context and still runs, so it fires normally;
#   - project settings outrank user settings, and nothing else participates.
#     `settings.local.json` is a real settings scope but this key's resolver
#     does not read it, so neither does this. Reading it anyway would make a
#     flag inert for a skill that does in fact run — the same silent loss, in
#     the other direction.
#
# First file that names the skill wins. A file that does not mention it is not
# an answer, so the search continues rather than concluding "enabled".
skill_disabled() {
  local file level
  for file in "$PWD/.claude/settings.json" "$CONFIG_DIR/settings.json"; do
    [ -f "$file" ] || continue
    level=$(jq -r --arg s "$1" '.skillOverrides[$s] // empty' "$file" 2>/dev/null)
    [ -n "$level" ] || continue
    case $level in
      off | user-invocable-only) return 0 ;;
      *) return 1 ;;
    esac
  done
  return 1
}

# `-` means "served by this hook itself, not by a skill" — `--wss-flags` and
# `--wss-alerts`. It is a real mapping rather than a missing arm on purpose:
# wss-doctor.sh and the contract suite both FAIL on a flag whose skill_for() arm is
# absent, and that check is worth keeping sharp. A silent empty string would
# have made a flag with no skill indistinguishable from one someone forgot to
# wire.
skill_for() {
  case $1 in
    --wss-flags | --wss-help | --wss-alerts) echo - ;;
    --wss-track) echo wss-track ;;
    --wss-todo | --wss-log) echo wss-record ;;
    --wss-wrap) echo wss-wrap ;;
    --wss-start) echo wss-start ;;
    --wss-release) echo wss-release ;;
    --wss-pr) echo wss-pr ;;
    --wss-stocktake | --wss-full-stocktake) echo wss-stocktake ;;
    --wss-adopt) echo wss-adopt ;;
    --wss-update) echo wss-update ;;
    --wss-docs | --wss-diagram) echo wss-docs ;;
    --wss-tools) echo wss-tools ;;
    --wss-check) echo wss-check ;;
    --wss-report) echo wss-report ;;
    --wss-full-check) echo wss-full-check ;;
    --wss-plan) echo wss-plan ;;
    --wss-overview) echo wss-overview ;;
    --wss-scout) echo wss-scout ;;
    --wss-describe) echo wss-describe ;;
    --wss-reference) echo wss-reference ;;
  esac
}

# Where a skill's SKILL.md actually resolved, in the order skill_exists() tries.
skill_path_() {
  local p
  for p in "$PWD/.claude/skills/$1/SKILL.md" "$CONFIG_DIR/skills/$1/SKILL.md"; do
    [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/skills/$1/SKILL.md" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT/skills/$1/SKILL.md"
    return 0
  fi
  return 1
}

# The leading clause of a skill's own description — what it does, before the
# shorthand and the trigger phrases. Read from the file rather than restated
# here: a second copy of every one-liner is an inventory, and this hook has
# a comment at the top about exactly that failure.
skill_gist_() {
  awk '
    NR == 1 && /^---$/ { f = 1; next }
    f && /^---$/ { exit }
    f && /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      gsub(/\\"/, "\"")
      # cut at the first sentence end, the shorthand, or the trigger list
      if (match($0, / SHORTHAND:| Also trigger| Invoke on| Trigger on| Use whenever/))
        $0 = substr($0, 1, RSTART - 1)
      # Cut to the first sentence, but only while that still says something.
      # wss-record opens with one short line about the record, and puts the
      # --wss-todo / --wss-log split in the sentence AFTER it, so cutting
      # unconditionally described both flags with the same nine words.
      # NOTE: no apostrophes in this comment. The whole program is inside a
      # single-quoted shell string, and one here ends it — which is a syntax
      # error in the hook that routes every flag.
      if (match($0, /\. [A-Z`]/) && RSTART >= 60) $0 = substr($0, 1, RSTART)
      sub(/[[:space:]]+$/, "")
      print; exit
    }' "$1"
}

# THE POINT OF THIS BLOCK: it is computed, every time, from the FLAGS array and
# skill_for() cases above and from each skill's own description. Nothing here is
# a second copy of anything, so it cannot drift from what the hook actually
# does — which is the failure mode a hand-written flag list has, and this repo
# has deleted two such inventories already for going stale.
#
# It also reports what resolves HERE, which a static list could never do: a flag
# whose skill is absent in this project is INERT, and saying so is most of the
# value. A user who types a flag and gets silence has no other way to find out.
flags_block_() {
  local f skill path gist state
  printf 'The user asked what flags exist. Present this table to them, as a table,\n'
  printf 'and add nothing to it from memory — it was computed from the hook that\n'
  printf 'actually routes the flags, so it is right by construction and anything\n'
  printf 'recalled alongside it may not be.\n\n'
  printf '| Flag | Runs | Here? | What it does |\n'
  printf '|---|---|---|---|\n'
  while IFS= read -r f; do
    skill=$(skill_for "$f")
    if [ "$skill" = "-" ]; then
      if [ "$f" = --wss-alerts ]; then
        printf '| `%s` | — | yes | Toggles the sound cue: `--wss-alerts on\\|off`. Served by the hook, so it needs no skill. |\n' "$f"
      else
        printf '| `%s` | — | yes | Lists these flags. Served by the hook, so it needs no skill. |\n' "$f"
      fi
      continue
    fi
    if path=$(skill_path_ "$skill"); then
      gist=$(skill_gist_ "$path")
      if skill_disabled "$skill"; then state='disabled'; else state='yes'; fi
    else
      gist=''
      state='**no**'
    fi
    printf '| `%s` | `%s` | %s | %s |\n' "$f" "$skill" "$state" "${gist:-—}"
  done < <(printf '%s\n' "${FLAGS[@]}" | sort)
  printf '\nA flag marked **no** is INERT here: its skill resolves in neither this\n'
  printf 'project nor the user configuration, so typing it does nothing at all\n'
  printf 'rather than failing. `disabled` means settings block model invocation.\n\n'
  printf 'A flag counts anywhere in the message, as its own token or a glued run\n'
  printf 'of flags with nothing else attached (`--wss-wrapper` stays inert). Several\n'
  printf 'may be combined and run in the order typed.\n'
}

block_for() {
  case $1 in
  --wss-flags | --wss-help)
    flags_block_
    # The grant line stays HERE, at column 0 in a heredoc, rather than inside
    # flags_block_. wss-doctor.sh reads this shape out of the hook source to compare
    # against WSS.OWNERSHIP.md, and a grant it cannot extract is counted as blind
    # rather than passed — correctly, since a block whose authorization moved
    # out of reach is exactly how the comparison would go quiet.
    cat <<'EOF'

Authorization: none.
EOF
    ;;
  --wss-track)
    cat <<'EOF'
The user included the `--wss-track` flag. That is an explicit, unconditional
instruction to invoke the `wss-track` skill now. The usual complexity
threshold does NOT apply — do not skip the list because the work looks small.

Authorization: none.
EOF
    ;;
  --wss-todo)
    cat <<'EOF'
The user included the `--wss-todo` flag. That is an explicit, unconditional
instruction to park an idea rather than build it, using the `wss-record`
skill — invoke it now, without asking for confirmation first.

The rest of the message is the idea to defer, not a question to answer.

Authorization: none.

Irreversible, in force before the skill loads: a deferral is a decision, so it
produces TWO entries — the task in the project's backlog record, and the
reasoning in its decision record. Never write the reasoning into the backlog.
If the real blocker is an unmade choice rather than bad timing it belongs in the
open-decisions record instead, and never in both. The decision entry NAMES WHOSE
CALL the deferral was — the owner's words, or the session's own judgment, which
stands only until the owner's next gate.
EOF
    ;;
  --wss-plan)
    cat <<'EOF'
The user included the `--wss-plan` flag. That is an explicit, unconditional
instruction to invoke the `wss-plan` skill now — what the next GOAL is, how a
roadmap's blocks are ordered, or whether a milestone is finished. The rest of
the message is scope, not a question to answer first.

Authorization: none.

Irreversible, in force before the skill loads:
- TWO RECORDS. `WSS.record.roadmap` holds GOALS and their blocks and SPLITS PER LANE.
  `WSS.record.releases` holds the milestones, the version each ships as, and the
  completion marks, and NEVER splits. NO ROADMAP CARRIES A VERSION OR A MARK —
  wss-doctor.sh FAILS one that does.
- READ `.claude/WSS.LANE` FIRST. Where it names a lane this invocation is
  goal-setting on that lane's roadmap and NOTHING ELSE: do not ask whether a
  milestone is done, do not name a version, do not write a mark, do not open
  `WSS.record.releases`. A mark is a checkpoint for the whole project and a lane
  session sees one lane of it.
- COMPLETING A MILESTONE IS THE USER'S CALL, NEVER YOURS, and only from the main
  checkout. Never mark one on the strength of your own reading or an agent's
  report. Say what the milestone claimed, what landed, and what is still open
  against it — then ask.
- BUT ASK WHEN THE LAST GOAL A MILESTONE CITES IS MET. Do not wait to be told.
- The mark you write is what authorizes `--wss-release` to tag, so write it into
  `WSS.record.releases` and not into the conversation: it must survive a `/clear`.
- A milestone with an open blocking decision, or with unremediated high-severity
  audit findings, is disqualified however finished it looks. Name it rather than
  letting a release discover it.
- A roadmap holds goals, blocks and their order. Not tasks, not design
  arguments. Breaking a block into tasks is `--wss-todo`'s job.
- Run the grep that would DISPROVE any "nothing does X" or count before writing
  it here.
EOF
    ;;
  --wss-adopt)
    cat <<'EOF'
The user included the `--wss-adopt` flag. That is an explicit, unconditional
instruction to run the `wss-adopt` skill now — bring this project under the
workflow by writing `.claude/WSS.WORKFLOW.json`.

Authorization: COMMIT what it creates. Not push.

Irreversible, in force before the skill loads:
- If a manifest already exists this is an AMENDMENT, not a rewrite. Fill gaps
  only; never overwrite a key the project already chose. THE ONE EXCEPTION is a
  key or filename matching a PREVIOUS suite convention — that is stale
  machinery, not a project's choice, and it routes to the migration procedure
  behind its own consent gate (the `wss-update` skill's Job 2), never mended
  silently as part of adoption.
- NEVER INVENT A PATH OR A COMMAND. Every value must be verified to exist or to
  be declared by the project's own tooling. A key you cannot resolve is LEFT
  OUT: a missing key degrades gracefully and says so; a wrong one misdirects
  every skill that reads it without ever failing.
- Record files are created EMPTY, with their heading and nothing else. The
  owning skill writes the first real line.
- Finish by running ~/.claude/wss-doctor.sh and showing its output. Adoption is not
  complete on a failing doctor; never report success over one.
EOF
    ;;
  --wss-update)
    cat <<'EOF'
The user included the `--wss-update` flag. That is an explicit, unconditional
instruction to run the `wss-update` skill now — update the suite install, then
detect what conventions this tree actually carries and migrate it to the
newest.

Authorization: COMMIT what the migration changes. Not push.

Irreversible, in force before the skill loads:
- DETECTION IS THE AUTHORITY. The stamp (`WSS.suite`) and the release list's
  migration lines only accelerate; every claim is re-verified against the
  tree's own files before anything is mended.
- SNAPSHOT BEFORE THE FIRST WRITE: wss-export-records.sh --all (it reads
  legacy manifests). Tell the user where the archive landed.
- The migration plan is shown and gets an explicit OK in that turn before any
  mend. A mend the plan did not name waits; it is never slipped in.
- A PARTIAL MIGRATION NEVER EXITS CLEAN, and the stamp is written only after
  a passing doctor — through manifest-writer, never by hand. No resolvable
  commit means NO stamp, not a guessed one.
- Append-only records are NEVER rewritten; old names inside historical text
  stay as written.
EOF
    ;;
  --wss-check)
    cat <<'EOF'
The user included the `--wss-check` flag. That is an explicit, unconditional
instruction to invoke the `wss-check` skill now and health-check the
project's record for claims that no longer match reality and for updates the code
owes but never got.

Authorization: none — and this skill writes NOTHING.

Irreversible, in force before the skill loads:
- Do not fix what you find. Report it, then dispatch each finding to the skill
  that OWNS that file, and let that owner re-verify before writing. Your finding
  is a hypothesis, and a share of findings do not reproduce when re-checked.
- Run the grep that would DISPROVE a negative claim before repeating it. The
  usual way "nothing does X" goes wrong is a grep matching the wrong call shape.
- Chronological decision entries are NOT stale. An entry describing a decision
  later reversed is correct as written. Never dispatch a rewrite of one.
EOF
    ;;
  --wss-full-check)
    cat <<'EOF'
The user included the `--wss-full-check` flag. That is an explicit, unconditional
instruction to invoke the `wss-full-check` skill now — re-verify every file
the project keeps for its functional value, at FULL scope: the records, the docs
site, and the tooling files.

Authorization: none — and this skill writes nothing that HAS AN OWNER.

Irreversible, in force before the skill loads:
- IGNORE every sweep checkpoint. Full scope means re-reading files a previous
  sweep listed as covered. Do not narrow to a diff.
- Stamp the checkpoints at the end, through `sweep-tracker`, and stamp ONLY what
  was actually read. An area whose reader died or returned a vague report is
  not-covered; coverage claimed and not earned is inherited by every cheap sweep
  after it and nothing downstream can detect the difference.
- Do not fix what you find IN A FILE THAT HAS AN OWNER. Dispatch each such
  finding to the skill that OWNS that file and let that owner re-verify first —
  your finding is a hypothesis, and a share of them do not reproduce. An owner
  invoked from here inherits THIS flag's grant, which is none: it writes its
  file and does not commit.
- A file with NO owner in the matrix is ordinary work: edit it directly and say
  what changed. Scripts, CI, the harness settings and the `workflow/*.md`
  contracts are the usual instances. Read this rule with the one above it —
  "dispatch everything" is what an earlier version of this block said, and it
  forbids the repair of a broken hook script that WSS.OWNERSHIP.md licenses.
- Run the grep that would DISPROVE a negative claim before repeating it.
- The append-only logs — decisions, audits, changelog — are OUT of scope. An
  entry describing a decision later reversed is correct as written. The only
  thing to check about them is whether a generated index has gone stale.
- Source code and the test suite are OUT of scope. The suite is
  --wss-full-stocktake's. Code analysis proper — correctness, security, the data
  model — is a PROJECT's own skill, which --wss-stocktake invokes where one exists
  and reports as not run where none does. No flag here delivers it on its own.
EOF
    ;;
  --wss-tools)
    cat <<'EOF'
The user included the `--wss-tools` flag. That is an explicit, unconditional
instruction to invoke the `wss-tools` skill now — keep the tooling
catalog in step with what skills and agents actually exist, fix stale claims
inside those files, and run the prose prune when that is what was asked.

Authorization: COMMIT. Not push.

Irreversible, in force before the skill loads:
- In PRUNE mode, propose first and cut second: a proposed cut is a hypothesis,
  and this is the one job where being wrong is silent — nothing fails when a
  rule stops being stated, it just stops being followed. NEVER cut inside a
  section another skill hands VERBATIM to a subagent, or a heading another
  file cites (grep for the anchor first, run the doctor after), or the last
  statement of a rule, or an agent file's `description` and `tools:` list. A
  description you touch gets shorter or stays the same, never longer.
- DELETE a stale mutable claim rather than correcting it. That one line is the
  part that overrides the instinct to be helpful, so it is here rather than only
  behind a link. Everything else the rule decides — what a skill or agent file
  may carry at all, and why a corrected count goes stale again — is stated once,
  in the "The mutable-claim rule" section of
  ~/.claude/workflow/WSS.RECORD-CONTRACT.md. READ IT before editing any such file.
- Say in the commit what you removed and why. It is the only audit trail an
  erasure gets.
- NEVER edit a file belonging to THIS SUITE — its own skills, agents, workflow
  contracts and scripts — from a session working in another project. Not even
  the skill currently running, and not even when the defect is obvious. Under a
  plugin install the suite is at ${CLAUDE_PLUGIN_ROOT}; in a checkout it is the
  ~/.claude repository. Editing it under a plugin is not refused — it is
  destroyed at the next plugin update, silently.
- This does NOT restrict the working project's own skills and agents. Those are
  what WSS.record.tooling.sources globs, and editing them is this flag's whole job.
  Nor does it cover a personal ~/.claude/skills/ that is not this suite.
- Instead, APPEND the finding to WSS.BUG-REPORTS.md in the config directory
  ($CLAUDE_CONFIG_DIR, else ~/.claude) — the one file any session in any project
  may write to — then stop. It is gitignored and so ships with no template:

      ## [open] <one-line summary>
      Found: <project worked in> · <config commit, short SHA>
      File: <path within the suite> · Detail: <what is wrong, what you expected>

  Never report only into the conversation — that loses the finding at the next
  /clear. Filing IS the action, not a step on the way to fixing it. Triage
  needs a checkout; from a plugin install, raise it upstream as well.
EOF
    ;;
  --wss-report)
    cat <<'EOF'
The user included the `--wss-report` flag. That is an explicit, unconditional
instruction to invoke the `wss-report` skill now — file the finding the rest of
the message describes: append it to the machine-local bug-reports inbox, then
offer to open an issue on the suite's public upstream repository. The rest of
the message is the finding, not a question to answer first.

Authorization: none. Opening the upstream issue is an outward, public act and
needs a fresh OK in that turn.

Irreversible, in force before the skill loads:
- APPEND to the inbox FIRST. A report living only in this conversation is lost
  at the next /clear; the local entry is the report, the issue is its
  durability. If gh is absent or unauthorized, the entry stands and the issue
  is owed — say so rather than failing silently.
- The upstream repository is PUBLIC. Never include the name, path or any
  detail of the project this session was working in unless the user says so in
  words after seeing what was withheld. A published issue outlives deletion.
- Show the exact title and body before sending, and send only on an explicit
  OK given in this turn. A standing yes from earlier does not carry.
- These rules cover every entry a BUNDLED report carries, not only the new
  finding — and hazards go upstream by group name only, never their text,
  which is private to the repository that wrote it.
EOF
    ;;
  --wss-log)
    cat <<'EOF'
The user included the `--wss-log` flag. That is an explicit, unconditional
instruction to invoke the `wss-record` skill now and record a decision that
has already been made. The rest of the message is the decision, not a question
to answer first — and it is not a request to re-open it.

Authorization: none.

Irreversible, in force before the skill loads:
- The decision record is APPEND-ONLY. Never rewrite a past entry: one describing
  a decision later reversed is correct as written.
- A decision nobody actually made belongs in the open-decisions record instead,
  with what it blocks. Never write it as settled.
- Regenerate the decisions index afterwards if the manifest names a command for
  it. Never hand-edit one.
EOF
    ;;
  --wss-describe)
    cat <<'EOF'
The user included the `--wss-describe` flag. That is an explicit, unconditional
instruction to invoke the `wss-describe` skill now and record what the system
does at runtime. The rest of the message is the rule, not a question to answer
first.

Authorization: none.

Irreversible, in force before the skill loads:
- The behaviour record takes RULES, never reasoning. Why a rule is the way it is
  goes through --wss-log; a rule with its rationale inline is a decision log
  growing inside a reference.
- Never record a rule that is decided but not built. That record describes the
  running system, and a plan written as a rule is indistinguishable from one.
- Verify the rule against the code before writing it. Where the two disagree the
  code wins, and the disagreement is what to report.
- Stack, architecture, data model and conventions are the REFERENCE record's,
  not this one's. Name the right record and stop rather than writing to the
  nearest file.
EOF
    ;;
  --wss-reference)
    cat <<'EOF'
The user included the `--wss-reference` flag. That is an explicit, unconditional
instruction to invoke the `wss-reference` skill now and record what the project
is — stack, architecture, data model, conventions — in the reference record.
The rest of the message is the material, not a question to answer first.

Authorization: none.

Irreversible, in force before the skill loads:
- The reference record holds CURRENT STATE, never reasoning or history. Why the
  stack is this stack goes through --wss-log.
- Runtime rules — auth, ownership, state transitions, error statuses — are the
  BEHAVIOUR record's, through --wss-describe. Name the right record and stop.
- Where the manifest maps the project's README.md into the reference array, this
  flag reaches a public landing page. Name the exact file before writing, keep
  to the section the fact belongs to, and never take over a README the manifest
  does not name.
- Verify every claim against the source before writing it; where the code
  disagrees, the code wins and the disagreement is what to report.
EOF
    ;;
  --wss-wrap)
    cat <<'EOF'
The user included the `--wss-wrap` flag. Treat it exactly as "wrap this up, I am
about to clear the session" — invoke the `wss-wrap` skill immediately and
unconditionally, with no further confirmation, even mid-task.

The rest of the message is context about what to record, not a question to
answer first.

Authorization: COMMIT and PUSH.

Irreversible, in force before the skill loads:
- A push publishes a REF, not a selection of commits, so another session's work
  rides along with yours. Check what is about to go out and say plainly if it
  includes commits this session did not make.
- Never force-push, and never resolve a rejected push by force. A rejection
  usually means someone else pushed first, which is a merge decision.
- In a LANE WORKTREE this also lands the lane on WSS.branch.integration, after
  pushing the lane's own branch: `git push origin <branch>:<integration>` with
  NO leading `+`, so it fast-forwards or the remote refuses it. A refusal is
  reported and stops there. Skip this entirely when the wrap fired because the
  session is ending rather than because the work was approved — half-done work
  on the branch every other lane syncs from arrives there looking finished.
- Never rewrite a commit this session did not make unless the user names it.
- Commit half-done work rather than losing it, but say so — in the message and
  in the summary. Never describe unverified work as done, and state plainly
  whether the verification commands actually ran.
- Commits and pushes go through git-writer, which owns the history and holds
  these rules. It inherits this grant; it never decides to push.
- After committing, check whether this session checked off the LAST open block
  of a goal, and whether that was the last goal an open milestone in
  `WSS.record.releases` cites. If so, invoke --wss-plan so the user is ASKED while the
  evidence is in front of them, then name --wss-release if they mark it. Do not
  mark the milestone yourself — that is --wss-plan's, and the mark is what
  authorizes a tag. FROM A LANE WORKTREE, DO NOT ASK AT ALL: a mark is a
  checkpoint for the whole project.
EOF
    ;;
  --wss-start)
    cat <<'EOF'
The user included the `--wss-start` flag. That is an explicit, unconditional
instruction to run the `wss-start` skill — invoke it now, without asking
what to work on or whether to begin.

The rest of the message is scope or emphasis ("--wss-start, stick to the social
block"), not a question to answer first.

Authorization: COMMIT as the work lands, so a compaction cannot lose a finished
lane. NOT push. Wait for the user to say so, or for the user to type --wss-wrap.
Nothing this skill INVOKES may push on its behalf: an invoked skill inherits this
grant, never its own flag's, so closing out goes through handoff-writer for the
handoff, not through wss-wrap for the ritual, and the commits go through
git-writer, which may commit here but not push.

Irreversible, in force before the skill loads:
- Lanes run concurrently in ONE shared working tree, so the unit of parallelism
  is the FILE SET, not the task. Two lanes editing one file do not merge: the
  second write wins and the first lane's work is gone silently. Give every lane
  an explicit list of files it owns, and tell it to stop rather than write
  outside that list.
- At most ONE lane in the whole batch may touch the paths the manifest lists
  under `WSS.lanes.exclusive`, and it runs first and alone.
- NO lane writes a record file. The orchestrator records once, at the end.
- Settle the open-decisions record with the user BEFORE selecting work. An open
  decision does not wait — it gets made silently by whoever writes the first
  line of code that depends on it.
- The test suite runs ONCE, at the end. Where the manifest names a consent
  token, no subagent can supply it, so there is one attempt per session. Do not
  spend it early.
EOF
    ;;
  --wss-release)
    cat <<'EOF'
The user included the `--wss-release` flag. That is an explicit, unconditional
instruction to run the `wss-release` skill — invoke it now, without asking whether
to start.

The rest of the message is context about what is being released, not a question
to answer first.

Authorization: COMMIT. The PUSH is NOT covered by this flag.

Irreversible, in force before the skill loads:
- The precondition is a MILESTONE MARKED COMPLETED in `WSS.record.releases`, written
  by --wss-plan. NOT the roadmap: that record holds goals, splits per lane, and
  carries no mark at all, so a goal being met is not a milestone being complete.
  If it looks complete but is not marked, hand to --wss-plan and come back; do not
  mark it yourself and do not infer the milestone from recent commits.
  Two exemptions, both written down rather than judged: a patch on an
  already-tagged version, and a `WSS.record.releases` that has itself declared an end
  to milestones. The skill's section 1 holds the cases; say which one applies.
- Show the commits, the tag name and the branch, then wait for an explicit OK
  IN THAT TURN before pushing either the branch or the tag. Unlike --wss-wrap and
  --wss-stocktake this flag is not standing authorization to publish: a tag another
  checkout has fetched cannot be recalled.
- Local tags and remote tags are different facts. Reconcile both before
  choosing a version.
- This skill WRITES NOTHING ITSELF. The changelog entry goes through
  changelog-writer and the tag through git-writer, which will not tag unless
  told the OK was given in this turn. Obtaining that OK is what this skill
  contributes; a primitive has no channel to ask a user for anything.
- No --force, no --amend, no --no-verify.
EOF
    ;;
  --wss-pr)
    cat <<'EOF'
The user included the `--wss-pr` flag. That is an explicit, unconditional
instruction to run the `wss-pr` skill — invoke it now, without asking whether
to open one.

The rest of the message is context about what is being merged, not a question
to answer first.

Authorization: COMMIT. The PUSH and the MERGE are NOT covered by this flag —
each needs a fresh OK in that turn. Opening the PR is covered.

Irreversible, in force before the skill loads:
- The precondition is that WSS.branch.integration is ALREADY PUSHED. A PR opened
  over unpushed commits describes a range the reviewer cannot see. If commits
  are local only, stop and say so — pushing them is not this flag's grant.
- Draft the body from `git log origin/<publish>..origin/<integration>`, NEVER
  from what this session remembers doing. A merge publishes the whole branch, so
  name the commits this session did not make — they are the ones a reviewer most
  needs.
- Check for an already-open PR on the same head before creating one. Two PRs
  for one branch is not recoverable by closing one; the review splits.
- READ the CI result before reporting the PR ready. Where the manifest declares
  no WSS.commands.ci, say CI was not checked — that is not the same report as
  saying it passed.
- Never --admin, and never merge past a failing required check.
- Squashing is not a safe default. Where WSS.branch.mergeMethod is undeclared, use
  a merge commit and say so: a squash discards the individual commit messages
  that the history is the record of.
- This skill WRITES NOTHING ITSELF. The merge goes through git-writer, which
  will not merge unless told the OK was given in this turn. Obtaining that OK is
  what this skill contributes; a primitive has no channel to ask a user for
  anything.
EOF
    ;;
  --wss-full-stocktake)
    cat <<'EOF'
The user included the `--wss-full-stocktake` flag. That is an explicit,
unconditional instruction to run the `wss-stocktake` skill at FULL scope —
invoke it now, without asking for confirmation first.

The rest of the message is scope or emphasis, not a question to answer first.

Authorization: COMMIT and PUSH — but the audit's OWN RECORD ONLY.

Irreversible, in force before the skill loads:
- Full scope means audit history is ignored ENTIRELY. Do not read coverage
  baselines out of the audit record and do not skip anything because a previous
  pass covered it. Everything is in scope, including whatever past passes listed
  as not-covered.
- Full scope does NOT mean attempting code analysis inline. That is a
  project-scoped code-analysis skill's, invoked from Phase 1 where one exists;
  where none does, report "no code analysis ran" rather than implying the code
  was examined.
- The push grant does NOT extend to remediation code written afterwards. That is
  ordinary work: commit it and ask.
- Close out through the `wss-wrap` skill rather than pushing by hand, so its
  rails apply — a push publishes a ref, so check what rides along, and never
  force-push or resolve a rejection by force.
EOF
    ;;
  --wss-docs)
    cat <<'EOF'
The user included the `--wss-docs` flag. That is an explicit, unconditional
instruction to invoke the `wss-docs` skill now — do not ask whether to start. Bare,
it means "document what we just worked on": infer the target from the
conversation and say what you picked before writing. With an argument, that is
the target. The rest of the message is scope, not a question to answer first.

Authorization: none. Committing and pushing stay ordinary decisions.

Irreversible, in force before the skill loads:
- Check `.claude/skills/` FIRST. If the project ships its own docs skill, defer
  to it and say so — it encodes conventions this one cannot know. Duplicating a
  project's documentation structure is expensive to unpick.
- Never migrate a project to a different renderer because this skill prefers
  one. Match the setup that exists.
- Never document from inference. Read every file you name; if you cannot find
  why something is the way it is, write "reason unclear" rather than inventing
  a rationale. A plausible-but-wrong doc is worse than no doc, because nobody
  knows which of its claims to distrust.
EOF
    ;;
  --wss-diagram)
    cat <<'EOF'
The user included the `--wss-diagram` flag. That is an explicit, unconditional
instruction to draw ONE diagram of what the message names — or, bare, of what
was just worked on — and land it in the docs site: invoke the `wss-docs` skill
now, and write the result as a page under the site's annex directory
(`docs/annex/` by the site's own convention). The rest of the message is the
subject, not a question to answer first.

Authorization: none. Committing and pushing stay ordinary decisions.

In force before the skill loads:
- The three diagram rules are the style guide's
  (`skills/wss-docs/references/WSS.STYLE-GUIDE.md`) and apply in full: check
  what will render it — docsify needs a plugin the default `index.html` does
  not load, so ASCII in a plain fence is the default; every box and arrow is a
  claim drawn from source you read; and stop before the graph stops being
  readable — a table is often the better answer, and saying so is a valid
  outcome of this flag.
- The catalog's interaction diagram is not this flag's to touch: `--wss-tools`
  draws that one.
EOF
    ;;
  --wss-stocktake)
    cat <<'EOF'
The user included the `--wss-stocktake` flag. That is an explicit, unconditional
instruction to run the `wss-stocktake` skill incrementally — invoke it now,
without asking for confirmation first.

The rest of the message is scope or emphasis, not a question to answer first.

Authorization: COMMIT and PUSH — but the audit's OWN RECORD ONLY.

Irreversible, in force before the skill loads:
- This skill asks WHERE THE PROJECT IS, not whether its code is correct. Its
  dimensions are the record, the project's consistency against its own stated
  conventions, its public interface, and whether the safety nets a release needs
  actually exist. Deep code analysis — correctness, security, the data model,
  test quality — belongs to a PROJECT-SCOPED code-analysis skill, which this one
  invokes when `.claude/skills/` has one. Do not attempt those dimensions
  inline.
- Where the project has NO such skill, say so in the plan and in the report:
  "no code analysis ran". Never let silence imply the code was examined and
  found clean.
- Incremental means resolving each dimension's slice from the audit record and
  re-reading only what changed since the governing baseline. Apply the
  blast-radius rule strictly, WHETHER OR NOT there is a manifest: a changed
  schema or migration voids the narrowing for every dimension, a changed
  dependency manifest or lockfile voids consistency, and anything touching auth,
  roles or ownership widens rather than narrows. `audit.invalidates` and
  `WSS.lanes.*` only ever ADD to that set. The record and safety-net dimensions are
  never incremental. When in doubt, widen.
- The push grant does NOT extend to remediation code written afterwards. That is
  ordinary work: commit it and ask.
- Close out through the `wss-wrap` skill rather than pushing by hand, so its
  rails apply — a push publishes a ref, so check what rides along, and never
  force-push or resolve a rejection by force.
EOF
    ;;
  --wss-overview)
    cat <<'EOF'
The user included the `--wss-overview` flag. That is an explicit, unconditional
instruction to invoke the `wss-overview` skill now — report where the project
stands, read fresh from its records, changing nothing.

The rest of the message is scope or emphasis, not a question to answer first.

Authorization: none — and this skill writes NOTHING: no record, no checkpoint,
no commit. It reads and reports.

Irreversible, in force before the skill loads:
- Every number is read NOW, from the record or command that owns it — never
  carried forward from memory, a handoff card, or an earlier session.
- A record the manifest does not declare is reported as UNDECLARED, never as
  zero. "No backlog is declared" and "the backlog is empty" are different
  facts, and a bare 0 renders them identically.
- A read that needs an unreachable tool or network is reported as NOT CHECKED,
  never omitted — an absent line reads as clean.
- The counts go in the reply and never into a file. A count written into a
  record is a mutable claim, which WSS.RECORD-CONTRACT.md forbids.
EOF
    ;;
  --wss-scout)
    cat <<'EOF'
The user included the `--wss-scout` flag. That is an explicit, unconditional
instruction to invoke the `wss-scout` skill now — consult the project's toolbelt
registry, and where it has no answer, search the stack's public registries for
existing libraries that do or broadly resemble what the rest of the message
describes, and explain the candidates. The rest of the message is the task to
scout for, not a question to answer first.

Authorization: none.

Irreversible, in force before the skill loads:
- ADVISE, do not implement. The deliverable is candidates and an explanation;
  building with the chosen tool is ordinary session work, after.
- Read the toolbelt registry FIRST. A row that matches the task shape answers
  the search before it starts, and skipping the lookup is how a project adopts
  two tools for one job.
- An adoption is a decision: the registry row is written only on the user's
  word, and the reasoning goes through --wss-log, never into the row.
EOF
    ;;
  --wss-alerts)
    printf 'The user included the `--wss-alerts` flag. The hook has already applied it:\n%s\n' "$alerts_msg"
    cat <<'EOF'

Relay that state to the user in one line. There is no skill to invoke and
nothing further to do — the toggle is a machine-local preference the alert
hook reads, not a record.

Authorization: none.
EOF
    ;;
  esac
}

# `--wss-alerts` is served by the hook and takes its argument from the prompt:
# the token immediately after the flag, `on` or `off` (anything else reports
# the current state). Applied HERE, deterministically, before the blocks are
# emitted — so what the block reports is what has already happened, not an
# instruction that might be reinterpreted.
ALERTS_STATE="$CONFIG_DIR/WSS.ALERTS-ON"
alerts_msg=''
if [ -n "${seen[--wss-alerts]:-}" ]; then
  alerts_arg=''
  for ((i = 0; i < n; i++)); do
    if decompose "${tokens[$i]}" 2>/dev/null | grep -qx -- --wss-alerts; then
      case ${tokens[$((i + 1))]:-} in on | off) alerts_arg=${tokens[$((i + 1))]} ;; esac
      break
    fi
  done
  case $alerts_arg in
    on)
      if : > "$ALERTS_STATE" 2>/dev/null; then
        alerts_msg='Sound alerts are now ON for this machine.'
      else
        alerts_msg="Sound alerts could NOT be enabled: $ALERTS_STATE is not writable."
      fi ;;
    off)
      rm -f "$ALERTS_STATE" 2>/dev/null || true
      alerts_msg='Sound alerts are now OFF for this machine.' ;;
    *)
      if [ -f "$ALERTS_STATE" ]; then
        alerts_msg='No argument given — sound alerts are currently ON here. `--wss-alerts on|off` toggles.'
      else
        alerts_msg='No argument given — sound alerts are currently OFF here. `--wss-alerts on|off` toggles.'
      fi ;;
  esac
fi

blocks=""
claimed=()
for f in "${ordered[@]}"; do
  [ -n "${seen[$f]:-}" ] || continue # dropped by the audit-scope rule above
  flag_skill=$(skill_for "$f")
  # `-` is served by this hook itself, so the two gates below do not apply — and
  # must not: gating the flag list on a skill existing would make it silent in
  # exactly the configuration where a user most needs to ask what is available.
  if [ "$flag_skill" != "-" ]; then
    skill_exists "$flag_skill" || continue
    skill_disabled "$flag_skill" && continue
  fi
  claimed+=("$f")
  blocks="${blocks}${blocks:+

}$(block_for "$f")"
done

[ ${#claimed[@]} -eq 0 ] && exit 0

# More than one flag is a sequence, not a choice — say so, because each block
# below reads as if it were the only instruction in the turn.
preamble=""
if [ ${#claimed[@]} -gt 1 ]; then
  preamble="The user included several flags: ${claimed[*]}. Every one of them is an
unconditional instruction. Carry out ALL of them, in the order listed here —
which is the order they were typed — and treat each as fully in force rather
than letting a later one cancel an earlier one. Where two overlap (an audit and
a wrap both wanting to commit and push, say), do the shared step once, at the
point the last flag that needs it calls for it, and make sure it satisfies
every flag's rules — the strictest constraint wins.

"
fi

CONTEXT="${preamble}${blocks}

The flag tokens themselves are for this hook, not part of the request. Ignore
them when interpreting what the user actually wants."

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

exit 0