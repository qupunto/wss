# Writing the stocktake log, and the audit index

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md), whose [read-inheritance rule](WSS.WRITERS.md#read-inheritance) this follows. Sole writer of `WSS.record.stocktake` and `WSS.record.audits`, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

**How supervised this write is: [`WSS.SUPERVISION-LADDER.md`](../WSS.SUPERVISION-LADDER.md)'s row for the surface — read it before any modify or delete; never restated here.**

`WSS.record.stocktake` is **the stocktake log**, written a whole entry at a time
or one `Outcome` at a time; what this file may and may not hold is
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md). **Frozen records spell the
log's former key, `WSS.record.audits`** — that key now names the audit index
below, and the decision log carries the split.

Resolve the path from `.claude/WSS.WORKFLOW.json`. **This record has no conventional
filename** — a project that has not declared `WSS.record.stocktake` does not have
one, and inventing a path is how a project ends up with two. Say so and stop.

## Append-only, with one exception

The log is chronological and additive: an old entry describing a tree that has
since changed is **correct as written** and is never corrected.

The single field editable in place is **`Outcome`**, which
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#status-fields) declares
for this file. It starts as `logged` and moves when remediation lands. Editing it
does not breach append-only, and it is not a reason to re-audit anything.

## Two kinds of caller, and they want very different amounts

This is why the record has its own primitive rather than living inside
`--wss-stocktake` — [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s split test, in its
starkest form:

| Caller | Wants |
|---|---|
| `--wss-stocktake` Phase 4 | A whole new entry: the full field block plus the coverage block |
| Anything landing a remediation | **One field on an existing entry.** `Outcome`, and nothing else |

The second must not have to invoke an audit procedure to get written.

## Writing a new entry

The caller arrives with the material — it ran the audit. This skill lays it out
and enforces what may go in.

**Fields, in order:**

- **Tree** — the commit the audit ran against, and whether the working tree was
  clean. Not a date alone: a date does not resolve to a tree.
- **Scope** — `--wss-stocktake` or `--wss-full-stocktake`, which dimensions, and whether
  checkpoints were honoured or ignored.
- **Method** — how the reading was done, and by what. **Where no code analysis
  ran, say so in those words.** An entry that lists mechanical checks passing
  reads as "the code was reviewed and found clean" unless it explicitly denies it.
- **Verification** — which findings were re-checked by hand and which are
  agent-reported. This distinction is the point of the field: a reader has no
  other way to calibrate how much to trust the rest.
- **Tests** and **CI** — the counts and the commit each ran against, or the
  explicit absence. "No run exists for any commit in this range" is a result.
- **Findings**, then the carry-over counts and any `[missed by <date> audit]`
  annotations.
- **Outcome** — starts as `logged`.

### The coverage block

Its rules are [`WSS.AUDIT-COVERAGE.md`](../WSS.AUDIT-COVERAGE.md) and they are
followed exactly. **Build `covered` from the auditors' reports, not from the
plan** — the rule that gets bent is *silence is not coverage*, and it gets bent
because a wide `covered` list is what makes the next audit cheap.

## What never goes in

**The resulting tasks.** Those are `WSS.record.todo`'s, written by `--wss-todo`. An audit
entry says what was found; the TODO list says what will be done about it, and the
two move on completely different schedules.

## The audit index — the second surface, and a much smaller one

**`WSS.record.audits` is the index of a project's independent audit passes** — the
frozen reports a stocktake does not produce. One table row per report file, added
when a pass lands: the filename, the pass, its verdict, and what it covered,
plus whatever short narrative the pass earned. Rows and narrative are frozen once
written, the same append-only footing as the log's entries; the opening prose is
the live half. `wss-doctor.sh` fails a report file that has no row.

A project that runs no independent audits never declares the key and this
section never applies. The same no-conventional-filename rule holds: undeclared
means say so and stop.

## Authorization

**None of its own.** Its grant is whatever the caller was granted, and it confers
nothing. `--wss-stocktake` carries commit-and-push scoped to its own record, and this
file is inside that scope — but the push is still the caller's act through
`git-writer`, never this procedure's.
