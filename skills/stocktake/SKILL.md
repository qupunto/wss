---
name: stocktake
description: "Take stock of where a project actually is — whether its record matches reality, its conventions and public surface hold, and a release's safety nets exist — then rebuild the backlog around it. SHORTHAND: `--wss-stocktake`, `--wss-full-stocktake` for everything. Also on \"take stock\", \"are we ready to ship\". Expensive and rewrites the backlog: not for \"where are we\"."
---

# Taking stock of the project

A deliberate, periodic pass asking **where this project actually is**. It ends
with `WSS.record.todo` rebuilt around the answer and an entry in `WSS.record.stocktake` —
written by [`audit-writer`](../../workflow/writers/WSS.AUDIT-WRITER.md), which owns that file —
recording what was examined, against which tree.

## What it is, and what it deliberately is not

- **Where is this project?** Does the record still describe it, do the
  conventions hold, is the public surface coherent, does it have the tests and
  CI a release depends on, and what should the backlog look like now? Answerable
  from evidence any repository provides. **That is this skill.**
- **Is this code correct and safe?** Trust boundaries, injection, cascade
  semantics, migration reversibility, whether an assertion passes for the wrong
  reason. Each needs to know what the stack *is*, so each belongs to a
  **project-scoped code-analysis skill**, which this invokes as one more source
  of findings when the project has one (Phase 1).

**Without one, this skill still runs and says so** — it reports that no code
analysis ran, rather than implying the code was looked at and found clean.

The whole discovery phase is read-only and autonomous. The user is often away
while it runs, so don't stop to ask permission for reads. The first time this
skill needs the user is the finding-by-finding review.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: the record paths under
`WSS.record.*` — where a `.claude/WSS.LANE` selector names a lane,
`WSS.lanes.named.<lane>.records.X` overrides `WSS.record.X` for `todo`,
`openDecisions`, `handoff` and `roadmap`, per
[`WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md)'s resolution rule, and the rebuilt
backlog goes to the resolved file; `WSS.agents.audit` for the fan-out and the remediation owners under
`agents.*`; `WSS.commands.typecheck`, `WSS.commands.test`, `WSS.commands.testConsentEnv`,
`audit.dimensions` and `audit.invalidates` for scope and blast radius;
`gate.coverage` for the threshold CI enforces.

**Without a manifest the audit still runs — smaller, and louder.** A supported
mode rather than a degraded one; it is every project on its first pass:

- No audit history, so the run is effectively `--wss-full-stocktake`: skip Phase 0
  step 3 and say so. Step 4's blast-radius default still applies; it never
  depended on the manifest.
- Verification commands are whatever the repo's own tooling declares — a script
  in its build file, a CI config. Where none resolves, **the absence is a
  finding, not a silent skip.**
- **For the audit's own record, ask once**: create the audits file, offering a
  conventional default, or keep this audit's record in the report only. Never
  invent the file silently, and never skip recording silently either.

At close-out, recommend `--wss-adopt`.

Who owns what is [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md).

## Use the highest model available

Pass the **highest model tier available** explicitly on every `Agent` call, even
where the audit agent's own file declares one: an audit's ceiling is the model's
ceiling.

If that tier is unavailable, **say so in the report and in the `Method` field of
the `WSS.record.stocktake` entry** — a reader has no other way to calibrate the
findings.

## Delegate reading, keep deciding

Standing rule for every phase: **if a step's cost is reading rather than
deciding, delegate it and keep the decision.** End an audit holding findings,
verdicts and dispositions — not the contents of the files they came from.

## Phase 0 — Scope

1. **Pin the tree.** `git rev-parse --short HEAD` and `git status --porcelain`.
   Findings are only ever true against a specific tree. If the working tree is
   dirty, say so in one line and audit `HEAD` plus the dirty files, recording the
   entry as `<sha>+dirty` — don't ask the user to commit and don't stall.
2. **Choose the dimensions from the project's shape.** Detect the shape per
   [`WSS.PROJECT-SHAPE.md`](../../workflow/WSS.PROJECT-SHAPE.md), which owns the signals
   and what evidence establishes each.

   **Two dimensions apply to any repository**: `record` and `consistency`. The
   third runs when its signal is present:

   | Extra dimension | Runs when the shape has |
   |---|---|
   | `interface` | `public-api`, `cli`, or `service` |

   **`safety-nets` always runs, and it is a presence check rather than a
   review.** Does a test suite exist and pass, does CI exist and gate anything,
   is there a lockfile. **A missing suite is not a skipped dimension — it is a
   standing `high` finding**, verified by the absence itself and carried into
   every stocktake until the user dispositions it. Same for absent CI. Whether
   the tests are any *good* is the project skill's question, not this one's.

   **`correctness`, `security`, `data-model` and test *quality* are not run
   here.** They are the project code-analysis skill's. Where the project has no
   such skill they are simply not covered, and step 7 says so out loud.

   **Where the manifest declares `audit.dimensions`** it prunes, adds or
   re-briefs: a string names one from the set above; an object
   `{"name": ..., "brief": "path.md#anchor"}` supplies a project's own. Manifest
   entries win over inference. Dimension names are stable — coverage accounting
   across audits joins on them.
3. **Narrow the two dimensions that can be narrowed.** `record` is invalidated by
   the **code** changing rather than the doc, and `safety-nets` asks a question no
   diff can narrow; both always run full and both write `covered: []`. That
   leaves `consistency` and `interface`.

   For each, read `WSS.record.stocktake` newest-first: a path's governing baseline is the
   newest audit listing it under `covered`, and
   `git diff --name-only <baseline>..HEAD -- <globs>` is the slice. A path that
   appears only under `not-covered`, or in no block at all, has never been audited
   and is fully in scope, no diff.

   The block's format, and the four rules constraining what you may skip, are
   [`WSS.AUDIT-COVERAGE.md`](../../workflow/WSS.AUDIT-COVERAGE.md)'s.
4. **Apply the blast radius, strictly.** A file being unchanged does not mean its
   *behaviour* is unchanged. If any of these changed since a dimension's
   baseline, that dimension's narrowing is void and it returns to full scope.

   **The default set applies always, including with no manifest at all:**

   | Changed | Voids the narrowing for |
   |---|---|
   | a schema, its migrations, or whatever else defines the shape of stored data | **every** dimension |
   | the dependency manifest or its lockfile | correctness, consistency, security |
   | anything touching authentication, roles or ownership | security, **always** |

   **`correctness` and `security` are defaults for a project that supplies
   them** — through `audit.dimensions`, or its own code-analysis skill. This
   skill runs neither, here or in the `lanes` rule below. The schema row's
   **every** does include the dimensions it does run.

   **Where the manifest declares `audit.invalidates`** — a map of glob to the
   dimensions that glob voids, with `"*"` meaning all of them — those entries are
   **added** to the default set. A project can widen this rule and cannot narrow
   it.

   **Where `WSS.lanes.exclusive` or `WSS.lanes.serialize` exist, fold their paths in too**
   — exclusive voids every dimension, serialize voids correctness, consistency and
   security. Treat them as extra evidence, never as the definition: the default
   set stands with or without a manifest.

   **When in doubt, widen.** An audit that narrowed wrongly reports a clean bill of
   health it did not earn.
5. **Under `--wss-full-stocktake`, skip steps 3 and 4.** Everything is in scope,
   including every path previous audits listed as `not-covered`. Step 2 still
   runs — full scope means every dimension the repo has evidence for, not every
   dimension imaginable.
6. **Build the carry-over list — what previous audits already found.** From
   `WSS.record.stocktake`, take each previous audit's `Findings` and `Outcome` and sort
   them into:

   - **Fixed** — the remediation landed. These are **regression targets**: name
     them to the relevant auditor and have it re-check the fix is still there.
   - **Still open** — logged and not yet done. Do not let an auditor re-report
     these as new. Count how many audits have now reported each one; **two or
     more is itself a finding**, and a higher-severity one than the original.
   - **Disputed or dropped** — the user decided against it. Don't resurface it
     unless the tree changed underneath the reason. If you do, say which audit
     dropped it and why.

   Give every auditor the slice of this list touching its dimension.
7. **State the plan in three or four lines before spending anything**: which
   dimensions run and on what evidence, each one's baseline and slice size, what
   is left out and why, and how many carry-over items came back. This is the
   user's chance to veto a dimension — but it is a statement, not a request for
   approval. Name a dimension left out for lack of evidence in the final report
   too: a reader cannot tell "clean" from "never looked at".
8. **Create the task list up front**, per `track`: one task per
   dimension, plus verification, the test run, the review and the rebuild. Mark
   each one as it moves — never batch the completions at the end.

## Phase 1 — Fan out

One `WSS.agents.audit` per dimension, **all in a single message so they run
concurrently**. Give each its slice as an explicit path list, its baseline
commit, its share of the carry-over list, and the brief below.

**Where no `WSS.agents.audit` role is declared** — the common case on a project that
has just adopted this — use general-purpose subagents. The brief travels entirely
in the prompt, so nothing is lost except the role's own standing instructions.
Record the substitution in the entry's `Method` field.

**Hand each auditor its decisions, and do the lookup once yourself.** Read
`WSS.record.decisionsIndex` — one line per entry — pick the entries bearing on each
dimension, and name them in that auditor's prompt. It reads `WSS.record.behaviour`
and `WSS.record.reference` for current state, the named entries for the *why*, and
opens the full log only if something contradicts what it is looking at.

### Invoke the project's code-analysis skill, if it has one

**This is where deep code analysis enters, and the only place it does.** Before
fanning out, look for a project-scoped code-analysis skill:

```bash
ls .claude/skills/ 2>/dev/null
```

Where one exists — a skill whose purpose is analysing *this* project's source —
invoke it as one more concurrent finding source, and tell it three things: the
slice Phase 0 resolved, its share of the carry-over list, and that it must
**report findings rather than fix them**, in the same severity-and-citation shape
as the briefs below. Its findings then flow into Phase 2's verification and
Phase 3's review exactly like any other dimension's.

**Where none exists, say so in the plan and in the final report** — "no code
analysis ran" — and recommend writing one into `.claude/skills/` if the user
wants that coverage. Never imply the code was examined.

### The briefs

Each brief names a failure **class**; Phase 0's evidence supplies the nouns. No
brief assumes the project has routes, or a database, or a server.

| Dimension | Brief |
|---|---|
| **`record`** | **Hand the auditor [`workflow/checks/WSS.RECORD-DRIFT.md`](../../workflow/checks/WSS.RECORD-DRIFT.md).** One change: the auditor reports, it does not dispatch or edit. |
| **`consistency`** | Layering, naming, error shapes, duplication that a fourth copy will turn into a bug, dead code, abstraction level **against the project's own stated conventions**, which are in `WSS.record.reference`. Not performance without a measured problem. |
| **`interface`** | The contract this project offers its callers, whichever form it takes: surfaces that changed shape without a version, undocumented or accidentally-public surface, inconsistent errors and exit codes, and defaults that are hard to reverse once depended on. Judged from outside, against what `WSS.record.behaviour` and `WSS.record.reference` claim it offers. |
| **`safety-nets`** | A **presence** check, not a review. Does a test suite exist, and does the full run pass. Does CI exist, does it run on the branches that matter, and does it actually gate a merge. Is there a lockfile. Are the destructive operations gated behind `permissions.ask`. Every answer is yes/no plus evidence. Whether the tests are *good* is the project code-analysis skill's question. |

**A dimension whose evidence Phase 0 did not find is not dispatched.**

**Where a project declares extra dimensions in `audit.dimensions`,** each carries
its own `brief` pointer, and those may be as stack-specific as the project likes.

**No auditor runs the test suite.** They have no write tools, but you are the one
who has to not ask them to.

## Phase 2 — Verify, then run the suite

### Re-verify by hand

Not optional. Before anything reaches the user, personally re-check:

- **every `critical` and `high` finding**, by reading the cited lines yourself;
- **every negative claim** ("nothing does X"), by running the grep that would
  *disprove* it —
  [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#negative-claims);
- **every count** — tests, routes, migrations, rows;
- **anything contradicting `WSS.record.decisions`.** The decision is usually right
  and the auditor usually missed it.

**Delegate the mechanical half.** Re-checking a `medium` or `low` finding, or
running the grep that settles a negative claim, is reading rather than
judgement — send it to a subagent with the citation and have it return a verdict
plus evidence.

**Do `critical` and `high` yourself.** Those are the ones that reach the user as
"I checked this".

That gives three levels, and the `WSS.record.stocktake` `Verification` field must say
which is which: **re-checked by the orchestrator**, **re-checked by an
independent verifier**, or **agent-reported**. Collapsing the middle into the
first is the dishonest move available here.

Mark each finding `[verified]`, `[reported]` or `[disproven]`. Disproven findings
are dropped from the review list but **named in the audit entry**.

Deduplicate across dimensions: the same defect found by three auditors is one
finding with three citations.

### Then check each survivor against the audit history

**False clean.** For every surviving finding, check whether its file sat inside a
previous audit's `covered` globs at a commit where the defect was already present
(`git log -1 --format=%H -- <file>` against that baseline tells you). If it did,
that audit reported clean on code that wasn't. Mark the finding
`[missed by <date> audit]`: it says a dimension's brief or slice was too narrow.

**Recurrence.** Match every finding against the carry-over list. A finding
matching a **fixed** item is a *regression* — re-open it one severity higher and
name the commit that was supposed to have fixed it. A finding matching a **still-open** item is
not new: fold it into the carry-over count rather than listing it twice.

### Then run the suite — once, and read CI

**The mechanics are
[`workflow/checks/WSS.MECHANICAL-GAUNTLET.md`](../../workflow/checks/WSS.MECHANICAL-GAUNTLET.md)**
— the doctor-first sequence, the full-suite-with-coverage rule, the consent
budget, the `test-run` carry-forward, and CI's four outcomes on the audited
SHA, all of them in the report. Run the project's schema-validation and
dependency-audit commands alongside, where it declares them.

What stays this skill's, because it is an orchestrator's:

- **Where there is no suite to run**, say so plainly and carry Phase 0's
  standing `high` finding — silence reads as "the tests pass". A missing CI run
  is Phase 0's finding the same way.
- **Check nothing else is mid-run first.** Grep the process table for the
  project's test runner; a collision produces failures indistinguishable from
  real defects, so wait and say so rather than retrying into it.
- **Consent is the orchestrating session's alone** — never a subagent's.
- **Afterwards, hand `sweep-tracker` the `test-run` entry** — the sha, the
  result and the runtime count. Hand it over rather than writing the file here:
  the checkpoint has one writer.
- **Record the runtime count from the run's own output**, not a count of call
  sites — parameterised helpers expand at runtime and undercount. Compare
  against the previous audit's figure; a suite that grew more slowly than the
  code did is a finding the test dimension should be asked about directly.

### Save the findings before talking to the user

Write the consolidated, verified findings to the scratchpad as `audit-<sha>.md` —
numbered, grouped, with citations and verification marks. Context may compact
partway through the review.

## Phase 3 — Review with the user, one finding at a time

Open with a **compact index**: every finding as one numbered line, grouped by
severity, with its kind and verification mark. Include the test, typecheck and CI
results, and the dimensions that came back clean — clean is a result.

### Split the list first: does the answer change anything?

**Auto-accept, don't ask** — a `[verified]` `defect` at `critical` or `high`
severity, or any **regression** of something a previous audit closed. Log these
straight to `WSS.record.todo`, list them in the index with citations, and say in one
line: *"these N were auto-accepted as verified defects — say the word and we'll
walk any of them."* The override must be genuinely available, not merely offered.

**Ask, one at a time** — everything else:

- every `suggestion`, `inconsistency` and `risk`, where the whole question is
  whether it is worth the complexity;
- every `gap` and schema/scale finding, where the answer depends on a product
  direction the auditor cannot see;
- anything `[reported]` rather than `[verified]` — you are asking the user to
  trust an unverified claim, so let them weigh it;
- **every carry-over item at two or more audits**, where the question is not
  "should we fix this" but "this keeps coming back — is it actually not going to
  happen, and should it stop being on the list?"

If in doubt about which pile something belongs in, ask. Auto-accepting is the
concession; individual review is the default.

### Then walk the ask-pile

Most severe first, via `AskUserQuestion` — one question per finding, showing the
citation and the one-line direction. Dispositions:

- **Fix now** — becomes a `TaskCreate` item, worked this session after the audit
  closes.
- **Log it** — into `WSS.record.todo` as a checkbox with technical detail.
- **Defer with reasoning** — hand to `--wss-todo`: task to `WSS.record.todo`, reasoning
  to `WSS.record.decisions`. A deferral is a decision.
- **It's an open decision** — to `WSS.record.openDecisions` with options and what it
  blocks, not to `WSS.record.todo`.
- **Drop it** — the finding is wrong, already handled, or deliberately not a
  problem. Record it as disputed in the audit entry with the user's reason. Never
  silently discard.

Two concessions to the user's time, and only two. **Batch the genuinely
identical**: the same defect in five routes is one question. And **honour a
blanket answer** — if the user says "log the rest of the mediums", stop asking and
log them, noting in the audit entry that those were dispositioned as a group.

Everything else in the ask-pile gets asked. If you find yourself auto-accepting
more than about a third of the findings, the classification is wrong — check
whether you are marking things `[verified]` that you only skimmed.

## Phase 4 — Rebuild `WSS.record.todo`, then record the audit

`WSS.record.todo` is not appended to — it is **restructured**. The restructure is
*decided* here and *written* by `--wss-todo`, which owns that file. This skill
supplies the dispositions and the approved shape.

1. **Propose the restructure before doing it.** Sections you would merge, split,
   rename, reorder or drop, and where new items land — a short list, not a diff.
2. **Then rewrite it through `--wss-todo`, and delegate the transcription.** Hand a
   subagent the dispositions, the approved restructure and the house format, and
   have it return the rewritten file. Ask it for a section inventory first if you
   need one for step 1 — that is a dozen lines, not the whole file. House format:
   new items in the section they belong to (checkbox, bold name, technical
   detail, file paths, no reasoning — reasoning lives in `WSS.record.decisions`),
   reordered within sections so severity is visible from the top. Delete anything
   the audit found already done; `WSS.record.todo` is forward-looking, items are
   removed, never struck through.
3. **Nothing disappears without a home.** Every deleted item is either
   demonstrably done (say where), moved to `WSS.record.decisions`, or moved to
   `WSS.record.openDecisions`. If you cannot name the home, it stays.
4. **`WSS.record.roadmap` and `WSS.record.releases` if priorities moved — propose, don't
   write.** `--wss-plan` is sole writer of both: goals and their order in the first
   — every lane's copy — and milestone boundaries, the version a milestone intends
   to ship as, and the marks in the second. A finding severe enough to reorder a
   roadmap gets its own block; hand the reorder to `--wss-plan` even when you have
   the whole picture and the edit looks trivial. **A version or a completion mark
   found in a roadmap is a finding, not a detail to preserve** — it belongs in
   `WSS.record.releases`, and under lanes it is a release checkpoint one worktree cut
   for the whole project. **A finding about a version or a tag is `--wss-release`'s
   decision**, and a correction to `WSS.record.changelog` is `changelog-writer`'s
   write — including drift between what the documents claim shipped and what
   `git tag` actually has.
5. **`WSS.record.handoff`, narrowly — through `handoff-writer`, which owns it.** Hand
   it only the `!important` warnings this audit *created* or *resolved*: one line
   each plus a pointer, with the resolved ones deleted immediately. Do not write
   the file here, even though it is one line and obviously correct. The broader
   currency pass comes later, when Phase 5's `--wss-wrap` calls the same primitive.
6. **Hand any decision this audit produced to `--wss-log`, and let it regenerate the
   index.** `WSS.record.decisions` and `WSS.record.decisionsIndex` are `record`'s,
   and the index is generated — never hand-run `WSS.commands.indexRegen` here.
7. **`WSS.record.stocktake` last — through [`audit-writer`](../../workflow/writers/WSS.AUDIT-WRITER.md),
   which owns it.** Hand it the material this audit produced: the tree and
   whether it was clean, the scope, the method, which findings you re-checked by
   hand against which are agent-reported, the test and CI results, the findings,
   the carry-over counts and any `[missed by <date> audit]` annotations.

   **Build `covered` from the auditors' reports, not from your plan**, and hand
   *that* over rather than a summary of your intentions. The four rules that make
   it mechanical rather than a judgement call are
   [`WSS.AUDIT-COVERAGE.md`](../../workflow/WSS.AUDIT-COVERAGE.md); the one that gets bent
   is *silence is not coverage*, and it gets bent because a wide `covered` list is
   what makes your next run cheap. Separating the claim from the record is what
   keeps it reviewable.

   **Updating `Outcome` later does not come back through this skill.** It is a
   one-field write on an existing entry, and the caller landing the remediation
   goes to `audit-writer` directly — needing a full audit procedure to move a
   status field is the shape this split removed.
8. **Then hand `sweep-tracker` a freshness-only entry** keyed `stocktake` — the
   name, the `baseline` and the date, and nothing else. **No coverage and no
   findings**: those went to `WSS.record.stocktake` in step 7, and
   [`WSS.AUDIT-COVERAGE.md`](../../workflow/WSS.AUDIT-COVERAGE.md) keeps them out of a
   cache that gets deleted. What this buys is that `--wss-overview` can say when
   this last ran without opening the audit record at all — and it licenses no
   narrowing, because an entry with no scopes leaves the next run's slice
   untouched. The shape is
   [`WSS.SWEEP-CHECKPOINT.md`](../../workflow/WSS.SWEEP-CHECKPOINT.md)'s.

## Phase 5 — Close out, and hand the work to its owners

**An audit is not finished when the findings are written. It is finished when
they are committed.** Not optional, and not conditional on the user asking.

**Invoke `--wss-wrap`** — the whole ritual this time, not the narrow hand-off of
Phase 4 step 5. It reconciles the task list, calls `handoff-writer` for the full
currency pass, and commits in coherent pieces through `git-writer`.

**It runs as a dispatched wrap, and its own file says what that means**: your
grant at your scope, no `/clear` declaration, and no milestone question — this
procedure continues afterwards with the Fix-now dispositions below.

**`--wss-stocktake` and `--wss-full-stocktake` are standing authorization to commit and push**,
exactly as `--wss-wrap` is, and it does not need asking again. The grant comes from
the flag, not from this file — [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md) is
where it is stated.

That authorization is **scoped to the audit's own record**: the `WSS.record.stocktake`
entry, the rebuilt `WSS.record.todo`, and any roadmap, decisions, open-decisions or
handoff changes the review produced. It does **not** extend to remediation. A
defect fixed an hour later in the same session is ordinary work under ordinary
rules — commit it, then ask before pushing, or wait for `--wss-wrap`.

Either way the history is written by `git-writer` and never by hand: its rules on
grouping, staging by name, session trailers and whose work a push would publish
are what make this grant safe, and they only apply if you use it. Invoked from
here it inherits the scoped grant above — record only.

Then route what the review produced. Every **Fix now** disposition has an owner,
and it is never this skill. **Where the manifest declares no role for a finding's
kind, the item goes on the session task list as ordinary work** — never to a
different role's agent:

| Finding in | Goes to |
|---|---|
| The schema or its migrations (`WSS.lanes.exclusive`) | `WSS.agents.architecture` to decide the shape, then the manifest's `onSchemaChange` skill for its mandatory post-edit sequence |
| Routes, services, domain logic | `WSS.agents.implement` |
| Containers, networking, infra scripts, CI workflows | `WSS.agents.infra` |
| A test gap, or missing regression coverage | `WSS.agents.test` |
| A security finding that needs proving before anyone fixes it | `WSS.agents.exploit` |
| A goal or roadmap block to add, reorder or reprioritise, or a milestone in `WSS.record.releases` | `--wss-plan` |
| A version or a tag, or drift between the documents and `git tag` | `--wss-release` — it decides; `changelog-writer` and `--wss-plan` write |
| A stale claim in **this project's** skill or agent file | `--wss-tools`, which owns them — dispatch, do not fix it here |
| A defect in a file belonging to **this suite** — including one this audit is running | **File it and stop.** Not `--wss-tools`, not a fix in place — destination and reasoning in [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session) |
| Anything the user decided not to do now | `--wss-todo` (already done in Phase 3) |

**Prove a defect with a failing test before fixing it wherever possible.**

## What this skill does not do

- **It changes no code.** Not during discovery, not during review, not "while I'm
  in there". Fixes happen after the audit closes, from the task list the review
  produced, under the user's eye.
- **It doesn't commit or push by hand, and never tags.** Its record goes out
  through `git-writer`. Deciding that a version ships is `--wss-release`'s alone.
- **It doesn't invent documents *silently*.** Everything it produces goes in a
  record file that already exists — except the audits record itself on a first
  pass, where it asks once and then creates the empty file, because
  `WSS.record.stocktake` has no conventional filename and `audit-writer` stops rather
  than guessing one. Creating the container is not writing the record; the entry
  still goes through the owner. If nothing else fits, say so rather than
  inventing structure.

## It absorbs `--wss-check`'s standalone sweep

That sweep and this skill's record dimension are the same job, so there is one
method and it lives in
[`workflow/checks/WSS.RECORD-DRIFT.md`](../../workflow/checks/WSS.RECORD-DRIFT.md) —
point the auditor at the file rather than copying it, or at the skill that
happens to also run it. Invoke one flag or the other, never both.

Ownership of everything else is
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md).
