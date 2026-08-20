---
name: start
description: "Pick up the project's pending work and do it — settle the open decisions first, select a batch from the TODO LIST, partition it into shards that cannot collide, and run those shards in parallel. SHORTHAND: `--wss-start`. Also trigger on \"carry on with what's pending\", \"pick up the next thing\", \"keep going with the TODO LIST\". COMMITS, NEVER PUSHES."
---

# Starting the next block of work

**Project facts come from `.claude/WSS.WORKFLOW.json`** — `WSS.record.*`, `WSS.commands.*`,
`WSS.gate`, `WSS.agents.*`, `WSS.lanes.*`, `WSS.hazards.*`. Read it first. Without a manifest,
fall back to conventional names, skip what you cannot resolve, and say so in one
line rather than guessing. **Under lane mode, some of these keys resolve to a
lane-scoped file instead, and the batch is bounded by that lane's `scope`
globs** — both are [`references/WSS.LANES.md`](references/WSS.LANES.md)'s, read
where lane mode is on, before step 3 reads any record; a non-lane run needs
neither and says nothing about it.

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
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md). **This skill
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
summary of them cannot be partitioned into shards. Read those directly. Never read
the decision log whole; go through `WSS.record.decisionsIndex`, pick the entries that
bear on the batch, and hand each shard the names of its own.

No source file needs to be open in this context. Locating and reading code is
what the shards are for.

## Phase 0 — Orient

Run the collector first, from the project directory:

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
bash "$S"/skills/start/assets/wss-orient.sh
```

<!-- load-bearing: the only route to contracts that survives publication — see the decision log before removing -->
The two resolution lines are [`contracts`](../contracts/SKILL.md)'
canonical form. `wss-orient.sh` is read-only and offline except a CI query that
degrades to "not checked" rather than a false zero. It emits the tree pin,
the CI result where the manifest names a workflow, and — for the three
planning records plus `WSS.record.decisionsIndex` — each one's resolved path,
whether it exists, its size, and (`openDecisions` only) its entry count. **It
reports facts, never their meaning**: it does not read any record's content,
so step 3 below is never optional because of it.

1. **Pin the tree**, from the block's `== tree ==` section. A dirty tree or
   unpushed commits are not a blocker, but say in one line what is already there.
   **If more than one session shares this checkout**, starting a parallel batch on
   top of another session's half-finished edits is the failure this phase exists
   to catch. If the dirt is not this session's, stop and say so rather than
   building on it.

   **Peer sessions serialize on the one checkout, and the serialization has a
   shape.** Whoever holds it works its branch; `WSS.branch.integration` is
   rebuilt only by the holder, never by a session that arrived second. A second
   session that wants the tree yields it — it does not rebuild the bench under
   the one that has it. The decision log's `2026-08-19 (thirty-eighth)` entry,
   and the paired designer/executor protocol built on it is `(forty-seventh)`.

   **In a lane worktree, two moves come first.** Lane mode is on where a
   `.claude/WSS.LANE` selector is present, or the manifest declares
   `WSS.lanes.named`. Where it is, **read
   [`references/WSS.LANES.md`](references/WSS.LANES.md) now and follow it before
   step 3 reads any record** — it holds the sync-forward and the transfer-queue
   drain, in that order, and where a cross-lane contradiction gets filed. Where
   it is off none of it can apply: skip the file and say nothing about it.
2. **Check the pipeline before adding to it**, from the block's `== CI ==`
   section. A pipeline can sit red for days before anyone notices, and a batch
   merged onto a red one hides which change broke it. If it is red,
   **fixing that is the batch** — say so and skip to Phase 4 with one shard.
3. **Read the three planning records**, plus `WSS.record.decisionsIndex` — the
   block's `== planning records ==` section already named each one's resolved
   path, existence and size; the content is only in the files themselves.

   **What counts as a finding while reading them is
   [`WSS.RECORD-READING.md`](../../wss/tests/WSS.RECORD-READING.md)**, whose runner
   this phase is — read it before trusting any entry's citations or concluding
   that nothing is eligible. It holds the greps for a blocker sitting outside
   `WSS.record.openDecisions`, the deferral-authority test that decides whether
   Phase 2 may reverse a parked entry, and the reason a dead citation and a real
   blocker are indistinguishable at selection time. **An empty open-decisions
   record is not the evidence it looks like**, and that method is where the
   locations a blocker has actually hidden in are kept.

   **This is also where the TODO LIST gets its duplicate read-back.** The
   write-time rule in `skills/record/SKILL.md` — check for an equivalent
   entry before appending — catches what one append-in-progress session can
   see; it cannot catch what only a whole-file read exposes, because a session
   appending one entry has no reason to read the other thousand-plus lines.
   The read above already opened `WSS.record.todo`; use it. Dispatch
   [`agents/wss-survey.md`](../../agents/wss-survey.md) — the Survey rung — pinned
   to `WSS.record.todo` as its whole read set, the one record measured to clear
   [the four-tool spawn floor](../../wss/tests/WSS.TOKEN-ECONOMY.md#per-grant-spawn-floor)
   on its own. Hand it this verdict format — four classes, all found by hand
   and none caught by the write-time rule:

   1. A standing register's line item, re-filed longhand as its own entry.
   2. One figure or concept restated across N entries with no canon named.
   3. A subtask claimed by two entries at once.
   4. An entry that belongs in a standing register and never joined it — the
      inverse of class 1, which a similarity check alone misses.

   Output is clusters of `file:line` pairs, each with a proposed disposition.
   **It detects and asks; it never merges** — entries carry different
   deferral authorities, and `Parked (owner ruled)` versus `Parked (session judgment)` is
   the whole eligibility test Phase 2 applies at the next `--wss-start`, so an
   automatic merge would silently change what a later batch may reverse. Put
   every cluster to the user as a ruling, batched into Phase 1 alongside the
   open decisions — it was never filed as one, so it does not belong in
   `WSS.record.openDecisions`, but it is exactly as blocking: a batch built on
   an unresolved duplicate risks doing the same work twice, or silently
   reversing a deferral nobody re-affirmed. Whatever the user rules, the edit
   goes through `--wss-todo`, same as any other write to that record — this
   step decides nothing and writes nothing. An empty result is the ordinary
   state and is said in one line, the same as an empty transfer queue.
4. **Create the task list up front** via `--wss-track`: one task per open decision,
   one per shard, plus integration, the suite run, and the record. The list is how
   the user sees where it got to without reading the transcript.

## Phase 1 — Settle the open decisions

Every entry in `WSS.record.openDecisions`, in file order — it is already ordered by
urgency. Present each with its options, its real tradeoffs, the recommendation if
it carries one, and **what it blocks**, because that last field is what makes the
question answerable.

**Batch in step 3's duplicate-read-back clusters too**, if it returned any —
each with its proposed disposition standing in for a recommendation. They
never lived in `WSS.record.openDecisions`, but they are asked here rather than
separately: one user-facing moment for everything that blocks the batch.

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
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md)'s rule 3, and one owner
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
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md) holds why.

Then the rest from `WSS.record.todo`, in section order (it is severity- and
dependency-ordered already). Not everything in it is eligible.

**When `WSS.record.todo` is declared as a provider** — an object with a
`provider` key, per
[`providers/WSS.GITHUB-ISSUES.md`](../../wss/workflow/providers/WSS.GITHUB-ISSUES.md) —
Phase 2 does not read it. The decision log's `2026-08-19 (sixty-ninth)` entry
rules that a repository's issues are read on demand only, by a person, and
what that read produces is a triage queue rather than TODO entries — an issue
never enters the TODO list mechanically. A project on this provider therefore
contributes nothing to autonomous batch selection: the batch draws from the
file records instead, and, finding nothing eligible there, falls through to
the roadmap exactly as below.

**Never autonomously in scope:**

- **Anything in `WSS.record.backlog`.** Phase 2 selects from `WSS.record.todo`
  and from no other task record. The backlog holds what nobody scheduled;
  promotion into the TODO LIST is `--wss-todo`'s and a person's, one entry at a
  time. A batch that reaches into it rebuilds the single bag the split exists to
  remove, and does it silently.
- **Anything that runs against production**, or is written as a deploy runbook.
  Those need a real deploy and a per-step confirmation. Not batch items.
- **Anything explicitly deferred** to a "later" section. Picking one up silently
  reverses a decision the user made.
- **Anything marked blocked** whose decision was not just settled in Phase 1.
- **Anything needing credentials, production access, or a remote host.**
- **Versions and tags** — `--wss-release`'s decision alone, and the changelog entry
  that goes with one is `changelog-writer`'s.

**Then size it.** Three to five shards is the working range, and the limit is
almost never ambition — it is Phase 3's partition. Prefer four clean shards over
seven that need serializing. One TODO list item touching disjoint code can split
into two shards; two separate items touching one file must merge into one.

**If the TODO LIST and open decisions both yield nothing eligible** — which will
happen, and is a good sign — go to the roadmap this checkout resolves and take the
first open block of the current goal. **In a lane worktree that is that lane's
roadmap**, and a goal belonging to another lane is that worktree's work rather
than a fallback for this one.
Do not improvise its breakdown here: hand the block to `--wss-plan`, which
turns it into concrete TODO list items with dependencies, then run Phase 2 again
over what that produced. **A roadmap block is a paragraph; a shard needs a file
list.**

**State the batch in three or four lines before spending anything**: which items,
which shards, what was skipped and why, and which decisions Phase 1 unblocked.
That is a statement, not a request for approval.

## Phase 3 — Partition into shards that cannot collide

**How the batch is partitioned, sequenced into waves, and briefed is
[`WSS.FAN-OUT.md`](../../wss/workflow/WSS.FAN-OUT.md)'s** — the file set as the
unit of parallelism, the two-list write/read collision rule, the
`WSS.lanes.*` table, serialize-not-isolate, wave ordering, the single-message
launch, and the brief's required fields. Read it now rather than reconstructing
it from feel.

**Match each shard against [the dispatch ladder](../../wss/workflow/WSS.DISPATCH-LADDER.md).**
Read it top to bottom and take the first rung whose key holds, then state the
rung and the matching key when the batch is stated, per the ladder's own
`## Citing a rung`.

**Then recut the task list to the partition.** Step 4's shard tasks were foreseen
before any shard existed; replace them with one task per actual shard, named with
its wave and its rung, the moment the batch is stated. The list is where an
Analyze-rung launch stays visible after the batch statement scrolls away.

## Phase 4 — Run the wave

**The launch itself, and what every shard's brief must carry, are
[`WSS.FAN-OUT.md`](../../wss/workflow/WSS.FAN-OUT.md)'s** — all shards of a wave in
a single message, and the brief's required fields, including one this skill
states again because it drives the launch call itself:

- **Its rung from [the dispatch ladder](../../wss/workflow/WSS.DISPATCH-LADDER.md)**
  — assigned in Phase 3, and cited in the same breath as the launch, per that
  file's "Citing a rung". **Route the shard to its rung's declared agent and let
  that agent's own `model:` be the tier.** That key is the resolved end of a chain
  the ladder fixes at every link — task type picks the agent, the agent's rung is
  what the agent is, the rung's tier is the ladder's table — which is why
  `wss-doctor.sh` fails an `agents/*.md` whose frontmatter disagrees with its row.
  **What the launch call itself passes is settled once, in the ladder's "Which
  model runs a task", and is not restated here** — including the one case that
  reaches for the tier mapping directly, which is no agent covering the task type
  at all. The ladder calls that a gap in itself, to be reported rather than
  settled quietly by the caller.

Route each shard to its owner from `agents.*` — this skill writes no feature
code itself:

| Shard's work | Manifest role |
|---|---|
| Schema shape, service boundaries, "how should this be modeled" | `WSS.agents.architecture` first (advises only), then the shard that implements it |
| Endpoints, services, domain logic, queries | `WSS.agents.implement` |
| Containers, deployment and build config, operational scripts, CI | `WSS.agents.infra` |
| Test coverage, the authorization matrix, validation boundaries | `WSS.agents.test` |
| Proving a specific vulnerability before anyone fixes it | `WSS.agents.exploit` — rare and expensive, against a named surface only |

**Where a role is undeclared the shard still leaves this context** — route it to
**its rung's own agent** instead of a general-purpose subagent: `agents/wss-survey.md`
for Survey, `agents/wss-analyze.md` for Analyze, `agents/wss-design.md` for Design,
`agents/wss-execute.md` for Execute, matching the rung Phase 3 already assigned this
shard against [the dispatch ladder](../../wss/workflow/WSS.DISPATCH-LADDER.md) — and say
so. Do not substitute a different *role's* agent, which is how a test shard ends up
writing feature code; routing by rung on an undeclared role is not the same move,
because every rung agent is role-agnostic by construction.

**The cost is real: say it plainly.** A shard
whose rung's tool grant withholds something the work turns out to need now fails
rather than proceeding on the widest possible grant — the ladder treats that as a
match failure working correctly, not as a reason to widen the fallback back out.
Grant cost is priced per spawn, absolute, so the common case (undeclared) is what
had to stop being the expensive one.

Undeclared is the normal case, not a misconfiguration: `--wss-adopt` tells a
project with no agent files to omit `agents` entirely, on the strength of the
rung-agent fallback. Inline is the
exception — for a shard too small to be worth a brief — because a shard run inline
spends its whole read-and-edit cycle in the orchestrator's context, and every
phase after it pays that context back on every call it makes.

In this skill's own phasing, the fan-out method's "consented run" a test shard
budgets an iteration after is Phase 5's; a shard's commit happens in Phase 5
step 3, through `git-writer` — as part of the batch commit, never as a commit
of its own; its record entries are written in Phase 6.

## Phase 5 — Integrate and verify, once

Shard reports are evidence, not verification. **Read every shard's diff** before it
counts as landed. A shard that reports "74/74 passing" has told you about its own
transcript, not about the tree.

**!important — a shard that dies without reporting may have left the code
deliberately broken.** Shards are told to prove a guard by breaking it on purpose;
a shard killed mid-cycle — API error, timeout, the user stopping it — never reaches
the restore. The residue is dangerous precisely because it is designed to look
plausible: an authorization check quietly relaxed one tier, at both the route and
the service, with the surrounding names still describing the stricter rule. It
reads as correct at a glance and it typechecks clean.

So when a shard does not return a report, treat its output as **suspect rather
than merely incomplete**:

- Instruct shards to mark deliberate breakage with a greppable token, then grep for
  it. That is the cheap check, not the sufficient one: a mutation can be
  structural — moving a write outside its transaction — and carry no marker.
- **Verifying one mutation was restored says nothing about the others.**
- The only reliable check is behavioural: run a harness over the invariants the
  shard was supposed to establish. If those assertions fail against a leftover
  mutation, you also get break-on-purpose evidence for your own repair free.

In order, and none of these are optional:

1. **Regenerate any generated client, on its own line**, never chained behind
   `&&` where a permission error can fail silently while a stale artifact keeps
   working until a nonsense error appears far from the cause.
2. **`WSS.commands.typecheck`.** Cross-shard type breakage lives here and nowhere
   else — it is the one failure no individual shard can see.
3. **Commit the whole batch grouped by CONCEPT** — never per shard, never per
   file — through `git-writer`, and **wait until every shard has finished
   first**. Sharding exists so parallel work cannot collide in one commit; it
   is not a unit of history. A commit is one concept and may span a dozen files
   across several shards — a fix to a workflow is one fix however many shards
   touched it — and per-shard commits bloat the history with divisions no
   reader of it cares about. The decision log's `2026-08-19 (thirty-ninth)`
   entry, which supersedes the earlier one-branch-per-shard-batch draft.

   - **One commit per concept, each on its own typed branch off
     `WSS.branch.publish`**, per the taxonomy: `feature/` `fix/` `refactor/`
     `docs/` `chore/` `release/`, as `folder/short-hyphenated-description`,
     lowercase, an issue id after the slash spelled as the tracker spells it.
   - **Nothing commits directly to `WSS.branch.integration`.** It is a
     disposable test bench, rebuilt at will, so a commit that exists only there
     dies when it is rebuilt. **Even a one-liner gets a `chore/` branch**
     (`(thirty-fifth)`).
   - **Every message follows the commit profile** — `(fortieth)`.
   - **The grouping is your judgment at commit time and nothing downstream can
     check it, so state it in the wrap**: which concepts you cut, and which
     shards fed each. A grouping nobody is shown is a grouping nobody can
     challenge.
   - **Capture every shard's report before committing, not after.** Waiting for
     the batch moves the commit further from the work that explains it. The
     edits themselves survive a compaction — they are on disk — but the
     reasoning does not, and the reasoning is what the message was for. That is
     the cost this ruling accepted; it is not an argument for committing per
     shard, and it is not a licence to write a thin message.

   Before the suite, not after: the suite may reset state destructively, and a
   crash mid-run should cost the run, not the work.
4. **Ask for suite consent, then run `WSS.commands.test` once.** Use the coverage
   command, not a bare test run — a green suite says nothing about the coverage
   gate, and `WSS.gate.coverage` is what CI enforces. A coverage gate can sit red
   across several pushes while every local run is green.
5. **Stamp the run through `sweep-tracker`**, as the `test-run` entry: the sha
   the run ran against, the result, and the runtime test count. Not written here
   — the checkpoint has one writer, the same reason Phase 6 hands every record
   to its owner. **Only after a full consented run whose result you read.**
   Consent refused, a run that died part-way, or a subset of the suite means **no
   stamp at all**: `--wss-health-check --deep`'s TODO resort skips its own run on the strength of this entry,
   so one no run earned is worse than none. A red result *is* stamped, as red —
   [`WSS.SWEEP-CHECKPOINT.md`](../../wss/workflow/WSS.SWEEP-CHECKPOINT.md) has the fields and
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
visible from inside any shard:

- **Tests written blind.** No test shard could execute its own files, so import
  slips and fixture collisions surface here first.
- **Pre-existing tests that encoded a rule the batch deliberately changed.**
  These are not bugs and must not be "fixed" by loosening the assertion. Move each
  to the new rule and say in the commit why the old assertion was true when
  written.

**A shard whose work does not survive this phase is not done.** Report it as
in-progress with the blocker named, and leave its TODO list item standing. Half a
batch landed honestly beats four shards described as finished.

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
2. **`--wss-log`** — any non-obvious call a shard made while building, and,
   whenever a Design-rung shard ran this wave, the rationale behind its design —
   always, never waved through as obvious. A design returns into this session's
   context and nothing else preserves its why. Phase 1's decisions are already
   recorded.
3. **`behaviour-writer` and `reference-writer`** — what the *code* changed:
   `WSS.record.behaviour` for runtime rules, `WSS.record.reference` for schema and
   architecture. Straight to the owning primitive, not through `--wss-docs`, which
   decides what the site holds and writes neither record. Invoke `--wss-docs` separately
   where the change also earns a page.
4. **`--wss-plan`** — only if a block advanced or completed. **From a lane
   worktree that is the whole of it**: a lane session records the goal's
   progress and never raises the milestone question, because a mark is a
   checkpoint for the whole project. From the main checkout, `--wss-plan` is what
   asks the user and marks a milestone completed in `WSS.record.releases`; that mark
   is what authorises a release, and it is never inferred from shard reports.
5. **New open decisions.** A batch that surfaced a choice and settled it silently
   has done the thing Phase 1 exists to prevent. Route it through `--wss-todo`, to the
   open-decisions record if still open.
6. **`--wss-health-check`** if any shard touched a skill or agent file — its
   default mode sweeps the changed tooling files, runs `wss-tools-inventory.sh`
   and hands off to `--wss-catalog` itself once it restructures anything, but a
   shard that touched files without tripping a sweep still owes the catalog a
   look for a row it never wrote.
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
  there is `--wss-health-check`; this skill builds what is not there yet.
- **It does not invent documents.** If nothing fits, say so rather than inventing
  structure — `WSS.RECORD-CONTRACT.md`'s standing rule, and it holds here.
