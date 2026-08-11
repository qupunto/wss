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
- **Anchored ratings** — every score states, in place, the standard its 10
  would satisfy, so the number is a distance from a defined ceiling rather
  than an impression; and every rated dimension ends with the concrete moves
  that would raise it. (Owner's rule.)
- **The proposals annex** — after the last step, an annex of improvement
  proposals ranked by leverage over effort, each naming its machinery cost and
  residual maintenance. Proposals only: nothing in the annex is applied by the
  pass itself. (Owner's rule.)

A pass that adds a feature adds it here, in the same change — this list is the
next pass's checklist.

## How the measuring is paid for

A delegated survey is dominated by deterministic counting, which pays model
tokens for arithmetic. The split below is part of the method, not an
optimisation a pass may skip:

- **`./wss-audit-assets.sh --base <previous pass's HEAD>` emits the
  deterministic measurements** — the header block's mechanical facts, the
  per-skill size table, the always-on components, sweep distances, record
  counts. Run it instead of delegating any survey whose questions are counts.
  The script deliberately does not run `wss-publish.sh`: the publish arc is a
  gate the pass exercises itself, watching it.
- **The two judgment surveys — delta-claim falsification and chain
  classification — go to subagents on the smallest capable model tier at low
  effort**, never the session model, with the verdict format pinned in the
  brief: `file:line` citations, byte counts, no file dumps. Judgment here
  means reading and classifying; the disposition of what comes back stays
  with the pass.
- **What never leaves the pass's own context:** fixtures, verdicts, findings,
  scores, the dedup step, and the filing.
- **Named maintenance:** a measurement the script silently stops emitting is
  caught by nothing except the dedup step against the previous report's
  header block — check the script's output covers the previous pass's
  mechanical features before trusting it.

## The chain-measurement convention

Stated here so a pass's chain numbers are reproducible by the next one. A
flag's same-window chain is measured as:

- **the flag's heaviest unconditional mode** (full adoption, not amendment;
  write mode, not read) — a lighter mode may be reported too, labelled;
- **transitive through every procedure invoked in-window**, including a
  writer's own unconditional references — a read dispatched to a subagent
  context counts zero;
- **condition-gated reads excluded** (mode gates, lane gates, provider
  gates), each exclusion citing the line that gates it;
- **row-scoped authority lookups excluded** (reading one row of the
  ownership matrix is not reading the file).

## Filing

The report is a frozen file in `audits/`, named `<date>-<model>-pass<N>.md`;
its index row goes to `WSS.record.audits` through `audit-writer`, in the same
change — `wss-doctor.sh` fails a report file that has no row. Rows and report
are frozen once written; remediation is recorded by the decision log and the
history, never by editing the pass.

**A finding that is a class rather than an instance names the sweep that owns
it.** Where the pass finds context bloat, writing structured to go false, or a
trigger that will misroute — and finds it across files rather than in one — the
report says to run `tools`' token-economy, rot-resistance or routing job.
That recommendation is one of those jobs' standing triggers, and it is what
stops a pass fixing one instance and leaving the class for the next pass to
re-find.
