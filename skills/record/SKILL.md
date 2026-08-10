---
name: record
description: "The project's record of work and why. `--wss-todo` parks what is not being built now: task to the backlog, reasoning to the decision log. `--wss-log` records a decision already made. Also on \"park this\", a decision announced as settled (\"we're going with X\"), pasted standup notes, or when you judge something premature. Not on a decision mentioned in passing."
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
`WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for `todo` and
`openDecisions` — [`WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md)'s resolution
rule; `WSS.record.decisions` never splits, and under lanes it is fed by promotion,
per [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md). The fallbacks
when a key is absent are
[`WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md)'s, not this file's — say which ones
you used. `WSS.record.decisionsIndex` is the one with no fallback: without it, append
to the decision log and say the index was not regenerated.

This skill is the **sole writer** of every one of them. Who owns everything else is
[`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md); what each
record may and may not hold is
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md), which is the authority
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

**An entry never lives in both** — [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s
rule 3, which is where the rule and its reasoning live. Executing it here means
deleting the entry from `openDecisions` and appending the outcome, including the
options rejected, to `decisions`.

**An open-decision entry is one `## <the choice>` heading**, with the options,
tradeoffs, recommendation and what it blocks in the body below. The shape is
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s, not a style
choice: the SessionStart staleness nudge counts entries by `## ` heading, and
an entry written as a bold paragraph is invisible to it.

## Intake: a block of notes, rather than one item

**Trigger on "here are my notes", "notes from the standup", "we discussed X, Y
and Z", "minutes from the call", or a pasted block of unstructured decisions and
actions.** The user is handing over a conversation they had somewhere else, and
the job is to route every line in it through the table above.

This is the one place the skill takes input it did not shape. Notes arrive
mixed: a decision, an action, a thing someone will "look into", a complaint, and
a date. Route each independently — **one note does not produce one entry**, and
the commonest mistake is filing the whole block as a single decision because it
arrived as a single paragraph.

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

## Writing to `WSS.record.todo`

**Read the value first: it may not be a file.** Where `WSS.record.todo` is an object
carrying a `provider` key, the backlog lives somewhere else and the procedure is
that provider's —
[`providers/WSS.GITHUB-ISSUES.md`](../../workflow/providers/WSS.GITHUB-ISSUES.md) for
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
  Ordinary backlog items, the ones simply not scheduled yet, carry no marker.

- **The reasoning still goes to `WSS.record.decisions`, never into the item.** An
  issue body is not a decision log. Link to the decision from the item — and
  note that the file form's closing line, "Deferred — see the decision log",
  stops being a pointer the moment it is read on github.com rather than three
  files away. Give a URL or a repo-relative path that resolves from there.
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
      Deferred — see the decision log.
```

If a decision blocks it, mark it `[blocked → <what's undecided>]` pointing at
`WSS.record.openDecisions`.

**`[critical → why]` is the one priority marker**, same line, same shape. It
means `--wss-start` takes this before section order applies. Everything else is
unmarked — there is no "high" and no "mid", because dependency ordering already
outranks priority when a batch is partitioned, and a grade that changes nothing
is a judgment call paid for on every write.

**Do not mark an entry critical in another lane's transfer queue.** Filing into
a sibling lane's inbox is a request; marking it critical is setting that lane's
order for them. The marker is written only where the **user** said so in that
turn, which in practice means `lane-record-sync`'s two gates —
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s queue section.

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
  [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s rule 2.
- **Record when the decision is made, not when it is built** —
  [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s rule 1. An entry
  goes in the day something is settled, even if no code follows for months.
- **Never rewrite a past entry** — that contract's rule 4. Appending is the only
  way this file changes.
- **Group a batch.** Several deferrals in one pass make one dated entry with a
  bullet each, not a dozen tiny ones.

**Then regenerate the index** with `WSS.commands.indexRegen`. It is generated, never
hand-edited, and a later `--wss-check` fails if you skip it. Where the manifest
declares no index command, say the index was not regenerated rather than leaving
it silently stale.

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
