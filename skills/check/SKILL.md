---
name: check
description: "Health-check every record the project's manifest declares, for claims that no longer match reality and updates the code changes owe but never got. Catches release drift too: a document claiming a version no git tag resolves. SHORTHAND: `--wss-check`, which runs incrementally. Also trigger on \"is the documentation up to date\", \"is anything stale\"."
---

# The record inspector

## It writes nothing. It dispatches.

When it finds something, it invokes the skill that **owns** that file, and that
owner re-verifies and writes under its own rules, in its own commit.

Delegation is a lookup, not a judgement, and
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md) is the authority. The
rows below are this skill's dispatch view of it — a second copy, kept honest
rather than remembered: `wss-doctor.sh` compares the two on their
`WSS.record.*` keys in both directions and fails on any divergence, so a record
that gains an owner without gaining a row here is reported rather than
discovered. What is free to differ is the owner column, which names the flag or
writer to invoke where the matrix names the skill.

| Finding lives in | Dispatch to |
|---|---|
| `WSS.record.handoff` | `handoff-writer` |
| `WSS.record.behaviour` | `behaviour-writer` |
| `WSS.record.reference` | `reference-writer` |
| `WSS.record.todo` (a file, or a provider — see below), `WSS.record.openDecisions`, `WSS.record.decisions` | `--wss-todo` / `--wss-log` |
| `WSS.record.decisionsIndex` — a stale generated index, per check 4 | `--wss-todo` / `--wss-log`, which owns `WSS.commands.indexRegen` |
| `WSS.record.roadmap` — every lane's copy — and `WSS.record.releases` | `--wss-plan` |
| `WSS.record.toolbelt` | `--wss-scout` |
| `WSS.record.stocktake`, `WSS.record.audits` | `audit-writer` |
| `WSS.record.changelog` | `changelog-writer` |
| `WSS.record.tooling.catalog` | `--wss-catalog` |
| `WSS.record.tooling.sources` | `--wss-tidy` |
| the docs site's annex page derived from `WSS.record.tooling.catalog` | `docs-writer` |
| `.claude/WSS.WORKFLOW.json` — a key naming a file that moved, or one nothing reads | `manifest-writer` |

**Every row is a primitive or a record owner, and none is an orchestrator whose
whole procedure would have to run.**

Resolve the paths through the lane selector first: where `.claude/WSS.LANE` names a
lane, `WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for the
splittable keys — [`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md)'s
resolution rule. A finding in a lane file dispatches to the same owner the
unsplit record has; the lane changes the path, never the writer.

**One exception, and it is not a dispatch.** A finding about a file belonging to
**this suite** — including one this inspection is running — does not go to
`--wss-tidy`. File it and stop, per
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session),
which holds the destination and the reasoning. This never covers the project's
own skills: `WSS.record.tooling.sources` globs are relative, so `--wss-tidy` owns them
as usual.

**The owner's second look is the point, not overhead** — hand over the evidence,
not a verdict, and expect a share of your findings to come back not reproduced.
Why that is load-bearing:
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing).

## Scope comes from the manifest

`.claude/WSS.WORKFLOW.json`'s `WSS.record.*` **is** the worklist. Iterate it; do not
carry a list here.

Without a manifest, the worklist is every key's fallback in
[`WSS.MANIFEST.md`](../../wss/workflow/WSS.MANIFEST.md) — that table is the authority, and a
list repeated here would drift from it. Say which fallbacks you used, since they
cannot know what the project actually keeps.

## When `WSS.record.todo` is a provider

An object with a `provider` key means the TODO list is not a file —
[`providers/WSS.GITHUB-ISSUES.md`](../../wss/workflow/providers/WSS.GITHUB-ISSUES.md#what-the-sweeps-do-with-it) is the
contract. It is swept the same way and findings dispatch to `--wss-todo` as always.

**One thing the checkpoint cannot do for it.** Incremental narrowing works by
diffing a record against a baseline commit, and an issue TODO list has no presence
in this repository's history — so there is nothing to diff and it is always read
in full. Record it as `not-covered` for the record scope unless you actually
read it; claiming coverage you did not earn is inherited by every cheap sweep
after it, and here there is no file whose mtime would ever contradict you.

## Scope comes from the checkpoint

**A record file that has not changed, describing code that has not changed, was
already checked.**

Ask `sweep-tracker` to resolve the entry `record` before reading anything. One
scope per record key, named for it — `WSS.record.behaviour`, `WSS.record.reference`, and
so on. **That naming is the `record` entry's contract, and `--wss-full-check`
stamps to the same one**: the key is what a reader resolves against, so a scope
named for a dimension instead joins to nothing and the expensive run's stamp
buys the cheap run nothing.

A scope's `covered` is the record file **plus the code globs this run read to
verify it**; that pairing is what a later run diffs against. **With no code
globs to pair, the scope writes `covered: []`** — the record alone would be
diffed against itself, which is
[`WSS.SWEEP-CHECKPOINT.md`](../../wss/workflow/WSS.SWEEP-CHECKPOINT.md#four-rules-and-they-are-the-whole-value)'s
rule 4 rather than a rule of this skill's.

The mechanics are
[`WSS.SWEEP-CHECKPOINT.md`](../../wss/workflow/WSS.SWEEP-CHECKPOINT.md#reading-a-checkpoint);
what is specific here is what voids a narrowing:

| Changed since the baseline | Puts back in full scope |
|---|---|
| the record file itself | that record — a hand edit is exactly what nothing else verifies |
| `.claude/WSS.WORKFLOW.json` | **every** record; a remapped key means the previous run checked a different file |
| a schema, its migrations, or anything defining the shape of stored data | `WSS.record.reference`, and `WSS.record.behaviour` |
| routes, services, domain logic | `WSS.record.behaviour` |
| container, deployment or proxy config, operational scripts, a stated convention | `WSS.record.reference` |
| block scope, order or dependencies | `WSS.record.roadmap` |
| a milestone's scope, its intended version, or which goals it comprises | `WSS.record.releases` |

**Check 1 is never incremental.** A negative claim — "nothing does X" — is
falsified by a file *added anywhere*, including in a directory no previous run
had reason to read. Narrowing it to the diff is how a claim stays "verified"
years after it stopped being true. Run it in full every time, over every record
file, and write `covered: []` for that scope.

**Stamp at the end**, through `sweep-tracker` — the baseline, and per scope what
was covered and what was not. A run that reports findings without stamping leaves
the next run to redo all of it.

## What to look for

**The taxonomy is [`wss/tests/WSS.RECORD-DRIFT.md`](../../wss/tests/WSS.RECORD-DRIFT.md)**
— the classes of drift, and the things that look like findings and are not.
Read it and apply it over the scope resolved above.

## The boundary with `--wss-docs`

Both look at prose. They ask different questions and must not both run on one
request:

| | Asks | Owns |
|---|---|---|
| `--wss-docs` audit mode | Is this document **true and well-formed**? Do paths exist, do links and anchors resolve, do enumerations still match source? | Fixing what it finds |
| `--wss-check` (here) | Is this document **owed**? Does the record still match reality, and did a change that obliged an update get one? | Reporting, and dispatching |

If the ask is "verify the docs site", that is `--wss-docs`. If it is "is the record
still true", it is this. If the ask is "where is the project" — the record plus
its conventions, interface, safety nets and a TODO list rebuild — that is
`--wss-stocktake`, which already includes this as one dimension. Run one, not both.

## How to report

Group by owner, not by file, since the owner is who acts:

```
behaviour-writer   1 finding
  WSS.record.behaviour:23   claims no endpoint enforces email verification;
                        the enforcing middleware is at <path>:41

reference-writer   1 finding
  WSS.record.reference:88   lists N seeded locales; the seed script seeds 1

--wss-tidy      1 finding
  <agent file>:12       claims the app registers only a health route;
                        it registers several route modules
```

Every finding carries **file:line and the evidence that contradicts it** — the
grep, the path, the count. A finding without evidence is an opinion, and the
owner will have to re-derive it anyway.

Then dispatch. If a finding has no owner, say so plainly rather than fixing it
yourself: an unowned record file is a gap in the matrix and worth surfacing as
one.

**A silent inspection is as good as no inspection.** Say what you checked, what
you found, and what you dispatched — including "nothing" where that is the
answer. A clean pass is a real result.
