# The finding dispatch

When it finds something, it invokes the skill that **owns** that file, and that
owner re-verifies and writes under its own rules, in its own commit.

Delegation is a lookup, not a judgement, and
[`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md) is the authority. The
rows below are the dispatching runner's view of it — a second copy, kept honest
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
| `WSS.record.setup` | `reference-writer` |
| `WSS.record.toggles` | `reference-writer` |
| `WSS.record.todo` (a file, or a provider — see below), `WSS.record.openDecisions`, `WSS.record.decisions`, `WSS.record.exerciseDebt`, `WSS.record.ruleEnforcementStatus` | `--wss-todo` / `--wss-log` |
| `WSS.record.decisionsIndex` — a stale generated index, per check 4 | `--wss-todo` / `--wss-log`, which owns `WSS.commands.indexRegen` |
| `WSS.record.roadmap` — every lane's copy — and `WSS.record.releases` | `--wss-plan` |
| `WSS.record.toolbelt` | `--wss-scout` |
| `WSS.record.stocktake`, `WSS.record.audits` | `audit-writer` |
| `WSS.record.changelog` | `changelog-writer` |
| `WSS.record.tooling.catalog` | `--wss-catalog` |
| the docs site's annex page derived from `WSS.record.tooling.catalog` | `docs-writer` |
| `.claude/WSS.WORKFLOW.json` — a key naming a file that moved, or one nothing reads | `manifest-writer` |

**Every row is a primitive or a record owner, and none is an orchestrator whose
whole procedure would have to run.**

**`WSS.record.tooling.sources` has no row, and that is deliberate rather than a
gap.** A stale claim, prune candidate, token-economy or rot-resistance hit, or
routing miss found there is not dispatched at all — `--wss-health-check` runs
those lenses itself and disposes of the finding in place, per its own
procedure, rather than handing it to a primitive the way every row above does.

Resolve the paths through the lane selector first: where `.claude/WSS.LANE` names a
lane, `WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for the
splittable keys — [`WSS.LANE-CONTRACT.md`](WSS.LANE-CONTRACT.md)'s
resolution rule. A finding in a lane file dispatches to the same owner the
unsplit record has; the lane changes the path, never the writer.

**One exception, and it is not a dispatch.** A finding about a file belonging to
**this suite** — including one the running inspection is itself reading — is not
disposed of in place. File it and stop, per
[`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session),
which holds the destination and the reasoning. This never covers the project's
own skills: `WSS.record.tooling.sources` globs are relative, so `--wss-health-check`
disposes of them as usual.

**The owner's second look is the point, not overhead** — hand over the evidence,
not a verdict, and expect a share of your findings to come back not reproduced.
Why that is load-bearing:
[`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md#the-inspector-writes-nothing).
