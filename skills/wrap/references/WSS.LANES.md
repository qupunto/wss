# Wrapping from a lane worktree

**Read this only where lane mode is on** — a `.claude/WSS.LANE` selector is
present in this checkout, or the manifest declares `WSS.lanes.named`. A main
checkout skips it entirely and there is nothing to say about it.

It holds what `--wss-wrap` hands over from a lane: Step 0's sync-forward, which
runs before anything is read or reported, and the landing procedure that follows
the commit.

**Worktree hygiene for a shared checkout is not here** — that applies to a
project with no lanes at all, so it stays in `--wss-wrap`'s *One worktree per
session*, outside this gate.

## Step 0 — sync forward before anything is read or reported

`git fetch`, then `git merge --ff-only` `WSS.branch.integration` into the
worktree's branch. It is the same move `--wss-start`'s lane reference makes at the
other end of a batch, for the same reason one step later: **a report written
from a stale base describes a lane that no longer exists** — a handoff written
without a sibling's landing records obligations as outstanding that were
executed elsewhere.

**The refusal rule is the ordinary one, with one difference: it does not stop
the wrap.** Where the branch has genuinely diverged, report it plainly, say the
report is written against a base the integration branch has moved past, and
**carry on**. A wrap's first duty is pushing the lane's own branch so the work
is not stranded, and that must still happen when everything else is refused.
Never force it, and never resolve the divergence here — a wrap is the worst
moment to take a merge decision, because the context that would explain it is
about to be cleared.

> **Syncing forward does not widen what the report may claim.** After the
> fast-forward this branch contains other lanes' commits, and the closing
> summary and handoff must still describe **this session's own work only**.
> Derive the range from this session's commits — the `WSS.commitTrailer` stamp
> is what distinguishes them — never from "everything new on this branch",
> which attributes every sibling lane's landing to this one.

## Landing the lane, in order

All three steps go through `git-writer` under `--wss-wrap`'s grant:

1. **Push the worktree's own branch.** Unchanged, and it happens first: it is
   the step that must succeed even when everything below is refused.
2. **Land it on `WSS.branch.integration`.** `git fetch origin`, then

   ```bash
   git push origin <worktree-branch>:<WSS.branch.integration>
   ```

   **No leading `+`, ever** — a working copy; the authority on the rule is
   `git-writer` (`wss/workflow/writers/WSS.GIT-WRITER.md`), which wins any
   disagreement. That is the entire safety property, and it is why
   this is not a merge: git resolves the push as a fast-forward or **refuses it
   server-side**. There is no working tree involved, no conflict to hit, and
   nothing half-applied to clean up. The lane normally *is* the integration
   branch plus this session's commits — `--wss-start`'s lane reference syncs forward
   before a batch reads anything — so the fast-forward is the ordinary case.

   **On a rejected push, report and stop. Never force, never resolve it here.**
   A rejection means the integration branch moved: another lane landed while
   this session ran. Say which branch is behind and that the lane needs syncing
   forward before it can land — the next `--wss-start` does exactly that.

   **`WSS.branch.mergeMethod` does not apply.** It governs the one merge
   `--wss-pr` hands `git-writer`, integration onto `WSS.branch.publish`. A
   fast-forward writes no merge commit, so there is no method to choose, and
   wiring one in here would create the merge commit this step exists to avoid.

3. **Sync the worktree back**, as before: `git merge --ff-only` the integration
   branch into the worktree's branch. In the happy path step 2 already made
   the two identical and this costs nothing. Where it cannot fast-forward,
   **report the divergence plainly and stop**; a merge with real deltas is a
   decision, not a wrap step. The lane records are why: an at-merge obligation
   already executed on the integration branch but surviving in the lane's copy
   reads as an instruction to execute it again. The start-side twin lives in
   `--wss-start`'s own `references/WSS.LANES.md`: a lane worktree also syncs forward before a batch
   runs.

Where this session has dispatched work into sibling lanes, append a dispatch note to each target lane's `transfer` queue after step 2 lands on `WSS.branch.integration`, carrying the same three things described for the transfer queue drain in `--wss-start`'s `references/WSS.LANES.md`.

**Step 2 does not fire on an unfinished-work wrap.** Where the wrap ran because
the session is ending rather than because the work was approved — `--wss-wrap`'s
third trigger — push the lane branch and **say plainly that it was deliberately
not landed**. Half-done work on a branch only this session reads is safe; the
same work on the branch every other lane syncs forward from is not, and it
arrives there looking finished.

**Why the push refspec rather than checking out the integration branch and
merging**: `WSS.branch.integration` is checked out in the main checkout, and git
refuses to check out a branch that another worktree holds.

## The milestone question is never asked from here

A mark in `WSS.record.releases` is a checkpoint for the whole project and a lane
session sees one lane of it. `--wss-wrap`'s step 6 stops at naming the goal that
closed; it does not invoke `plan` from a lane worktree.
