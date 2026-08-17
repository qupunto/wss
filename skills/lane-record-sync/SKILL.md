---
name: lane-record-sync
description: "Reconcile every lane's records at once — conflicts between them, and work one lane's plans imply for another. Every finding needs an explicit ruling: accept, accept as critical, defer or decline. What is accepted goes to the addressed lane's transfer queue, never its records. Invoke only as its own slash command; it has no flag."
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
dispatch from another skill.

Who owns what is [`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md); what a
queue holds, and every other lane rule, is
[`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md); what a record holds is
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md); the keys are
[`WSS.MANIFEST.md`](../../wss/workflow/WSS.MANIFEST.md).

## Two hard preconditions

**1. The main checkout, never a lane worktree.** If `.claude/WSS.LANE` names a
lane, **stop and say so.**

**2. `WSS.lanes.named` must declare more than one lane.** With none or one,
**say so and stop.**

## What it costs, said before it runs

State, in three or four lines: how many lanes, how many record files that is,
and that every finding will need a decision from the user. Then run.

This is the run the user should be able to stop before it starts. It reads every
lane's `todo`, `openDecisions` and `roadmap`, and the cross-lane comparison is
quadratic in the lane count.

Name in the same statement which lane branches step 0 will attempt to land,
so the one part of the run that moves a ref is visible before it happens.

## The seven steps

Both preconditions above are the only gate this skill has: pass them and every
step below is in play, in order, for the whole run. There is no "lane mode
off" path through this skill the way there can be in `--wss-start` or
`--wss-wrap` — it never runs with fewer than two lanes declared, so nothing
here is conditional on that a second time. Read each step's reference file
right before doing that step, and follow it in full.

0. **[Land what the lanes have delivered](references/WSS.STEP0-LAND.md).** Bring
   every named lane's branch into `WSS.branch.integration` before anything is
   read, so the run reconciles current records instead of stale ones.
1. **[Analyze](references/WSS.STEP1-ANALYZE.md).** Read every lane's records,
   drain the conflict inbox first, then derive conflicts and dependencies from
   what remains.
2. **[Resolve conflicts](references/WSS.STEP2-CONFLICTS.md).** Mediated by the
   user, before anything else is integrated.
3. **[Present every dependency for a decision](references/WSS.STEP3-DEPENDENCIES.md).**
   Four rulings — accept, accept as critical, defer, decline — each with its
   own consequence for the next run.
4. **[Record the run](references/WSS.STEP4-RECORD.md).** The audit entry, the
   conflict-inbox movements, the four ruling counts, and the declines' own
   write to the decision log.
5. **[Return the merged state to every lane](references/WSS.STEP5-RETURN.md).**
   The redistribution half of step 0's pair, run last on purpose.
6. **[Close the run out through `--wss-wrap`](references/WSS.STEP6-CLOSEOUT.md).**
   Runs even when step 5 skipped every lane.
