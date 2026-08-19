# The record contract

**What each record file holds, and what it must never hold.** One copy — the
general rule is *One source of truth* below, and this table is its first
instance. A second copy of this table anywhere declares an authority nothing
enforces, and the copies drift apart silently — partial versions in individual
skills and project files are how that happens.

Who may *write* each file is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md). Which path plays
which role in a given project is that project's `.claude/WSS.WORKFLOW.json`, whose
keys are [`WSS.MANIFEST.md`](WSS.MANIFEST.md). This file is about **content**: what
belongs where, and why putting it elsewhere breaks something.

## The split

| Role | Holds | Does **not** hold |
|---|---|---|
| `WSS.record.todo` | What to build and how. Checkboxes, technical detail, file references. Forward-looking only. | Reasoning about *whether* to build something. Completed items — they are removed, not struck through. |
| `WSS.record.backlog` | Non-blocking, non-critical findings a session turned up on its way to something else — worth someone's attention, not worth scheduling. Read deliberately, cherry-picked from. | Anything queued, blocking or critical — that is `WSS.record.todo`'s, and an entry moves rather than being copied. Reasoning about whether to build something. |
| `WSS.record.decisions` | The **why**, chronological, append-only. What was chosen, and what was rejected. | Anything undecided. Rewrites of past entries. Statements of current behaviour. |
| `WSS.record.decisionsIndex` | **Generated.** One row per decision. The cheap way in. | Anything hand-written. |
| `WSS.record.openDecisions` | Decisions **pending**, one `## <the choice>` heading per entry: options, tradeoffs, a recommendation where one exists, and what each one blocks. The heading is contractual — machinery counts entries by `## ` line, and an entry shaped any other way is invisible to the staleness nudge. | Anything settled — it moves out when decided. |
| `WSS.record.behaviour` | What the system **currently does** at runtime, by topic. | Why it does it. Decided-but-unbuilt behaviour. |
| `WSS.record.reference` | Current state — stack, architecture, data model, conventions. | Decision history. |
| `WSS.record.stocktake` | What each stocktake examined, when, against which commit, and what was found. Each entry carries an [`audit-coverage`](WSS.AUDIT-COVERAGE.md) block. Frozen records spell this role's former key, `WSS.record.audits`. | The resulting tasks — those go to `WSS.record.todo`. |
| `WSS.record.audits` | The index of the independent audit passes: one row per frozen report — what it covered, its verdict, where it was wrong — plus the per-pass narrative between rows. | The findings' remediation — `git log` is the authority on what was done about each. |
| `WSS.record.roadmap` | **Goals.** What an area of work is trying to achieve, the blocks that get it there, their order and dependencies. Written in that area's own terms. | Design arguments. **A version number or a completion mark** — those are `WSS.record.releases`', and a roadmap carrying one is the failure the split below exists to prevent. |
| `WSS.record.releases` | **The release list.** One entry per milestone: the version it intends to ship as, which goals it comprises, and whether it is marked completed. Plus the declaration, where one has been made, that milestones have ended. **And, where a release ships a structural change adopted trees must apply, one `- migrate:` line per change at column 0 in that release's own entry** — `- migrate: <detect-condition> → <mend>`, each line idempotent as written (its condition failing means already done). **A release with no milestone still owes its lines**, and gets a version-keyed container of its own — `#### <version> — tagged <date>`, carrying the lines and nothing else, marking nothing and authorising nothing, since a milestone entry implies a mark that authorises a tag. Column 0 is the load-bearing half either way: an indented line is quoted text rather than a filed one. `update` reads every such line after a tree's `WSS.suite` stamp, in release order; `--wss-plan` and `--wss-release` author them, and `--wss-release`'s minor tier fires on *this version's own entry* owing one. | Goal prose or task breakdowns — it *cites* the goals a milestone comprises rather than restating them. The claim that a version *shipped* — a tag is the only proof of that. |
| `WSS.record.changelog` | The **engineering log**: what changed per released version, in the project's own terms — contract names, paths, reasoning, and any marker the machinery reads. | Unreleased work. User-facing release notes — those are the public `CHANGELOG.md`, which is not a record; see below. |
| `WSS.record.handoff` | What a fresh session must know **before it touches code**, compressed, plus pointers to everything else. | Anything it can look up when the topic comes up. |
| `WSS.record.toolbelt` | One row per **adopted capability**: task shape → package → pointer into the `WSS.record.decisions` entry that adopted it. Consulted before building any capability. | The reasoning — that goes to `WSS.record.decisions` via `--wss-log` at the moment of adoption, so the registry stays a lookup table rather than a second decision log. |
| `WSS.record.tooling.catalog` | What skills and agents exist, what each is for in one human sentence, and a diagram of who invokes whom. It is the **source** for the docs site's Claude-tooling annex page, which `docs-writer` derives and owns. | Anything that changes as the project changes — see the mutable-claim rule below, and the carve-out under this table, which is narrow and applies to this row only. |
| `WSS.record.tooling.inventory` | **Generated.** Every *measured* fact about the tooling surface — sizes, grants, tiers, invoke/invoked-by edges, chain bytes — one entry per skill, agent, script, hook, command, check, writer and contract, regenerated wholesale by `wss-tools-inventory.sh`. The numeric half `WSS.record.tooling.catalog` points at rather than repeats. | Judgement. What a tool is *for*, in human language, is the catalog's; this file carries no sentence a person wrote. |

**The catalog row contradicts itself unless this carve-out is read with it.** Its
"Holds" column requires an inventory of what skills and agents exist; its "Does
not hold" column bars anything that changes as the project changes — and an
inventory is exactly that. So, stated here where every project reads it: **the inventory itself is
permitted in `WSS.record.tooling.catalog`, and nothing else mutable is.** Rows for
what exists, yes. Counts of them, "currently", a status, a health verdict, a
line about what some skill is in the middle of — no; those are ordinary mutable
claims and get deleted rather than corrected.

The carve-out holds only because something re-derives this file on a schedule:
`--wss-catalog` rebuilds it whenever a skill or agent changes, or `--wss-tidy`
edits one, and a repo whose maintenance skill refreshes it on every run keeps it
honest. An inventory nothing re-derives drifts silently and is worse than no
inventory, because it reads as current.

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
| Written by | `changelog-writer` | `changelog-writer`, invoked again |
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

## Two write modes: every record is a log or a register

**A record holds either an immutable timeline or mutable state, and which one it
is decides what may touch it.** A **log** is appended to and never edited; a
**register** is rewritten in place and holds only what is true now. Every
declared record is one or the other — the files outside the split are the
**generated** ones: `WSS.record.decisionsIndex`, wholesale from a log, and
`WSS.record.tooling.inventory`, wholesale from the tooling tree — both
hand-written by nobody.

| Mode | Files | Failure if done badly |
|---|---|---|
| **Log** — append-only | `decisions`, `stocktake`, `audits`, `changelog` | Additive. A wrong entry is a wrong entry; nothing true was lost. |
| **Register** — rewritten in place | `behaviour`, `reference`, `handoff`, `todo`, `backlog`, `roadmap`, `releases`, `openDecisions`, `toolbelt`, `tooling.catalog` | Destroys the previous true statement. |

**A log grows at one end, and which end is part of the rule rather than an
exception to it.** The rule is to add without modifying what is already there;
whether new entries stack upward or downward is irrelevant so long as a given
record never changes direction. So a prepending record — `WSS.record.changelog`,
newest first, by the convention its readers expect — is not a carve-out, it is
the same rule pointed the other way. The consequence is that only the entry at
the growing end is ever still a draft; **the entry at the other end is sealed**,
and rewriting it is an excision like any other. Both the direction and what
counts as an entry are declared per record in `WSS.recordMode`, defaulting to
tail-growth and `## ` headings — [`WSS.MANIFEST.md`](WSS.MANIFEST.md#recordmode--which-records-are-logs-which-are-registers)
carries the shape. Owner's ruling, the decision log's `2026-08-18 (twenty-fourth)`
entry, which also records the record this left wholly unguarded while the guard
was inferring instead of reading.

Appending a dated entry and rewriting a topic section have different blast radii.
That is why `WSS.record.decisions` belongs to the append-record primitive and
`WSS.record.behaviour` belongs to `behaviour-writer`, rather than one owner holding
both.

**The class also decides how a wrong statement is fixed**, which is the half
that gets improvised. A register is corrected in place — the false sentence goes
and the true one takes its seat, because the file's only job is to be right now.
A log is corrected by appending: the entry stays as written and a later entry
records the change of state. Correcting a log in place and appending to a
register are the same mistake in opposite directions, and both look like
diligence at the moment they are done.

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

**Which record has a mutable field is declared, and absent means none.** This
table is the authority, and `WSS.recordMode.<key>.mutable` is how the guard
learns it — a record that declares nothing gets no status-field exemption. The
guard once applied the `Outcome:` exemption to every log record with no
reference to which one it was reading, so the field this table denies
`WSS.record.decisions` was mutable there in practice. (Owner's rule; the
decision log carries the fixture that found it.)

**A fourth permitted deletion: a pointer kept correct.** A deleted line paired 1:1 with a
replacement whose basename and every other character are identical — so only
the directory part of a path changed — is not a rewrite of history; it is
stopping a reference from rotting when its target moves, and without it an
absolute-path convention cannot be maintained inside an append-only record at
all. Renaming a file, or repointing a line at a *different* file, still fails,
because both change a basename. (Owner's rule.) It was in force in the guard
before it was written here — the guard's own header enumerated three exemptions
while its code had four.

The distinction is what keeps this checkable. "Append-only with exceptions" is a
rule nobody can apply confidently; "bodies never change, and the cells this
table names are the only mutable ones" is a rule you can verify by reading. **Widening the
set is a decision to record, not an edit to make** — and rewriting a body under
cover of updating its status is the failure this table exists to name.

### A mechanical pass stops at the live surface

**Any pass that edits many files by pattern** — a rename, a prefix change, a path
move, a link fix, a terminology sweep, **a redaction** — applies to the records
that are **actively read to decide what to do**, and to nothing else. A log's
body keeps the words it was written with, permanently, even when those words
exist nowhere else in the tree.

**Redaction is the case that walks past a rule framed as renames-only**, and it
is the expensive one: it does not read as a convention change, it reads as a
privacy measure, so it is run with a clear conscience — and what it strips from a
log is not prose but the evidence that something happened. Agnostic output is
manufactured at the publish assembly, which drops and blanks on the copy
(`wss-publish.sh`, `wss-reset-records.sh`); the private tree is never redacted in
place. If a pass cannot state which of the two it is doing, it is doing the
second one.

An old name inside a log entry — or any other wording a later pass would tidy
away — is **not stale and not a defect**. It is a fact
about what the thing was called when that was written, which is the entire
purpose of a record whose job is registering the journey. Correcting it forfeits
the only thing the file is for, and leaves no way to tell what a past session
actually saw. A health check that flags one is wrong; the finding to file is
against the check.

Applies to every append-only file in the table above — `decisions`, `stocktake`,
`audits`, `changelog` — and to `decisions-index`, which is generated from bodies and
carries their spelling with them.

**A record's header is not one of its entries.** The prose above the first entry
— what the file holds, who its sole writer is, which manifest key declares it,
which contract governs it — describes the record *now*. It is the file's
instructions, and it tracks reality like any rewritten-in-place record does. An
append-only file whose header still names a renamed writer is simply wrong, and
a header link to a moved file is a dead link, not a preserved fact.

The boundary is the first dated entry. The same
split applies to an index like the audit index (`WSS.record.audits`), whose
opening prose is live and whose per-entry rows are frozen.

## Worktree lanes

**Lane mode only — a `.claude/WSS.LANE` selector present in this checkout, or
`WSS.lanes.named` declared in the manifest.** Which records may split by lane
and which must never, the transfer queue, the conflict inbox and the
`[critical → why]` marker are [`WSS.LANE-CONTRACT.md`](WSS.LANE-CONTRACT.md)'s.
One reader that gate cannot detect follows the pointer anyway: a session
deciding whether to adopt lanes at all has no selector yet, and needs that
file most.

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

**One form is permitted, and it is narrow: a citation into an append-only
record, written inside a code span** — the shape
`wss/logs/WSS.DECISIONS.md`'s `2026-08-12 (seventh)` entry has, and no other. Such
an entry is a frozen anchor: it is never rewritten and never renumbered, so
unlike a count it cannot drift, and what this rule guards against is history
that goes *stale*. Two things the exception does not reach: a citation into
anything mutable, and the same fact written as bare prose outside a code span.
The exception is why a rule may point at the measurement that produced it
instead of restating a figure — deleting such a citation leaves the rule
unfalsifiable, which is the cost this narrow form buys off.

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

## One source of truth

**No concept is written twice, and no figure is written without its source.**
The write-mode split above governs *when* a record may change; this governs
whether something else has to change with it. Both failures are silent — nothing
goes red, the two statements simply stop agreeing, and whoever found the wrong
one has no way to tell that they did.

The exceptions are real, and *The exception list* at the end of this section is
where they live. A copy that is neither derived nor listed there, and any figure
without its source, is a defect — whatever it was for.

### A concept is stated once; nothing else restates it by hand

**Where a rule, a format, a list or a definition already has a home, no other
site writes the text out by hand.** The home is whichever file owns the thing.
Three forms are permitted at the second site, and nothing else is:

1. **A pointer** — a link, a `file:line`, or the name of the section. The
   default, because it is paid only by the readers who follow it, where a copy
   is paid on every path.
2. **A copy mechanically derived from the canon** — the full text, marked as
   derived at the copy, naming the canon and the command that regenerates it. A
   derived copy is checked by **regenerating and comparing the output**, never
   by a reader asserting that the two agree. `WSS.commands.indexRegen` derives
   `WSS.record.decisionsIndex` from the decision log this way, and `wss-doctor.sh`
   locates a canon and its restatements by marker rather than by a hardcoded
   file list.
3. **An entry on the exception list** below.

**A copy is derived only if a command reproduces it.** Not if one is planned,
and not if someone undertakes to keep the two in step — that is a hand-copy with
a promise attached, and the rule below applies to it unchanged. The command is
the whole of the difference.

**A hand-copy goes by elimination, not by comparison.** It is removed; it is not
registered as a sanctioned pair and policed for agreement. A check that
two copies agree still leaves two things to edit on every change, and it passes
on the day both are wrong — which is the day it was bought for. A regeneration
check is not that check renamed: it leaves one thing to edit, and it cannot pass
while the copy differs.

The damage a hand-copy does is not the drift itself. It is that a duplicate
reads as authoritative to whoever finds it first, so the stale copy gets acted
on by exactly the reader it was written for — which is also why a derived copy
must say at the copy that it is one.

### A figure carries what recomputes it

**Every number written anywhere carries its source beside it**: the dated log
entry, the audit pass, the health check, or the command that recomputes it. A
count with no source cannot be re-verified, only re-trusted — and a reader who
doubts it has to reconstruct the query that produced it before they can act at
all, which costs more than the count ever saved.

Two forms qualify and nothing else does: a citation the reader can open (a
`file:line`, a dated entry, an audit pass), or a command they can run. **Prefer
the command.** It stays correct after the number goes stale, which is the normal
case rather than the exception, and it turns a stale figure into a two-second
check instead of a research task.

### The exception list

**The rule ships with exceptions rather than as an absolute**, and this is the
only place they live — appended to once an exception has been ruled on, never
asserted inline at the site that wants one. A rule that cannot state its own
exceptions gets exceptions invented for it.

**1. The handoff's private-identifier match count.** Writing the figure is
itself another match, so the number is falsified by the act of recording it and
every correction repeats the fault. It is never written down, in any record, in
any form. Gate 1 of `wss-publish.sh` recomputes it, and that command stands in
for the figure everywhere the figure would otherwise have gone.

**2. A verbatim copy, or a condensation of a table, that no command
reproduces, where the canon is genuinely unreachable at the point of use.**
Not inconvenient to follow — unreachable: a walkthrough read before a clone of
the tree exists, or a rendered docs page whose site router never reaches the
canon's directory. **The derived form takes precedence**: where a command can
reproduce the copy it is form 2 above and this entry does not apply, so what
lands here is only the residue — the copy that has to exist and that nothing
generates. Two conditions hold together, and a copy failing either is an
ordinary duplicate:

- **It is verbatim, or — for a table — a condensation of one: cells may
  shorten, drop a column's wording, or omit a row, but never add a row, a
  label, or a claim the canon does not carry.** A paraphrase that could reword
  or add a claim is a second statement of the thing, which is what the rule
  forbids; a condensation bounded this way cannot become one.
- **It says so at the copy** — naming the canon, and saying what fidelity it
  holds: a verbatim copy says it changes only when the canon does; a
  condensation says its cells condense freely but its row labels track the
  canon's. That note is also what makes the exception findable: a copy
  carrying none is the defect, and the note is what a check has to grep for.

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
