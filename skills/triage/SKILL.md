---
name: triage
description: "A thin route to `WSS.INBOX-TRIAGE.md` — the method for triaging the suite's own defect inbox. User-invocable only; no `health-check` mode runs it. SHORTHAND: `--wss-triage`. Also on \"triage the inbox\", \"triage bug reports\", \"check filed defects against the suite\"."
---

# Triaging the suite's defect inbox

**A thin route, not a procedure.** The method — what an entry is, the two
halves of the inbox, the per-entry steps, what closing requires — lives in
[`wss/tests/WSS.INBOX-TRIAGE.md`](../../wss/tests/WSS.INBOX-TRIAGE.md) and is
not restated here. This skill is the door: when to walk through it, what it
needs, and where a finding goes once classified.

## User-invocable only

**No `health-check` mode runs this.** That skill reports the inbox's open
count at hand-off and never triages it — the decision log's
`2026-08-19 (eighty-second)` entry is explicit that the family split into two
adopter-facing skills, health-check and triage, precisely so triage stays a
deliberate act a session opts into rather than one a pipeline fires on its
behalf. An entry in the inbox is a claim awaiting verification filed by a
session that could not fix it and is long since cleared — treating that as
routine automated work is how a stale report gets re-fixed and a live one
gets closed.

## What it needs

- **Whether this session is authorized to triage at all, and where a
  confirmed finding routes**, is `WSS.CHECKS.md`'s call, not this skill's —
  the method file defers to it and so does this one.
- **The two halves' locations are hardcoded, not manifest keys** — the
  machine-local inbox (`$CLAUDE_CONFIG_DIR/WSS.BUG-REPORTS.md`) and the
  upstream repository (`qupunto/wss`), both as
  [`report`](../report/SKILL.md) documents them. Nothing here
  duplicates that.

## Where a finding goes

**This skill writes no record.** A confirmed or stale entry is a finding
like any other, and it routes through the normal owners per
[`WSS.FINDING-DISPATCH.md`](../../wss/workflow/WSS.FINDING-DISPATCH.md):
work to `--wss-todo`, a ruling to `--wss-log`. The act of closing an entry —
committing the fix, or removing a did-not-reproduce claim with what it
claimed recorded — belongs to whichever of those the finding lands with, not
to this skill.

## What this skill does not do

- **It does not run automatically.** No mode of `health-check`, and no
  other check, invokes it — see above.
- **It does not classify by re-deriving the method.** The steps, and the
  distinction between *confirmed*, *stale* and *did not reproduce*, are
  `WSS.INBOX-TRIAGE.md`'s; this skill only routes a session there.
- **It does not write `WSS.record.todo`, `WSS.record.decisions`, or the
  inbox files themselves.** Those go through their owners, per the dispatch
  above.
