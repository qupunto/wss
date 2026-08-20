# Writing the handoff

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md), whose [read-inheritance rule](WSS.WRITERS.md#read-inheritance) this follows. Sole writer of `WSS.record.handoff` and its overflow document, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

**How supervised this write is: [`WSS.SUPERVISION-LADDER.md`](../WSS.SUPERVISION-LADDER.md)'s row for the surface — read it before any modify or delete; never restated here.**

What this file may and may not hold is
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md), the authority where the
two disagree.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.handoff` is the
file, and the other `WSS.record.*` keys are what it points *at*. Without a manifest
the fallback is `WSS.HANDOFF.md` — say in one line that you used it, because a silent
fallback is how a project ends up with two handoff files. Where a `.claude/WSS.LANE`
selector names a lane, `WSS.lanes.named.<lane>.records.handoff` overrides
`WSS.record.handoff` — [`WSS.LANE-CONTRACT.md`](../WSS.LANE-CONTRACT.md)'s resolution rule — and the
lane's handoff is the one this procedure writes from that worktree; the
session hook injects the same file.

**No flag of its own**, on the same reasoning as `sweep-tracker`: nobody wants
"write the handoff", they want a wrap, a landed batch, or an audit. This is the
step inside those, not a thing to ask for. **The grant is always the caller's**,
per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md). It has no flag, so it confers
nothing on its own. **It never pushes and never decides to.**

**Why a primitive, not part of `--wss-wrap`**: `WSS.record.handoff` has several
callers wanting different amounts of work; a single owner lets the caller pick
the scope by picking the callee. **Why not a subagent**: a subagent starts with
a fresh context and would have to reconstruct what changed by reading diffs —
exactly the knowledge the session that did the work already has. **Never
delegate this.**

## `--wss-wrap` does not read this file

`## State` is a log-of-one: wiped and rewritten wholesale every wrap, never
read first. A conditional read still has to open
the file to evaluate its own condition, which only drops the cost to
*sometimes zero*; a wipe-and-rewrite drops it to zero.

`skills/wrap/assets/wss-handoff-state.sh` performs the splice:
`state` replaces the content of `## State` — everything between the card
marker and `## Where everything else is` — wholesale; `hazard-append`/
`hazard-delete` add or remove one hazard paragraph by locating its heading.
All three locate an anchor mechanically; **none of them read the file's
prose to decide what the new text should say** — that judgment is the
caller's, made from what the session lived through, not from what is
already written here.

**The `state` content file is body only — no `## State` heading.** The
script emits that heading itself as part of the splice; a content file that
also opens with `## State` produces two consecutive `## State` headings in
the handoff. The script refuses a content file whose first non-blank line
is `## State`, but write it as body from the start rather than relying on
the refusal.

## What goes in, and what doesn't

The test is not importance, it is **recoverability**: the question this file
answers is what a session must know *before it can look anything up*.

| Must be in | Must not be in — already has a home |
|---|---|
| What the project is, in a paragraph — the one thing no log carries | Commit SHAs, batch narrative, "what this session did" → `git log`, `WSS.record.changelog` |
| Every unfixed hazard whose natural assumption is wrong, marked `!important` | Why a decision was made, options weighed, a reversal → `WSS.record.decisions` |
| The current state of anything half-built, as the claim, not the history | What an audit found, and how well it found it → `WSS.record.stocktake`, `wss/logs/audits/` |
| Where each other record lives | The task list, per-item detail, what is deferred → `WSS.record.todo` |
| | Goals, blocks, milestone marks → `WSS.record.roadmap`, `WSS.record.releases` |
| | A hazard answerable by "am I about to touch that file?" → the overflow document |
| | A resolved warning, kept for the record → nowhere, delete it |

**Delete resolved warnings the moment they are fixed.** A stale `!important`
teaches the reader to distrust the real ones, which costs the real ones their
credibility. **Prefer a one-line warning plus a pointer** over a paragraph;
link, do not inline.

**Watch for state claims going stale**: counts, "not yet built", "nothing does
X" — [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#the-mutable-claim-rule).
If the work just done changed one, fix it now.

## Retention, per section

| Section | Retention | Failure it prevents |
|---|---|---|
| The card, and `!important` | Rewritten in place. A warning survives until it is **fixed**, then deleted the same session. | Both directions: a stale warning teaches distrust of the real ones; a deleted live one is the same defect with no symptom. |
| `## State` | **Superseded.** The current entry replaces the previous one. | A journal that grows without bound while claiming to be state. |
| `## Where everything else is` | Rewritten in place. Change a pointer when its target moves. | A pointer that no longer resolves. |

**Before superseding `## State`, route what has no other home** — one
question per paragraph: *if this entry vanished, would the fact vanish with
it?*

- **A standing hazard**, still true and unfixed → the card, or the overflow
  document, under the group naming when it applies.
- **A current-state fact** — a surface that ships unexercised, a count, a
  half-built thing → rewrite it into the new `## State`, as the claim alone.
- **Anything else** → delete it. `git log` and the decision log already hold
  it.

## Card and overflow: unconditional, not important

**Only the card — everything up to `<!-- handoff:card-ends -->` — is injected
into a session**; `wss-session-check.sh` stops there. Order sections so the
marker can land in one place: what the project is, and what will bite
someone, go above it; the current state and the record index go below.

**What stays in the card is decided by unconditionality, not by importance.**
A hazard that must be known *before touching anything* stays inline; one
answerable by "am I about to touch that file?" moves to the overflow
document — in this configuration, `wss/records/WSS.HAZARDS.md` beside
`wss/records/WSS.HANDOFF.md`, one writer for both because they are one record
split by cost rather than by subject. An importance test alone produces a
handoff that keeps everything, because every standing hazard is important.

Two failure modes: a pointer nobody follows is worse than a long file — group
the overflow by *when it applies*, never alphabetically or by severity; and
splitting past a handful of inline hazards inverts the cost, since the reader
then opens both files every time.

**A new overflow file is usually gitignored and will not ship** — check both a
`*`-then-reinclude ignore pattern and a publication whitelist when creating
one.

`wss-doctor.sh`'s "Handoff budget" section measures the card, the whole file
and the dated-entry count mechanically; it cannot judge content, which is what
this section stands in for.

## Scope: do what the caller asked for and stop

| Called by | Write |
|---|---|
| `--wss-wrap` | Every section, composed fresh from what the session knows and spliced in with `wss-handoff-state.sh` — never by reading the existing file first |
| `--wss-start` | What the batch changed, plus any `!important` it created or resolved |
| `--wss-health-check --deep`'s TODO resort | Only the `!important` warnings that audit created or resolved: one line each plus a pointer, resolved ones deleted |
| `--wss-health-check` | Every finding it dispatched here, each re-verified first: resolved warnings still present, and pointers that no longer resolve |

**A caller with no row gets the `--wss-health-check` row**, not `--wss-wrap`'s: write
the findings you were handed and stop, and say in one line that the caller
was not listed, so the row can be added rather than guessed at again.

A dispatched finding is a hypothesis, not an instruction:
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md#the-inspector-writes-nothing).
Re-verify first, and **hand the disagreement back** rather than writing a
correction that is itself wrong — every session reads what you write here.

**If nothing changed, say so and move on.** A no-op pass is a fine outcome;
editing the file to show effort is not.

## What this procedure does not do

- **It does not commit or push.** The caller does, under the caller's grant.
- **It does not write any other record.** Not `WSS.record.todo`, not
  `WSS.record.decisions` — those are `--wss-todo`/`--wss-log`'s, and a handoff
  that starts carrying reasoning is how the split collapses.
- **It does not decide whether a milestone finished.** `--wss-wrap` reads
  `WSS.record.releases` for that, and `--wss-plan` is what marks it.
