---
name: wrap
description: "Close out a unit of work or a session — task-list cleanup, handoff refresh, tight summary, committing and pushing what is outstanding, then /clear. SHORTHAND: `--wss-wrap`. Also on an explicit close-out: \"wrap this up\", \"close this out\", \"before I clear\". COMMITS AND PUSHES — never infer it from \"done\", praise, or approval, which report a state rather than ask for one."
---

# Wrapping up an approved task

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.branch.integration` is what
this skill pushes — and, from a lane worktree, what it fast-forwards that lane
onto — `WSS.record.roadmap` and `WSS.record.releases` are what step 6 reads,
and `WSS.commitTrailer`
names the session trailer. Without a manifest, fall back to the current branch
and say in one line that you did. Where a `.claude/WSS.LANE` selector names a lane,
`WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for `todo`, `openDecisions`,
`handoff` and `roadmap` — [`WSS.LANE-CONTRACT.md`](../../workflow/WSS.LANE-CONTRACT.md)'s
resolution rule — so a lane worktree wraps into its own four files.
`WSS.record.releases` is never among them, which is why step 6 below asks the
milestone question only from the main checkout.

**This skill writes no record file.** The handoff — the part that makes this the
handoff — belongs to `handoff-writer`, which step 3 invokes. Who owns what is
[`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md).

## The `--wss-wrap` shorthand

`--wss-wrap` invokes this immediately, with no confirmation and regardless of
whether the work looks finished. It overrides every judgment call below: don't
ask "is this really done?", don't wait for approval of the last deliverable,
just run the closing ritual.

Where a flag counts is [`README.md`](../../README.md); what it authorizes is
the block `wss-shorthand-flags.sh` injects and
[`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md)'s matrix — the two
copies `wss-doctor.sh` compares, never restated per skill.

## When it triggers

- The user gives clear, final approval of the last deliverable in a unit
  of work ("done", "approved", "wrap this up", "looks good, that's it")
  — not approval of one intermediate step with more steps still coming.
- Nothing in the same message pivots straight into related follow-up
  work — if it does, that follow-up is still the same unit of work, so
  don't wrap yet; let it finish first.
- **Or: the session is about to end regardless of approval state** — the
  user says they're going to `/clear`, commit and stop for the day, or
  asks what a fresh session would still know. Work doesn't have to be
  finished for the handoff to matter. In that case
  do steps 1-3 and 5 — the commit matters more when the work is
  unfinished, not less — and skip the "safe to `/clear`" framing, saying plainly
  what's half-done and where it's recorded.

## When another skill invokes this one

**A caller reaches this skill to close out its own procedure, and the catalog's
who-invokes-whom table is where the current set of them is recorded** — not a
list here, which would be a second copy going stale against the first. What is
*this* file's is the rule: a dispatched wrap differs from a typed one in three
ways, and **the caller states each of them when it invokes.**

- **The grant is the caller's, at the caller's scope, and never wider than the
  tree happens to contain.** `--wss-stocktake` grants commit and push **for the
  audit's own record only** — the audits entry, the rebuilt backlog and the
  records the review touched, never remediation code written in the same
  session. **A flagless caller has no grant to pass on at all**
  ([`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md)'s *authorization comes
  from the flag*), so a wrap dispatched from one asks the user for the commit in
  that turn, at the scope the caller names, and treats a refusal as an ordinary
  outcome rather than a failure.
- **Declare the session safe to `/clear` only where the caller says it is
  finished.** Step 8 is written for a user who typed the flag and has nothing
  left. A caller that routes more work *after* this — `--wss-stocktake` places
  its Fix-now dispositions there — is mid-procedure, and telling the user to
  clear throws away the context the rest of it needs. A caller whose close-out
  is genuinely its last step is not, and the framing is honest. **The caller
  says which; do not infer it from how finished the tree looks.**
- **Skip step 6.** Whether the caller's work closed a milestone is the caller's
  question to raise, not a second opinion offered from inside its close-out.

**A caller that wants less than the ritual should not call this skill at all.**
One that needs only the handoff calls `handoff-writer`; one that needs only a
commit calls `git-writer`. Running the whole closing pass for either would end a
session that is not over.

## What to do, in order

**Step 0 — decide whether this is a lane worktree, before anything is read or
reported.** Lane mode is on where a `.claude/WSS.LANE` selector is present in
this checkout, or the manifest declares `WSS.lanes.named`. Where it is,
**read [`references/WSS.LANES.md`](references/WSS.LANES.md) now and follow it** —
it holds the sync-forward this step performs, the landing procedure step 5 ends
in, and why the milestone question in step 6 is never asked from a lane. Where
it is off there is no lane branch, no sibling to sync from and nothing to land,
so skip the file entirely and say nothing about it.

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
3. **Invoke `handoff-writer` for the full currency pass — this is the important
   one.** `WSS.record.handoff` is what a fresh session inherits, and it is that
   skill's to write. Ask it for the
   full pass rather than a single correction, and do it *before* the summary, so
   what you tell the user matches what the next session will actually see.
4. **Give a tight closing summary** — a few sentences, not a report:
   what shipped, what (if anything) is still open or blocked on the
   user, and any follow-up already logged in `WSS.record.todo` and `WSS.record.decisions`
   so it's clear nothing was silently dropped.
5. **Commit and push what's outstanding**, through `git-writer`. `/clear` leaves
   the working tree alone but throws away the only cheap explanation of it, so
   this is the last moment a commit message can be written honestly. See the
   section below.
6. **Check whether this session finished a goal, and whether that finished a
   milestone.** Two records and two questions — read the roadmap this checkout
   resolves, then `WSS.record.releases`:

   - If the work just committed checked off the last open block of a goal, say
     so. In a lane worktree that is where it stops: **a lane session never asks
     the milestone question**, because a mark is a checkpoint for the whole
     project and this session can see one lane of it.
   - In the main checkout, if that goal was the last one an open milestone in
     `WSS.record.releases` cites, **invoke `plan`** so the question is put to the
     user now, while the evidence is in front of them.

   Do **not** mark it completed yourself — `WSS.record.releases` is `--wss-plan`'s, and
   whether a milestone is done is the user's call, which `--wss-plan` asks and the
   two disqualifier checks it runs are part of. If the user marks it, name
   `--wss-release` as the next step; if they don't, that is a complete outcome and
   the wrap continues.

   **A mark written here lands after step 5's commit**, so commit it too rather
   than leaving `WSS.record.releases` dirty for a `/clear` to strip the context from.
   It is `--wss-plan`'s write and this skill's commit, which is the normal division.
7. **Report where the project now stands**, in four numbers and a sweep line,
   read from the
   records after step 5's commit and step 6's mark so they describe the tree the
   user is about to walk away from:

   | Read | From | Say |
   |---|---|---|
   | open backlog items | `WSS.record.todo` | how many remain |
   | decisions nobody has made | `WSS.record.openDecisions` | how many are pending, and **name them** — an unmade decision gets made by accident by whoever writes the first line of code that depends on it |
   | the next goal | `WSS.record.roadmap` — this checkout's, and **name the lane** where one is selected | which goal is current, and its next unchecked block |
   | milestones outstanding | `WSS.record.releases` | how many are not yet completed |

   **Count what the record actually contains — never carry a number forward from
   earlier in the session.** The batch just committed is exactly what moves these,
   so a figure quoted from before it is wrong in the one direction that matters.

   **This goes in the reply and never into a file.** A count is a mutable claim
   and [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)
   forbids writing one into a record — but the reply is not a record, it is read
   once, by someone who is about to decide whether to stop.

   Where a record is undeclared or absent, say so in its place rather than
   printing a zero. "No release list is declared" and "no milestones remain" are
   opposite facts and a bare `0` renders them identically.

   **`WSS.record.todo` may be a provider rather than a file.** Where the value
   carries a `provider` key, count there instead:

   ```bash
   gh issue list --repo "$REPO" --state open --limit 500 --json number,labels \
     | jq --arg L "$LABEL" '[.[] | select($L == "" or (.labels
         | any((.name | ascii_downcase) == ($L | ascii_downcase))))] | length'
   ```

   **Not the `--label` form**, and this step is the reason that rule exists.
   `--label` is served from a search index that lags writes, and this step runs
   *after* step 5's commit and whatever issues just closed with it — so it is
   the one read in the suite guaranteed to be a read-after-write. See
   [`providers/WSS.GITHUB-ISSUES.md`](../../workflow/providers/WSS.GITHUB-ISSUES.md#after-writing-in-the-same-session-do-not-read-with---label).

   Say the backlog is provider-managed and give the number. Where `gh` cannot
   reach it, say *that* — an unreachable backlog is a third fact again, and the
   same contract forbids reading a local file in its place.

   **Then one line: how far each sweep has fallen behind.** `WSS.sweeps` holds a
   baseline per sweep — the tree that sweep last covered
   ([`WSS.SWEEP-CHECKPOINT.md`](../../workflow/WSS.SWEEP-CHECKPOINT.md#reading-a-checkpoint))
   — and the distance from that baseline to `HEAD` is drift that is otherwise
   seen only where someone goes looking for it (`--wss-overview` prints it per
   entry) or once a hook threshold trips. A wrap runs every session, so it is the
   cheapest place to watch the number move:

   ```bash
   S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
   [ -x "$S/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
   bash "$S"/skills/overview/assets/wss-sweep-distance.sh --compact
   ```

   **That script is the only implementation of this measurement**, shared with
   `--wss-overview`, which runs it `--verbose` through `wss-probe.sh` for its
   per-entry block. The two renderings are formatting; the resolution of
   `WSS.sweeps`, the `+dirty` strip and the states below are computed once, in a
   file `tests/wss-hook-contract.sh` covers. Where the script cannot be
   reached, say the sweep line could not be read — do not re-derive it here, and
   do not let a missing report hold up the wrap.

   Print the line, name it as commits behind each baseline, and stop. **It is a
   report and not a gate**: no figure here blocks a wrap, fails one, asks the
   user anything, or turns into a recommendation to sweep. `wss-session-check.sh`
   already nudges past its own thresholds at the *start* of a session; this step
   exists so the distance is visible while it is still small, which is why the
   thresholds themselves were left alone.

   How it declines to be interesting:

   - **No checkpoint, or one whose `entries` is empty** — nothing prints and
     nothing is said. An undeclared `WSS.sweeps` is not itself the absent case:
     the read falls back to the default path exactly as `wss-session-check.sh`
     and `wss-doctor.sh` do, so a project that swept without declaring the key
     still gets its line, and only a path with no file behind it goes quiet. A
     project that has never swept has no distance, and inventing a zero for it
     would claim freshness it has not earned.
   - **A baseline `HEAD` does not descend from** — a force-push, a rebase, a sha
     stamped on another branch — prints `off this history` and no number.
     `rev-list` would happily count there, but what it counts is everything on
     `HEAD`'s side of the divergence, which reads as catastrophic drift when the
     only fact is that the sha no longer sits behind `HEAD`. A sha that resolves
     to nothing at all prints `no such commit`; an entry with no baseline field
     prints `no baseline`. None of the three is an error.
   - **Only `entries` is read**, matching what `sweep-tracker` resolves. A stamp
     landing at the root of the checkpoint file instead of under `entries` is
     invisible to the tracker; a reporter that saw further than the writer
     would report freshness the sweep machinery does not have.

   The checkpoint is `sweep-tracker`'s file
   ([`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md)) — this step reads it
   and never writes it. Measuring a baseline is not advancing one.

8. **Tell the user plainly that it's safe to run `/clear`** — and that
   starting the next unrelated task fresh (either `/clear` or a new
   session) means Claude isn't re-reading/paying for this task's full
   history going forward. Don't just imply it — say it directly. No skill
   can run `/clear`; only the user can. **Where the work is unfinished —
   however this skill was reached — skip the framing and say plainly what is
   half-done and where it is recorded**, rather than declaring a half-done
   tree safe to clear.

## Committing and pushing

`--wss-wrap` is standing authorization to commit and push — it does not need
asking again each time. That authorization is *this* skill's, not a general
one: it does not carry over to ordinary turns.

**The commits go through `git-writer`**, which owns the history and holds the
rules that make a commit safe — coherent grouping, staging by name, the session
trailer, the check on whose work a push would publish, and the refusal to force
anything. It inherits this skill's grant, so it may push here; it never decides
to.

Two things stay this skill's judgement rather than `git-writer`'s, because they
need the session's own knowledge:

- **How the work divides.** You lived through it; tell `git-writer` which files
  belong in which commit and why, rather than letting it infer groupings from a
  diff.
- **Interrupted work still gets committed.** When `--wss-wrap` fires mid-task,
  commit the half-done state rather than leaving it to die in the working tree —
  but say so in the commit message *and* in the summary. Never describe
  unverified work as done.

If a push is rejected, `git-writer` stops and hands back. Report it rather than
resolving it: a rejection usually means another session pushed first, and that
is a merge decision, not a wrap-up step. **This holds for the lane's landing
push in [`references/WSS.LANES.md`](references/WSS.LANES.md) too** — that one is
refused rather than forced by design, and a rejection there is the same fact
wearing a different shape.

**Where the pushed branch is now ahead of `WSS.branch.publish`, name `--wss-pr`
and stop.** Do not open one: a session ending and work being ready to merge are
two different facts, and the second is the user's to assert.

If the tree is clean and nothing is unpushed, say so in one line and move on.

## One worktree per session

**This applies whether or not the project uses lanes** — it is ordinary hygiene
for a shared checkout, and the case it addresses is a project with no lanes at
all. Every session wraps before it finishes, and a wrap pushes, so two sessions
sharing one checkout collide: they share a working tree, an index and a `HEAD`,
which per-session *branches* do not fix. Isolate at the worktree level:

```bash
git worktree add ../<project>-<topic> -b <topic>   # from the main checkout
```

Check whether `.claude/settings.json` sets `worktree.symlinkDirectories` for the
project's dependency directories. Where it does, a new worktree symlinks them
instead of duplicating hundreds of megabytes or needing a fresh install. Where
it does not, a worktree is expensive and may arrive unable to run anything —
confirm before treating one as cheap.

Worktree branches are short-lived; the integration branch stays the integration
branch. Landing a **declared lane** onto that branch is a different act with its
own refusal rules, and it lives in
[`references/WSS.LANES.md`](references/WSS.LANES.md).

## What this skill does not do

**It writes no record file.** It owns the session: the closing pass, the commits,
and the `/clear` nudge. Every record write above is a handoff to that file's
owner, and who owns what is [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md); what
each one holds is
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md).

- **It does not write the handoff, or edit that file directly** — step 3 hands
  the full currency pass over.
- **It does not commit, tag or push by hand**, and duplicates none of the rules
  that govern those. They go through the history's owner under this skill's grant.
- **It does not decide that a milestone finished.** Step 6 puts the question to
  the user through `WSS.record.releases`' owner and never answers it — and never
  puts it at all from a lane worktree. That dispatch is
  safe because an invoked skill inherits **this** skill's grant and never its own
  flag's.
