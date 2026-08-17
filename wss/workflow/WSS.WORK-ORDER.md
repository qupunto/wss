# Ordering within a unit of work

**Two forces decide what to do first inside one unit of work, and they
disagree: a change other steps depend on must go first regardless of
urgency, while most of what's left shares a slow, repeatable step that
should run once instead of once per change.** Every caller that turns a set
of changes into a sequence — a task list, a shard brief, a review order —
reads this rather than reinventing the ordering from scratch, because
getting the first rule wrong means redoing work, not just reordering it.

**Scope.** This file governs sequencing *within* a single unit of work — the
order changes happen in once the scope is already known. It does not decide
how a batch is partitioned into units, sequenced into waves, or briefed —
that's [`WSS.FAN-OUT.md`](WSS.FAN-OUT.md). It does not decide which tier a
unit launches at — that's
[`WSS.DISPATCH-LADDER.md`](WSS.DISPATCH-LADDER.md). It does not decide
`[critical → why]` — that's [`WSS.LANE-CONTRACT.md`](WSS.LANE-CONTRACT.md).
This file settles ordering within a unit of work, and nothing else.

## Apply these two forces in order

### 1. Ramification beats priority

A change that alters something **other steps build on** goes first, whatever
its own priority. Reordering costs a little; redoing costs the whole step.

Hoist to the front anything that changes:

- a **data model or schema** other steps read or write
- a **shared type, interface or helper** other steps call
- an **auth or permission rule** other steps must satisfy
- a **naming or structural convention** other steps follow
- an **API contract** a caller elsewhere in the sequence depends on

This is the one rule that overrides stated priority. Say so when you invoke
it — "doing the schema change first because steps 3 and 5 query that
table" — so the reordering is visible rather than silent.

### 2. Everything else batches by its expensive tail

Most remaining work shares a slow, repeatable step at the end. Do every
change in the family, **then run the step once**:

| Family | Batch together | Tail, run once after the batch |
|---|---|---|
| Schema / data model | models, fields, relations, enums, indexes | the project's schema sequence — validate, regenerate the client, typecheck, migrate, reseed. Where `.claude/WSS.WORKFLOW.json` names a `WSS.onSchemaChange` skill, that skill owns the exact order |
| API / endpoints | routes, handlers, services, request schemas | the full test suite (`WSS.commands.test`), then iterate on what fails |
| Architecture / infra | compose files, service boundaries, build config | rebuild the stack, then smoke-run it |
| Docs | every doc invalidated by the work above | a single documentation pass at the end |

**Make the tail an explicit step, never an implicit one.** An unlisted step
is a step that gets skipped, and it is usually the step that catches the
mistake — whatever mechanism records the sequence should name the tail as
its own entry, with the batch it depends on stated rather than assumed.

### 3. Keep priority where the first two rules leave it free

After hoisting ramifications, order the **groups** by the highest-priority
change each one contains, and keep the stated order **within** a group.
Grouping is meant to change how work is bundled, not to quietly demote
something that was flagged urgent.

## Do not over-batch

Batching trades **feedback granularity** for fewer expensive runs.

Keep a batch small enough that a failed tail is still diagnosable. When
changes are independent and the tail is cheap, prefer the earlier signal
over the saved run — batching is an optimization, not a virtue.
