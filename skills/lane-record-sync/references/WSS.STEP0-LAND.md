# Step 0 — Land what the lanes have delivered

This skill reads every lane **at the integration branch's state**. So, before
anything is read, bring each named lane's branch into `WSS.branch.integration`
— **by fast-forward only, through `git-writer`** (the main-checkout twin of
`--wss-wrap`'s landing: git-writer's lane-landing rule, same constraints,
local instead of remote). Per lane, in one pass:

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
the merged result back *out*, once the run has finished producing it.
