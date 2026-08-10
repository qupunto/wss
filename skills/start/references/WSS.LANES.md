# Starting a batch from a lane worktree

**Read this only where lane mode is on** — a `.claude/WSS.LANE` selector is
present in this checkout, or the manifest declares `WSS.lanes.named`. A project
worked from a single checkout skips it entirely; nothing here can apply, and
there is nothing to say about it.

It holds what `--wss-start`'s Phase 0 hands over, **in the order written**, all
of it before anything reads a `WSS.record`.

**This is not the same thing as partitioning a batch into lanes.** Phase 3 does
that inside one checkout, driven by `WSS.lanes.exclusive`, `.serialize` and
`.generated`, and it runs whether or not this file was ever read.

## 1. Sync forward before anything reads a record

Where the worktree's branch is behind `WSS.branch.integration`, `git fetch` and
`git merge --ff-only` it up to date before Phase 0 reads anything — a batch run
against records the integration branch has already moved past re-executes
obligations that were already executed there, the lane handoff being the copy
that bites. Where the two branches have genuinely diverged, stop and report:
reconciling them is a merge decision, not a batch's first step.

The wrap-side twin lives in `--wss-wrap`: it opens with the same sync-forward,
before it reports anything, then pushes its branch, lands it on
`WSS.branch.integration` by fast-forward, and syncs back. **This sync-forward is
what keeps that landing possible** — a lane that never catches up diverges, and
the landing push is then refused rather than merged.

## 2. Drain the lane's transfer queue

`WSS.lanes.named.<lane>.transfer` is this lane's inbox: what every *other* lane
filed as work it believes this lane owns. Nothing else consumes it, and an
undrained queue is work that has been delivered and is invisible.

The order is not arbitrary — **the sync-forward is what delivers the entries.**
A sibling lane appends on its own branch, so its entry arrives here only once
that lane has landed on `WSS.branch.integration` and step 1 has pulled it in. A
queue that looks empty on a lane that has not synced forward proves nothing.

Per entry, in file order:

- **Move it into the record its `[target]` names** — `todo`, `openDecisions` or
  `roadmap`, resolved through this lane's own paths — and delete it from the
  queue. The write goes through that record's owner, the same as any other:
  `--wss-todo` for the first two, `--wss-plan` for a roadmap goal.
- **A queue entry is a request, not an instruction.** Where it does not belong
  here, delete it with one line saying why rather than leaving it to be re-read
  every run. Say so in the orientation; the filing lane is entitled to know its
  request was declined.
- **Carry `[critical → why]` across unchanged**, and never add one. A lane may
  not set another lane's priority; only the **user** may, which in practice
  means an entry arrives marked from one of `lane-record-sync`'s two gates —
  a mediated conflict, or an *accept as critical* ruling.

**Eligibility follows provenance; priority follows the marker.** An entry that
came through `lane-record-sync`'s approval gate was already ruled on by the
user, so it is eligible for *this* batch as soon as it lands in
`WSS.record.todo`. An entry a lane appended outside that gate is drained,
**announced, and waits a run** — derived work reaching a batch with nobody
between is exactly the failure the gate exists to prevent, and an inbox is not a
gate.

Say in one line what was drained, where each entry went, and which are eligible
now. An empty queue is the ordinary state and is said in one line too, never
silently.

## A contradiction goes to the conflicts inbox, not into the work

Where this lane's records and a sibling's cannot both be right — a data shape,
an endpoint, a contract — append an entry to `WSS.lanes.conflicts` and carry on
with what is unaffected. Do not resolve it: a session in one lane cannot mediate
between two, and picking whichever reading unblocks this batch is how one lane's
assumption becomes the project's by default. `lane-record-sync` is the only
consumer, and it re-verifies the claim rather than acting on it —
[`WSS.RECORD-CONTRACT.md`](../../../workflow/WSS.RECORD-CONTRACT.md) holds the
entry shape. Filing is the whole action; say that you filed it.
