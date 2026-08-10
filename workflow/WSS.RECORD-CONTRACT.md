# The record contract

**What each record file holds, and what it must never hold.** One copy. A
second copy of this table anywhere declares an authority nothing enforces, and
the copies drift apart silently — partial versions in individual skills and
project files are how that happens.

Who may *write* each file is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md). Which path plays
which role in a given project is that project's `.claude/WSS.WORKFLOW.json`, whose
keys are [`WSS.MANIFEST.md`](WSS.MANIFEST.md). This file is about **content**: what
belongs where, and why putting it elsewhere breaks something.

## The split

| Role | Holds | Does **not** hold |
|---|---|---|
| `WSS.record.todo` | What to build and how. Checkboxes, technical detail, file references. Forward-looking only. | Reasoning about *whether* to build something. Completed items — they are removed, not struck through. |
| `WSS.record.decisions` | The **why**, chronological, append-only. What was chosen, and what was rejected. | Anything undecided. Rewrites of past entries. Statements of current behaviour. |
| `WSS.record.decisionsIndex` | **Generated.** One row per decision. The cheap way in. | Anything hand-written. |
| `WSS.record.openDecisions` | Decisions **pending**, one `## <the choice>` heading per entry: options, tradeoffs, a recommendation where one exists, and what each one blocks. The heading is contractual — machinery counts entries by `## ` line, and an entry shaped any other way is invisible to the staleness nudge. | Anything settled — it moves out when decided. |
| `WSS.record.behaviour` | What the system **currently does** at runtime, by topic. | Why it does it. Decided-but-unbuilt behaviour. |
| `WSS.record.reference` | Current state — stack, architecture, data model, conventions. | Decision history. |
| `WSS.record.stocktake` | What each stocktake examined, when, against which commit, and what was found. Each entry carries an [`audit-coverage`](WSS.AUDIT-COVERAGE.md) block. Frozen records spell this role's former key, `WSS.record.audits`. | The resulting tasks — those go to `WSS.record.todo`. |
| `WSS.record.audits` | The index of the independent audit passes: one row per frozen report — what it covered, its verdict, where it was wrong — plus the per-pass narrative between rows. | The findings' remediation — `git log` is the authority on what was done about each. |
| `WSS.record.roadmap` | **Goals.** What an area of work is trying to achieve, the blocks that get it there, their order and dependencies. Written in that area's own terms. | Design arguments. **A version number or a completion mark** — those are `WSS.record.releases`', and a roadmap carrying one is the failure the split below exists to prevent. |
| `WSS.record.releases` | **The release list.** One entry per milestone: the version it intends to ship as, which goals it comprises, and whether it is marked completed. Plus the declaration, where one has been made, that milestones have ended. **And, where a release ships a structural change adopted trees must apply, one `- migrate:` line per change at column 0 in that milestone's entry** — `- migrate: <detect-condition> → <mend>`, each line idempotent as written (its condition failing means already done). `update` reads every such line after a tree's `WSS.suite` stamp, in release order; `--wss-plan` and `--wss-release` author them. | Goal prose or task breakdowns — it *cites* the goals a milestone comprises rather than restating them. The claim that a version *shipped* — a tag is the only proof of that. |
| `WSS.record.changelog` | The **engineering log**: what changed per released version, in the project's own terms — contract names, paths, reasoning, and any marker the machinery reads. | Unreleased work. User-facing release notes — those are the public `CHANGELOG.md`, which is not a record; see below. |
| `WSS.record.handoff` | What a fresh session must know **before it touches code**, compressed, plus pointers to everything else. | Anything it can look up when the topic comes up. |
| `WSS.record.toolbelt` | One row per **adopted capability**: task shape → package → pointer into the `WSS.record.decisions` entry that adopted it. Consulted before building any capability. | The reasoning — that goes to `WSS.record.decisions` via `--wss-log` at the moment of adoption, so the registry stays a lookup table rather than a second decision log. |
| `WSS.record.tooling.catalog` | What skills and agents exist, what each is for in one human sentence, and a diagram of who invokes whom. It is the **source** for the docs site's Claude-tooling annex page, which `--wss-docs` derives and owns. | Anything that changes as the project changes — see the mutable-claim rule below, and the carve-out under this table, which is narrow and applies to this row only. |

**The catalog row contradicts itself unless this carve-out is read with it.** Its
"Holds" column requires an inventory of what skills and agents exist; its "Does
not hold" column bars anything that changes as the project changes — and an
inventory is exactly that. So, stated here where every project reads it: **the inventory itself is
permitted in `WSS.record.tooling.catalog`, and nothing else mutable is.** Rows for
what exists, yes. Counts of them, "currently", a status, a health verdict, a
line about what some skill is in the middle of — no; those are ordinary mutable
claims and get deleted rather than corrected.

The carve-out holds only because something re-derives this file on a schedule:
`--wss-tools` rebuilds it whenever a skill or agent changes, and a repo whose
maintenance skill refreshes it on every run keeps it honest. An inventory nothing
re-derives drifts silently and is worse than no inventory, because it reads as
current.

## Two files named changelog, and only one is a record

`WSS.record.changelog` is the engineering log above. A project may **also** keep a
public `CHANGELOG.md` for people using it. That file is **not a record**: no
manifest key points at it, no writer owns it, and `wss-reset-records.sh` leaves
it alone.

That last point is the reason the split exists rather than being tidiness.
Records ship **blanked**, because they hold one project's history and an adopter
reading an inherited backlog would believe it. A changelog that is a record
therefore reaches the public tree empty — so a project whose only changelog is
`WSS.record.changelog` publishes no release notes at all, and nobody notices,
because the file is present and correctly named.

| | `WSS.record.changelog` | public `CHANGELOG.md` |
|---|---|---|
| Reader | someone editing the project | someone using it |
| Names | contracts, paths, keys | behaviour that changed |
| Written by | `changelog-writer` | `--wss-release`, directly |
| On publish | blanked | ships as written |

**One file is the normal case.** A project with a single changelog has a record
and nothing to reconcile; the second file is for projects that are *published*
to someone. Where both exist, an entry belongs in exactly one — the test is
whether it parses for a reader who has never opened the source.

## Four rules that are easy to get wrong

**1. A decision is recorded when it is *made*, not when it is built.** The
opposite rule fails concretely: a batch of real design commitments sits in the
backlog mixed in with unbuilt sketches, with no way to tell one from the other.
If something is settled in conversation it gets an entry that day, even if no
code follows for months. What *exists* is `WSS.record.reference`'s job.

**2. A decision not to build something is still a decision.** It gets an entry.
The task stays in `WSS.record.todo` as an unchecked item pointing at it. **And the
entry names whose call the deferral was** — the owner's words, or the session's
own judgment, which stands only until the owner's next gate. A parking written
without attribution reads as settled while hiding who settled it, and "I don't
recall ordering this" must be answerable from the record rather than by forensic
reading of which entries *do* carry an owner's name.

**3. An entry never lives in both `openDecisions` and `decisions`.** Settling one
means deleting it from the first and appending the outcome — including the
options rejected — to the second. Never both. An entry in both is the specific
failure the split exists to prevent.

**4. History is not staleness.** An old entry in `WSS.record.decisions` describing a
decision later reversed is **correct as written**. The *later* entry is what makes
the record accurate. Do not rewrite it. This is the one file exempt from "fix what
is stale", and the exemption is the whole reason the file can be trusted as a log.

## Two write modes, and why they do not share an owner

| Mode | Files | Failure if done badly |
|---|---|---|
| **Append-only** | `decisions`, `audits`, `changelog` | Additive. A wrong entry is a wrong entry; nothing true was lost. |
| **Rewritten in place** | `behaviour`, `reference`, `handoff`, `todo`, `roadmap`, `releases`, `toolbelt` | Destroys the previous true statement. |

Appending a dated entry and rewriting a topic section have different blast radii.
That is why `WSS.record.decisions` belongs to the append-record primitive and
`WSS.record.behaviour` belongs to `behaviour-writer`, rather than one owner holding
both.

### Status fields

**Append-only constrains the entry, not every character in it.** An entry's
**body** — what was decided, what was examined and found, what shipped — is never
rewritten once written. A **status field** records the entry's current
disposition rather than a claim about the past, and updating one destroys nothing
that was true. A field is mutable only if this table names it:

| File | Status field | Updated when |
|---|---|---|
| `WSS.record.decisions` | **none** | — |
| `WSS.record.stocktake` | `Outcome` | remediation lands. Starts as `logged` |
| `WSS.record.changelog` | an entry's released / unreleased status | drift against `git tag` is settled by declaring the work unreleased |

`WSS.record.decisions` has none, deliberately, and that is what rule 4 above
protects: alone of the three, its entries are claims about the past and nothing
else. An audit's `Outcome` and a changelog entry's release status are statements
about *now* that happen to live in a dated entry — leaving them stale does not
preserve history, it just makes the file wrong.

The distinction is what keeps this checkable. "Append-only with exceptions" is a
rule nobody can apply confidently; "bodies never change, and these three cells
are the only mutable ones" is a rule you can verify by reading. **Widening the
set is a decision to record, not an edit to make** — and rewriting a body under
cover of updating its status is the failure this table exists to name.

### A convention change stops at the live surface

Renames, prefix changes, path moves and other conventions apply to the records
that are **actively read to decide what to do** — and to nothing else. An
append-only body keeps the spelling it was written with, permanently, even when
that spelling no longer exists anywhere else in the tree.

**This is the rule a tree-wide rewrite breaks without ever noticing.** The
section above reasons about *entries* and *status fields*, which is the frame you
are in when editing one file by hand. A `sed` across every tracked file is not in
that frame — it has no concept of an entry, so it satisfies every sentence above
while destroying exactly what they protect. State it separately or it does not
get applied.

An old name inside a log entry is **not stale and not a defect**. It is a fact
about what the thing was called when that was written, which is the entire
purpose of a record whose job is registering the journey. Correcting it forfeits
the only thing the file is for, and leaves no way to tell what a past session
actually saw. A health check that flags one is wrong; the finding to file is
against the check.

Applies to every append-only file in the table above — `decisions`, `audits`,
`changelog` — and to `decisions-index`, which is generated from bodies and
carries their spelling with them.

**A record's header is not one of its entries.** The prose above the first entry
— what the file holds, who its sole writer is, which manifest key declares it,
which contract governs it — describes the record *now*. It is the file's
instructions, and it tracks reality like any rewritten-in-place record does. An
append-only file whose header still names a renamed writer is simply wrong, and
a header link to a moved file is a dead link, not a preserved fact.

The boundary is the first dated entry, and it is worth stating because the two
halves of these files read alike and a convention change wants to treat them the
same. It gets it backwards in both directions: sweeping the whole file destroys
history, and excluding the whole file leaves instructions that lie. The same
split applies to an index like the audit index (`WSS.record.audits`), whose
opening prose is live and whose per-entry rows are frozen.

## Lane-scoped records — which may split, and which must never

A project worked on from several git worktrees at once may split a record into
per-lane files, declared under the manifest's `WSS.lanes.named` and resolved by
[`WSS.MANIFEST.md`](WSS.MANIFEST.md)'s resolution rule. **Splittable: `todo`,
`openDecisions`, `handoff`, `roadmap`** — forward-looking records, lane-scoped by
nature, and the ones every concurrent session wants to write, which is exactly
where the merge conflicts were. **Never: `decisions`, `audits`, `changelog`** —
the append-only single timelines; three branches appending at EOF conflict
trivially and resolve as "keep both" — **nor `releases`**, which is the release
list and must be singular for the reason below, **nor `behaviour`, `reference`**,
which describe one system, **nor `toolbelt`** — which tool does a job is a
property of the project, not of a worktree. A lane-local decision log is the
failure this rule exists to prevent: the why of a choice fragments across
files nobody reads together.

Under lanes the decision log is fed by promotion, not by lane writes: a lane
appends *candidate* entries to its own openDecisions file, and the merge to
the integration branch is what promotes settled ones into `WSS.record.decisions`.
One writer per file still holds — each lane file has the same owner its
unsplit record has, per [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md).

## The transfer queue — a lane's inbox, and not a record

**A lane never writes another lane's records.** What it writes instead is that
lane's **transfer queue**, declared as `WSS.lanes.named.<lane>.transfer` — a sibling
of `records`, deliberately outside it, because everything in this file's tables
has one writer and a queue has many.

| | A record | A transfer queue |
|---|---|---|
| Writers | exactly one | **any lane** |
| Holds | state — what is true, planned or decided | **messages in flight** |
| Steady state | whatever it says | **empty** |
| Write mode | append-only or rewritten in place | append-only, always |
| Consumed by | nothing — it is read | the owning lane's `--wss-start`, which moves each entry into the record it names and deletes it |

**Append-only is what makes many writers safe**, the same argument the defect
inbox rests on: an append is additive, so a wrong entry is merely wrong and
nothing true is lost. **One consumer is what keeps the records' invariant
intact** — an entry becomes part of `WSS.record.todo` only when that lane's own
session moves it there, so `todo` still has exactly one writer.

An entry names the record it is bound for, because one queue serves every
destination it can reach:

```
## [todo] <one-line summary>
From: <originating lane> · <what it came from — a block, a conflict, an entry>
Why: <what makes this the receiving lane's work>
```

`[todo]`, `[openDecisions]` and `[roadmap]` are the only targets — three of the
four splittable records, since a lane's handoff is written by that lane alone
and nothing files into it. **A queue entry
is a request, never an instruction**: the receiving lane's session is what
decides the entry belongs, and an entry it rejects is deleted with a line saying
so rather than silently dropped.

**Delivery rides the integration WSS.branch.** A lane appends on its own branch, so
the entry reaches another worktree only once the writing lane lands on
`WSS.branch.integration` and the receiving one syncs forward. Two lanes appending to
different queues never collide; two appending to the *same* queue conflict at
EOF and resolve as "keep both", which is the trivial case the append-only
records already accept.

### The conflict inbox — `WSS.lanes.conflicts`

**The second queue, and it differs from the first in who it is addressed to.**
A transfer queue is addressed to a *lane*: work one lane believes another owns.
The conflict inbox is addressed to a *skill*: a contradiction between two lanes'
records, noticed by a session that was doing something else, which needs
mediation nobody in that session can perform.

There is **one per project**, not one per lane, because a contradiction is not
any single lane's property — and routing it to one of the two lanes involved
would be picking a side before anyone has ruled.

| | Transfer queue | Conflict inbox |
|---|---|---|
| Declared | `WSS.lanes.named.<lane>.transfer`, one per lane | `WSS.lanes.conflicts`, one per project |
| Addressed to | that lane | `lane-record-sync` |
| Consumed by | that lane's `--wss-start` | that skill, on its next run |
| Holds | work believed to be that lane's | a suspected contradiction between two lanes |

Every queue rule above applies unchanged: append-only, any session may write,
empty in the steady state, and an entry is deleted when it has been handled.

```
## <one-line statement of the contradiction>
Lanes: <one lane> vs <the other>
Found: <the lane that filed it> · <what it was doing when it noticed>
Claim: <what each side's record says, cited so it can be checked>
```

**A filed entry is a claim, not a conflict.** The skill re-verifies it against
the records before promoting it — the same second look
[`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md#the-inspector-writes-nothing) requires of any
finding that crosses skills, and for the same reason: a meaningful share do not
reproduce as reported, and one that was already resolved reads exactly like one
that is live. What the reporting session contributes is **evidence**, not a
verdict.

**Nothing else empties it.** A session that files an entry and a session that
would act on it are different sessions, so an inbox nobody consumes is a
contradiction somebody already found and nobody will see again.

### `[critical → why]`

**One priority marker, not a ladder.** It goes on the first line of an entry's
body — the same place and shape as `[blocked → …]` and `[later → …]`, so there
is one convention rather than two, and it survives a provider-backed backlog
where sections do not exist. Everything else is unmarked. `--wss-start` takes
critical items first, before any section ordering applies.

Two levels rather than four because dependency ordering already outranks
priority when a batch is partitioned, so finer grades mostly lose to it — and
every extra grade is a judgment call on every write, with "mid" and "unmarked"
meaning the same thing in practice.

**A lane may not mark its own request critical in another lane's queue.** The
marker is written only where **the user said so in that turn** —
`lane-record-sync`'s mediation of a conflict, or its *accept as critical*
ruling on a dependency. Priority inflation is the standard failure of every
ladder, and here it is worse than usual: a lane marking its own asks critical is
one lane setting another lane's order. The user setting it is not that, which is
why the rule names the *writer* rather than the route.

## Why the roadmap and the release list are two records

**A roadmap sets the next goal. A release list is a gate.** They were one file
while a project had one area of work, and pulling them apart is what lets the
roadmap split.

**No roadmap carries a version number or a completion mark** — not a lane's, not
an unsplit project's. `WSS.record.releases` is the only file either appears in, and
`--wss-release` reads no other planning record. That is the whole mechanism: a
project may hold any number of lane roadmaps without ever holding more than one
release checkpoint.

A goal that becomes ship-facing does not acquire a version where it sits. A
milestone in `WSS.record.releases` **cites** it — one direction, by name. So the
milestone entry is where lane work and the shipping plan are reconciled, and it
is reconciled because somebody wrote it there. **Nothing aggregates lane
roadmaps**, and nothing detects a lane whose goals are all met while the
milestone citing them still reads open. That is a cost of the split, accepted
rather than covered: the alternative is a release gate that waits on the slowest
lane.

## The mutable-claim rule

**A skill or agent file may carry conventions, decisions and pointers — never
counts, inventories, or "not yet built".**

Anything that changes as the project changes goes in a record file that something
keeps current, or in a command the skill runs. This is not a style preference: a
stale claim in one of these files makes the agent re-derive the real state on
every run, paying for it every time — and it recurs, because nothing ever
triggers a re-read of the file that misled it.

So when a stale claim is found in one of these files, **delete the claim rather
than correcting it.** A corrected count is a claim that will go stale again; a
deleted one cannot.

**The pattern rule — this rule's general form: a rule file states behavior; the
log explains it.** A skill, agent, procedure, check or contract file carries
explicit behavioral patterns — trigger, action, boundary — plus at most one
clause of *mechanism* per counterintuitive rule. History never appears: no
dates, no incident citations, no what-a-file-used-to-say, no who-found-what.
All of that belongs in `WSS.record.decisions` or the audit log, which exist to
explain the pattern without being loaded beside it. The test is robustness: a
rule a reader must infer from an anecdote is inferred differently by each
reader, and variance in reading becomes variance in behavior — where stating
the rule explicitly costs more words, the words are the cheaper side of that
trade. `wss-doctor.sh` polices the greppable proxy: a date-shaped string in prose,
outside a fenced block, in any rule file.

The same risk applies to `WSS.record.handoff`, which is loaded every session and
therefore costs tokens forever. Prefer a one-line warning plus a pointer over a
paragraph, and **delete a resolved warning the moment it is fixed** — a stale
warning teaches the reader that the warnings in that file are unreliable, which
costs you the real ones.

## Negative claims

**"Nothing does X" is the highest-risk sentence in any record file.** Run the grep
that would *disprove* it — not one that confirms it — before writing it, every
time. This holds for any absolute claim about state that moves, including counts.

The failure mode is a grep written against the wrong call shape: search for a
bare framework method in a codebase that wraps it, and the absence of results
"proves" a capability is missing when every instance is right there under another
name. A negative claim is then used to retire work, which is what makes it
expensive rather than merely wrong.

## A record holds one project, and only its own

**A finding about another project never enters this project's records.** Not
`todo`, not `roadmap`, not `openDecisions`, and **not `decisions`** — which is
otherwise the file that takes everything settled, and is the one most likely to
be reached for on the grounds that a real decision was made. Hand it to that
project's own record, in that project's lane, and stop there.

This is not the lane split one level up. Lanes divide one project among
worktrees; this divides projects. A lane's records still describe the system all
its lanes build.

The suite is installed once and serves every project on the machine, so another
project reaches a session routinely — through a shared inbox, a question asked
mid-batch, a checkout in the next directory. **Reaching a session confers no
ownership.** What goes wrong is not exposure: it is that an entry filed in the
wrong project is read by sessions that cannot act on it, missed by the ones that
can, and counted in a status report describing a tree it does not describe.

Where this project's own machinery must change *because* of what another project
showed, that item is legitimate and belongs here — **written from this project's
facts**. State what is true here; never name the other project, quote its
configuration, or cite its records as the evidence. A reader of this record must
be able to act on the entry without access to anything outside this tree.

### The one exception: a name that is load-bearing

**Another project's name may be written where the name itself is the operative
detail of a fact about *this* tree.** Both halves are required:

- **It is a fact about this project.** This repository's history contains the
  string; this repository's gate trips on it; this repository's file was copied
  from there. Not a fact about the other project's state, plans or adoption.
- **The name does the work.** Redacting it breaks the entry — it is the needle a
  grep is run with, the literal a check matches on, the value that has to be
  typed. A name that could be replaced by "another project" without loss is not
  load-bearing, and the rule above applies unchanged.

The canonical case is a hazard whose own command embeds the string: abstracting
the name leaves a warning nobody can act on, which is a worse record than the
one that names it. The canonical *non*-case is a condition on the other project
— "once they adopt this", "when their migration lands" — which names it for
state a reader of this tree cannot observe, and fails whether or not the name is
spelled out.

Provenance on already-completed work qualifies where the name is what makes the
provenance checkable, and not otherwise. Append-only records get no separate
allowance, and no licence to rewrite either: `WSS.record.decisions` takes no rewrites
of past entries (the table at the top of this file), so an entry that violated
the rule when written stays as written and the correction is a later entry.

Telling the user what was noticed is always right. **Filing is what routes**, and
it routes outward.

## When nothing fits

Say so. Do not invent structure — ask which existing file should stretch, or
whether a new one is warranted, and once decided keep using that same place for
the same kind of content instead of re-deciding it each time.
