# Step 1 — Analyze

Read every lane's records, at the integration branch's state. **All lanes, not
just one.**

### Drain the conflict inbox first

**`WSS.lanes.conflicts` is where sessions file contradictions they hit while
doing something else**, and this skill is its only consumer. Read it before
deriving anything: an observed contradiction is better evidence than an
inferred one, because somebody actually ran into it.

**Every entry is a claim, not a conflict.** Re-verify each against what the
records say *now*, at the integration branch's state, before it goes anywhere
— [`WSS.OWNERSHIP.md`](../../../wss/workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing)'s
second-look rule, and it applies with full force here. The reporting session
contributed evidence; the verdict is this run's.

Then, per entry:

- **Reproduces** → it joins step 2's mediation set alongside the conflicts
  derived here. Note that it came from the inbox rather than from analysis;
  the provenance matters to whoever reads the report.
- **Does not reproduce** — already resolved, misread, or the records now agree
  → **delete it, with the reason.** Leaving it means re-verifying the same
  dead claim on every run.

**Either way the entry leaves the inbox.** It is a queue, empty in the steady
state.

**Both movements go in step 4's report — promoted and deleted, with counts and
reasons.**

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
target is `openDecisions`, not `todo`.

**Read `WSS.record.decisionsIndex` too, and drop anything a previous run
declined.** The index is one line per settled decision and is the cheap way
in — the same lookup `--wss-plan` and `--wss-start` use. Say in the opening
how many derivations were suppressed that way, so a shrinking list is visible
rather than mysterious.

**Deferred items are not in that set and must come back.** That asymmetry is
the whole reason both rulings exist — step 3's table.

Delegate the reading where the project declares an agent for it.
