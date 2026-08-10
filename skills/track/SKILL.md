---
name: track
description: "The session task list for multi-step work, built up front and kept honest. SHORTHAND: `--wss-track`. Judge by the SHAPE of a request — several dependent steps — never by a verb in it."
---

# Tracking complex tasks

The tools are `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`.

## The `--wss-track` shorthand

`--wss-track` invokes this immediately, with no confirmation, and overrides the
threshold below: build the list even for work you would otherwise have judged too
small. It authorizes nothing else — this skill writes no file and touches no
record, so there is nothing for a grant to confer.

Where a flag counts is [`README.md`](../../README.md); what it authorizes is
the block `wss-shorthand-flags.sh` injects and
[`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md)'s matrix — the two
copies `wss-doctor.sh` compares, never restated per skill.

## The threshold

Build a list when **any** of these is true:

- The work has **3 or more distinct steps** that can each be finished and
  verified on their own.
- It touches **more than one file or subsystem**.
- The user **listed several things** — numbered, comma-separated, or just
  "do X and also Y".
- You cannot state the whole plan in **one sentence** without an "and then".
- You are **mid-task and it grew**. Late is much better than never; build
  the list the moment you notice.

Skip it — and just do the work — when it is a single edit, a question, a
lookup, a one-file change, or a conversational turn. A one-item list is
noise.

## Build the whole list before starting

Create every task you can foresee **up front**, in one message with parallel
`TaskCreate` calls, then start. A list that grows one task at a time as you
go gives the user no way to see where this is heading, which is most of the
point.

Each task needs:

- **`subject`** — imperative and specific. "Add cascade delete to the parent
  media relations", not "fix media".
- **`description`** — what done looks like, including how it gets verified.
  This is what stops a task being marked complete on vibes.
- **`activeForm`** — present continuous, shown in the spinner while the task
  runs. "Adding cascade delete to media relations".

Write tasks as **outcomes, not motions**. "Understand the auth flow" and
"look at the tests" are not tasks — they are things you do inside a task.
If a step has no verifiable end state, it does not belong on the list.

Call `TaskList` first if a list may already exist, so you extend it instead
of building a confusing parallel one.

## Order by ramification, then group by shared cost

Two different forces decide the order. Apply them in this order.

### 1. Ramification beats priority

A change that alters something **other tasks build on** goes first, whatever
its own priority. Reordering costs you a little; redoing costs you the whole
task.

Hoist to the front anything that changes:

- a **data model or schema** other tasks read or write
- a **shared type, interface or helper** other tasks call
- an **auth or permission rule** other tasks must satisfy
- a **naming or structural convention** other tasks follow
- an **API contract** a caller elsewhere in the list depends on

This is the one rule that overrides the user's stated priority. Say so in
your reply when you invoke it — "doing the schema change first because tasks
3 and 5 query that table" — so the reordering is visible rather than silent.

### 2. Everything else batches by its expensive tail

Most remaining work shares a slow, repeatable step at the end. Do every
change in the family, **then run the step once**:

| Family | Batch together | Tail, run once after the batch |
|---|---|---|
| Schema / data model | models, fields, relations, enums, indexes | the project's schema sequence — validate, regenerate the client, typecheck, migrate, reseed. Where `.claude/WSS.WORKFLOW.json` names a `WSS.onSchemaChange` skill, that skill owns the exact order |
| API / endpoints | routes, handlers, services, request schemas | the full test suite (`WSS.commands.test`), then iterate on what fails |
| Architecture / infra | compose files, service boundaries, build config | rebuild the stack, then smoke-run it |
| Docs | every doc invalidated by the work above | a single documentation pass at the end |

### 3. Keep priority where the first two rules leave it free

After hoisting ramifications, order the **groups** by the highest-priority
task each one contains, and keep the user's stated order **within** a group.
Grouping is meant to change how work is bundled, not to quietly demote
something the user said was urgent.

### Expressing it in the list

- One task per change, as usual.
- One **explicit task for the tail** — "Run migrate + reseed and typecheck".
  Never leave it implicit: an unlisted step is a step that gets skipped, and
  it is usually the step that catches the mistake.
- Give the tail task `addBlockedBy` for every member of its batch, so the
  list shows *why* it cannot run yet.
- Tag members with `metadata: {"group": "schema"}` so the batches stay
  legible when the list is long.

### A failed tail creates tasks, it does not reopen them

When the batch's verification step fails — tests red, migration rejected,
build broken — leave the tail task `in_progress`, create a task per distinct
failure, fix those, then re-run the tail.

### Do not over-batch

Batching trades **feedback granularity** for fewer expensive runs.

Keep a batch small enough that a failed tail is still diagnosable. When
changes are independent and the tail is cheap, prefer the earlier signal
over the saved run — batching is an optimization, not a virtue.

## Keep exactly one task in progress

Mark a task `in_progress` **before** starting it, not after. One at a time —
if two are genuinely in flight, the list is modelling the work wrong and
should be re-cut.

Mark it `completed` the **moment** it is done. Never batch completions at
the end of a turn: a list that flips from all-pending to all-complete in one
go tracked nothing, it just described the past.

## Only complete what is actually done

A task is `completed` when the thing works and you have checked. Not when
you have written the code and it looks right.

Leave it `in_progress` and create a **new task naming the blocker** when:

- tests fail, or you have not run them yet
- the implementation is partial
- you hit an error you have not resolved
- a file or dependency you needed was not there

## When the plan changes, change the list

Plans move. Reflect it immediately rather than silently working off-list:

- Work turned out bigger → split the task into real sub-tasks.
- Work turned out unnecessary → set it `deleted` and say why in your reply.
- Something new surfaced → `TaskCreate` for it, don't just do it silently.
- Order matters → `addBlockedBy` / `addBlocks`, so the dependency is visible
  rather than living only in your head.

## Report progress in the reply, not only in the list

The list shows *state*; your prose should carry the *meaning*. When you
finish a meaningful chunk, say what changed and what it means — especially
anything that alters the plan the user agreed to. "Done: 3/7" tells them
nothing they cannot already see.

At the end, state plainly what was completed, what was not, and why. If any
task is still open, say so rather than letting the list quietly carry it.

## Do not confuse this with the project's backlog

Two different artifacts, and mixing them loses work:

- **The task list here** — this session's working plan. Ephemeral. Gone when
  the session ends.
- **The project's backlog** — durable pending work for the repo, `WSS.record.todo`
  in the project's manifest. `--wss-todo` owns it, alongside the reasoning in
  `WSS.record.decisions`.

If something surfaces that should outlive the session it belongs there, not
just here. And when the whole unit of work is approved and done, `--wss-wrap` closes
the list out.

Who may write which record file is
[`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md); what each one
holds is [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md).
