# Writing the behaviour record

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md), whose [read-inheritance rule](WSS.WRITERS.md#read-inheritance) this follows. Sole writer of `WSS.record.behaviour`, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

What this file may and may not hold is
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md), the authority where the
two disagree.

Resolve the path from `.claude/WSS.WORKFLOW.json`. Without a manifest the fallback is
in [`WSS.MANIFEST.md`](../WSS.MANIFEST.md) — **say which you used.** A
manifest that names the file is the authority on placement, so it keeps its path
and skips `--wss-docs`' tier placement and sidebar wiring entirely.

## What this record holds

**What the system does at runtime, by topic.** Auth rules, ownership rules, state
transitions, visibility rules, error statuses, ordering guarantees — the answers
someone needs before they can predict what a request will do.

Three things it never holds, and each has an owner:

- **Why a rule is the way it is.** That is `--wss-log`'s (`WSS.record.decisions`). A rule
  with its rationale inline is a decision log growing inside a reference, and it
  goes stale in a way nobody notices because the rule beside it is still true.
- **Decided-but-unbuilt behaviour.** Also `--wss-log`'s. This file describes the
  running system; a rule that does not exist yet is a plan, and a reader who
  cannot tell the two apart has no reason to trust either.
- **Stack, architecture, data model, conventions.** That is `WSS.record.reference`'s,
  written by [`reference-writer`](WSS.REFERENCE-WRITER.md).

## Two kinds of caller, and they want different amounts

This is why the record has its own primitive rather than living inside `--wss-docs` —
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s split test.

### A dispatched one-line correction

From any inspecting or building caller that found a single rule wrong. Scope is
**the section the finding names, and nothing else.**

1. **Re-verify against source before writing.** A dispatched finding is a
   hypothesis, not an instruction —
   [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md#the-inspector-writes-nothing). A
   finding that has already been fixed reads exactly like a live one, and acting
   on it can mask a real instance of the same class one file away. Hand the
   disagreement back rather than writing a correction that is itself wrong.
2. **Fix what was asked.** A dispatched one-line correction is not a licence to
   rewrite the page. If the section around it is also wrong, report that; do not
   quietly widen the job.

### A batch of runtime changes

From `--wss-describe`, which exists to bring one here directly; from `--wss-start`
Phase 6; or from `--wss-docs` when a page it owns turns out to describe behaviour
rather than architecture.

1. **Read the source, not the diff summary.** The caller knows what it changed;
   only the code knows what the rule now is.
2. **Rewrite only the affected topics.** Enumerated tables are the usual
   casualty — a new endpoint invalidates a row, not the page.
3. **Check for consequences.** Does the intro still describe the current
   arrangement? Did a renamed rule break an inbound anchor elsewhere?
   `grep -rn '#the-old-slug'` across the docs tree.

## Watch for state claims this edit falsifies

**Before writing, grep the record for the claims the new rule makes false** —
"no endpoint enforces X", "not yet built", an ordering guarantee this rule
overrides, a table row the new status code invalidates — and fix them in the
same edit ([`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)).
Same-file scope is the cheap case and the usual one; the cross-record form is a
rule asserting X exists falsifying "no X exists" wherever that sentence lives.

## Where the code disagrees, the code is right

Fix the record and **report the drift you found** — a record that silently
converged on the source has thrown away the one signal that says how far it had
drifted, and the next reader has no reason to check anything.

## Authorization

**None of its own.** Its grant is whatever the caller was granted, and it confers
nothing — [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md) has the rule. It does not
commit; the caller does that when its own flag allows.
