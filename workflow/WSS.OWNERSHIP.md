# Ownership

**The one authority on who may write what.** Every skill links here instead of
carrying its own "relationship to other tools" section, because those were n²
cross-references maintained by hand and a dangling one reads exactly like a live
one.

The invariant this file exists to state:

> **Every record file has exactly one writer.**

Shared ownership does not stay shared for long: two skills that both write a file
end up each carrying a paragraph negotiating which one really owns it, deferring
to each other on different axes. That negotiation is the symptom, not the fix.

## Two tiers

| Tier | Writes | Fires on |
|---|---|---|
| **Primitive** — owns one record, or the history | its own file and nothing else | a flag, or any skill that dispatches to it |
| **Orchestrator** — owns the session | usually **nothing** — and never another owner's record, never the history | a flag, or any skill that dispatches to it |

**"Owns the session" is the definition. Writing code is not**, and the tier used
to be defined that way because of a single row. Orchestrators write nothing at
all: they decide, and hand every write to the primitive that owns the file.
`--wss-start` is the one that writes source code, and it is the exception rather
than the shape.

**There are no carve-outs.** The matrix is the whole rule: no orchestrator owns
a record, and every record reaches its file through the primitive that owns it.
A carve-out is a second writer wearing a justification, and the matrix must not
carry one.

Apply the SPLIT test below against *owns the session*, never against *writes
code*; read the matrix's "Sole writer of" column for what any given row actually
writes, rather than inferring it from this row.

**An orchestrator can be dispatched to, and a primitive can dispatch.** Neither
is exotic: `--wss-release` invokes `--wss-full-check`, `--wss-stocktake` invokes `--wss-wrap`, `--wss-adopt`
invokes `--wss-docs`, and the primitive `--wss-tools` invokes `--wss-docs` for the
documentation page derived from its catalog. The tier says what a skill *owns*,
not who is allowed to call it.

**Orchestrator-to-orchestrator dispatch is the shape to audit**, because the
callee arrives carrying its own flag's authorization unless the reader applies
the inheritance rule below. Do not read this table as saying it cannot happen —
an unnoticed dispatch of that shape is exactly how a callee runs on authorization
the user never gave. Read it as: when it happens, the grant is still the *user's* flag, and a callee whose
own procedure would exceed that must be given a narrower scope explicitly.

**The git history is a record for this purpose**, and `git-writer` is its writer.
It reads oddly beside the file-shaped ones, and it is the same rule: commits and
tags are a durable statement about the project that several skills need written
and none of them should each be writing their own way.

**A skill that produces content for a file it does not own hands that content
to the owner.** Stated directly and applying to any skill — no third tier
exists for that shape, because a tier with one member buys nothing the rule
itself does not.

**Which skill is in which tier is the matrix below**, and deliberately not a
second list here. A membership list beside the definition is an inventory: it
goes stale silently every time a flag is added, because nothing reads it against
anything.

**Several primitives have no flag of their own**, and for the same reason:
nothing a user wants is "record a baseline", "write the handoff" or "make a
commit". They want a sweep, a wrap, a landed batch, a release — and the stamp,
the handoff, the changelog entry and the commit are steps inside those. Those
primitives are the flagless rows in the matrix below, and are invoked only by
other skills.

**They are not skills — they are procedure files under
[`writers/`](writers/WSS.WRITERS.md), read by the skill that needs one.** A skill's
description is a standing per-session cost, and these are invoked only by other
skills — a trigger a description cannot serve — so they live outside `skills/`.
**The location changes nothing about ownership** — one procedure, one record,
and this matrix is still where you look it up. The
rows carry a path now instead of a skill name, and that path is how you reach
them: follow the link and do what it says.

`git-writer` has a second reason, particular to it: **a flag is how a user
confers authorization**, and that skill must never confer any. Its grant is
always the caller's.

An orchestrator that needs a record written **calls the primitive that owns it.**
It does not write the file itself, even when that is one line and obviously
correct. The point is not that a given write would be wrong; it is that a rule
with exceptions is one nobody can apply confidently, and a contract applied
unevenly stops being one.

**Be honest about what enforces this.** `wss-doctor.sh` checks that skills and agents
resolve, that cited sections exist, and that manifest keys are real — it does not
watch writes, and nothing diffs a commit against the matrix. The invariant holds
because it is simple enough to follow, not because it is policed. That is the
argument for keeping it free of exceptions: an unenforced rule survives only
while it stays easy to state.

## The matrix

| Verb | Flag | Skill or procedure | Tier | Sole writer of | Authorization the flag grants |
|---|---|---|---|---|---|
| adopt | `--wss-adopt` | `adopt` | orchestrator | **nothing with an owner** — the manifest goes through `manifest-writer`. It merges the `permissions.ask` entries it proposes into the project's `.claude/settings.json`, which is not a record | commit, **not** push |
| update | `--wss-update` | `update` | orchestrator | **nothing with an owner** — the manifest and its `WSS.suite` stamp go through `manifest-writer`, commits through `git-writer`, record surgery through each record's writer; the renames and regenerations touch the project's own unowned files | commit, **not** push |
| list the flags | `--wss-flags` `--wss-help` | *the hook itself* | — | **nothing** — it reads `wss-shorthand-flags.sh`'s own FLAGS array and prints what resolves here | — |
| alerts | `--wss-alerts` | *the hook itself* | — | **nothing** — it toggles the machine-local state file the alert hook reads, which is a preference rather than a record | — |
| track | `--wss-track` | `track` | primitive | the session task list | — |
| defer | `--wss-todo` | `record` | primitive | `WSS.record.todo`, `WSS.record.openDecisions`, `WSS.record.decisions` + index | — |
| record | `--wss-log` | `record` *(same skill as `--wss-todo`)* | primitive | `WSS.record.decisions` + index — **and the delete from `WSS.record.openDecisions`** that settling an entry entails, which is the same skill's file and so not a second writer | — |
| order | `--wss-plan` | `plan` | primitive | `WSS.record.roadmap` — every lane's copy — **and** `WSS.record.releases`, the release list, which never splits | — |
| scout | `--wss-scout` | `scout` | primitive | `WSS.record.toolbelt` — the registry of adopted capabilities; the reasoning behind each row goes through `--wss-log`, which is `record`'s file | — |
| catalog | `--wss-tools` | `tools` | primitive | `WSS.record.tooling.catalog`, plus stale claims and the prose prune inside `WSS.record.tooling.sources` | commit, **not** push |
| build | `--wss-start` | `start` | orchestrator | source code | commit, **not** push |
| document | `--wss-docs` | `docs` | orchestrator | the docs site | — |
| draw | `--wss-diagram` | `docs` *(same skill as `--wss-docs`)* | orchestrator | the docs site — one ad-hoc diagram, landed as a page in the site's annex directory | — |
| state the wiring | — | `contracts` | primitive | **nothing** — it says where the contracts resolve and which file settles a disagreement | — |
| stamp | — | [`writers/WSS.SWEEP-TRACKER.md`](writers/WSS.SWEEP-TRACKER.md) | primitive | `WSS.sweeps` — the checkpoint cache | — |
| hand over | — | [`writers/WSS.HANDOFF-WRITER.md`](writers/WSS.HANDOFF-WRITER.md) | primitive | `WSS.record.handoff` | — |
| note | — | [`writers/WSS.CHANGELOG-WRITER.md`](writers/WSS.CHANGELOG-WRITER.md) | primitive | `WSS.record.changelog` | — |
| declare | — | [`writers/WSS.MANIFEST-WRITER.md`](writers/WSS.MANIFEST-WRITER.md) | primitive | `.claude/WSS.WORKFLOW.json` | — |
| describe | `--wss-describe` | `describe`, which dispatches to [`writers/WSS.BEHAVIOUR-WRITER.md`](writers/WSS.BEHAVIOUR-WRITER.md) | primitive | `WSS.record.behaviour` — the writer's; the skill is a route to it and writes nothing | — |
| reference | `--wss-reference` | `reference`, which dispatches to [`writers/WSS.REFERENCE-WRITER.md`](writers/WSS.REFERENCE-WRITER.md) | primitive | `WSS.record.reference` — the writer's; the skill is a route to it and writes nothing | — |
| log an audit | — | [`writers/WSS.AUDIT-WRITER.md`](writers/WSS.AUDIT-WRITER.md) | primitive | `WSS.record.stocktake` — the stocktake log — plus `WSS.record.audits`, the index of independent passes, one row per report | — |
| commit | — | [`writers/WSS.GIT-WRITER.md`](writers/WSS.GIT-WRITER.md) | primitive | commits and tags | — |
| inspect | `--wss-check` | `check` | orchestrator | **nothing** — dispatches to the owner | — |
| overview | `--wss-overview` | `overview` | orchestrator | **nothing** — a read-only report; its counts go in the reply, which is not a record | — |
| health-check | `--wss-full-check` | `full-check` | orchestrator | **nothing with an owner** — every write goes through the owner it invokes: the skill files and the catalog through `--wss-tools`, the checkpoints through `sweep-tracker`. It edits the project's unowned files directly, the same as any ordinary work there | — |
| take stock | `--wss-stocktake` `--wss-full-stocktake` | `stocktake` | orchestrator | **nothing** — the entry goes through `audit-writer` | commit **and** push, **its own record only** |
| merge | `--wss-pr` | `pr` | orchestrator | **nothing** — the merge goes through `git-writer` | commit; push needs a fresh OK |
| publish | `--wss-release` | `release` | orchestrator | **nothing** — the entry goes through `changelog-writer`, the tag through `git-writer` | commit; push needs a fresh OK |
| hand off | `--wss-wrap` | `wrap` | orchestrator | **nothing** — the handoff goes through `handoff-writer` | commit **and** push, the latter including fast-forwarding a lane worktree's branch onto `WSS.branch.integration` |
| report upstream | `--wss-report` | `report` | orchestrator | **nothing with an owner** — it appends to the machine-local inbox, which any session in any project may write | none — opening the upstream issue needs a fresh OK in that turn |
| synch lanes | — | `lane-record-sync` | orchestrator | **nothing with an owner** — every finding is appended to the addressed lane's transfer queue, which has no single writer; it drains `WSS.lanes.conflicts`, the queue it is the sole consumer of; and the run's entry goes through `audit-writer` | none — **and it has no flag by design.** Slash-invoked only, so it can never fire from a phrase, a batch or another skill. Its step 0 lands lane branches onto `WSS.branch.integration`, and its step 5 brings each lane worktree back onto it once the run has finished — both **fast-forward only, through `git-writer`, locally** — a ref moved onto existing commits, nothing authored, nothing pushed; divergence is reported, never resolved, and step 5 additionally skips any lane whose worktree is dirty. Its step 6 hands the close-out to `--wss-wrap`, which inherits that nothing and **asks for its own commit in that turn** — the same shape as `report upstream` above. A flagless row can confer no grant, because there is no hook block to state one and no flag for `git-writer` to trace back to; the user is present throughout a slash-only run, so asking costs one question. **The push is never on offer**: step 0's local landings would otherwise reach the remote as a side effect of tidying up |
| retire | — | `retire` | orchestrator | **nothing** — the retire and reset scripts delete, the export script archives, and a deletion is not a record write; the dirty tree it leaves is the user's to commit or restore | none — **and it has no flag by design.** Slash-invoked only, and its own frontmatter blocks model invocation, so a deletion can never fire from a phrase, a batch or another skill; each destructive action runs only where the user checked its box in that turn |

`WSS.record.*` keys resolve through the project's `.claude/WSS.WORKFLOW.json`. A project
without one falls back to conventional names and skips what it cannot resolve.

**`--wss-adopt` is the one skill that runs before the contract applies**, since a
project has no owners until it has a manifest. That is a statement about *when*
it runs, not a licence to write outside the matrix: the manifest itself goes
through `manifest-writer`, and what `--wss-adopt` does is the detection, the search
and the asking — which a primitive cannot do, because it has no channel to reach
the user.

What it touches directly is bounded by merging the `permissions.ask` entries the
user approves into the project's `.claude/settings.json`, and creating the record
files *empty*. Creating a container is not writing a record: the owning primitive
still writes every line that goes in it, and the invariant holds from that point
on.

Settings are not a record and have no single owner — the user edits them, and so
does the harness. `--wss-adopt` merges into that file rather than writing it, which
is why the invariant is not in play there.

**A file with no owner in the matrix is not ownerless work — it is ordinary
work.** Scripts, CI, harness settings and the `workflow/*.md` contracts have no
row here, and a skill that edits one is not claiming ownership of it; it is doing
what any session in that project does. The matrix constrains *records*, and a
file that is not a record is constrained by nothing but review. This is what lets
`--wss-full-check` fix a broken hook script it found without a row licensing it.

**A record's overflow sibling is owned by that record's owner**, and does not
need a row of its own. Where a record has outgrown one file and been split by
cost rather than by subject — `.claude/WSS.HAZARDS.md` beside `.claude/WSS.HANDOFF.md`
is this configuration's instance — the two are one record with one writer.
Read the rule above without this one and the overflow file falls through to
"ordinary work", which is the opposite of what its owner says: `handoff-writer`
claims it as sole writer, and the matrix must not quietly license anyone else.

**A transfer queue has many writers, and that does not touch the invariant
above.** `WSS.lanes.named.<lane>.transfer` is a lane's inbox: every *other* lane
appends to it, and the owning lane's `--wss-start` is the only thing that
consumes it, moving each entry into the record it names. So the queue is
many-writer and every **record** still has exactly one — an entry becomes part
of `WSS.record.todo` when that lane's own session puts it there, not when a sibling
files it.

**This is not a carve-out, because a queue is not a WSS.record.** A record holds
state and is read; a queue holds messages in flight and is empty in the steady
state. [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) draws the line and holds the
entry shape. The invariant is unchanged and still has no exceptions — which is
the whole reason the queue was put beside `records` in the manifest rather than
inside it.

The same append-only argument the defect inbox rests on is what makes many
writers safe here: an append is additive, so a wrong entry is merely wrong and
nothing true is lost.

**`WSS.lanes.conflicts` is the same shape with a different consumer.** One per
project, written by any session that notices two lanes' records contradicting
each other, and consumed by `lane-record-sync` — which re-verifies each
claim before acting on it, per [the inspector rule](#the-inspector-writes-nothing)
below. Neither queue has a row in the matrix, because neither is a record.

**One handoff between owners is worth stating here, because it crosses two
files.** `--wss-plan` marks a milestone completed in `WSS.record.releases`; that mark is
`--wss-release`'s precondition for tagging. The mark is deliberately a written state
rather than a spoken approval — a conversation does not survive a `/clear`, and a
precondition nobody can check is one that never fires. `--wss-release` never writes
that mark, and `--wss-plan` never writes a tag.

**A release list that has declared an end to milestones satisfies that
precondition a second way**, and it is still `--wss-plan`'s written state rather
than a spoken one — the declaration is a section in `WSS.record.releases`.
`--wss-release`'s §1 holds the cases and the rule that a release names which one
it is.

**`WSS.record.roadmap` is not in that path at all**, and one skill owning both files
is what makes that safe to state: `--wss-plan` writes the goals a lane is working
toward and, separately, the milestone that cites them. A roadmap never carries a
version or a mark — [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds that rule —
so a session in a lane worktree cannot produce a release checkpoint even by
accident.

## The inspector writes nothing

`--wss-check` reads the whole record and reports. When it finds something, it
**invokes the owning skill for that file**, and that owner re-verifies and writes
under its own rules, in its own commit.

Delegation is a lookup, not a judgement — that is what the matrix above is for.

This is stronger than letting the inspector fix what it finds. An inspector that
writes is a second writer on every file it touches, which breaks the invariant
everywhere at once. An inspector that dispatches keeps every write coming from
the sole owner.

**The owner's second look is load-bearing, not ceremonial.** A dispatched finding
is a hypothesis, not an instruction: a meaningful share of them do not reproduce
as reported. Worse, a finding that has already been fixed reads exactly like a
live one, and acting on it can mask a real instance of the same class one file
away. So the owner re-verifies against the cited file before writing, and hands
the disagreement back rather than writing a correction that is itself wrong.

This applies to every finding that crosses skills, not only `--wss-check`'s — the
same holds for `--wss-full-check`, `--wss-stocktake`, a filed bug report, or a proposed
cut. The reporter hands over evidence, not a verdict.

## One writer, many readers — the sweep checkpoint

`--wss-check`, `--wss-full-check`, `--wss-docs`, `--wss-tools` and the test run all narrow their scope
by reading `.claude/WSS.SWEEPS.json`. **None of them writes it.** They hand their baseline and
their coverage to `sweep-tracker`, which is its sole writer, exactly as an
orchestrator hands a backlog change to `--wss-todo`.

This is what keeps the invariant free of exceptions. The obvious shape — a shared
state file each sweep updates in place — would put every sweep on one file and
require a clause saying ownership is per-key here and per-file everywhere else.
A rule with one exception is a rule nobody applies confidently.

There is a second reason, and it is not about tidiness. A sweep is *motivated* to
claim broad coverage, because a wide `covered` list is what makes its next run
cheap. Separating the claim from the record keeps the claim reviewable — the
rules that constrain it are [`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md).

The checkpoint is **gitignored and derived**, so it is not a record and does not
appear in [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md). Deleting it costs one full
sweep and can never cost correctness.

## Authorization comes from the flag, not the skill

A skill never decides how much it is allowed to do. The grant in the table above
is conferred by the user typing the flag, and it is stated in the hook block that
fires — so a skill cannot widen its own permissions by editing its own
instructions.

**A skill invoked by another skill inherits the caller's grant, never its own
flag's.** This is the rule that keeps dispatch from being a privilege escalator:
`--wss-check` grants nothing, so an owner it dispatches to may write its file and
must not commit; `--wss-start` grants commit but not push, so the `handoff-writer` it
invokes when a batch lands writes the file and nothing acquires push. Anything
beyond the caller's grant needs the user's word in that turn. Without this rule
every restricted flag could reach a permissive one by delegating to it, which is
exactly what the matrix exists to prevent.

**The flagless primitives make this easier to hold to, and that is part of why
they exist.** A primitive with no flag has no grant of its own to inherit *from*,
so there is nothing to reason about — whereas an orchestrator invoked by another
orchestrator arrives carrying its own flag's authorization, and the only thing
standing between that and a privilege escalation is a reader applying this
paragraph correctly.

For the same reason, **an owner invoked to fix one finding writes that finding
and stops.** It does not run its whole procedure — a dispatched one-line handoff
correction is not a reason to run a full closing ritual.

## A file belonging to the installation is never edited from a project session

**A finding about a skill, agent or workflow file belonging to THIS SUITE —
surfaced while working in some other project — is filed and stopped. Never fixed
in place.**

The suite's own files and the project you are standing in are two different
places, and where the suite sits depends on how it was installed:

| install form | the suite is at | the config directory is |
| --- | --- | --- |
| checkout | `~/.claude` — the repo *is* the working tree | the same directory |
| plugin | `${CLAUDE_PLUGIN_ROOT}`, under `plugins/cache/` | `~/.claude`, separately |

In a checkout the two coincide, which is why one path used to describe both.
Under a plugin they do not, so **`~/.claude` names the suite only in a checkout.**
The config directory — `WSS.BUG-REPORTS.md`, `projects/`, `settings.json` — is
`~/.claude` in both.

This is not the ordinary one-writer rule. `--wss-tools` genuinely owns those files;
the question is *which session* may act, and nothing above answers it. The
project's `WSS.record.tooling.sources` globs are relative, so a `--wss-tools` sweep in
another project correctly targets that project's own skills — but a defect
noticed in the suite file you are *currently executing* falls outside those
globs, and the instinct to fix what is demonstrably broken has nothing standing
against it.

Why the edit is worse than it looks, in a checkout:

- **It lands in a different repository than the session is about.** It never
  appears in that project's diff, so the review that would catch it never sees
  it.
- **`--wss-tools` grants commit**, so it may not even wait as a dirty tree. A commit
  can appear in the config repo authored during a session about something else.
- **The justification is discarded.** The reasoning lives in a context about to
  be cleared, leaving a change nobody can reconstruct.

**Under a plugin it is worse still, and silently.** The installation is an
ordinary clone — nothing refuses the write. But `${CLAUDE_PLUGIN_ROOT}` is
replaced on every plugin update, so the edit applies, works, and is destroyed
later with no error and no trace. A checkout at least leaves a dirty tree
somebody eventually notices.

**But do not merely say it — file it.** A finding reported into a session that
is about to be cleared is a finding that never existed, which is a worse outcome
than the edit this rule prevents. Append an entry to `$CLAUDE_CONFIG_DIR`'s
`WSS.BUG-REPORTS.md` — `~/.claude/WSS.BUG-REPORTS.md` unless that variable is set, in
either install form — which is the one file **any session in any project may
write to**, then stop.

Not a link, because the file is **not in this repository** — it is gitignored,
so it exists on a machine and never in a checkout or a published tree. That also
means it ships with no template, so an entry is:

```
## [open] <one-line summary>
Found: <the project the session was working in> · <config commit, `git -C … rev-parse --short HEAD`>
File: <path within the suite> · Detail: <what is wrong, and what you expected>
```

`wss-doctor.sh` counts entries whose heading is `## [open]`; that is how one gets
seen. Closing one is editing its heading during triage.

That file is append-only, and that is what makes many writers safe on it: an
append is additive, so a wrong entry is merely wrong and nothing true is lost.
It is also gitignored, so filing leaves no dirty tree in a repository the
session is not about.

Filing is the whole action. It is not a step on the way to fixing it.

**Where a filed report goes next depends on the install form, and only a
checkout can close one.** Triage runs from a session whose working directory is
the suite's own repository. An adopter running the plugin has no such
repository, so their terminal step is an issue upstream at
`qupunto/wss`; the local entry stays as their own record that it
was reported.

**A grant is authorization, not the act.** Every skill in the matrix that may
commit does so by invoking `git-writer`, which inherits that grant and confers
none of its own — so the commit *rules* (coherent grouping, staging by name, the
session trailer, checking whose work a push would publish) bind every authorized
caller, rather than only the one whose file happens to state them.

Three grants recur, and the distinction between them is deliberate:

- **commit, not push.** Work should survive a compaction; publishing is a
  separate decision. (`--wss-start`, `--wss-tools`)
- **commit and push.** The flag *is* the decision to publish. (`--wss-wrap`;
  `--wss-stocktake`, but scoped to its own record — never to remediation code written
  afterwards, which stays ordinary work.) **`--wss-wrap` from a lane worktree also
  lands that lane on `WSS.branch.integration`**, and that stays inside this grant
  rather than needing a fresh OK for one reason: it is a fast-forward or a
  refusal, never a merge, so it publishes the lane's own commits and can destroy
  nothing. Moving work onto `WSS.branch.publish` is the gated act and is `--wss-pr`'s.
- **commit; push needs a fresh OK in that turn.** For anything effectively
  permanent, or anything that moves work onto `WSS.branch.publish`. A tag another
  checkout has fetched cannot be recalled, and a merge another checkout has
  pulled is reverted rather than undone. (`--wss-release`, `--wss-pr`)

## Work scoped to another lane is announced first, then routed to that lane

The second which-session-may-act rule, for projects worked on in worktree
lanes. Where the manifest declares `WSS.lanes.named` and a `.claude/WSS.LANE` selector
names this session's lane, a request whose scope falls under a *different*
lane's `scope` globs is another worktree's work, and two things hold — both
**before any file is touched**:

- **Warn up front.** Name the session's lane, the owning lane, and where the
  work will happen. The scope globs sit in the shared manifest, so the
  mismatch is detectable the moment the request arrives — detect it then, not
  at commit time, when the only remaining options are both wrong.
- **The work happens in the owning lane's home.** Its worktree, its branch,
  its records. Interactively, offer the switch to a session in that worktree;
  where the user has the work proceed from here anyway, it proceeds *into*
  the owning lane's worktree and branch — absolute paths — and its record
  writes resolve through that lane's `records`, not this one's.
  **Lane-foreign files are never committed to the current worktree's
  branch**: a commit that mixes lanes undoes the partition the lanes exist to
  provide, and the conflict it defers lands on whoever merges next.

A request that straddles two lanes is a partition question, not a licence —
split it, do this lane's share here, and route the rest.

## Decide here, delegate the writing

A skill that both decides something and writes the record of it is two skills.
The tiers above have no row for that, which is not an omission: the shape is a
skill to be split rather than a third kind of thing.

`--wss-release` is the worked example. It reads the milestone mark, invokes
`--wss-full-check` for drift, confirms the version and holds the publish gate — and
writes nothing.
The changelog entry goes to `changelog-writer` and the tag to `git-writer`.

**What cannot move to a primitive is the asking.** Publishing needs an explicit
OK in the turn it happens, and a primitive has no channel to obtain one; it can
only be handed a report of one. That is the whole reason `--wss-release` exists
alongside the agent that prepares its material, and it is the general case —
**the decision stays wherever the user can be reached.**

### When to split

Either of these is enough:

- **The decision needs a conversation and the write does not.** Marking a
  milestone completed is a question for the user; writing the mark is not.
- **The record has callers wanting different amounts of work.** A one-line
  correction dispatched by `--wss-check` should not have to invoke a full release,
  audit or documentation procedure to get written. `WSS.record.handoff` is the
  worked example: `--wss-wrap`'s full currency pass and `--wss-check`'s dispatched
  one-line correction are the two ends of the range one primitive serves.

### When not to split

**Do not separate a judgement a skill makes about its own file.** `--wss-tools`
decides what counts as a mutable claim and then deletes it; splitting that would
produce a decision skill with nobody to ask. The test is whether the decision
needs a conversation, not whether it is a decision.

**One writer per file is the invariant — not one file per skill.**
`record` owns several records and keeps them, because a deferral writes
the backlog entry and the decision entry as a single action. Splitting it would
turn that atomicity into a convention between two skills, which is weaker than
a procedure. A skill owning several files is only a problem when they move
independently.

## Adding a skill to this workflow

1. Decide the tier. Does it own a record file, or does it own a session? If the
   answer is both, split it first — the section above is the test.
2. If it writes a record file, that file must have **no other writer**. If one
   exists, you are not adding a skill — you are moving ownership, and that is a
   decision to record before it is a change to make.
3. Add the row here. This table is the authority; a skill's own file describes
   only what *it* does.
4. Add the flag to `wss-shorthand-flags.sh` with its grant, and to the project's
   reference documentation — **through whichever skill owns that file.** Where
   the manifest maps a README into `WSS.record.reference`, editing it directly makes
   you its second writer, and this step is where that happens most often.
   **The flag's name equals the skill's name** — a scope-variant prefix
   (`--wss-full-stocktake` over `stocktake`) is the one sanctioned divergence.
   Where one skill serves several verbs, each verb's flag gets a same-named
   wrapper in `commands/`, so the menu entry, the flag and the route stay one
   token; `wss-doctor.sh` asserts every wrapper fires the flag its name promises.
   **A flag whose name already equals its skill's gets no wrapper** — it reaches
   the menu as the skill — and neither does a scope-variant prefix
   (`--wss-full-stocktake`). `wss-doctor.sh` cannot catch a redundant one, since it
   fires the flag its name promises; the cost is a duplicate menu entry.
   Wrappers exist only for flags whose skill carries its own rules — never for
   hook-served flags, whose whole behavior lives in the hook and would be
   improvised from memory if reached without it.
5. Run `wss-doctor.sh`, which checks that every flag resolves and that no project
   skill silently shadows a global one.

## What this file does not decide

- **Which file plays which role in a given project** — that is the project's
  `.claude/WSS.WORKFLOW.json`, whose keys are [`WSS.MANIFEST.md`](WSS.MANIFEST.md).
- **What each record file holds** — that is
  [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md).
- **How a skill does its job** — that is the skill.
