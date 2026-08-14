# Claude tooling

Every skill, agent and script in this repository, and what each one is for. This
repo is *only* tooling, so this doubles as the overview of what the project is.

`tools` (`--wss-tools`) owns this file and is its sole writer.
`--wss-full-check` hands it back here at the end of every health check, which is what
keeps it from becoming the stale inventory this workflow warns about everywhere
else.

**Where a project has a documentation site**, `--wss-tools` hands this file to
`docs-writer`, which adapts it into a Claude-tooling annex page and owns that page —
`--wss-docs` only where the page does not exist yet and its placement is still open.
This repository's is `docs/annex/WSS.CLAUDE-TOOLING.md`. This file stays the
source — when the two disagree, this one is right.

**What this file deliberately does not carry**: which record each skill may
write, or what any grant permits in detail. That is
[`WSS.OWNERSHIP.md`](../workflow/WSS.OWNERSHIP.md), and a second copy here would drift
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
authorization flow. `--wss-tools` maintains this picture itself, under the
diagram rules whose authority is the docs style guide
(`skills/docs/references/WSS.STYLE-GUIDE.md`, its Diagrams section).

```
                 a flag the user types
                          │
                          │  confers the grant. A skill never widens
                          │  its own, and an invoked skill inherits
                          │  its CALLER's grant, never its own flag's.
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
   │                  toggle             (all slash only)       │
   └───────────────────────────┬────────────────────────────────────┘
                               │
                               │  invokes, passing its grant down
                               ▼
   ┌────────────────────────────────────────────────────────────────┐
   │  PRIMITIVES — a record, the history, or a rule                 │
   │                                                                │
   │    with a flag:  --wss-track    --wss-todo / --wss-log         │
   │                  --wss-plan     --wss-tools    --wss-scout     │
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

**These procedures are not skills.** They live at `workflow/writers/*.md`
and a caller reaches one by reading the file, not by invoking anything — a
skill's description loads into every session whether the skill is used or not,
and each of these is invoked only by other skills, a trigger a description
cannot serve. They are drawn in this box because the tier is the same: one
record each, sole writer, no grant of their own. `workflow/writers/WSS.WRITERS.md` is their index.

**The flagless row cannot be entered from the top**, and that is the point
rather than an omission: a primitive with no flag has no grant of its own to
inherit from, so a caller can never acquire authorization the user did not give
it. Arrows also run the other way — the primitive `--wss-tools` invokes `--wss-docs` —
and reaches `docs-writer` directly — because the tier says what a skill owns, not
who may call it.

**Three orchestrators are flagless for a second reason on top of that.**
`lane-record-sync` is expensive and writes into every lane's inbox;
`retire` deletes a project's workflow files; `toggle` edits the user's
`settings.json`. Slash-only invocation is what stops any of them from
happening because a sentence contained the right words. They confer no grant
and inherit none, since nothing may call them.

### Who invokes whom

| Caller | Invokes | For |
|---|---|---|
| `--wss-adopt` | `manifest-writer`, `--wss-docs`, `git-writer`, `wss-export-records.sh --import`, `update` | writing the manifest it decided on; scaffolding a project that has no documentation; committing; restoring an archive when its first question — asked up front, default no — gets a yes, before any record is seeded. Amendment mode — one key in an existing manifest — reaches `manifest-writer` without the detection phase. A stale-convention tree — pre-rename filename, v1 schema — is routed to `update`'s migration mode behind its own gate rather than amended around; a finished adoption stamps `WSS.suite` through `manifest-writer` |
| `--wss-update` | `wss-export-records.sh --all`, `manifest-writer`, `git-writer`, `--wss-plan` | the snapshot before the first write; the `WSS.suite` stamp and any manifest key move, only over a passing doctor; one mend per commit; content surgery that lands in a planning record — extracting embedded milestones into the release list — goes through the record's owner, not directly |
| `--wss-start` | `--wss-track`, `--wss-todo` / `--wss-log`, `--wss-plan`, `--wss-tools`, `--wss-docs`, `behaviour-writer`, `reference-writer`, `handoff-writer`, `git-writer`, `sweep-tracker` | building the task list before the batch; recording what the batch produced, committing it, and stamping the suite run so the next audit need not repeat it. `--wss-docs` only where a change also earns a page. Its Phase 6 handoffs run **serialized**, never concurrently — every record writer re-verifies against the other records, so each one's read set is all of them |
| `--wss-check` | the owner of each finding, and `sweep-tracker` | it writes nothing itself — dispatch is the whole design. Every row in its table is a primitive, so a one-line staleness fix never has to run a whole orchestrator procedure to get written |
| `--wss-full-check` | the same owners at full scope, plus `--wss-track`, `--wss-tools` (catalog and prune), `sweep-tracker`, `wss-doctor.sh` and the project's own test command | building the task list before the run, then ignoring every checkpoint. It resolves the suite carry-forward at the start and deliberately never stamps it at the end, because its later steps always run against a tree it has already edited |
| `--wss-stocktake` | `--wss-track`, the manifest's `WSS.agents.audit` — one subagent per dimension, general-purpose where the role is undeclared — `--wss-todo` / `--wss-log`, `--wss-plan`, `--wss-tools`, `--wss-release`, `--wss-wrap`, `audit-writer`, `handoff-writer`, `git-writer`, `sweep-tracker`, and the project's own code-analysis skill where one exists | the task list before its fan-out; the dimension fan-out itself; the dispositions — a finding about a version or a tag dispatched to `--wss-release`, which decides — its own audit entry, and a dispatched close-out. It runs the record dimension itself from `workflow/checks/WSS.RECORD-DRIFT.md` — the hook drops `--wss-check` when either stocktake flag is typed |
| `--wss-release` | the manifest's `WSS.agents.release`, `--wss-full-check`, `changelog-writer`, `git-writer`, `--wss-plan` | the reading — release list, cited roadmaps, changelog, backlog, audit log, git history — returned as a proposal; everything being in order before a tag — drift included, since that is one of its dimensions — then the entry and the tag, a resumed release re-checking the entry through `changelog-writer` and not just the tag. A milestone that looks complete but is unmarked is handed to `--wss-plan`: it reads that mark and never writes it |
| `--wss-plan` | the manifest's `WSS.agents.roadmap`, `--wss-todo` | the reading — roadmaps, release list, backlog, decision index, audit log, git history — delegated so only a proposal returns, while the asking stays here; and a task breakdown that surfaces mid-planning, which is `--wss-todo`'s file rather than a roadmap block. It *names* `--wss-release` as the next step after a mark and never invokes it |
| `lane-record-sync` | `git-writer`, `audit-writer`, `--wss-log`, `--wss-wrap` | step 0's landing, step 5's return leg and step 6's close-out — each lane's branch fast-forwarded onto `WSS.branch.integration` locally, then each lane worktree brought back onto it once the run has finished writing into them; divergence reported and never resolved, and a dirty lane worktree skipped; the run's audit entry — which reports what it promoted out of the conflict inbox and what it deleted as not reproducing — and the declined derivations as one decision entry so a later run does not re-ask them. Every finding it keeps reaches a lane through that lane's transfer queue, never by writing its records. Having no flag it passes no grant down, so the wrap it dispatches asks the user for its own commit in that turn and is never offered the push — step 0's local landings would otherwise reach the remote as a side effect of tidying up; step 6 runs even where step 5 skipped every lane |
| `--wss-wrap` | `handoff-writer`, `--wss-plan`, `git-writer` | the handoff, the milestone question — **from the main checkout only**, since a mark is a checkpoint for the whole project — the commits. It *names* `--wss-pr` where the pushed branch is ahead of `WSS.branch.publish`, and never invokes it — a session ending and work being ready to merge are two different facts |
| `--wss-pr` | `git-writer`, `--wss-todo` | the merge, once the user confirms in that turn; and the review threads nobody resolved, which the merge is about to hide — proposed to the user, never filed automatically, because a meaningful share of unresolved threads is chatter. It drafts the body and holds the gate, and writes nothing itself |
| `--wss-tools` | `docs-writer`, `--wss-docs`, `--wss-todo`, `--wss-log`, `manifest-writer`, `sweep-tracker`, `git-writer`, `wss-doctor.sh`, `workflow/checks/WSS.TOOLING-CLAIMS.md`, `workflow/checks/WSS.PROSE-PRUNE.md`, `workflow/checks/WSS.TOKEN-ECONOMY.md`, `workflow/checks/WSS.ROT-RESISTANCE.md`, `workflow/checks/WSS.ROUTING-HEALTH.md` | handing the catalog over to the writer — `--wss-docs` only where the annex page does not exist yet and its placement has to be decided, stamping the sweep. It draws the diagram above itself. Job 2 runs the claims method, Job 3 the prune method, Job 4 the token-economy method — what could be a script, a cheaper subagent, a gated reference or a cache hit — Job 5 the rot-resistance method, which finds the structure that will produce tomorrow's Job 2 finding, and Job 6 the routing method, the only one of them able to argue a description longer; durable reasoning a cut relocates goes through `--wss-log`, and the doctor runs every sweep for dangling pointers. A tooling *task* it uncovers goes to `--wss-todo` rather than being written here; a `WSS.record.tooling.sources` glob that leaves tooling files undeclared goes to `manifest-writer`, since it never sweeps an undeclared file on its own authority |
| `--wss-docs` | `docs-writer`, `--wss-todo`, `--wss-track`, `sweep-tracker`, `behaviour-writer`, `reference-writer` | every write to the site, which it decides and never performs; parking a page set larger than one session, since this skill stores no state of its own; narrowing its next audit; and handing over a subject that turns out to be a runtime rule or reference material rather than a page, which it never writes itself |
| `--wss-scout` | `--wss-log` | the reasoning entry an adoption earns, at the moment the user adopts — the registry row stays lean and points at it |
| `retire` | `wss-retire-workflow.sh` (`--dir`, then `--suite`), `wss-export-records.sh --all`, `wss-reset-records.sh`, and `claude plugin uninstall` for the user to run | the tidy exit, sequenced: dry run, one checkbox dialog, then the checked actions in dependency order — snapshot before any deletion, wipe before the machinery delete that removes the manifest it reads, the installation last in either form, since it removes the skills the walkthrough runs on |

`--wss-check` and `--wss-full-check` appear as callers and never as callees of a write:
an inspector that writes is a second writer on every file it touches.

---

## Global skills

In `skills/`, loaded in every project. The record procedures are the table
after this one.

| Skill | Flag | What it does |
|---|---|---|
| `adopt` | `--wss-adopt` | Brings a project under this workflow — detects its shape, maps files it already has, decides what its `.claude/WSS.WORKFLOW.json` should say and hands that to `manifest-writer`, proposes `permissions.ask` gating for the destructive commands it finds, and hands a project with no documentation to `--wss-docs`. The detection and the asking are what stay here: a primitive has no channel to reach the user. A tree carrying a *previous* suite convention is recognized before the adoption/amendment verdict and routed to `update`'s migration mode |
| `update` | `--wss-update` | Updates the suite install (checkout pull `--ff-only`, or plugin update), then detects what conventions the adopted tree actually carries and migrates it to the newest — detection is the authority, the `WSS.suite` stamp and the release list's `- migrate:` lines only set the starting point. Its own consent gate shows the full plan of mends; the snapshot precedes the first write; one mend per commit, a partial migration never exits clean, append-only records are never rewritten, and the stamp lands last, only over a passing doctor |
| `docs` | `--wss-docs` `--wss-diagram` | Decides what a project's long-form documentation site holds — whether a subject earns a page, which page, and which tier it lands in — then hands the target to `docs-writer`, which writes it. Covers per-workflow flow pages, a diagram plus stages citing the behaviour record and the code. `--wss-diagram` is the ad-hoc entry: one diagram, placed here, drawn by the writer under the style guide's three rules, landed as an annex page |
| `full-check` | `--wss-full-check` | Asks whether a project's records, docs and tooling are in order — runs its mechanical checks, re-verifies all three at full scope ignoring every checkpoint, triages the defect inbox filed from other projects, orders the prune, has this catalog refreshed, then leaves fresh checkpoints. `--wss-release` runs it before a tag. It reaches Jobs 1 and 3 of `--wss-tools` and not the three sweeps — Job 2's method it runs itself, in its own readers — so "in order" is these three records rather than everything the suite can check |
| `pr` | `--wss-pr` | Moves work from the integration branch onto the publish branch through a pull request — drafts the body from the branch range rather than from memory, opens it, watches its CI, and merges behind a fresh confirmation. The only thing in the suite that moves work between the two branches |
| `stocktake` | `--wss-stocktake`, `--wss-full-stocktake` | Where is this project — record, conventions, public surface, safety nets — then rebuilds the backlog around the answer. Invokes the project's own code-analysis skill where one exists |
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
| `tools` | `--wss-tools` | Keeps this catalog current, hands it to `--wss-docs` where a site exists, deletes stale claims from every file `WSS.record.tooling.sources` reaches — skills and their references, agents, the writer and check procedures, the command wrappers, and the `workflow/` contracts where the globs reach them — and runs the prose prune and the token-economy sweep over the same set. A contract file there is subject to the mutable-claim rule like any other; what the sweep never touches is the *rules* those files state |
| `track` | `--wss-track` | Builds the visible task list for multi-step work and keeps it honest as the work moves |
| `retire` | — | Retires the workflow from a project — the reverse of `--wss-adopt`. Shows what would go, then one checkbox dialog: a full snapshot (`WSS.RETIREMENT-PLAN.tar.gz`, restorable at re-adoption) asked first, then the actions to run — delete the machinery, delete the records, wipe the records, uninstall the plugin — executed in dependency order, a wipe skipped as redundant beside a records delete. Slash-invoked only, and its frontmatter blocks model invocation — a deletion never fires from a phrase |
| `lane-record-sync` | — | Reconciles every lane's records at once, from the main checkout: conflicts between lanes are mediated with the user, work one lane's plans imply for another is presented for an explicit ruling — accept, accept as critical, defer or decline, the last two differing in whether the next run asks again, and what is approved is appended to the addressed lane's **transfer queue** — never to its records. Expensive, and slash-invoked only so it can never fire from a phrase or a batch. The mechanism is `docs/annex/lane-synching.md` |
| `contracts` | — | States how the suite is wired — that the skills are global, that project facts come from `.claude/WSS.WORKFLOW.json`, what a project without a manifest falls back to, and where the contracts resolve in a checkout versus a plugin install. It exists because a plugin root's `CLAUDE.md` is never loaded, so an adopter who installs rather than clones would otherwise see none of it |
| `toggle` | — | Toggles what each skill costs at session start: shows every skill's current `skillOverrides` level, then sets `on`, `name-only`, `user-invocable-only` or `off` in the user's `settings.json` — refusing a level that would break a skill another skill dispatches to, and warning when a change silences a flag. Slash-invoked only, its frontmatter blocks model invocation, and it is the checkout form's lever: the harness ignores overrides for plugin skills |
| `wrap` | `--wss-wrap` | Closes out a session — task list, the handoff through `handoff-writer`, the commits and push through `git-writer`, asks `--wss-plan` whether a milestone just finished, and from a lane worktree syncs that lane forward before it reports anything, then lands it on `WSS.branch.integration` by fast-forward — both refused rather than forced, and the landing withheld entirely when the wrap fired on an unfinished session. Reports where the project stands in the reply (backlog left, decisions nobody has made, the next goal and milestone, and how far each sweep's baseline has fallen behind `HEAD` — read from the checkpoint, never written to it), and says when it is safe to clear |

---

## The record procedures

In `workflow/writers/`, **not** in `skills/`. A caller reaches one by reading
the file — there is nothing to invoke, and nothing loads unless a caller opens
it. A description costs every session whether or not the skill is used, and
each of these is invoked only by other skills — so they are procedure files
rather than skills. Ownership is unaffected by the location —
`workflow/WSS.OWNERSHIP.md` is still the authority, and `workflow/writers/WSS.WRITERS.md`
is their index.

| Procedure | Sole writer of | What it does |
|---|---|---|
| [`audit-writer`](../workflow/writers/WSS.AUDIT-WRITER.md) | `WSS.record.stocktake`, `WSS.record.audits` | Writes the stocktake log entry — what a stocktake examined, against which tree, and what it found, with its coverage block — plus the one-field `Outcome` update when remediation lands, which is why it is not part of `--wss-stocktake`. Also appends the index row in `WSS.record.audits` when an independent audit pass lands |
| [`behaviour-writer`](../workflow/writers/WSS.BEHAVIOUR-WRITER.md) | `WSS.record.behaviour` | Writes the record of what the system does at runtime, by topic. Never *why* it does it, which is `--wss-log`'s. Reached by dispatch from a check or a build, or directly through `--wss-describe` |
| [`changelog-writer`](../workflow/writers/WSS.CHANGELOG-WRITER.md) | `WSS.record.changelog` | Writes the changelog entry for a version, and marks an entry unreleased when the documents claim more than the tags do |
| [`docs-writer`](../workflow/writers/WSS.DOCS-WRITER.md) | the documentation site | Writes every page and annex page, their `_sidebar.md` and `index.md` rows, the translation mirrors, and the diagrams inside them — re-rendering a diagram a caller hands over rather than reshaping it. It decides nothing: whether a subject earns a page, which page, and which tier are settled by `--wss-docs` before it is called, and a target contradicting the taxonomy is handed back rather than quietly relocated |
| [`git-writer`](../workflow/writers/WSS.GIT-WRITER.md) | commits and tags | Makes the commits, the tags and `--wss-pr`'s merge for every skill that may, so the rules that keep a commit, a merge or a push safe live in one file rather than in whichever caller remembered them |
| [`handoff-writer`](../workflow/writers/WSS.HANDOFF-WRITER.md) | `WSS.record.handoff` | Writes the handoff a fresh session inherits, at whatever scope its caller asked for |
| [`manifest-writer`](../workflow/writers/WSS.MANIFEST-WRITER.md) | `.claude/WSS.WORKFLOW.json` | Writes `.claude/WSS.WORKFLOW.json` — validates each key against `workflow/WSS.MANIFEST.md`, refuses one nothing reads or whose path does not resolve, and runs the doctor. Decides nothing: the caller arrives having settled the values |
| [`reference-writer`](../workflow/writers/WSS.REFERENCE-WRITER.md) | `WSS.record.reference` | Writes the record of what the system *is* — stack, architecture, data model, stated conventions. Often the project's `README.md`, where the manifest maps it there. Reached by dispatch from a check or a build, or directly through `--wss-reference` |
| [`sweep-tracker`](../workflow/writers/WSS.SWEEP-TRACKER.md) | the sweep checkpoint | Records which commit each sweep last verified and what it covered, so the next one re-reads only what changed. It refuses a stamp claiming a commit with no coverage — except a freshness-only entry, which claims none and licenses nothing |


---

## The shared check methods

In `workflow/checks/`, **not** in the skills that wrote them. Each is one way of
finding inconsistency in something the project has written down, or the structure
that will produce one; the skill that runs one supplies the scope and decides
what happens to a finding.

Each is single-sourced here because a method borrowed by **citing another
skill's headings** breaks silently on a rename, leaving the borrower reporting
success over checks it never ran; `wss-doctor.sh`'s section-citation check polices
the citations that remain.

| Method | What it finds | Run by |
|---|---|---|
| [`WSS.RECORD-DRIFT.md`](../workflow/checks/WSS.RECORD-DRIFT.md) | the classes of drift in a record, and the things that look like drift and are not | `--wss-check`, `--wss-full-check`, `--wss-stocktake` |
| [`WSS.DOCS-AUDIT.md`](../workflow/checks/WSS.DOCS-AUDIT.md) | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--wss-docs`, `--wss-full-check` |
| [`WSS.TOOLING-CLAIMS.md`](../workflow/checks/WSS.TOOLING-CLAIMS.md) | mutable claims inside the tooling files, which are deleted rather than corrected | `--wss-tools`, `--wss-full-check` |
| [`WSS.MECHANICAL-GAUNTLET.md`](../workflow/checks/WSS.MECHANICAL-GAUNTLET.md) | a non-green result from the project's own verifications — doctor, typecheck, suite, CI — and what each outcome means | `--wss-full-check`, `--wss-stocktake` |
| [`WSS.PROSE-PRUNE.md`](../workflow/checks/WSS.PROSE-PRUNE.md) | prose in a skill, agent or tooling file whose removal changes nothing about what Claude does | `--wss-tools`; `--wss-full-check` orders that job rather than reading this file |
| [`WSS.AUDIT-PASS.md`](../workflow/checks/WSS.AUDIT-PASS.md) | what an independent audit pass must carry — the cumulative rubric, and how focuses rotate | the audit ritual, on the owner's ask; no flag |
| [`WSS.TOKEN-ECONOMY.md`](../workflow/checks/WSS.TOKEN-ECONOMY.md) | a skill, agent or tooling file paying more context than its job needs — each lens with a proven in-tree example and the drawback to outweigh | `--wss-tools` |
| [`WSS.ROT-RESISTANCE.md`](../workflow/checks/WSS.ROT-RESISTANCE.md) | writing that is true today and structured to go false — an uncompared copy, a file with two writers, a claim nothing can test, a drift nothing would report | `--wss-tools` |
| [`WSS.ROUTING-HEALTH.md`](../workflow/checks/WSS.ROUTING-HEALTH.md) | a skill that will not be reached when it should be, or will be when it should not — the one check that can push a description longer | `--wss-tools` |

**A method says what counts as a finding; a runner decides scope, disposition
and owner.** `workflow/checks/WSS.CHECKS.md` holds that line and why it matters —
material that drifts to the wrong side of it stops being borrowable.

---

## Backlog providers

In `workflow/providers/`. `WSS.record.todo` is normally a path; a project whose
backlog already lives somewhere else declares a provider object instead. Nothing
else in `WSS.record.*` takes one.

**Every skill that touches the backlog goes through the provider, not just
`--wss-todo`** — `--wss-adopt` offers the choice and `manifest-writer` validates it,
`--wss-start` and `--wss-check` and `--wss-full-check` read it, `--wss-wrap` counts it. None of
them may read a local file instead when the remote is unreachable; they say so
and write nothing.

| Provider | Declared as | Contract |
|---|---|---|
| GitHub Issues | `{ "provider": "github-issues", "repo": "owner/name", "label": "backlog" }` | [`WSS.GITHUB-ISSUES.md`](../workflow/providers/WSS.GITHUB-ISSUES.md) |

**A declared provider is never a silent fallback to a file.** `wss-doctor.sh` fails
on one nothing implements, on a missing `repo`, on a repo that does not
resolve, and on a declared `label` no label on the repo matches; it warns when
`gh` is absent or unauthorized, which is a fault of the machine rather than the
manifest. The reasoning behind an item still goes to
`WSS.record.decisions` — a file — because an issue thread is a conversation and a
decision log is read months later.

## Skills scoped to this repo

The workflow supports them — a project ships a skill under `.claude/skills/` and
the flag hook resolves it there before the global suite. Anything this catalog
lists above is global; `ls .claude/skills/` is what says whether a scoped one
exists here.

## Agents

| Agent | What it does |
|---|---|
| `wss-release-prep` | Prepares a release's material for `--wss-release`: the version tier it proposes and which trigger fired, the changelog entry text in the voice of the entries above it, and any drift between what the release list and changelog claim shipped and what a tag actually resolves. Reads the release list, the roadmaps the milestone cites, the changelog, the backlog, the audit log and the git history — several thousand tokens that stay out of the caller's context. It writes nothing, tags nothing and publishes nothing. Declared as `WSS.agents.release`. **This one travels** |

The remaining `agents.*` roles in the schema stay something an *adopting* project
declares. What a skill does with a role no manifest declares is
[`WSS.MANIFEST.md`](../workflow/WSS.MANIFEST.md)'s `agents` section, and a second
copy here would drift from it.

## Scripts

| Script | What it does |
|---|---|
| `wss-doctor.sh` | Read-only health check of this config and the project in the working directory. Prints what it checks, so the list cannot go stale |
| `hooks/wss-shorthand-flags.sh` | The `UserPromptSubmit` hook that turns a `--flag` into a deterministic skill invocation rather than a judgement call |
| `hooks/wss-session-check.sh` | The `SessionStart` hook, and the only thing here that speaks without being asked — so it is built to stay silent unless it has something worth a session's attention: a doctor failure, a sweep or a record gone stale, a filed bug report, an unread upstream filing (counted only in the suite's own checkout, where triage can act), a handoff the harness would not otherwise load, or a one-time orientation block on the first session after a plugin install, since a plugin has no channel to speak at install time |
| `hooks/wss-alert.sh` | A sound cue when a session waits for input — permission prompts, option pickers, idle, turn end. Ships silent and opts in per machine: `--wss-alerts on\|off` (served by the flag hook, no skill) toggles a state file in the config directory that this hook gates on. Sound only, cross-platform, one cue per burst |
| `hooks/hooks.json` | Declares the same events for a **plugin** install, where `settings.json` is the user's and a plugin never owns it. Plugin hooks merge with the user's rather than replacing them |
| `.claude-plugin/plugin.json` | The manifest that makes this directory installable. `claude plugin validate` reads it |
| `wss-reset-records.sh` | Blanks every record the manifest declares back to its canonical heading — a fresh start with the structure kept and the content gone. Dry-run unless given `--write`. Skips a `WSS.record.todo` that names a provider rather than a file, and never touches `WSS.record.reference` or `WSS.record.tooling.catalog`, which describe the tooling rather than the project. **This one travels**, and `wss-publish.sh` runs the copy of it rather than keeping a second list |
| `wss-export-records.sh` | Moves machine-local workflow state between machines — untracked record files, the lane selector, and the config directory's bug-reports inbox. Skips tracked records and the sweep checkpoint — except under `--all`, the retirement snapshot `/wss:retire` takes before deleting, which keeps tracked records in and adds the docs tree. Import is all-or-nothing, refuses escaping entries, and refuses non-empty collisions without `--force`. **This one travels** |
| `wss-retire-workflow.sh` | The tidy exit: removes the suite's machinery from a project — manifest, sweep cache, lane selector — and, only behind `--write --records`, the workflow-shaped records. Never touches the reference, changelog or tooling files, a CLAUDE.md handoff, or the suite's own tree. `--suite` is the other direction — the installation rather than a project: it names any plugin install for the harness to uninstall, deletes a checkout by `git ls-files` keeping `CLAUDE.md` and `settings.json`, and reports what a running script cannot unlink for the user to remove by hand. Dry-run by default. `/wss:retire` is the walkthrough around it. **This one travels** |
| `wss-remove-lanes.sh` | Turns worktree-lane mode off for one checkout: deletes `.claude/WSS.LANE` and drops `WSS.lanes.named` and `.conflicts` from the manifest. Keeps `WSS.lanes.exclusive`, `.serialize` and `.generated`, which drive `--wss-start`'s Phase 3 inside a single checkout and are not worktree machinery. Deletes no record under any flag — a lane file holding content refuses the write until `--allow-orphans`. Dry-run by default; refuses an untracked or uncommitted manifest so the rewrite stays revertible. **This one travels** |
| `wss-tree-survey.sh` | Prints one adopted tree's own properties, read-only, run by hand from inside it: adoption state and manifest schema — including a pre-rename `.claude/workflow.json`, which every other current reader sees as cleanly absent — then lanes, backlog as file or provider, behaviour record, `WSS.localCI`, branches, commands and declared agents, an exists/missing roll of every declared record, and a bounded `wss-doctor.sh` tail with its exit code reported separately. It names what it could not read instead of leaving a row blank. Exists so a surface can be mapped to a tree that can exercise it, from that tree's manifest rather than from its name. **This one travels; its output does not** — a survey names a private project's paths and record layout, so it is never routed through `--wss-report` or any issue |
| `wss-survey-all.sh` | Runs the surveyor over every adopted tree under the roots it is given — both manifest filenames, so a pre-rename tree is found rather than passed over — writing one survey per tree outside every tree, then printing what a stack of individual surveys cannot say. **It counts projects, not directories**: worktrees are grouped by resolved git common directory and the main checkout is the member every surface is read from, because a lane worktree named as the candidate sends a reader to a project that does not exist. Unread probes travel into the summary as flags, so a doctor that never ran or a backlog `gh` could not read never reads as a clean result. The rollup is taken from each project's manifest rather than from the survey text, distinguishes no candidate from unread, and prints `/wss:retire` as undetectable rather than inferring intent no key records. **This one travels; its output does not**, and less than the surveyor's — one file names every private tree on the machine |
| `wss-audit-assets.sh` | Emits the deterministic measurements an independent audit pass needs — the mechanical floor with the doctor and contract suite actually run, per-skill sizes, always-on components, sweep distances, record counts — so a pass spends its model tokens only on judgment. Deliberately does not run `wss-publish.sh`, which the pass exercises itself as a gate. Reads this repo's own record paths, so it does not travel |
| `wss-publish.sh` | Assembles the public tree from `HEAD` and gates it — copies only what it admits, empties the records on the copy, then asserts no ancestry, no private identifier, a whitelist of tracked paths, the credential rules, and the doctor and tests from inside the result. Never pushes. Does not travel with what it copies |
| `.claude-plugin/marketplace.json` | Makes the same directory its own marketplace, listing one plugin whose `source` is `"./"` — so there is no second repository to keep in step. Handed a directory holding both, `claude plugin validate` checks this one and not the other; name the file to check the other |
| `skills/docs/assets/wss-scaffold.sh` | Creates a docsify site shell and only the shell, never content. Refuses to touch an existing directory, and prints the steps it deliberately leaves to its caller. Takes the site's root from `WSS.docs.root` rather than as an argument — `--root` overrides, and the resolved root is announced on every run — which makes it the one skill asset that reads the manifest. Invoked by `--wss-docs` in Scaffold mode |
| `skills/record/assets/wss-index-decisions.sh` | Generates `WSS.record.decisionsIndex` from the decision log — one row per entry, line number and heading — and verifies it without writing under `--check`. Declared as `WSS.commands.indexRegen` / `WSS.commands.indexCheck` in this repo's manifest; refuses to run where the index key is undeclared |
| `skills/overview/assets/wss-probe.sh` | Emits `--wss-overview`'s whole mechanical block in one read-only call — tree, record counts, doctor result, sweep freshness, the roadmap's current goal and the release list's current milestone — so the report costs seconds instead of a model read of every record. Offline by design: external state is reported as not counted, never as zero. Invoked by `--wss-overview` |
| `skills/overview/assets/wss-sweep-distance.sh` | How far each sweep baseline sits behind `HEAD` — the single implementation, with two renderings: `--verbose` for `wss-probe.sh`'s `== sweeps ==` block, one entry per line, and `--compact` for `--wss-wrap` step 7's closing line. Read-only and offline — measuring a baseline is not advancing one, which stays `sweep-tracker`'s. **The figures are a report and never a gate**: every path exits 0, no checkpoint and an off-history baseline included, and only a usage error is non-zero |
| `tests/wss-hook-contract.sh` | The contract tests for the hook, whose breakage is total and silent |
| `.github/workflows/publish.yml` | Fires on a release-tag push, and on manual dispatch — which is how a publication is staged when the public repo has drifted behind `dev` without a tag. Runs `wss-publish.sh` and stages the gated assembly as a PR on the public repository, never a merge. It asserts the pushed tag against `.claude-plugin/plugin.json` first, and reports rather than refuses on a dispatch run, where there is no tag to assert against. Needs the `PUBLISH_TOKEN` secret; removed from the assembly so it never ships |
| `.github/workflows/verify.yml` | CI. Runs `wss-doctor.sh`, the hook contract tests, and the static checks the workflow file itself enumerates. Runs on a push to any branch except `main`, on every pull request, and on manual dispatch — `main` is reached only through a PR, and on the published repository `main` additionally requires that PR run to be green before it can be merged |

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

| Wrapper | Fires | Routes to |
|---|---|---|
| `commands/todo.md` | `--wss-todo` | `record` |
| `commands/log.md` | `--wss-log` | `record` |

## Files that are not tools

Worth naming, because they are most of what a reader will otherwise open:

| File | What it is |
|---|---|
| `workflow/*.md` | The contracts every skill links to rather than each inventing its own — a few rules are deliberately restated inline where a dispatch site's reader should not have to follow a link, and `wss-doctor.sh` holds those copies in step with the contract; the directory's own listing is the inventory |
| `skills/*/references/*.md` | A skill's own reference material. Nothing here loads at session start — only a `SKILL.md`'s frontmatter does — and nothing here is invocable: the owning `SKILL.md` cites each file at the point its procedure reaches it, and `docs` gates several to one mode. That skill file is the inventory, so a reference is never listed twice |
| `CLAUDE.md` | Loaded into every session in every project — the checkout form only, because a plugin root's is never read as project context. Routing and machine-wide rules, kept short because they are paid for in every session; what each contract governs is `contracts`', which owns it |
| `README.md` | How the repo is adopted on a new machine, and how the flags work |
| `WSS.BUG-REPORTS.md` | Gitignored inbox for defects found in these files by sessions working in other projects |
