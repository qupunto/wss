# Phase 1 — Fan out

One `WSS.agents.audit` per dimension, **all in a single message so they run
concurrently**. Give each its slice as an explicit path list, its baseline
commit, its share of the carry-over list, and the brief below.

**Where no `WSS.agents.audit` role is declared** — the common case on a project that
has just adopted this — route each auditor to its rung's own agent,
[`wss-survey`](../../../agents/wss-survey.md), matching the Survey rung the router
already assigned it. **Never a general-purpose subagent, and never a different
role's declared agent.** The brief travels entirely in the prompt, so nothing is
lost except the role's own standing instructions. Name the rung agent used in
place of the undeclared role in the entry's `Method` field.

**Hand each auditor its decisions, and do the lookup once yourself.** Read
`WSS.record.decisionsIndex` — one line per entry — pick the entries bearing on each
dimension, and name them in that auditor's prompt. It reads `WSS.record.behaviour`
and `WSS.record.reference` for current state, the named entries for the *why*, and
opens the full log only if something contradicts what it is looking at. **Below
the spawn floor, read it here** — "once yourself" is what keeps every dimension's
auditor from repeating the read. **At or above it, delegate that same single
lookup to [`wss-survey`](../../../agents/wss-survey.md) instead** — brief:
`WSS.record.decisionsIndex` plus the list of dimensions
in play; verdict: which entries bear on which dimension, one line each.

### Invoke the project's code-analysis skill, if it has one

**This is where deep code analysis enters, and the only place it does.** Before
fanning out, look for a project-scoped code-analysis skill:

```bash
ls .claude/skills/ 2>/dev/null
```

Where one exists — a skill whose purpose is analysing *this* project's source —
invoke it as one more concurrent finding source, and tell it three things: the
slice Phase 0 resolved, its share of the carry-over list, and that it must
**report findings rather than fix them**, in the same severity-and-citation shape
as the briefs below. Its findings then flow into Phase 2's verification and
Phase 3's review exactly like any other dimension's.

**Where none exists, say so in the plan and in the final report** — "no code
analysis ran" — and recommend writing one into `.claude/skills/` if the user
wants that coverage. Never imply the code was examined.

### The briefs

Each brief names a failure **class**; Phase 0's evidence supplies the nouns. No
brief assumes the project has routes, or a database, or a server.

| Dimension | Brief |
|---|---|
| **`record`** | **Hand the auditor [`wss/tests/WSS.RECORD-DRIFT.md`](../../../wss/tests/WSS.RECORD-DRIFT.md).** One change: the auditor reports, it does not dispatch or edit. |
| **`consistency`** | Layering, naming, error shapes, duplication that a fourth copy will turn into a bug, dead code, abstraction level **against the project's own stated conventions**, which are in `WSS.record.reference`. Not performance without a measured problem. |
| **`interface`** | The contract this project offers its callers, whichever form it takes: surfaces that changed shape without a version, undocumented or accidentally-public surface, inconsistent errors and exit codes, and defaults that are hard to reverse once depended on. Judged from outside, against what `WSS.record.behaviour` and `WSS.record.reference` claim it offers. |
| **`safety-nets`** | A **presence** check, not a review. Does a test suite exist, and does the full run pass. Does CI exist, does it run on the branches that matter, and does it actually gate a merge. Is there a lockfile. Are the destructive operations gated behind `permissions.ask`. Every answer is yes/no plus evidence. Whether the tests are *good* is the project code-analysis skill's question. |

**A dimension whose evidence Phase 0 did not find is not dispatched.**

**Where a project declares extra dimensions in `WSS.audit.dimensions`,** each carries
its own `brief` pointer, and those may be as stack-specific as the project likes.

**No auditor runs the test suite.** They have no write tools, but you are the one
who has to not ask them to.
