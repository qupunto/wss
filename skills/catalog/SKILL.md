---
name: catalog
description: "Owns the tooling catalog — `WSS.record.tooling.catalog` — a human-readable index of every skill and agent, what each is for, and who invokes whom. SHORTHAND: `--wss-catalog`. Use whenever a skill or agent is created, edited or removed, or after `--wss-tidy` edits anything. Also on \"update the tooling catalog\", \"who invokes whom\", \"add this skill to the catalog\"."
---

# The tooling catalog

One job: keep `WSS.record.tooling.catalog` — a human-readable index of every
skill and agent, what each is for, and the diagram of who invokes whom — true
of the tree the run ends with.

**The cross-skill contract with `--wss-tidy`.** `wss-tools-inventory.sh` is the
discovery step neither skill skips. Before this skill renders or edits
anything, run `bash wss/scripts/wss-tools-inventory.sh` (no `--root` flag) to regenerate
`.claude/WSS.TOOLS.json` — `WSS.record.tooling.inventory` — so the catalog
describes what is actually on disk rather than what the last run left behind.
`--wss-tidy` runs the same script and then invokes this skill after any edit
that restructures a file, for the same reason from the other side: a row or an
arrow written before a Job 3, 4 or 5 edit lands describes a tree that no longer
exists.

**Every skill, agent, script and hook entry in `.claude/WSS.TOOLS.json` needs a
matching row here, and every catalog row of those four kinds needs a matching
entry there.** `wss-doctor.sh` verifies that pairing on every run (not
`--check`, which is `wss-tools-inventory.sh`'s flag, not this script's) — keep
it true rather than letting either side drift. A contract, reference or writer
entry has no comparable catalog row to check by design; see the doctor's own
"Catalog rows vs tools inventory" section for exactly which kinds are covered
and why the rest are out of its reach.

**It does not fire on a file belonging to this suite** — including the very
skill being executed. That is filed and left, per
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).
The working project's own skills and agents are this skill's ordinary business
and are not affected.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.tooling.catalog`
(what this skill writes) and `WSS.record.tooling.inventory` — `.claude/WSS.TOOLS.json`
(what the script writes and this skill reads for the numbers it must not repeat).
Without a manifest, fall back to `.claude/WSS.TOOLING.md`, `.claude/skills/*/SKILL.md`
and `.claude/agents/*.md`, and say so.

Who owns what else is
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md).

## When it triggers

- A skill or agent is created, removed, or has its `description` or purpose
  edited in a way that changes what it does or when it's used.
- After `--wss-tidy` edits anything — the re-open half of the contract above.

Not needed for internal changes that don't alter purpose, like rewording a
section.

## The catalog

1. Run `bash wss/scripts/wss-tools-inventory.sh` first (see the contract above).
2. Add, edit or remove the matching row in `WSS.record.tooling.catalog`.
3. Write the summary in short, human language, one sentence. **Don't copy the
   frontmatter `description` verbatim** — that is written to be read by Claude as
   a trigger condition, not by a human at a glance.
4. **No numbers.** Byte sizes, counts, chain totals live in
   `.claude/WSS.TOOLS.json` — a row points at the entry rather than repeating
   its measurements.
5. If the new skill overlaps an existing one, check that one's row too: its
   summary may now be wrong, especially if it has started delegating.
6. Refresh the interaction diagram below if what you changed moved an arrow.
7. Commit through `git-writer` under this flag's commit-only grant; say what
   changed in the message. No confirmation needed beyond that — this is
   low-risk internal documentation.

### Hand it to `docs-writer` — do not write into the site

Where the project has a documentation site, its annex should carry a **Claude
tooling** page: a catalog is an exhaustive per-item reference over an enumerable
set, which is what an annex is for.

**You do not write that page.** After updating `WSS.record.tooling.catalog`, hand
the catalog over as the source to
[`docs-writer`](../../wss/workflow/writers/WSS.DOCS-WRITER.md), which adapts it into
the site's annex in the site's own conventions and owns everything under `docs/` —
the page, its index row, its sidebar entry.

**Go to the writer, not to `--wss-docs`.** Re-deriving a page that already exists
decides nothing — the tier was settled when the page was created — and routing it
through the whole skill buys only the cost of loading it. `--wss-docs` is for the
one case that *is* a decision: the **Claude tooling** page does not exist yet and
its placement has to be chosen.

**The derived copy is only as current as the handoff**, so making it is part of
this procedure rather than a courtesy — and where the catalog moved but the site
did not, that is a finding for `--wss-check`, not something to fix by editing the
page.

**The handoff goes out once, from the catalog the run ends with.** Where a later
job restructures a file, handing over at the moment the row was first written
publishes an intermediate state and pays the derivation twice — and the second
payment is a page rewrite, which is the expensive end.

Where the project has no documentation site, there is no second file and nothing
to hand over.

### The interaction diagram

The catalog carries a diagram of how the tooling fits together, because the rows
describe each skill alone and **the thing a newcomer cannot reconstruct from any
single file is who invokes whom.**

**Draw it yourself.**

Three rules apply, and **the authority on them is the docs style guide**
(`skills/docs/references/WSS.STYLE-GUIDE.md`, its Diagrams section): check
what will render it before choosing a form, draw every box and arrow only from
files actually read, and stop before it stops being readable.

The diagram travels with the catalog when it goes to `docs-writer`, which
re-renders it for the site's own renderer under the same rules, keeping every box
and arrow it asserted.

## What this skill does not do

It does not run the sweeps and it does not edit the `WSS.record.tooling.sources`
files — those are `--wss-tidy`'s, and the contract above is how the two meet. It
does not write `.claude/WSS.TOOLS.json`: that record is
`wss-tools-inventory.sh`'s, which this skill triggers and never edits by hand.
And it writes no other record — a tooling task belongs in `WSS.record.todo` and
its reasoning in `WSS.record.decisions`, both `--wss-todo`'s, so hand them over
rather than editing them here.
