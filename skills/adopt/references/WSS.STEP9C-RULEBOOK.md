# Step 9c — Inherit the rulebook, or take its structure

**Runs only where the adopted tree carries `wss/rules/`.** Where it does not,
say nothing: a project without a rulebook is not missing one.

**The rules ship as written — that is settled** — and the choice of whether to
keep them belongs here rather than at publication. Step 7 asks it; this step
carries it out.

## Inherit

Do nothing. The files arrived with their rows and are the adopter's starting
rules. Say which judge files carry rows and how many, so the answer is informed
rather than nominal — `wss/scripts/wss-rules-checkup.sh <consumer>` prints them.

## Start fresh

```bash
bash wss/scripts/wss-rules-truncate.sh --dir .          # show what would go
bash wss/scripts/wss-rules-truncate.sh --write --dir .  # do it
```

**Every file survives and every section survives; only rows go.** That is not a
softer version of "empty" — `wss-rules-checkup.sh` resolves a consumer against
the index's consumer table and then checks the files it names **exist**, so a
deleted file breaks every consumer naming it. What the adopter receives
validates on arrival and is ready for their first row.

**Run the dry form first and show it.** The write form is the only irreversible
step in this skill that touches content the adopter might have wanted, and a
person who sees `17 row(s) would be removed` before answering has been told
what the answer costs.

## What this step does not decide

**Neither answer is reversible for free in the other direction.** Inheriting and
truncating later is one command; starting fresh and wanting the rules back means
going to the published tree for them. That asymmetry is why step 7 offers
inherit first, and it is worth saying out loud to the adopter rather than
leaving in the option order.

**The privacy control is not this step's.** A row's `statement` is the rule and
never the phrasing of a private source — a write-time rule for
`agents/wss-rules-writer.md`, enforced when a row is written rather than when a
tree is adopted. `wss-publish.sh`'s Gate 1 greps the whole tracked tree for
identity needles and catches literal leakage; nothing mechanical checks phrasing.
