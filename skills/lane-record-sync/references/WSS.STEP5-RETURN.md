# Step 5 — Return the merged state to every lane

Step 0 brought every lane's work **into** the integration branch. This step
sends the result back out, so the lanes end the run holding what the run
produced instead of each holding its own slice of it.

**It is last, and that placement is the whole of its correctness.** Step 3's
rulings are written into lane transfer queues and step 4's declines into the
decision log — so a lane brought forward at step 0 would be stale again by the
time the run ended, and stale in the most misleading way: updated once,
visibly, and therefore trusted. Bringing every lane forward here means each
one starts its next `--wss-start` already holding the mediations, the
approvals and the queue entries this run filed for it.

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
cheap signal and the one to act on; a clean worktree with a live session in it
is indistinguishable from an idle one here, so **say which lanes were skipped
and why, and treat a clean-but-live lane as a known gap rather than an
impossibility.**

**A skipped lane is not a failed run.** Steps 0–4 have already done the work
this skill exists for; this step is redistribution, and a lane that has to
wait for its own next batch is exactly where it would have been before this
step existed.
