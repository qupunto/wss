---
name: reference
description: "Record what the project is — stack, architecture, data model, conventions — settled in conversation, written into the reference record. SHORTHAND: `--wss-reference`. Also trigger on \"write down the stack\", \"record the data model\", \"update the reference for X\". Not on runtime rules, which are `--wss-describe`'s, and not on why, which is `--wss-log`'s."
---

# Record what the project is

A fact about the project's shape settled in conversation has no way to reach
`WSS.record.reference` on its own. Every other route into that record is a side
effect — an inspecting or building caller dispatches to the writer when it
happens to notice a gap, and none of them fire because someone settled what the
stack, the data model or a convention is. This flag is that route — the same
shape as `--wss-describe`, for the record one column over.

**This skill decides nothing and writes nothing itself.** It resolves the record
and hands the work to
[`writers/WSS.REFERENCE-WRITER.md`](../../wss/workflow/writers/WSS.REFERENCE-WRITER.md),
which is the sole writer of `WSS.record.reference` per
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md). The whole of what to write,
how much, and what that record may not hold is that procedure's — read it rather
than restating its rules here.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.reference` — an
**array of paths**, not one — with the fallback in
[`WSS.MANIFEST.md`](../../wss/workflow/WSS.MANIFEST.md). Say which you used.

## The file this reaches may be the project's landing page

`--wss-describe` can never rewrite a README; this flag can, and that asymmetry is
the one thing to hold in mind before anything is written. A manifest may map
`README.md` into the reference array — that mapping is consent, and the writer's
"never take over a README that was not offered" section is the authority on it.
What this skill owes on top: **name the exact file the fact resolved to before
writing**, and where that file is the project's public landing page, say so in
the same breath. A write that lands on a README the user did not expect is the
failure this paragraph exists to prevent.

## What reaches this flag, and what does not

`WSS.record.reference` holds **current state** — the stack and its versions, how
the pieces fit together, the data model, directory layout, adopted conventions.
Three neighbours are routinely handed here and each belongs elsewhere:

| Handed here | Actually | Route |
|---|---|---|
| *Why* the stack is this stack | reasoning | `--wss-log` |
| Auth, ownership, state transitions, error statuses | `WSS.record.behaviour` | `--wss-describe` |
| A guide, runbook or long-form page | the docs site | `--wss-docs` |

## Procedure

1. **Resolve `WSS.record.reference`** from the manifest, or the fallback. Say
   which file in the array the fact belongs to — and say plainly when that file
   is the project's `README.md`.
2. **Check the fact is about what the project is**, against the table above. If
   it is not, name the right record and stop — routing beats writing to the
   nearest file.
3. **Verify the fact against the source before writing it.** A claim stated in
   conversation is a claim about the tree, and this record is exactly what a
   later reader trusts instead of checking. Where the code disagrees, the code
   wins and the disagreement is what to report.
4. **Hand it to `reference-writer`** with the fact, the file and section it
   belongs to, and what you verified it against.
5. **If the fact is new rather than a correction**, the reasoning behind it is a
   separate record: offer `--wss-log`. Do not write it yourself, and do not let it
   ride along inside the reference.
