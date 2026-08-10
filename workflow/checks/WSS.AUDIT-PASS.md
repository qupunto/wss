# The independent audit pass

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). The rubric of
the ritual that produces the frozen reports under `audits/`: an adversarial
read of the whole suite from outside its own machinery, run on the owner's ask,
by whatever model is running the session. This file is the rubric; a pass that
reads only its predecessors inherits precedent instead.

## The cumulative law

**A pass carries the union of every prior pass's distinct features.** Features
accumulate; they are never traded away for a focus. Before running one, re-read
the previous report and the index, and enumerate the features as a checklist.

**A focus rotates.** An owner's brief may point one pass at specific ground
("the rename", "the lanes"); the next pass treats that ground as freshly
covered and re-checks it only through the standard prior-findings step. Focus
goes wherever audit coverage is currently thinnest.

## The standing features

- **The header block** — date; the exact HEAD and whether the tree was clean;
  method (warm or cold, subagents or inline); doctor, contract suite, syntax
  pass, publish-gate and CI results, each with its count or verdict; the delta
  since the previous pass.
- **Findings come from execution, not reading** — unhappy paths run against
  synthetic fixtures in the scratchpad; a finding names the command, the
  fixture and the observed output. Reading finds candidates; running settles
  them.
- **The verdicts** — one overall score /10 with the argument for why it moved
  or held; an explicit publishable yes/no; the plugin-as-distributable score as
  its own axis.
- **The rubric dimensions** — token efficiency (always-on and per-invocation,
  measured in bytes); functionality; usefulness of **all** skills; ease of use;
  integration into a new repo; skills partitioning, including the
  compartmentalization audit (only orchestrators compose); SOLID; code
  coherence.
- **The per-skill table** — every skill, with body and description bytes,
  per-invocation load, usefulness, real use graded from artifacts (tags,
  entries, PRs, sweep stamps — never impressions), a trim note at the "could be
  trimmed around the edges" grain, and an overall rating.
- **The inspection-stack inventory** — every self-audit mechanism, what it
  answers, when it fires, and the simplification verdict.
- **Attack the previous pass** — every prior finding re-verified as genuinely
  closed or still open, by reading or by running, never by trusting the record.
- **Findings** — ranked most-severe first, each with evidence, a concrete
  failure scenario, and a fix.
- **Proven clean** — numbered, with the evidence; clean is a result and must be
  distinguishable from "never looked at".
- **The last step** — dedup every finding against `WSS.record.audits`, and place
  the verdict against the series' continuity, dimension by dimension.

A pass that adds a feature adds it here, in the same change — this list is the
next pass's checklist.

## Filing

The report is a frozen file in `audits/`, named `<date>-<model>-pass<N>.md`;
its index row goes to `WSS.record.audits` through `audit-writer`, in the same
change — `wss-doctor.sh` fails a report file that has no row. Rows and report
are frozen once written; remediation is recorded by the decision log and the
history, never by editing the pass.
