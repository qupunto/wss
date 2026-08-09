# Overview

What the repository contains, what a Claude Code session loads from it and when,
and how to check that any of it is working.

## The stack, such as it is

There isn't one. No package manager, no dependencies, no build step, no runtime.
The project is markdown instruction files plus a small set of POSIX shell scripts
— `git ls-files '*.sh'` is the list, deliberately, because a count written here
has already gone stale once — and CI runs `bash -n`, `shellcheck`, `jq` and a
hand-written test harness.

That is a deliberate constraint rather than an accident of youth: the artifact is
a *configuration directory* that must be adoptable on a machine that has nothing
installed, and every dependency added is a dependency an adopter has to satisfy
before a single skill runs.

## Layout

```
~/.claude/
│
├── settings.json          hooks and permissions — the file that wires everything
├── CLAUDE.md              loaded into EVERY session of EVERY project
├── README.md              adopting the repo, and what each `--flag` does
├── LICENSE
│
├── wss-doctor.sh              read-only health check — see "Verifying" below
├── wss-reset-records.sh       blanks the records to their headings — what makes a fork yours
├── wss-export-records.sh      moves machine-local state between machines by archive
├── wss-retire-workflow.sh     the tidy exit — removes the machinery, and only on request the records
├── wss-remove-lanes.sh        turns worktree-lane mode off for one checkout — never touches a record
├── wss-publish.sh             assembles and gates the public tree; deliberately never pushes
│
├── hooks/                 the hook scripts, and the hooks.json a plugin needs
│   ├── wss-shorthand-flags.sh   UserPromptSubmit — `--flag` to invocation
│   ├── wss-session-check.sh     SessionStart — see "The hooks" below
│   ├── wss-alert.sh             Notification/Stop — opt-in sound cue, `--wss-alerts on|off`
│   └── hooks.json           read only when installed as a plugin
├── .claude-plugin/        plugin.json and marketplace.json — installable, and its own marketplace
│
├── commands/              slash-command wrappers: the filename is the flag it fires
├── skills/                the global suite; available in every project
├── workflow/              the contracts every skill links to instead of copying
│
├── .claude/WSS.WORKFLOW.json  the manifest — which file plays which record role
├── .claude/WSS.HANDOFF.md     WSS.record.handoff, mapped away from CLAUDE.md
├── .claude/WSS.HAZARDS.md     the standing hazards, split out of the handoff
├── .claude/WSS.TOOLING.md     WSS.record.tooling.catalog — source for the annex page
├── .claude/WSS.SWEEPS.json    the sweep checkpoint cache — gitignored, machine-local
├── WSS.TODO.md                WSS.record.todo
├── WSS.ROADMAP.md             WSS.record.roadmap — goals; splits by lane, carries no version
├── WSS.RELEASES.md            WSS.record.releases — milestones, versions, and what authorises a tag
├── CHANGELOG.md           the public user-facing log — not a record, ships as written
├── WSS.CHANGELOG.md       WSS.record.changelog — the engineering log
│
├── audits/                frozen agent audit reports — the maintained index is `docs/WSS.AUDITS.md`; `audits/README.md` points there
├── tests/                 the hook contract tests, whose breakage is silent
├── .github/workflows/     CI
│
└── docs/                  this site — and the decision log, its generated index, and the open-decision, stocktake and audit-index records
```

`workflow/` sits outside `skills/` on purpose. A directory under `skills/` with
no `SKILL.md` is ignored today, but relying on that is a bet on Claude Code's
discovery internals rather than on documented behaviour.

**Every `WSS.record.*` path in that tree is named by `.claude/WSS.WORKFLOW.json` rather
than by convention**, and that manifest is the first file both `--wss-adopt` and
`wss-doctor.sh` resolve against — which is why a repo running the workflow on itself
needs one at all. A project without a manifest still works: skills fall back to
the conventional names in `workflow/WSS.MANIFEST.md` and skip what they cannot
resolve. The fallback worth knowing is `WSS.record.handoff`'s, which is
`WSS.HANDOFF.md` — a file the harness never loads on its own, so
`wss-session-check.sh` injects whatever the handoff resolves to, declared or
fallback, whenever that file exists and is not `CLAUDE.md`. This repo maps it
to `.claude/WSS.HANDOFF.md`.

## What a session loads, and when

This is the part that decides what everything costs, because a byte in one place
is paid for far more often than a byte in another.

| Loaded | When | Consequence |
|---|---|---|
| `CLAUDE.md` | every session, every project — **in the checkout form only** | the most expensive file in the repo, and unread entirely as a plugin |
| Each skill's frontmatter `description` | every session | it is what decides whether the skill is ever invoked |
| A skill's **body** | only when that skill is invoked | length here is cheap by comparison |
| `skills/wss-docs/references/*.md` | only when the `wss-docs` skill reads one | reference detail belongs here, not in a body |
| A `wss-shorthand-flags.sh` block | when its flag fires — minus the worktree-lane paragraphs, unless the checkout is in lane mode | injected into the prompt |
| The project's `WSS.record.handoff` — or just its **card**, where the file carries a `<!-- handoff:card-ends -->` marker | every session in **any** project whose resolved handoff — declared, or the `WSS.HANDOFF.md` fallback when the key or the manifest is absent — is an existing file other than `CLAUDE.md`, via `wss-session-check.sh` | so *card* length is the permanent per-session cost of adopting, not file length. Without the marker the whole file is injected, which is what the split exists to escape |

Two rules follow. **A description must carry every case that should trigger the
skill, and nothing else** — no procedure summary, no inventory of callers, since
routing to a skill happens from the calling skill's body rather than from the
callee's description. And a "not for X" clause is the expensive kind of mistake:
it cannot be caught by using the skill, because its effect is that the skill is
never used, so the body that would correct it never loads.

Measured, the always-loaded floor is `CLAUDE.md` plus the sum of every skill
description — paid in every session of every project before anything happens;
`wss-doctor.sh`'s description-budget line prices the current sum. A skill body is
paid only when invoked, which is why detail belongs there and not in a
description.

## What can be switched off, and what cannot

The lever above has a hard limit, and which shape the suite is in decides whether
you have it at all.

**As a checkout**, `skillOverrides` in `settings.json` controls each skill
individually, and `/wss-toggle` is the slash-only editor of exactly that block
— it lists effective levels, refuses a level that would break a
dispatch-reached skill, and warns when a change silences a flag. This
repository uses two levels: `name-only` for a skill a session cannot usefully
be routed to by description yet must stay dispatch-reachable, and
`user-invocable-only` for the heavyweights the owner invokes by slash alone —
under which a skill's *flag* is deliberately inert as well, since the flag
hook honours the same override. Read the current set out of
`settings.json` rather than a count here; it shrank once already, when the
record procedures left `skills/` for `workflow/writers/` and stopped being
skills at all. `wss-doctor.sh` guards the arrangement: its dispatch-only check (the
`dispatch-only skills vs overrides` section) warns when a skill no flag maps to
has no override entry, and
its pass line names how many skills it *examined* — every one with a `SKILL.md`,
not the dispatch-only subset it warns about — **so read that line rather than the
summary**, and read it as scope rather than as a count of what it found. The policy is never `off` for these — `off` blocks *model*
invocation, which is the only kind a dispatched skill ever gets, so it would not
trim the skill but break it. The warning text states that policy; the check
itself only tests that an entry exists and never inspects its value.

**Two values disable, not one.** `skill_disabled()` returns true for `off` *and*
for `user-invocable-only`, and it reads `$PWD/.claude/settings.json` before the
config directory's — so a project can disable a skill the user enabled globally.

**As a plugin, none of that reaches the skills.** `skillOverrides` is ignored for
plugin skills at `off` as well as `name-only`, under bare and namespaced keys
alike. The Claude Code documentation states it outright — *"Plugin skills are not
affected by `skillOverrides`. Manage those through `/plugin` instead"* — and what
`/plugin` manages is plugins: `claude plugin disable <name>` takes every skill in
one with it.

**This suite is one plugin**, so once it is distributed that way, installing it
brings every skill with no way for the harness to decline any of them.

**The flags are the exception, and they are in-suite rather than harness.**
`skill_disabled()` in `hooks/wss-shorthand-flags.sh` reads `skillOverrides` out of
`settings.json` itself, so `off` still stops that skill's *flag* firing under a
plugin install — the skill stays callable by name, the shorthand does not fire.
Half a disabled skill, and the half a user reaches for most. What is genuinely
absent is harness-level per-skill selection, since `skillOverrides` was the
mechanism that would have used. **The rejected alternative was shipping
several plugins by dependency group**, which would have made the group the unit of
choice; it was tried, proven to work, and dropped because the suite's skills reach
their shared contracts by relative link and every one of those would have had to
be re-anchored across plugin boundaries. [`docs/WSS.DECISIONS.md`](WSS.DECISIONS.md)
carries both decisions and what each cost.

One thing this is *not*: the overrides and the `wss-doctor.sh` check are **not dead
code**. They are correct for the checkout shape, which stays supported.

**A second, unrelated way the forms differ: a plugin root's `CLAUDE.md` is not
loaded as project context at all.** `claude plugin validate` says so and suggests
a skill instead. So an adopter who installs rather than clones would get no
statement that the workflow is global, that skills read `.claude/WSS.WORKFLOW.json`,
or where the three contracts are — none of which is inferable from a skill body.
That is what `wss-contracts` carries, and why `CLAUDE.md` now holds the
contract paths and a pointer rather than the rules themselves: one owner, in the
form that can actually reach both. The warning does not go away, because it fires
on the file existing at the plugin root rather than on what is in it.

Writing that skill turned up a plain defect alongside the two costs. `CLAUDE.md`
named the contracts as `~/.claude/workflow/*.md`, which resolves to nothing under
a plugin install — the suite sits at `${CLAUDE_PLUGIN_ROOT}` while `~/.claude`
holds the adopter's own settings. `wss-doctor.sh` had resolved both forms correctly
since the conversion; the prose had not. The skill links them relatively, as the
rest of the suite does.

**What is and is not built.** Both forms are built and both are installable.
`.claude-plugin/plugin.json` and `hooks/hooks.json` exist, `claude plugin
validate` passes, and since 2026-08-02 the published repository —
`qupunto/workflow-secretary-suite` — is public and is its own marketplace:
`.claude-plugin/marketplace.json` names the repository root as its plugin
source, so the marketplace-add and plugin-install commands name the same place
and there is no second repository to keep in step. The checkout remains the
route for developing, forking or auditing the suite. `claude plugin marketplace
add` also accepts a local path, so a `git archive HEAD` copy can be installed
and measured without publishing anything — which is how the costs described above
were taken.

## The hooks

The events wired in `settings.json` all fail *silently* when
misconfigured — the event fires, nothing happens, and behaviour degrades without
an error.

The scripts live in `hooks/`. Installed as a plugin the wiring comes from
`hooks/hooks.json` instead, which declares the same events against
`${CLAUDE_PLUGIN_ROOT}`; plugin hooks **merge** with the user's rather than
replacing them, so an adopter's own hooks keep firing.

- **`UserPromptSubmit` → `hooks/wss-shorthand-flags.sh`.** Turns a `--flag` into an
  explicit instruction to invoke a skill. Without it, every flag falls back to
  being matched from a skill description, which is reliable in practice but not
  guaranteed. A flag counts anywhere in the message; what gates it is exact
  decomposition — a token must split entirely into flags, so a pasted
  `git branch --track origin/dev` or a `--wss-wrapper` fires nothing. What a
  block *contains* is gated a second time: `lanes_named_()` withholds the
  worktree-lane paragraphs (today, `--wss-plan`'s) unless `.claude/WSS.LANE`
  exists or the manifest declares a non-empty `WSS.lanes.named`, so a project
  with no worktrees never pays for instructions that cannot fire there.
- **`SessionStart` → `hooks/wss-session-check.sh`.** Silent when there is nothing worth a
  session's attention, because its output is injected into every session's
  context — a chatty version would be both a permanent token cost and a warning
  nobody reads. It speaks on a `wss-doctor.sh` **failure** (warnings are routinely
  benign, and a dirty tree reported every session would train the reader to skip
  the whole block); on a sweep checkpoint 40 commits behind `HEAD`; on open
  decisions unchanged for 25 commits, or a backlog or roadmap unchanged for 80 —
  but only for records the project's manifest actually *declares*, and only
  while the file has entries at all, since an empty open-decisions log is the
  normal state and nudging about it is exactly what would teach a reader to skip
  this block; and never for a backlog that names a provider rather than a file,
  because "unchanged for N commits" cannot be asked of a set of issues that
  leaves no trace in this repository's history; and on an open entry in `WSS.BUG-REPORTS.md`, which nothing else
  surfaces because the file is gitignored. It also counts **open issues on the
  suite's public repository**, but only from a session standing in the suite's
  own checkout — that is the one place triage can act, and the gate keeps a
  network call out of every other project's session start. An unreachable read
  says the repository was *not checked* rather than going silent, since silence
  would make "unreachable" and "zero" identical. Age is counted in **commits, not dates** — no date
  semantics exist anywhere else in this workflow, and a hook is the wrong place
  to introduce one. Two outputs are not warnings at all. It injects the project's
  handoff — the declared path, or the `WSS.HANDOFF.md` fallback where the key
  or the whole manifest is absent. It stays silent only where the resolved
  handoff *is* `CLAUDE.md` (the harness has already loaded it, and injecting
  would put the same file in context twice), where the resolved file does not
  exist, or where a manifest is present but unreadable. And **the first session
  after a plugin install gets one orientation block**, since a plugin has no
  channel to speak at install time and `SessionStart` is the documented
  alternative; it is gated by a marker in the config directory rather than under
  the plugin root, so it survives a plugin update, and where that directory is
  unwritable the notice repeats rather than being lost. Plugin form only — a
  checkout user has `README.md`. Read the script for the
  current thresholds; it is the authority and this page describes it.
- **`Notification`, `Stop`, `PreToolUse(AskUserQuestion)` → `hooks/wss-alert.sh`.** An
  opt-in sound cue when the session waits for input. Silent until a machine runs
  `--wss-alerts on`, which the flag hook serves itself by writing a state file in
  the config directory; one cue per burst of events, sound only, never blocking —
  it always exits 0 and prints nothing.

Because the failure is silent, `wss-doctor.sh` checks the wiring rather than assuming
it. That state persisted unnoticed on one machine for weeks.

## Verifying

```bash
./wss-doctor.sh                    # read-only; prints every check it performs
bash tests/wss-hook-contract.sh    # the hook's contract
```

**Run these rather than trusting any list written in markdown, including this
page.** The doctor has caught classes of drift that reading did not: an
unadopted checkout, dangling citations that read exactly like live ones, a
manifest key no skill reads, a `.gitignore` silently refusing to track new
files, and bugs in itself twice.

It also checks the invariant this suite rests on that nothing else can: that
each `--flag`'s stated grant matches between the hook that fires it and the
ownership matrix — two hand-written copies of the same fact.

## Key files

- `hooks/wss-shorthand-flags.sh` — the `FLAGS` array is the set of tokens the hook will
  decompose a run into; each flag's *grant* is written into the block it
  injects, not into the array. The list of flags is restated for different
  readers in `README.md`, `workflow/WSS.OWNERSHIP.md`, `.claude/WSS.TOOLING.md` and
  [the annex](annex/WSS.CLAUDE-TOOLING.md), so treat none of those as the source.
  The grants are restated in exactly one other place — `workflow/WSS.OWNERSHIP.md` —
  which is what makes the pair comparable at all; see "Verifying" above.
- `wss-doctor.sh` — read-only. It never writes, so it is always safe to run.
- `workflow/WSS.OWNERSHIP.md` — the authority on who may write what. It settles any
  disagreement between two skills.
- `workflow/WSS.RECORD-CONTRACT.md` — what each record file holds and must not hold.
- `workflow/WSS.MANIFEST.md` — which keys a project's `.claude/WSS.WORKFLOW.json` may
  set, and what each falls back to when absent.
