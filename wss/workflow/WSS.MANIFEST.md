# The project manifest — `<project>/.claude/WSS.WORKFLOW.json`

**The one authority on what a manifest may contain.** The skills are global; this
file is how a project tells them its own paths, commands and roles. Without a
single authority the shape is implied by whatever each skill happens to read,
and the skills disagree — two names for one command, keys depended on but
defined nowhere, one value read as both a string and an array.

Who may write each record is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md). This file is about **keys**.

**Filenames are [`WSS.NAMING.md`](WSS.NAMING.md)'s** — which files carry the
`WSS.`/`wss-` prefix, how the segments are cased and hyphenated, why key names
take neither, and **who rules a case on the boundary**, which is the owner and is
stated there once. **A pass that settles filenames and key names together reads
both files**; `--wss-adopt` and `update` are exactly that, and for them the
split is a second read and no saving, because a key declared here resolves to a
path whose *name* this contract does not govern.

**To create one, use `--wss-adopt`** — it detects the project's shape, maps files
that already exist to the records that expect them, and proves the result with
`wss-doctor.sh`. Writing a manifest by hand is fine too; this table is what it must
conform to either way.

## The one rule

**Paths, commands, roles and thresholds only — never prose.**

A manifest that carries explanation becomes a second handoff file that drifts
from the first. Hazards and hard-won lessons stay in the project's own docs, and
the manifest names the *file and anchor* to read. Every value being a path,
command or name is also what lets `wss-doctor.sh` verify a manifest at all.

## The `WSS` root, and versioning

**Everything nests under a single top-level `WSS` object.** The file carries
exactly one key at its root, and every key this contract documents lives below
it — `jq` reads `.WSS.record.todo`, never `.record.todo`:

```json
{ "WSS": { "manifest": "workflow/v2" } }
```

The root is the namespace stated once instead of on every line — the same
territorial mark the filename carries, applied to the file's inside, so a
foreign tool merging keys into `.claude/WSS.WORKFLOW.json` cannot land among
ours unnoticed.

`WSS.manifest` is required. Without it a global skill cannot tell which shape it
is holding, so a renamed key reads as absent rather than as an error — the
failure that is worst precisely because it is silent. A flat `workflow/v1`
manifest — keys at top level, no root — is **rejected** by `wss-doctor.sh`, not
misread: the nesting arrived with `workflow/v2` and is what the version gate
exists to catch.

The pre-rename **filename** — `.claude/workflow.json` — is the counterpart
case, and the more dangerous one: no skill looks for it, so without
its own check it reads as *cleanly absent* rather than as legacy, and every
skill falls back to defaults over an adopted tree. `wss-doctor.sh` fails on that
filename too and routes to `update`; `wss-export-records.sh` still
reads it, export-only, so the snapshot can be taken before the migration.

## Keys

Every key below is written as its full path from the root — `WSS.record.todo`
is the `todo` key inside `record` inside `WSS`. Every key is optional. A skill
that cannot resolve one says so and continues.

### `record` — where each record file lives

| Key | Type | Fallback with no manifest |
|---|---|---|
| `WSS.record.todo` | path, **or a provider object** | `wss/records/WSS.TODO.md` |
| `WSS.record.backlog` | path | `wss/records/WSS.BACKLOG.md` |
| `WSS.record.roadmap` | path | `wss/records/WSS.ROADMAP.md` |
| `WSS.record.releases` | path | `wss/records/WSS.RELEASES.md` |
| `WSS.record.changelog` | path | `wss/logs/WSS.CHANGELOG.md` |
| `WSS.record.handoff` | path | `wss/records/WSS.HANDOFF.md` |
| `WSS.record.setup` | path | — (no fallback; see below) |
| `WSS.record.decisions` | path | `wss/logs/WSS.DECISIONS.md` |
| `WSS.record.decisionsIndex` | path (generated) | — (see below) |
| `WSS.record.openDecisions` | path | `wss/records/WSS.OPEN-DECISIONS.md` |
| `WSS.record.behaviour` | path | `wss/records/WSS.BEHAVIOUR.md` |
| `WSS.record.reference` | **array of paths** | `WSS.README.md` |
| `WSS.record.stocktake` | path | — (see below) |
| `WSS.record.audits` | path | — (see below) |
| `WSS.record.toolbelt` | path | `wss/records/WSS.TOOLBELT.md` |
| `WSS.record.tooling.catalog` | path | `.claude/WSS.TOOLING.md` |
| `WSS.record.tooling.sources` | array of globs | `.claude/skills/*/SKILL.md`, `.claude/agents/*.md` |
| `WSS.record.tooling.inventory` | path | `.claude/WSS.TOOLS.json` |

**`WSS.record.todo` is the one key that accepts something other than a path.** A
project whose backlog already lives somewhere else declares a provider instead:

```json
"record": { "todo": { "provider": "github-issues", "repo": "owner/name", "label": "backlog" } }
```

`provider` is what distinguishes the two forms, and every reader keys on its
presence rather than on the value being an object — `WSS.record.tooling` is an
object too and is not a provider. A provider resolves to its contract file
under [`providers/`](providers/WSS.GITHUB-ISSUES.md), which is the
authority on its keys and on what a skill does when the remote cannot be
reached. Declaring one nothing implements is a `wss-doctor.sh` failure, not a
silent fallback to a file.

**Nothing else takes a provider, and that is deliberate.** `WSS.record.decisions`
and `WSS.record.openDecisions` are prose read months later by someone reconstructing
why a choice was made; an issue thread is a conversation. The task may move; the
reasoning stays in a file.

**`WSS.record.handoff` is one of two records with a session-start cost,
whatever it resolves to** — the other is `WSS.record.setup`, below. The harness auto-loads only the working directory's `CLAUDE.md`;
every other resolved handoff — a declared path, or the `WSS.HANDOFF.md`
fallback when the key or the whole manifest is absent — is injected by
`wss-session-check.sh` instead: the card above the `handoff:card-ends` marker
where one exists, the whole file where none does, and nothing where the
resolved file does not exist. Either way its lines are paid for in every
session of that project, including the ones its subject is irrelevant to,
which is why [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md#the-mutable-claim-rule)
makes compression, and deleting a resolved warning the moment it is fixed, a
rule for this record and no other. Mapping the handoff **to** `CLAUDE.md` is
still a project's explicit choice; the hook is then deliberately silent, since
the harness has already loaded it — and that choice merges a
rewritten-in-place record into the file holding the project's standing agent
instructions, which have no owner in the matrix, leaving `handoff-writer` sole
writer of a file the user also edits. Nothing warns about that: the mapping is
the consent.

**`WSS.record.setup` is injected whole by `wss-session-check.sh`, and has no
fallback.** It holds the per-machine facts and toggle values a session must
have before it can look anything up; the admission test is in the record's own
header, and `wss-doctor.sh` caps its size (`SETUP_CAP`) the way it caps the
handoff card. Undeclared means nothing is injected — the correct degrade,
since a project without the record has nothing to say. `wss-reset-records.sh`
blanks it on publication: the record's structure ships, its values are one
machine's.

**`WSS.record.reference` is an array, not a sub-object.** Skills describing "the
reference doc (overview)" or "(data model)" are naming *which file in that array*
they mean, not a `WSS.record.reference.overview` key. There is no such key.

**`WSS.record.backlog` is the unqueued half of `WSS.record.todo`**, and the split
is the point: `WSS.record.todo` holds what is genuinely queued, `WSS.record.backlog`
holds the non-blocking, non-critical findings a session turns up on its way to
something else. Both are `record`'s, and moving an entry from one to the
other is a deliberate act by a person — `--wss-start` never selects from the
backlog, or the split buys nothing. It takes no provider: a provider exists so a
team already living in an issue tracker can adopt the workflow, and nobody files
"might be worth looking at" as an issue.

**`WSS.record.stocktake` has no conventional fallback**, because no filename for
it is conventional. `--wss-stocktake` asks once on a first pass and then creates one;
see that skill's no-manifest section. **Frozen records spell this role's former
key, `WSS.record.audits`, throughout** — that key now names the index below, and
the decision log carries the split.

**`WSS.record.audits` is now the index of a project's independent audit passes** —
one row per frozen report, `audit-writer`'s, appended when a pass lands. Most
projects never declare it: a project that runs no independent audits has nothing
to index.

**Undeclared, it falls back to `wss/logs/audits/README.md`** — where the index lives in a
tree that never declared the key. `wss-doctor.sh` implements that fallback and
says so at the resolution site (`grep -n 'a_idx_rel' wss-doctor.sh`), which is
the authority for what it currently resolves to. The fallback only *matters*
where `wss/logs/audits/README.md` exists, so a project that runs no audits is unaffected
either way.

**`WSS.record.toolbelt` is the capability registry** — one row per adopted library
or tool, read before building any capability. `scout` is its sole writer and
[`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds the row shape. An absent file is
an empty registry, not a failure: the file is created when the first adoption is
made. It never appears under a lane's `records` — which tool does a job is a
property of the project, not of a worktree.

**`WSS.record.decisionsIndex` has no fallback, and that is not an oversight.** It is
a generated record whose filename is only meaningful alongside a
`WSS.commands.indexRegen` that writes it. A project with no manifest has no such
command, so a fallback here would name a file nothing can produce — and an owner
appending to the decision log would then report an index it never regenerated.
Where the index is absent, append to `WSS.record.decisions` and say the index was not
updated. `WSS.record.tooling.inventory` is generated too, but its regenerator —
`wss-tools-inventory.sh` — is a fixed suite script rather than a project-declared
command, so it exists whether or not a project has a manifest; that is what lets
it carry the conventional fallback the index cannot.

### `recordMode` — which records are logs, which are registers

| Key | Type | Fallback when absent |
|---|---|---|
| `WSS.recordMode` | map of record key → `log` \| `register` \| `generated`, **or** an object `{ "mode": …, "grows": "tail" \| "head", "entry": "heading" \| "table-row", "mutable": "outcome" \| "none" }` | The classification in [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md#two-write-modes-every-record-is-a-log-or-a-register), applied by record key name |

**The object form declares a log record's SHAPE**, so `wss-append-only.sh` reads
it rather than inferring it. `grows` names the end new entries arrive at — the
other end is sealed — and `entry` names what an entry is made of, because a log
kept as a table of rows has no `## ` heading anywhere and was therefore read as
having no entries at all. **Both default to the shape the guard assumed before
the form existed**, tail and `heading`, so a manifest carrying only the string
form behaves exactly as it did; that is why the string form stays legal rather
than being migrated. Only `mode` is required. The reasoning, and the probe that
found the unguarded record, are the decision log's `2026-08-18 (twenty-fourth)`
entry.

**`mutable` is the exception to that "defaults to the old behaviour" rule, and
deliberately so.** It names the one status field a record may have rewritten in
place, and **absent means none** — where the guard previously granted the
`Outcome:` exemption to every log record regardless of what the contract said.
That was an over-permission, not a default worth preserving: the contract's
status-field table gives `WSS.record.decisions` no mutable field at all, and an
`Outcome:` block could be deleted from any of its entries. So a record that does
not declare one does not get the exemption, and an adopter's records follow their
own contract instead of inheriting this repo's table. The decision log's
`2026-08-19` entry has the fixture.

Keyed by the same names as `record` above — `todo`, `decisions`,
`tooling.catalog`, `tooling.inventory` — one entry per declared record, and no
entry for `WSS.record.tooling.sources`, which is a glob list rather than a
record:

```json
"recordMode": { "todo": "register", "decisions": "log", "decisionsIndex": "generated", "tooling.inventory": "generated" }
```

- **`log`** — appended to, never edited; a correction is a later entry.
- **`register`** — rewritten in place, holding only what is true now.
- **`generated`** — hand-written by nobody, regenerated wholesale by a command.
  `WSS.record.decisionsIndex` and its `WSS.commands.indexRegen` are one instance,
  and the mode is why that index has no fallback path — the command is
  project-declared, so an unconfigured project has none to name a file for.
  `WSS.record.tooling.inventory` is the second: regenerated by the fixed
  `wss-tools-inventory.sh`, a suite script rather than a project-declared
  command, which is why *it* has a fallback path where the index does not — the
  regenerator exists on every install, configured or not.

**One entry per declared record is a constraint, not a style note.** Leaving the
key out entirely is legal and inherits the table above, and `wss-doctor.sh` says
so with a warning. A map that is *present and partial* **fails**: the records it
names are enforced, the one it omits is silently exempt. So the map is written
whole or not written — which is why `--wss-adopt` and `--wss-update` build it
from the record keys they are already writing rather than from the classification
table.

**What each mode obliges is
[`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md#two-write-modes-every-record-is-a-log-or-a-register)'s
and is not restated here.** This key says only which mode a record is in. A
declared value that disagrees with that file's table is wrong in the manifest
rather than a local override — a mode is a property of what the record holds,
and the same record cannot be a log in one project and a register in the next.
Declaring it makes the split machine-readable per project, so a check enforcing
append-only reads the tag instead of a path list only one repo's paths satisfy.

**A sibling map rather than a field inside `WSS.record.*`, because those values
are load-bearing.** Every skill reads `WSS.record.todo` as a string,
`WSS.record.reference` as an array and `WSS.record.tooling` as an object;
widening them to objects to carry a tag breaks every reader at once.
`wss-doctor.sh` also walks every string under `WSS.record` as a path that must
exist, so a `"mode": "log"` nested there is reported as a missing file.

**Absent means the contract's table, not "untagged".** A project adopted before
this key existed classifies exactly as one adopted after it; nothing is
unenforced for want of a declaration. `wss-doctor.sh` therefore *warns* once
where the whole key is missing and *fails* where it is present and partial — a
half-written map is the state that silently exempts one record, while a missing
one is a migration.

### `commands` — what to run

| Key | Type | Notes |
|---|---|---|
| `WSS.commands.typecheck` | shell command | — |
| `WSS.commands.test` | shell command | The **full** suite with coverage, not a bare test run |
| `WSS.commands.indexRegen` | shell command | **Rewrites** `WSS.record.decisionsIndex`. For the owners that append to the decision log |
| `WSS.commands.indexCheck` | shell command | **Verifies** the index is current, without writing. For `--wss-check`, which writes nothing — usually the same script with a `--check` flag |
| `WSS.commands.testConsentEnv` | env var **name** | Where the suite is gated behind a token only the user can supply |
| `WSS.commands.ci` | object | `{ "tool": "gh", "workflow": "<name>" }`, or a shell command returning run status |

### `agents` — which subagent plays which role

Values are agent names resolvable in that project. All optional; **a skill that
finds a role undeclared routes to that shard's own rung agent instead** —
`agents/wss-survey.md`, `agents/wss-analyze.md`, `agents/wss-design.md` or
`agents/wss-execute.md`, matching the rung the dispatching skill already assigned
against [`WSS.DISPATCH-LADDER.md`](WSS.DISPATCH-LADDER.md) — **never a
general-purpose subagent, and never a different role's declared agent.** Say
which rung agent was used in place of the undeclared role.

**This is the inverted default, and its cost is the honest tradeoff for a
narrower grant on the common case.** A rung agent's tool grant is sized for its
rung, not for an unknown role — where the work turns out to need a tool the
rung withholds, it now fails rather than proceeding on the widest possible
grant. The ladder treats that as a match failure working correctly: a project
that finds this happening routinely should declare the role, not widen the
rung agent's grant.

Since grant cost is priced **per spawn, absolute**, this is also why a project
with no agent files omits `agents` entirely rather than declaring `general-purpose`
everywhere — the fallback is already the cheap path, not the expensive one it
used to be.

`architecture`, `implement`, `infra`, `test`, `exploit`, `audit`, `roadmap`,
`release`.

### `lanes` — shard collision rules, and named worktree lanes

Consumed by `--wss-start` when partitioning parallel work into shards — and, for
`WSS.lanes.named`, by every reader of the splittable records.

| Key | Rule |
|---|---|
| `WSS.lanes.exclusive` | At most one shard in a batch, and it runs first, alone |
| `WSS.lanes.serialize` | A shard *modifying* one runs alone or first; shards merely *calling* it run in parallel |
| `WSS.lanes.generated` | No shard writes these; the orchestrator regenerates once |
| `WSS.lanes.named` | Map of lane name → `{"scope": [globs], "records": {…}, "transfer": path}`, one entry per lane for a project worked on from several git worktrees at once |
| `WSS.lanes.conflicts` | path — **one per project**, the conflict inbox `lane-record-sync` consumes |

**Everything else about worktree lanes is
[`WSS.LANE-CONTRACT.md`](WSS.LANE-CONTRACT.md)** — the `WSS.lanes.named` entry
shape and its validating example, which records may split and which must
never, the transfer queue, the conflict inbox, the `.claude/WSS.LANE` selector,
the resolution rule, and the `wss-doctor.sh` failures each constraint carries.
Read it in lane mode — a selector present, or `WSS.lanes.named` declared — and
when **deciding whether to adopt lanes at all**: that reader has no selector
yet, so no gate can detect it, and it follows the pointer anyway.

### `audit` — scope control for `--wss-stocktake`

| Key | Type | Notes |
|---|---|---|
| `WSS.audit.dimensions` | array | Strings name a built-in dimension; `{"name": ..., "brief": "path.md#anchor"}` supplies a project's own. Prunes, adds and re-briefs |
| `WSS.audit.invalidates` | map of glob → array | Which dimensions a changed path voids. `"*"` means all. **Only ever widens** the built-in blast radius — see the skill's Phase 0 |

### `docs` — the shape of the documentation site

Read by `--wss-docs` and by
[`tests/WSS.DOCS-AUDIT.md`](../tests/WSS.DOCS-AUDIT.md), which resolves every one
of its shell blocks from these three values rather than from one project's tree.

| Key | Type | Notes |
|---|---|---|
| `WSS.docs.root` | directory path | Where the site's markdown lives, relative to the project root — the doctor FAILs a root that resolves to a real directory but holds no `*.md` file at any depth, the same tier as a root that isn't a directory at all. Fallback: the **first existing** of `docs/`, `doc/`, `documentation/`, `website/`. If none exists the project has no site, and every site-shaped check is skipped with a one-line note |
| `WSS.docs.languages` | array of strings | **The first element is the root language**, whose pages sit at `<root>/`; every later element is a translation subdirectory at `<root>/<lang>/`. Absent means monolingual, and the translation-parity check is skipped. Order is the contract, not decoration — a list written translation-first inverts every parity comparison |
| `WSS.docs.devCommand` | shell command | Starts the site's dev server, for the live-render step that no grep can replace. Absent means that step is skipped with a one-line note |

All three optional, and the `docs` object itself optional — the fallbacks above
are the contract, not a convenience, and a check that takes one says so in one
line rather than silently narrowing its scope. `wss-doctor.sh` checks the types
and that a declared `root` resolves to a directory; a wrong root is otherwise
silent, because a check that finds no pages reports no findings.

**Declare `root` only where the fallback gets it wrong.** A project whose site is
at `docs/` is already resolved by the first fallback, and a key that restates a
default is one more thing to keep true.

### Everything else

| Key | Type | Notes |
|---|---|---|
| `WSS.branch.integration` | branch name | The **disposable test bench**: what `--wss-wrap` pushes, and where work is proved before it is shaped into a release. **Never a PR source** — a PR comes from a release branch, so this branch may be reset or discarded without losing anything a release depends on |
| `WSS.branch.release` | branch name **pattern** | Where a release is assembled and what `--wss-pr` opens a PR from. `<version>` is substituted at branch-creation time; the settled shape is `release/v<version>` |
| `WSS.branch.publish` | branch name | What `--wss-release` tags, and what `--wss-pr` merges into |
| `WSS.branch.mergeMethod` | `merge` \| `squash` \| `rebase` | How `--wss-pr` merges. Fallback **`merge`** — a squash discards the individual commit messages the history is the record of, so it is a project's explicit choice rather than a default |
| `WSS.gate.coverage` | object of thresholds | e.g. `{"lines": 91, "branches": 79}` — what CI enforces |
| `WSS.pair.relay` | path (gitignored, **per-checkout**) | The relay directory two paired sessions hand planning content through. Fallback `.claude/WSS/RELAY/`. Local pair machinery lives under `.claude/WSS/` by the owner's ruling; the protocol is [`pair`](../../skills/pair/SKILL.md) |
| `WSS.pair.claims` | path (gitignored, **per-checkout**) | The claims file naming which session holds which pair role. Fallback `.claude/WSS/PAIR`. **Never under `WSS.record.*`** — like `WSS.sweeps` it legitimately may not exist yet, and every `WSS.record.*` path is expected to |
| `WSS.prChecks` | object: checkbox label → `WSS.commands.*` key | Which declared command ticks which box in `.github/PULL_REQUEST_TEMPLATE.md`'s Checks section. `--wss-pr` runs each before drafting and ticks only from the result, citing the command. **The value is a key, never a command string** — a command written here would be a second copy of one the manifest already declares, and the two would drift. Sub-keys are the project's own labels, so nothing enumerates them; `wss-doctor.sh` checks that every value resolves to a command this manifest declares |
| `WSS.commitTrailer` | trailer key | e.g. `Claude-Session` |
| `WSS.sweeps` | path (generated, **gitignored**) | The sweep checkpoint cache. Fallback `.claude/WSS.SWEEPS.json`; its shape and rules are [`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md) |
| `WSS.onSchemaChange` | **skill name** | The project's mandatory post-schema-edit sequence, and the guard rails around it. A skill rather than a command, because the order matters and because the dangerous operations need prose next to them |
| `WSS.localCI` | path | The project's local-CI runbook script — prepare-never-perform. Presence says integration-branch pushes run the suite on a self-hosted runner; `adopt` reads it, raising the key only when the user asks and confirming the path resolves |
| `WSS.hazards.*` | `file#anchor` | Map of phase name → where that phase's known traps are written. Conventional names: `testing`, `lanes`, `migrations`, `generated` |
| `WSS.suite` | object | `{"version": "<semver>", "commit": "<sha>"}` — the migration stamp: which suite version, at which suite commit, this tree was last migrated to. Written **only** by `update` and `--wss-adopt`; read by `update` as an accelerator. **Detection from the tree is the authority** — a wrong or stale stamp is overridden by what the tree actually is, and its absence means "detect unaided", which both pre-stamp customers require anyway. The commit is what anchors a tree migrated from a checkout between releases |

**The branch model these keys describe binds once the flow's cycles land, not
when this table changes.** Structure before enforcement: `--wss-pr` still opens
from `WSS.branch.integration` until the cycle that moves it, so a reader
checking today's behaviour against this table will find the two disagree — the
table is the target, not a description of the current run. The rulings are the
decision log's `2026-08-19 (thirty-fifth)`–`(thirty-eighth)` entries.

**The QA/staging tier is deliberately NOT a manifest key.** It is the
`staging-branch` toggle in `WSS.record.setup`, which is its single source. A
staging key in a manifest would be a second source for one fact, and
`wss-doctor.sh` fails a manifest that carries one.

**`WSS.sweeps` is deliberately not under `WSS.record.*`.** Every `WSS.record.*` path is
expected to exist, and `wss-doctor.sh` fails on one that does not. The checkpoint is
a cache that legitimately has not been created yet — on a fresh clone, in CI, or
before the project's first sweep — and its absence means "sweep in full", which
is the safe answer rather than a fault. Filing it as a record would turn that
into a failure report on every clean checkout.

**Not manifest keys.** `worktree.symlinkDirectories` lives in the project's
`.claude/settings.json`, not here — it configures the harness rather than the
workflow. Skills that read it say so explicitly.

**Nor is a project name.** A manifest that ships carries its value into
whatever repository it lands in, so a name is worse than useless: it is
confidently wrong. The ban is written down because rule 1 below cannot catch a
key that is already present — nothing reading it looks exactly like something
reading it. A project that needs its own name has `README.md`.

**Nor are permissions.** A stack's destructive commands — migration resets,
force-syncs, anything that drops state — belong in the project's own
`.claude/settings.json` under `permissions.ask`, beside the `WSS.onSchemaChange`
skill that explains them. Shipping them in a shared global config sends one
stack's tooling to every adopter, and worse, it puts the guard somewhere the
project cannot change when its tooling does.

**Nor is a record only this project would declare — but it can still be
write-checked.** Rule 1 below keeps it out of this table because
`wss-commit-provenance.sh` shipping it to every adopter would mean nothing
there, but that script's write-check does not require a manifest row:
`.claude/WSS.LOCAL-RECORDS.json`, a project-local sibling of
`.claude/WSS.WORKFLOW.json`, holds `WSS.record.*` entries for exactly this
case. Gitignore-re-included so it is committed and history-backed, but never
published — `wss-publish.sh` removes it before Gate 2, whose `.claude/`
whitelist (three named files) backstops a dropped rm on its own, needing no
dedicated denial line the way a wholesale-admitted directory would. Its
entries merge into the same key space `wss-commit-provenance.sh` reads from
the manifest, so a `WSS.OWNERSHIP.md` row spells the key exactly as it would
for any other record — only which file holds the path differs.
`wss/logs/WSS.DECISIONS.md`'s `2026-08-18 (second)` entry has the reasoning.

## Adding a key

1. A key earns its place only if a **global** skill reads it. A fact only one
   project uses belongs in that project's docs, with `WSS.hazards.*` pointing
   at it — or, if it wants commit-time write-checking anyway, in
   `.claude/WSS.LOCAL-RECORDS.json` per "Not manifest keys" above.
2. Add the row here first. This table is the authority; a skill's own file says
   what it does with the value, never what the key is.
3. Use the existing name if one fits. Two names for one concept is the failure
   this file exists to end.
4. Run `wss-doctor.sh`, which checks that paths and `#anchor`s in a manifest resolve.
   **Add the key to the set it checks against (`KNOWN_KEYS`) in the same change**,
   or every run warns that nothing reads it — a warning whose cause is two files
   away from where it prints.

## When a project has no manifest

Every skill degrades rather than failing: fall back to the conventional names
above, skip what cannot be resolved, and **say in one line which**. A silent
fallback is how a project ends up with two handoff files.

