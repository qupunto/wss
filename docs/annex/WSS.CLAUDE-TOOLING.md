# Claude tooling

Exhaustive reference for every skill and script in this repository: what each
one is for, and — the part no single file shows — which of them invoke each
other.

**Source.** This page is derived from `.claude/WSS.TOOLING.md`, which `--wss-tools`
owns and hands over. That file is the source of fact; this page is its
adaptation into the site. If the two disagree, the catalog is right and this
page is stale — which is a finding for `--wss-check`, not something to fix by
editing here. For the guide to *how* the tiers work, see
[WSS.OVERVIEW.md](../WSS.OVERVIEW.md).

**Everything listed here exists and can be invoked**, which is not the same as
everything being described to Claude in every session. A skill can be set to
`name-only` — still fully invocable, but with its description kept out of the
always-loaded context, which is what that description costs in every session of
every project. Which skills are set that way is `skillOverrides` in
`settings.json`, and that file is the authority; this page deliberately does not
list them, because a copy of a settings block is stale the moment it is edited.

**That lever is the checkout form's, with one exception.** `skillOverrides` does
not reach plugin skills, so an install loads every description here regardless.
But `hooks/wss-shorthand-flags.sh` reads the overrides itself, so under a plugin
install `off` still stops that skill's *flag* firing while the skill stays
callable by name.

The diagram below is ASCII rather than Mermaid because `docs/index.html` loads
only the search plugin; a Mermaid fence would render as raw markup for every
reader.

---

## How the pieces fit

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
   │    flagless:     wss-lane-record-sync   wss-retire             │
   │                  wss-toggle             (all slash only)       │
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
   │    flagless:     wss-contracts  (a skill)                      │
   │                                                                │
   │    procedures    sweep-tracker     handoff-writer              │
   │    under         changelog-writer  git-writer                  │
   │    workflow/     manifest-writer   behaviour-writer            │
   │    writers/:     reference-writer  audit-writer                │
   └───────────────────────────┬────────────────────────────────────┘
                               │  the ones that write
                               ▼
              the record files, and the git history
```

**Every orchestrator writes no record**, and the box needs only one row to say
so. The diagram draws the current state, never an intended one — a map showing
the destination gets read as showing the territory.

That includes `--wss-docs`, which produced this page: it owns the site and nothing
else. `WSS.record.behaviour` and `WSS.record.reference` are `behaviour-writer`'s and
`reference-writer`'s, so a one-line staleness correction reaches them directly
instead of having to run a whole documentation procedure.

**The flagless row cannot be entered from the top of that picture.** A primitive
with no flag has no grant of its own to inherit from, so a caller can never
acquire authorization the user did not give it — which is why they have no flag
rather than merely happening to lack one. Arrows also run upward: the primitive
`--wss-tools` invokes the orchestrator `--wss-docs`, because a tier says what a skill
owns, not who may call it.

**Three orchestrators are flagless for a second reason on top of that.**
`wss-lane-record-sync` is expensive and writes into every lane's inbox;
`wss-retire` deletes a project's workflow files; `wss-toggle` edits the user's
`settings.json`. Slash-only invocation is what stops any of them from
happening because a sentence contained the right words. They inherit no grant,
since nothing may call them, and they confer none on anything they call, having
no flag to confer from. `wss-lane-record-sync` is the one that does call
something — it hands its close-out to `--wss-wrap` — and that wrap therefore
arrives with nothing and asks the user for its own commit in that turn.

**Not every primitive writes**, which is why the arrow leaving that box is
labelled rather than bare. `wss-contracts` only states how the suite is wired —
the "rule" the box label admits; an unlabelled arrow would read as though the
whole tier ended at the record files. It is a primitive on the same test as
the rest: one job, no session of its own, no authorization it did not inherit.

## Who invokes whom

| Caller | Invokes | For |
|---|---|---|
| `--wss-adopt` | `manifest-writer`, `--wss-docs`, `git-writer`, `wss-export-records.sh --import`, `wss-update` | writing the manifest it decided on; scaffolding a project that has no documentation; committing; restoring an archive when its up-front question — y/N, default no — gets a yes, before any record is seeded. Amending one key in an existing manifest reaches `manifest-writer` without the detection phase, which is what the split was for. A stale-convention tree — pre-rename filename, v1 schema — routes to `wss-update`'s migration mode behind its own gate; a finished adoption stamps `WSS.suite` through `manifest-writer` |
| `--wss-update` | `wss-export-records.sh --all`, `manifest-writer`, `git-writer`, `--wss-plan` | the snapshot before the first write; the `WSS.suite` stamp and any manifest key move, only over a passing doctor; one mend per commit; content surgery that lands in a planning record — extracting embedded milestones into the release list — goes through the record's owner, not directly |
| `--wss-start` | `--wss-track`, `--wss-todo` / `--wss-log`, `--wss-plan`, `--wss-tools`, `--wss-docs`, `behaviour-writer`, `reference-writer`, `handoff-writer`, `git-writer`, `sweep-tracker` | building the task list before the batch; recording what a batch produced, committing it, and stamping the suite run so the next audit need not repeat it — `--wss-docs` only where a change also earns a page. Its closing handoffs run **serialized**: every record writer re-verifies against the other records, so each one's read set is all of them |
| `--wss-check` | the owner of each finding, and `sweep-tracker` | it writes nothing itself — dispatch is the whole design |
| `--wss-full-check` | the same owners at full scope, plus `--wss-track`, `--wss-tools` (claims and prune), `sweep-tracker`, `wss-doctor.sh` and the project's own test command | building the task list before the run, then ignoring every checkpoint. It resolves the suite carry-forward at the start and deliberately never stamps it at the end, since its later steps always run against a tree it has already edited |
| `--wss-stocktake` | `--wss-track`, `--wss-todo` / `--wss-log`, `--wss-plan`, `--wss-tools`, `--wss-wrap`, `audit-writer`, `handoff-writer`, `git-writer`, `sweep-tracker`, and the project's own code-analysis skill where one exists | the task list before its fan-out; the dispositions, its audit entry, and a dispatched close-out. It runs the record dimension itself from `workflow/checks/WSS.RECORD-DRIFT.md` — the hook drops `--wss-check` when either stocktake flag is typed |
| `--wss-release` | `--wss-full-check`, `changelog-writer`, `git-writer` | everything being in order before a tag — drift included, since that is one of its dimensions — then the entry and the tag. It reads `--wss-plan`'s mark and never writes it |
| `wss-lane-record-sync` | `git-writer`, `audit-writer`, `--wss-log`, `--wss-wrap` | step 0's landing, step 5's return leg and step 6's close-out — each lane's branch fast-forwarded onto `WSS.branch.integration` locally, then each lane worktree brought back onto it once the run has finished writing into them; divergence reported and never resolved, and a dirty lane worktree skipped; the run's audit entry — which reports what it promoted out of the conflict inbox and what it deleted as not reproducing — and the declined derivations as one decision entry so a later run does not re-ask them. Every finding it keeps reaches a lane through that lane's transfer queue, never by writing its records. Having no flag it passes no grant down, so the wrap it dispatches asks the user for its own commit in that turn and never offers the push — step 0's local landings would otherwise reach the remote as a side effect of tidying up; step 6 runs even where step 5 skipped every lane |
| `--wss-wrap` | `handoff-writer`, `--wss-plan`, `git-writer` | the handoff, the milestone question — **from the main checkout only**, since a mark is a checkpoint for the whole project — the commits. It *names* `--wss-pr` where the pushed branch is ahead of `WSS.branch.publish`, and never invokes it — a session ending and work being ready to merge are two different facts |
| `--wss-pr` | `git-writer`, `--wss-todo` | the merge, once the user confirms in that turn; and the review threads nobody resolved, which the merge is about to hide — proposed to the user, never filed automatically, because a meaningful share of unresolved threads is chatter. It drafts the body and holds the gate, and writes nothing itself |
| `--wss-tools` | `--wss-docs`, `--wss-todo`, `sweep-tracker`, `git-writer` | handing the catalog over, stamping the sweep; a tooling *task* it uncovers goes to `--wss-todo` rather than into the catalog. It draws the diagram itself |
| `--wss-docs` | `--wss-todo`, `--wss-track`, `sweep-tracker`, `behaviour-writer`, `reference-writer` | parking a page set larger than one session, since it stores no state of its own; narrowing its next audit; and handing over a subject that turns out to be a runtime rule or reference material rather than a page, which it never writes itself |
| `--wss-scout` | `--wss-log` | the reasoning entry an adoption earns, at the moment the user adopts — the registry row stays lean and points at it |
| `wss-retire` | `wss-retire-workflow.sh`, `wss-export-records.sh --all`, `wss-reset-records.sh`, and `claude plugin uninstall` last | the tidy exit, sequenced: a dry run, one checkbox dialog, then the checked actions in dependency order — the snapshot before any deletion, a wipe before the machinery delete that removes the manifest it reads, the uninstall last and only on a plugin install, since it removes the skills the walkthrough runs on |

`--wss-check` and `--wss-full-check` appear as callers and never as callees of a write:
an inspector that writes is a second writer on every file it touches.

## Global skills

In `skills/`, loaded in every project.

| Skill | Flag | What it does |
|---|---|---|
| `wss-adopt` | `--wss-adopt` | Brings a project under this workflow — detects its shape, maps files it already has, decides what its `.claude/WSS.WORKFLOW.json` should say and hands that to `manifest-writer`, proposes `permissions.ask` gating for the destructive commands it finds, and hands a project with no documentation to `--wss-docs`. The detection and the asking are what stay here: a primitive has no channel to reach the user. A tree carrying a *previous* suite convention is recognized before the adoption/amendment verdict and routed to `wss-update`'s migration mode |
| `wss-update` | `--wss-update` | Updates the suite install (checkout pull `--ff-only`, or plugin update), then detects what conventions the adopted tree actually carries and migrates it to the newest — detection is the authority, the `WSS.suite` stamp and the release list's `- migrate:` lines only set the starting point. Its own consent gate shows the full plan of mends; the snapshot precedes the first write; one mend per commit, a partial migration never exits clean, append-only records are never rewritten, and the stamp lands last, only over a passing doctor |
| `wss-docs` | `--wss-docs` `--wss-diagram` | Writes and maintains this documentation site, every claim anchored to a real source path — and nothing else. It decides whether a subject belongs on the site and which tier it lands in, and owns the workflow-page shape: an end-to-end flow as a Mermaid diagram plus stages citing the behaviour record and the code. `--wss-diagram` is the ad-hoc entry: one diagram, drawn under the style guide's three rules, landed as an annex page. The behaviour and reference records are `behaviour-writer`'s and `reference-writer`'s |
| `wss-full-check` | `--wss-full-check` | Asks whether a project is in order end to end — runs its mechanical checks, re-verifies its records, docs and tooling files at full scope ignoring every checkpoint, triages the defect inbox filed from other projects, orders the prune, has the catalog refreshed, then leaves fresh checkpoints. `--wss-release` runs it before a tag |
| `wss-pr` | `--wss-pr` | Moves work from the integration branch onto the publish branch through a pull request — drafts the body from the branch range rather than from memory, opens it, watches its CI, and merges behind a fresh confirmation. The only thing in the suite that moves work between the two branches |
| `wss-record` | `--wss-todo`, `--wss-log` | Parks work that is not being built now, and records decisions already made |
| `wss-describe` | `--wss-describe` | Gets a runtime rule settled in conversation into `WSS.record.behaviour`, which every other route reaches only as a side effect of a check or a build. Dispatches to `behaviour-writer` and writes nothing itself; its own work is turning away the three things handed to it by mistake — reasoning and decided-but-unbuilt behaviour, both `--wss-log`'s, and stack or architecture, which is `--wss-reference`'s |
| `wss-reference` | `--wss-reference` | Gets a fact about what the project *is* — stack, architecture, data model, a convention — into `WSS.record.reference`, the same shape as `wss-describe` one record over. Dispatches to `reference-writer` and writes nothing itself; it names the exact file the fact resolved to before anything is written, because a manifest may map the project's `README.md` into the reference array and the flag then reaches a public landing page |
| `wss-scout` | `--wss-scout` | Consults the project's toolbelt registry before any capability gets hand-built, searches the stack's public registries when the registry has no answer, and explains the candidates — advises, never implements. Sole writer of `WSS.record.toolbelt`; the reasoning behind each row goes through `--wss-log` |
| `wss-stocktake` | `--wss-stocktake`, `--wss-full-stocktake` | Where is this project — record, conventions, public surface, safety nets — then rebuilds the backlog around the answer. Invokes the project's own code-analysis skill where one exists |
| `wss-check` | `--wss-check` | Asks whether a project's records still match reality, including whether the documents claim a version no tag resolves; reports and dispatches, writes nothing itself |
| `wss-report` | `--wss-report` | Files a finding about this suite upstream — appends it to the machine-local inbox, then opens a GitHub issue on the public repository behind a preview, a redaction of the project context, and a fresh OK. Can bundle every open inbox entry under the same rules; hazards are referenced by group name, never quoted |
| `wss-release` | `--wss-release` | Decides that a version ships — once `WSS.record.releases` marks a milestone done, or once it has declared an end to milestones and the release is maintenance on evidence — and asks before anything is published |
| `wss-plan` | `--wss-plan` | Sets the next goal in `WSS.record.roadmap` — which splits by lane — and keeps `WSS.record.releases`, the release list, where the milestones, their versions and their marks live. A roadmap carries neither |
| `wss-overview` | `--wss-overview` | Reports where a project stands at a glance — branch and lane, per-record counts, sweep freshness, pending warnings, the nearest milestones — read fresh at invocation, writing nothing at all. Every mechanical number comes from its probe script in one call; the model adds only the judgment lines. The read-only sibling of `--wss-check`: it counts what the records say and never verifies them |
| `wss-start` | `--wss-start` | Picks up pending work and does it, in parallel lanes partitioned so they cannot collide |
| `wss-tools` | `--wss-tools` | Keeps the catalog current, hands it to `--wss-docs` where a site exists, deletes stale claims from skill and agent files, and runs the prose prune over the same set |
| `wss-track` | `--wss-track` | Builds the visible task list for multi-step work and keeps it honest as the work moves |
| `wss-retire` | — | Retires the workflow from a project — the reverse of `--wss-adopt`. Shows what would go, then one checkbox dialog: a full snapshot (`WSS.RETIREMENT-PLAN.tar.gz`, restorable at re-adoption) asked first, then the actions to run — delete the machinery, delete the records, wipe the records, uninstall the plugin — executed in dependency order, a wipe skipped as redundant beside a records delete. Slash-invoked only, and its frontmatter blocks model invocation, so a deletion never fires from a phrase |
| `wss-lane-record-sync` | — | Reconciles every lane's records at once, from the main checkout: conflicts between lanes are mediated with the user, work one lane's plans imply for another is presented for an explicit ruling — accept, accept as critical, defer or decline, the last two differing in whether the next run asks again, and what is approved is appended to the addressed lane's **transfer queue** — never to its records. Expensive, and slash-invoked only so it can never fire from a phrase or a batch. See [Lane synching](lane-synching.md) |
| `wss-contracts` | — | States how the suite is wired: that the skills are global, that project facts come from `.claude/WSS.WORKFLOW.json`, what a project without a manifest falls back to, and where the three contracts resolve in a checkout against a plugin install. It exists because a plugin root's `CLAUDE.md` is never loaded as project context, so an adopter who installs rather than clones would otherwise see none of it |
| `wss-toggle` | — | Toggles what each skill costs at session start: shows every skill's current `skillOverrides` level, then sets `on`, `name-only`, `user-invocable-only` or `off` in the user's `settings.json` — refusing a level that would break a skill another skill dispatches to, and warning when a change silences a flag. Slash-invoked only, its frontmatter blocks model invocation, and it is the checkout form's lever: the harness ignores overrides for plugin skills |
| `wss-wrap` | `--wss-wrap` | Closes out a session — task list, handoff, commits, the milestone question, and from a lane worktree syncs that lane forward before reporting, then lands it on `WSS.branch.integration` by fast-forward — both refused rather than forced, and the landing withheld entirely when the wrap fired on an unfinished session. A readout of where the project stands, and whether it is safe to clear |


## The record procedures

In `workflow/writers/`, **not** in `skills/`. A caller reaches one by reading
the file; there is nothing to invoke, and nothing loads unless a caller opens
it. They left `skills/` because a skill description is a
per-session cost paid whether or not the skill is used, and each of these
declared in its own description that only other skills invoked it. Ownership is
unchanged — `workflow/WSS.OWNERSHIP.md` remains the authority.

| Procedure | Sole writer of | What it does |
|---|---|---|
| `audit-writer` | `WSS.record.stocktake`, `WSS.record.audits` | Writes the stocktake log entry — what a stocktake examined, against which tree, and what it found, with its coverage block — plus the one-field `Outcome` update when remediation lands, which is why it is not part of `--wss-stocktake`. Also appends the index row in `WSS.record.audits` when an independent audit pass lands |
| `behaviour-writer` | `WSS.record.behaviour` | Writes the record of what the system does at runtime, by topic. Never *why* it does it, which is `--wss-log`'s. Reached by dispatch from a check or a build, or directly through `--wss-describe` |
| `changelog-writer` | `WSS.record.changelog` | Writes the changelog entry for a version, and marks an entry unreleased when the documents claim more than the tags do |
| `git-writer` | commits and tags | Makes the commits, the tags and `--wss-pr`'s merge for every skill that may, so the rules that keep a commit, a merge or a push safe live in one file rather than in whichever caller remembered them |
| `handoff-writer` | `WSS.record.handoff` | Writes the handoff a fresh session inherits, at whatever scope its caller asked for |
| `manifest-writer` | `.claude/WSS.WORKFLOW.json` | Writes `.claude/WSS.WORKFLOW.json` — validates each key against `workflow/WSS.MANIFEST.md`, refuses one nothing reads or whose path does not resolve, and runs the doctor. Decides nothing: the caller arrives having settled the values |
| `reference-writer` | `WSS.record.reference` | Writes the record of what the system *is* — stack, architecture, data model, stated conventions. Often the project's `README.md`, where the manifest maps it there. Reached by dispatch from a check or a build, or directly through `--wss-reference` |
| `sweep-tracker` | the sweep checkpoint | Records which commit each sweep last verified and what it covered, so the next one re-reads only what changed. It refuses a stamp claiming a commit with no coverage — except a freshness-only entry, which claims none and licenses nothing |

## The shared check methods

In `workflow/checks/`, not in the skills that wrote them. Each is one way of
finding inconsistency in something the project has written down; the skill that
runs one supplies the scope and decides what happens to a finding.

Each is single-sourced here because a method reached by citing another skill's
headings breaks silently on a rename, leaving the borrower reporting success
over checks it never ran.

| Method | What it finds | Run by |
|---|---|---|
| `WSS.RECORD-DRIFT.md` | the classes of drift in a record, and the things that look like drift and are not | `--wss-check`, `--wss-full-check`, `--wss-stocktake` |
| `WSS.DOCS-AUDIT.md` | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--wss-docs`, `--wss-full-check` |
| `WSS.TOOLING-CLAIMS.md` | mutable claims inside the tooling files, which are deleted rather than corrected | `--wss-tools`, `--wss-full-check` |
| `WSS.MECHANICAL-GAUNTLET.md` | a non-green result from the project's own verifications — doctor, typecheck, suite, CI — and what each outcome means | `--wss-full-check`, `--wss-stocktake` |
| `WSS.PROSE-PRUNE.md` | prose in a skill, agent or tooling file whose removal changes nothing about what Claude does | `--wss-tools`, `--wss-full-check` |
| `WSS.AUDIT-PASS.md` | what an independent audit pass must carry — the cumulative rubric, and how focuses rotate | the audit ritual, on the owner's ask; no flag |

A method says what counts as a finding; a runner decides scope, disposition and
owner. Material that drifts to the wrong side of that line stops being borrowable.

## Backlog providers

In `workflow/providers/`. Every record is a markdown file except one:
`WSS.record.todo` may name a **provider** object instead of a path, and then the
backlog is a set of open issues. It exists because a team already living in
GitHub Issues cannot adopt a workflow whose backlog is a file — they would be
maintaining two, and the second one loses. Nothing else in `WSS.record.*` takes a
provider, deliberately: `WSS.record.decisions` and `WSS.record.openDecisions` are prose
read months later by someone reconstructing why, and an issue thread is a
conversation rather than a record.

Declared in `.claude/WSS.WORKFLOW.json`:

```json
"record": { "todo": { "provider": "github-issues", "repo": "owner/name", "label": "backlog" } }
```

| Provider | Contract | Required | Optional |
|---|---|---|---|
| GitHub Issues | `workflow/providers/WSS.GITHUB-ISSUES.md` | `repo` | `label` — without it the backlog is *every* open issue in the repository, including bug reports filed by users, which is almost never meant |

Readers key on the presence of a `provider` key rather than on the value being an
object, because `WSS.record.tooling` is an object too and is not a provider.

The mapping is the markdown one, item for item: an unchecked `- [ ]` becomes an
open issue with the label, its bold short name becomes the title, and **closing
the issue is how an item leaves the backlog** — not a "done" comment, because a
backlog is forward-looking and a closed issue is what that reads like here.
`wss-record` is the sole writer of issues carrying the label; an issue
without it belongs to somebody else.

**Every skill that touches the backlog goes through the provider, not just
`--wss-todo`** — `--wss-adopt` offers the choice and `manifest-writer` validates it,
`--wss-start`, `--wss-check` and `--wss-full-check` read it, `--wss-wrap` counts it. None of them
may write a local `WSS.TODO.md` when the remote is unreachable: a project that
declared a provider and finds a stray markdown backlog appearing has the two
backlogs this exists to prevent. They say what could not be reached and write
nothing.

`wss-doctor.sh` is where a broken one surfaces. It **fails** on a provider nothing
implements, on a missing `repo`, on a `repo` that does not resolve, and on a
declared `label` no label on the repo matches — the resolution faults being
manifest faults rather than transient ones, so they route to `--wss-adopt` in
amendment mode. It **warns** when `gh` is absent or unauthorized, because the
manifest is correct and only the machine is not.

One cost worth knowing: **a checkpoint cannot narrow an issue sweep the way it
narrows a file sweep.** A file's staleness is a diff against a baseline commit;
an issue's leaves no trace in the repository's history at all, so an issue
backlog is always read in full.

## Skills scoped to this repository

None, and the reason is worth reading before adding one.

The mechanism exists and every project may use it: a skill under
`.claude/skills/` is resolved there before the global suite, which is how a
project ships conventions the global skills cannot know. The argument for
putting one there is cost — a skill in `skills/` loads its description into
every session of every project, so one nothing else can use should not be paid
for everywhere.

This repository has none. Running a project's own checks, triaging the defects
other sessions filed, and keeping a tooling catalog from going stale are things
any adopted project
wants. What looked project-scoped was a global concern with this project's paths
hardcoded into it.

The test that follows from that: before scoping a skill to a repository, ask
whether the *concern* is local or only the *paths* are. If it is the paths, the
manifest is the answer and the skill belongs in `skills/`.

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
| `commands/wss-todo.md` | `--wss-todo` | `wss-record` |
| `commands/wss-log.md` | `--wss-log` | `wss-record` |

## Scripts

| Script | What it does |
|---|---|
| `wss-doctor.sh` | Read-only health check of this config and the project in the working directory. Prints what it checks, so the list cannot go stale |
| `wss-reset-records.sh` | Blanks every record the manifest declares back to its canonical heading, so a fork or a fresh install starts with the structure and none of somebody else’s content. Dry-run unless given `--write`; skips a provider-backed backlog, and never touches the files that describe the tooling itself. **This one travels**, and `wss-publish.sh` runs the copy of it rather than keeping a second list |
| `wss-export-records.sh` | Moves machine-local workflow state between machines — untracked record files, the lane selector, and the config directory's bug-reports inbox. Skips tracked records and the sweep checkpoint — except under `--all`, the retirement snapshot `/wss-retire` takes before deleting, which keeps tracked records in and adds the docs tree. Import is all-or-nothing, refuses escaping entries, and refuses non-empty collisions without `--force`. **This one travels** |
| `wss-retire-workflow.sh` | The tidy exit: removes the suite's machinery from a project — manifest, sweep cache, lane selector — and, only behind `--write --records`, the workflow-shaped records. Never touches the reference, changelog or tooling files, a CLAUDE.md handoff, or the suite's own tree. Dry-run by default. `/wss-retire` is the walkthrough around it. **This one travels** |
| `wss-remove-lanes.sh` | Turns worktree-lane mode off for one checkout — deletes the `.claude/WSS.LANE` selector and drops `WSS.lanes.named` and `.conflicts` from the manifest, while keeping `WSS.lanes.exclusive`, `.serialize` and `.generated`, which drive `--wss-start`'s batch partitioning inside a single checkout and are not worktree machinery. It deletes no record file under any flag: a lane record still holding content stops the write until `--allow-orphans`. Dry-run by default, and it refuses an untracked or uncommitted manifest so the rewrite stays revertible. **This one travels** |
| `wss-publish.sh` | Assembles the public tree from `HEAD` and gates it — copies only what it admits, empties the records on the copy, then asserts no ancestry, no private identifier, a whitelist of tracked paths, the credential rules, and the doctor and tests from inside the result. Never pushes, and does not travel with what it copies |
| `hooks/wss-shorthand-flags.sh` | The `UserPromptSubmit` hook that turns a `--flag` into a deterministic skill invocation rather than a judgement call |
| `hooks/wss-session-check.sh` | The `SessionStart` hook — the only thing here that speaks unasked, so it is built to stay silent unless something is worth a session's attention: a doctor failure, a sweep or a record gone stale, a filed bug report, an unread upstream filing (counted only in the suite's own checkout, where triage can act), a handoff the harness would not otherwise load, or a one-time orientation block on the first session after a plugin install, since a plugin has no channel to speak at install time |
| `hooks/wss-alert.sh` | A sound cue when a session waits for input — permission prompts, option pickers, idle, turn end. Ships silent and opts in per machine: `--wss-alerts on\|off` (served by the flag hook, no skill) toggles a state file in the config directory that this hook gates on. Sound only, cross-platform, one cue per burst |
| `hooks/hooks.json` | Declares those same events when this is installed as a **plugin**, where `settings.json` belongs to the user and a plugin never owns it. Plugin hooks merge with the user's rather than replacing them, so an adopter's own hooks keep firing |
| `.claude-plugin/plugin.json` | The manifest that makes the directory installable, and what `claude plugin validate` reads |
| `.claude-plugin/marketplace.json` | Makes the same directory its own marketplace, listing one plugin whose `source` is `"./"` — so an installer adds this repository as a marketplace and installs from it, with no second repository to keep in step. Handed a directory holding both manifests, `claude plugin validate` checks this one; name the file to check the other |
| `skills/wss-docs/assets/wss-scaffold.sh` | Creates a docsify site shell — and only the shell, never content. Refuses to touch an existing directory, and prints the steps it deliberately leaves to the caller. Invoked by `--wss-docs` in Scaffold mode |
| `skills/wss-record/assets/wss-index-decisions.sh` | Generates `WSS.record.decisionsIndex` from the decision log — one row per entry, line number and heading — and verifies it without writing under `--check`. Declared as `WSS.commands.indexRegen` / `WSS.commands.indexCheck` in this repo's manifest; refuses to run where the index key is undeclared |
| `skills/wss-overview/assets/wss-probe.sh` | Emits `--wss-overview`'s whole mechanical block in one read-only call — tree, record counts, doctor result, sweep freshness, the roadmap's current goal and the release list's current milestone — so the report costs seconds instead of a model read of every record. Offline by design: external state is reported as not counted, never as zero. Invoked by `--wss-overview` |
| `tests/wss-hook-contract.sh` | The contract tests for the hook, whose breakage is total and silent |
| `.github/workflows/publish.yml` | Fires on a release-tag push, and on manual dispatch — which is how a publication is staged when the public repo has drifted behind `dev` without a tag. Runs `wss-publish.sh` and stages the gated assembly as a PR on the public repository, never a merge. It asserts the pushed tag against `.claude-plugin/plugin.json` first, and reports rather than refuses on a dispatch run, where there is no tag to assert against. Needs the `PUBLISH_TOKEN` secret; removed from the assembly so it never ships |
| `.github/workflows/verify.yml` | CI. The doctor (twice, from both scopes) and the hook contract tests, plus shell syntax, Shellcheck, JSON validity, credential scans, skill frontmatter, cross-links and absolute-path checks. Runs on a push to any branch except `main`, on **every pull request**, and on manual dispatch — `main` is reached only through a PR, and on the published repository `main` additionally requires that PR run to be green before it can be merged |

## Agents

None. Every `agents.*` role in the manifest schema is something an *adopting*
project declares; this repository declares none, so a skill that would route a
lane to an agent does that work inline and says so.
