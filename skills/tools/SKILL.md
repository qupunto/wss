---
name: tools
description: "Owns the project's tooling files — the catalog of skills and agents, the diagram of who invokes whom, the claims inside them, and the prose, token, rot and routing sweeps over them. SHORTHAND: `--wss-tools`. Use whenever a skill or agent file is created, edited or removed, or a stale claim is found in one. Also trigger on \"prune the skills\", \"these files are getting long\"."
---

# Keeping the tooling files honest

Six jobs, all about the files that describe and drive the tooling:

1. **The catalog** — `WSS.record.tooling.catalog` is a human-readable index of every
   skill and agent: what exists and what it is for, so the user can see it at a
   glance without opening every file.
2. **The claims inside those files** — `WSS.record.tooling.sources`. A skill or agent
   file that states something false about the project is worse than one that
   states nothing, and nothing else in the workflow owns them.
3. **The prose prune** — the same files, for text that is verbose and *true*.
   Job 2 deletes claims that have gone false and is silent on everything else;
   Job 3 is the deliberate sweep for prose whose removal changes nothing about
   what Claude does.
4. **The token-economy sweep** — the same files again, for structure that
   costs more context than the job needs: what could be a script, a cheaper
   subagent, a gated reference, a shared method, a cache hit. Job 3 asks
   whether the prose earns its bytes; Job 4 asks whether the *mechanism*
   earns its chain.
5. **The rot-resistance sweep** — the same files once more, for writing that is
   true today and shaped to go false: an uncompared second copy, a file two
   procedures write, a claim no reader can test, a drift nothing would report.
   Job 2 deletes what has already gone false; Job 5 finds what will.
6. **The routing sweep** — the same files for the one property none of the
   others measure: whether a skill is reachable. Jobs 3, 4 and 5 can all make a
   description shorter and none can make one longer, so this is the counterweight
   rather than a fifth way of trimming.

**These are jobs, not steps.** Each has its own trigger, and the numbering is
for reading rather than running — the sweeps never fire as a side effect of an
edit made under another, and each says so. One dependency does bind them, in the
direction the numbering hides: **the catalog describes the tree the run ends
with.** A row and an arrow written before Job 4 extracts a method or Job 5
retires a copy describe a state that no longer exists, so a job that restructures
anything re-opens Job 1 before the run closes.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.tooling.catalog` and
`WSS.record.tooling.sources`. Without a manifest, fall back to `.claude/WSS.TOOLING.md`,
`.claude/skills/*/SKILL.md` and `.claude/agents/*.md`, and say so.

**The declared globs are the scope, and an incomplete one is a finding rather
than a narrowing you inherit.** A manifested project never reaches the fallback
above, so a `sources` list that reaches the skills and not the agents leaves
every agent file unswept while the catalog above still claims to index them.
Before Job 2 or Job 3, check the declared globs against what the tree actually
holds — agent files, and any directory of tooling prose the catalog has a row
for. Where they do not match, say which files fall outside and hand the missing
glob to [`manifest-writer`](../../workflow/writers/WSS.MANIFEST-WRITER.md); do
not sweep undeclared files on your own authority, and do not report the declared
scope as if it were the whole.

Who owns what else is
[`workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md).

## When it triggers

- A skill or agent is created, removed, or has its `description` or purpose
  edited in a way that changes what it does or when it's used.
- **A stale claim is found inside a skill or agent file** — by you, or dispatched
  here by `--wss-check`.

Not needed for internal changes that don't alter purpose, like rewording a
section.

**It does not fire on a file belonging to this suite** — including the very
skill being executed. That is filed and left, per
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).
The working project's own skills and agents are this skill's ordinary business
and are not affected.

## Job 1 — the catalog

1. Add, edit or remove the matching row in `WSS.record.tooling.catalog`.
2. Write the summary in short, human language, one sentence. **Don't copy the
   frontmatter `description` verbatim** — that is written to be read by Claude as
   a trigger condition, not by a human at a glance.
3. If the new skill overlaps an existing one, check that one's row too: its
   summary may now be wrong, especially if it has started delegating.
4. Refresh the interaction diagram below if what you changed moved an arrow.
5. No confirmation needed. This is low-risk internal documentation.

### Hand it to `docs-writer` — do not write into the site

Where the project has a documentation site, its annex should carry a **Claude
tooling** page: a catalog is an exhaustive per-item reference over an enumerable
set, which is what an annex is for.

**You do not write that page.** After updating `WSS.record.tooling.catalog`, hand
the catalog over as the source to
[`docs-writer`](../../workflow/writers/WSS.DOCS-WRITER.md), which adapts it into
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

## Scope, when this runs as a sweep

Fired by a specific change — a skill edited, a finding dispatched here — the scope
*is* that change and there is nothing to resolve. Fired as a sweep over every file
in `WSS.record.tooling.sources`, ask `sweep-tracker` to resolve the entry `tooling`
first. One scope, `claims`, covering the files whose contents were actually read.

**A file swept clean once stays clean as the project moves, and that is not an
assumption — it is what Job 2 enforces.**

So re-read a tooling file when **the file itself changed** since the baseline, or
when it was left `not-covered`. Two things void that:

- **A file the previous run corrected rather than deleted.** If you cannot tell
  from the checkpoint, re-read it. One corrected count is enough to break the
  argument above for that file.
- **Dangling pointers**, which do go stale without the file changing. Cheap to
  check and not worth narrowing: run the suite's `wss-doctor.sh` every time.

## Job 2 — stale claims inside the tooling files

**The procedure is [`workflow/checks/WSS.TOOLING-CLAIMS.md`](../../workflow/checks/WSS.TOOLING-CLAIMS.md).**
This skill is what enforces it; `--wss-full-check` runs the same method over every
file in `WSS.record.tooling.sources`.

In one line, because it overrides the instinct to be helpful: *delete the mutable
claim rather than correcting it.* The rule itself is
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule).

**A contract file inside `sources` is subject to that rule like any other file
there**, and this is worth stating because it reads as surprising. Where the
declared globs reach the `workflow/*.md` contracts, a count, a "currently", or a
claim about what does not yet exist in `WSS.OWNERSHIP.md` or `WSS.MANIFEST.md`
is deleted rather than corrected, exactly as in a skill file. The rule carries no
exemption for them, and
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#the-matrix) already places
the contracts outside the record matrix as ordinary work constrained by review —
this sweep is that review, not an exception to it. What the sweep never touches
is the *rules* those files state: a rule is not a claim about state, and
deleting one because it reads as absolute is the failure mode to watch for here
and nowhere else in `sources`.

**What the method deliberately leaves to this skill**, because scope,
disposition and authorization are a runner's and a method that carried them
could not be borrowed by the next caller:

- **Say what you removed and why**, in the commit — `git-writer` writes it under
  this flag's commit-only grant, but the message is yours to supply. It is the
  only audit trail a markdown file has.
- **After a sweep, hand `sweep-tracker` the baseline and the files you actually
  read.** List a file you deleted a claim from under `covered`, and a file you
  corrected one in under `not-covered` — the narrowing only holds where the
  mutable claim is gone rather than restated.
- **When `--wss-check` dispatches a finding here, re-verify before deleting.** A
  deletion is not recoverable from the file itself, which makes the second look
  in [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing)
  especially load-bearing at this end.

## Job 3 — the prose prune

Run deliberately — on the trigger phrases, or when `--wss-full-check` orders it —
never as a side effect of a Job 1/2 edit.

**The method is [`workflow/checks/WSS.PROSE-PRUNE.md`](../../workflow/checks/WSS.PROSE-PRUNE.md)**
— the keep test, what passes it, what is never cut, and propose-first,
measure-second. This skill is its standalone runner, exactly
as Job 2 runs its own method file.

What the method leaves to the runner:

- **Where relocated reasoning goes** — durable reasoning to
  `WSS.record.decisions` through `--wss-log`, or into the commit message.
- **Say what you cut and why, in the commit**, as with Job 2's deletions.

**Scope and stamping**: resolve through `sweep-tracker`, entry `prune`, one
scope `prose` — separate from Job 2's `tooling` entry, because the two sweeps
answer different questions about the same files. A file whose candidates were
refused or deferred is `not-covered`; only one whose candidates were all cut or
judged lean is `covered`. **Take the baseline after the cuts land, not
before** — the entry voids for any file edited since its baseline, and the
cuts are themselves edits, so an early baseline voids the whole entry.

## Job 4 — the token-economy sweep

Run deliberately — on the owner's ask, or when an audit pass recommends it —
never as a side effect of a Job 1/2/3 edit.

**The method is
[`workflow/checks/WSS.TOKEN-ECONOMY.md`](../../workflow/checks/WSS.TOKEN-ECONOMY.md)**
— the lenses, each with a proven in-tree example and the drawback it must
outweigh, and the gate that every application is proposed before anything
structural moves. This skill is its standalone runner, exactly as Jobs 2 and 3
run their own method files. The measurements come from `wss-audit-assets.sh`
where the lens needs numbers; run it rather than re-deriving sizes by hand.

What the method leaves to the runner:

- **Scope and stamping**: resolve through `sweep-tracker`, entry `token`, one
  scope — separate from `tooling` and `prune`, because it answers a different
  question about the same files — over the `WSS.record.tooling.sources` globs
  plus the root and asset scripts the catalog rows name. A file is due when it
  changed since the baseline, was left `not-covered`, or **when the method file
  itself changed since the baseline** — a new lens re-opens every file. Take
  the baseline after the changes land, as Job 3 does.
- **Dispositions**: a bounded fix lands in the run; anything structural goes
  to `--wss-todo` with the estimated saving *and* the drawback stated; a
  ruling either way — including "the overlap stays, here is why" — goes
  through `--wss-log`. `covered` only where nothing is pending.
- **Say what you changed and what it saves, in the commit**, as with Jobs 2
  and 3.

## Job 5 — the rot-resistance sweep

Run deliberately — on the owner's ask, when an audit pass recommends it, or when
a Job 2 finding turns out to be the second instance of the same shape, which is
the signal that the structure rather than the text is what is wrong. Never as a
side effect of a Job 1/2/3/4 edit.

**The method is
[`workflow/checks/WSS.ROT-RESISTANCE.md`](../../workflow/checks/WSS.ROT-RESISTANCE.md)**
— the lenses, each with a proven in-tree example and the drawback it must
outweigh, and what is deliberately not a hit. This skill is its standalone
runner, exactly as Jobs 2, 3 and 4 run their own method files.

What the method leaves to the runner:

- **Scope and stamping**: resolve through `sweep-tracker`, entry `rot`, one
  scope — separate from `tooling`, `prune` and `token`, because it answers a
  different question about the same files. A file is due when it changed since
  the baseline, was left `not-covered`, or **when the method file itself changed
  since the baseline** — a new lens re-opens every file. Take the baseline after
  the changes land, as Jobs 3 and 4 do.
- **Dispositions**: a bounded fix lands in the run; anything that moves a rule
  between files, retires a copy or adds a detector is proposed first, and goes
  to `--wss-todo` if it is not taken. **A drawback weighed and accepted is a
  ruling like any other** — it goes through `--wss-log` with the trigger that
  would reverse it, or the next run re-argues it and the lens becomes a tax.
  `covered` only where nothing is pending.
- **A finding against a file this suite owns is filed, not fixed**, the same as
  everywhere else — see
  [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).
- **Say what you changed and what it stops diverging, in the commit**, as with
  Jobs 2, 3 and 4.

## Job 6 — the routing sweep

Run deliberately — on the owner's ask, when an audit pass recommends it, and
**after any run of Job 3, 4 or 5 that shortened a `description`**, which is the
one trigger the other jobs create rather than an owner. Never as a side effect
of a Job 1/2 edit.

**The method is
[`workflow/checks/WSS.ROUTING-HEALTH.md`](../../workflow/checks/WSS.ROUTING-HEALTH.md)**
— the lenses, what is not a finding, and the asymmetric gate that makes this the
only sweep here able to argue a description *longer*. This skill is its
standalone runner, as Jobs 2 through 5 are theirs.

What the method leaves to the runner:

- **Scope and stamping**: resolve through `sweep-tracker`, entry `routing`, one
  scope. A file is due when it changed since the baseline, was left
  `not-covered`, or when the method file itself changed since the baseline.
  **A `description` change makes a file due, and so does a body edit** — the
  latter since lenses 8 and 9, which read citations in and route claims out, fire
  on files carrying no frontmatter at all. Depth is the method's applicability
  table, not this scope: a file due for the body-only row is a search for those
  two, never a full read.
- **What the doctor already checks is not re-derived by reading**: the
  advertised-shorthand lens, and the *structural* half of the
  fires-on-conversation lens — a one-word trigger, or a phrase observed to
  misfire. Run
  `wss-doctor.sh` and read its verdict. **Its other half is yours**: whether a
  trigger's casualness matches the action's reversibility is judgment no script
  makes, and skipping it is how a committing skill keeps a remark for a door.
- **Dispositions**: a wording fix lands in the run. **Anything that ends an
  overlap rather than describing it is a proposal, never an edit** — it moves a
  job between two skills, which is two owners' surface. A description grown past
  the budget is a ruling: it goes through `--wss-log` with the misroute it buys
  off, or the next budget warning quietly reverses it.
- **Say what you changed and what it now catches, in the commit**, as with Jobs
  2 through 5.

## What this skill does not do

It does not write any other record. If the change resolves or creates a tooling
task, that belongs in `WSS.record.todo` and its reasoning in `WSS.record.decisions` —
both `--wss-todo`'s, so hand it over rather than editing them here.
