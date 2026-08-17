---
name: record
description: "The project's record of work and why. `--wss-todo` parks what is not being built now: task to the TODO LIST, reasoning to the decision log. `--wss-log` records a decision already made. Also on \"park this\", a decision announced as settled (\"we're going with X\"), pasted standup notes, or when you judge something premature. Not on a decision mentioned in passing."
---

# The project record

This skill owns the project's task and decision records, and one idea:
**nothing that was decided should survive only in a chat log.**

| Flag | Means | Writes |
|---|---|---|
| `--wss-todo` | park this; we are not building it now | `WSS.record.todo` **and** `WSS.record.decisions` — a deferral is a decision |
| `--wss-log` | we decided this; record the reasoning | `WSS.record.decisions` only |

Both go through the same routing table, the same file rules, and the same index
regeneration.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.todo`,
`WSS.record.decisions`, `WSS.record.decisionsIndex`, `WSS.record.openDecisions`, and
`WSS.commands.indexRegen`. Where a `.claude/WSS.LANE` selector names a lane,
`WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for whichever of
those are splittable — [`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md)'s resolution
rule; `WSS.record.decisions` never splits, and under lanes it is fed by promotion,
per the same file. The fallbacks
when a key is absent are
[`WSS.MANIFEST.md`](../../wss/workflow/WSS.MANIFEST.md)'s, not this file's — say which ones
you used. `WSS.record.decisionsIndex` is the one with no fallback: without it, append
to the decision log and say the index was not regenerated.

This skill is the **sole writer** of every one of them. Who owns everything else is
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md); what each
record may and may not hold is
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md), which is the authority
if this file and that one ever disagree.

## Routing: which file, and why it matters

```
Is it settled?
├─ No — we cannot start until someone chooses  → WSS.record.openDecisions
│                                                (options, tradeoffs, a
│                                                recommendation if there is one,
│                                                and WHAT IT BLOCKS)
└─ Yes
   ├─ and it produces work         → WSS.record.todo + WSS.record.decisions
   └─ and it produces no work      → WSS.record.decisions
```

**The first branch is the one to get right.** "Not now, because the project does
not need it" is a **decision** → `decisions`. "We cannot start because nobody has
chosen between A and B" is an **open decision** → `openDecisions`.

**An entry never lives in both** — [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md)'s
rule 3, which is where the rule and its reasoning live. Executing it here means
deleting the entry from `openDecisions` and appending the outcome, including the
options rejected, to `decisions`.

**An open-decision entry is one `## <the choice>` heading**, with the options,
tradeoffs, recommendation and what it blocks in the body below. The shape is
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md)'s, not a style
choice: the SessionStart staleness nudge counts entries by `## ` heading, and
an entry written as a bold paragraph is invisible to it.

## Intake: a block of notes, rather than one item

**Trigger on "here are my notes", "notes from the standup", "we discussed X, Y
and Z", "minutes from the call", or a pasted block of unstructured decisions and
actions.**

This is the one place the skill takes input it did not shape. Route every line
through the table above, each independently — **one note does not produce one
entry**, and the commonest mistake is filing the whole block as a single
decision because it arrived as a single paragraph.

**Three passes, in this order:**

1. **Split into claims.** One decision, action or question per line. A sentence
   containing "and we should also" is two.
2. **Route each** through the table above: settled + work → `WSS.record.todo` and
   `WSS.record.decisions`; settled + no work → `WSS.record.decisions`; unsettled and
   blocking → `WSS.record.openDecisions`.
3. **Report what you dropped, and why.** Status updates, restated context and
   anything already in a record are not entries. Say which lines produced
   nothing — silently discarding half of someone's notes is how they stop
   handing them over.

**What does not survive intake:**

- **Attribution.** "Sam thinks we should…" becomes the proposal, not the person.
  These records are read months later by someone who does not know who Sam is,
  and `WSS.RECORD-CONTRACT.md` gives them decisions rather than a transcript.
- **"We should probably…"** is not settled. It is either an open decision with
  what it blocks, or it is nothing — and asking which is cheaper than guessing.
- **A date with no decision attached.** A deadline belongs to `--wss-plan`.

**Ask before writing when the block is large or the routing is genuinely
ambiguous** — list what you propose to file where, in one message, and let the
user correct it.

**Everything here is still the flags' work underneath.** Intake decides the
routing; the writing is `--wss-todo` and `--wss-log` exactly as above, under whatever
grant the caller arrived with. Intake confers nothing of its own.

## Which of the two records

`WSS.record.todo` is the **TODO LIST**: what is genuinely queued, what a batch
may pick up, what someone is waiting on. `WSS.record.backlog` is everything
else worth writing down — the non-blocking, non-critical findings a session
turned up on its way to something else.

**The test is one question: is anything waiting on this?** If a person, a
release, another entry or a broken thing is waiting, it is queued and goes to
the TODO LIST. If the honest answer is "someone should look at this sometime",
it is a backlog entry. `[critical → why]` and `[blocked → …]` are TODO-LIST
markers and never appear in the backlog: an entry carrying either was queued by
definition. When unsure, file to the backlog — promotion is one deliberate move
and an over-queued list is the failure this split exists to remove.

## Writing to `WSS.record.backlog`

An ordinary register, rewritten in place, headed `# Backlog`, grouped under
`## ` sections by area. One entry:

```
- **Short name.** What was noticed, concretely — which files, which behaviour.
  Why it is not queued, in one clause.
  Noticed (owner|session) YYYY-MM-DD.
```

**No checkbox.** That is the discriminator, and it is load-bearing: a `- [ ]`
means queued, every counter in the suite counts checkboxes, and a backlog full
of them reads to every consumer as a TODO list. **No technical breakdown** —
file paths and the shape of the fix are what promotion writes, and writing them
here does the queued item's work for an item nobody scheduled.

**Promotion is a MOVE, never a copy, and only on a person's explicit say-so.**
Delete the entry from `WSS.record.backlog` and write it into `WSS.record.todo`
in that record's own format in the SAME edit: add the `- [ ]`, add the technical
detail the entry deliberately lacked, drop the `Noticed` line. An entry in both
files is the same failure as an entry in both `openDecisions` and `decisions`.
Never promote as a side effect of reading the backlog for something else, and
never promote in bulk — cherry-picking is the whole mechanism.

Demotion — TODO LIST back to backlog — is the same move reversed, and equally a
person's call.

## Writing to `WSS.record.todo`

**Read the value first: it may not be a file.** Where `WSS.record.todo` is an object
carrying a `provider` key, the TODO LIST lives somewhere else and the procedure is
that provider's —
[`providers/WSS.GITHUB-ISSUES.md`](../../wss/workflow/providers/WSS.GITHUB-ISSUES.md) for
GitHub Issues.
Everything below about *what an entry says* still applies; only where it is
written changes.

Three rules that survive the medium, and are the ones most easily lost:

- **An explicit deferral must be marked, because there is no section to put it
  in.** Where you would have filed the item under a `## Later` heading — the
  decision was "not now, revisit when X" rather than "do this in due course" —
  the issue body opens with `[later → X]`, exactly as a blocked item opens with
  `[blocked → …]`. This is not optional bookkeeping: `--wss-start` reads issues
  newest-first, so an item parked seconds ago is the *first* thing it reaches
  for, and an unmarked deferral is reversed by the next session that runs it.
  Ordinary TODO list items, the ones simply not scheduled yet, carry no marker.

- **The reasoning still goes to `WSS.record.decisions`, never into the item.** An
  issue body is not a decision log. Link to the decision from the item — and
  note that the file form's closing line, "Deferred (owner|session) — see the
  decision log", stops being a pointer the moment it is read on github.com
  rather than three files away. Give a URL or a repo-relative path that resolves from there.
- **Never fall back to a local file when the provider cannot be reached.** Say
  the item was not filed and name it, so it can be filed by hand. A project that
  declared a provider and finds a stray `WSS.TODO.md` appearing now has two
  backlogs, which is the failure the provider exists to prevent.

The rest of this section is the file form.

Pick the section it belongs to, or add one if none fits — don't force it
somewhere wrong. Check for an equivalent entry first and update rather than
duplicate.

A checkbox, a bold name, then the **technical** detail someone needs to actually
do it: file paths, table names, the shape of the fix, and the constraints that
would bite the implementer. **Not the argument for or against.**

```
- [ ] **Short name.**
      What it is, concretely. Which files/tables/endpoints.
      Constraints or gotchas that would bite the implementer.
      Deferred (owner|session) — see the decision log.
```

**The closing line names whose judgment deferred it, written at filing time.**
`Deferred (owner)` when the user made the call; `Deferred (session)` when this
session judged it premature. Whose judgment a deferral names is the whole
eligibility test at the next batch start — an owner deferral is a decision not
to reverse, a session deferral is a question addressed to the next
`--wss-start` — and a bare "Deferred" forces every batch to open the decision
log to re-derive an attribute the log entry already states.

If a decision blocks it, mark it `[blocked → <what's undecided>]` pointing at
`WSS.record.openDecisions`.

**`[critical → why]` is the one priority marker** — same line, same shape, no
other grades, and never written into another lane's transfer queue. The rules —
who may set it, why two levels, how consumers read it — are
[`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md)'s
`[critical → why]` section.

**Watch for state claims this entry falsifies.** Before writing, grep
`WSS.record.todo` and `WSS.record.openDecisions` for the claims the new entry makes
false — "nothing exercises Y", "no X exists yet", a `[blocked → …]` marker whose
decision has since been settled, a sibling entry proposing what this one
supersedes — and fix them in the same edit
([`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)).
Same-file scope is the cheap case and the usual one; the cross-record form is an
entry asserting X exists falsifying "no X exists" wherever that sentence lives.

**Never write the reasoning here.** That is the whole point of the split.

## Writing to `WSS.record.decisions`

Append-only, chronological. Lead with a `**Decided:** …` line stating the
outcome, then what was proposed, what was chosen instead, and *why now is or is
not the time* — what complexity it avoids, or what it depends on to make sense.

Four rules that are not stylistic:

- **A deferral names its authority.** The owner's words, or the session's own
  judgment — which stands only until the owner's next gate. The entries that
  omit this read as settled while hiding who settled them, and "I don't recall
  ordering this" must be answerable from the record —
  [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md)'s rule 2.
- **Record when the decision is made, not when it is built** —
  [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md)'s rule 1. An entry
  goes in the day something is settled, even if no code follows for months.
- **Never rewrite a past entry** — that contract's rule 4. Appending is the only
  way this file changes.
- **Group a batch.** Several deferrals in one pass make one dated entry with a
  bullet each, not a dozen tiny ones.

**Then regenerate the index** with `WSS.commands.indexRegen`. It is generated, never
hand-edited, and a later `--wss-check` fails if you skip it. Where the manifest
declares no index command, say the index was not regenerated rather than leaving
it silently stale.

### Then walk the deferral pointers back

**A deferral pointer is one-way, and this step is the only thing that closes the
loop.** A parked entry in `WSS.record.todo` cites the decision that will answer
it — `Deferred (owner) — see the decision log's <date> (<ordinal>) entry` — but
nothing ever walks that link in reverse. A session appending a decision does not
revisit the entries now pointing at it, so an answered entry sits open and the
next session describes the same thing a second time. That is the recorded root
cause of a duplicate pair, and it is **not** "nothing detects duplicates".

So, immediately after appending an entry and before this skill returns:

1. **Grep `WSS.record.todo` for the pointers that now cite the entry you just
   wrote** — its date and its ordinal, in the spelling the entry actually carries.
   Also grep for pointers citing the same date with no ordinal, which is a
   spelling that has been used.
2. **Read each entry the grep returns and ask one question**: does the decision
   just appended answer the entry's open question in full?
3. **Where it does**, the entry is done — hand it to `--wss-todo` for deletion,
   the same route as any other completed item, and say in your reply which
   entries closed this way. Where it answers only part, hand `--wss-todo` the
   narrowed text rather than leaving the whole entry standing.
4. **Where the grep returns nothing, say so in one line.** A silent step is
   indistinguishable from a skipped one, and an empty result is the ordinary case.

**This adds no script, no record and no commit-time gate**, and that is
deliberate. A pre-write duplicate check with a ruling menu, a helper script this
procedure would have to quote, and a refusal in `wss-append-only.sh` were all
proposed and all rejected: each adds machinery to catch a symptom of a one-way
link, which is the pattern this step exists instead of.

## When a deferred item is later done

**Delete it from `WSS.record.todo`.** Don't strike it through — that record is
forward-looking only, and struck-through items bury the live ones. What was built is recorded in `WSS.record.decisions`, `WSS.record.changelog`
and `WSS.record.reference`.

## What this skill does not do

- **It does not decide.** It records what the user decided. If you find yourself
  writing an entry for a choice nobody actually made, that belongs in
  `WSS.record.openDecisions` instead.
- **It does not touch `WSS.record.roadmap` or `WSS.record.releases`** — both are
  `--wss-plan`'s — or
  `WSS.record.changelog`, which is `changelog-writer`'s, or tags, which are
  `git-writer`'s and only ever on `--wss-release`'s say-so. A task *about* releasing
  something is fine; a task that *is* a release is not.
- **`WSS.record.changelog` is the neighbour worth keeping straight.** `--wss-log` records
  *why a choice was made*, for whoever maintains the project; a changelog records
  *what a user of the software notices*, keyed to a version.
- **It does not judge whether the work is worth doing.** A known bug that will
  not be fixed now still gets logged — as a defect with reproduction steps
  rather than as a deferred idea. Those read very differently to whoever picks it
  up.
- **It is not the session task list.** That is `--wss-track`: ephemeral, gone when
  the session ends. If something must outlive the session, it belongs here.

## Being invoked by something else

Orchestrators call this skill rather than writing the record themselves —
`--wss-start` when it settles an open decision or removes a shipped item, `--wss-stocktake`
when it dispositions a finding, `--wss-check` when it dispatches one.

When called that way, the caller supplies the content and you own the placement,
the format, and the index.
