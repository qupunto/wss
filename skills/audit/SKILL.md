---
name: audit
description: "Run an independent audit pass over this project and file the frozen report — the cumulative rubric, findings settled by execution rather than reading, anchored verdicts, the proposals annex. Expects a clean pinned tree and a session with no memory of the work judged. Invoke only as /wss:audit: no flag, never inferred. COMMITS, NEVER PUSHES, FIXES NOTHING."
disableModelInvocation: true
disable-model-invocation: true
---

# The audit pass

**This ritual ships** — the ruling is the decision log's
`2026-08-19 (eighty-first)` entry, which closed Cycle 29's first gate. What does *not* ship
is this project's own reports: `wss-publish.sh` deletes `wss/logs/audits/` from
every assembly, and `WSS.record.audits` ships blanked, so an adopted tree
receives the ritual and none of our findings.

**Where the reports go.** `WSS.record.audits` names the audit *index* — a file,
not a directory. **The frozen reports live in an `audits/` directory alongside
that index file**, so in this tree the index `wss/logs/WSS.AUDITS.md` puts them
in `wss/logs/audits/`, which is where they already are.

**Resolve it from the index's own directory, and never from the undeclared
fallback.** Where `WSS.record.audits` is undeclared, **say so and stop** — a
tree with no audit index is not running this ritual, and the fallback path is
itself inside an `audits/` directory, so composing against it would nest one
`audits/` inside another. That trap is the reason this rule is stated in words
rather than as a path expression: the key and the directory share a name, and an
expression built from both reads as though it doubles even when it does not.

**The rubric is
[`wss/tests/WSS.AUDIT-PASS.md`](../../wss/tests/WSS.AUDIT-PASS.md).**
It carries the cumulative law, the standing features, the report skeleton and
its budgets, the chain-measurement convention, and the filing rules. This file
is the runner: what to read, in what order, what to delegate, and what may never
leave the session. **Where the two disagree, the rubric is right** — it is the
file a pass adds a feature to, and the one the next pass reads as its checklist.

## Before anything: is this session eligible

**A pass judges work it did not do.** Run this in a session with no memory of
the changes under audit — after `/clear`, or freshly. If this session prepared
the tree, stop and say so: the finding you would most want is the one a fixer
cannot see.

Declare the method in the header block, from the rubric's named values — `warm`,
`cold`, or `cold-after-health-check`. It is not a formality: **a score is only
comparable within one method**, and a prepared tree scores higher for reasons
that are not improvement.

## A. Pin

`git rev-parse --short HEAD` and `git status --porcelain`. A dirty tree is a
stop rather than a caveat: every coverage claim would be `not-covered` under
[`WSS.AUDIT-COVERAGE.md`](../../wss/workflow/WSS.AUDIT-COVERAGE.md)'s own rule,
because a file verified in a state no sha addresses licenses nothing.

Take the previous pass's baseline from `WSS.record.audits` — the delta range is
that sha to this one.

## B. Load the stable material, once, in this order

1. The rubric, in full.
2. **The previous report's `## FINDINGS` section only.** Not the whole report.
   The checklist is the rubric, the verdicts and continuity are the index, and
   the shape is the rubric's skeleton — the previous report is authoritative on
   one thing, which is what it found. Reading it whole is how each pass
   inherited the last one's prose habits.
3. `WSS.record.audits`, for the dedup step and the continuity argument.
4. `./wss/scripts/wss-audit-assets.sh --base <previous pass's HEAD>` — every deterministic
   measurement, so no model tokens are spent on arithmetic.

Read these early and do not re-read them. Everything after this point is
execution, and the pass wants its context spent there.

## C. Attack the previous pass

Every prior finding re-verified as genuinely closed or still open — **by
running, not by trusting the record**. A finding marked closed in the index and
not reproducible by execution is a finding about the record.

## D. Attack the preparation run, where one ran in the range

Every prose cut in the delta re-checked against
[`WSS.PROSE-PRUNE.md`](../../wss/tests/WSS.PROSE-PRUNE.md)'s never-cut
list, above all **the last surviving statement of a rule**. `git log -p` over
the prune commits is the read; `wss-duplication.sh` on the pre-delta tree tells
you which paragraphs *had* a second copy, and a cut whose counterpart also went
is the shape to hunt.

## E. Fixtures

Unhappy paths executed against synthetic fixtures in the scratchpad. A finding
names the command, the fixture and the observed output. **Reading finds
candidates; running settles them** — and an unexecuted scenario is labelled
unexecuted in the finding itself rather than left to read as proven.

## F. The two delegated surveys, and only these two

Delta-claim falsification, and chain classification. Both go to
[`wss-survey`](../../agents/wss-survey.md) with the verdict format pinned in
the brief: `file:line`, byte counts, no file dumps. Judgment here means reading
and classifying; **the disposition of what comes back stays in this session.**

Everything else — fixtures, verdicts, findings, scores, dedup, filing — never
leaves it. Delegating a disposition is delegating the pass.

## G. Judge

The rubric's dimensions, the per-skill table, the inspection-stack
inventory, the verdicts. **§10 and §11 are settled in E, not here** — a
transparency row without a fixture and an observed output, or a reliability row
calling a gate mechanical without having watched it fail, is an impression. Every score states the standard its 10 would satisfy
and the concrete moves that would raise it, per the rubric's anchored-ratings
rule.

**Skills are judged as a set, not only one by one.** Two skills doing the same
job with near-identical prose is a finding no per-file pass produces; run
`./wss/scripts/wss-duplication.sh` and read `.claude/WSS.TOOLS.json`'s measured chains
rather than re-deriving sizes.

## H. Place and file

Dedup every finding against `WSS.record.audits`. Place the verdict against the
series dimension by dimension — and where the method changed, argue the delta
against **the method change first** and the previous number second.

The proposals annex is last: ranked by leverage over effort, each naming its
machinery cost and its residual maintenance. **Nothing in it is applied by this
pass.**

Then file, per the rubric's `## Filing`: the frozen report at
`<the reports directory above>/<date>-<model>-pass<N>.md`, and its index row through
[`audit-writer`](../../wss/workflow/writers/WSS.AUDIT-WRITER.md) **in the same
change** — `wss-doctor.sh` fails a report that has no row, and the row is not
this skill's to write.

**A finding that is a class rather than an instance names the sweep that owns
it.** Context bloat, writing shaped to go false, a trigger that will misroute —
found across files rather than in one — is a recommendation to run the matching
`--wss-health-check` lens. That recommendation is one of those lenses' standing
triggers, and it is what stops a pass fixing one instance and leaving the class
for the next pass to re-find.

## What it never does

- **It fixes nothing.** Findings are ranked and filed; remediation is a separate
  decision on the owner's ruling, and the report is frozen the moment it lands.
- **It does not edit a prior report or row.** Those are append-only history. A
  claim that is factually false is the sole exception, and it is the owner's
  call, not this skill's.
- **It does not push.**

## Authorization

**Commit, not push**, per
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md)'s matrix. The report is
this skill's own file; the index row goes through `audit-writer`, which holds no
grant of its own and writes under this one.
