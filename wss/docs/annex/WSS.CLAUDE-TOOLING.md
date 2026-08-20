# Claude tooling

Exhaustive reference for every skill and script in this repository: what each
one is for, and — the part no single file shows — which of them invoke each
other.

**Source.** This page is derived from `.claude/WSS.TOOLING.md`, which `--wss-catalog`
owns and hands over. That file is the source of fact; this page is its
adaptation into the site. If the two disagree, the catalog is right and this
page is stale — which is a finding for `--wss-health-check`, not something to fix by
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

The diagram below is ASCII rather than Mermaid because `wss/docs/index.html` loads
only the search plugin; a Mermaid fence would render as raw markup for every
reader.

---

## How the pieces fit

```text
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
   │    --wss-start          --wss-health-check      --wss-release  │
   │    --wss-wrap           --wss-pr                --wss-report   │
   │    --wss-docs           --wss-adopt             --wss-overview │
   │    --wss-diagram        --wss-update            --wss-triage   │
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
   │                  --wss-plan     --wss-catalog                  │
   │                  --wss-scout                                   │
   │                  --wss-describe --wss-reference                │
   │                                                                │
   │    flagless:     contracts  (a skill)                      │
   │                                                                │
   │    procedures    sweep-tracker     handoff-writer              │
   │    under         changelog-writer  git-writer                  │
   │    wss/workflow/     manifest-writer   behaviour-writer            │
   │    writers/:     reference-writer  audit-writer                │
   │                  docs-writer                                   │
   └───────────────────────────┬────────────────────────────────────┘
                               │  the ones that write
                               ▼
              the record files, and the git history
```

**The top arrow's inheritance stops at a subagent.** A dispatched skill runs in
its caller's own context and arrives holding that caller's grant, which is the
case the label describes. A subagent is the other shape, and what it inherits is
read and write on the file set its brief declares, with no commit grant — the
rule holding unchanged where the brief says nothing about committing at all. The
rule itself, why the trace stops at that boundary and the cost it accepts are
`wss/workflow/writers/WSS.GIT-WRITER.md`'s, under "The grant is the caller's,
always". The qualifier earns its place on this page because the table below
lists `git-writer` among what `--wss-catalog` and `--wss-health-check` reach: a reader taking the picture
at face value would read that row as a lane's own authorization to commit, and a
lane is exactly the case where it is not.

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
`--wss-catalog` invokes the orchestrator `--wss-docs`, because a tier says what a skill
owns, not who may call it.

**Three orchestrators are flagless for a second reason on top of that.**
`lane-record-sync` is expensive and writes into every lane's inbox;
`retire` deletes a project's workflow files; `skill-toggle` edits the user's
`settings.json`. Slash-only invocation is what stops any of them from
happening because a sentence contained the right words. They inherit no grant,
since nothing may call them, and they confer none on anything they call, having
no flag to confer from. `lane-record-sync` is the one that does call
something — it hands its close-out to `--wss-wrap` — and that wrap therefore
arrives with nothing and asks the user for its own commit in that turn.

**Not every primitive writes**, which is why the arrow leaving that box is
labelled rather than bare. `contracts` only states how the suite is wired —
the "rule" the box label admits; an unlabelled arrow would read as though the
whole tier ended at the record files. It is a primitive on the same test as
the rest: one job, no session of its own, no authorization it did not inherit.

## Who invokes whom

A condensed copy of the canon table in `.claude/WSS.TOOLING.md`'s "Who
invokes whom", sanctioned under `wss/workflow/WSS.RECORD-CONTRACT.md`'s
exception 2: this table's cells are free to shorten, but every caller must
be one the catalog carries.

| Caller | Invokes | For |
|---|---|---|
| `--wss-adopt` | `manifest-writer`, `--wss-docs`, `git-writer`, `wss-export-records.sh --import`, `update` | writing the manifest it decided on; scaffolding a project that has no documentation; committing; restoring an archive when its up-front question — y/N, default no — gets a yes, before any record is seeded. Amending one key in an existing manifest reaches `manifest-writer` without the detection phase, which is what the split was for. A stale-convention tree — pre-rename filename, v1 schema — routes to `update`'s migration mode behind its own gate; a finished adoption stamps `WSS.suite` through `manifest-writer` |
| `--wss-update` | `wss-export-records.sh --all`, `manifest-writer`, `git-writer`, `--wss-plan` | the snapshot before the first write; the `WSS.suite` stamp and any manifest key move, only over a passing doctor; one mend per commit; content surgery that lands in a planning record — extracting embedded milestones into the release list — goes through the record's owner, not directly |
| `--wss-start` | `wss-orient.sh`, `--wss-track`, `--wss-todo` / `--wss-log`, `--wss-plan`, `--wss-health-check`, `--wss-catalog`, `--wss-docs`, `behaviour-writer`, `reference-writer`, `handoff-writer`, `git-writer`, `sweep-tracker` | building the task list before the batch; recording what a batch produced, committing it, and stamping the suite run so the next audit need not repeat it — `--wss-docs` only where a change also earns a page. Its closing handoffs run **serialized**: every record writer re-verifies against the other records, so each one's read set is all of them |
| `--wss-health-check` | `wss-survey` for the file-sharded read fan-out, `wss-duplication.sh`, `wss-mechanical-gauntlet.sh`, the owner of each record finding, `--wss-todo`, `--wss-log`, `--wss-catalog`, `wss-tools-inventory.sh`, `git-writer`, `sweep-tracker` — plus the project's own publish assembly under `--publish` where it has one — this suite's assembler does not travel — and, `--deep`'s TODO resort once taken, the manifest's `WSS.agents.audit` fan-out, `--wss-plan`, `--wss-release`, `--wss-wrap`, `audit-writer`, `handoff-writer` | one skill, four mutually exclusive modes, where `--wss-check`, `--wss-full-check`, `--wss-stocktake` / `--wss-full-stocktake` and `--wss-tidy` used to be four flags on five skills. Reads the mode's scope, runs the mechanical floor, dispatches and applies record and tooling findings itself, regenerates the catalog and the inventory after any restructuring, commits by concept, and stamps a checkpoint only for a scope that came back healthy |
| `triage` | `WSS.INBOX-TRIAGE.md`'s method, the finding's own owner once classified | works the suite's own defect inbox. **User-invocable only**: no `--wss-health-check` mode runs it |
| `--wss-release` | the manifest's `WSS.agents.release`, `--wss-health-check --deep`, `changelog-writer`, `git-writer`, `--wss-plan` | the reading — release list, cited roadmaps, changelog, TODO list, audit log, git history — returned as a proposal; everything being in order before a tag — drift included, since that is one of its dimensions — then the entry and the tag, a resumed release re-checking the entry through `changelog-writer` and not just the tag. A milestone that looks complete but is unmarked is handed to `--wss-plan`: it reads that mark and never writes it |
| `--wss-plan` | the manifest's `WSS.agents.roadmap`, `--wss-todo` | the reading — roadmaps, release list, TODO list, decision index, audit log, git history — delegated so only a proposal returns, while the asking stays here; and a task breakdown that surfaces mid-planning, which is `--wss-todo`'s file rather than a roadmap block. It *names* `--wss-release` as the next step after a mark and never invokes it |
| `lane-record-sync` | `git-writer`, `audit-writer`, `--wss-log`, `--wss-wrap` | step 0's landing, step 5's return leg and step 6's close-out — each lane's branch fast-forwarded onto `WSS.branch.integration` locally, then each lane worktree brought back onto it once the run has finished writing into them; divergence reported and never resolved, and a dirty lane worktree skipped; the run's audit entry — which reports what it promoted out of the conflict inbox and what it deleted as not reproducing — and the declined derivations as one decision entry so a later run does not re-ask them. Every finding it keeps reaches a lane through that lane's transfer queue, never by writing its records. Having no flag it passes no grant down, so the wrap it dispatches asks the user for its own commit in that turn and never offers the push — step 0's local landings would otherwise reach the remote as a side effect of tidying up; step 6 runs even where step 5 skipped every lane |
| `--wss-wrap` | `handoff-writer`, `--wss-plan`, `git-writer` | the handoff, the milestone question — **from the main checkout only**, since a mark is a checkpoint for the whole project — the commits. It *names* `--wss-pr` where the pushed branch is ahead of `WSS.branch.publish`, and never invokes it — a session ending and work being ready to merge are two different facts |
| `--wss-pr` | `git-writer`, `--wss-todo` | the merge, once the user confirms in that turn; and the review threads nobody resolved, which the merge is about to hide — proposed to the user, never filed automatically, because a meaningful share of unresolved threads is chatter. It drafts the body and holds the gate, and writes nothing itself |
| `--wss-catalog` | `docs-writer`, `--wss-docs`, `git-writer`, `wss-tools-inventory.sh` | running the collector before it renders, then handing the catalog over to the writer — `--wss-docs` only where the annex page does not exist yet and its placement has to be decided. It draws the diagram above itself. It holds no numbers: every measured fact is `WSS.record.tooling.inventory`'s, and a row here points at that entry rather than repeating it |
| `--wss-docs` | `docs-writer`, `wss-docs-audit.sh`, `--wss-todo`, `--wss-track`, `sweep-tracker`, `behaviour-writer`, `reference-writer` | every write to the site, which it decides and never performs; parking a page set larger than one session, since it stores no state of its own; narrowing its next audit; and handing over a subject that turns out to be a runtime rule or reference material rather than a page, which it never writes itself |
| `--wss-scout` | `--wss-log` | the reasoning entry an adoption earns, at the moment the user adopts — the registry row stays lean and points at it |
| `retire` | `wss-retire-workflow.sh` (`--dir`, then `--suite`), `wss-export-records.sh --all`, `wss-reset-records.sh`, and `claude plugin uninstall` for the user to run | the tidy exit, sequenced: a dry run, one checkbox dialog, then the checked actions in dependency order — the snapshot before any deletion, a wipe before the machinery delete that removes the manifest it reads, the installation last in either form, since it removes the skills the walkthrough runs on |
| `skill-toggle` | `wss-skill-levels.sh` | step 1's level table in one deterministic call — the two settings reads, the two tree enumerations, the merge — rather than a re-derivation each invocation |

`--wss-health-check` appears as a caller and never as a callee of a write: an
inspector that writes is a second writer on every file it touches.

## Global skills

In `skills/`, loaded in every project.

| Skill | Flag | What it does |
|---|---|---|
| `adopt` | `--wss-adopt` | Brings a project under this workflow — detects its shape, maps files it already has, decides what its `.claude/WSS.WORKFLOW.json` should say and hands that to `manifest-writer`, proposes `permissions.ask` gating for the destructive commands it finds, and hands a project with no documentation to `--wss-docs`. The detection and the asking are what stay here: a primitive has no channel to reach the user. A tree carrying a *previous* suite convention is recognized before the adoption/amendment verdict and routed to `update`'s migration mode |
| `update` | `--wss-update` | Updates the suite install (checkout pull `--ff-only`, or plugin update), then detects what conventions the adopted tree actually carries and migrates it to the newest — detection is the authority, the `WSS.suite` stamp and the release list's `- migrate:` lines only set the starting point. Its own consent gate shows the full plan of mends; the snapshot precedes the first write; one mend per commit, a partial migration never exits clean, append-only records are never rewritten, and the stamp lands last, only over a passing doctor |
| `docs` | `--wss-docs` `--wss-diagram` | Decides what this documentation site holds — whether a subject belongs on it at all, which page, and which tier it lands in — then hands the target to `docs-writer`, which writes it. Owns the workflow-page shape: an end-to-end flow as a diagram plus stages citing the behaviour record and the code. `--wss-diagram` is the ad-hoc entry: one diagram, placed here and drawn by the writer under the style guide's three rules, landed as an annex page. The behaviour and reference records are `behaviour-writer`'s and `reference-writer`'s |
| `health-check` | `--wss-health-check` | Asks whether the project is healthy — the mechanical floor, then every declared record and tooling file, read for drift and staleness. **One skill, four mutually exclusive modes**: `--shallow` reads and reports and applies nothing; the bare run adds dispatch-and-apply; `--deep` ignores every checkpoint and ask-gates a TODO resort; `--publish` narrows to the shipping set with the publish gates in its floor. `--wss-release` runs `--deep` before a tag. It stamps a checkpoint **only for a healthy scope**. Reports the inbox's open count at hand-off and never triages it |
| `triage` | `--wss-triage` | Works the suite's own defect inbox — which filed defects reproduce, which went stale, which were never true. **User-invocable only**: no `health-check` mode runs it |
| `pr` | `--wss-pr` | Moves work from the integration branch onto the publish branch through a pull request — drafts the body from the branch range rather than from memory, opens it, watches its CI, and merges behind a fresh confirmation. The only thing in the suite that moves work between the two branches |
| `record` | `--wss-todo`, `--wss-log` | Parks work that is not being built now, and records decisions already made |
| `describe` | `--wss-describe` | Gets a runtime rule settled in conversation into `WSS.record.behaviour`, which every other route reaches only as a side effect of a check or a build. Dispatches to `behaviour-writer` and writes nothing itself; its own work is turning away the three things handed to it by mistake — reasoning and decided-but-unbuilt behaviour, both `--wss-log`'s, and stack or architecture, which is `--wss-reference`'s |
| `reference` | `--wss-reference` | Gets a fact about what the project *is* — stack, architecture, data model, a convention — into `WSS.record.reference`, the same shape as `describe` one record over. Dispatches to `reference-writer` and writes nothing itself; it names the exact file the fact resolved to before anything is written, because a manifest may map the project's `README.md` into the reference array and the flag then reaches a public landing page |
| `scout` | `--wss-scout` | Consults the project's toolbelt registry before any capability gets hand-built, searches the stack's public registries when the registry has no answer, and explains the candidates — advises, never implements. Sole writer of `WSS.record.toolbelt`; the reasoning behind each row goes through `--wss-log` |
| `report` | `--wss-report` | Files a finding about this suite upstream — appends it to the machine-local inbox, then opens a GitHub issue on the public repository behind a preview, a redaction of the project context, and a fresh OK. Can bundle every open inbox entry under the same rules; hazards are referenced by group name, never quoted |
| `release` | `--wss-release` | Decides that a version ships — once `WSS.record.releases` marks a milestone done, or once it has declared an end to milestones and the release is maintenance on evidence — and asks before anything is published |
| `plan` | `--wss-plan` | Sets the next goal in `WSS.record.roadmap` — which splits by lane — and keeps `WSS.record.releases`, the release list, where the milestones, their versions and their marks live. A roadmap carries neither |
| `overview` | `--wss-overview` | Reports where a project stands at a glance — branch and lane, per-record counts, sweep freshness, pending warnings, the nearest milestones — read fresh at invocation, writing nothing at all. Every mechanical number comes from its probe script in one call; the model adds only the judgment lines. The read-only sibling of `--wss-health-check`: it counts what the records say and never verifies them |
| `start` | `--wss-start` | Picks up pending work and does it, in parallel lanes partitioned so they cannot collide |
| `catalog` | `--wss-catalog` | Keeps this catalog current and draws the diagram above — what each tool is *for*, in one human sentence per row, and who invokes whom. Hands it to `docs-writer` where a site exists. It contains no numbers by construction: the measured half is `.claude/WSS.TOOLS.json` |
| `track` | `--wss-track` | Builds the visible task list for multi-step work and keeps it honest as the work moves |
| `retire` | — | Retires the workflow from a project — the reverse of `--wss-adopt`. Shows what would go, then one checkbox dialog: a full snapshot (`WSS.RETIREMENT-PLAN.tar.gz`, restorable at re-adoption) asked first, then the actions to run — delete the machinery, delete the records, wipe the records, uninstall the plugin — executed in dependency order, a wipe skipped as redundant beside a records delete. Slash-invoked only, and its frontmatter blocks model invocation, so a deletion never fires from a phrase |
| `lane-record-sync` | — | Reconciles every lane's records at once, from the main checkout: conflicts between lanes are mediated with the user, work one lane's plans imply for another is presented for an explicit ruling — accept, accept as critical, defer or decline, the last two differing in whether the next run asks again, and what is approved is appended to the addressed lane's **transfer queue** — never to its records. Expensive, and slash-invoked only so it can never fire from a phrase or a batch. See [Lane synching](WSS.LANE-SYNCHING.md) |
| `contracts` | — | States how the suite is wired: that the skills are global, that project facts come from `.claude/WSS.WORKFLOW.json`, what a project without a manifest falls back to, and where the contracts resolve in a checkout against a plugin install. It exists because a plugin root's `CLAUDE.md` is never loaded as project context, so an adopter who installs rather than clones would otherwise see none of it |
| `skill-toggle` | — | Toggles what each skill costs at session start: shows every skill's current `skillOverrides` level, then sets `on`, `name-only`, `user-invocable-only` or `off` in the user's `settings.json` — refusing a level that would break a skill another skill dispatches to, and warning when a change silences a flag. Slash-invoked only, its frontmatter blocks model invocation, and it is the checkout form's lever: the harness ignores overrides for plugin skills |
| `wrap` | `--wss-wrap` | Closes out a session — task list, a handoff that `handoff-writer` rewrites wholesale from what the session knows rather than reading the old one, commits, the milestone question, and from a lane worktree syncs that lane forward before reporting, then lands it on `WSS.branch.integration` by fast-forward — both refused rather than forced, and the landing withheld entirely when the wrap fired on an unfinished session. Its mechanical readout — dirty files, unpushed commits, record counts, open decisions, the roadmap's next block, sweep freshness — comes from one call to its status script, so only the judgment lines are the model's. A readout of where the project stands, and whether it is safe to clear |
| `audit` | `/wss:audit` only — no flag, model invocation blocked | Runs an independent audit pass over the suite and files the frozen report into `wss/logs/audits/`. Refuses to run in a session that prepared the tree it would be judging |


## The record procedures

In `wss/workflow/writers/`, **not** in `skills/`. A caller reaches one by reading
the file; there is nothing to invoke, and nothing loads unless a caller opens
it. They left `skills/` because a skill description is a
per-session cost paid whether or not the skill is used, and each of these
declared in its own description that only other skills invoked it. Ownership is
unchanged — `wss/workflow/WSS.OWNERSHIP.md` remains the authority, and `wss/workflow/writers/WSS.WRITERS.md` indexes the writers.

| Procedure | Sole writer of | What it does |
|---|---|---|
| `audit-writer` | `WSS.record.stocktake`, `WSS.record.audits` | Writes the stocktake log entry — what a stocktake examined, against which tree, and what it found, with its coverage block — plus the one-field `Outcome` update when remediation lands, which is why it is not part of `--wss-health-check`. Also appends the index row in `WSS.record.audits` when an independent audit pass lands |
| `behaviour-writer` | `WSS.record.behaviour` | Writes the record of what the system does at runtime, by topic. Never *why* it does it, which is `--wss-log`'s. Reached by dispatch from a check or a build, or directly through `--wss-describe` |
| `changelog-writer` | `WSS.record.changelog` | Writes the changelog entry for a version, and marks an entry unreleased when the documents claim more than the tags do |
| `docs-writer` | the documentation site | Writes every page and annex page of this site, their `_sidebar.md` and `index.md` rows, the translation mirrors, and the diagrams inside them — re-rendering a diagram a caller hands over rather than reshaping it. It decides nothing: whether a subject earns a page, which page, and which tier are `--wss-docs`' calls, settled before it is invoked |
| `git-writer` | commits and tags | Makes the commits, the tags and `--wss-pr`'s merge for every skill that may, so the rules that keep a commit, a merge or a push safe live in one file rather than in whichever caller remembered them |
| `handoff-writer` | `WSS.record.handoff` | Writes the handoff a fresh session inherits, at whatever scope its caller asked for |
| `manifest-writer` | `.claude/WSS.WORKFLOW.json` | Writes `.claude/WSS.WORKFLOW.json` — validates each key against `wss/workflow/WSS.MANIFEST.md`, refuses one nothing reads or whose path does not resolve, and runs the doctor. Decides nothing: the caller arrives having settled the values |
| `reference-writer` | `WSS.record.reference` | Writes the record of what the system *is* — stack, architecture, data model, stated conventions. Often the project's `README.md`, where the manifest maps it there. Reached by dispatch from a check or a build, or directly through `--wss-reference` |
| `sweep-tracker` | the sweep checkpoint | Records which commit each sweep last verified and what it covered, so the next one re-reads only what changed. It refuses a stamp claiming a commit with no coverage — except a freshness-only entry, which claims none and licenses nothing |

## The shared check methods

In `wss/tests/`, not in the skills that wrote them. Each is one way of
finding inconsistency in something the project has written down; the skill that
runs one supplies the scope and decides what happens to a finding.

Each is single-sourced here because a method reached by citing another skill's
headings breaks silently on a rename, leaving the borrower reporting success
over checks it never ran.

A condensed copy of the canon table in `wss/tests/WSS.CHECKS.md`, sanctioned
under `wss/workflow/WSS.RECORD-CONTRACT.md`'s exception 2: this table's cells
are free to shorten, but every row label must still be one the canon
carries.

| Method | What it finds | Run by |
|---|---|---|
| `WSS.RECORD-DRIFT.md` | the classes of drift in a record, and the things that look like drift and are not | `--wss-health-check`, at any depth |
| `WSS.DOCS-AUDIT.md` | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--wss-docs`, `--wss-health-check --deep` |
| `WSS.TOOLING-CLAIMS.md` | mutable claims inside the tooling files, which are deleted rather than corrected | `--wss-health-check`, at any depth |
| `WSS.MECHANICAL-GAUNTLET.md` | a non-green result from the project's own verifications — doctor, typecheck, suite, CI — and what each outcome means | `--wss-health-check`, at any depth, and its `--deep` TODO resort |
| `WSS.PROSE-PRUNE.md` | prose in a skill, agent or tooling file whose removal changes nothing about what Claude does | `--wss-health-check` |
| `WSS.AUDIT-PASS.md` | what an independent audit pass must carry — the cumulative rubric, and how focuses rotate | the audit ritual, on the owner's ask; no flag |
| `WSS.TOKEN-ECONOMY.md` | a skill, agent or tooling file paying more context than its job needs — each lens with a proven in-tree example and the drawback to outweigh | `--wss-health-check` |
| `WSS.ROT-RESISTANCE.md` | writing that is true today and structured to go false — an uncompared copy, a file with two writers, a claim nothing can test, a drift nothing would report | `--wss-health-check` |
| `WSS.ROUTING-HEALTH.md` | a skill that will not be reached when it should be, or will be when it should not — the one check that can push a description longer | `--wss-health-check` |

A method says what counts as a finding; a runner decides scope, disposition and
owner. `wss/tests/WSS.CHECKS.md` holds that line, and material that drifts to the wrong side of it stops being borrowable.

## TODO list providers

In `wss/workflow/providers/`. Every record is a markdown file except one:
`WSS.record.todo` may name a **provider** object instead of a path, and then the
TODO list is a set of open issues. It exists because a team already living in
GitHub Issues cannot adopt a workflow whose TODO list is a file — they would be
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
| GitHub Issues | `wss/workflow/providers/WSS.GITHUB-ISSUES.md` | `repo` | `label` — without it the TODO list is *every* open issue in the repository, including bug reports filed by users, which is almost never meant |

Readers key on the presence of a `provider` key rather than on the value being an
object, because `WSS.record.tooling` is an object too and is not a provider.

The mapping is the markdown one, item for item: an unchecked `- [ ]` becomes an
open issue with the label, its bold short name becomes the title, and **closing
the issue is how an item leaves the TODO list** — not a "done" comment, because a
TODO list is forward-looking and a closed issue is what that reads like here.
`record` is the sole writer of issues carrying the label; an issue
without it belongs to somebody else.

**Every skill that touches the TODO list goes through the provider, not just
`--wss-todo`** — `--wss-adopt` offers the choice and `manifest-writer` validates it,
`--wss-start` and `--wss-health-check` read it, `--wss-wrap` counts it. None of them
may write a local `WSS.TODO.md` when the remote is unreachable: a project that
declared a provider and finds a stray markdown TODO list appearing has the two
TODO lists this exists to prevent. They say what could not be reached and write
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
TODO list is always read in full.

## The audit ritual

`audit` **ships** — the ruling is the decision log's `2026-08-19
(eighty-first)` entry. It is the second half of a pair: `--wss-health-check
--publish` prepares the tree — the mechanical floor, the publish gates, every
lens over the tooling files and the records, bounded fixes applied, derived
artifacts regenerated, the resulting commit pinned — and this skill judges it,
in a deliberately separate run, because a session that spent the morning fixing
cannot audit its own work.

**Slash-only — no flag, model invocation blocked** — so the command is the whole
route by design. The frozen reports land in an `audits/` directory beside the
index `WSS.record.audits` names; where that key is undeclared the skill says so
and stops, rather than filing reports somewhere nothing indexes them.

## Command wrappers

In `commands/`, one file per verb flag of a multi-verb skill — a flag whose
name differs from its skill's for a reason other than a scope-variant prefix
(no currently-shipped flag uses one; the pattern's last example,
`--wss-full-stocktake`, retired into `--wss-health-check --deep`). The wrapper's filename **is** the flag, so
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

## Scripts

| Script | What it does |
|---|---|
| `wss-doctor.sh` | Read-only health check of this config and the project in the working directory. Prints every check it performs except the note class, which is counted in every run and printed only under `--notes`; the summary always says how many notes were withheld and how to see them, so the list cannot go stale silently |
| `wss-tools-inventory.sh` | Walks a tooling surface — this installation's own, by default — and writes `.claude/WSS.TOOLS.json`: one entry per skill, agent, script, hook, command, check, writer, contract and reference, carrying every *measured* fact about it, while the catalog keeps the judgement. Dependencies are named rather than located, since a name is what the harness dispatches by and a `path:line` is what drifts. `--check` regenerates to a temp file and diffs, failing on any difference, so the output is deterministic by construction and the artifact is tracked rather than derived on demand. `--root` points the *enumeration* somewhere else, for a caller wanting a project's own skills measured instead — the doctor uses it on a project-local skill it could otherwise only report as unmeasured. What that flag deliberately does not move is where contracts are looked up: a project's skills cite the suite's `wss/workflow/`, so classification stays anchored to the installation, and repointing it too would report every chain as merely the file's own bytes. Such a run prints and never persists, this artifact naming only this suite's entries; an unresolvable `--root` exits non-zero rather than measuring nothing, an honest notice beating a confident wrong figure. It holds the chain walk that used to live in the doctor, giving that figure one implementation instead of two. Writes its artifact and stops — no commit grant |
| `hooks/wss-tools-inventory-hook.sh` | The `PostToolUse` hook that regenerates the inventory when a tooling file of *this installation* is edited, anchored to the installation before any pattern is tried. Synchronous and never backgrounded, since a regeneration racing the doctor’s staleness check is the failure the arrangement avoids. The convenience layer rather than the guarantee — the doctor is that — which is what lets its filter be loose. Silent unless it fires, and always exits zero, so it can never block a tool call |
| `wss-append-only.sh` | Fails any change that deletes a line from a record `WSS.recordMode` tags `log`. The set comes from the manifest rather than from a directory, so an adopted project inherits the check by declaring its own write modes; a `generated` record is out of scope by its tag rather than by an exemption on its name. Three deletions are legal and each is a clause of the record contract — a record's header, an `Outcome:` block, and the draft entry at either end where the same hunk rewrites it — chosen by measuring every commit that had ever deleted from a log, because a guard that reddens on ordinary work gets bypassed. An entry count that falls and a record that vanishes are caught separately, since neither shows up as a deleted line. Runs as a CI step, and as a `.git/hooks/pre-commit` where `--install-hook` has been run: that half is per-clone and untracked, so CI is the enforcement and the hook is the early warning. `wss-doctor.sh` reports which of the two a clone has — a pass where the hook is installed, a warning where it is not — so a checkout guarded by CI alone is now visible instead of reading exactly like one guarded on both sides. It says nothing under CI, where the checkout commits nothing and the guard runs as a workflow step of its own. Resolving zero log records is a hard failure, not a clean pass |
| `wss-commit-provenance.sh` | Makes a record-touching commit declare which records it writes and under whose authority. The declaration is a delimited block in the commit message — `prepare-commit-msg` emits it, `commit-msg` asserts it — and only the block's interior is fixed, so the author writes freely before and after it. That is what a commit trailer could never offer: a trailing line is reflowed by humans and tooling alike, which would make an ordinary hand commit a violation. A commit touching no record is silent. **It catches mistakes rather than misconduct**, the authority being self-declared — what it sees is a session writing a record from the wrong skill, the one failure no tree-level check can reach, having no baseline to diff against. In scope means declared *and* claimed: a path reaches it only through a manifest key the ownership matrix names a sole writer for, so a file the manifest carries under some other key is silent by declaration rather than by exemption. One record spanning several files is one line with several paths; one file claimed by two records is two lines, with no arbitration. It also owns the sole-writer matrix parser `wss-doctor.sh` once held inline, which the doctor now calls out to so the two cannot drift — resolved from the installation the doctor was run from, never from the tree it is checking. `--install-hook` writes both hooks for the current clone and is per-clone and untracked like the guard above, so CI stays the enforcement and the hook is the early warning |
| `wss-reset-records.sh` | Blanks every record the manifest declares back to its canonical heading, so a fork or a fresh install starts with the structure and none of somebody else’s content. Dry-run unless given `--write`; skips a provider-backed TODO list, and never touches `WSS.record.reference` or `WSS.record.tooling.catalog`, which describe the tooling rather than the project. **This one travels**, and `wss-publish.sh` runs the copy of it rather than keeping a second list |
| `wss-export-records.sh` | Moves machine-local workflow state between machines — untracked record files, the lane selector, and the config directory's bug-reports inbox. Skips tracked records and the sweep checkpoint — except under `--all`, the retirement snapshot `/wss:retire` takes before deleting, which keeps tracked records in and adds the docs tree. Import is all-or-nothing, refuses escaping entries, and refuses non-empty collisions without `--force`. **This one travels** |
| `wss-retire-workflow.sh` | The tidy exit: removes the suite's machinery from a project — manifest, sweep cache, lane selector — and, only behind `--write --records`, the workflow-shaped records. Never touches the reference, changelog or tooling files, a CLAUDE.md handoff, or the suite's own tree. Dry-run by default. `/wss:retire` is the walkthrough around it. **This one travels**. `--suite` is the other direction — the installation rather than a project: it names any plugin install for the harness to uninstall, deletes a checkout by `git ls-files` keeping `CLAUDE.md` and `settings.json`, and reports what a running script cannot unlink |
| `wss-remove-lanes.sh` | Turns worktree-lane mode off for one checkout — deletes the `.claude/WSS.LANE` selector and drops `WSS.lanes.named` and `.conflicts` from the manifest, while keeping `WSS.lanes.exclusive`, `.serialize` and `.generated`, which drive `--wss-start`'s batch partitioning inside a single checkout and are not worktree machinery. It deletes no record file under any flag: a lane record still holding content stops the write until `--allow-orphans`. Dry-run by default, and it refuses an untracked or uncommitted manifest so the rewrite stays revertible. **This one travels** |
| `wss-tree-survey.sh` | Answers "which of my projects can exercise this surface" from each project's own manifest rather than from its name. Run it in a project root and it prints that tree's adoption state and manifest schema — including a pre-rename `.claude/workflow.json`, which every other current reader sees as cleanly absent — then the properties a mapping turns on: lanes, TODO list as a file or a provider, behaviour record, local CI, branches, commands, and whether every declared record file actually exists. It names what it could not read instead of leaving a row blank. Read-only, and deliberately a script rather than a skill: a skill's description is billed to every plugin consumer in every session, and this is a finite task. **This one travels; its output does not** — a survey names a private project's paths and record layout, so it is read locally and never filed through `--wss-report` or an issue |
| `wss-survey-all.sh` | Answers the same question as the surveyor asked of a whole machine: run it over the roots you name and it surveys every adopted tree beneath them — both manifest filenames, so a pre-rename tree is found rather than passed over — writes one survey per tree outside every tree, and then prints the two things a stack of individual surveys cannot tell you. First, **how many projects there are**, which is not how many directories there are: worktrees of one checkout are grouped by their resolved git common directory and the main checkout is the member every conclusion is read from, because six directories sharing one checkout read as six candidates and can be exercised once. Second, a surface-to-candidate rollup taken from each project's manifest, which separates a surface with no candidate from one whose evidence was never read — a doctor that could not run and a TODO list `gh` could not reach are carried through as flags, and `/wss:retire` is printed as undetectable rather than inferred, since no key records whether a project is winding down. Read-only. **This one travels; its output does not**, and less so than the surveyor's — a single file here names every private tree on the machine |
| `wss-audit-assets.sh` | Emits the deterministic measurements an independent audit pass needs — the mechanical floor with the doctor and contract suite actually run, per-skill sizes, always-on components, sweep distances, record counts — so a pass spends its model tokens only on judgment rather than on counting. Born from pass 14 measuring its own survey subagents at ≈219k tokens, most of it re-deriving `wc -c`. Deliberately does not run `wss-publish.sh`, which the pass exercises itself as a gate, watching it. Reads this repo's own record paths, so it does not travel — except in one mode. `--always-on-basis [--root DIR]` skips the mechanical floor entirely and prints the always-on basis total as a single integer, measuring the project at `--root` or `$PWD` rather than the tree the script itself lives in. That mode exists so `wss-wrap-status.sh` can reuse this measurement instead of mirroring its formula, and the root argument is what stops it reporting the suite's own bytes as the project's. It resolves the handoff from `WSS.record.handoff`, falls back to the `wss/records/WSS.HANDOFF.md` convention where no manifest declares one, and exits non-zero naming both when neither resolves — deliberately, since the basis total is incomplete without the handoff card and a short total understates every delta measured against it |
| `wss-publish.sh` | Assembles the public tree from `HEAD` and gates it — copies only what it admits, empties the records on the copy, then asserts no ancestry, no private identifier, a whitelist of tracked paths, the credential rules, and the doctor and tests from inside the result. Never pushes, and does not travel with what it copies |
| `hooks/wss-shorthand-flags.sh` | The `UserPromptSubmit` hook that turns a `--flag` into a deterministic skill invocation rather than a judgement call |
| `hooks/wss-session-check.sh` | The `SessionStart` hook — the only thing here that speaks unasked, so it is built to stay silent unless something is worth a session's attention: a doctor failure, a sweep or a record gone stale, a filed bug report, an unread upstream filing (counted only in the suite's own checkout, where triage can act), a handoff the harness would not otherwise load, the setup record where a project declares one — per-machine facts and toggles, injected whole, size-capped by the doctor — or a one-time orientation block on the first session after a plugin install, since a plugin has no channel to speak at install time |
| `hooks/wss-alert.sh` | A sound cue when a session waits for input — permission prompts, option pickers, idle, turn end. Ships silent and opts in per machine: `--wss-alerts on\|off` (served by the flag hook, no skill) toggles a state file in the config directory that this hook gates on. Sound only, cross-platform, one cue per burst |
| `hooks/hooks.json` | Declares those same events when this is installed as a **plugin**, where `settings.json` belongs to the user and a plugin never owns it. Plugin hooks merge with the user's rather than replacing them, so an adopter's own hooks keep firing |
| `.claude-plugin/plugin.json` | The manifest that makes the directory installable, and what `claude plugin validate` reads |
| `.claude-plugin/marketplace.json` | Makes the same directory its own marketplace, listing one plugin whose `source` is `"./"` — so an installer adds this repository as a marketplace and installs from it, with no second repository to keep in step. Handed a directory holding both manifests, `claude plugin validate` checks this one; name the file to check the other |
| `wss-mechanical-gauntlet.sh` | Runs the mechanical gauntlet in one call — the doctor, the project's typecheck, its full test suite and CI resolved against the declared workflow — and prints the verdict block, so a runner stops retyping four commands it would otherwise re-emit into Bash on every audit. The method file stays the contract and keeps the two calls the script deliberately does not make: whether the user was asked for test consent, and whether a carry-forward is licensed. Both arrive as flags, and the consent flag is required only where the project declares a consent environment variable — a project that set no gate is not gated by one. Finds the doctor beside itself rather than through a home directory, so it reads a plugin cache and a checkout alike, and re-runs a failing suite once before calling it a finding. Exits non-zero only on a real failure: an undeclared command or an unrun suite is reported, never failed |
| `wss-sweep-stamp.sh` | `sweep-tracker`'s implementation for the sweep checkpoint. Three shapes — freshness-only, a test run, and a scoped entry taking its coverage lists from a file — and it computes the baseline itself from the working tree rather than accepting one, which is what makes a stamp misreporting the commit it claims structurally impossible instead of merely discouraged; the dirty marker is derived the same way, so a stamp cannot quietly claim a clean tree. It refuses rather than half-writes: an empty or missing scope list, a malformed or duplicated scope, a checkpoint path that is not gitignored, an existing file of the wrong shape. Only the named entry is merged; every other one stays byte-identical. Deciding *what* was covered remains the caller's judgement and is deliberately not in here |
| `wss-docs-audit.sh` | The mechanical half of the docs-drift method, as named subcommands run singly or all in order — resolve the project's shape, then the dead-path, link, type, translation-parity, index-parity, mechanics and accuracy checks. It reads the docs root, the languages and the dev command from the manifest with declared fallbacks, so it works against an adopted tree's own layout instead of guessing at one, and short-circuits every check to a named skip where no root resolves — walking an empty set and reporting a clean site is the one failure that method cannot survive silently. What a finding *means*, and what makes a hit a false positive, stays in the method |
| `skills/docs/assets/wss-scaffold.sh` | Creates a docsify site shell — and only the shell, never content. Refuses to touch an existing directory, and prints the steps it deliberately leaves to the caller. Takes the site's root from `WSS.docs.root` and its languages from `WSS.docs.languages` rather than as arguments — `--root` and the positional language list override, each origin is announced on every run, and absent still means monolingual — which makes it the one skill asset that reads the manifest. A declared `languages` that is not a non-empty array of non-empty strings exits before anything is created, naming the key; an unparseable manifest is a different answer and stays a fallback, reported once. Invoked by `--wss-docs` in Scaffold mode |
| `skills/record/assets/wss-index-decisions.sh` | Generates `WSS.record.decisionsIndex` from the decision log — one row per entry, line number and heading — and verifies it without writing under `--check`. Declared as `WSS.commands.indexRegen` / `WSS.commands.indexCheck` in this repo's manifest; refuses to run where the index key is undeclared |
| `skills/overview/assets/wss-probe.sh` | Emits `--wss-overview`'s whole mechanical block in one read-only call — tree, record counts, doctor result, sweep freshness, the roadmap's current goal, the release list's current milestone, and whether a release is in flight — so the report costs seconds instead of a model read of every record. The release-in-flight check compares the plugin manifest's version against the newest tag and distinguishes between both absences, since no tag and a missing manifest are separate facts neither of which is "nothing in flight"; the probe's standing rule that undeclared, missing and a real zero must never render the same bare answer is maintained. Offline by design: external state is reported as not counted, never as zero. Invoked by `--wss-overview` |
| `skills/overview/assets/wss-sweep-distance.sh` | Answers how far each sweep baseline has fallen behind `HEAD`, computed once and rendered twice: `--verbose` for `wss-probe.sh`'s `== sweeps ==` block, which prints baseline, stamp, method, result and distance one entry per line, and `--compact` for `--wss-wrap` step 7's single closing line. It exists because those two renderings were previously two implementations — one a script the contract suite could reach, the other a fenced block in a skill's prose that nothing ever executed — and they had already diverged where nothing would report it. Read-only and offline: it reads the manifest, the checkpoint and git, and writes nothing, since advancing a baseline is `sweep-tracker`'s and measuring one is not the same act. **The figures are a report and never a gate** — every path exits 0, including no checkpoint, no entries and a baseline that is off this history, so no caller can be blocked by it; only a usage error is non-zero |
| `wss/tests/wss-hook-contract.sh` | The contract tests for the hook, whose breakage is total and silent |
| `.github/workflows/publish.yml` | Fires on a release-tag push, and on manual dispatch — which is how a publication is staged when the public repo has drifted behind `dev` without a tag. Runs `wss-publish.sh` and stages the gated assembly as a PR on the public repository, never a merge. It asserts the pushed tag against `.claude-plugin/plugin.json` first, and reports rather than refuses on a dispatch run, where there is no tag to assert against. Needs the `PUBLISH_TOKEN` secret; removed from the assembly so it never ships |
| `.github/workflows/verify.yml` | CI. The doctor, the hook contract tests, and the static checks the workflow file itself enumerates. Runs on a push to any branch except `main`, on **every pull request**, and on manual dispatch — `main` is reached only through a PR, and on the published repository `main` additionally requires that PR run to be green before it can be merged |
| `skills/start/assets/wss-orient.sh` | Emits `--wss-start` Phase 0's whole mechanical block in one read-only call: the tree pin, CI where the manifest names a workflow, each planning record's resolved path, whether it exists and its size, the open-decisions entry count, and the sweep distances — delegated to `wss-sweep-distance.sh` above rather than computed a second time. It reports facts and never their meaning: it opens no record's contents, so Phase 0's own read of the three planning records is never made optional by it. Honours a lane selector through the manifest's per-lane record overrides, and degrades rather than misreports — an unreachable CI reads as not checked, never as green or zero |
| `skills/wrap/assets/wss-wrap-status.sh` | Emits `--wss-wrap`'s whole mechanical block in one call: dirty files, unpushed commits, how far ahead of `WSS.branch.publish` the branch sits, the four record counts, open-decision titles, the roadmap's next unchecked block, whether the last block of a goal just closed, the sweep line, and the always-on-bytes delta against the previous wrap — reusing `wss-sweep-distance.sh` above and `wss-audit-assets.sh --always-on-basis` rather than reimplementing either. Resolves every record path from the manifest, and honours a `.claude/WSS.LANE` selector through `WSS.lanes.named.<lane>.records.*` overrides. A report, never a gate, on the same contract as `wss-sweep-distance.sh`: it always exits 0. Read-only but for a single file it owns outright — `.claude/WSS.ALWAYS-ON-STAMP.json`, gitignored and machine-local, holding the baseline the next run measures its delta against; it stages, commits, pushes and advances nothing. Offline by design — external state it cannot reach is reported as not counted, never as zero |
| `skills/wrap/assets/wss-handoff-state.sh` | `handoff-writer`'s implementation for `WSS.record.handoff` and `wss/records/WSS.HAZARDS.md`. Three subcommands: `state` wholesale-replaces everything between the card marker and the `## Where everything else is` heading, without reading the old body first; `hazard-append` and `hazard-delete` add or remove one hazard paragraph by locating its `## `-heading anchor, each required to occur exactly once and in order. Every write is checked against the 4,096 B card cap before it lands; writes are atomic and preserve permission bits, and any violation aborts with the file byte-identical |
| `skills/skill-toggle/assets/wss-skill-levels.sh` | Emits `skill-toggle` step 1's level table in one call: every skill directory under both `skills/` trees, its effective `skillOverrides` level, which settings file set it, which tree it came from, and whether its own frontmatter hides it. Refuses rather than rendering a table it cannot trust — no `jq`, invalid settings JSON, or no skills tree at all — and lists any `CLAUDE_PLUGIN_ROOT` skills separately as not controllable here. Read-only |
| `wss/workflow/writers/assets/wss-git-commit.sh` | `git-writer`'s implementation: stages files by exact name — a file list structurally cannot become `git add -A` — assembles and verifies the commit trailer, refuses a push refspec with a leading `+` before touching git, and hands a push rejection back rather than retrying or forcing it. Every project and session fact — the trailer key, the co-author line — arrives as an argument; none is hardcoded, so nothing here goes stale when the model behind a session changes |

## Agents

| Agent | What it does |
|---|---|
| `wss-release-prep` | Prepares a release's material for `--wss-release`: the version tier and which trigger fired, the changelog entry text, and any drift between what the release list and changelog claim shipped and what a tag resolves. It writes nothing, tags nothing and publishes nothing. Declared as `WSS.agents.release`. The dispatch ladder's assignment table puts it at the top tier, which is spelled by carrying no `model:` key at all |
| `wss-survey` | The agent form of `wss/workflow/WSS.DISPATCH-LADDER.md`'s Survey rung: handed both a read set and a verdict format, it returns `file:line` verdicts and nothing else. Holds `Read, Grep, Glob, Bash` — no write tool, so "readers report, they do not write" is enforced by the grant rather than asked for, and no `Agent` tool, so it cannot report delegated coverage as its own. The ladder's assignment table resolves it to the bottom tier and its `model:` is copied from that row, so a caller naming it passes no override |
| `wss-analyze` | The Analyze rung: it chooses its own read set against an open question and returns the plan, finding or artifact citation another rung then works from. The top tier, because choosing a read set is the expensive judgement the cheaper rungs are defined by not making. Holds `Read, Grep, Glob, Bash` and writes no files, and carries no `model:` key, because that absence is how the assignment table's top tier is written |
| `wss-design` | The Design rung: handed a settled brief, it produces the design — an interface, a shape, a file-by-file sequence — and stops there without implementing it. Same grant as the surveyor and the analyst; what separates it from Analyze is that its scope arrives rather than being chosen. The assignment table puts it at the standard tier, the only agent there, and its `model:` is copied from that row |
| `wss-execute` | The Execute rung: it applies a design handed over as an artifact, file by file, without surveying the tree or judging whether the design is right. Holds `Read, Edit, Write, Bash` — deliberately no `Grep` or `Glob`, so it structurally cannot survey — which makes it the narrowest grant in the suite that can still write. Carries an explicit stop-and-report on any premise the design leaves missing, and a falsification line, so a precise-but-wrong brief fails loudly instead of being executed faithfully. The assignment table puts it at the bottom tier alongside the surveyor, and its `model:` is copied from that row. **This one travels** |

The four rung agents are declared as no role: a caller names one directly. Every
*other* `agents.*` role in the manifest schema is something an adopting
project declares. What a skill does with a role no manifest declares is
`WSS.MANIFEST.md`'s `agents` section, and a second copy here would drift from it.
