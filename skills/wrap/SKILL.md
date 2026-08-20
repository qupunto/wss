---
name: wrap
description: "Close out a unit of work or a session — task-list cleanup, handoff refresh, tight summary, committing and pushing what is outstanding, then /clear. SHORTHAND: `--wss-wrap`. Also on an explicit close-out: \"wrap this up\", \"close this out\", \"before I clear\". COMMITS AND PUSHES — never infer it from \"done\", praise, or approval, which report a state rather than ask for one."
---

# Wrapping up an approved task

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.branch.integration`
is what this skill pushes — and, from a lane worktree, what it fast-forwards
that lane onto — `WSS.record.roadmap` and `WSS.record.releases` are what step
6 reads, and `WSS.commitTrailer` names the session trailer. Without a
manifest, fall back to the current branch and say in one line that you did.
Where `.claude/WSS.LANE` names a lane, `WSS.lanes.named.<lane>.records.X`
overrides `WSS.record.X` for the splittable keys
— [`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md)'s resolution
rule. `WSS.record.releases` is never among them, which is why step 6 asks the
milestone question only from the main checkout.

**This skill writes no record file.** The handoff — the part that makes this the
handoff — belongs to `handoff-writer`, which step 3 invokes. Who owns what is
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md).

## The `--wss-wrap` shorthand

`--wss-wrap` invokes this immediately, with no confirmation and regardless of
whether the work looks finished. It overrides every judgment call below: don't
ask "is this really done?", don't wait for approval of the last deliverable,
just run the closing ritual.

Where a flag counts is [`README.md`](../../README.md); what it authorizes is
the block `wss-shorthand-flags.sh` injects and
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md)'s matrix — the two
copies `wss-doctor.sh` compares, never restated per skill.

## When it triggers

- The user gives clear, final approval of the last deliverable in a unit
  of work ("done", "approved", "wrap this up", "looks good, that's it")
  — not approval of one intermediate step with more steps still coming.
- Nothing in the same message pivots straight into related follow-up
  work — if it does, that follow-up is still the same unit of work, so
  don't wrap yet; let it finish first.
- **Or: the session is about to end regardless of approval state** — the user
  says they're going to `/clear`, commit and stop for the day, or asks what a
  fresh session would still know. Do steps 1-3 and 5 — the commit matters
  more when the work is unfinished, not less — and skip the "safe to
  `/clear`" framing, saying plainly what's half-done and where it's recorded.

## When another skill invokes this one

**Only where dispatched, not typed** — a user-typed `--wss-wrap` skips this
entirely. Where another skill's procedure reaches this one to close out its
own work, read
[`references/WSS.CALLER-CONTRACT.md`](references/WSS.CALLER-CONTRACT.md) now:
it holds the three ways a dispatched wrap differs from a typed one — whose
scope the commit/push grant is, whether `/clear` is safe to declare, and that
step 6 is skipped — each of which the caller states at the point it invokes.

**A caller that wants less than the ritual should not call this skill at all.**
One that needs only the handoff calls `handoff-writer`; one that needs only a
commit calls `git-writer`. Running the whole closing pass for either would end a
session that is not over.

## What to do, in order

**Step 0 — decide whether this is a lane worktree, before anything is read or
reported.** Lane mode is on where `.claude/WSS.LANE` is present or the manifest
declares `WSS.lanes.named`. Where it is, read
[`references/WSS.LANES.md`](references/WSS.LANES.md) now and follow it. Where
it is off, skip the file entirely and say nothing.

**Step 0.5 — consume the relay, where the pairing is on.** Check
`→WSS.script.wss-toggle.sh --on paired-sessions`; off or absent means skip
this step and say nothing. While it is on, the loop consumes
`.claude/WSS/RELAY/` at each boundary — this step, no ask, no hold, no
notifications; the protocol's one source is
[`skills/pair/SKILL.md`](../pair/SKILL.md). For each item file, in
filename order:

1. **Apply the body verbatim through the skill its `target:` names** —
   `--wss-log`, `--wss-todo`, `--wss-plan`. Placement, ordinals, format and
   the index stay theirs; the relay moves content, never authority over
   where content goes.
2. **Add a line naming the relay item and the authoring session** to every
   applied entry — mandatory, because an applied entry carries this
   session's trailer and nothing else distinguishes relayed content from
   authored content.
3. **Delete the item immediately after confirming its own apply succeeded**,
   in the same pass — deleting late is the double-apply window, deleting
   before confirming is the lost-apply one, and never both halves in one
   shell command, which is how an item was once deleted unapplied.
4. **Bounce a malformed item untouched** — report it to the designer, never
   repair it; repairing silently makes this session the author of content
   the header attributes to someone else.

Items are consumed as whole files from the one directory `WSS.pair.relay`
names, never read out of a shared live file and never from a second path —
filename identity is an accident, not a double-apply guard.

1. **Reconcile the task list.** Run `TaskList`. Mark anything genuinely
   finished as `completed` via `TaskUpdate`; delete anything stale,
   duplicated, or superseded during the work rather than leaving it
   dangling `pending`. If a real task remains open (something explicitly
   deferred, not this unit of work), leave it — wrapping doesn't mean
   force-closing unfinished items.
2. **Check whether anything from this task belongs in memory** per the
   normal memory rules (`user`/`feedback`/`project`/`reference` types
   only — never implementation details, file paths, or code patterns,
   which `git log`/the code itself already cover). This is a final
   check, not a bulk save — most of what qualifies should already have
   been captured live during the work, following its own triggers.
3. **Invoke `handoff-writer` for a full-section rewrite — never a
   read-then-edit.** `WSS.record.handoff` is what a fresh session inherits,
   and it is that skill's to write. **`--wss-wrap` does not read the handoff
   first** — the read existed only to avoid contradicting text that a
   wholesale write now replaces (the decision log carries the reasoning).
   Compose `## State` fresh from what this session knows and hand it to
   `handoff-writer`, which splices it in with `wss-handoff-state.sh state` —
   a mechanism that locates anchors, never one that reads the old prose to
   decide what the new text says. Do this *before* the summary, so what you
   tell the user matches what the next session will actually see.
4. **Give a tight closing summary** — a few sentences, not a report:
   what shipped, what (if anything) is still open or blocked on the
   user, and any follow-up already logged in `WSS.record.todo` and `WSS.record.decisions`
   so it's clear nothing was silently dropped.
5. **Commit and push what's outstanding**, through `git-writer`. `/clear` leaves
   the working tree alone but throws away the only cheap explanation of it, so
   this is the last moment a commit message can be written honestly. See the
   section below.
6. **Check whether any roadmap goal is fully closed, and whether that closes
   a milestone.** Run `bash skills/wrap/assets/wss-wrap-status.sh` (no
   args, from the project directory; always exits 0) and read its
   `goal-closed:` line — **every** roadmap goal whose blocks are all checked
   (`|`-separated), or `none`. It is the roadmap's structural state, not an
   event this session caused: a goal closed by an earlier session still
   appears here every wrap until an open milestone stops citing it. Which
   milestone in `WSS.record.releases` *cites* which of those goals is prose
   the script can't parse, so the correlation stays this step's: check each
   open milestone's "Comprises the roadmap goal" citation against the
   `goal-closed:` list.

   - In a lane worktree that is where it stops: **a lane session never asks
     the milestone question**, whatever the list says, because a mark is a
     checkpoint for the whole project and this session can see one lane of it.
   - In the main checkout, if an open milestone in `WSS.record.releases` cites
     one of the closed goals, **invoke `plan`** so the question is put to
     the user now, while the evidence is in front of them.

   Do **not** mark it completed yourself — `WSS.record.releases` is `--wss-plan`'s, and
   whether a milestone is done is the user's call, which `--wss-plan` asks and the
   disqualifier checks it runs are part of. If the user marks it, name
   `--wss-release` as the next step; if they don't, that is a complete outcome and
   the wrap continues.

   **A mark written here lands after step 5's commit**, so commit it too rather
   than leaving `WSS.record.releases` dirty for a `/clear` to strip the context from.
   It is `--wss-plan`'s write and this skill's commit, which is the normal division.
7. **Report where the project now stands.** Run
   `bash skills/wrap/assets/wss-wrap-status.sh` again — after step 5's
   commit and step 6's mark, so it describes the tree the user is about to
   walk away from. Relay its `== counts ==`, `== open-decision titles ==`,
   `== roadmap ==` and `== sweep ==` blocks in the reply, and never into a
   file: a count is a mutable claim and
   [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)
   forbids writing one into a record, but the reply is read once, by someone
   about to decide whether to stop.

   Where a record reads `?(...)` — undeclared, missing, or unreachable — say
   that in place of a count. A provider-managed `WSS.record.todo` is not
   fetched here at all: report "TODO list is a github-issues provider
   (on-demand triage)" instead of a count, per
   [`providers/WSS.GITHUB-ISSUES.md`](../../wss/workflow/providers/WSS.GITHUB-ISSUES.md#what-the-sweeps-do-with-it).
   A bare `0` would claim a fact ("nothing left") the read never established.

   **Read `milestones=N`'s parenthetical, not the bare integer.**
   `milestones=0` alone means no milestones remain; `milestones=0
   (end-of-milestones declared)` means the project has declared it is done
   cutting releases — a different fact a bare `0` renders identically.

   The sweep line is `wss-sweep-distance.sh --compact`'s — the one
   implementation, shared with `--wss-overview`'s `--verbose` rendering, and
   [`tests/wss-hook-contract.sh`](../../wss/tests/wss-hook-contract.sh) covers it.
   Its failure states (no checkpoint, off this history, no such commit, no
   baseline) are documented in that script and not restated here. **It is a
   report and not a gate**: no figure blocks a wrap, fails one, asks the user
   anything, or turns into a recommendation to sweep.
8. **Tell the user plainly that it's safe to run `/clear`** — and that
   starting the next unrelated task fresh (either `/clear` or a new
   session) means Claude isn't re-reading/paying for this task's full
   history going forward. Don't just imply it — say it directly. No skill
   can run `/clear`; only the user can. **Where the work is unfinished —
   however this skill was reached — skip the framing and say plainly what is
   half-done and where it is recorded**, rather than declaring a half-done
   tree safe to clear.

## Committing and pushing

`--wss-wrap` is standing authorization to commit and push, without asking
again — this skill's own grant, and it does not carry over to ordinary turns.

**The commits go through [`git-writer`](../../wss/workflow/writers/WSS.GIT-WRITER.md)**,
the sole owner of commits, pushes and tags — coherent grouping, the session
trailer, the force-push refusal and the rejected-push handling are its rules,
not restated here. It inherits this skill's grant, so it may push; it never
decides to.

Two things stay this skill's judgement, because they need the session's own
knowledge, not `git-writer`'s:

- **How the work divides** — tell `git-writer` which files belong in which
  commit and why, rather than letting it infer groupings from a diff.
- **Interrupted work still gets committed.** When `--wss-wrap` fires mid-task,
  commit the half-done state and say so in both the commit message and the
  summary — never describe unverified work as done.

**A rejected push is `git-writer`'s to report and hand back, not to resolve
here** — including the lane's landing push in
[`references/WSS.LANES.md`](references/WSS.LANES.md), refused by design on the
same rule. **Where the pushed branch is now ahead of `WSS.branch.publish`,
name `--wss-pr` and stop** rather than opening one: a session ending and work
being ready to merge are different facts, and the second is the user's to
assert. If the tree is clean and nothing is unpushed, say so in one line.

## One worktree per session

**Applies whether or not the project uses lanes** — ordinary hygiene for a
shared checkout. Two sessions sharing one collide on the working tree, index
and `HEAD`, which per-session branches don't fix. Isolate at the worktree
level:

```bash
git worktree add ../<project>-<topic> -b <topic>   # from the main checkout
```

Check whether `.claude/settings.json` sets `worktree.symlinkDirectories` for
the project's dependency directories — where it does, a new worktree symlinks
them instead of duplicating hundreds of megabytes; where it does not, a
worktree is expensive and may arrive unable to run anything, so confirm
before treating one as cheap.

Worktree branches are short-lived; the integration branch stays the
integration branch. Landing a **declared lane** onto it is a different act
with its own refusal rules, in
[`references/WSS.LANES.md`](references/WSS.LANES.md).

## What this skill does not do

Beyond writing no record file (stated above): it does not commit, tag or push
by hand — step 5's grant flows through `git-writer` — and it does not decide
that a milestone finished. Step 6 puts that question to the user through
`WSS.record.releases`' owner, `plan`, and never answers it itself,
including declining to ask at all from a lane worktree.
