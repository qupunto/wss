---
name: adopt
description: "Bring a project under this workflow — map what already exists to the records the skills expect, and write its `.claude/WSS.WORKFLOW.json`. SHORTHAND: `--wss-adopt`. Also trigger on \"set up the workflow here\", \"create the manifest\", \"declare <key> in the manifest\", \"import a records archive\", or when a skill reports falling back to conventional filenames."
---

# Adopting a project

Every skill in this workflow reads `.claude/WSS.WORKFLOW.json`, and only this
skill ever creates one; without
it each skill degrades to conventional filenames and stays there. This skill is
the way out, and the **only** one that runs before the project is under the
contract at all.

**It writes the `permissions.ask` entries of step 5 and nothing else with content
in it.** The manifest itself goes through `manifest-writer`, which is its sole
writer — this skill decides what the values should be and hands them over; the
citation is [step 8's](references/WSS.STEP8-MANIFEST.md). The keys it may ask for
are `WSS.MANIFEST.md`, cited from that same step; what the files those keys
point at may be **called** is `WSS.NAMING.md`, cited from
[step 9](references/WSS.STEP9-CREATE-RECORDS.md); who owns each record afterwards
is [`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md).

**The first two are one pass and two reads.** An adoption settles a key and the
name of the file it resolves to in the same breath, and they are separate
contracts.

## What it is not

**Not a rewrite.** If a manifest already exists this is an *amendment*: read it,
report what it declares, fill only the gaps, and never overwrite a key the
project already chose. **The one exception is a key or filename matching a
previous suite convention** — the pre-rename `.claude/workflow.json`, a flat
`workflow/v1` schema, an old record name. That is stale *machinery*, not a
project's choice, and amending around it builds on the wrong facts. It routes
to the migration procedure — the `update` skill's Job 2 — behind **its own
consent gate**, distinct from amendment's: the plan of mends is shown and OK'd
before anything is corrected, and it is never folded silently into adoption.

**Not a documentation pass.** It creates record files *empty*, with their
heading and nothing else. Content is the owning skill's, always.

**Not a judgement about the project.** It reports what it found and what it could
not resolve, and an unresolvable key is left **out** of the manifest: a missing
key degrades gracefully and says so, while a key pointing at the wrong file
misdirects every skill that reads it, silently.

## 1. Establish which mode you are in

`.claude/WSS.WORKFLOW.json` present → amendment. Absent → adoption. `--lane <name>`
in the request → worktree setup for a declared lane, which skips to its own
section below. Say which in one line before doing anything, because the modes
have different blast radii.

**This skill acts on the session's own working directory and cannot be aimed
elsewhere. That is the design, not a missing flag.** Every path it resolves is
relative — the manifest above, the git revision it stamps — and there is no
`--dir`, deliberately: adoption writes into a tree with the blast radius
`wss-retire-workflow.sh` guards its own `--dir` against, and a wrong target is
unrecoverable. **The consequence, which is the part that gets rediscovered:**
adoption cannot be exercised from a session opened in some *other* project, so
proving it by use means opening a session in the target tree and running it from
there. A session that finds itself planning an adoption run against a directory
it is not in has already hit this, and the answer is to move, not to add a flag.

**Before either verdict, check for a stale-convention tree — it masquerades as
both.** A pre-rename `.claude/workflow.json` (with the current filename absent,
this reads as *adoption* and would write a second manifest over an adopted
project; with both present, as a half-finished migration), or a current
filename holding a flat `workflow/v1` schema (reads as amendment; the doctor
rejects it). Any of these → **migration mode**: dispatch to the `update`
skill's Job 2, whose consent gate and snapshot rule apply, and return here only
for what genuinely was never declared. `wss-doctor.sh` fails on all three shapes
now, so run it when unsure which tree this is.

**Then the wizard's first question, before anything else it does — y/N,
default no: "An archive to restore first?"** A `wss-export-records.sh` export
or a retirement snapshot (`WSS.RETIREMENT-PLAN.tar.gz`) is the machine-change
and re-adoption path back in. No is the default because most adoptions have
no other machine — a plain no closes the subject for the rest of the run. On
yes, take the path and run [step 8b's import](references/WSS.STEP8B-IMPORT.md) **now**, so the restored records
already exist for every later step. `--lane` mode skips the question — a
worktree shares the project's records.

Also pin the tree — `git rev-parse --short HEAD` and `git status --porcelain`.
If the tree is dirty, say so and continue.

## The steps

Read each step's reference file right before doing that step, and follow it in
full — only one mode's chain of steps is ever in play for a given run.

- **2. [Detect the shape](references/WSS.STEP2-SHAPE.md).** Per `WSS.PROJECT-SHAPE.md`,
  report each signal with the evidence that established it.
- **3. [Find what already exists](references/WSS.STEP3-EXISTING.md).** Search, do not
  assume — map every record by content as well as name, and check for a GitHub
  Issues TODO list before calling one absent.
- **4. [Read the commands out of the project's own tooling](references/WSS.STEP4-COMMANDS.md).**
  Never invent a command.
- **5. [Propose `permissions.ask`](references/WSS.STEP5-PERMISSIONS.md).** Only for
  the commands the project actually declares that destroy state.
- **6. [Read the roles out of `.claude/agents/`](references/WSS.STEP6-AGENTS.md).**
  Propose `agents.*` from what exists; leave it out entirely where nothing does.
- **7. [Ask only what cannot be inferred](references/WSS.STEP7-ASK.md).** Batched
  with `AskUserQuestion`, four at a time, recommended option first.
- **8. [Hand the manifest to `manifest-writer`](references/WSS.STEP8-MANIFEST.md).**
  Only keys with real, verified values, plus the `WSS.recordMode` map built in
  the same pass.
- **9. [Create the missing records — empty](references/WSS.STEP9-CREATE-RECORDS.md).**
  Heading and nothing else; the owning skill writes the first real line.
- **9c. [Inherit the rulebook, or take its structure](references/WSS.STEP9C-RULEBOOK.md).**
  Only where the tree carries `wss/rules/`. Step 7 asks; this carries it out.
- **`--lane <name>`. [Set up a worktree for a declared lane](references/WSS.LANE-MODE.md).**
  Reached directly, like amendment — no detection, no search, no questions
  beyond the lane's own two.
- **8b. [Import an archive from another machine](references/WSS.STEP8B-IMPORT.md).**
  Reached from step 1's y/N question above, or whenever the user hands an
  archive over unprompted — always before step 9.
- **10. [Prove it, do not claim it](references/WSS.STEP10-PROVE.md).** Run the
  doctor, stamp the tree, then measure it.
- **11. [Hand an undocumented project to `--wss-docs`](references/WSS.STEP11-DOCS.md).**
  Bound to the scaffold and the overview page.
- **12. [Close out](references/WSS.STEP12-CLOSEOUT.md).** The manifest, the files
  created, the gate, the doctor result, and the cadence card below.

## The cadence card

**It stays in this file rather than moving into step 12's reference, and that is
load-bearing.** `wss-doctor.sh`'s "Cadence tables" check reads the flag column
out of this table by a hardcoded path and compares it against `README.md`'s "How
often" copy — the two are hand-copies of one list with no way to source it once,
so agreement is what gets asserted. A card living behind a reference is a card
the check reads as absent, and an empty-vs-empty comparison passes while an
adopter is handed a cadence missing last week's flag.

Read it out at the end of an adoption. It is a selection, not an inventory — say
`--wss-flags` is what lists every flag, then:

| When | Flag |
|---|---|
| Starting anything non-trivial | `--wss-track` |
| Facing a capability-shaped task | `--wss-scout` |
| Deciding *not* to build something | `--wss-todo` |
| A decision with no task attached | `--wss-log` |
| Settling how the system behaves | `--wss-describe` |
| Settling what the project *is* — stack, data model, a convention | `--wss-reference` |
| Finishing a unit of work, or before `/clear` | `--wss-wrap` |
| Weekly, or after a refactor | `--wss-check` |
| The suite moved under this project, or the doctor names a pre-rename manifest | `--wss-update` |
| Before a release, or when you stop trusting the record | `--wss-full-check` |
| Monthly, or when picking the project back up | `--wss-stocktake` |
| After editing any skill or agent file | `--wss-tidy` then `--wss-catalog` |

**Name the three that pay on day one — `--wss-track`, `--wss-todo`, `--wss-wrap` — and say
the rest pay back over weeks.**
