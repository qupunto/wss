# The dispatch ladder — where a unit of work runs, at which tier, at what effort

**One table every fanning-out skill reads, so dispatch is a match rather than a
judgement.** A caller matches the task against the rungs and takes the first that
holds; it does not decide a tier. That is what makes an assignment defensible
instead of felt, uniform across callers, and auditable after the fact.

Who may write what is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md). This file settles
**how a unit of work is dispatched** and nothing else.

## The ladder

Read top to bottom; **the first row whose key matches is the rung**. Every key is
an observable property of the task — what it writes, who consumes its output,
whether the design is finished, whether the brief names the read set — never how
hard the work feels.

A rung sets **three** things and no fourth. It sets no task ordering:
`[critical → why]` is [`WSS.LANE-CONTRACT.md`](WSS.LANE-CONTRACT.md)'s and
ramification-first ordering is `skills/track/SKILL.md`'s.

| Rung | Matches when | Where | Tier | Effort |
|---|---|---|---|---|
| **Keep** | it needs what the session lived through — a handoff, a wrap, a decision being logged, a commit, the disposition of findings — **or** its whole read set is smaller than the spawn floor below | inline | the session's own | the session's own |
| **Survey** | it writes no files, the read set is named before dispatch — by the brief, or by a declared agent's own file — and the verdict format is pinned | agent | bottom | low |
| **Execute** | a finished design is handed over as an artifact the caller can point at, its exact anchors re-verified at dispatch, and the work applies it | agent | bottom | low |
| **Analyze** | its output is the authority another rung works from — a plan they execute, a finding they act on, an artifact they cite — **or** the agent must choose its own read set | agent | top | high |
| **Design** | everything else worth dispatching — the work still contains a decision, which is why no key above it holds | agent | standard | high |

## Why Design is last, and where the floor comes from

**The bottom tier is reachable only through a key that says the deciding is
already done** — Survey's pinned brief, Execute's handed-over design. Work that
writes files with neither matches nothing above Design, so the standard tier is
its floor. That is a consequence of the keys rather than a second rule: it lifts
by itself for a caller whose own phases produce the design, with no edit here.

**A vague brief is priced, not tolerated.** A read-only survey whose files the
caller did not name is not Survey — the agent is choosing its read set, which is
Analyze, at the top tier. Pinning the brief is what makes it cheap.

## The spawn floor, and why a ladder rather than an arbiter

**The floor is not one number — it is set by the tool grant the caller would
dispatch, not by the rung or the tier.** The per-grant table, the probe that
recomputes each row, and which rows are still unmeasured (and why) are in
[`WSS.TOKEN-ECONOMY.md`'s "Per-grant spawn
floor"](../tests/WSS.TOKEN-ECONOMY.md#per-grant-spawn-floor) — cite that table or
run its command; nothing here restates a figure. Work whose entire job reads
less than the floor for the grant it would spawn is cheaper inline whatever
else it looks like, which is Keep's second half. The first half is
[`CLAUDE.md`](../../CLAUDE.md)'s: delegate what comes back as a verdict, keep what
needs what the session lived through.

**The `19,095–26,170` range once stated here described only the
`general-purpose` (`Tools: *`) case** — three model overrides measured against
one grant, not three grants. The figure, and the probe that produced it, are in
[`wss/logs/WSS.DECISIONS.md`](../logs/WSS.DECISIONS.md) at the `2026-08-12 (seventh)`
entry; it stands as the record of that measurement and is not deleted, only
scoped. Every other grant, and a same-day recompute of this one, is in the
per-grant table linked in the paragraph above — which is in
[`WSS.TOKEN-ECONOMY.md`](../tests/WSS.TOKEN-ECONOMY.md), not in this file.

**Keep's comparison prices a subagent's one-time spawn cost against a read's
one-time cost, and the second half of that is not accurate** — a read kept
inline is re-billed on every later turn of the session that holds it. By how
much is unmeasured, and the table linked above carries that correction along
with why no figure for it is stated. It is not repeated here.

**A dispatcher whose output is the tier that felt right drifts upward under
uncertainty.** Same log, the `2026-08-12 (sixth)` entry, carries the batch that
established it.

## Which model runs a task, and what to do when no agent covers it

**This ladder decides the model. An agent never chooses its own.** The chain is
fixed at every link: a task's type picks the agent, the agent's rung is what the
agent *is*, the rung's tier is the table above, and the tier's spelling is the
mapping below. The `model:` key in an agent definition is the **resolved end of
that chain**, written into the file only so the harness can honour it — never an
independent decision the agent gets to make. A caller matches the task to an
agent and passes no model override, because the resolution already happened
here.

**Where no agent covers the task type, that is a GAP IN THIS LADDER — not a case
the caller settles quietly.** Use the tier mapping below so the work can proceed,
and tell the owner in the same breath that no agent covers this task type. The
remedy is to **expand the ladder**: a new row in the assignment table, and
usually a new agent to go with it. Falling back is what keeps a batch moving; it
is not the resolution, and a fallback taken silently is how a task type stays
permanently uncovered.

The spelling, once, for the launch itself: omitting `model:` inherits the
session's own model and is the top tier; `model: 'sonnet'` is the standard tier;
`model: 'haiku'` is the bottom tier.

### The assignment table

**This table is the canon, and every agent file's `model:` is a derived copy of
its row.** `wss-doctor.sh` fails on an agent whose frontmatter disagrees with its
row, and on an `agents/*.md` that has no row at all. Change an assignment *here*
first; the agent file follows.

| Agent | Rung | Tier | `model:` |
|---|---|---|---|
| `wss-survey` | Survey | bottom | `haiku` |
| `wss-execute` | Execute | bottom | `haiku` |
| `wss-design` | Design | standard | `sonnet` |
| `wss-analyze` | Analyze | top | *(none)* |
| `wss-release-prep` | Analyze | top | *(none)* |

**At the top tier the key is absent, and the absence IS the assignment** —
omitting `model:` inherits the caller's own model, which is what the top tier
means. Each such agent says so in its own body, so the gap cannot read as an
oversight to be helpfully filled in.

**That mapping is the rot-prone line in this file.** Recompute it rather than
trust it: dispatch a throwaway subagent that reads nothing, runs nothing, and is
asked only to report its own model back.

## Citing a rung

**A caller names the rung it took and the key that matched**, in the same breath
as the launch. The top tier is the expense, so an Analyze launch stays a visible
decision rather than a silent one — but every rung is named, because a rung
nobody wrote down is a rung nobody can check.
**Never assume something reads those citations back.** The obvious home is
[`tests/WSS.ROUTING-HEALTH.md`](../tests/WSS.ROUTING-HEALTH.md) — establish
whether it carries a lens for rungs, tiers or this table with
`grep -in 'rung\|ladder\|Survey\|Analyze' wss/tests/WSS.ROUTING-HEALTH.md`
rather than trusting a line here. Where nothing does, a rung cited wrongly is
caught by a reader or not at all, which is why the citation is mandatory rather
than advisory: the convention has to survive on its own until a check exists.
