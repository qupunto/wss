---
name: wss-lane-record-sync
description: "Reconcile every lane's records at once — conflicts between them, and work one lane's plans imply for another. Every finding needs an explicit ruling: accept, accept as critical, defer or decline. What is accepted goes to the addressed lane's transfer queue, never its records. Invoke only as /wss-lane-record-sync; it has no flag."
disableModelInvocation: true
disable-model-invocation: true
---

# Synchronising the lanes

Lanes divide one project so sessions cannot collide. What they cannot divide is
the **dependencies between the work** — a plan in one lane changes a data shape,
an endpoint or a contract another lane builds against, and nothing in the
ordinary flow surfaces that until someone hits it.

This skill reads every lane's records together, which no other session can do,
and turns what it finds into entries in the lanes' transfer queues.

**It is slash-invoked and nothing else.** No flag, no `commands/` wrapper, no
dispatch from another skill. That is a design constraint, not an omission: the
run is expensive, and it writes into every lane's inbox. Both are reasons it
should never fire from a phrase in a sentence.

Who owns what is [`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md); what a
queue holds and what a record holds is
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md); the keys are
[`WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md).

## Two hard preconditions

**1. The main checkout, never a lane worktree.** If `.claude/WSS.LANE` names a lane,
**stop and say so.** Every lane's records resolve through the shared manifest,
but their *contents* live on their own branches — a lane worktree sees a sibling
only as `WSS.branch.integration` last delivered it, so a run from there reads a
partial and stale picture while producing findings that look complete. Two lanes
running it concurrently would also file overlapping requests into each other's
queues.

**2. `WSS.lanes.named` must declare more than one lane.** With none or one there is
nothing to reconcile, and the expensive part is the cross-product. Say so and
stop.

## What it costs, said before it runs

State, in three or four lines: how many lanes, how many record files that is,
and that every finding will need a decision from the user. Then run.

This is the run the user should be able to stop before it starts. It reads every
lane's `todo`, `openDecisions` and `roadmap`, and the cross-lane comparison is
quadratic in the lane count.

Name in the same statement which lane branches step 0 will attempt to land,
so the one part of the run that moves a ref is visible before it happens.

## Step 0 — Land what the lanes have delivered

A reconciliation over stale lanes reconciles the wrong records: this skill
reads every lane **at the integration branch's state**, and a lane whose
branch carries committed work the integration branch has not taken yet is a
lane whose plans are invisible to the run — the findings then look complete
and are derived from last week.

So, before anything is read, bring each named lane's branch into
`WSS.branch.integration` — **by fast-forward only, through `git-writer`**, the
main-checkout twin of `--wss-wrap`'s landing (git-writer's lane-landing rule;
same constraints, local instead of remote). Per lane, in one pass:

- **Already contained** — the ordinary steady state; nothing to do.
- **Fast-forwards** — land it and say so. A landing can make the next lane's
  branch land too or stop it; take the lanes in whatever order maximises what
  lands, and re-try the refused ones once after every success.
- **Diverged** — **report it and read that lane at what integration last
  took.** A merge with real deltas is a merge decision for that lane's own
  session, never resolved here and never forced — the same refusal rule as
  every landing. Say plainly in step 4's entry that the lane was read stale
  and by how many commits.

Fetch first where the lanes ride a remote; a branch that only looks behind is
the failure the sync-forward rules exist to catch. **No push.** What landed
locally is published by the user's ordinary close-out, not by this run.

**This step is half of a pair.** It brings the lanes' work *in*; step 5 sends
the merged result back *out*, once the run has finished producing it. Landing
without redistributing leaves every lane holding its own slice and none of the
others', which is the state this skill is invoked to end.

## Step 1 — Analyze

Read every lane's records, at the integration branch's state. **All lanes, not
just one** — this skill is costly enough that a single-lane run would mean
invoking it again shortly, and the conflicts it looks for are between pairs.

### Drain the conflict inbox first

**`WSS.lanes.conflicts` is where sessions file contradictions they hit while doing
something else**, and this skill is its only consumer. Read it before deriving
anything: an observed contradiction is better evidence than an inferred one,
because somebody actually ran into it.

**Every entry is a claim, not a conflict.** Re-verify each against what the
records say *now*, at the integration branch's state, before it goes anywhere —
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing)'s
second-look rule, and it applies with full force here. A meaningful share of
filed findings do not reproduce as reported, and one that has since been
resolved reads exactly like one that is live. The reporting session contributed
evidence; the verdict is this run's.

Then, per entry:

- **Reproduces** → it joins step 2's mediation set alongside the conflicts
  derived here. Note that it came from the inbox rather than from analysis; the
  provenance matters to whoever reads the report.
- **Does not reproduce** — already resolved, misread, or the records now agree
  → **delete it, with the reason.** Leaving it means re-verifying the same dead
  claim on every run.

**Either way the entry leaves the inbox.** It is a queue, empty in the steady
state, and an entry that survives its own assessment is an entry that will be
assessed again forever.

**Both movements go in step 4's report — promoted and deleted, with counts and
reasons.** A run that reports only what it promoted is indistinguishable from
one that promoted everything, and the deletions are where a session learns that
what it filed was wrong.

### Then derive the rest

Two different things are being looked for, and they are not confused:

| | A **conflict** | A **dependency** |
|---|---|---|
| Is | two lanes' records that cannot both be right | one lane's plan implying work in another |
| Example | one lane's plan says a price is per item, another's assumes per variant | a lane's endpoint block implies the consuming lane needs a payload contract |
| Exists | now, in the records | in the future, when the work lands |
| Handled by | step 2, which needs mediation | step 3, which needs approval |

**A dependency whose resolution is genuinely uncertain is not a task.** Where
what the receiving lane should do depends on a choice nobody has made, its
target is `openDecisions`, not `todo` — that is what that record is for, and
filing it as a task manufactures a decision by making someone implement one.

**Read `WSS.record.decisionsIndex` too, and drop anything a previous run declined.**
The index is one line per settled decision and is the cheap way in — the same
lookup `--wss-plan` and `--wss-start` use. Without it this skill is stateless and
every run re-litigates every rejection, which is the failure mode that ends with
the gate being cleared unread. Say in the opening how many derivations were
suppressed that way, so a shrinking list is visible rather than mysterious.

**Deferred items are not in that set and must come back.** That asymmetry is the
whole reason both rulings exist — step 3's table.

Delegate the reading where the project declares an agent for it; the record
volume is the whole cost of this skill, and a subagent's context is discarded
when it returns.

## Step 2 — Resolve conflicts, before anything is integrated

Conflicts first and separately, because a dependency derived from a record that
is wrong is a dependency derived twice.

**Two sources, one set.** The conflicts promoted out of `WSS.lanes.conflicts` and
the ones derived in step 1 are mediated together and to the same standard — but
say which is which when presenting them. An observed contradiction comes with a
session that hit it; a derived one comes with an inference, and the user is
entitled to weigh those differently.

Per conflict: name both sides, both lanes, and what each record actually says.
Then **ask the user to mediate**. This is not step 3's four-way ruling — it is a
question about which of two statements is right, and it has no default. Neither
*defer* nor *decline* is on offer: two records that contradict each other keep
contradicting each other, and a conflict left unmediated is the one thing this
skill must not carry forward silently.

Once resolved, **file the outcome into every affected lane's transfer queue,
marked `[critical → why]`.** The marker is legitimate because the user ruled on
it in this turn, which is the whole condition
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md) puts on a lane
receiving a critical item it did not raise — the same condition step 3's *accept
as critical* satisfies.

**Never write another lane's records directly**, even where the correction is
one line and obviously right, and even from the main checkout where the files
are reachable. The queue is the only route in; a record has one writer and it is
that lane's own session. Writing it here would make this skill a second writer
of every record in the project at once.

## Step 3 — Present every dependency for a decision

**Lane by lane, and within each lane in three passes: `todo`, then
`openDecisions`, then `roadmap`.** The grouping is what makes a long list
reviewable — a user deciding twenty items wants them sorted by where they land,
not by which lane happened to imply them.

Every item is presented with the facts needed to rule on it:

- **Which record it was derived from**, by lane and by name.
- **Why it is this lane's work**, in one sentence.
- **What it would land as** — the target record, and the entry text.

**Four rulings, and they differ in two axes: whether anything is filed, and
whether the next run asks again.**

| Ruling | Files to the queue | Next run |
|---|---|---|
| **Accept as critical** | yes, with `[critical → why]` | — |
| **Accept** | yes, unmarked | — |
| **Defer** | no | **asks again** |
| **Decline** | no | **does not ask** — see below |

**`[critical → why]` is written only where the user said so in this turn** —
here, or at step 2's mediation. The standing rule is that *a lane* may not set
another lane's priority; the user always may, and this gate is one of the two
places they do it.

### Defer and Decline are not the same answer

They file the same thing — nothing — and that is where the resemblance ends.

- **Defer means the derivation is right and the timing is wrong.** It is
  remembered nowhere, deliberately: the next run finding it again *is* the
  behaviour wanted. This is the cheap ruling and it needs no machinery.
- **Decline means the derivation is wrong** — not that lane's work, or a
  mistaken inference. Re-deriving it every run would ask the same wrong question
  forever, and **a gate that asks a wrong question repeatedly stops being a
  gate**: the user learns to clear the prompt, which costs the approvals that
  matter.

So a decline is written down. **A decision not to build something is still a
decision** — [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s rule 2
— so hand `--wss-log` **one entry per run listing every decline**, with what each
was derived from and why it was rejected. One entry rather than one per item:
they were ruled on together, and N entries would be N index lines for one
sitting.

**Read `WSS.record.decisionsIndex` in step 1 and do not re-present anything a
previous run declined.** The index is one line per settled decision and is the
cheap way in — the same lookup `--wss-plan` and `--wss-start` already use. Say in
the run's opening how many derivations were suppressed that way, so a shrinking
list is visible rather than mysterious.

**A decline is not permanent by machinery, it is permanent by WSS.record.** Nothing
here detects that the source record changed and the derivation became valid
again. Reversing it is a later decision, logged as one, which is how every other
reversal in this project works — do not build change-detection to guess at it.

**The approval is mandatory and it is the point of this skill.** An item filed
without it arrives in a lane's records looking exactly like work the user asked
for, and the receiving session has no way to tell that it was derived. It would
then be built, and defended, as though somebody wanted it. Derived work is a
*proposal* until a person says otherwise, and this is the only place a person is
present.

Two consequences of that, both easy to get wrong:

- **Never batch the rulings into one prompt.** "Add all 14?" is not the
  decision this exists to obtain — the whole risk is that some of them are
  stale or wrong, and one answer cannot separate them.
- **Declining and deferring are different answers**, per the table above, and
  offering only one of them collapses "this is wrong" into "not yet".

An entry that came through this gate is eligible for the receiving lane's next
batch as soon as `--wss-start` drains it, because it has already been ruled on
here.

## Step 4 — Record the run

**Hand [`audit-writer`](../../workflow/writers/WSS.AUDIT-WRITER.md) an entry**: what
was examined, at which commit, how many lanes, the conflicts found and how each
was mediated, and the dependencies found with how many were approved and how
many declined. That record is `WSS.record.stocktake`, which exists for exactly this —
what was examined, when, against which commit, and what was found.

**Report the conflict inbox's movements: how many entries were promoted into
mediation, and how many deleted as not reproducing, each with its reason.**
Both halves are required. The deletions are how a session that filed something
wrong ever finds out, and a run reporting only promotions is indistinguishable
from one that promoted everything it was handed — which is precisely the
rubber-stamping the re-verification exists to prevent.

**Report the four rulings separately — accepted, accepted as critical, deferred,
declined.** The two that filed nothing are the most valuable numbers in the
entry: a run reporting only what it filed is indistinguishable from one that
filed everything, and collapsing "wrong" and "not yet" into a single
*not added* hides the only distinction that changes what the next run does.

**The declines are also a second write, and it is not this one.** They go to
`WSS.record.decisions` through `--wss-log` — one entry for the run — and the audit
entry says how many, not what they were.

**Do not write a documentation page describing this run.** The mechanism is
documented once, in the docs site's lane-synching annex, and a page carrying one
run's actions is stale the moment the next run happens with nothing to
re-derive it —
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule).
Where the *mechanism* itself changed, that is `--wss-docs`' page to update.

## Step 5 — Return the merged state to every lane

Step 0 brought every lane's work **into** the integration branch. This step
sends the result back out, so the lanes end the run holding what the run
produced instead of each holding its own slice of it.

**It is last, and that placement is the whole of its correctness.** Step 3's
rulings are written into lane transfer queues and step 4's declines into the
decision log — so a lane brought forward at step 0 would be stale again by the
time the run ended, and stale in the most misleading way: updated once, visibly,
and therefore trusted. Bringing every lane forward here means each one starts
its next `--wss-start` already holding the mediations, the approvals and the
queue entries this run filed for it.

Per lane, in its own worktree, `git merge --ff-only` the integration branch,
through `git-writer`. **This is `--wss-wrap`'s step-0 sync-forward, fanned out
from the main checkout** — the same move that skill makes for the one lane it
is sitting in, made here for every lane at once, which is the part no wrap can
do from where this skill runs. Its constraints and its refusals are that rule
and `git-writer`'s lane-landing rule, and they are **not restated here**: a
second copy is a second thing to keep true.

Name the lane and the distance moved for each one that lands.

**One state is this step's own, because no wrap ever meets it: a dirty
worktree.** Skip it and say so. Uncommitted work in a lane worktree belongs to
whoever is sitting in it, and this run does not know what it is — a wrap is
invoked *by* that person and can commit it, and this run is not and cannot.
Merging over it is the one thing here that could destroy work rather than
merely confuse it.

**Never move a branch under a live session.** A lane worktree with a session
running in it is mid-batch, and a batch whose `HEAD` and working tree change
underneath it produces diffs that describe nothing. A dirty worktree is the
cheap signal and the one to act on; there is no reliable clean-worktree
liveness check today — lane session state is designed and unbuilt — so
**say which lanes were skipped and why, and treat a clean-but-live lane as a
known gap rather than an impossibility.**

**A skipped lane is not a failed run.** Steps 0–4 have already done the work
this skill exists for; this step is redistribution, and a lane that has to wait
for its own next batch is exactly where it would have been before this step
existed.

## Step 6 — Close the run out through `--wss-wrap`

**Invoke `wss-wrap` and let it run its whole ritual.** A run that has written
into every lane's inbox, drained the conflict queue and filed an audit entry is
a run whose output dies in the working tree if the session clears. The close-out
has an owner; this skill calls it rather than describing what the user ought to
do next.

**Ask for the commit, in that turn.** This skill has no flag, so it has no grant
to pass on — [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md)'s *authorization
comes from the flag* rule, and a skill that granted itself one by writing it here
would be the exact move that rule forbids. Say what the commit would cover and
ask. The user is present for the whole run — every conflict was mediated and
every dependency ruled on by them — so one more question is cheap, and a refusal
just leaves the tree as it was.

**Never offer the push.** Step 0 landed sibling lanes' branches onto
`WSS.branch.integration` locally and ruled there that publishing them is not this
run's act. A push here would carry those landings to the remote as a side effect
of tidying up. Ask for the commit; name what is unpushed; stop.

Everything else is `wss-wrap`'s — the task list, the memory check,
`handoff-writer`'s currency pass, the closing counts. None of it is restated
here, and a change to any of it belongs in that file.

**Step 6 runs even when step 5 skipped every lane.** The queues, the deletions
from `WSS.lanes.conflicts` and the audit entry are already written by then, and
those are the writes a close-out exists to make durable. A run that reconciled
nothing still changed the tree.

## What this skill does not do

- **It does not write any lane's records.** Every finding goes to a queue, and
  the receiving lane's `--wss-start` is what integrates it.
- **It does not decide anything.** Conflicts are mediated by the user and
  dependencies ruled on by the user; a run where neither happened produced
  nothing and should say so.
- **It does not remember a deferral**, and that is deliberate rather than a
  gap. Only a decline is written down, because only a decline is a claim that
  the derivation was wrong.
- **It does not trust the conflict inbox.** An entry there is evidence from a
  session that is long gone, and it is re-verified against the records before
  anything is done with it.
- **It does not commit by hand, it confers no grant, and it never pushes.**
  Step 6 hands the close-out to `--wss-wrap`, which asks the user for the
  commit in that turn; the commit itself is `git-writer`'s as everywhere else.
  Nothing this run does reaches a remote: step 0's landing and step 5's
  redistribution both move a ref onto commits that already exist — authoring
  nothing, publishing nothing — and anything more than a fast-forward is
  refused and reported.
- **It does not run from a lane**, and does not degrade to a partial run there.
