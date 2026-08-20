---
name: overview
description: "Report where a project stands at a glance — record counts per lane, sweep freshness, pending warnings, the nearest milestones, branch and lane. SHORTHAND: `--wss-overview`. Also trigger on \"where does the project stand\", \"state of the repo\", \"project status at a glance\"."
---

# The project at a glance

**This skill writes nothing.** No record, no checkpoint, no commit, no sweep.
Anything that looks wrong is reported with the flag that owns fixing it, in
one line, and left alone.

## Run the probe first

Every mechanical number in the report comes from one script, run from the
project directory:

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
bash "$S"/skills/overview/assets/wss-probe.sh
```

<!-- load-bearing: the only route to contracts that survives publication — see the decision log before removing -->
The two resolution lines are [`contracts`](../contracts/SKILL.md)'
canonical form.

The probe is read-only and offline. It resolves `.claude/WSS.WORKFLOW.json`
itself — conventional fallbacks, the `.claude/WSS.LANE` selector, `WSS.lanes.named`
overrides, all per [`WSS.MANIFEST.md`](../../wss/workflow/WSS.MANIFEST.md) — counts every
record, runs `wss-doctor.sh`, computes each sweep baseline's distance from HEAD
— by calling `wss-sweep-distance.sh` beside it, the one implementation of that
measurement, which `--wss-wrap` step 7 runs `--compact` for its closing line —
locates the roadmap's first goal with open blocks, and locates the release
list's first milestone not marked completed. **The roadmap is lane-resolved
and the release list never is** — one release checkpoint per project, however
many lanes it runs, per
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md). **Quote its
block rather than re-rendering it**: paste the probe's output as the report,
then append the judgment lines below — one line each. Every number
was read at this invocation: never carried forward from a handoff card,
memory, or an earlier session. A count is a mutable claim, so it lives in
the reply and never lands in a file
([`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)).

The general form of that rule, and its concurrency caveat, is
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#a-skill-resolves-its-pointers-before-it-runs).

Where the probe cannot run at all, read and count by hand to the same
contract, and say so in one line.

## What the model adds — the judgment lines

The probe stops where mechanics stop. On top of its output:

- **Finish the lines it marks "not counted here" or "not checked".** A
  provider-backed TODO list is not fetched here at all: report the line as
  "TODO list is a github-issues provider (on-demand triage)" rather than a
  count, per
  [`providers/WSS.GITHUB-ISSUES.md`](../../wss/workflow/providers/WSS.GITHUB-ISSUES.md#what-the-sweeps-do-with-it).
  Never dropped: an absent line reads as clean.
- **Interpret both positions, and keep them apart.** The roadmap's is *what
  this area is working toward* — in a lane worktree, that lane's, and say
  which lane. The release list's is *what ships next*: name the first
  milestone not marked completed, whether it is a real milestone or a
  maintenance gate, and which of its versions is the nearest minor and which
  the nearest major. **A goal being met is not a milestone being complete**,
  and nothing derives one from the other.
- **Say when the probe warns that a roadmap heading carries a version or a
  completion mark.** That is a release checkpoint in the wrong file — under
  lanes, one worktree's — and it goes to `--wss-plan`.
- **Report whether a release is in flight.** The probe compares `.claude-plugin/plugin.json`'s
  version against the newest git tag: if the version leads, a release is in flight; if they match,
  nothing is in flight; if no tag or no plugin.json exists, say so and interpret nothing.
- **Keep the probe's distinct states distinct.** "Undeclared", "missing" and
  "0 open" are three different facts — "no TODO list is declared" and "the
  TODO list is empty" must never render as the same bare `0`.
- **Report, never repair.** Stale sweep → name `--wss-health-check`. Untriaged
  inbox → name `triage`. A milestone that looks complete → name
  `--wss-plan`. One line each; acting on them is those flags' work, under
  their grants.

## What this skill does not do

- **It does not stamp anything.** Reading records is not a sweep and earns no
  checkpoint — `sweep-tracker` never hears from it, and the probe is as
  read-only as the skill.
- **It does not verify claims.** Drift detection is `--wss-health-check`'s method;
  this skill counts what the records say, not whether they are right.
- **It does not rebuild or reorder anything** — TODO list is `--wss-todo`'s,
  roadmap is `--wss-plan`'s, and a full reckoning is `--wss-health-check --deep`'s TODO resort.
