# Claude tooling

Every skill, agent and script in this repository, and what each one is for. This
repo is *only* tooling, so this doubles as the overview of what the project is.

`catalog` (`--wss-catalog`) owns this file and is its sole writer.
`--wss-tidy` invokes it after any edit that restructures a tooling file, and
`wss-tools-inventory.sh` runs before either renders, so the rows below describe
the tree the run ends with rather than the one it started from.
`--wss-full-check` hands it back here at the end of every health check, which is what
keeps it from becoming the stale inventory this workflow warns about everywhere
else.

**Where a project has a documentation site**, `--wss-catalog` hands this file to
`docs-writer`, which adapts it into a Claude-tooling annex page and owns that page —
`--wss-docs` only where the page does not exist yet and its placement is still open.
This repository's is `wss/docs/annex/WSS.CLAUDE-TOOLING.md`. This file stays the
source — when the two disagree, this one is right.

**What this file deliberately does not carry**: which record each skill may
write, or what any grant permits in detail. That is
[`WSS.OWNERSHIP.md`](../wss/workflow/WSS.OWNERSHIP.md), and a second copy here would drift
from it. The diagram below shows the two tiers and the direction authorization
flows, because that is the shape nobody can reconstruct from a single file — but
where it and `WSS.OWNERSHIP.md` disagree, `WSS.OWNERSHIP.md` is right. This answers
*what does this thing do*, and *what calls what*.

Nor does it say which skills a session actually loads in full. A skill can be set
to `name-only` — still invocable, but with its description kept out of the
session's context — and which ones are is `skillOverrides` in `settings.json`.
**The harness half of that lever is the checkout form's only.** `skillOverrides`
does not reach plugin skills, and `settings.json` is the user's rather than the
plugin's, so an install loads every description in this file regardless. Every
skill below exists and can be called whether or not it is listed there.

**But `wss-shorthand-flags.sh` checks the overrides itself**, so under a plugin
install `off` still stops that skill's *flag* firing while the skill stays
callable. Half a disabled skill; `README.md` carries the detail.

---

## How the pieces fit

The rows below describe each skill alone. What none of them shows — and what
nobody can reconstruct from any single file — is the direction work and
authorization flow. `--wss-catalog` maintains this picture itself, under the
diagram rules whose authority is the docs style guide
(`skills/docs/references/WSS.STYLE-GUIDE.md`, its Diagrams section).

```
                 a flag the user types
                          │
                          │  confers the grant. A skill never widens
                          │  its own, and a DISPATCHED skill inherits
                          │  its CALLER's grant, never its own flag's.
                          │  A SUBAGENT inherits no commit grant.
                          ▼
   ┌────────────────────────────────────────────────────────────────┐
   │  ORCHESTRATORS — own the session, write no record              │
   │                                                                │
   │    --wss-start      --wss-check      --wss-full-check          │
   │    --wss-release    --wss-wrap       --wss-pr                  │
   │    --wss-stocktake  --wss-report     --wss-docs                │
   │    --wss-adopt      --wss-overview   --wss-diagram             │
   │    --wss-update                                                │
   │                                                                │
   │    flagless:     lane-record-sync   retire             │
   │                  skill-toggle       (all slash only)       │
   └───────────────────────────┬────────────────────────────────────┘
                               │
                               │  invokes, passing its grant down
                               ▼
   ┌────────────────────────────────────────────────────────────────┐
   │  PRIMITIVES — a record, the history, or a rule                 │
   │                                                                │
   │    with a flag:  --wss-track    --wss-todo / --wss-log         │
   │                  --wss-plan     --wss-catalog  --wss-tidy      │
   │                  --wss-scout                                   │
   │                  --wss-describe --wss-reference                │
   │                                                                │
   │    flagless:     contracts  (a skill)                      │
   │                                                                │
   │    procedures    sweep-tracker     handoff-writer              │
   │    under         changelog-writer  git-writer                  │
   │    workflow/     manifest-writer   behaviour-writer            │
   │    writers/:     reference-writer  audit-writer                │
   │                  docs-writer                                   │
   └───────────────────────────┬────────────────────────────────────┘
                               │  the ones that write
                               ▼
              the record files, and the git history
```

**Every orchestrator writes no record**, and the box needs only one row to say
so. The diagram draws the current state, never an intended one — a map that
shows the destination is read as showing the territory.

The picture shows tier and grant direction only. **Who invokes whom is the table
below**, deliberately not drawn here: the two would fight for the same arrows.

**Not every primitive writes**, which is why the bottom arrow is labelled.
`contracts` only states how the suite is wired — the "rule" in the box
label. It is a primitive on the same test as the rest: one job, no session of
its own, no authorization it did not inherit.

**These procedures are not skills.** They live at `wss/workflow/writers/*.md`
and a caller reaches one by reading the file, not by invoking anything — a
skill's description loads into every session whether the skill is used or not,
and each of these is invoked only by other skills, a trigger a description
cannot serve. They are drawn in this box because the tier is the same: one
record each, sole writer, no grant of their own. `wss/workflow/writers/WSS.WRITERS.md` is their index.

**The flagless row cannot be entered from the top**, and that is the point
rather than an omission: a primitive with no flag has no grant of its own to
inherit from, so a caller can never acquire authorization the user did not give
it. Arrows also run the other way — the primitive `--wss-catalog` invokes `--wss-docs` —
and reaches `docs-writer` directly — because the tier says what a skill owns, not
who may call it.

**Three orchestrators are flagless for a second reason on top of that.**
`lane-record-sync` is expensive and writes into every lane's inbox;
`retire` deletes a project's workflow files; `skill-toggle` edits the user's
`settings.json`. Slash-only invocation is what stops any of them from
happening because a sentence contained the right words. They confer no grant
and inherit none, since nothing may call them.

**The top arrow's inheritance stops at a subagent.** A dispatched skill runs in
its caller's own context, so the grant travels with it; a subagent holds no flag,
its context is discarded on return, and it runs beside its siblings — so what it
inherits is read and write on the file set its brief declares, and no commit
grant. The rule, its reason and the cost it accepts are `git-writer`'s, under
"The grant is the caller's, always"
([`WSS.GIT-WRITER.md`](../wss/workflow/writers/WSS.GIT-WRITER.md)).

### Who invokes whom

<!-- wss:region entry=table-row -->
| Caller | Invokes | For |
|---|---|---|
| `--wss-adopt` | `manifest-writer`, `--wss-docs`, `git-writer`, `wss-export-records.sh --import`, `update` | writing the manifest it decided on; scaffolding a project that has no documentation; committing; restoring an archive when its first question — asked up front, default no — gets a yes, before any record is seeded. Amendment mode — one key in an existing manifest — reaches `manifest-writer` without the detection phase. A stale-convention tree — pre-rename filename, v1 schema — is routed to `update`'s migration mode behind its own gate rather than amended around; a finished adoption stamps `WSS.suite` through `manifest-writer` |
| `--wss-update` | `wss-export-records.sh --all`, `manifest-writer`, `git-writer`, `--wss-plan` | the snapshot before the first write; the `WSS.suite` stamp and any manifest key move, only over a passing doctor; one mend per commit; content surgery that lands in a planning record — extracting embedded milestones into the release list — goes through the record's owner, not directly |
| `--wss-start` | `wss-orient.sh`, `--wss-track`, `--wss-todo` / `--wss-log`, `--wss-plan`, `--wss-tidy`, `--wss-catalog`, `--wss-docs`, `behaviour-writer`, `reference-writer`, `handoff-writer`, `git-writer`, `sweep-tracker` | Phase 0's mechanical state in one call before any record is read; building the task list before the batch; recording what the batch produced, committing it, and stamping the suite run so the next audit need not repeat it. `--wss-docs` only where a change also earns a page. Its Phase 6 handoffs run **serialized**, never concurrently — every record writer re-verifies against the other records, so each one's read set is all of them |
| `--wss-check` | the owner of each finding, and `sweep-tracker` | it writes nothing itself — dispatch is the whole design. Every row in its table is a primitive, so a one-line staleness fix never has to run a whole orchestrator procedure to get written |
| `--wss-full-check` | the same owners at full scope, plus `--wss-track`, `--wss-catalog` (the catalog) and `--wss-tidy` (the prune), `sweep-tracker`, `wss-survey` as each of its three readers, `wss-mechanical-gauntlet.sh` — which is how it reaches `wss-doctor.sh`, the typecheck and the project's own test command, rather than running any of them directly — and `wss-docs-audit.sh` for the docs dimension's mechanical half | building the task list before the run, then ignoring every checkpoint. It resolves the suite carry-forward at the start and deliberately never stamps it at the end, because its later steps always run against a tree it has already edited |
| `--wss-stocktake` | `--wss-track`, the manifest's `WSS.agents.audit` — one subagent per dimension, routing to its rung's own agent `wss-survey` rather than to `general-purpose` where the role is undeclared — `wss-survey` for its three whole-record reads above the spawn floor and for re-checking a `medium` or `low` finding, `--wss-todo` / `--wss-log`, `--wss-plan`, `--wss-tidy`, `--wss-release`, `--wss-wrap`, `audit-writer`, `handoff-writer`, `git-writer`, `sweep-tracker`, `wss-mechanical-gauntlet.sh` for the doctor/typecheck/test/CI pass, and the project's own code-analysis skill where one exists | the task list before its fan-out; the dimension fan-out itself; the dispositions — a finding about a version or a tag dispatched to `--wss-release`, which decides — its own audit entry, and a dispatched close-out. It runs the record dimension itself from `wss/tests/WSS.RECORD-DRIFT.md` — the hook drops `--wss-check` when either stocktake flag is typed |
| `--wss-release` | the manifest's `WSS.agents.release`, `--wss-full-check`, `changelog-writer`, `git-writer`, `--wss-plan` | the reading — release list, cited roadmaps, changelog, TODO list, audit log, git history — returned as a proposal; everything being in order before a tag — drift included, since that is one of its dimensions — then the entry and the tag, a resumed release re-checking the entry through `changelog-writer` and not just the tag. A milestone that looks complete but is unmarked is handed to `--wss-plan`: it reads that mark and never writes it |
| `--wss-plan` | the manifest's `WSS.agents.roadmap`, `--wss-todo` | the reading — roadmaps, release list, TODO list, decision index, audit log, git history — delegated so only a proposal returns, while the asking stays here; and a task breakdown that surfaces mid-planning, which is `--wss-todo`'s file rather than a roadmap block. It *names* `--wss-release` as the next step after a mark and never invokes it |
| `lane-record-sync` | `git-writer`, `audit-writer`, `--wss-log`, `--wss-wrap` | step 0's landing, step 5's return leg and step 6's close-out — each lane's branch fast-forwarded onto `WSS.branch.integration` locally, then each lane worktree brought back onto it once the run has finished writing into them; divergence reported and never resolved, and a dirty lane worktree skipped; the run's audit entry — which reports what it promoted out of the conflict inbox and what it deleted as not reproducing — and the declined derivations as one decision entry so a later run does not re-ask them. Every finding it keeps reaches a lane through that lane's transfer queue, never by writing its records. Having no flag it passes no grant down, so the wrap it dispatches asks the user for its own commit in that turn and is never offered the push — step 0's local landings would otherwise reach the remote as a side effect of tidying up; step 6 runs even where step 5 skipped every lane |
| `--wss-wrap` | `handoff-writer`, `--wss-plan`, `git-writer` | the handoff, the milestone question — **from the main checkout only**, since a mark is a checkpoint for the whole project — the commits. It *names* `--wss-pr` where the pushed branch is ahead of `WSS.branch.publish`, and never invokes it — a session ending and work being ready to merge are two different facts |
| `--wss-pr` | `git-writer`, `--wss-todo` | the merge, once the user confirms in that turn; and the review threads nobody resolved, which the merge is about to hide — proposed to the user, never filed automatically, because a meaningful share of unresolved threads is chatter. It drafts the body and holds the gate, and writes nothing itself |
| `--wss-catalog` | `docs-writer`, `--wss-docs`, `git-writer`, `wss-tools-inventory.sh` | running the collector before it renders, then handing the catalog over to the writer — `--wss-docs` only where the annex page does not exist yet and its placement has to be decided. It draws the diagram above itself. It holds no numbers: every measured fact is `WSS.record.tooling.inventory`'s, and a row here points at that entry rather than repeating it |
| `--wss-tidy` | `wss-tools-inventory.sh`, `--wss-catalog`, `--wss-todo`, `--wss-log`, `manifest-writer`, `sweep-tracker`, `git-writer`, `wss-doctor.sh`, `wss/tests/WSS.TOOLING-CLAIMS.md`, `wss/tests/WSS.PROSE-PRUNE.md`, `wss/tests/WSS.TOKEN-ECONOMY.md`, `wss/tests/WSS.ROT-RESISTANCE.md`, `wss/tests/WSS.ROUTING-HEALTH.md` | the five sweeps, and stamping each one. Job 2 runs the claims method, Job 3 the prune method, Job 4 the token-economy method — what could be a script, a cheaper subagent, a gated reference or a cache hit — Job 5 the rot-resistance method, which finds the structure that will produce tomorrow's Job 2 finding, and Job 6 the routing method, the only one of them able to argue a description longer. After any edit that restructures a file it runs the collector and then `--wss-catalog`, or the catalog describes the pre-tidy tree. Durable reasoning a cut relocates goes through `--wss-log`; a tooling *task* it uncovers goes to `--wss-todo`; a `WSS.record.tooling.sources` glob that leaves tooling files undeclared goes to `manifest-writer`, since it never sweeps an undeclared file on its own authority |
| `--wss-docs` | `docs-writer`, `wss-docs-audit.sh`, `--wss-todo`, `--wss-track`, `sweep-tracker`, `behaviour-writer`, `reference-writer` | the audit's mechanical half, so a drift check is one call rather than ten fenced blocks retyped; every write to the site, which it decides and never performs; parking a page set larger than one session, since this skill stores no state of its own; narrowing its next audit; and handing over a subject that turns out to be a runtime rule or reference material rather than a page, which it never writes itself |
| `--wss-scout` | `--wss-log` | the reasoning entry an adoption earns, at the moment the user adopts — the registry row stays lean and points at it |
| `retire` | `wss-retire-workflow.sh` (`--dir`, then `--suite`), `wss-export-records.sh --all`, `wss-reset-records.sh`, and `claude plugin uninstall` for the user to run | the tidy exit, sequenced: dry run, one checkbox dialog, then the checked actions in dependency order — snapshot before any deletion, wipe before the machinery delete that removes the manifest it reads, the installation last in either form, since it removes the skills the walkthrough runs on |
| `skill-toggle` | `wss-skill-levels.sh` | step 1's level table, so the two settings reads, the two tree enumerations and the merge are one deterministic call rather than a re-derivation each invocation. Everything the table is read *for* — which skills a dispatch reaches, which lose a flag, which are plugin-owned and uncontrollable — stays the skill's judgment and is deliberately not in the script |
<!-- wss:region-end -->

`--wss-check` and `--wss-full-check` appear as callers and never as callees of a write:
an inspector that writes is a second writer on every file it touches.

---

## Global skills

In `skills/`, loaded in every project. The record procedures are the table
after this one.

<!-- wss:region entry=table-row -->
| Skill | Flag | What it does |
|---|---|---|
| `adopt` | `--wss-adopt` | Brings a project under this workflow — detects its shape, maps files it already has, decides what its `.claude/WSS.WORKFLOW.json` should say and hands that to `manifest-writer`, proposes `permissions.ask` gating for the destructive commands it finds, and hands a project with no documentation to `--wss-docs`. The detection and the asking are what stay here: a primitive has no channel to reach the user. A tree carrying a *previous* suite convention is recognized before the adoption/amendment verdict and routed to `update`'s migration mode |
| `update` | `--wss-update` | Updates the suite install (checkout pull `--ff-only`, or plugin update), then detects what conventions the adopted tree actually carries and migrates it to the newest — detection is the authority, the `WSS.suite` stamp and the release list's `- migrate:` lines only set the starting point. Its own consent gate shows the full plan of mends; the snapshot precedes the first write; one mend per commit, a partial migration never exits clean, append-only records are never rewritten, and the stamp lands last, only over a passing doctor |
| `docs` | `--wss-docs` `--wss-diagram` | Decides what a project's long-form documentation site holds — whether a subject earns a page, which page, and which tier it lands in — then hands the target to `docs-writer`, which writes it. Covers per-workflow flow pages, a diagram plus stages citing the behaviour record and the code. `--wss-diagram` is the ad-hoc entry: one diagram, placed here, drawn by the writer under the style guide's three rules, landed as an annex page |
| `full-check` | `--wss-full-check` | Asks whether a project's records, docs and tooling are in order — runs its mechanical checks, re-verifies all three at full scope ignoring every checkpoint, triages the defect inbox filed from other projects, orders the prune, has this catalog refreshed, then leaves fresh checkpoints. `--wss-release` runs it before a tag. It reaches `--wss-catalog` and Job 3 of `--wss-tidy` and not the other four sweeps — Job 2's method it runs itself, in its own readers — so "in order" is these three records rather than everything the suite can check |
| `pr` | `--wss-pr` | Assembles a release branch from the publish branch, merging the chosen typed branches into it, and ships it onto the publish branch through a pull request — drafts the body from the branch range rather than from memory, opens it, watches its CI, and merges behind a fresh confirmation. The integration branch is the disposable test bench and is never a PR source. The only thing in the suite that moves work onto the two branches |
| `stocktake` | `--wss-stocktake`, `--wss-full-stocktake` | Where is this project — record, conventions, public surface, safety nets — then rebuilds the TODO list around the answer. Invokes the project's own code-analysis skill where one exists |
| `record` | `--wss-todo`, `--wss-log` | Parks work that is not being built now, and records decisions already made |
| `describe` | `--wss-describe` | Gets a runtime rule settled in conversation into `WSS.record.behaviour`, which every other route reaches only as a side effect of a check or a build. Dispatches to `behaviour-writer` and writes nothing; its own work is turning away the three things handed to it by mistake — reasoning and decided-but-unbuilt behaviour, both `--wss-log`'s, and stack or architecture, which is `--wss-reference`'s |
| `reference` | `--wss-reference` | Gets a fact about what the project *is* — stack, architecture, data model, a convention — into `WSS.record.reference`, the same shape as `describe` one record over. Dispatches to `reference-writer` and writes nothing; it names the exact file the fact resolved to before anything is written, because the manifest may map the project's `README.md` into the reference array and this flag then reaches a public landing page |
| `scout` | `--wss-scout` | Consults the project's toolbelt registry before any capability gets hand-built, searches the stack's public registries when the registry has no answer, and explains the candidates — advises, never implements. Sole writer of `WSS.record.toolbelt`; the reasoning behind each row goes through `--wss-log` |
| `check` | `--wss-check` | Asks whether a project's records still match reality — including whether the documents claim a version no tag resolves; reports and dispatches, writes nothing itself |
| `report` | `--wss-report` | Files a finding about this suite upstream — appends it to the machine-local inbox, then opens a GitHub issue on the public repository behind a preview, a redaction of the project context, and a fresh OK. Can bundle every open inbox entry under the same rules; hazards are referenced by group name, never quoted |
| `release` | `--wss-release` | Decides that a version ships — once `WSS.record.releases` marks a milestone done, or once it has declared an end to milestones and the release is maintenance on evidence — and asks before anything is published. The entry and the tag are written by the two primitives above |
| `plan` | `--wss-plan` | Sets the next goal in `WSS.record.roadmap` — which splits by lane — and keeps `WSS.record.releases`, the release list, where the milestones, their versions and their marks live. A roadmap carries neither |
| `overview` | `--wss-overview` | Reports where a project stands at a glance — branch and lane, per-record counts, sweep freshness, pending warnings, the nearest milestones — read fresh at invocation, writing nothing at all. Every mechanical number comes from its probe script in one call; the model adds only the judgment lines. The read-only sibling of `--wss-check`: it counts what the records say and never verifies them |
| `start` | `--wss-start` | Picks up pending work and does it, in parallel lanes partitioned so they cannot collide |
| `catalog` | `--wss-catalog` | Keeps this catalog current and draws the diagram above — what each tool is *for*, in one human sentence per row, and who invokes whom. Hands it to `docs-writer` where a site exists. It contains no numbers by construction: the measured half is `.claude/WSS.TOOLS.json` |
| `tidy` | `--wss-tidy` | Runs the five sweeps over every file `WSS.record.tooling.sources` reaches — skills and their references, agents, the writer and check procedures, the command wrappers, and the `workflow/` contracts where the globs reach them: stale claims deleted rather than corrected, the prose prune, the token-economy sweep, the rot-resistance sweep and the routing sweep. A contract file there is subject to the mutable-claim rule like any other; what the sweep never touches is the *rules* those files state. It re-opens the catalog through `--wss-catalog` whenever it restructures anything |
| `track` | `--wss-track` | Builds the visible task list for multi-step work and keeps it honest as the work moves |
| `retire` | — | Retires the workflow from a project — the reverse of `--wss-adopt`. Shows what would go, then one checkbox dialog: a full snapshot (`WSS.RETIREMENT-PLAN.tar.gz`, restorable at re-adoption) asked first, then the actions to run — delete the machinery, delete the records, wipe the records, uninstall the plugin — executed in dependency order, a wipe skipped as redundant beside a records delete. Slash-invoked only, and its frontmatter blocks model invocation — a deletion never fires from a phrase |
| `lane-record-sync` | — | Reconciles every lane's records at once, from the main checkout: conflicts between lanes are mediated with the user, work one lane's plans imply for another is presented for an explicit ruling — accept, accept as critical, defer or decline, the last two differing in whether the next run asks again, and what is approved is appended to the addressed lane's **transfer queue** — never to its records. Expensive, and slash-invoked only so it can never fire from a phrase or a batch. The mechanism is `wss/docs/annex/WSS.LANE-SYNCHING.md` |
| `contracts` | — | States how the suite is wired — that the skills are global, that project facts come from `.claude/WSS.WORKFLOW.json`, what a project without a manifest falls back to, and where the contracts resolve in a checkout versus a plugin install. It exists because a plugin root's `CLAUDE.md` is never loaded, so an adopter who installs rather than clones would otherwise see none of it |
| `pair` | — | States how two sessions share one checkout as designer and executor: which of them may write what, and how planning content crosses between them as whole files through a relay directory rather than over a message channel that proved unreliable. It owns the protocol and runs nothing — the loop's consume step belongs to `--wss-wrap`, behind the `paired-sessions` toggle. Flagless, because a role is read at session start rather than invoked |
| `skill-toggle` | — | Toggles what each skill costs at session start: shows every skill's current `skillOverrides` level, then sets `on`, `name-only`, `user-invocable-only` or `off` in the user's `settings.json` — refusing a level that would break a skill another skill dispatches to, and warning when a change silences a flag. Slash-invoked only, its frontmatter blocks model invocation, and it is the checkout form's lever: the harness ignores overrides for plugin skills |
| `wrap` | `--wss-wrap` | Closes out a session — task list, the handoff through `handoff-writer` (a full-section rewrite spliced in by `wss-handoff-state.sh`, never a read of the old file), the commits and push through `git-writer`, asks `--wss-plan` whether a milestone just finished, and from a lane worktree syncs that lane forward before it reports anything, then lands it on `WSS.branch.integration` by fast-forward — both refused rather than forced, and the landing withheld entirely when the wrap fired on an unfinished session. Its whole mechanical block — dirty files, unpushed commits, the record counts, open decisions, the roadmap's next block, the sweep line, the always-on delta — comes from one call to `wss-wrap-status.sh`; the model adds only the judgment lines. Reports where the project stands in the reply (TODO list items left, decisions nobody has made, the next goal and milestone, and how far each sweep's baseline has fallen behind `HEAD` — read from the checkpoint, never written to it), and says when it is safe to clear |
<!-- wss:region-end -->

---

## The record procedures

In `wss/workflow/writers/`, **not** in `skills/`. A caller reaches one by reading
the file — there is nothing to invoke, and nothing loads unless a caller opens
it. A description costs every session whether or not the skill is used, and
each of these is invoked only by other skills — so they are procedure files
rather than skills. Ownership is unaffected by the location —
`wss/workflow/WSS.OWNERSHIP.md` is still the authority, and `wss/workflow/writers/WSS.WRITERS.md`
is their index.

<!-- wss:region entry=table-row -->
| Procedure | Sole writer of | What it does |
|---|---|---|
| [`audit-writer`](../wss/workflow/writers/WSS.AUDIT-WRITER.md) | `WSS.record.stocktake`, `WSS.record.audits` | Writes the stocktake log entry — what a stocktake examined, against which tree, and what it found, with its coverage block — plus the one-field `Outcome` update when remediation lands, which is why it is not part of `--wss-stocktake`. Also appends the index row in `WSS.record.audits` when an independent audit pass lands |
| [`behaviour-writer`](../wss/workflow/writers/WSS.BEHAVIOUR-WRITER.md) | `WSS.record.behaviour` | Writes the record of what the system does at runtime, by topic. Never *why* it does it, which is `--wss-log`'s. Reached by dispatch from a check or a build, or directly through `--wss-describe` |
| [`changelog-writer`](../wss/workflow/writers/WSS.CHANGELOG-WRITER.md) | `WSS.record.changelog` | Writes the changelog entry for a version, and marks an entry unreleased when the documents claim more than the tags do |
| [`docs-writer`](../wss/workflow/writers/WSS.DOCS-WRITER.md) | the documentation site | Writes every page and annex page, their `_sidebar.md` and `index.md` rows, the translation mirrors, and the diagrams inside them — re-rendering a diagram a caller hands over rather than reshaping it. It decides nothing: whether a subject earns a page, which page, and which tier are settled by `--wss-docs` before it is called, and a target contradicting the taxonomy is handed back rather than quietly relocated |
| [`git-writer`](../wss/workflow/writers/WSS.GIT-WRITER.md) | commits and tags | Makes the commits, the tags and `--wss-pr`'s merge for every skill that may, so the rules that keep a commit, a merge or a push safe live in one file rather than in whichever caller remembered them |
| [`handoff-writer`](../wss/workflow/writers/WSS.HANDOFF-WRITER.md) | `WSS.record.handoff` | Writes the handoff a fresh session inherits, at whatever scope its caller asked for |
| [`manifest-writer`](../wss/workflow/writers/WSS.MANIFEST-WRITER.md) | `.claude/WSS.WORKFLOW.json` | Writes `.claude/WSS.WORKFLOW.json` — validates each key against `wss/workflow/WSS.MANIFEST.md`, refuses one nothing reads or whose path does not resolve, and runs the doctor. Decides nothing: the caller arrives having settled the values |
| [`reference-writer`](../wss/workflow/writers/WSS.REFERENCE-WRITER.md) | `WSS.record.reference` | Writes the record of what the system *is* — stack, architecture, data model, stated conventions. Often the project's `README.md`, where the manifest maps it there. Reached by dispatch from a check or a build, or directly through `--wss-reference` |
| [`sweep-tracker`](../wss/workflow/writers/WSS.SWEEP-TRACKER.md) | the sweep checkpoint | Records which commit each sweep last verified and what it covered, so the next one re-reads only what changed. It refuses a stamp claiming a commit with no coverage — except a freshness-only entry, which claims none and licenses nothing |
<!-- wss:region-end -->


---

## The shared check methods

In `wss/tests/`, **not** in the skills that wrote them. Each is one way of
finding inconsistency in something the project has written down, or the structure
that will produce one; the skill that runs one supplies the scope and decides
what happens to a finding.

Each is single-sourced here because a method borrowed by **citing another
skill's headings** breaks silently on a rename, leaving the borrower reporting
success over checks it never ran; `wss-doctor.sh`'s section-citation check polices
the citations that remain.

**Which methods exist, what each finds and what runs it is
[`wss/tests/WSS.CHECKS.md`](../wss/tests/WSS.CHECKS.md)'s "Method and
runner" table** — that file is the list, and this catalog does not carry a second
one. It also holds the line between the two: **a method says what counts as a
finding; a runner decides scope, disposition and owner** — material that drifts
to the wrong side of it stops being borrowable.

---

## TODO list providers

In `wss/workflow/providers/`. `WSS.record.todo` is normally a path; a project whose
TODO list already lives somewhere else declares a provider object instead. Nothing
else in `WSS.record.*` takes one.

**Every skill that touches the TODO list goes through the provider, not just
`--wss-todo`** — `--wss-adopt` offers the choice and `manifest-writer` validates it,
`--wss-start` and `--wss-check` and `--wss-full-check` read it, `--wss-wrap` counts it. None of
them may read a local file instead when the remote is unreachable; they say so
and write nothing.

<!-- wss:region entry=table-row -->
| Provider | Declared as | Contract |
|---|---|---|
| GitHub Issues | `{ "provider": "github-issues", "repo": "owner/name", "label": "backlog" }` | [`WSS.GITHUB-ISSUES.md`](../wss/workflow/providers/WSS.GITHUB-ISSUES.md) |
<!-- wss:region-end -->

**A declared provider is never a silent fallback to a file.** `wss-doctor.sh` fails
on one nothing implements, on a missing `repo`, on a repo that does not
resolve, and on a declared `label` no label on the repo matches; it warns when
`gh` is absent or unauthorized, which is a fault of the machine rather than the
manifest. The reasoning behind an item still goes to
`WSS.record.decisions` — a file — because an issue thread is a conversation and a
decision log is read months later.

## Agents

<!-- wss:region entry=table-row -->
| Agent | What it does |
|---|---|
| `wss-release-prep` | Prepares a release's material for `--wss-release`: the version tier it proposes and which trigger fired, the changelog entry text in the voice of the entries above it, and any drift between what the release list and changelog claim shipped and what a tag actually resolves. Reads the release list, the roadmaps the milestone cites, the changelog, the TODO list, the audit log and the git history — several thousand tokens that stay out of the caller's context. It writes nothing, tags nothing and publishes nothing. Declared as `WSS.agents.release`. Like the analyst the assignment table puts it at the top tier — its output is what `--wss-release` then acts on — which is spelled by carrying **no** `model:` key. **This one travels** |
| `wss-survey` | The agent form of [the dispatch ladder's](../wss/workflow/WSS.DISPATCH-LADDER.md) Survey rung: handed a read set and a verdict format, it returns `file:line` verdicts and nothing else. Holds `Read, Grep, Glob, Bash` — no write tool, so "readers report, they do not write" is enforced by the grant rather than asked for, and no `Agent` tool, so it cannot report delegated coverage as its own. Carries the brief contract the callers used to each restate. Declared as no role: callers name it directly, which is a clarity choice rather than a saving, since an undeclared role routes to its rung's own agent rather than to `general-purpose`. Its `model:` is resolved by the dispatch ladder's assignment table at the bottom tier and copied into the file, so a caller naming it need not — and should not — pass an override. **This one travels** |
| `wss-analyze` | The Analyze rung: it chooses its own read set against an open question and returns the plan, finding or artifact citation another rung then works from. The top tier, because its output is the authority someone else acts on and because choosing a read set is the expensive judgement the cheaper rungs are defined by not making. Holds `Read, Grep, Glob, Bash` and writes no files. The ladder's assignment table puts it at the top tier, which is spelled by carrying **no** `model:` key at all — omitting it inherits the caller's own model — and its body says so to stop the absence reading as an oversight. **This one travels** |
| `wss-design` | The Design rung: handed a settled brief, it produces the design — an interface, a shape, a file-by-file sequence — and stops there without implementing it. Same grant as the surveyor and the analyst, and the same no-write property; what separates it from Analyze is that its scope arrives rather than being chosen. The assignment table puts it at the standard tier — the only agent there — and its `model:` is copied from that row. **This one travels** |
| `wss-execute` | The Execute rung: it applies a design handed over as an artifact, file by file, without surveying the tree or judging whether the design is right. Holds `Read, Edit, Write, Bash` — deliberately no `Grep` or `Glob`, so it structurally cannot survey — which makes it the narrowest grant in the suite that can still write. Carries an explicit stop-and-report on any premise the design leaves missing, and a falsification line, so a precise-but-wrong brief fails loudly instead of being executed faithfully. The assignment table puts it at the bottom tier alongside the surveyor, and its `model:` is copied from that row. **This one travels** |
| `wss-rules-writer` | The rulebook's own writer, scoped strictly to `wss/rules/` — a write outside that tree is not a path its tool grant can reach, rather than a rule it might break. Receives a complete rule row with every field already decided by a Design dispatch or a caller; deciding a field itself is explicitly out of scope, which is what keeps it strict by construction rather than by brief. Holds `Read, Edit, Write, Bash`, and validates every row it writes with `wss-rules-checkup.sh`, stopping at the first failure rather than writing on. Assignment table puts it at the bottom tier alongside the surveyor and the general executor, and its `model:` is copied from that row. Shipped 2026-08-17; not yet exercised — the agent registry loads at session start, so the session that creates an agent cannot dispatch it |
<!-- wss:region-end -->

The remaining `agents.*` roles in the schema stay something an *adopting* project
declares. What a skill does with a role no manifest declares is
[`WSS.MANIFEST.md`](../wss/workflow/WSS.MANIFEST.md)'s `agents` section, and a second
copy here would drift from it.

## Scripts

<!-- wss:region entry=table-row -->
| Script | What it does |
|---|---|
| `wss/tests/wss-doctor.sh` | Read-only health check of this config and the project in the working directory. Prints every check it performs except the note class, which is counted in every run and printed only under `--notes`; the summary always says how many notes were withheld and how to see them, so the list cannot go stale silently |
| `wss/scripts/wss-tools-inventory.sh` | Walks a tooling surface — this installation's own, by default — and writes `.claude/WSS.TOOLS.json`, the measured half of what this catalog describes: one entry per skill, agent, script, hook, command, check, writer, contract and skill reference, carrying its description cost, tool grant, ownership tier and grant, its invokes/invokedBy edges and its same-window chain size. Facts only — what a tool is *for* is judgment and stays here. Dependencies are named rather than located, since a name is already the identifier the harness dispatches by and a `path:line` is what drifts. `--check` regenerates to a temp file and diffs, failing on any difference, which is why the output is deterministic by construction — no timestamps, no absolute paths, everything sorted — and why the artifact is tracked rather than derived on demand. `--root` points the *enumeration* at a different tree, for a caller that needs a project's own skills measured rather than the suite's — `wss-doctor.sh` uses it on a project-local skill, which it could previously only report as unmeasured. What `--root` deliberately does not move is where contracts are looked up: a project's skills cite the suite's `workflow/`, so classification stays anchored to the installation, and repointing it too would report every chain as just the file's own bytes. Such a run prints and never persists, since this artifact names this suite's entries only; an unresolvable `--root` exits non-zero rather than measuring nothing, an honest notice being better than a confident wrong figure. It carries the chain walk that used to live in `wss-doctor.sh`, so that figure now has one implementation instead of two; editor and backup residue is excluded, since a stray file measured once becomes a committed entry no fresh clone can satisfy. Writes its artifact and stops: it holds no commit grant, and whoever invoked it commits. **This one travels**, and `wss-publish.sh` regenerates it against the assembly rather than shipping a copy that describes the private tree |
| `hooks/wss-tools-inventory-hook.sh` | The `PostToolUse` hook that regenerates that inventory when a tooling file of *this installation* is edited — anchored to the installation first, then a deliberately loose filter within it, since a file outside cannot be one of these tools whatever it is named. Runs synchronously and is never backgrounded: a regeneration racing the doctor's own staleness check is the failure the arrangement exists to avoid. It is the convenience layer and not the guarantee — `wss-doctor.sh` is what makes staleness impossible — which is what lets the filter be loose, because a false match costs one wasted run and a missed one costs nothing. Silent unless it fires, and exits zero whatever happens, so it can never block a tool call |
| `wss/scripts/wss-append-only.sh` | Fails any change that deletes a line from a record `WSS.recordMode` tags `log`. Resolves that set from the manifest rather than from a path, so it needs no directory layout and an adopted project inherits it by declaring its own modes; a record tagged `generated` is out of scope by its tag rather than by an exemption on its name. Three deletions are legal and each is a clause of `wss/workflow/WSS.RECORD-CONTRACT.md` — a record's header, an `Outcome:` block, and the draft entry at either end where the same hunk rewrites it — chosen by measuring every commit that has ever deleted from a log rather than by reasoning. Two checks run regardless of line counts, since a `--numstat` predicate alone misses both: an entry count that falls, and a record that disappears. Runs as a CI step and, via `--install-hook`, as a `.git/hooks/pre-commit`; the hook is per-clone and untracked, so **CI is the enforcement and the hook is the early warning** — and `wss-doctor.sh` warns where this clone has no hook installed, so a clone guarded by CI alone is reported rather than indistinguishable from a guarded one. **The two venues hand it different evidence and can reach opposite verdicts**: pre-commit sees `--staged`, which is one appended entry, while CI sees `--base origin/<publish>`, which is every entry the branch has added since the merge base. A defect in how the exemptions attribute lines to entries can therefore be structurally invisible to the venue that runs on every commit — demonstrated on 2026-08-16, when a single-heading anchor passed every commit and failed CI. Its contract tests are `wss/tests/wss-append-only-test.sh`. Resolving zero log records is a hard failure, not a clean pass |
| `wss/scripts/wss-commit-provenance.sh` | Makes a record-touching commit declare which records it writes and under whose authority, so the ownership matrix is enforced rather than merely documented. The declaration is a delimited block in the commit message: `prepare-commit-msg` emits it, `commit-msg` asserts it, and the author writes freely before and after — only the block's interior is fixed, which is what a trailer could never offer, since humans and tooling both reflow a trailing line. A commit touching no record is silent. It **catches mistakes rather than misconduct**, the authority being self-declared: what it sees is a session writing a record from the wrong skill, which is the one failure no tree-level check can reach, having no baseline to diff against. In scope means declared *and* claimed — a path reaches it only through a manifest key the matrix names a sole writer for, so a file present in the manifest under some other key is silent by declaration rather than by exemption. One record spanning several files is one line with several paths; one file claimed by two records is two lines, with no arbitration. It also owns the sole-writer matrix parser `wss-doctor.sh` once held inline, which the doctor now calls out to so the two cannot drift. Like the append-only guard, `--install-hook` is per-clone and untracked, so CI remains the enforcement and the hook is the early warning |
| `wss/scripts/wss-rules-checkup.sh` | Resolves a consumer's rule-file set from `wss/rules/WSS.RULES-INDEX.md`'s consumer table, cats those files, and stops — the mechanism the rulebook goal's index describes as how a consumer is meant to read its rules: `wss-rules-checkup.sh <consumer>` resolves, cats, exits 0. Fails loud on exactly three conditions: an unresolvable consumer, a file the table resolves to that does not exist, and a consumer whose file list is empty — closing what the design calls "a fourth silent-failure path beside the three already on record," alongside `wss-commit-provenance.sh`'s missing/`UNDECLARED`-authority NOTICE-and-exit-0, the three per-clone untracked git hooks, and `wss-session-check.sh`'s `trap exit_clean ERR`. No caching: the index is read fresh every call, deliberately, since a cached copy is an unpoliced one. `--json <consumer>` fails loud naming that `WSS.RULES.json` (the generated twin for shell arbiters) does not exist yet rather than silently no-op'ing — its generator is separate, undesigned follow-on work. Ships with `wss/rules/` itself, built with no rows in any judge file — nothing cites either yet, so both stay reversible. Shipped as the roadmap's "Rules that can be looked up" goal, third block, 2026-08-17 |
| `wss/scripts/wss-rules-truncate.sh` | Strips the rows from an adopted rulebook and keeps everything else — the "structure only" half of the adoption choice `--wss-adopt` step 9c carries out. Dry-run unless given `--write`, with `--dir` for a tree other than the cwd. **Every file and every non-row section survives**: `wss-rules-checkup.sh` resolves a consumer to a file set and then checks those files EXIST, so deleting one breaks every consumer naming it — what the adopter receives validates on arrival and is ready for their first row. A row is a `### <ID>` heading matching the schema's id grammar and the block under it; anything else is a section and stays, and fenced blocks are skipped so the index's own worked example survives. **Takes its file list from the directory, not from the consumer table** — that table names five consumers resolving to eight files, while `WSS.RULES-HOOK.md` and five of the six `prospective/` files are named by no consumer at all, so a table-driven list would leave their rows behind as the fill grows. Not part of `wss-reset-records.sh`, which reads only the shipped manifest and guards on `type == "string"`: `WSS.record.rules` is an array in `.claude/WSS.LOCAL-RECORDS.json`, which `wss-publish.sh` deletes before Gate 2, so an adopter's checkout has no key that could reach the rulebook |
| `wss/scripts/wss-resolve.sh` | Resolves a `KEY[#fragment]` citation to a `path:line`, implementing `wss/workflow/WSS.ADDRESSING.md` and stating none of it. Reads three registries — the shipped manifest, `.claude/WSS.LOCAL-RECORDS.json`, and the generated `.claude/WSS.TOOLS.json` — walking `WSS.record` recursively, so a nested key like `tooling.catalog` resolves and an array-valued key answers with its whole set rather than one member. **A key resolving differently in two registries is a hard failure naming both**, never a precedence question; an array inside one registry is a set and not a conflict. A `log` record's fragment resolves through the decisions index — which is a lookup rather than the destination, since each row carries the entry's line in the log. Runs `wss-tools-inventory.sh --check` before trusting the inventory and refuses on a stale one. `--check` fails only on fragment-bearing citations, and counts bare tokens that resolve to nothing without failing them, because the scheme has no syntax separating a citation from a mention of a manifest key. `--open-loops` is deliberately absent |
| `wss/scripts/wss-toggle.sh` | Reads the project's toggles out of `WSS.record.setup`'s `## Toggles` table — the one parser, so a second consumer is not a second thing to drift. Bare call prints every toggle as `name<TAB>value`, a named call prints one value and exits 1 where the toggle has no row, and `--on <name>` exits 0 only where the value is `on`. **Absent means off everywhere**: no row, no table and no script all read the same way, so no consumer has to distinguish them and only an explicit named lookup reports absence. The whole table is the default output because `wss-doctor.sh` is forked ~144 times by the contract suite — a consumer shelling out per toggle pays that per toggle per fork, so the doctor takes one call and parses it once. Resolves the record through the manifest, so an adopter's own path is honoured, and reads correctly from a blanked record because the region markers survive `wss-reset-records.sh` |
| `hooks/wss-shorthand-flags.sh` | The `UserPromptSubmit` hook that turns a `--flag` into a deterministic skill invocation rather than a judgement call |
| `hooks/wss-session-check.sh` | The `SessionStart` hook, and the only thing here that speaks without being asked — so it is built to stay silent unless it has something worth a session's attention: a doctor failure, a sweep or a record gone stale, a filed bug report, an unread upstream filing (counted only in the suite's own checkout, where triage can act), a handoff the harness would not otherwise load, the setup record where a project declares one — per-machine facts and toggles, injected whole, size-capped by the doctor — or a one-time orientation block on the first session after a plugin install, since a plugin has no channel to speak at install time |
| `hooks/wss-alert.sh` | A sound cue when a session waits for input — permission prompts, option pickers, idle, turn end. Ships silent and opts in per machine: `--wss-alerts on\|off` (served by the flag hook, no skill) toggles a state file in the config directory that this hook gates on. Sound only, cross-platform, one cue per burst |
| `hooks/hooks.json` | Declares the same events for a **plugin** install, where `settings.json` is the user's and a plugin never owns it. Plugin hooks merge with the user's rather than replacing them |
| `.claude-plugin/plugin.json` | The manifest that makes this directory installable. `claude plugin validate` reads it |
| `wss/scripts/wss-reset-records.sh` | Blanks every record the manifest declares back to its canonical heading — a fresh start with the structure kept and the content gone. Dry-run unless given `--write`. Skips a `WSS.record.todo` that names a provider rather than a file, and never touches `WSS.record.reference` or `WSS.record.tooling.catalog`, which describe the tooling rather than the project. **This one travels**, and `wss-publish.sh` runs the copy of it rather than keeping a second list |
| `wss/scripts/wss-export-records.sh` | Moves machine-local workflow state between machines — untracked record files, the lane selector, and the config directory's bug-reports inbox. Skips tracked records and the sweep checkpoint — except under `--all`, the retirement snapshot `/wss:retire` takes before deleting, which keeps tracked records in and adds the docs tree. Import is all-or-nothing, refuses escaping entries, and refuses non-empty collisions without `--force`. **This one travels** |
| `wss/scripts/wss-retire-workflow.sh` | The tidy exit: removes the suite's machinery from a project — manifest, sweep cache, lane selector — and, only behind `--write --records`, the workflow-shaped records. Never touches the reference, changelog or tooling files, a CLAUDE.md handoff, or the suite's own tree. `--suite` is the other direction — the installation rather than a project: it names any plugin install for the harness to uninstall, deletes a checkout by `git ls-files` keeping `CLAUDE.md` and `settings.json`, and reports what a running script cannot unlink for the user to remove by hand. Dry-run by default. `/wss:retire` is the walkthrough around it. **This one travels** |
| `wss/scripts/wss-remove-lanes.sh` | Turns worktree-lane mode off for one checkout: deletes `.claude/WSS.LANE` and drops `WSS.lanes.named` and `.conflicts` from the manifest. Keeps `WSS.lanes.exclusive`, `.serialize` and `.generated`, which drive the partition `--wss-start`'s Phase 3 makes inside a single checkout — the rules themselves are `wss/workflow/WSS.FAN-OUT.md`'s — and are not worktree machinery. Deletes no record under any flag — a lane file holding content refuses the write until `--allow-orphans`. Dry-run by default; refuses an untracked or uncommitted manifest so the rewrite stays revertible. **This one travels** |
| `wss/scripts/wss-tree-survey.sh` | Prints one adopted tree's own properties, read-only, run by hand from inside it: adoption state and manifest schema — including a pre-rename `.claude/workflow.json`, which every other current reader sees as cleanly absent — then lanes, TODO list as file or provider, behaviour record, `WSS.localCI`, branches, commands and declared agents, an exists/missing roll of every declared record, and a bounded `wss-doctor.sh` tail with its exit code reported separately. It names what it could not read instead of leaving a row blank. Exists so a surface can be mapped to a tree that can exercise it, from that tree's manifest rather than from its name. **This one travels; its output does not** — a survey names a private project's paths and record layout, so it is never routed through `--wss-report` or any issue |
| `wss/scripts/wss-survey-all.sh` | Runs the surveyor over every adopted tree under the roots it is given — both manifest filenames, so a pre-rename tree is found rather than passed over — writing one survey per tree outside every tree, then printing what a stack of individual surveys cannot say. **It counts projects, not directories**: worktrees are grouped by resolved git common directory and the main checkout is the member every surface is read from, because a lane worktree named as the candidate sends a reader to a project that does not exist. Unread probes travel into the summary as flags, so a doctor that never ran or a TODO list `gh` could not read never reads as a clean result. The rollup is taken from each project's manifest rather than from the survey text, distinguishes no candidate from unread, and prints `/wss:retire` as undetectable rather than inferring intent no key records. **This one travels; its output does not**, and less than the surveyor's — one file names every private tree on the machine |
| `wss/scripts/wss-duplication.sh` | Emits the deterministic half of two sweeps so a model pays only for the judgment: repeated paragraphs across the declared tooling globs, and lines carrying the shapes a mutable claim tends to take. Read-only, and it decides nothing — the repeats feed `wss/tests/WSS.ROT-RESISTANCE.md`'s uncompared-second-copy lens and `WSS.TOKEN-ECONOMY.md`'s extraction lens, the claim candidates feed `WSS.TOOLING-CLAIMS.md`, and each method keeps its own verdict. **Matching is normalised-exact rather than fuzzy**, deliberately: a similarity score would find more and would not reproduce run to run, which turns a sweep input into permanent noise — so a paraphrase is a miss by design and the reading pass stays the authority above it. Its claim patterns were tuned against this tree's own measured hits rather than intuition, and the two that were cut for precision are named in the script so nobody re-adds them believing they were overlooked. Globs come from the manifest, never from this script; a project declaring none is refused rather than swept against a guess, since silently sweeping a default would report coverage the manifest never claimed. `--scope` chooses which manifest keys supply them: `tooling` (the default, `WSS.record.tooling.sources`), `records` — every key `WSS.recordMode` tags `register`, resolved through `WSS.record`, so a moved record is followed rather than missed — or `all`. Logs and generated files are deliberately out of every scope: a repeated paragraph in an append-only log is history, and a generated file is rewritten wholesale from its source, so hits in either are unactionable. `--paths` takes an explicit glob for a one-off and is deliberately not the default, because a path typed on a command line is a fourth place the record set is written down. **This one travels** — it hard-codes no path and serves methods that ship, so an adopted tree gets the same pre-filter this one does |
| `wss/scripts/wss-mechanical-gauntlet.sh` | Runs the mechanical gauntlet in one call — `wss-doctor.sh`, `WSS.commands.typecheck`, the full `WSS.commands.test` suite and CI resolved against `WSS.commands.ci` — and prints the verdict block, so a runner stops retyping four commands it would otherwise re-emit into Bash on every audit. `wss/tests/WSS.MECHANICAL-GAUNTLET.md` stays the contract and keeps every call the script deliberately does not make: whether the user was asked for consent, and whether a carry-forward is licensed. Those arrive as `--test-consent` and `--carry-forward REASON`, and the consent flag is required only where the project declares `WSS.commands.testConsentEnv` — a project without one is not gated by a gate it never set. Resolves the doctor beside itself rather than through `$HOME`, so it reads a plugin cache and a checkout alike, and re-runs a failing suite once before calling it a finding. Exits non-zero only on a real failure: an undeclared command or an unrun suite is reported, never failed. Invoked by `--wss-full-check` and `--wss-stocktake` |
| `wss/scripts/wss-sweep-stamp.sh` | `sweep-tracker`'s implementation for the checkpoint the manifest declares as `WSS.sweeps`. Three shapes — a freshness-only entry, a test-run entry, and a scoped one taking its coverage lists from a file — and it **computes the baseline itself** from the working tree rather than accepting one as an argument, which is what makes a stamp misreporting the commit it claims structurally impossible instead of merely discouraged; the `+dirty` suffix is derived the same way, so a stamp cannot silently claim a clean tree. Refuses rather than half-writes: an empty or missing scope list, a malformed or duplicated scope, a checkpoint path that is not gitignored, an existing file that is not the expected JSON shape, no `jq`. Merges only the named entry and leaves every other one byte-identical. Deciding *what* was covered stays the caller's judgment and is deliberately not in here. Invoked by `sweep-tracker` |
| `wss/scripts/wss-docs-audit.sh` | The mechanical half of `wss/tests/WSS.DOCS-AUDIT.md`, as named subcommands run singly or all in order — resolve the project's shape, then the dead-path, link, type, translation-parity, index-parity, mechanics and accuracy checks. Resolves the docs root, the languages and the dev command from `WSS.docs` with its declared fallbacks, so it reads an adopted tree's own layout rather than guessing at one, and short-circuits every check to a named skip where no root resolves — walking an empty set and reporting a clean site is the one failure that method cannot survive silently. The method file keeps what a finding *means* and what makes a hit a false positive. Invoked by `--wss-docs` and `--wss-full-check` |
| `wss/scripts/wss-gen-lane-rulings.sh` | Derives the copy of the four-rulings table inside `wss/docs/annex/WSS.LANE-SYNCHING.md` from its canon in `skills/lane-record-sync/`, resolving that canon by content rather than by a pinned path so a file move does not silently stop it deriving. The bare form rewrites the generated block between its markers; `--check` derives to a temp file and diffs, which is what `wss-doctor.sh` runs so the annex copy is verified by regeneration rather than by a reader asserting the two agree. The canon's trailing intra-document "see below" is stripped as part of deriving, so a navigation aid local to the skill file never registers as drift. This is the copy the annex needs because `workflow/` sits outside the docs site's docsify root, where a pointer would leave the site rather than cost a click |
| `wss/scripts/wss-gen-cadence-flags.sh` | Reproduces `README.md`'s cadence Flag column from `skills/adopt/SKILL.md`'s card and reports which flags have drifted. **Check-only by design, and the refusal is the feature**: `--write` exits 2 saying `README.md` is a declared record whose sole writer is `reference-writer`, because a generator writing there would be the second writer that `wss-doctor.sh`'s sole-writer check exists to prevent. That is what lets a record carry a derived copy at all — the command reproduces it for comparison, and the record's own writer applies whatever the comparison reports |
| `.claude-plugin/marketplace.json` | Makes the same directory its own marketplace, listing one plugin whose `source` is `"./"` — so there is no second repository to keep in step. Handed a directory holding both, `claude plugin validate` checks this one and not the other; name the file to check the other |
| `skills/docs/assets/wss-scaffold.sh` | Creates a docsify site shell and only the shell, never content. Refuses to touch an existing directory, and prints the steps it deliberately leaves to its caller. Takes the site's root from `WSS.docs.root` and its languages from `WSS.docs.languages` rather than as arguments — `--root` and the positional language list override, each origin is announced on every run, and absent still means monolingual — which makes it the one skill asset that reads the manifest. A declared `languages` that is not a non-empty array of non-empty strings exits before anything is created, naming the key; an unparseable manifest is a different answer and stays a fallback, reported once. Invoked by `--wss-docs` in Scaffold mode |
| `skills/record/assets/wss-index-decisions.sh` | Generates `WSS.record.decisionsIndex` from the decision log — one row per entry, line number and heading — and verifies it without writing under `--check`. Declared as `WSS.commands.indexRegen` / `WSS.commands.indexCheck` in this repo's manifest; refuses to run where the index key is undeclared |
| `skills/overview/assets/wss-probe.sh` | Emits `--wss-overview`'s whole mechanical block in one read-only call — tree, record counts, doctor result, sweep freshness, the roadmap's current goal, the release list's current milestone, and whether a release is in flight — so the report costs seconds instead of a model read of every record. The release comparison reads the plugin manifest's version against the newest tag and distinguishes both absences, since no tag and no plugin manifest are different facts and neither is "nothing in flight". Offline by design: external state is reported as not counted, never as zero. Invoked by `--wss-overview` |
| `skills/overview/assets/wss-sweep-distance.sh` | How far each sweep baseline sits behind `HEAD` — the single implementation, with two renderings: `--verbose` for `wss-probe.sh`'s `== sweeps ==` block, one entry per line, and `--compact` for `--wss-wrap` step 7's closing line. Read-only and offline — measuring a baseline is not advancing one, which stays `sweep-tracker`'s. **The figures are a report and never a gate**: every path exits 0, no checkpoint and an off-history baseline included, and only a usage error is non-zero |
| `skills/start/assets/wss-orient.sh` | Emits `--wss-start` Phase 0's whole mechanical block in one read-only call: the tree pin, CI where the manifest names a workflow, each planning record's resolved path, whether it exists and its size, the open-decisions entry count, and the sweep distances — which it delegates to `wss-sweep-distance.sh` rather than computing a second time. **It reports facts and never their meaning**: it opens no record's contents, so Phase 0's own read of the three planning records is never made optional by it. Honours a `.claude/WSS.LANE` selector through `WSS.lanes.named.<lane>.records.*`. Degrades rather than misreports — an unreachable CI reads as not checked, never as green or zero. Invoked by `--wss-start` |
| `skills/wrap/assets/wss-wrap-status.sh` | Emits `--wss-wrap`'s whole mechanical block in one call: dirty files, unpushed commits, how far ahead of `WSS.branch.publish` the branch sits, the four record counts, open-decision titles, the roadmap's next unchecked block, whether the last block of a goal just closed, the sweep line, and the always-on-bytes delta against the last wrap — reusing `wss-sweep-distance.sh` and `wss-audit-assets.sh --always-on-basis` rather than reimplementing either. Resolves every record path from the manifest, and honours a `.claude/WSS.LANE` selector through `WSS.lanes.named.<lane>.records.*` overrides. **A report, never a gate, on the same contract as `wss-sweep-distance.sh`**: it always exits 0. **Read-only except for one file it owns outright** — `.claude/WSS.ALWAYS-ON-STAMP.json`, gitignored and machine-local, the baseline the next run's delta is measured against; it stages, commits, pushes and advances nothing. Offline by design: external state it cannot reach is reported as not counted, never as zero. Invoked by `--wss-wrap` |
| `skills/wrap/assets/wss-handoff-state.sh` | `handoff-writer`'s implementation for `WSS.record.handoff` and `wss/records/WSS.HAZARDS.md`. Three subcommands: `state <handoff-file> <content-file\|->` wholesale-replaces everything between the `<!-- handoff:card-ends -->` marker and the `## Where everything else is` heading, without reading the old body; `hazard-append <file> <anchor> <entry-file\|->` and `hazard-delete <file> <anchor> <pattern>` operate on a `## `-heading section, each anchor required to occur exactly once and in order. Every write is checked against the 4,096 B card cap before it lands; writes are atomic and preserve permission bits, and any violation aborts with the file byte-identical. Invoked by `handoff-writer` |
| `skills/skill-toggle/assets/wss-skill-levels.sh` | Emits `skill-toggle` step 1's whole level table in one call: every skill directory under both `skills/` trees, its effective `skillOverrides` level, which settings file set it, which tree it came from, and whether its own frontmatter hides it — the resolver `hooks/wss-shorthand-flags.sh`'s `skill_disabled()` uses, project settings then user settings, first file that names the skill winning, and never `settings.local.json`. It **refuses rather than rendering a table it cannot trust**: no `jq`, a settings file that is not valid JSON, or no skills tree at all exits 1 with the reason, because a level table read as "nothing is overridden" is what a wrong edit is then made against. Lists any `CLAUDE_PLUGIN_ROOT` skills separately as not controllable here. Read-only. Invoked by `skill-toggle` |
| `wss/workflow/writers/assets/wss-git-commit.sh` | `git-writer`'s implementation. `--files PATH` (repeatable, at least one required), `--message`, `--session`, `--coauthor`, `--trailer-key`, and an optional `--push REFSPEC`. Stages by exact name, structurally — a file list cannot become `git add -A` — assembles and verifies the trailer paragraph via `%(trailers:key=…)`, refuses a refspec with a leading `+` before touching git, and hands a push rejection back rather than retrying or forcing it. No default trailer key and no model name anywhere in it: every project and session fact arrives as an argument. Invoked by `git-writer` |
| `wss/tests/wss-hook-contract.sh` | The contract tests for the hook, whose breakage is total and silent |
| `wss/tests/wss-append-only-test.sh` | The contract tests for `wss-append-only.sh`, which had none until 2026-08-16 — `wss/records/WSS.RELEASES.md` had been recording their absence. Builds a throwaway git repo per case and never touches the checkout it runs in. The cases that matter are the ones covering exemption 3's anchor when a change adds MORE than one entry, which is the shape a branch measured against its merge base always has and a single commit never does. **`WSS_APPEND_ONLY_BIN` points it at another build of the guard** — `git show <ref>:wss/scripts/wss-append-only.sh` to a temp file — which is the difference between asserting a regression case and demonstrating it, and the only way to tell a case that discriminates from one that passes whatever it is run against. One case is deliberately kept while labelled in place as *not* testing what its name suggests, rather than deleted for passing. Invoked by `WSS.commands.test` and by its own CI step |
| `.github/workflows/publish.yml` | Fires on a release-tag push, and on manual dispatch — which is how a publication is staged when the public repo has drifted behind `dev` without a tag. Runs `wss-publish.sh` and stages the gated assembly as a PR on the public repository, never a merge. It asserts the pushed tag against `.claude-plugin/plugin.json` first, and reports rather than refuses on a dispatch run, where there is no tag to assert against. Needs the `PUBLISH_TOKEN` secret; removed from the assembly so it never ships |
| `.github/workflows/verify.yml` | CI. Runs `wss-doctor.sh`, the two contract suites — the hook's and the append-only guard's — and the static checks the workflow file itself enumerates. Runs on a push to any branch except `main`, on every pull request, and on manual dispatch — `main` is reached only through a PR, and on the published repository `main` additionally requires that PR run to be green before it can be merged |
<!-- wss:region-end -->

## Command wrappers

In `commands/`, one file per verb flag of a multi-verb skill — a flag whose
name differs from its skill's for a reason other than a scope-variant prefix
(`--wss-full-stocktake` gets none). The wrapper's filename **is** the flag, so
the `/` menu autocompletes it and its body fires the flag with `$ARGUMENTS`
appended. The `UserPromptSubmit` hook
does not fire on a wrapper's expanded body — routing rides the flag token plus
the owning skill's own rules — which is why only skill-backed flags get
wrappers and the hook-served ones (`--wss-flags`, `--wss-help`, `--wss-alerts`)
never do. `wss-doctor.sh` asserts every wrapper fires the flag its name promises.

<!-- wss:region entry=table-row -->
| Wrapper | Fires | Routes to |
|---|---|---|
| `commands/todo.md` | `--wss-todo` | `record` |
| `commands/log.md` | `--wss-log` | `record` |
<!-- wss:region-end -->

## Files that are not tools

Worth naming, because they are most of what a reader will otherwise open:

<!-- wss:region entry=table-row -->
| File | What it is |
|---|---|
| `workflow/*.md` | The contracts every skill links to rather than each inventing its own — a few rules are deliberately restated inline where a dispatch site's reader should not have to follow a link, and `wss-doctor.sh` holds those copies in step with the contract; the directory's own listing is the inventory |
| `skills/*/references/*.md` | A skill's own reference material. Nothing here loads at session start — only a `SKILL.md`'s frontmatter does — and nothing here is invocable: the owning `SKILL.md` cites each file at the point its procedure reaches it. Where that skill is a **router** — a short `SKILL.md` whose body is a table of steps, phases or modes, each behind its own reference — the gating is the whole design and is what keeps the always-on chain off the budget `wss-doctor.sh` measures; a mode-exclusive skill genuinely saves, a sequential one mainly stops being charged. That skill file is the inventory, so a reference is never listed twice |
| `CLAUDE.md` | Loaded into every session in every project — the checkout form only, because a plugin root's is never read as project context. Routing and machine-wide rules, kept short because they are paid for in every session; what each contract governs is `contracts`', which owns it |
| `README.md` | How the repo is adopted on a new machine, and how the flags work |
| `.claude/WSS.TOOLS.json` | This catalog's generated twin, written by `wss-tools-inventory.sh` and never by hand. The split is deliberate and is the one-source-of-truth rule enforced by construction: every *measured* fact about a tool lives there, every judgement about what it is for lives here, and this file therefore carries no figures — a number here would be a second copy of one that file already holds. Tracked, because the staleness check that guards it is a regenerate-and-diff and has nothing to compare against otherwise |
| `WSS.BUG-REPORTS.md` | Gitignored inbox for defects found in these files by sessions working in other projects |
<!-- wss:region-end -->
