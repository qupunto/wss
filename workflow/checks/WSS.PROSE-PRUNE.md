# The prose prune

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What counts as
cuttable prose in a skill, agent or tooling file: text that is verbose and
*true*. The claims check deletes what has gone false and is silent on
everything else; this method is the deliberate sweep for prose whose removal
changes nothing about what Claude does.

It lives here so any orchestrator can borrow it; `--wss-tools` remains its
standalone runner and keeps the runner's share — scope, stamping, and where
relocated reasoning goes.

## The test

**A line stays if removing it would change what Claude does.** Apply it
literally, paragraph by paragraph. Three things pass:

- **Behaviour** — a rule, threshold, ordering, boundary, path, command, or the
  name of a file or skill to hand something to.
- **Defence of a counterintuitive rule** — kept as **one clause**, not a
  paragraph and not a story, because a rule that looks wrong gets reverted by
  the next session unless the why survives. The clause is the **mechanism**,
  never the incident: "it has happened here" is history, not defence, however
  recent the scar.
- **Routing** — the frontmatter `description`, the most expensive text here and
  the one whose removal breaks the file outright.

Everything else is a candidate: the second illustration, the history of how a
rule was arrived at, the reassurance, the restatement. **Nothing is destroyed,
only relocated** — durable reasoning moves to the decision log or the commit
message; where it lands is the runner's call.

## What is never cut

Five hazards, each failing silently:

- **A heading another file cites by name** — the citation resolves to nothing
  while reading as live. Run the suite's `wss-doctor.sh` before proposing and
  after cutting.
- **The last statement of a rule.** Confirm a restatement is genuinely stated
  elsewhere and say where; zero copies is a behaviour change disguised as
  tidying.
- **A link to a `workflow/*.md` authority.**
- **Text inside a fenced block** — executed or copied verbatim.
- **An agent file's `tools:` list and frontmatter `description`** — narrowing a
  description shows up as the agent never being chosen, never as an error. A
  description you touch gets shorter or stays the same, never longer.

## How to cut

**Propose first, cut second — the second look survives the merge.** Classify
every paragraph and collect the candidates *before* touching anything, then
re-check each against the hazards as a separate pass; a proposed cut is a
hypothesis, and skipping the re-check turns the prune into a generator of
plausible deletions.

**Measure** — bytes before, bytes proposed, share of the file; a cut worth less
than a percent or two is not worth the churn. **A file already lean is a
finding** — say so rather than proposing marginal cuts to justify the run.
