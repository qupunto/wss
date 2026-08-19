---
name: stocktake
description: "Take stock of where a project actually is — whether its record matches reality, its conventions and public surface hold, and a release's safety nets exist — then rebuild the TODO list around it. SHORTHAND: `--wss-stocktake`, `--wss-full-stocktake` for everything. Also on \"take stock\", \"are we ready to ship\". Expensive and rewrites the TODO list: not for \"where are we\"."
---

# Taking stock of the project

A deliberate, periodic pass asking **where this project actually is**. It ends
with `WSS.record.todo` rebuilt around the answer and an entry in `WSS.record.stocktake` —
written by [`audit-writer`](../../wss/workflow/writers/WSS.AUDIT-WRITER.md), which owns that file —
recording what was examined, against which tree.

## What it is, and what it deliberately is not

- **Where is this project?** Does the record still describe it, do the
  conventions hold, is the public surface coherent, does it have the tests and
  CI a release depends on, and what should the TODO list look like now? Answerable
  from evidence any repository provides. **That is this skill.**
- **Is this code correct and safe?** Trust boundaries, injection, cascade
  semantics, migration reversibility, whether an assertion passes for the wrong
  reason. Each needs to know what the stack *is*, so each belongs to a
  **project-scoped code-analysis skill**, which this invokes as one more source
  of findings when the project has one (Phase 1).

**Without one, this skill still runs and says so** — it reports that no code
analysis ran, rather than implying the code was looked at and found clean.

The whole discovery phase is read-only and autonomous. The user is often away
while it runs, so don't stop to ask permission for reads. The first time this
skill needs the user is the finding-by-finding review.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: the record paths under
`WSS.record.*` — where a `.claude/WSS.LANE` selector names a lane,
`WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for the
splittable keys, per
[`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md)'s resolution rule, and the rebuilt
TODO list goes to the resolved file; `WSS.agents.audit` for the fan-out and the remediation owners under
`agents.*`; `WSS.commands.typecheck`, `WSS.commands.test`, `WSS.commands.testConsentEnv`,
`WSS.audit.dimensions` and `WSS.audit.invalidates` for scope and blast radius;
`WSS.gate.coverage` for the threshold CI enforces.

**Without a manifest the audit still runs — smaller, and louder.** A supported
mode rather than a degraded one; it is every project on its first pass:

- No audit history, so the run is effectively `--wss-full-stocktake`: skip Phase 0
  step 3 and say so. Step 4's blast-radius default still applies; it never
  depended on the manifest.
- Verification commands are whatever the repo's own tooling declares — a script
  in its build file, a CI config. Where none resolves, **the absence is a
  finding, not a silent skip.**
- **For the audit's own record, ask once**: create the audits file, offering a
  conventional default, or keep this audit's record in the report only. Never
  invent the file silently, and never skip recording silently either.

At close-out, recommend `--wss-adopt`.

Who owns what is [`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md).

## Dispatch through the ladder

Each dimension auditor matches [the dispatch ladder's](../../wss/workflow/WSS.DISPATCH-LADDER.md)
Survey rung — the bottom tier at low effort — **reversing this skill's former
rule to pass the highest tier on every `Agent` call.** Name the rung and key
per the ladder's `## Citing a rung`, and record the rung in the `Method` field
of the `WSS.record.stocktake` entry — a reader has no other way to calibrate
the findings.

The same table governs the orchestrator's own whole-record reads — Phase 0's
baseline lookup and carry-over build, and Phase 1's decisions lookup. Each
reads one record end to end for a small, nameable answer, so each matches
Survey too **once that record clears
[the spawn floor](../../wss/workflow/WSS.DISPATCH-LADDER.md#the-spawn-floor-and-why-a-ladder-rather-than-an-arbiter)**
(`wc -c` it before dispatching). **The floor to clear is `wss-survey`'s own
row**, not the `Tools: *` one — naming the agent is what makes it determinate,
and its four-tool grant floors far lower, so a record can clear it while
sitting well under the figure a `general-purpose` dispatch would have to beat.
Take the row from
[`WSS.TOKEN-ECONOMY.md`'s per-grant table](../../wss/tests/WSS.TOKEN-ECONOMY.md#per-grant-spawn-floor);
no figure is repeated here. **Compare against the floor divided by the turns the
read will be held, not against the floor** — a read kept inline is re-billed on
every later turn, and an audit has many. That correction is the owner's, adopted
from the recompute in the decision log's `2026-08-19 (eleventh)` entry and ruled
in `(twenty-third)`; the verdict consumes its sign and no figure is published.
**In practice this resolves to Survey for every record this skill reads whole**,
including `WSS.record.stocktake` and `WSS.record.decisionsIndex`, which the
one-shot form left inline. Keep's second clause still holds below that divided
floor — a genuinely small record, or a run ending on the turn that reads it.

## Delegate reading, keep deciding

Standing rule for every phase: **if a step's cost is reading rather than
deciding, delegate it and keep the decision.** End an audit holding findings,
verdicts and dispositions — not the contents of the files they came from.

## The six phases

Every phase below runs, in order, on every invocation — the only skips are the
ones a phase's own reference states (`--wss-full-stocktake` skipping Phase 0's
steps 3 and 4, a dimension with no evidence not being dispatched). Read each
phase's reference file right before doing that phase, and follow it in full.

0. **[Scope](references/WSS.PHASE0-SCOPE.md).** Pin the tree, choose the dimensions
   from the project's shape, narrow the two that can be narrowed, apply the
   blast radius, build the carry-over list, and state the plan before spending
   anything.
1. **[Fan out](references/WSS.PHASE1-FAN-OUT.md).** One `WSS.agents.audit` per
   dimension, all in a single message so they run concurrently, each with its
   slice, its baseline, its carry-over share and its brief — plus the project's
   own code-analysis skill where one exists.
2. **[Verify, then run the suite](references/WSS.PHASE2-VERIFY.md).** Re-check every
   `critical` and `high` by hand, check each survivor against the audit history,
   then the mechanical gauntlet once.
3. **[Review with the user, one finding at a time](references/WSS.PHASE3-REVIEW.md).**
   Split the auto-accept pile from the ask-pile first, then walk the ask-pile
   most severe first.
4. **[Rebuild `WSS.record.todo`, then record the audit](references/WSS.PHASE4-REBUILD.md).**
   Decided here, written by the owning skill or writer in every case.
5. **[Close out, and hand the work to its owners](references/WSS.PHASE5-CLOSE-OUT.md).**
   An audit is finished when its findings are committed, not when they are
   written.

## What this skill does not do

- **It changes no code.** Not during discovery, not during review, not "while I'm
  in there". Fixes happen after the audit closes, from the task list the review
  produced, under the user's eye.
- **It doesn't commit or push by hand, and never tags.** Its record goes out
  through `git-writer`. Deciding that a version ships is `--wss-release`'s alone.
- **It doesn't invent documents *silently*.** Everything it produces goes in a
  record file that already exists — except the audits record itself on a first
  pass, where it asks once and then creates the empty file, because
  `WSS.record.stocktake` has no conventional filename and `audit-writer` stops rather
  than guessing one. Creating the container is not writing the record; the entry
  still goes through the owner. If nothing else fits, say so rather than
  inventing structure.

## It absorbs `--wss-check`'s standalone sweep

That sweep and this skill's record dimension are the same job, so there is one
method and it lives in
[`wss/tests/WSS.RECORD-DRIFT.md`](../../wss/tests/WSS.RECORD-DRIFT.md) —
point the auditor at the file rather than copying it, or at the skill that
happens to also run it. Invoke one flag or the other, never both.
