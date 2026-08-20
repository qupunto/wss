---
name: health-check
description: "Health-check the project: mechanical floor, then every declared record and tooling file, for drift and staleness. Checkpoint-narrowed, fixes dispatched. `--shallow` reports only; `--deep` ignores checkpoints, ask-gates a TODO resort; `--publish` covers the shipping set pre-release. SHORTHAND: `--wss-health-check`. Also on \"check everything\", \"take stock\"."
---

# Health-checking the project

**One skill, four mutually exclusive modes**, where `wss-check`, `wss-full-check`,
`wss-stocktake`, `wss-tidy` and `wss-preflight` used to be five — each ran a
fragment of the same read-then-settle-then-dispatch pipeline over an overlapping
file set, so running two of them against one request paid twice for the same
answers. The ruling is the decision log's `2026-08-19 (eighty-second)` entry.

| Invocation | Scope | Depth | What it is |
|---|---|---|---|
| `--shallow` | everything declared | checkpoint-narrowed | the check only: read, verify, report, apply nothing |
| *(default)* | everything declared | checkpoint-narrowed | check, then dispatch and apply fixes |
| `--deep` | everything declared | every checkpoint ignored | trust-nothing pass, TODO resort included (ask-gated) |
| `--publish` | the shipping set only | every checkpoint ignored | publish gates in the floor, fixes to shipping files, hand-off names the release invocation |

**It dispatches; it does not write a record itself.** Every record finding goes
to the skill that owns that file, per
[`WSS.FINDING-DISPATCH.md`](../../wss/workflow/WSS.FINDING-DISPATCH.md), which
re-verifies and writes under its own rules. A finding in a file with no owner in
the matrix — a script, CI config, harness setting, a `wss/workflow/*.md`
contract, or one of the tooling files this skill now sweeps directly — is
disposed of here, per §4. Who owns what is
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md); what each record holds
is [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md).

**Project facts come from `.claude/WSS.WORKFLOW.json`**: every `WSS.record.*`
key (the worklist — iterate it, do not carry a second list here),
`WSS.record.tooling.sources` and `WSS.record.tooling.catalog`,
`WSS.commands.typecheck`, `WSS.commands.test`, `WSS.commands.testConsentEnv`,
`WSS.commands.indexRegen`, `WSS.commands.indexCheck`, `WSS.commands.ci`,
`WSS.agents.audit`, `WSS.audit.dimensions`, `WSS.audit.invalidates`,
`WSS.gate.coverage` and `WSS.branch.publish`. Without a manifest, fall back to
each key's fallback in [`WSS.MANIFEST.md`](../../wss/workflow/WSS.MANIFEST.md)
and say which fallbacks were used. Where `.claude/WSS.LANE` names a lane,
`WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for the splittable
keys — [`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md)'s
resolution rule.

## The `--wss-health-check` shorthand

Where a flag counts is [`README.md`](../../README.md); what it authorizes is the
block `wss-shorthand-flags.sh` injects and
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md)'s matrix. Bare or
`--shallow`, invoking without confirmation is safe — a read is reversible by
construction. `--deep` and `--publish` are heavier; say roughly how much there
is before spending it, same as the retired `--wss-full-check` did.

## Procedure

### 0. Scope, from the mode

**`--shallow` and the default** resolve scope through `sweep-tracker`, one entry
per lens (§2), exactly as
[`WSS.SWEEP-CHECKPOINT.md`](../../wss/workflow/WSS.SWEEP-CHECKPOINT.md#reading-a-checkpoint)
states the procedure — the union of what changed since each entry's baseline,
everything left `not-covered`, and everything never swept. The file set is
**everything the manifest declares**: every `WSS.record.*` key,
`WSS.record.tooling.sources`, and the docs site.

**`--deep`** widens to the same file set with every checkpoint ignored — full
scope, the shape a fresh clone would sweep.

**`--publish`** narrows the file set instead of widening it — see "The shipping
set" below — and ignores every checkpoint over that narrower set regardless of
mode: a file about to ship gets read fresh every time this mode runs, because
"unchanged since last verified" is not the promise a release needs.

**What voids a record's narrowing**, carried over from the retired `wss-check`
— [`WSS.SWEEP-CHECKPOINT.md`](../../wss/workflow/WSS.SWEEP-CHECKPOINT.md#reading-a-checkpoint)'s
step 3 leaves this to the runner and does not state it itself:

| Changed since the baseline | Puts back in full scope |
|---|---|
| the record file itself | that record — a hand edit is exactly what nothing else verifies |
| `.claude/WSS.WORKFLOW.json` | **every** record; a remapped key means the previous run checked a different file |
| a schema, its migrations, or anything defining the shape of stored data | `WSS.record.reference`, and `WSS.record.behaviour` |
| routes, services, domain logic | `WSS.record.behaviour` |
| container, deployment or proxy config, operational scripts, a stated convention | `WSS.record.reference` |
| block scope, order or dependencies | `WSS.record.roadmap` |
| a milestone's scope, its intended version, or which goals it comprises | `WSS.record.releases` |

**What voids a tooling file's narrowing**, carried over from the retired
`wss-tidy`: a file the previous run *corrected* rather than deleted a claim
from stays due even if unchanged since, because one corrected count does not
prove the next one is not also wrong; and **the method file itself changing
re-opens every file under that lens** — a new lens version invalidates
everything it was never checked against. Dangling pointers go stale without
the file changing at all, which is cheap enough not to narrow: run
`wss-doctor.sh` every time regardless of scope.

**The docs site has no equivalent table.** Nothing in the retired five ever
incrementally narrowed it — `docs`'s audit mode always read the whole
site, and `wss-full-check` stamped a `docs` checkpoint entry nobody read back.
Narrowing it here by the generic diff-based procedure alone, with no
lens-specific blast radius, is new behaviour this build introduces rather than
transplants — flagged so a first false-clean (a page describing a renamed flag
whose own file did not change) is recognised as this gap rather than a defect
in the checkpoint mechanism.

State the resolved scope in three or four lines before spending anything: what
is in scope, whether checkpoints are live or ignored, and roughly how much
there is.

### 1. Pin, then the mechanical floor

`git rev-parse --short HEAD` and `git status --porcelain`; dirty paths are
audited as they stand and recorded `not-covered`. Then
[`WSS.MECHANICAL-GAUNTLET.md`](../../wss/tests/WSS.MECHANICAL-GAUNTLET.md) —
doctor, `WSS.commands.typecheck`, the full suite gated on the consent budget, CI
on the audited sha. Nothing in §2 proceeds until it is green; an edit landing
while the doctor is broken compounds a failure nobody can see.

**`--publish` adds the publish gates.** Run
`wss-publish.sh` against a scratch directory
— never `--accept-ship-lock` here, since a delta from
[`WSS.SHIP-LOCK.txt`](../../wss/scripts/WSS.SHIP-LOCK.txt) is a finding for the
user to accept deliberately, not something this run regenerates in passing —
and fold its four gates into this step's verdict. **Where the tree carries
neither file** — the ordinary case away from this suite's own repository, since
**`wss-publish.sh` is deliberately never linked from here.** It removes itself
from every assembly it makes, so a link would resolve in this repository and
dangle in every tree that receives this skill — the exact failure Gate 3 exists
to catch, and it caught it. It is a private-to-public assembly bespoke to this project and is
itself stripped from what it assembles — say so and skip the publish gates
rather than inventing an equivalent; the mechanical floor still runs.

### 2. Read fan-out, over the resolved file set

One [`wss-survey`](../../agents/wss-survey.md) shard per **file**, not per lens
— every shard carries every lens that applies to what it holds, because
sharding by lens re-reads the same tree once per lens and the file reads
already dominate. Four to six shards, one message, Sonnet tier: three of the
lenses below are judgment by their own methods' account, and a cheaper tier's
false cut has no detector. Each shard matches
[the dispatch ladder's](../../wss/workflow/WSS.DISPATCH-LADDER.md) Survey rung;
name the rung and key per its `## Citing a rung`.

The seven lenses, each a method file rather than a paragraph here:

| Reads | Method |
|---|---|
| every declared record | [`WSS.RECORD-DRIFT.md`](../../wss/tests/WSS.RECORD-DRIFT.md) |
| the docs site | [`WSS.DOCS-AUDIT.md`](../../wss/tests/WSS.DOCS-AUDIT.md) |
| `WSS.record.tooling.sources` | [`WSS.TOOLING-CLAIMS.md`](../../wss/tests/WSS.TOOLING-CLAIMS.md), [`WSS.PROSE-PRUNE.md`](../../wss/tests/WSS.PROSE-PRUNE.md), [`WSS.TOKEN-ECONOMY.md`](../../wss/tests/WSS.TOKEN-ECONOMY.md), [`WSS.ROT-RESISTANCE.md`](../../wss/tests/WSS.ROT-RESISTANCE.md), [`WSS.ROUTING-HEALTH.md`](../../wss/tests/WSS.ROUTING-HEALTH.md) |

`WSS.RECORD-DRIFT.md`'s check 1 is never incremental — run it in full over every
record every time, per its own rule, and write `covered: []` for that scope
regardless of mode.

Run `wss-duplication.sh --scope all` before dispatching and hand its output to
the shards: repeated paragraphs and mutable-claim candidates are deterministic
and cost no model tokens, and a shard asked to find what a regex already found
is paying for arithmetic.

Where `WSS.record.todo` names a provider, it is out of this fan-out's reach —
record `not-covered` and say why, per
[`providers/WSS.GITHUB-ISSUES.md`](../../wss/workflow/providers/WSS.GITHUB-ISSUES.md#what-the-sweeps-do-with-it);
never read a local file in its place.

Each shard returns findings as `file:line` with a lens tag and `candidate cut`
never `cut`, plus **the list of files it actually opened** — §9's coverage is
built from that list, never from the plan.

### 3. Settle

[`WSS.SETTLE.md`](../../wss/tests/WSS.SETTLE.md) — re-verify every candidate at
its cited line, settle every negative claim with the grep that would disprove
it, dedup across shards. **This step also authorizes a prune cut**, so its
last-statement variant applies: grep the whole of `WSS.record.tooling.sources`
for a rule's last statement before any cut lands.

**`--shallow` stops here.** A clean settle — nothing survived — goes straight to
§9's stamp and §10's hand-off; nothing below applies anything.

A settle that still holds findings **does not stamp**, and does not simply end:
ask whether to run the default scope now, handing over what was just settled.
**On yes**, continue at §4 — the survey and the settle do not run twice. **On
no**, hand off per §10, reporting the findings and that nothing was stamped, so
they stay in every future run's scope until someone acts. The ruling is the
decision log's `(eighty-fourth)` entry.

### 4. Dispatch and apply — default, `--deep`, `--publish`

[`WSS.FINDING-DISPATCH.md`](../../wss/workflow/WSS.FINDING-DISPATCH.md) resolves
the owner for every record finding; hand it the evidence, not a verdict, and
expect some findings to come back not reproduced — that second look is the
point, not overhead.

**A `WSS.record.tooling.sources` finding is not dispatched to a separate
skill** — stale claim, prune candidate, token-economy or rot-resistance hit,
routing miss. This skill runs those lenses itself now, so it disposes of them
itself, the same split `wss-preflight` used: a bounded fix lands now; anything
structural goes to `--wss-todo` with the estimated saving and the drawback,
except a confirmed duplicate, which is extracted rather than filed; a ruling —
including "the overlap stays, here is why" — goes through `--wss-log`; a prune
cut lands only after its why-sentence reaches the decision log, never before.

**A finding against a file this suite owns — including one this run is itself
reading — is filed and left**, never fixed, per
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).

**A record with no owner in the matrix is a gap to surface, not to fill.** A
script, CI workflow, harness setting or `wss/workflow/*.md` contract with no
owner is ordinary work instead: edit it directly and say what changed. That is
the same rule from `--wss-check`'s and `--wss-full-check`'s two sides at once,
and neither reading licenses writing a record nobody owns.

**`--publish` disposes only within the shipping set.** A finding outside it —
reachable because the mode still runs the mechanical floor's checkpoint state
over the whole declared scope — is reported, not fixed: fixing it belongs to
the default mode, and mixing the two blurs which commit a release actually
gates on.

### 5. TODO resort — `--deep` only, ask-gated

Ask the question the retired `wss-stocktake` opened with: run the dimension
fan-out and rebuild `WSS.record.todo` around where the project actually stands?
Default no — it is *position*, not *state*, and roughly doubles the run.

**Taken**, run in order, after this run's own §4 dispositions have filed to the
TODO list — never before, or the resort rebuilds a list this run then
invalidates:
[`WSS.PHASE0-SCOPE.md`](../../wss/tests/WSS.PHASE0-SCOPE.md),
[`WSS.PHASE1-FAN-OUT.md`](../../wss/tests/WSS.PHASE1-FAN-OUT.md),
[`WSS.PHASE2-VERIFY.md`](../../wss/tests/WSS.PHASE2-VERIFY.md),
[`WSS.PHASE3-REVIEW.md`](../../wss/tests/WSS.PHASE3-REVIEW.md),
[`WSS.PHASE4-REBUILD.md`](../../wss/tests/WSS.PHASE4-REBUILD.md),
[`WSS.PHASE5-CLOSE-OUT.md`](../../wss/tests/WSS.PHASE5-CLOSE-OUT.md). Phase 2
runs its own mechanical-gauntlet pass regardless of §1 already having proved the
tree green — the phase's own method, not repeated here.

**Not taken**, skip to §6.

### 6. Regenerate derived artifacts

`bash wss/scripts/wss-tools-inventory.sh`, then `WSS.commands.indexRegen`, then
`--wss-catalog` for anything this run created, renamed, retired or changed the
purpose of — after the edits, always, because a catalog rendered before the
restructuring describes a tree that no longer exists.

### 7. Re-verify, no carry-forward

The gauntlet again, unconditionally —
[`WSS.MECHANICAL-GAUNTLET.md`](../../wss/tests/WSS.MECHANICAL-GAUNTLET.md)'s
carry-forward was licensed by the tree §1 found, and every step since has had
the chance to edit it. `--publish` re-runs its publish gates here too, against
the tree these edits actually leave.

### 8. Commit, by concept

Through `git-writer`, grouped so one commit does not span the settle's repairs,
the prune, and the regeneration — a hundred files in one commit defeats the
reading a later pass performs, and it runs the append-only hook once per
concept rather than once for everything. Every record write goes out through
its own owner's commit, not this one.

### 9. Stamp

Hand `sweep-tracker` one entry per lens — `record`, `docs`, `tooling`, `prune`,
`token`, `rot`, `routing` — plus `health` for the run as a whole, built only
from what the shards actually reported opening, never from the plan.

**The stamp asserts health, not coverage.**
[`WSS.SWEEP-CHECKPOINT.md`](../../wss/workflow/WSS.SWEEP-CHECKPOINT.md) is where
that rule lives, as its rule 5, and the definition is not maintained here — what
follows is a one-line gloss so this step reads on its own, and the file wins on
any difference: **no findings, or every finding fixed or dispatched, stamps; a
finding left with no home does not**, and the files it
lives in stay inside every future run's scope until someone acts. §3's
`--shallow` branch is this rule's plainest case. The ruling is the decision
log's `(eighty-fourth)` entry.

### 10. Hand off

Say what was checked, what was found, what was dispatched or applied and to
whom, what came back clean, and what stayed `not-covered` and why — clean is a
result, and a reader cannot otherwise tell it from "never looked at".

**Report the defect inbox's open count; never triage it.** Where this project
*is* this suite's own configuration directory — the only place
[`WSS.INBOX-TRIAGE.md`](../../wss/tests/WSS.INBOX-TRIAGE.md)'s entries can even
exist — count the `[open]` entries below the append marker and the open
upstream issues, and say the count, per half. Triaging them is `triage`'s,
invoked by the user, never a step this skill takes on its own account: naming
the count and stopping is the whole of this skill's business with the inbox.

**`--publish` names the release invocation.** Where every gate passed, print the
pinned sha and say `--wss-release` is next; `--wss-release` dispatches this
mode ahead of a tag for exactly this reason. Where a gate failed, say which and
stop — a release invocation on top of a known failure is a decision for the
user to make in words, not by this skill's omission.

## The shipping set

**One source, never a second hand-kept list**: the tracked lock at
[`wss/scripts/WSS.SHIP-LOCK.txt`](../../wss/scripts/WSS.SHIP-LOCK.txt), read
against what `wss-publish.sh` actually
assembles. The lock is the shipping set, and it is the file `--publish` narrows
to — resolving it any other way, or copying its contents into a second list
here, is the duplication this suite exists to prevent. The ruling is the
decision log's `(seventy-sixth)` entry.

**This machinery is this repository's own, even though this skill file ships**
— the decision log's `(eighty-first)` entry — **and it is not
manifest-resolved**: `wss-publish.sh` names this project's own public
repository by construction and does not itself ship; see its own header. On an
adopted tree carrying neither file, `--publish` has no shipping set to narrow
to; say so and point at the default mode instead of guessing at an
equivalent.

## What this skill does not do

- **It does not triage the defect inbox.** It counts and reports; `triage`
  disposes, on the user's own invocation.
- **It does not write a record file directly**, in any mode. Every dispositioned
  finding in a record goes through that record's owner.
- **It does not run the TODO resort outside `--deep`, and not there without an
  explicit yes.** `--shallow` and the default report and fix drift; rebuilding
  the TODO list around the project's position is a heavier, separate question.
- **It does not stamp a checkpoint over an unhealthy scope.** A finding with no
  home withholds the stamp for the scope it lives in; see §9.
- **It does not commit or push by hand, and does not tag.** Commits go through
  `git-writer`; a version is `--wss-release`'s.
- **It does not invent a shipping set where none is declared.** `--publish`
  degrades to "not applicable here" rather than approximating one.
