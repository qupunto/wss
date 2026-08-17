# Step 3 — Present every dependency for a decision

**Lane by lane, and within each lane in three passes: `todo`, then
`openDecisions`, then `roadmap`.** The grouping is what makes a long list
reviewable — a user deciding twenty items wants them sorted by where they
land, not by which lane happened to imply them.

Every item is presented with the facts needed to rule on it:

- **Which record it was derived from**, by lane and by name.
- **Why it is this lane's work**, in one sentence.
- **What it would land as** — the target record, and the entry text.

**Four rulings, and they differ in two axes: whether anything is filed, and
whether the next run asks again.**

| Ruling | Files to the queue | Next run |
|---|---|---|
| **Accept as critical** | yes, with `[critical → why]` | — |
| **Accept** | yes, unmarked | — |
| **Defer** | no | **asks again** |
| **Decline** | no | **does not ask** — see below |

**wss/docs/annex/WSS.LANE-SYNCHING.md's copy of this table is generated from here** —
after changing a row, run `bash wss/scripts/wss-gen-lane-rulings.sh` from the repo root
before the docs check next runs.

**`[critical → why]` is written only where the user said so in this turn** —
this gate and step 2's mediation are the two places, per the contract section
cited there.

### Defer and Decline are not the same answer

They file the same thing — nothing — and that is where the resemblance ends.

- **Defer means the derivation is right and the timing is wrong.** It is
  remembered nowhere, deliberately: the next run finding it again *is* the
  behaviour wanted. This is the cheap ruling and it needs no machinery.
- **Decline means the derivation is wrong** — not that lane's work, or a
  mistaken inference. Re-deriving it every run would ask the same wrong
  question forever, and **a gate that asks a wrong question repeatedly stops
  being a gate**: the user learns to clear the prompt, which costs the
  approvals that matter.

So a decline is written down. **A decision not to build something is still a
decision** — [`WSS.RECORD-CONTRACT.md`](../../../wss/workflow/WSS.RECORD-CONTRACT.md)'s rule 2
— so hand `--wss-log` **one entry per run listing every decline**, with what
each was derived from and why it was rejected. One entry rather than one per
item: they were ruled on together, and N entries would be N index lines for
one sitting.

**A decline is not permanent by machinery, it is permanent by record.**
Nothing here detects that the source record changed and the derivation became
valid again. Reversing it is a later decision, logged as one, which is how
every other reversal in this project works — do not build change-detection to
guess at it.

**The approval is mandatory and it is the point of this skill.** Derived work
is a *proposal* until a person says otherwise, and this is the only place a
person is present.

Two consequences of that, both easy to get wrong:

- **Never batch the rulings into one prompt.** "Add all 14?" is not the
  decision this exists to obtain — the whole risk is that some of them are
  stale or wrong, and one answer cannot separate them.
- **Declining and deferring are different answers**, per the table above, and
  offering only one of them collapses "this is wrong" into "not yet".

An entry that came through this gate is eligible for the receiving lane's next
batch as soon as `--wss-start` drains it, because it has already been ruled on
here.
