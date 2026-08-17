# The prose prune

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What counts as
cuttable prose in a skill, agent, tooling file or record: text that is verbose
and *true*. The claims check deletes what has gone false and is silent on
everything else; this method is the deliberate sweep for prose whose removal
changes nothing about what Claude does.

**Which files a run opens is the runner's**, per `WSS.CHECKS.md` — a record is
in scope for this method the same way a skill is, and neither is swept because
this file said so.

It lives here so any orchestrator can borrow it; `--wss-tidy` remains its
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

## A second axis: why-sentences move to the log, not to deletion

One shape of candidate gets a fixed destination instead of a runner's choice:
a sentence that explains **why** a step exists, the step itself already stated
nearby. It moves to the decision log rather than being cut with the rest.

**The test:** strip the sentence and ask whether an executor who has never
seen this file would act differently on the very next run. No change → the
sentence only re-justifies a step nobody would do differently without it, and
it moves. Would change → it is behaviour, the test above already keeps it —
this includes the **defence of a counterintuitive rule** two bullets up, which
also explains but stays in the body because cutting it reverts the rule.

**Worked pair:**

- **Goes** — "Run the sweep before the release, because that is the moment the
  drift is cheapest to fix." Stripped of the because-clause, the executor still
  runs it before the release; the ordering was already an instruction, and the
  reason only re-justified it. **Written out rather than cited**, because a
  worked example that points at a live line makes the method depend on that
  line staying wrong — cutting it, as the method says to, would break the
  citation that justified the cut.
- **Stays** — [`skills/lane-record-sync/references/WSS.STEP2-CONFLICTS.md:15`](../../skills/lane-record-sync/references/WSS.STEP2-CONFLICTS.md):
  "…legitimate here because the user just ruled, which is the one condition
  [`WSS.LANE-CONTRACT.md`](../workflow/WSS.LANE-CONTRACT.md)'s `[critical → why]`
  section puts on the marker." Reads as a because-clause but *is* the gating
  condition — strip it and the marker gets applied somewhere the contract
  forbids. A boundary stated as a reason is still a boundary.

**The handoff — the sweep never writes the log itself.** `wss/logs/WSS.DECISIONS.md`
is `recordMode: log`; `wss-append-only.sh` fails any commit deleting a line
from it, and `--wss-log` is its route to `record`, the sole writer
([`wss/workflow/WSS.OWNERSHIP.md`](../workflow/WSS.OWNERSHIP.md)). So: the sweep proposes
the sentence, its `file:line` and the step it justified, same as any candidate
under "How to cut"; `--wss-log` writes the entry; only then does the body edit
land, why-clause gone, the step's own statement untouched. A body edit before
the entry exists has discarded the reasoning instead of relocating it.

**What the original site keeps: nothing.** Per
[`wss/workflow/WSS.RECORD-CONTRACT.md`, "A concept is stated once"](../workflow/WSS.RECORD-CONTRACT.md),
a second site holds only a pointer, a derived copy, or a listed exception —
never a hand-restatement. The why-sentence is not the rule; the rule stays,
stated once, in the body, and the reasoning is now stated once, in the log.
Zero copies left behind is correct, not a gap — a "see decision log" gloss
written back into the body would itself be the hand-copy that section forbids.

## What is never cut

Each of these fails silently:

- **A heading another file cites by name** — the citation resolves to nothing
  while reading as live. Run the suite's `wss-doctor.sh` before proposing and
  after cutting.
- **The last statement of a rule.** Confirm a restatement is genuinely stated
  elsewhere and say where; zero copies is a behaviour change disguised as
  tidying.
- **A link to a `wss/workflow/*.md` authority.**
- **Text inside a fenced block** — executed or copied verbatim.
- **An agent file's `tools:` list and frontmatter `description`** — narrowing a
  description shows up as the agent never being chosen, never as an error. A
  description you touch gets shorter or stays the same, never longer.

### In a record

The test above is unchanged — a line stays if removing it would change what
Claude does. What changes is which text a record makes *look* cuttable, so these
are stated as hazards rather than left to be rediscovered:

- **Anything below the first `##` heading of a `recordMode: log` file.** Only
  the header above it describes the record now and is rewritten in place;
  everything under it is an entry, correct as written, and `wss-append-only.sh`
  refuses the commit either way — as a pre-commit hook and again in CI. Proposing
  a cut there spends a reading pass on text no commit can carry.
- **A TODO list, roadmap or release entry.** It reads as prose and is a
  commitment; cutting one silently drops work. Hand it to the skill that owns
  the record instead — the prune has no disposition of its own here.
- **A handoff card's hazard block.** It is loaded at session start and is the
  only thing standing between a fresh session and whatever it warns about. Long
  narrative prose is what a hazard has to be to survive contact with a reader
  who has not hit it yet, so length is not evidence against it.
- **A record that is also a published surface**, `WSS.record.reference` most
  often. A cut lands in two places at once, and only one of them is reviewed
  here.

**Where the record's own history lives, a why-sentence has nowhere to move.**
The handoff above says relocation goes to the decision log — but a decision
log's own header cannot relocate into itself. In a record that *is* the
destination, a why-sentence is either behaviour (it stays) or it is deleted
outright, and deleting it needs the same second look as any other cut with no
relocation target.

## How to cut

**Propose first, cut second — the second look survives the merge.** Classify
every paragraph and collect the candidates *before* touching anything, then
re-check each against the hazards as a separate pass; a proposed cut is a
hypothesis, and skipping the re-check turns the prune into a generator of
plausible deletions.

**Measure** — bytes before, bytes proposed, share of the file; a cut worth less
than a percent or two is not worth the churn. **A file already lean is a
finding** — say so rather than proposing marginal cuts to justify the run.
