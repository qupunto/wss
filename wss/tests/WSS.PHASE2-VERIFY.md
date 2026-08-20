# Phase 2 — Verify, then run the suite

### Re-verify by hand

Not optional. Before anything reaches the user, personally re-check:

- **every `critical` and `high` finding**, by reading the cited lines yourself;
- **every negative claim** ("nothing does X"), by running the grep that would
  *disprove* it —
  [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md#negative-claims);
- **every count** — tests, routes, migrations, rows;
- **anything contradicting `WSS.record.decisions`.** The decision is usually right
  and the auditor usually missed it.

**Delegate the mechanical half.** Re-checking a `medium` or `low` finding, or
running the grep that settles a negative claim, is reading rather than
judgement — the **Survey** rung, on the key that the brief names the read set
and pins the verdict format. Send it to
[`wss-survey`](../../agents/wss-survey.md) with the citation and have it return
a verdict plus evidence.

**Do `critical` and `high` yourself.** Those are the ones that reach the user as
"I checked this".

That gives three levels, and the `WSS.record.stocktake` `Verification` field must say
which is which: **re-checked by the orchestrator**, **re-checked by an
independent verifier**, or **agent-reported**. Collapsing the middle into the
first is the dishonest move available here.

Mark each finding `[verified]`, `[reported]` or `[disproven]`. Disproven findings
are dropped from the review list but **named in the audit entry**.

Deduplicate across dimensions: the same defect found by three auditors is one
finding with three citations.

### Then check each survivor against the audit history

**False clean.** For every surviving finding, check whether its file sat inside a
previous audit's `covered` globs at a commit where the defect was already present
(`git show <that audit's baseline>:<file>` is the file as that audit saw it). If it did,
that audit reported clean on code that wasn't. Mark the finding
`[missed by <date> audit]`: it says a dimension's brief or slice was too narrow.

**Recurrence.** Match every finding against the carry-over list. A finding
matching a **fixed** item is a *regression* — re-open it one severity higher and
name the commit that was supposed to have fixed it. A finding matching a **still-open** item is
not new: fold it into the carry-over count rather than listing it twice.

### Then run the suite — once, and read CI

**The mechanics are
[`wss/tests/WSS.MECHANICAL-GAUNTLET.md`](../../wss/tests/WSS.MECHANICAL-GAUNTLET.md)**
— the doctor-first sequence, the full-suite-with-coverage rule, the consent
budget, the `test-run` carry-forward, and CI's four outcomes on the audited
SHA, all of them in the report. Run the project's schema-validation and
dependency-audit commands alongside, where it declares them.

What stays this skill's, because it is an orchestrator's:

- **Where there is no suite to run**, say so plainly and carry Phase 0's
  standing `high` finding — silence reads as "the tests pass". A missing CI run
  is Phase 0's finding the same way.
- **Check nothing else is mid-run first.** Grep the process table for the
  project's test runner; a collision produces failures indistinguishable from
  real defects, so wait and say so rather than retrying into it.
- **Consent is the orchestrating session's alone** — never a subagent's.
- **Afterwards, hand `sweep-tracker` the `test-run` entry** — the sha, the
  result and the runtime count. Hand it over rather than writing the file here:
  the checkpoint has one writer.
- **Record the runtime count from the run's own output**, not a count of call
  sites — parameterised helpers expand at runtime and undercount. Compare
  against the previous audit's figure; a suite that grew more slowly than the
  code did is a finding the test dimension should be asked about directly.

### Save the findings before talking to the user

Write the consolidated, verified findings to the scratchpad as `audit-<sha>.md` —
numbered, grouped, with citations and verification marks. Context may compact
partway through the review.
