# Workflow Secretary Suite

> **Suite-maintained.** This repository's manifest maps this file to
> `WSS.record.reference`, so `reference-writer` keeps it current and may rewrite
> sections of it. That mapping is deliberate — it is also the landing page — and
> it is *opt-in*: the suite writes a `README.md` only where a manifest names
> one. Your project's README is not touched unless you ask for it.
> Release notes for users are [`CHANGELOG.md`](CHANGELOG.md); the engineering
> log is `WSS.CHANGELOG.md`.

A suite of Claude Code skills that keep a project's record, roadmap, docs and
tooling honest — a secretary to coding, not the coder. Anything needing stack
knowledge — architecture, correctness, security, the data model — is
deliberately not here.

## Two ways to run it

**As a plugin**, if you want the skills in your own projects and nothing else:

```bash
claude plugin marketplace add qupunto/wss --scope project
claude plugin install wss --scope project
```

This repository is its own marketplace — `.claude-plugin/marketplace.json` sits
beside the plugin manifest and names the repository root as the source — so the
two commands above name the same place, and there is no second repository to
keep in step with this one.

**`--scope project` is written out because both commands default to `user` and
neither asks.** Only the interactive `/plugin` menu prompts; drop the flag and
the CLI installs the suite for every project on the machine without saying so.
It belongs on *both* — a project-scoped install pointing at a user-scoped
marketplace resolves on your machine and nowhere else, so it will not travel
with the repository you are adopting.

Project scope is the one to reach for first because this suite keeps *a
project's* record: its manifest, backlog, decision log and handoff all live in
the repository, so the machinery that reads them belongs there too. Drop the
flag from both commands if you would rather have the skills everywhere; `local`
is the third option, meaning this machine and this project, written to nothing
tracked. If you have already installed at the wrong scope,
`claude plugin uninstall` and `claude plugin marketplace remove` undo both
halves before you redo them.

That gives you every skill and both hooks, merged with whatever config you
already have — a plugin never owns your `settings.json`. The one thing it costs
you is granularity: **plugin skills are all-or-nothing.** `skillOverrides` does
not reach them, so it is the whole suite or none of it, and `claude plugin
disable` is the only switch. That was a deliberate trade for one manifest, one
version and cross-links that keep working; the reasoning is in the decision
log — which in a published copy of this repository ships blank on purpose,
like every record, so the full entry is only readable from the development
tree.

**As a checkout**, if you want to develop, fork or audit the suite: it becomes
your `~/.claude`, and you get the tests, the docs site and the records too. Go
to [Adopting the repo on a new machine](#adopting-the-repo-on-a-new-machine).
Per-skill control works in this form.

Everything immediately below describes the checkout. An installer never touches
any of it.

## The checkout form

**This repo *is* `~/.claude`.** It does not install into that directory; the
directory is the working tree. `.gitignore` is inverted for that reason: it
ignores `*` and then re-includes only what is genuinely configuration —
`git ls-files | xargs cat | wc -c` is the figure rather than any number written
here — because `~/.claude` is otherwise hundreds of megabytes of machine-local
state
— transcripts, auto-memory, caches, session bookkeeping — that must not travel,
and in one case (`.credentials.json`) must never leave the machine at all.

## What's in it

| Path | What |
|---|---|
| `settings.json` | Permissions and hook wiring |
| `hooks/wss-shorthand-flags.sh` | `UserPromptSubmit` hook — the `--flag` shorthands |
| `hooks/wss-session-check.sh` | `SessionStart` hook — the only thing here that speaks unasked, so it is built to stay silent unless something is worth a session's attention: a `wss-doctor.sh` failure, a sweep or a record gone stale, an open bug report, an unread upstream filing (counted only in the suite's own checkout). It also injects the project's handoff wherever the resolved file is not `CLAUDE.md` — a declared mapping, or the `WSS.HANDOFF.md` fallback when the key or the manifest is absent — since the harness loads only `CLAUDE.md` on its own |
| `hooks/wss-alert.sh` | `Notification`/`Stop`/`PreToolUse(AskUserQuestion)` hook — a sound cue when a session waits for input. Ships silent; `--wss-alerts on\|off` toggles it per machine via a state file in the config directory |
| `hooks/hooks.json` | Wires those same events when this is installed as a plugin instead of cloned. `settings.json` is the user's in that case and a plugin never owns it; plugin hooks merge with the user's rather than replacing them |
| `.claude-plugin/plugin.json` | The plugin manifest. `claude plugin validate` reads it |
| `wss-doctor.sh` | Read-only health check for this config and the current project. Stays at the root rather than moving into `hooks/`, because it is run by hand as often as by the hook |
| `wss-reset-records.sh` | Blanks every record the manifest declares back to its heading. Dry-run by default; `--write` to do it. What makes a fork yours rather than an inheritance — see below |
| `WSS.BUG-REPORTS.md` | Inbox for defects in this config found from *other* projects. Gitignored, so it is not in the repo — `wss-doctor.sh` surfaces open entries |
| `skills/` | User-level skills, available in every project |
| `commands/` | Slash-command wrappers for the flags whose skill carries a different name — a wrapper's name tracks the flag it fires, so `/wss:todo` autocompletes and fires `--wss-todo`. (Installed as a plugin the wrapper is `/wss:todo`, because the namespace supplies the prefix; the flag is `--wss-todo` in both forms.) `wss-doctor.sh` asserts every wrapper fires the flag its name promises |
| `.claude/skills/` | Where a project's own skills go, resolved before the global suite. This repo keeps none — see the annex for why both of the ones it had turned out to be global concerns with local paths baked in |
| `workflow/` | The authority files every skill links to instead of carrying its own copy — who may write what, what each record holds, which manifest keys exist, and how a sweep narrows itself — plus the record-writer procedures under `workflow/writers/` and the shared check methods under `workflow/checks/` |
| `workflow/providers/` | Where a record lives somewhere that is not a file. Only `WSS.record.todo` takes one, and `WSS.GITHUB-ISSUES.md` is the only one that exists — see below |

## What you can turn off, and what you cannot

**As a checkout** — cloning into `~/.claude`, which is what the section below
does, and the form this suite is developed in — `skillOverrides` in
`settings.json` controls each skill individually, and `/wss:toggle` is the
slash-only editor of that block. This repository uses two levels: `name-only`
for dispatch-reached skills (the description unloads, the dispatch still
works) and `user-invocable-only` for heavyweights invoked by slash alone —
under which the skill's *flag* is deliberately inert too, since the flag hook
honours the same override. `wss-doctor.sh` warns when a skill no flag maps to
has no entry. Read the current set out of `settings.json` rather than a count
here.

**As a plugin, the harness ignores that lever** — `skillOverrides` does not reach
plugin skills, at `off` as well as `name-only`, under bare and namespaced keys
alike. The documentation states it directly: *"Plugin skills are not affected by
`skillOverrides`. Manage those through `/plugin` instead."* What `/plugin`
manages is plugins, and `claude plugin disable <name>` takes every skill in one
with it.

**But `off` is not inert here, and this is the sharp edge.** The `--flag` hook
does its own check and honours `skillOverrides` in either form, so setting a
skill to `off` under a plugin install **stops its flag firing while leaving the
skill itself perfectly callable** by name or by the model's own judgement. You
get half a disabled skill: the deterministic route is gone, the non-deterministic
one is not. Measured on a real install rather than reasoned about.

That is the safe half to lose if you are going to lose one — a flag that does
nothing is visible, where an injected instruction for a skill the harness refuses
to run is not. But do not reach for `off` under a plugin expecting it to do
nothing, and do not reach for it expecting it to work either. `name-only` behaves
as documented in both forms: the flag still fires, only the description is
trimmed.

**This suite is one plugin**, so installing it brings every skill and every flag,
and the only whole-hog lever is removing it. Decide whether you want the suite
entire before installing it — and run `claude plugin details` to see the
always-on cost, rather than counting bytes.

**That lever is worth roughly what the overrides save** — measured on
2026-08-01 at about a third of the always-on cost, an excess since shrunk by
the record procedures leaving `skills/`; the structure holds even where the
figure has moved.

Neither the overrides nor the `wss-doctor.sh` check that guards them is dead code —
both are correct for the checkout shape, which stays supported. And
`claude plugin marketplace add` accepts a local path as well as a repository, so
you can install and measure a fork without publishing anything.

## The original, and why the records may be empty

This workflow is developed in a **private repository that runs it on itself** —
the same skills keep that repo's own backlog, decision log and handoff current.
That is the only test of a project secretary worth anything: a suite that cannot
keep its own record straight has no business keeping yours.

But what those records *say* is about that repository. So a published copy ships
them **present and empty**, carrying only their canonical heading. Which files
those are is `wss-reset-records.sh`'s `RECORDS` table plus any overflow sibling a
handoff declares — read the script rather than a list here, since a list is one
record away from being wrong and this one already was. Empty rather
than absent, because `wss-doctor.sh` fails on a declared record whose file is missing,
and a fresh clone has to pass its own health check.

**Read that emptiness as a decision, not an omission.** Shipping the populated
originals as a worked example was the obvious alternative and was rejected: a
session in your clone would read that backlog and *believe* it — `--wss-start` would
pick work off someone else's project, and `--wss-check` would verify those claims
against the wrong repository. `--wss-adopt`'s own rule applies, that the owning skill
writes the first real line so that it is a true one.

**If you fork this, or inherit records from anywhere, run `wss-reset-records.sh`.**
It blanks every record the manifest declares back to its heading, and it is the
same script the publishing step runs, so the state you get is the state a fresh
install gets. It is a dry run unless you pass `--write`:

```bash
./wss-reset-records.sh              # list what would be blanked, change nothing
./wss-reset-records.sh --write      # do it
```

It never touches `README.md` or `.claude/WSS.TOOLING.md` even though the manifest
calls them records — those describe the **tooling**, which is the part that
should travel. And where `WSS.record.todo` names a GitHub Issues provider rather than
a file, it skips it and says so: emptying somebody's issue tracker is not a thing
a reset script gets to decide.

## The backlog does not have to be a file

Every record above is a markdown file, with one exception. A team already living
in GitHub Issues cannot adopt a workflow whose backlog is a file — they would be
maintaining two, and the second one loses. So `WSS.record.todo` alone may name a
**provider** instead of a path, and then `--wss-todo` files an issue, `--wss-start`
reads the open ones, and `--wss-wrap` counts them:

```json
"record": { "todo": { "provider": "github-issues", "repo": "owner/name", "label": "backlog" } }
```

Declare a `label` unless you genuinely mean *every* open issue including user bug
reports. `wss-doctor.sh` checks the provider is implemented and the repo resolves, and
fails rather than quietly writing to a file instead.
[`workflow/providers/WSS.GITHUB-ISSUES.md`](workflow/providers/WSS.GITHUB-ISSUES.md) is
the authority on the mapping — closing an issue is how an item leaves the
backlog, and an issue without the label is somebody else's.

**Nothing else takes a provider**, deliberately: the decision log and open
decisions are prose read months later, and an issue thread is a conversation.
And be aware of the maturity gap — **the file form is the battle-tested path**,
used by the suite on its own repository since the beginning; the provider is
newer and has
far fewer miles on it. `--wss-adopt` offers the choice when it finds open issues.

## Adopting the repo on a new machine

`~/.claude` already exists and holds live state, so `git clone` into it will
refuse. Adopt it in place instead:

**Do these in order, and do not skip step 3.** Steps 1 and 3 are a pair: the
first closes the window where your credentials are stageable, and the second
re-opens the guard that stops the checkout overwriting your own files. Running 1
without 3 is worse than running neither.

```bash
cd ~/.claude

# 1. PROTECT FIRST. Between `git init` and the checkout there is no .gitignore
#    in the working tree, so git sees the entire directory as untracked —
#    including .credentials.json. This exclude is local-only and takes effect
#    immediately.
git init
printf '%s\n' '*' '!.gitignore' > .git/info/exclude
git status --porcelain          # MUST be empty. If it lists anything, stop.

# 2. POINT AT THE REPOSITORY. A public clone needs nothing but this.
#    If your copy is PRIVATE, run `gh auth setup-git` first to supply the
#    token: a bare https remote against a private repo fails with "Repository
#    not found", which reads like a typo, so you would debug the URL instead
#    of the credentials.
git remote add origin https://github.com/<owner>/<repo>.git
git fetch origin

# 3. NARROW THE PROTECTION BEFORE CHECKING OUT. While `*` is excluded git
#    treats your existing files as *ignored*, and checkout overwrites an
#    ignored file without a word — it only refuses on *untracked* ones. So
#    leaving step 1's exclude in place silently destroys your settings.json,
#    your CLAUDE.md and any skill whose name collides, none of which were ever
#    committed anywhere. Narrow it to the one file that must never be staged.
printf '%s\n' '.credentials.json' > .git/info/exclude
git status --porcelain          # now lists YOUR files as untracked. Expected.

# 4. Check out. The branch is `main`. It will now REFUSE on any collision,
#    which is what you want — see below.
git checkout -b main --track origin/main

# 5. Drop the stopgap — the real .gitignore governs from here — and confirm.
#    The `||` branch matters: `check-ignore -q` prints nothing whether it
#    succeeds or fails, so without it a failure is indistinguishable from
#    success.
: > .git/info/exclude
git check-ignore -q .credentials.json \
  && echo "credentials ignored: ok" \
  || echo "STOP. .credentials.json is NOT ignored — do not run 'git add'."

# 6. Hooks are useless unless executable. They live under hooks/, not at the
#    root — a *.sh glob at the root would silently skip them.
(cd ~/.claude && chmod +x $(git ls-files '*.sh'))
~/.claude/wss-doctor.sh    # doctor:checkout-only — this block is building the checkout
```

**Step 4 will stop on any file that already exists locally and differs** —
`settings.json` is the usual one, since a machine that has been used has hooks
of its own. Move it aside, retry, then diff the two and merge by hand. There is
no safe automatic merge: one side may carry machine-specific paths the other
must not inherit.

If the local `skills/` already holds a skill that is also in the repo, the same
applies. Move it aside rather than letting the checkout fail, then compare.

**Do not skip `wss-doctor.sh`.** A hook that is missing, unwired or non-executable
fails *silently* — the event fires, nothing happens, and every `--flag` quietly
degrades to being matched from a skill description instead of being injected
deterministically. That state persisted unnoticed on one machine for weeks.

### Machine-local state does not clone — export it

A clone brings every tracked file and nothing else. What it leaves behind on
the old machine: record files a project keeps **untracked**, the `.claude/WSS.LANE`
worktree selector, and — in the config directory — `WSS.BUG-REPORTS.md`, the one
file whose loss is unrecoverable. `wss-export-records.sh` moves exactly that set:

```bash
wss-export-records.sh                      # on the old machine, per project
wss-export-records.sh --import <archive>   # on the new one, after the clone
```

It skips tracked records (the clone brings them) and the sweep checkpoint (a
cache) — except under `--all`, the retirement snapshot, which keeps tracked
records in and adds the docs tree. It refuses archive entries that escape the
project, and refuses to overwrite a non-empty file unless given `--force`. `--wss-adopt` runs the import
when handed an archive during adoption.

### Stopping cleanly — `/wss:retire`, or the script it drives

`claude plugin uninstall wss` removes the skills and hooks and
touches no project — the manifest, sweep cache and records a project
accumulated all stay behind. **`/wss:retire` is the guided exit**, run per
project: one checkbox dialog — a full snapshot (`WSS.RETIREMENT-PLAN.tar.gz`,
made by `wss-export-records.sh --all`, restorable at re-adoption) asked first,
then the actions to run — delete the machinery, delete the records, wipe the
records, uninstall the plugin — executed in dependency order. It is
slash-invoked only and has no `--flag`: a deletion should never fire because a
sentence contained the right words.

`wss-retire-workflow.sh` is the script underneath, usable on its own, dry-run
by default:

```bash
wss-retire-workflow.sh            # show what would go
wss-retire-workflow.sh --write    # remove the machinery: manifest, sweep cache, lane selector
wss-retire-workflow.sh --write --records   # ...and the workflow-shaped records
```

Records hide behind the second flag because they hold the project's own
knowledge, and some files never go whatever the flags: the reference docs
(usually the README), the changelog, the tooling files, and a handoff living
in `CLAUDE.md`. Export first if in doubt.

## Adding anything to this repo

**`.gitignore` ignores `*` and re-includes by name**, so a new *kind* of file is
invisible by default and `git add` says nothing when it declines one. This has
already cost `README.md` and `docs/`, which could not be committed at all until
they were whitelisted.

So after adding a new top-level path, verify rather than assume:

```bash
git status --porcelain          # your new file must appear
git check-ignore -v <path>      # and this must find no rule ignoring it
```

That bias is correct for a directory that also holds `.credentials.json` — the
cost is one check whenever the shape of the repo changes.

## The `--flag` shorthands

`hooks/wss-shorthand-flags.sh` injects an explicit instruction for each flag, so
invoking a skill by flag is deterministic rather than a judgement call.

**Type `--wss-flags` to get this list from the hook itself**, computed at run time
and marked up with what actually resolves where you are standing. `--wss-help` does
the same, and `--wss-alerts on|off` is the third flag the hook serves without a
skill — it toggles the sound cue `hooks/wss-alert.sh` plays when a session waits
for input. Everything below is the curated version — which one you want, and how
often — and it is the only part of this section that a machine does not generate.

### Which flag do I want?

Five of them ask a similar-sounding question and are routinely confused. The
difference is **what they read**, not how hard they try:

| You want to know | Flag | Reads | Writes |
|---|---|---|---|
| Where do we stand, at a glance? | `--wss-overview` | branch and lane, record counts, sweep freshness, nearest milestones — fresh, never from memory | nothing at all — the report is the reply |
| Is what we wrote down still true? | `--wss-check` | the records only, and only those whose code moved | nothing — dispatches to each record's owner |
| Is the whole configuration sound? | `--wss-full-check` | records + the docs site + the tooling files, every one, ignoring checkpoints | nothing with an owner; fixes unowned files directly |
| Where is this project? | `--wss-stocktake` | all of the above plus conventions, public surface, safety nets, and the code via the project's own analysis skill | rebuilds the backlog, writes an audit entry |
| Is this document true and well-formed? | `--wss-docs` | one docs site — paths, links, anchors, claims against source | the pages it fixes |

`--wss-full-check` is **not** a bigger `--wss-check`. It is `--wss-check` plus five unrelated
jobs — the docs site, the tooling files, the defect inbox, the prune, the
catalog refresh. Reach for it when you distrust the configuration, not when you
want a thorough record sweep.

Running two of them against one request pays twice for the same answers, so the
hook drops the narrower flag when a wider one is present: `--wss-full-check` absorbs
`--wss-check`, and either stocktake absorbs it too. `--wss-docs` and `--wss-tools` are never
dropped, because each has a second job that is a *write* request and silently
skipping one to save a read is the wrong way to be wrong.

### How often

A cadence that has held in practice. None of it is enforced — nothing here
nags, and the SessionStart hook only speaks when a checkpoint has fallen far
behind.

| When | Flag | Why then |
|---|---|---|
| Starting anything non-trivial | `--wss-track` | before the work, so the list is the plan rather than a summary |
| Facing a capability-shaped task | `--wss-scout` | the toolbelt registry answers before anything is hand-built, and the search runs before the first failed attempt rather than after the third |
| The moment you decide *not* to build something | `--wss-todo` | the reasoning is perishable; it is gone by tomorrow |
| A decision made with no task attached | `--wss-log` | the same, minus the backlog entry |
| Settling how the system behaves | `--wss-describe` | the rule goes to the behaviour record while it is still checkable against the code; `--wss-log` takes the reasoning, and the two are routinely conflated into one entry that ages badly |
| Settling what the project *is* — stack, data model, a convention | `--wss-reference` | the reference record is what a later reader trusts instead of checking, so write it while the claim is still checkable; where the manifest maps `README.md` into it, this reaches the landing page and the writer's consent rules apply |
| Finishing a unit of work, or before `/clear` | `--wss-wrap` | the handoff is what the next session inherits |
| Every week or so, or after a refactor | `--wss-check` | cheap, incremental, and catches the records the code just falsified |
| The suite moved under an adopted project — or the doctor names a pre-rename manifest | `--wss-update` | updates the install, then detects what conventions the tree actually carries and migrates it behind its own gate; the `WSS.suite` stamp only accelerates, detection decides |
| Before a release, or when you stop trusting the record | `--wss-full-check` | the expensive one; earns its cost when the answer might be "no" |
| Every month or so, or when picking a project back up | `--wss-stocktake` | rebuilds the backlog around where things actually are |
| After editing any skill or agent file | `--wss-tools` | immediately, before ending the turn — it is the one with a deadline |

**If you only ever use three, use `--wss-track`, `--wss-todo` and `--wss-wrap`.** They are
the ones that pay on the first day; everything else pays back over weeks.

**Exact decomposition is the whole signal.** A flag counts anywhere in the
message; what gates it is that the token decomposes entirely into flags, with
nothing left over:

```
--wss-wrap                            invoke
--wss-stocktake--wss-release--wss-wrap            invoke all three, in that order
that's everything --wss-docs          invoke
commit it, then --wss-todo the rest    invoke — position does not matter
git branch --track origin/dev     does NOT invoke — --track is not a wss- flag
see the --wss-wrapper module          does NOT invoke — does not decompose
```

Position used to matter — flags were read only from the start or end of a
message — because unprefixed flags collided with pasted commands. The `wss-`
prefix removed that collision: no real command carries a `--wss-*` option. The
one consequence to know: a message that *quotes* a flag as its own bare token
fires it. With the prefix, an exact token is taken as intent, wherever it sits.

A flag whose skill does not resolve in the current project is **inert, not
broken** — `skill_exists()` declines to inject an instruction that cannot be
carried out. That is what keeps a partial install or a plugin layout degrading
quietly rather than injecting instructions nothing can follow, and it is what
lets project-specific and global skills share one hook.

A skill that is present but **disabled in settings** is inert the same way.
`skillOverrides` maps a skill name to `on`, `name-only`, `user-invocable-only`
or `off`, and `/skills` manages it; `skill_disabled()` treats the last two as
absent, because both block *model* invocation — the only kind a flag can ask
for, since the injected block tells Claude to call the skill. `name-only` still
fires, trimming only what is loaded into context. Project settings outrank user
settings, and `settings.local.json` is deliberately not read, matching the CLI's
own resolver for this key: reading it would silence a flag whose skill does in
fact run. Without this gate, turning a skill off got you an injected instruction
and a harness refusal in the same turn.

Current flags:

| Flag | Skill | Tier |
|---|---|---|
| `--wss-adopt` | `adopt` | orchestrator |
| `--wss-update` | `update` | orchestrator — updates the install, then migrates the adopted tree to the newest conventions; detection decides what needs migrating, the `WSS.suite` stamp only accelerates |
| `--wss-track` | `track` | primitive |
| `--wss-todo` | `record` | primitive |
| `--wss-log` | `record` | primitive |
| `--wss-plan` | `plan` | primitive |
| `--wss-tools` | `tools` | primitive |
| `--wss-check` | `check` | orchestrator — writes nothing; dispatches |
| `--wss-full-check` | `full-check` | orchestrator — writes no record; dispatches. `--wss-release` runs it before a tag |
| `--wss-docs` | `docs` | orchestrator |
| `--wss-diagram` | `docs` | orchestrator — one ad-hoc diagram, drawn under the style guide's rules and landed as an annex page |
| `--wss-start` | `start` | orchestrator |
| `--wss-stocktake` / `--wss-full-stocktake` | `stocktake` | orchestrator |
| `--wss-pr` | `pr` | orchestrator |
| `--wss-release` | `release` | orchestrator |
| `--wss-wrap` | `wrap` | orchestrator |
| `--wss-report` | `report` | orchestrator — appends to the machine-local inbox, then opens an upstream issue on a fresh OK |
| `--wss-overview` | `overview` | orchestrator — reads and reports, writes nothing at all |
| `--wss-scout` | `scout` | primitive |
| `--wss-describe` | `describe` | primitive — dispatches to `behaviour-writer`, which is `WSS.record.behaviour`'s sole writer |
| `--wss-reference` | `reference` | primitive — dispatches to `reference-writer`, which is `WSS.record.reference`'s sole writer |

**What each flag authorizes is deliberately not a column here.** A grant is
written by hand in two places — the block `wss-shorthand-flags.sh` injects, and the
matrix in [`workflow/WSS.OWNERSHIP.md`](workflow/WSS.OWNERSHIP.md) — and `wss-doctor.sh`
compares exactly those two on every run. A third copy in this file would be
compared against neither while being the one a newcomer treats as
authoritative, so the matrix is the single answer to *what may this flag do*.
Three grants recur there: commit but not push, commit and push, and commit with
a push that needs a fresh OK in the same turn.

**`--wss-pr` is the only thing that moves work between the two branches.**
`--wss-wrap` pushes `WSS.branch.integration` and stops; this drafts the PR body from the
branch range rather than from what the session remembers doing, opens it, watches
its CI, and merges once you confirm in that turn. `--wss-pr`'s short form has a
history: no flag may be a prefix of another — a token would decompose into the
shorter flag plus junk, and `wss-doctor.sh` fails the list on it — and `--wss-pr`
sat inside the old prune flag, which was renamed and later retired when its
skill merged into `tools`. The invariant held throughout; the neighbours
moved.

Two flags reach one skill where that skill does two jobs: `--wss-todo` parks an idea
and `--wss-log` records a decision, both through `record`.

Two pairs are one job at two scopes, and the wider one wins when both are typed:
`--wss-stocktake` / `--wss-full-stocktake`, and `--wss-check` / `--wss-full-check`.

A third suppression is absorption rather than scope: either stocktake flag drops
`--wss-check`, because `stocktake` runs that sweep as its own record
dimension. `--wss-full-check` survives alongside a stocktake, since it also covers
the docs site and the tooling files that no stocktake reads.

**Some primitives have no flag**, deliberately, and are invoked by other skills
rather than by you. Nobody wants to "record a baseline", "write the handoff" or
"make a commit"; they want a sweep, a wrap, a landed batch, a release — and
these are steps inside those. They are **procedure files under
`workflow/writers/`, not skills** — a caller reads the file and follows it.
(Three *skills* are also flagless — `/wss:lane-record-sync`, `/wss:retire` and
`/wss:toggle` — for the opposite reason: they are invoked only by you, never
by a phrase or another skill.)
`workflow/writers/WSS.WRITERS.md` is the index and the ownership matrix names each
one's record; four are worth knowing by name:

- **`sweep-tracker`** owns `.claude/WSS.SWEEPS.json`, the gitignored cache recording
  which commit each sweep last verified and what it actually covered. Its shape
  and its rules are
  [`workflow/WSS.SWEEP-CHECKPOINT.md`](workflow/WSS.SWEEP-CHECKPOINT.md).
- **`handoff-writer`** owns `WSS.record.handoff`, the compressed state a fresh
  session inherits. `--wss-wrap` calls it for a full currency pass, `--wss-start` for
  what a batch changed, `--wss-stocktake` for the warnings an audit created or
  resolved, and `--wss-check` for a single stale claim.
- **`changelog-writer`** owns `WSS.record.changelog`. `--wss-release` calls it for the
  entry that goes with a version, and `--wss-check` when the changelog claims a
  version no tag resolves.
- **`git-writer`** owns the git history — commits, tags, and the merge
  `--wss-pr` asks for. Every skill that may commit calls it, which is what
  keeps the rules that make a commit safe in one place rather than in whichever
  caller happened to think of them.

Flaglessness is load-bearing rather than cosmetic. Authorization comes from the
flag the user typed, and an invoked skill inherits its caller's grant — so a
primitive with **no** flag has no grant of its own to inherit from, and an
orchestrator that calls one cannot acquire authorization it was never given.
Where the owner of a record is itself an orchestrator, that guarantee is only as
good as the reader applying the rule correctly.

That is why a skill which both decides something and writes the record of it
gets split: the deciding half keeps the flag, because it is the half that has to
reach the user, and the writing half becomes a flagless primitive anything can
call. `--wss-release` is the worked example — it holds the publish gate and writes
nothing. [`workflow/WSS.OWNERSHIP.md`](workflow/WSS.OWNERSHIP.md) is the authority on all
of it, including when a split is *not* worth making.

**Every flag here maps to a global skill.** A project whose own skill wants a
flag adds it to that project's hook — a global block guarding a skill only one
project has is a permanent warning in `wss-doctor.sh` and a set of rules that project
cannot edit.

The rule holds with no exceptions today, and the one it once had was resolved
the right way round — by generalising the skill rather than dropping its flag.
`tools`'s prune reads `WSS.record.tooling.sources` from whatever project it runs in,
so it is global like the rest.

## Finding a bug in this suite from another project

A session working in some other repository **may not edit this suite's own
skills, agents, workflow contracts or scripts** — the change would land outside
the repository that session is about, never appear in its diff, and lose its
justification at the next `/clear`. Installed as a plugin it is worse: the write
succeeds and is destroyed at the next plugin update, silently.

This does **not** restrict your project's own skills and agents. Those are what
`WSS.record.tooling.sources` globs and what `--wss-tools` exists to maintain. The rule
draws the line at the installation, not around skill files in general.

So a session files instead: one append to `WSS.BUG-REPORTS.md` in your config
directory (`$CLAUDE_CONFIG_DIR`, else `~/.claude`), the single file any session
in any project may write to. Append-only, which is what makes many writers safe
on it — an append is additive, so concurrent entries cannot destroy each other.
Gitignored, so filing never dirties a tree and your private project names never
travel with the repo. `wss-doctor.sh` counts the open entries, since nothing else
would ever surface them. Because it is gitignored it ships with no template:

```
## [open] <one-line summary>
Found: <project worked in> · <config commit, short SHA>
File: <path within the suite> · Detail: <what is wrong, what you expected>
```

Triage them from a session whose working directory is a **checkout** of this
suite, re-verifying each before acting. Running it as a plugin you have no such
checkout, so the entry is your own record and the fix is an issue upstream at
[`qupunto/wss`](https://github.com/qupunto/wss).

Who may write which file is [`workflow/WSS.OWNERSHIP.md`](workflow/WSS.OWNERSHIP.md);
what each record holds is
[`workflow/WSS.RECORD-CONTRACT.md`](workflow/WSS.RECORD-CONTRACT.md). Every skill links
there rather than carrying its own copy.

