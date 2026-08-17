# The writers

**Procedures, not skills.** Each file here is the one procedure that writes one
record. A skill that needs a record written **reads the file and follows it** —
there is nothing to invoke.

**This is an index of the `.md` procedures in this directory, not of every
record writer** — a script elsewhere in the tree can own a record too, and one
does. Read [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s matrix for the complete
answer to "what writes this record"; it stays the single place that is asserted,
so this line points rather than restates. Ruled against widening
this file's scope: the case is one script, and widening would make a record's
writer something two files claim.

## Why they are not skills

A skill's `description` loads into every session whether or not the skill is
ever used. A procedure invoked only by other skills pays that standing
per-session cost for a trigger it explicitly disclaims — and in plugin form
nothing can suppress it, since `skillOverrides` does not reach plugin skills.
So these are files to read, not skills to invoke.

**Reading a procedure is more reliable than dispatching to one, not less.** A
skill fires when the model judges a description to match; a link is followed
because the caller was told to follow it. The mechanism is the same one every
skill already uses to reach [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md) and the other
contracts in this directory.

## Location does not change ownership

**One writer per record.** A procedure is one file, the sole writer of its
record, and [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s matrix is the authority on
which. Where a procedure lives says nothing about who may write what.

**The authorization rule.** A procedure inherits the grant of the flag the
*user* typed, however many hops away. It confers nothing of its own: a flag that
reaches one of these does so through a skill, and the grant stays that flag's.

## Read inheritance

**A procedure invoked by a caller assumes the caller's in-window contract
reads and skips its own — reading anyway when invoked with no caller, or when
what the caller says about a contract is disputed.** The caller already paid
for `WSS.OWNERSHIP.md`, `WSS.RECORD-CONTRACT.md`, or whichever contract sits
behind the call; reading it a second time here buys nothing the first read did
not already put in the window. The no-caller branch is not the rare case to
trim away — a procedure invoked directly has no caller's reads to inherit, and
skipping them anyway is how a contract goes unread.

**Silence is not inheritance, and this is the half that actually bites.** A
caller is not presumed to hold a contract merely by existing: inherit a read
only where the caller **says** it holds that contract, or where the caller's own
procedure mandates that read. Where the caller says nothing, there is nothing to
inherit and the procedure reads. The failure this prevents is quieter than the
no-caller one and has no symptom — a caller that never read
`WSS.RECORD-CONTRACT.md` invokes a writer, the writer skips it on the assumption
the caller paid, and the contract governs a write that neither of them read.
**So a caller claiming inheritance names the contracts it holds**, in the brief
or in the invocation; a bare invocation inherits nothing. Each writer's header
links here rather than restating the rule.

## The files

| Procedure | Sole writer of |
|---|---|
| [`WSS.AUDIT-WRITER.md`](WSS.AUDIT-WRITER.md) | `WSS.record.stocktake`, `WSS.record.audits` |
| [`WSS.BEHAVIOUR-WRITER.md`](WSS.BEHAVIOUR-WRITER.md) | `WSS.record.behaviour` |
| [`WSS.CHANGELOG-WRITER.md`](WSS.CHANGELOG-WRITER.md) | `WSS.record.changelog` |
| [`WSS.DOCS-WRITER.md`](WSS.DOCS-WRITER.md) | the documentation site — pages, index and sidebar rows, mirrors, and the diagrams inside them |
| [`WSS.GIT-WRITER.md`](WSS.GIT-WRITER.md) | commits and tags |
| [`WSS.HANDOFF-WRITER.md`](WSS.HANDOFF-WRITER.md) | `WSS.record.handoff` and its overflow document |
| [`WSS.MANIFEST-WRITER.md`](WSS.MANIFEST-WRITER.md) | `.claude/WSS.WORKFLOW.json` |
| [`WSS.REFERENCE-WRITER.md`](WSS.REFERENCE-WRITER.md) | `WSS.record.reference` |
| [`WSS.SWEEP-TRACKER.md`](WSS.SWEEP-TRACKER.md) | the sweep checkpoint |

That column is a convenience. Where it and [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)
disagree, the matrix wins — it is the copy `wss-doctor.sh` compares the flag hook
against, and this one is compared against nothing.
