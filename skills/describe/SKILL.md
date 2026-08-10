---
name: describe
description: "Record what the system does at runtime — a rule settled in conversation, written into the behaviour record. SHORTHAND: `--wss-describe`. Also trigger on \"write that rule down\", \"record how this behaves now\", \"document the new auth rule\". Not on why a rule is the way it is, which is `--wss-log`'s."
---

# Describe the running system

A rule settled in conversation has no way to reach `WSS.record.behaviour` on its
own. Every other route into that record is a side effect — an inspecting or
building caller dispatches to the writer when it happens to notice a gap, and
none of them fire because someone decided how the system should behave. This
flag is that route.

**This skill decides nothing and writes nothing itself.** It resolves the record
and hands the work to
[`writers/WSS.BEHAVIOUR-WRITER.md`](../../workflow/writers/WSS.BEHAVIOUR-WRITER.md),
which is the sole writer of `WSS.record.behaviour` per
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md). The whole of what to write, how
much, and what that record may not hold is that procedure's — read it rather
than restating its rules here.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.behaviour`, with the
fallback in [`WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md). Say which you used.

## What reaches this flag, and what does not

`WSS.record.behaviour` holds **what the system does at runtime** — auth rules,
ownership rules, state transitions, visibility rules, error statuses, ordering
guarantees. Three neighbours are routinely handed here and each belongs
elsewhere:

| Handed here | Actually | Route |
|---|---|---|
| *Why* the rule is that way | reasoning | `--wss-log` |
| A rule decided but not built | a plan, not the running system | `--wss-log` |
| Stack, architecture, data model, conventions | `WSS.record.reference` | `--wss-reference`, through `reference-writer` |

The third has the same shape as this one: `--wss-reference` is to
`reference-writer` what this flag is to `behaviour-writer`. Dispatching to the
wrong writer because the user typed this flag at the wrong record is still the
wrong fix; say the record is `WSS.record.reference` and name that flag instead.

## Procedure

1. **Resolve `WSS.record.behaviour`** from the manifest, or the fallback. An absent
   file is an empty record, not an error.
2. **Check the rule is about the running system**, against the table above. If it
   is not, name the right record and stop — routing beats writing to the nearest
   file.
3. **Verify the rule against the code before writing it.** A rule stated in
   conversation is a claim about the tree, and this record is read as though
   every line in it were observed. Where the code disagrees, the code wins and
   the disagreement is what to report.
4. **Hand it to `behaviour-writer`** with the rule, the topic it belongs under,
   and what you verified it against.
5. **If the rule is new rather than a correction**, the reasoning behind it is a
   separate record: offer `--wss-log`. Do not write it yourself, and do not let it
   ride along inside the rule.
