---
name: wss-start
description: "Pick up the project's pending work and do it — settle the open decisions first, select a batch from the backlog, partition it into lanes that cannot collide, and run those lanes in parallel. SHORTHAND: `--wss-start`. Also trigger on \"carry on with what's pending\", \"pick up the next thing\", \"keep going with the backlog\"."
---

# Starting the next block of work

**Project facts come from `.claude/WSS.WORKFLOW.json`** — `WSS.record.*`, `WSS.commands.*`,
`gate`, `agents.*`, `WSS.lanes.*`, `WSS.hazards.*`. Read it first. Without a manifest,
fall back to conventional names, skip what you cannot resolve, and say so in one
line rather than guessing. Where a `.claude/WSS.LANE` selector names a lane,
`WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for `todo`, `openDecisions`,
`handoff` and `roadmap` — [`WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md)'s
resolution rule —
and that lane's `scope` globs bound the batch: partition within them, and treat
work outside them as another worktree's.

Three records hold the pending work and they answer different questions:

| Record | Answers | Precedence |
|---|---|---|
| `WSS.record.openDecisions` | What can't responsibly start until a choice is made | **First, always** |
| `WSS.record.todo` | What could start today, with the detail to do it | Second |
| `WSS.record.roadmap` — this lane's, where a selector resolves one | What goal is being worked toward, and what order its blocks go in | Only when the first two are dry |

Under lanes there is a step before all three: **the transfer queue is drained in
Phase 0**, so what a sibling lane filed is already sitting in the records above
by the time this table applies. It is never read as a fourth source here.

Decisions come first because an open decision is not a task that can wait — it
is a choice that **gets made anyway**, silently, by whoever writes the first line
of the code that depends on it.

Who may write each record is
[`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md). **This skill
writes source code and commits. It writes no record file directly** — it calls
the primitive that owns each one.

## Shape of the run: the user is present exactly once

Phase 1 needs them and nothing else does. Everything after it is autonomous by
design — the user is often away while a batch runs — so do not stop mid-batch to
ask whether to keep going.

The one unavoidable second interruption is the test suite, where the project
gates it behind the user's own words (`WSS.commands.testConsentEnv`). Budget for
**one** such run, at the end. Do not spend it early.

## Keep the orchestrator's context for deciding, not for reading

A subagent's context is discarded when it returns; this file, once invoked, is
here for the rest of the session. So: **if a step's cost is *reading* rather than
*deciding*, delegate it.**

The exception is the three planning records above — they **are** the input, and a
summary of them cannot be partitioned into lanes. Read those directly. Never read
the decision log whole; go through `WSS.record.decisionsIndex`, pick the entries that
bear on the batch, and hand each lane the names of its own.

No source file needs to be open in this context. Locating and reading code is
what the lanes are for.

## Phase 0 — Orient

1. **Pin the tree.** `git rev-parse --short HEAD`, `git status --porcelain`, and
   `git log origin/<integration>..<integration> --oneline`. A dirty tree or
   unpushed commits are not a blocker, but say in one line what is already there.
   **If more than one session shares this checkout**, starting a parallel batch on
   top of another session's half-finished edits is the failure this phase exists
   to catch. If the dirt is not this session's, stop and say so rather than
   building on it.

   **In a lane worktree, two moves come first.** Lane mode is on where a
   `.claude/WSS.LANE` selector is present, or the manifest declares
   `WSS.lanes.named`. Where it is, **read
   [`references/WSS.LANES.md`](references/WSS.LANES.md) now and follow it before
   step 3 reads any record** — it holds the sync-forward and the transfer-queue
   drain, in that order, and where a cross-lane contradiction gets filed. Where
   it is off none of it can apply: skip the file and say nothing about it.
2. **Check the pipeline before adding to it.** Where the manifest names a CI
   workflow, query it. A pipeline can sit red for days before anyone notices, and
   a batch merged onto a red one hides which change broke it. If it is red,
   **fixing that is the batch** — say so and skip to Phase 4 with one lane.
3. **Read the three planning records**, plus `WSS.record.decisionsIndex`.
4. **Create the task list up front** via `--wss-track`: one task per open decision,
   one per lane, plus integration, the suite run, and the record. The list is how
   the user sees where it got to without reading the transcript.

## Phase 1 — Settle the open decisions

Every entry in `WSS.record.openDecisions`, in file order — it is already ordered by
urgency. Present each with its options, its real tradeoffs, the recommendation if
it carries one, and **what it blocks**, because that last field is what makes the
question answerable.

Use `AskUserQuestion`. Batch up to four at a time rather than one call per entry,
and put the recommended option first, labelled.

**"Leave it open" is a legitimate answer and must be offered.** An entry that
genuinely lacks the evidence to decide is correctly still open, and forcing a call
on it produces a decision the first real data will reverse. What is *not*
legitimate is leaving it open while building the thing it blocks.

For each decision the user actually makes, **hand it to `--wss-log`** — which owns
deleting the entry from `WSS.record.openDecisions`, appending the outcome and the
options rejected to `WSS.record.decisions`, and regenerating the index. Do not write
those files here: never-in-both is
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s rule 3, and one owner
is how it stays prevented.

A decision *not* to build something is still a decision and still gets an entry —
that goes through `--wss-todo`, which owns the task-and-reasoning split.

If the user is unreachable and no open decision blocks the batch you would
otherwise pick, proceed and say plainly which entries went unasked. If a decision
**does** block the batch, that is the one case where stopping is right — building
past it is how it gets made by accident.

## Phase 2 — Choose the batch

**Critical first, then section order.** Any item whose body carries
`[critical → why]` is taken before section ordering applies, in file order among
themselves, and **named as critical in the batch statement** — an item that
jumps the queue silently is indistinguishable from one that was simply near the
top. There is one marker and no other grades;
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md) holds why.

Then the rest from `WSS.record.todo`, in section order (it is severity- and
dependency-ordered already). Not everything in it is eligible.

**`WSS.record.todo` may be a provider rather than a file** — an object with a
`provider` key, per
[`providers/WSS.GITHUB-ISSUES.md`](../../workflow/providers/WSS.GITHUB-ISSUES.md). Read
it through that contract, and mind its `--limit`: a list command that silently
returns the first thirty of forty-five items hands this phase a batch chosen
from a truncated backlog, which looks exactly like a batch chosen from the whole
one. When an item lands, closing it is `--wss-todo`'s, the same as deleting a line.

**Then drop the section-order assumption above, because there are no sections.**
An issue list comes back *newest first*, which is not the ordering this phase
expects and is nearly its inverse. Two consequences, both of which pick the wrong
batch rather than failing:

- **Rank has to come from content, not position.** Read the items and judge
  severity and dependency yourself. The first row is the most recent, and the
  most recent is frequently the least urgent. **`[critical → why]` still
  applies and is read out of the body**, exactly as `[blocked → …]` is — that
  is why the marker lives in the body rather than in a section heading, and it
  is the only ordering signal that survives here.
- **Deferral is a marker, not a place.** The "explicitly deferred" exclusion
  below is written for a `## Later` section that does not exist here; under a
  provider it is `[later → why]` on the first line of the body, alongside
  `[blocked → …]`. Both must be read out of the body, and an item carrying
  either is out of scope exactly as it would be in a file. An unmarked item
  filed a minute ago by `--wss-todo` may well be one that was *just* deferred —
  if the body says it was, treat it as deferred whatever the marker says.

**Never autonomously in scope:**

- **Anything that runs against production**, or is written as a deploy runbook.
  Those need a real deploy and a per-step confirmation. Not batch items.
- **Anything explicitly deferred** to a "later" section. Picking one up silently
  reverses a decision the user made.
- **Anything marked blocked** whose decision was not just settled in Phase 1.
- **Anything needing credentials, production access, or a remote host.**
- **Versions and tags** — `--wss-release`'s decision alone, and the changelog entry
  that goes with one is `changelog-writer`'s.

**Then size it.** Three to five lanes is the working range, and the limit is
almost never ambition — it is Phase 3's partition. Prefer four clean lanes over
seven that need serializing. One backlog item touching disjoint code can split
into two lanes; two separate items touching one file must merge into one.

**If the backlog and open decisions both yield nothing eligible** — which will
happen, and is a good sign — go to the roadmap this checkout resolves and take the
first open block of the current goal. **In a lane worktree that is that lane's
roadmap**, and a goal belonging to another lane is that worktree's work rather
than a fallback for this one.
Do not improvise its breakdown here: hand the block to `--wss-plan`, which
turns it into concrete backlog items with dependencies, then run Phase 2 again
over what that produced. **A roadmap block is a paragraph; a lane needs a file
list.**

**State the batch in three or four lines before spending anything**: which items,
which lanes, what was skipped and why, and which decisions Phase 1 unblocked.
That is a statement, not a request for approval.

## Phase 3 — Partition into lanes that cannot collide

Lanes run concurrently in one shared working tree. Two agents editing one file do not merge — the second write wins
and the first lane's work is gone, silently, with its tests still passing in its
own transcript.

So the unit of parallelism is not the task. **It is the file set.** Assign every
lane an explicit list of files it owns and may write, and state that it must not
write anything outside that list — if it needs to, it stops and reports rather
than reaching.

**Disjoint write sets are not enough. Count what each lane *reads* as well.** Two
lanes must not run concurrently when one reads a file the other writes. **A
read/write race corrupts nothing, so nothing looks broken**: what it produces is a confident, well-cited, wrong report, citing a file
where the evidence genuinely was a moment ago.

So the brief for each lane carries **two** lists — the files it may write, and the
files it depends on being stable. Where one lane's read list intersects another's
write list, they go in different waves. When in doubt, serialize: a wave costs
wall-clock, and a wrong finding costs a change that looks right.

The manifest's `lanes` block says which paths are dangerous and how:

| Manifest key | Rule |
|---|---|
| `WSS.lanes.exclusive` | **At most one lane in the entire batch.** Paths where two concurrent edits produce two artifacts that cannot both be right — a schema plus its migrations being the canonical case, since two parallel migrations get two timestamps and the second is authored against a schema that no longer exists. If two items need changes here, merge them into one lane making both in a single migration, and run that lane **first, alone**, so every other lane generates against the final state. |
| `WSS.lanes.serialize` | Shared machinery. A lane that **modifies** one runs alone or first. Lanes that only **call** it run in parallel freely. |
| `WSS.lanes.generated` | Nobody. Regenerating is the orchestrator's, once, after the exclusive lane. |
| A given route file or service | Single owner, no exceptions. Two lanes adding endpoints to one router is the classic silent loss. |
| Test files | One per lane, named for its feature. Fixtures scoped to the lane's own rows (see Phase 5). |
| **Every `WSS.record.*` file** | **No lane writes these.** Every lane will want to and they would collide on every line. The orchestrator records once, in Phase 6, through the owning primitives. |

**When a partition cannot be made disjoint, serialize — do not isolate.**
Worktree isolation looks like the answer and is usually a trap: a fresh worktree
needs the gitignored things a subagent cannot supply — environment files, a
dependency symlink or install, any generated client — so an isolated lane arrives
unable to run anything. Two sequential lanes are cheaper than one lane that
cannot verify itself. Check `worktree.symlinkDirectories` in
`.claude/settings.json` before assuming otherwise.

**Order the WSS.lanes.** Anything others build on goes first regardless of its own
priority: exclusive paths, then shared modules, then features, then the tests for
them. Lanes in the same wave are concurrent; waves are sequential.

**Assign each lane a model tier.** Lanes inherit the session's model unless the
launch overrides it, which prices a doc-sync lane the same as the schema lane.
Inherit by default; hand a cheaper tier only to a lane that is mechanical *and*
fully specified — its brief names exactly what to change, and checking the
result is cheap and local. Never downgrade the exclusive lane, a lane whose
output others build on, or Phase 5's verification. The asymmetry is deliberate:
a wrong downgrade produces plausible-but-wrong work, and the redo through
integration costs more than the saving — when unsure, inherit. State tiers
relative to the session ("session model", "a cheaper tier"), never as model
names, which rot; and name every downgrade when stating the batch, so an
economy stays a visible decision rather than a silent one.

**Then recut the task list to the partition.** Step 4's lane tasks were foreseen
before any lane existed; replace them with one task per actual lane, named with
its wave and its tier, the moment the batch is stated. The list is where a tier
downgrade stays visible after the batch statement scrolls away.

## Phase 4 — Run the wave

All lanes of a wave in **a single message so they run concurrently**. Route each
to its owner from `agents.*` — this skill writes no feature code itself:

| Lane's work | Manifest role |
|---|---|
| Schema shape, service boundaries, "how should this be modeled" | `WSS.agents.architecture` first (advises only), then the lane that implements it |
| Endpoints, services, domain logic, queries | `WSS.agents.implement` |
| Containers, deployment and build config, operational scripts, CI | `WSS.agents.infra` |
| Test coverage, the authorization matrix, validation boundaries | `WSS.agents.test` |
| Proving a specific vulnerability before anyone fixes it | `WSS.agents.exploit` — rare and expensive, against a named surface only |

Where a role is undeclared, do that lane's work inline and say so; do not
substitute a different role's agent, which is how a test lane ends up writing
feature code.

Each lane's brief carries, explicitly:

- **The backlog item verbatim**, including its `file:line` citations — with the
  standing caveat that line numbers drift and the file plus description is the
  real reference. Re-locate rather than concluding an item is stale.
- **Its file ownership list**, and the instruction to stop rather than write
  outside it.
- **Its model tier from Phase 3** — passed as the launch's model override where
  the harness exposes one; where it does not, every lane inherits and the
  assignment costs nothing.
- **The decision entries that bear on it, by name** — looked up once here from
  the index, not six times by six lanes. Plus `WSS.record.behaviour` for what the
  rule currently *is*, and any `WSS.hazards.*` pointer that applies to its phase.
- **Whether it may run the test suite at all.** Where the project gates the suite
  behind a consent token, a lane cannot run it — not the whole suite, not one
  file, not a single filter, because the gate is in the harness rather than in the
  command. Say this explicitly: "do not run the full suite" reads as though a
  targeted run were the sanctioned alternative, and a lane that discovers
  otherwise mid-task has already wasted the attempt. Give the lane the sanctioned
  alternative instead — a disposable environment it builds, exercises and drops
  entirely within its own scope. Where the manifest names one under `WSS.hazards.*`,
  point at that; a lane left to invent one will reach for the shared state the
  gate exists to protect.
- **A test lane is the case that bites**, and it needs saying separately: it
  writes files it cannot execute even once. **Budget an iteration after the
  consented run**, and do not treat a test lane's report as
  the end of its own task.
- **Prove the guard by breaking the code on purpose.** An assertion proves
  nothing until it has failed against the broken version. A test can pass on
  first run against the very bug it targets when something upstream of the code
  under test rejects the input first — request validation firing before the
  handler, for instance — so the guard is never actually exercised.
- **Run the grep that would disprove a negative claim** before reporting "nothing
  does X" — [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#negative-claims).
- **Do not touch any record file.** Report what changed and why; Phase 6 records
  it.

## Phase 5 — Integrate and verify, once

Lane reports are evidence, not verification. **Read every lane's diff** before it
counts as landed. A lane that reports "74/74 passing" has told you about its own
transcript, not about the tree.

**!important — a lane that dies without reporting may have left the code
deliberately broken.** Lanes are told to prove a guard by breaking it on purpose;
a lane killed mid-cycle — API error, timeout, the user stopping it — never reaches
the restore. The residue is dangerous precisely because it is designed to look
plausible: an authorization check quietly relaxed one tier, at both the route and
the service, with the surrounding names still describing the stricter rule. It
reads as correct at a glance and it typechecks clean.

So when a lane does not return a report, treat its output as **suspect rather
than merely incomplete**:

- Instruct lanes to mark deliberate breakage with a greppable token, then grep for
  it. That is the cheap check, not the sufficient one: a mutation can be
  structural — moving a write outside its transaction — and carry no marker.
- **Verifying one mutation was restored says nothing about the others.**
- The only reliable check is behavioural: run a harness over the invariants the
  lane was supposed to establish. If those assertions fail against a leftover
  mutation, you also get break-on-purpose evidence for your own repair free.

In order, and none of these are optional:

1. **Regenerate any generated client, on its own line**, never chained behind
   `&&` where a permission error can fail silently while a stale artifact keeps
   working until a nonsense error appears far from the cause.
2. **`WSS.commands.typecheck`.** Cross-lane type breakage lives here and nowhere
   else — it is the one failure no individual lane can see.
3. **Commit each lane separately** through `git-writer`, telling it which files
   belong to which lane — the partition is yours to know, the trailer and the
   staging rules are its. Before the suite, not after: the suite may reset state
   destructively, and a crash mid-run should cost the run, not the work.
4. **Ask for suite consent, then run `WSS.commands.test` once.** Use the coverage
   command, not a bare test run — a green suite says nothing about the coverage
   gate, and `gate.coverage` is what CI enforces. A coverage gate can sit red
   across several pushes while every local run is green.
5. **Stamp the run through `sweep-tracker`**, as the `test-run` entry: the sha
   the run ran against, the result, and the runtime test count. Not written here
   — the checkpoint has one writer, the same reason Phase 6 hands every record
   to its owner. **Only after a full consented run whose result you read.**
   Consent refused, a run that died part-way, or a subset of the suite means **no
   stamp at all**: `--wss-stocktake` skips its own run on the strength of this entry,
   so one no run earned is worse than none. A red result *is* stamped, as red —
   [`WSS.SWEEP-CHECKPOINT.md`](../../workflow/WSS.SWEEP-CHECKPOINT.md) has the fields and
   the two things that void a carry-forward. Nothing here reads the entry back;
   the baseline is a commit this batch just made, so no carry-forward could
   apply either way.
6. **When a test fails only in CI, suspect the run's *shape* before the code.**
   CI usually allocates far fewer parallel workers than a dev machine, so the
   same suite concentrates into fewer partitions holding far more shared state.
   **Never assert against an unscoped query or listing** — scope every assertion
   to the test's own data, or it passes alone and fails under density.

**Expect the first consented run to fail, and treat that as the phase working
rather than as a setback.** Two kinds of failure are normal here and neither is
visible from inside any lane:

- **Tests written blind.** No test lane could execute its own files, so import
  slips and fixture collisions surface here first.
- **Pre-existing tests that encoded a rule the batch deliberately changed.**
  These are not bugs and must not be "fixed" by loosening the assertion. Move each
  to the new rule and say in the commit why the old assertion was true when
  written.

**A lane whose work does not survive this phase is not done.** Report it as
in-progress with the blocker named, and leave its backlog item standing. Half a
batch landed honestly beats four lanes described as finished.

## Phase 6 — Record through the owners, then close out

This skill writes no record file. Each of these is a handoff:

**Run them one at a time, never concurrently.** Their write sets look disjoint —
one primitive per record — which is exactly what makes parallelising them
tempting, and it is wrong. **Every record writer re-verifies its claims against
the *other* records before writing**, so each one's read set is all of them. That
is the read/write race Phase 3 describes.

1. **`--wss-todo`** — remove what shipped, and rewrite anything that turned out
   bigger than its checkbox with what was actually learned. Completed items
   *leave*; they are not kept struck through.
2. **`--wss-log`** — any non-obvious call a lane made while building. Phase 1's
   decisions are already recorded.
3. **`behaviour-writer` and `reference-writer`** — what the *code* changed:
   `WSS.record.behaviour` for runtime rules, `WSS.record.reference` for schema and
   architecture. Straight to the owning primitive, not through `--wss-docs`, which
   owns the site and no longer writes either record. Invoke `--wss-docs` separately
   where the change also earns a page.
4. **`--wss-plan`** — only if a block advanced or completed. **From a lane
   worktree that is the whole of it**: a lane session records the goal's
   progress and never raises the milestone question, because a mark is a
   checkpoint for the whole project. From the main checkout, `--wss-plan` is what
   asks the user and marks a milestone completed in `WSS.record.releases`; that mark
   is what authorises a release, and it is never inferred from lane reports.
5. **New open decisions.** A batch that surfaced a choice and settled it silently
   has done the thing Phase 1 exists to prevent. Route it through `--wss-todo`, to the
   open-decisions record if still open.
6. **`--wss-tools`** if any lane touched a skill or agent file.
7. **`handoff-writer`** — what the batch changed, plus any `!important` it
   created or resolved, so the next session inherits it. Not `--wss-wrap`: this skill
   grants commit and not push, and an invoked skill inherits the caller's grant,
   so calling the whole closing ritual here would end the session on `--wss-start`'s
   authority rather than the user's. The user typing `--wss-wrap` is what gets the
   ritual and the push.

## What this skill does not do

- **It does not push, and nothing it invokes may push on its behalf.** `--wss-start`
  covers committing; publishing is the user's call. The commits themselves go
  through `git-writer`, which inherits this commit-only grant.
- **It does not review existing code.** Finding what is wrong with what is already
  there is `--wss-stocktake`; this skill builds what is not there yet.
- **It does not invent documents.** If nothing fits, say so rather than inventing
  structure — `WSS.RECORD-CONTRACT.md`'s standing rule, and it holds here.
