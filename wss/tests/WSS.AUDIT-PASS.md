# The independent audit pass

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). The rubric of
the ritual that produces the frozen reports under `wss/logs/audits/`: an adversarial
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
  **method**; doctor, contract suite, syntax
  pass, publish-gate and CI results, each with its count or verdict; the delta
  since the previous pass.

  **Method is a named value, because the score is only comparable within one.**
  `warm` (in-session, the tree's own context), `cold` (a subagent or a cleared
  session with no memory of the work being judged), and
  `cold-after-preflight` — cold, against a tree a preparation run has just swept
  and committed. The last one scores higher for reasons that are not
  improvement, so a pass carrying it argues its delta against the method change
  before arguing it against the previous number. Say inline whether the reading
  was inline or delegated; that is a cost disclosure, not a method.
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
  coherence; **transparency and reliability**, defined in their own section
  below because neither is self-defining for a suite made of prose.
- **The per-skill table** — every skill, with body and description bytes,
  per-invocation load, usefulness, real use graded from artifacts (tags,
  entries, PRs, sweep stamps — never impressions), a trim note at the "could be
  trimmed around the edges" grain, and an overall rating.
- **The inspection-stack inventory** — every self-audit mechanism, what it
  answers, when it fires, and the simplification verdict.
- **Attack the previous pass** — every prior finding re-verified as genuinely
  closed or still open, by reading or by running, never by trusting the record.
- **Attack the preparation run**, where one ran in the audited range. Every
  prose cut it made is re-checked against
  [`WSS.PROSE-PRUNE.md`](WSS.PROSE-PRUNE.md)'s never-cut list — above all *the
  last surviving statement of a rule*, which a sweep working file-by-file
  cannot check for itself. A cut that removed the only copy is a behaviour
  change wearing the shape of tidying, and **nothing else in this suite would
  report it**: the doctor sees a resolving tree, the tests see no code, and the
  next sweep sees prose that is now consistent because the dissenting copy is
  gone. This is the one feature that exists because a *fix* can do damage a
  defect could not.
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

## Transparency and reliability — the two the order puts first

They are numbered §10 and §11: last in the report, first in the owner's order
(transparency > reliability > efficiency). **The numbering keeps §1–§9
comparable with the frozen series and says nothing about rank** — efficiency has
been §1 since pass 1 while neither of these was anywhere, which is the gap they
close. Both are scored like any other dimension: an anchored 10, and the
concrete moves that would raise it.

**§10 Transparency — does a run say what it actually did?** Not whether the
prose promises disclosure, but whether the disclosure survives the unhappy path,
which is the only place it is load-bearing. Take the obligations the suite
already states — "no code analysis ran" rather than a silent skip, an absent
verification command reported as a finding, a gate printing its own
local-vs-assembled gap, a count never quoted without the command behind it, a
cost disclosed as a cost — and exercise each where the input is missing,
ambiguous or already stale. **The failure class is output that cannot
distinguish *checked and clean* from *never looked at*:** a fallback taken
silently, a self-skip that prints nothing, a value carried from memory rather
than from the file that owns it, a summary that reads as coverage the run did
not have. One row per obligation *exercised*, naming the fixture and the
observed output; an obligation read but not run is labelled unexercised rather
than scored.

**§11 Reliability — is the rule enforced, and does it fail closed?** For each
rule the pass touches, name what holds it up: a script, test, gate or hook
(**mechanical**), or prose a model may or may not follow (**asserted**). Report
the split as a count, not an impression. Then, for each mechanical one, whether
a broken check fails the run or passes vacuously — **a gate that cannot fail is
`asserted` wearing a script's clothes**, and pass 13's F1 is the worked example.
The findings this dimension produces: a rule with no detector; a check that
self-skips on a file it cannot see; a claim written in two places where a change
can half-land; an enforcement whose last real firing nobody can date. **§9
inventories the mechanisms; this dimension judges whether the rules have any** —
do not repeat the inventory here.

## The report's shape

**This section exists so a pass never has to open its predecessor to learn what
a report looks like.** That was the standing reason to read the previous report
in full, and reading it for *shape* is how each pass inherited the last one's
prose habits along with its structure — the series runs from roughly 8 KB to
45 KB on one rubric, which is a spread in style, not in findings.

```
# Independent Audit — Pass N
<header block>                          ~0.5 KB
## OVERALL VERDICT: <score> — moved or held, and the argument         ~0.5 KB
## ATTACK THE PREVIOUS PASS             one line per prior finding      ~1 KB
## ATTACK THE PREPARATION RUN           where one ran in the range      ~1 KB
## FIXTURES EXECUTED THIS PASS          command, fixture, observed      ~1 KB
## 1..8  the eight rubric dimensions    ~1 KB each; #3 (per-skill) ~3 KB
## 9. THE INSPECTION STACK                                           ~1.5 KB
## 10. TRANSPARENCY   obligations exercised, fixture and output         ~1 KB
## 11. RELIABILITY    mechanical vs asserted, and fails-closed          ~1 KB
## FINDINGS                             ranked; ~1 KB each, count free
## PROVEN CLEAN                         numbered, with the evidence      ~1 KB
## LAST STEP — duplicates against `WSS.record.audits`                ~0.5 KB
# ANNEX — Proposals                                                    ~2 KB
```

**The budgets bound restatement, not findings.** Findings and proven-clean
entries are uncapped in number — the per-entry figure is what is bounded. A
section running over is a prompt to check whether it is re-explaining something
the rubric already says, which is the failure the spread above measures; it is
not a violation, and nothing enforces it.

**A pass reads its predecessor's `## FINDINGS` section and stops there.** The
checklist is this file, the verdicts and continuity are `WSS.record.audits`, and
the shape is the block above — the previous report is authoritative on one
thing only, which is what it found.

## How the measuring is paid for

A delegated survey is dominated by deterministic counting, which pays model
tokens for arithmetic. The split below is part of the method, not an
optimisation a pass may skip:

- **`./wss/scripts/wss-audit-assets.sh --base <previous pass's HEAD>` emits the
  deterministic measurements** — the header block's mechanical facts, the
  per-skill size table, the always-on components, sweep distances, record
  counts. Run it instead of delegating any survey whose questions are counts.
  The script deliberately does not run `wss-publish.sh`: the publish arc is a
  gate the pass exercises itself, watching it.
- **The two judgment surveys — delta-claim falsification and chain
  classification — go to [`wss-survey`](../../agents/wss-survey.md), the agent
  form of [the dispatch ladder's](../workflow/WSS.DISPATCH-LADDER.md)
  Survey rung**, with the verdict format pinned in the
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

The report is a frozen file in `wss/logs/audits/`, named `<date>-<model>-pass<N>.md`;
its index row goes to `WSS.record.audits` through `audit-writer`, in the same
change — `wss-doctor.sh` fails a report file that has no row. Rows and report
are frozen once written; remediation is recorded by the decision log and the
history, never by editing the pass.

**A finding that is a class rather than an instance names the sweep that owns
it.** Where the pass finds context bloat, writing structured to go false, or a
trigger that will misroute — and finds it across files rather than in one — the
report says to run `tidy`'s token-economy, rot-resistance or routing job.
That recommendation is one of those jobs' standing triggers, and it is what
stops a pass fixing one instance and leaving the class for the next pass to
re-find.
