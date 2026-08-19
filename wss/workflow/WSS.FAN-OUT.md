# The fan-out method — shard partition, collision rules, and wave ordering

**One method every fan-out skill reads, so a chosen batch becomes shards by rule
rather than by feel.** Shards run concurrently in one shared working tree. Two
agents editing one file do not merge — the second write wins and the first
shard's work is gone, silently, with its own tests still passing in its own
transcript. A read/write race is worse: it corrupts nothing, so nothing looks
broken, and what it produces is a confident, well-cited, wrong report, citing a
file where the evidence genuinely was a moment ago.

Which tier a shard launches at is
[`WSS.DISPATCH-LADDER.md`](WSS.DISPATCH-LADDER.md)'s, not this file's. Task
ordering within a shard — `[critical → why]`, ramification-first — is
[`WSS.LANE-CONTRACT.md`](WSS.LANE-CONTRACT.md)'s and `skills/track/SKILL.md`'s.
This file settles **how an already-chosen batch is partitioned into shards,
sequenced into waves, launched, and briefed**, and nothing else.

## The unit of parallelism is the file set

So the unit of parallelism is not the task. **It is the file set.** Assign
every shard an explicit list of files it owns and may write, and state that it
must not write anything outside that list — if it needs to, it stops and
reports rather than reaching.

## Two lists, not one: writes and reads

**Disjoint write sets are not enough. Count what each shard *reads* as well.**
Two shards must not run concurrently when one reads a file the other writes.

So the brief for each shard carries **two** lists — the files it may write, and
the files it depends on being stable. Where one shard's read list intersects
another's write list, they go in different waves. When in doubt, serialize: a
wave costs wall-clock, and a wrong finding costs a change that looks right.

## The `lanes` rules

The manifest's `lanes` block says which paths are dangerous and how:

| Manifest key | Rule |
|---|---|
| `WSS.lanes.exclusive` | **At most one shard in the entire batch.** Paths where two concurrent edits produce two artifacts that cannot both be right — a schema plus its migrations being the canonical case, since two parallel migrations get two timestamps and the second is authored against a schema that no longer exists. If two items need changes here, merge them into one shard making both in a single migration, and run that shard **first, alone**, so every other shard generates against the final state. |
| `WSS.lanes.serialize` | Shared machinery. A shard that **modifies** one runs alone or first. Shards that only **call** it run in parallel freely. |
| `WSS.lanes.generated` | Nobody. Regenerating is the orchestrator's, once, after the exclusive shard. |
| A given route file or service | Single owner, no exceptions. Two shards adding endpoints to one router is the classic silent loss. |
| Test files | One per shard, named for its feature. Fixtures scoped to the shard's own rows. |
| **Every `WSS.record.*` file** | **No shard writes these.** Every shard will want to and they would collide on every line. The orchestrator records once, through the owning primitives. |

## Serialize rather than isolate

**When a partition cannot be made disjoint, serialize — do not isolate.**
Worktree isolation looks like the answer and is usually a trap: a fresh
worktree needs the gitignored things a subagent cannot supply — environment
files, a dependency symlink or install, any generated client — so an isolated
shard arrives unable to run anything. Two sequential shards are cheaper than one
shard that cannot verify itself. Check `worktree.symlinkDirectories` in
`.claude/settings.json` before assuming otherwise.

## Order the shards into waves

Anything others build on goes first regardless of its own priority: exclusive
paths, then shared modules, then features, then the tests for them. Shards in
the same wave are concurrent; waves are sequential.

## Launch a wave in one message

**All shards of a wave go out in a single message so they run concurrently.** A
wave launched one shard at a time is not a wave — it is a serial run wearing the
name, and it pays wall-clock for nothing.

## What the brief carries

A subagent shares no cache with its parent or its siblings, so N shards handed
the same pointer pay for N full reads of the same file, where the caller
reading it once and quoting it in the brief pays once. Quote the content a
shard would otherwise open a file to get; reserve a pointer for a fact only one
shard needs, or one small enough to quote exactly — see
[`tests/WSS.TOKEN-ECONOMY.md`](../tests/WSS.TOKEN-ECONOMY.md)'s lens 13,
"Re-reading across agents".

Every shard's brief carries, explicitly:

- **The work item verbatim**, including its `file:line` citations — with the
  standing caveat that line numbers drift and the file plus description is the
  real reference. Re-locate rather than concluding an item is stale.
- **Every exact old-string the brief hands over has been re-grepped immediately
  before dispatch.** The re-verification is
  the **caller's**, never the shard's: Execute's premise is that no judgement is
  needed, and a shard told to re-locate its own anchors is exercising the
  judgement its tier does not pay for. Where an anchor has moved, re-locate it by
  its banner comment or heading — never by the line number — and hand over the
  fresh string.
- **Its file ownership list**, and the instruction to stop rather than write
  outside it.
- **No git command that touches a path outside its own file-ownership list —
  `reset`, `checkout`, `restore`, `clean`, `stash`, or any other command that
  can rewrite or discard working-tree content.** The unit of parallelism is
  one shared working tree (above), so every shard's `git status` shows every
  other shard's — and the caller's own — legitimate in-progress work as, from
  that shard's local view, unexplained dirt. A shard "cleaning" the tree
  before writing its own files destroys work it was never told existed.
  `wss/logs/WSS.DECISIONS.md`'s `2026-08-17 (twenty-fifth)` entry has the
  reasoning.
- **Its rung from [the dispatch ladder](WSS.DISPATCH-LADDER.md)**, named in the
  brief so the assignment is checkable rather than felt. **What the launch call
  itself passes is that file's and is not restated here** — see its "Which model
  runs a task", which fixes the whole chain from task type to the agent's own
  `model:` key. This file settles partitioning; the ladder settles dispatch, and
  the division is the same one the anchor-freshness rule already follows.
- **The operative sentences of any decision entries that bear on it** — quoted
  once from the index, not looked up by name by every shard. Plus the relevant
  slice of the behaviour record for what a rule currently *is*.
- **Whether it may run the test suite at all.** Where the project gates the
  suite behind a consent token, a shard cannot run it — **not the whole suite,
  not one file, not a single filter, because the gate is in the harness rather
  than in the command.** Say that explicitly: a brief reading "do not run the
  full suite" reads as though a targeted run were the sanctioned alternative,
  and a shard that discovers otherwise mid-task has already wasted the attempt.
  Give it the real alternative instead — a disposable environment it builds,
  exercises and drops entirely within its own scope, per any `WSS.hazards.*`
  pointer the manifest names. A shard left to invent one reaches for the shared
  state the gate exists to protect.
- **A shard whose brief includes tests is the case that bites**: it writes files
  it cannot execute even once before the caller's own consented run. Budget an
  iteration after that run, and do not treat such a shard's report as the end of
  its own task.
- **A shard proving a guard must break the code on purpose first.** An assertion
  proves nothing until it has failed against the broken version. A test can pass
  on its first run against the very bug it targets when something upstream of
  the code under test rejects the input first — request validation firing before
  the handler, for instance — so the guard is never actually exercised.
- **Run the grep that would disprove a negative claim** before reporting
  "nothing does X" —
  [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md#negative-claims).
- **What it inherits by default: its file set, and no commit grant.** Say it in
  the brief rather than leaving it to the link — a silent brief is exactly what
  the rule is written against. The rule, its reason and the cost it accepts are
  `git-writer`'s, under "The grant is the caller's, always"
  ([`writers/WSS.GIT-WRITER.md`](writers/WSS.GIT-WRITER.md)).
- **Do not touch any record file.** Report what changed and why; the caller's
  own record phase writes it.

## When a shard stops, the question routes to the records or to the owner

**A rung that stops on a question hands the caller a problem, not a license.**
The caller has exactly two legal moves: answer it from the records — the
decision log, the behaviour record, the reference — quoting the operative
entry in the re-brief so the answer is checkable; or derive it to the owner,
batched into the same ask as the open decisions. The caller's own judgment is
not a source. Every rung already refuses to guess — Analyze stops on a false
premise, Design stops rather than designing around one, Execute has no third
option between executing as written and stopping — so a caller that quietly
settles the question itself and re-briefs is the last place a guess survives,
and it survives wearing the re-brief's authority. The doctrine is the owner's:
`wss/logs/WSS.DECISIONS.md`'s `2026-08-18 (eighteenth)` entry.
