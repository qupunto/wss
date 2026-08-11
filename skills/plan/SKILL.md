---
name: plan
description: "Set the next goal, and keep the release list — `WSS.record.roadmap` holds the goals and splits by lane, `WSS.record.releases` holds the milestones, their versions and their marks. Marking one authorises `--wss-release` to tag. SHORTHAND: `--wss-plan`. Also on \"what should we build next\", \"what's next for the UI\", \"is this milestone done\", \"reorder the roadmap\"."
---

# Goals, and the release list

This skill is the sole writer of two records, and the split between them is the
thing to hold onto:

| Record | Holds | Splits by lane |
|---|---|---|
| `WSS.record.roadmap` | **Goals.** What an area of work is trying to achieve, the blocks that get it there, their order. In that area's own terms. | **yes** |
| `WSS.record.releases` | **The release list.** One entry per milestone: the version it intends to ship as, which goals it comprises, whether it is marked completed. | **never** |

**No roadmap carries a version number or a completion mark.** Not a lane's, not
an unsplit project's. That single prohibition is what lets a project hold any
number of lane roadmaps while still holding exactly one release checkpoint —
`--wss-release` reads `WSS.record.releases` and no other planning record.
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md) holds the rule and the
reasoning; `wss-doctor.sh` fails on a roadmap that breaks it.

A roadmap is **not** a task list and **not** a place for design arguments. The
checklist is `WSS.record.todo` and the reasoning is `WSS.record.decisions`, both
`--wss-todo`/`--wss-log`'s.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.roadmap`,
`WSS.record.releases`, `WSS.record.todo`, `WSS.record.openDecisions`,
`WSS.record.decisionsIndex`, `WSS.record.stocktake`, and `WSS.agents.roadmap`. Without a
manifest, fall back to `WSS.ROADMAP.md` and `WSS.RELEASES.md` and say so. Where a
`.claude/WSS.LANE` selector names a lane, `WSS.lanes.named.<lane>.records.X` overrides
`WSS.record.X` for `todo`, `openDecisions`, `handoff` and `roadmap` —
[`WSS.LANE-CONTRACT.md`](../../workflow/WSS.LANE-CONTRACT.md)'s resolution rule. `releases` is
never among them.

Who owns what is [`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md);
what each record holds is
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md).

## Which mode you are in — read the selector first

**`.claude/WSS.LANE` decides what this invocation is allowed to be about**, before
anything else. It is a file, gitignored, one per worktree, holding a lane name.

| Selector | Mode | This skill does |
|---|---|---|
| names a lane | **lane** | goal-setting on that lane's roadmap, and nothing else |
| absent | **project** | goal-setting on the unsplit roadmap, **plus** the release list |

**In lane mode the release machinery does not fire.** Do not ask whether a
milestone is done, do not name a version, do not write a mark, do not open
`WSS.record.releases`. A session in a lane worktree is planning that lane's work; the
shipping question belongs to a session that can see the whole project, and asking
it here produces a checkpoint nobody else agreed to.

Where a lane session genuinely needs a milestone decision, say which lane it is
in and that the question belongs to the main checkout. That is
[`WSS.LANE-CONTRACT.md`](../../workflow/WSS.LANE-CONTRACT.md)'s route-to-the-owning-lane rule
applied to a record rather than to a file.

## Why this is a skill and not only the agent

Same split as `--wss-release` and for the same reason. The agent named in
`WSS.agents.roadmap` does the reading — the roadmaps, the release list, the backlog,
the decision index, the audit log, the git history — and returns a proposal.

But **completing a milestone requires asking the user, in conversation, and
waiting for the answer.** A subagent has no channel for that; it can only return
a report. So the reading is delegated and the asking stays here.

Where a project declares no roadmap agent, do the reading yourself and say that
you did, since it costs context the user should know about.

## Before proposing anything, check the real state

- **The roadmap this mode resolves** — what is in progress and what is next.
- `WSS.record.todo` — so you don't propose as a "next block" something already
  deliberately deferred.
- `WSS.record.decisionsIndex` — one line per settled decision. Go through the index,
  never the decision log itself, which can run to tens of thousands of tokens;
  open an entry only when you need its reasoning.
- `WSS.record.openDecisions` — **a block whose blocking decision is still open is
  not ready to start.** Say so rather than scheduling it anyway.
- `WSS.record.stocktake` — in project mode, a milestone carrying unremediated
  high-severity findings is not a candidate for completion.

## Setting the next goal

**This is the job with the most value in it, and the one most often skipped**
because the release questions below are louder. A goal is not the next unchecked
box: it is what the area is trying to become, stated so that finishing it is
recognisable.

A goal proposal names four things:

- **What changes for someone using this area** when the goal is met. A goal
  phrased as work rather than as an outcome cannot be judged complete.
- **The blocks that get there**, in order, each a paragraph.
- **What it depends on** — another lane's goal, an open decision, an audit
  finding. A dependency on another lane is named, not resolved here.
- **What it explicitly is not**, where the goal has a tempting adjacent scope.

**Propose in the area's own vocabulary.** An interface lane thinks in flows,
states and surfaces; a service lane thinks in endpoints, schemas and jobs.
Translating both into one house style is how a roadmap stops being read by the
people whose work it describes.

**A goal is not sized by a version.** Do not ask what release it lands in while
proposing it — in lane mode you cannot answer that, and in project mode the
answer belongs to the release list, later, deliberately.

## Deciding a milestone is done — project mode only

Checking a block off as it lands is bookkeeping. **A milestone completing is the
decision**, and it is the one this skill exists to get right.

The user decides — but **you ask at the moment the last goal a milestone cites
is met.** Do not wait to be told; nobody volunteers the word, and a milestone
nobody asks about is a release that never happens.

So, when the last cited goal is met:

1. Say what the milestone claimed to cover, what actually landed, and what is
   still open against it. **Where the project runs lanes, name which lanes
   contributed** — a milestone cites goals across roadmaps, and a reader of
   `WSS.record.releases` alone cannot see them.
2. Name either disqualifier if it applies — **an open blocking decision**, or
   **unremediated high-severity audit findings**. Both are worth catching here,
   because the alternative is a release discovering them.
3. Ask, once, in conversation.
4. On yes, **mark it completed in `WSS.record.releases` with its version**, then name
   `--wss-release` as the next step and stop.

**The mark is the durable form of the answer** — a spoken "yes" does not survive
a `/clear`. It goes in `WSS.record.releases` and nowhere else: a mark written into a
roadmap is invisible to `--wss-release`, and a mark written into a *lane's*
roadmap is a checkpoint one worktree cut for the whole project.

Versions, the changelog and tags themselves are not yours.

## A milestone cites goals; it does not restate them

An entry in `WSS.record.releases` names the goals it comprises — by name, by roadmap,
one direction. It does not copy their prose, and nothing derives it: **you write
which goals a milestone covers, and that authorship is the point.** It is the
only place a lane's work and the shipping plan are reconciled.

The cost this accepts, and it is worth stating to the user when it bites:
**nothing aggregates lane roadmaps.** A lane can meet every goal it holds while
the milestone citing them still reads open, and no check finds that. The
alternative — deriving milestone completion from N roadmaps — is a release gate
that waits on the slowest lane, which is the failure that put goals and the
release list in different files.

## Declaring an end to milestones — project mode only

A project can finish its planned work. When the release list has no next
milestone and the user says the remaining work is maintenance rather than a next
version, **write that into `WSS.record.releases` as a section saying so.** It is this
skill's write and nobody else's.

It matters beyond tidiness: `--wss-release` reads that section as one of the
cases that authorize a tag. Without it, every milestone is completed and tagged,
"marked completed with no tag for it" is permanently false, and **no further
release can be cut** — the project ships its last version and then silently
cannot ship again.

Three rules, and the first is the one that gets skipped:

- **Ask before writing it, the same as completing a milestone.** This is a larger
  statement than any single mark: it says the plan is done. Never infer it from an
  empty next-up list or from the last milestone being tagged — those are the
  ordinary state of a project between blocks.
- **Say what replaces the plan.** What now triggers work, in terms a reader of
  *this* tree can evaluate — a defect, an inbox entry, an owed publish. A trigger
  nobody can check is not a trigger.
- **It is reversible.** New planned work means a new milestone and the section
  goes; say so when writing it, so it does not read as a project's obituary.

**Ending milestones does not end the roadmaps.** Goals keep being set after the
last version is planned — that is what a maintenance project does. A roadmap left
to rot because the release list closed is the predictable misreading of this
section.

## Keeping the files honest

- Blocks move between in-progress, next-up and completed. A block that has
  quietly stopped being worked on belongs in neither of the first two without a
  note saying why.
- **Every block belongs to a goal, and every goal is cited by a milestone or is
  explicitly out of scope for the current plan.** A goal no milestone cites can
  never ship, because nothing will ever mark it complete — the same failure the
  orphaned-block rule prevents one level down.
- **A milestone is a version's worth of work**, not a release-day checklist. If
  it has grown to where completing it is implausible, split it — two shipped
  minors beat one milestone that stays open for months.
- When an audit reorders priorities, a finding severe enough to jump the queue
  gets its own block on the roadmap it belongs to.
- **A roadmap block is a paragraph; a lane needs a file list.** When a block is
  ready to start, do not improvise its task breakdown here — that is
  `--wss-todo`'s, which owns `WSS.record.todo` and the format it needs.

## State claims rot, and these files are read to set priorities

Both records are read to set priorities, which makes a false claim in either
unusually expensive: it does not just misinform, it redirects work. So "nothing
does X" and any count go through
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#negative-claims) before
they are written here, and a finding dispatched about either file gets the
re-verification in
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing) before
it is acted on.

**Watch for state claims this write falsifies.** Before writing, grep the
resolved roadmap and the release list for the claims the new goal, reordering or
mark makes false — a block still sitting in next-up that this goal completes, a
stated dependency this order reverses, a milestone reading open that the mark
closes, an end-of-milestones section a new milestone contradicts — and fix them
in the same edit
([`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)).
Same-file scope is the cheap case and the usual one; the cross-record form is a
mark or goal asserting X exists falsifying "no X exists" wherever that sentence
lives.
