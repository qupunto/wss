# Writing the handoff

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md). Sole writer of `WSS.record.handoff` and its overflow document, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

**Sole writer of `WSS.record.handoff`.** Everything else in this workflow that
needs the handoff changed calls this procedure; who owns what is
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md), and what this
file may and may not hold is
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md), which is the
authority if the two ever disagree.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.handoff` is the
file, and the other `WSS.record.*` keys are what it points *at*. Without a manifest
the fallback is `CLAUDE.md` — say in one line that you used it, because a silent
fallback is how a project ends up with two handoff files. Where a `.claude/WSS.LANE`
selector names a lane, `WSS.lanes.named.<lane>.records.handoff` overrides
`WSS.record.handoff` — [`WSS.MANIFEST.md`](../WSS.MANIFEST.md)'s resolution rule — and the
lane's handoff is the one this procedure writes from that worktree; the
session hook injects the same file.

**Refuse that fallback when the working directory is `~/.claude`.** There
`CLAUDE.md` is not a project's handoff, it is the user's global instruction file
loaded into every session of every project, and a per-session handoff written
into it is both destructive and paid for everywhere forever. So when the cwd is
`~/.claude` and no manifest declares `WSS.record.handoff`: **write nothing**, and
hand back the two fixes — run `--wss-adopt`, or declare `WSS.record.handoff` in
`.claude/WSS.WORKFLOW.json` — for the caller to pick between.

**No flag of its own**, on the same reasoning as `sweep-tracker`: nobody wants
"write the handoff", they want a wrap, a landed batch, or an audit. This is the
step inside those, not a thing to ask for.

## Why a primitive and not part of `--wss-wrap`

`WSS.record.handoff` has several callers, and they want different amounts of work. A
single owner keeps that honest: the caller picks the scope by picking the
callee, rather than by a clause somewhere describing when a skill should do less
than its whole procedure.

**The grant is always the caller's**, per
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md). This skill has no flag, so it
confers nothing on its own: dispatched from `--wss-check`, which grants nothing, it
writes the file and does not commit; called from `--wss-start`, which grants commit
but not push, it writes the file and the caller commits. **It never pushes and
never decides to.**

## Why not a subagent

A subagent starts with a fresh context and would have to reconstruct what
changed by reading diffs — which is exactly the knowledge the session that did
the work already has. **Never delegate this.** The compression is only cheap for
whoever lived through it, which is also why this procedure loads into the calling
session rather than running as one.

## What the file must answer, in this order

1. **What is this project** — stable, rarely changes.
2. **What state is it actually in** — what exists, what is half-built.
3. **What would hurt someone who did not know it.** Unfixed defects, absent
   safety nets, environments out of sync, anything where the natural assumption
   is wrong. Mark these `!important`.
4. **Where to look for everything else** — the doc split, so a fresh session
   knows `WSS.record.todo` is the checklist and `WSS.record.decisions` holds the why.

## Rules for what goes in

- **In**: anything a fresh session needs *before it touches code*. A layer that
  silently skips a filter everything else applies belongs here, because someone
  will otherwise trust it. An absent CI test job belongs here, because someone
  will otherwise assume a green local run means something.
- **Out**: anything it can look up *when the topic comes up*. Reasoning,
  history, per-item detail, the full task list. Link, do not inline.
- **Prefer a one-line warning plus a pointer** over a paragraph. The goal is
  that the next session knows what it does not know.
- **Delete resolved warnings the moment they are fixed.** A stale `!important`
  is worse than none — it teaches whoever reads it that the warnings in this
  file are not reliable, which costs you the real ones.
- **Watch for state claims going stale**: counts (tests, migrations, endpoints),
  "not yet built", "nothing does X" —
  [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#the-mutable-claim-rule). These rot
  silently, and a stale one in the card is read every session. If the work just
  done changed one, fix it now.
- **Budget**: see the card below. A section growing past a screenful is the
  signal it belongs in a reference doc with a pointer left behind — not that
  `WSS.record.handoff` should get longer.

## The card, and the marker that ends it

**Only the top of this file is injected into a session.** `wss-session-check.sh`
stops at a line reading exactly:

```
<!-- handoff:card-ends -->
```

Everything above it lands in every session of every kind of work; everything
below it is read on demand, and the hook says so where it cuts. A file with no
marker is injected whole, so a project that has not split its handoff keeps
working — but the split is what makes the file affordable, and it stops being
optional the moment the file passes a few KB.

**Order the sections so the card can end in one place.** Sections 1 and 3 above
— what this project is, and what will bite someone who does not know it — go
above the marker. Sections 2 and 4 — the current state, and where everything
else lives — go below it. That is not their natural reading order, and it is
worth the awkwardness: the alternative is a marker that cannot be placed without
splitting a section.

**The test is unconditionality, not importance**, the same one the overflow
document below is chosen by. The state section is usually the largest thing in
the file and it still goes below the line, because it matters *once you are
already editing a record* — a session that is answering a question, running a
build or reading code never needed it and paid for it anyway.

**Budget the card, not the file.** Keep it under about 4 KB. When it overruns,
the answer is never a smaller font on the state section — it is a warning that
has been resolved, a paragraph of history that belongs in the decision log, or a
hazard that has become conditional and belongs in the overflow document.

## The overflow document

Where a project's hazards have outgrown the handoff, they live in a **sibling
reference document this procedure also owns** — in this configuration,
`.claude/WSS.HAZARDS.md` beside `.claude/WSS.HANDOFF.md`. One writer still, because the
two are one record split by cost rather than by subject.

**What stays in the handoff is decided by unconditionality, not by importance.**
A hazard that must be known *before touching anything* stays inline; one that is
answerable by "am I about to touch that file?" moves. Applying an importance
test instead produces a handoff that keeps everything, because every standing
hazard is important — that is why it is standing.

Two failure modes, and the second is the reason to keep the split shallow:

- **A pointer nobody follows is worse than a long file.** If the moved section
  cannot be found by asking what you are about to do, it has been lost rather
  than filed. Group the overflow by *when it applies*, never alphabetically or
  by severity.
- **Splitting past a handful of inline hazards inverts the cost.** The reader
  then has to open both files every time, which is what the budget rule was
  avoiding.

**A new overflow file is usually gitignored and will not ship.** Configurations
that ignore `*` and re-include by name silently exclude it, and a whitelist of
tracked paths in a publication check will fail on it or omit it. Check both when
creating one.

Negative claims are the ones this file gets punished for, because it is read
most often: [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#negative-claims).

## Scope: do what the caller asked for and stop

| Called by | Write |
|---|---|
| `--wss-wrap` | The full currency pass — every section re-checked against what the session did |
| `--wss-start` | What the batch changed, plus any `!important` it created or resolved |
| `--wss-stocktake` | Only the `!important` warnings that audit created or resolved: one line each plus a pointer, resolved ones deleted |
| `--wss-check` | The one stale claim it found, re-verified first |
| `--wss-full-check` | Every finding it dispatched here, each re-verified first: resolved warnings still present, and pointers that no longer resolve |

**A caller with no row gets the `--wss-check` row**, not the `--wss-wrap` one: write the
findings you were handed and stop. Say in one line that the caller was not
listed, so the row can be added rather than guessed at again.

A dispatched finding is a hypothesis, not an instruction:
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md#the-inspector-writes-nothing).
Re-verify first, and **hand the disagreement back** rather than writing a
correction that is itself wrong — every session reads what you write here.

**Fix what was asked and stop.** No task-list pass, no summary, no commit, no
`/clear` nudge — a caller that wanted a wrap would have called `--wss-wrap`.

## If nothing changed

Say so and move on. A no-op pass is a fine outcome; editing the file to show
effort is not.

## What this procedure does not do

- **It does not commit or push.** The caller does, under the caller's grant.
- **It does not write any other record.** Not `WSS.record.todo`, not
  `WSS.record.decisions` — those are `--wss-todo`/`--wss-log`'s, and a handoff that starts
  carrying reasoning is how the split collapses.
- **It does not decide whether a milestone finished.** `--wss-wrap` reads
  `WSS.record.releases` for that, and `--wss-plan` is what marks it.
