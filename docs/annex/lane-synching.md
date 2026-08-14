# Lane synching

How work crosses between lanes without any lane writing another's records.

This page documents the **mechanism**. It is not a log of synch runs — each run
records itself in `WSS.record.stocktake`, which is where "what was examined, when,
against which commit, and what was found" belongs. A page carrying one run's
actions would be stale the moment the next run happened, with nothing to
re-derive it.

## The problem lanes create

Worktree lanes divide a project so that concurrent sessions cannot collide.
What they cannot divide is the **dependencies between the work**. A plan in one
lane changes a data shape, an endpoint or a contract another lane builds
against — and nothing in the ordinary flow surfaces that until somebody hits it
at the worst moment.

The naive fix is to let a lane write into the lane it depends on. That breaks
the invariant every record in this suite rests on: one writer per file.

## The transfer queue

Each lane declares an **inbox** — `WSS.lanes.named.<lane>.transfer` — that every
*other* lane may append to.

| | A record | A transfer queue |
|---|---|---|
| Writers | exactly one | any lane |
| Holds | state | messages in flight |
| Steady state | whatever it says | **empty** |
| Consumed by | nothing — it is read | the owning lane's `--wss-start` |

**It is declared beside `records`, never inside it**, and the nesting is the
argument: everything under `records` has one writer, and a queue has many.
`wss-doctor.sh` fails on `transfer` appearing under `records`, and on a queue
declared for some lanes but not all — a lane without one is a lane nothing can
file to, so the request goes into its records by hand instead, which is the
second writer the queue exists to prevent.

**Append-only is what makes many writers safe** — an append is additive, so a
wrong entry is merely wrong and nothing true is lost. **One consumer is what
keeps the records' invariant intact**: an entry becomes part of `WSS.record.todo`
only when that lane's own session moves it there.

### An entry

```
## [todo] <one-line summary>
From: <originating lane> · <what it came from>
Why: <what makes this the receiving lane's work>
```

`[todo]`, `[openDecisions]` and `[roadmap]` are the only targets — three of the
four splittable records, since a lane's handoff is written by that lane alone
and nothing files into it. One queue serves all three, so the entry names where
it is bound rather than the filename implying it.

**A queue entry is a request, never an instruction.** The receiving lane's
session decides whether it belongs, and declines it with a line saying so rather
than dropping it silently.

## The conflict inbox — the second queue

A transfer queue is addressed to a **lane**. The conflict inbox is addressed to
a **skill**.

`WSS.lanes.conflicts` is one file per project — not one per lane, because a
contradiction between two lanes belongs to neither, and filing it to one of them
would pick a side before anyone has ruled. Any session that trips over one while
doing something else appends to it; `/wss:lane-record-sync` is the only thing
that consumes it.

```
## <one-line statement of the contradiction>
Lanes: <one lane> vs <the other>
Found: <the lane that filed it> · <what it was doing when it noticed>
Claim: <what each side's record says, cited so it can be checked>
```

**A filed entry is a claim, not a conflict.** The skill re-verifies it against
what the records say now before promoting it into mediation — a meaningful share
of filed findings do not reproduce, and one already resolved reads exactly like
one still live. What the reporting session contributes is evidence; the verdict
belongs to the run.

An entry leaves the inbox either way — promoted into mediation, or deleted with
the reason it did not reproduce. **Both movements go in the run's report**, and
the deletions are the half that matters most: they are how a session that filed
something wrong ever finds out, and a run reporting only promotions is
indistinguishable from one that rubber-stamped everything it was handed.

**A lane session files rather than resolves.** One lane cannot mediate between
two, and picking whichever reading unblocks the current batch is how one lane's
assumption quietly becomes the project's.

## Delivery rides the integration branch

A lane appends on its own branch. The entry reaches another worktree only once
the writing lane has landed on `WSS.branch.integration` and the receiving lane has
synced forward.

```
lane A appends → --wss-wrap lands A on integration → lane B's --wss-start
                 (fast-forward, or refused)         syncs forward, then drains
```

So a queue that looks empty on a lane which has not synced forward proves
nothing. `--wss-start` drains **after** the sync-forward and **before** anything
reads a record, which is why that ordering is stated rather than incidental.

Two lanes appending to different queues never collide. Two appending to the
*same* queue conflict at end-of-file and resolve as "keep both" — the trivial
case the append-only records already accept.

## Priority: one marker

One priority marker, `[critical → why]`, and everything else unmarked. Its
shape and placement, why two levels rather than a ladder, and what
`--wss-start` does with it are `workflow/WSS.LANE-CONTRACT.md`'s
`[critical → why]` section. What belongs on this page is the rule about lanes:

**A lane may not mark its own request critical in another lane's queue.** The
marker is written only where the **user** said so in that turn — a mediated
conflict, or an *accept as critical* ruling. Priority inflation is the standard
failure of every ladder, and here it is worse than usual: a lane marking its own
asks critical is one lane setting another lane's order. The user setting it is
not that, which is why the rule names the writer rather than the route.

## `/wss:lane-record-sync`

The skill that finds what to file. **Slash-invoked only** — no flag, no
`commands/` wrapper, no dispatch from another skill — because the run is
expensive and it writes into every lane's inbox.

It runs from the **main checkout only**. A lane worktree sees a sibling only as
`WSS.branch.integration` last delivered it, so a run from there reads a stale
partial picture while producing findings that look complete.

Seven steps. Steps 0 and 5 are a pair — the lanes' work comes **in** before
anything is read, the merged result goes back **out** once the run has finished
producing it — and step 6 closes out what all of them wrote:

0. **Land what the lanes have delivered.** Each named lane's branch is brought
   into `WSS.branch.integration` first — fast-forward only, locally, through
   `git-writer` — so the run reads every lane at its latest delivered state
   rather than at last week's. A branch that cannot fast-forward is a merge
   decision for its own lane's session: it is reported, read stale, and never
   resolved or forced here. Nothing is pushed — the landings are local, and
   step 6's close-out does not offer the push either, so they reach a remote
   only by a later act of the user's.
1. **Analyze** every lane's `todo`, `openDecisions` and `roadmap` together,
   separating **conflicts** (two records that cannot both be right, now) from
   **dependencies** (one lane's plan implying work in another, later).
2. **Mediate the conflicts first**, before anything is integrated — a
   dependency derived from a record that is wrong is a dependency derived
   twice. Resolutions are filed to every affected lane's queue as `critical`.
3. **Present every dependency for an explicit ruling**, lane by lane and within
   each lane by target record, showing which record it was derived from and why
   it is this lane's work.
4. **Record the run** through `audit-writer`, and the declines through
   `--wss-log`.
5. **Return the merged state to every lane** — each lane worktree brought
   forward onto `WSS.branch.integration`, fast-forward only, locally, nothing
   pushed. It is last rather than folded into step 0 because steps 2–4 are
   still *writing* into lane queues: a lane updated at the start would be stale
   again by the end, and stale after a visible update is worse than never
   updated at all. A lane whose worktree is **dirty** is skipped — uncommitted
   work there belongs to whoever is sitting in it — as is one that has
   diverged, on the same refusal rule as every other landing. Skipped lanes are
   named; each simply waits for its own next `--wss-start`, which is where it
   would have been anyway.
6. **Close the run out through `--wss-wrap`**, which is what makes the run's
   writes survive the session — the queue entries, the deletions from
   `WSS.lanes.conflicts` and the audit entry otherwise die in the working tree
   when it clears. The skill has no flag and so has no grant to pass down: the
   wrap it dispatches **asks the user for the commit in that turn**, naming
   what it would cover, and a refusal just leaves the tree as it was. The
   **push is never offered** — step 0's local landings would otherwise reach
   the remote as a side effect of tidying up. This step runs even where step 5
   skipped every lane, because everything worth making durable was written
   before it.

### The four rulings

| Ruling | Files to the queue | Next run |
|---|---|---|
| **Accept as critical** | yes, with `[critical → why]` | — |
| **Accept** | yes, unmarked | — |
| **Defer** | no | **asks again** |
| **Decline** | no | **does not ask** |

**Defer and Decline file the same thing — nothing — and that is where the
resemblance ends.**

*Defer* means the derivation is right and the timing is wrong, so the next run
finding it again is exactly the behaviour wanted. It is remembered nowhere, and
needs no machinery.

*Decline* means the derivation is **wrong** — not that lane's work, or a
mistaken inference. Re-deriving it every run would ask the same wrong question
forever, and **a gate that asks a wrong question repeatedly stops being a
gate**: the user learns to clear the prompt, which costs the approvals that
matter. So a decline is written to `WSS.record.decisions` — one entry per run, since
they were ruled on together — and step 1 reads `WSS.record.decisionsIndex` and drops
anything already declined.

A decline is permanent **by record, not by machinery**. Nothing detects that the
source changed and the derivation became valid again; reversing it is a later
decision, logged as one, which is how every other reversal here works.

### Why the approval is mandatory

An item filed without it arrives in a lane's records looking exactly like work
the user asked for, and the receiving session has no way to tell it was derived.
It would then be built, and defended, as though somebody wanted it. **Derived
work is a proposal until a person says otherwise**, and the gate is the only
place a person is present.

Which is also why rulings are never batched into one prompt: the whole risk is
that some items are stale or wrong, and one answer cannot separate them. And why
declining and deferring are offered separately — collapsing them loses the only
distinction that changes what the next run does.

## Eligibility and priority are separate axes

- **Priority** comes from the marker.
- **Eligibility** comes from provenance. An entry that passed the synch approval
  gate was already ruled on, so it is eligible for the receiving lane's batch as
  soon as `--wss-start` drains it. An entry a lane appended outside that gate is
  drained, announced, and waits a run — an inbox is not a gate.
