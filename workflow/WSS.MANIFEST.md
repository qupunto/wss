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
| `WSS.record.todo` | path, **or a provider object** | `WSS.TODO.md` |
| `WSS.record.roadmap` | path | `WSS.ROADMAP.md` |
| `WSS.record.releases` | path | `WSS.RELEASES.md` |
| `WSS.record.changelog` | path | `WSS.CHANGELOG.md` |
| `WSS.record.handoff` | path | `WSS.HANDOFF.md` |
| `WSS.record.decisions` | path | `docs/WSS.DECISIONS.md` |
| `WSS.record.decisionsIndex` | path (generated) | — (see below) |
| `WSS.record.openDecisions` | path | `docs/WSS.OPEN-DECISIONS.md` |
| `WSS.record.behaviour` | path | `docs/WSS.BEHAVIOUR.md` |
| `WSS.record.reference` | **array of paths** | `WSS.README.md` |
| `WSS.record.stocktake` | path | — (see below) |
| `WSS.record.audits` | path | — (see below) |
| `WSS.record.toolbelt` | path | `WSS.TOOLBELT.md` |
| `WSS.record.tooling.catalog` | path | `.claude/WSS.TOOLING.md` |
| `WSS.record.tooling.sources` | array of globs | `.claude/skills/*/SKILL.md`, `.claude/agents/*.md` |

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

**`WSS.record.handoff` is the record with a session-start cost, whatever it
resolves to.** The harness auto-loads only the working directory's `CLAUDE.md`;
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

**`WSS.record.reference` is an array, not a sub-object.** Skills describing "the
reference doc (overview)" or "(data model)" are naming *which file in that array*
they mean, not a `WSS.record.reference.overview` key. There is no such key.

**`WSS.record.stocktake` has no conventional fallback**, because no filename for
it is conventional. `--wss-stocktake` asks once on a first pass and then creates one;
see that skill's no-manifest section. **Frozen records spell this role's former
key, `WSS.record.audits`, throughout** — that key now names the index below, and
the decision log carries the split.

**`WSS.record.audits` is now the index of a project's independent audit passes** —
one row per frozen report, `audit-writer`'s, appended when a pass lands. It has
no conventional fallback either, and most projects never declare it: a project
that runs no independent audits has nothing to index.

**`WSS.record.toolbelt` is the capability registry** — one row per adopted library
or tool, read before building any capability. `scout` is its sole writer and
[`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds the row shape. An absent file is
an empty registry, not a failure: the file is created when the first adoption is
made. It never appears under a lane's `records` — which tool does a job is a
property of the project, not of a worktree.

**`WSS.record.decisionsIndex` has no fallback, and that is not an oversight.** It is
the one generated record, so its filename is only meaningful alongside a
`WSS.commands.indexRegen` that writes it. A project with no manifest has no such
command, so a fallback here would name a file nothing can produce — and an owner
appending to the decision log would then report an index it never regenerated.
Where the index is absent, append to `WSS.record.decisions` and say the index was not
updated.

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
finds a role undeclared does that work inline or with a general-purpose subagent,
and says so — it never substitutes a different role's agent.**

`architecture`, `implement`, `infra`, `test`, `exploit`, `audit`, `roadmap`,
`release`.

### `lanes` — concurrent-write collision, and named worktree lanes

Consumed by `--wss-start` when partitioning parallel work — and, for `WSS.lanes.named`,
by every reader of the splittable records.

| Key | Rule |
|---|---|
| `WSS.lanes.exclusive` | At most one lane in a batch, and it runs first, alone |
| `WSS.lanes.serialize` | A lane *modifying* one runs alone or first; lanes merely *calling* it run in parallel |
| `WSS.lanes.generated` | No lane writes these; the orchestrator regenerates once |
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
[`checks/WSS.DOCS-AUDIT.md`](checks/WSS.DOCS-AUDIT.md), which resolves every one
of its shell blocks from these three values rather than from one project's tree.

| Key | Type | Notes |
|---|---|---|
| `WSS.docs.root` | directory path | Where the site's markdown lives, relative to the project root. Fallback: the **first existing** of `docs/`, `doc/`, `documentation/`, `website/`. If none exists the project has no site, and every site-shaped check is skipped with a one-line note |
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
| `WSS.branch.integration` | branch name | What `--wss-wrap` pushes, and what `--wss-pr` opens a PR from |
| `WSS.branch.publish` | branch name | What `--wss-release` tags, and what `--wss-pr` merges into |
| `WSS.branch.mergeMethod` | `merge` \| `squash` \| `rebase` | How `--wss-pr` merges. Fallback **`merge`** — a squash discards the individual commit messages the history is the record of, so it is a project's explicit choice rather than a default |
| `WSS.gate.coverage` | object of thresholds | e.g. `{"lines": 91, "branches": 79}` — what CI enforces |
| `WSS.commitTrailer` | trailer key | e.g. `Claude-Session` |
| `WSS.sweeps` | path (generated, **gitignored**) | The sweep checkpoint cache. Fallback `.claude/WSS.SWEEPS.json`; its shape and rules are [`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md) |
| `WSS.onSchemaChange` | **skill name** | The project's mandatory post-schema-edit sequence, and the guard rails around it. A skill rather than a command, because the order matters and because the dangerous operations need prose next to them |
| `WSS.localCI` | path | The project's local-CI runbook script — prepare-never-perform. Presence says integration-branch pushes run the suite on a self-hosted runner; `adopt` reads it, raising the key only when the user asks and confirming the path resolves |
| `WSS.hazards.*` | `file#anchor` | Map of phase name → where that phase's known traps are written. Conventional names: `testing`, `lanes`, `migrations`, `generated` |
| `WSS.suite` | object | `{"version": "<semver>", "commit": "<sha>"}` — the migration stamp: which suite version, at which suite commit, this tree was last migrated to. Written **only** by `update` and `--wss-adopt`; read by `update` as an accelerator. **Detection from the tree is the authority** — a wrong or stale stamp is overridden by what the tree actually is, and its absence means "detect unaided", which both pre-stamp customers require anyway. The commit is what anchors a tree migrated from a checkout between releases |

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

## Adding a key

1. A key earns its place only if a **global** skill reads it. A fact only one
   project uses belongs in that project's docs, with `WSS.hazards.*` pointing at it.
2. Add the row here first. This table is the authority; a skill's own file says
   what it does with the value, never what the key is.
3. Use the existing name if one fits. Two names for one concept is the failure
   this file exists to end.
4. Run `wss-doctor.sh`, which checks that paths and `#anchor`s in a manifest resolve.

## When a project has no manifest

Every skill degrades rather than failing: fall back to the conventional names
above, skip what cannot be resolved, and **say in one line which**. A silent
fallback is how a project ends up with two handoff files.

