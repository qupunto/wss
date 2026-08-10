# The project manifest — `<project>/.claude/WSS.WORKFLOW.json`

**The one authority on what a manifest may contain.** The skills are global; this
file is how a project tells them its own paths, commands and roles. Without a
single authority the shape is implied by whatever each skill happens to read,
and the skills disagree — two names for one command, keys depended on but
defined nowhere, one value read as both a string and an array.

Who may write each record is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md). This file is about **keys**.

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
case, and the more dangerous one: no current reader looks for it, so without
its own check it reads as *cleanly absent* rather than as legacy, and every
skill falls back to defaults over an adopted tree. `wss-doctor.sh` fails on that
filename too and routes to `update`; `wss-export-records.sh` alone still
reads it, export-only, so the snapshot can be taken before the migration.

## Keys

Every key below is written as its full path from the root — `WSS.record.todo`
is the `todo` key inside `record` inside `WSS`. Every key is optional. A skill
that cannot resolve one says so and continues.

## The file-naming convention, and what it does NOT cover

Every file **the suite creates in order to run** carries a prefix, so a user can
tell at a glance which files in their tree are theirs and which are the suite's.
That is a transparency property: a file that looks like the user's but is
written by machinery is the shape a hostile change would take.

**The form follows the file's ROLE, not its extension.** Extension is a poor
proxy: `.json` is caps for the manifest, which people read, and would be a
hidden lowercase file if it were a cache.

| Role | Form | Examples |
|---|---|---|
| A name the harness resolves as an identifier | `wss-<name>`, lowercase — the filename *is* the invocation | `skills/check/`, `commands/log.md` |
| Executable | `wss-<name>.sh`, lowercase | `wss-doctor.sh`, `hooks/wss-alert.sh` |
| Anything a person is meant to read or notice | `WSS.<FUNCTION>` | `WSS.TODO.md`, `.claude/WSS.WORKFLOW.json`, `WSS.ALERTS-ON` |
| Machine bookkeeping with no reader | `.wss-<name>`, hidden | `.wss-alert.stamp` |

**Caps are a channel, not decoration**, which is why that last row is not an
oversight. Caps mean *a human should notice this*, borrowed from `README`,
`TODO` and `LICENSE`. A debounce timestamp has no reader, so shouting at nobody
would be noise — and the same test is what keeps a cache from becoming
`WSS.CACHE.json`.

### The segment grammar

**A dot is navigation — it narrows to a subset.** A hyphen joins words inside
one concept and never navigates.

```
WSS . <GROUP> . <FUNCTION> . <instance> . <ext>
      CAPS       CAPS         lowercase
      optional                optional
```

- **The FUNCTION segment is caps**, hyphenated only where the concept itself
  needs several words: `WSS.AUDIT-COVERAGE.md`. Hyphens do not group files.
- **A GROUP segment is caps and names a subsystem** whose files belong together:
  `WSS.LANE.CONFLICTS.md`. Reading left to right narrows — suite, then lane
  machinery, then which file.
- **An instance segment is lowercase and follows the FUNCTION it instantiates**,
  appearing only where the file is one of many: `WSS.TODO.frontend.md` beside
  the unsplit `WSS.TODO.md`. The unsplit name is a prefix of every split one, so
  the lane variants sort beside their twin and one glob — `WSS.TODO.*` — catches
  the whole family.

**Case is what tells a group from an instance**, and position alone cannot be
trusted to. Lane names are user-chosen, so a lane may be called `docs`, `state`
or `todo`. `WSS.LANE.CONFLICTS.md` and `WSS.TODO.frontend.md` are unambiguous at
a glance; their all-lowercase equivalents are not. That is why the convention is
cased.

**A file about a subsystem takes no instance segment** — its subject is the
machinery, not one member. `WSS.LANE.CONFLICTS.md` is one per project and
addressed to `lane-record-sync`; only a genuinely per-lane file, like that
lane's transfer queue, carries a lane name.

### Manifest keys are not filenames

`WSS.record.todo`, `WSS.lanes.named`, `WSS.commands.indexRegen` are keys inside
`.claude/WSS.WORKFLOW.json`. **The `WSS` root carries the namespace once; every
key below it takes no prefix and no caps.** Prefixing each key would restate the
namespace on every line and buy nothing — below the root there is nothing
foreign to separate from, and keys already navigate by dot, which is the same
idea one level down. The caps root against the lowercase keys is the same
group-versus-instance casing the filename grammar uses.

**Ownership is authorship, not usage.** Using a file, or even being its sole
writer, does not make it ours — that is governance. The prefix marks files whose
*format we invented*. A file whose name belongs to somebody else's tool keeps
that name, however much the suite writes it:

- `SKILL.md`, `hooks.json`, `plugin.json`, `marketplace.json`, `settings.json` —
  the harness resolves these by name.
- `README.md`, `CHANGELOG.md`, `LICENSE`, `.gitignore` — the ecosystem's.
- `index.md`, `_sidebar.md`, `index.html` — docsify's, even though the suite's
  own scaffold writes them.

**Where the two tests disagree, authorship of the *name* wins.** `index.md` is
produced on every docs scaffold and is still not ours, because docsify defined
it. Conversely a page the suite always emits under a name of its own —
`WSS.OVERVIEW.md` — is ours, while a topic annex a project chose to write
(`annex/lane-synching.md`) is that project's.

**The test for a new file: would this file exist if the suite were not
installed?** If yes, it is not ours to rename. If no, it takes the prefix. Where
that is genuinely unclear, ask the owner and record the ruling here rather than
guessing — the boundary is the kind of thing that has to be decided once.

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
object too and is not a provider. The only provider that exists is
[`providers/WSS.GITHUB-ISSUES.md`](providers/WSS.GITHUB-ISSUES.md), which is the
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

**`WSS.record.releases` is the release list and `WSS.record.roadmap` is not.** Milestones,
the version each intends to ship as and the completion marks live in the first;
goals and the blocks that reach them live in the second, which may split by lane.
[`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds why, and holds the rule that
makes a split roadmap safe: **no roadmap, lane or unsplit, carries a version
number or a completion mark.** `wss-doctor.sh` fails on one that does.

**`WSS.lanes.named` holds the worktree lanes**, nested so lane names cannot collide
with the three reserved keys above. Each entry's `scope` globs are the paths the
lane owns — a `--wss-start` batch running inside that worktree partitions within
them — and its `records` object may redirect a record to a lane-scoped file:

```jsonc
// inside the WSS root, beside "record" and "commands"
"lanes": {
  "named": {
    "backend": { "scope": ["backend/**"],
                 "records": { "todo": "WSS.TODO.backend.md",
                              "openDecisions": "docs/WSS.OPEN-DECISIONS.backend.md",
                              "handoff": "docs/WSS.HANDOFF.backend.md",
                              "roadmap": "WSS.ROADMAP.backend.md" },
                 "transfer": "docs/WSS.TRANSFER.backend.md" },
    "frontend": { "scope": ["frontend/**"],
                  "records": { "todo": "WSS.TODO.frontend.md",
                               "openDecisions": "docs/WSS.OPEN-DECISIONS.frontend.md",
                               "handoff": "docs/WSS.HANDOFF.frontend.md",
                               "roadmap": "WSS.ROADMAP.frontend.md" },
                  "transfer": "docs/WSS.TRANSFER.frontend.md" }
  },
  "conflicts": "WSS.LANE.CONFLICTS.md"
}
```

The example validates as it stands — both lanes split every record they split,
and both declare a queue — because the half-shapes it must not show are
`wss-doctor.sh` failures, described below.

**`transfer` is a sibling of `records`, never a key inside it**, and the nesting
is the point rather than tidiness: everything under `records` has exactly one
writer, and a transfer queue has many. It is the lane's **inbox** — where every
*other* lane files work it believes this lane owns, so that no lane ever writes
another's records. [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds what it may
contain, why append-only makes many writers safe, and the `[critical → why]`
marker. `wss-doctor.sh` fails on `transfer` appearing under `records`.

Like the splittable records it is **declared for all named lanes or none** — a
lane with no queue is a lane nothing can file to, which reads as "nobody needs
anything from them" and is almost never true. It is tracked, unlike the
`.claude/WSS.LANE` selector, because an entry has to travel to the worktree it is
addressed to.

**`WSS.lanes.conflicts` is the second queue and there is exactly one**, a sibling of
`named` rather than a key inside a lane. It takes a contradiction between two
lanes' records that some session noticed while doing something else, and
`lane-record-sync` is what consumes it. One per project because a
contradiction belongs to neither lane involved — filing it to one of them would
be picking a side before anyone has ruled.
[`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds the entry shape and the rule
that a filed entry is a claim to be re-verified rather than a conflict to act
on. Declaring it without `WSS.lanes.named` is meaningless and `wss-doctor.sh` says so.

Only `todo`, `openDecisions`, `handoff` and `roadmap` may appear under a lane's
`records` — which records may split by lane and which must never is
[`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md)'s rule, and `wss-doctor.sh` fails on any
other key there. **`releases` is not among them**, and that is what keeps a
release checkpoint singular however many lanes a project runs. A splittable record is split for **all** named lanes or none:
a half-split is how two writers land on one file, and `wss-doctor.sh` fails on that
too. Name lane files by **lane**, which is durable (`WSS.TODO.backend.md`),
never by worktree, which is litter that outlives the worktree — the instance
segment after the FUNCTION, per the segment grammar above.

**The selector is a file, not a key: `.claude/WSS.LANE`** — gitignored, one per
worktree, holding the lane name, written once at worktree setup
(`--wss-adopt --lane <name>`). Absence means "unsplit project", the same degradation
as any missing key. It is deliberately **not** derived from the git branch name:
tempting and fragile, where the explicit file is boring and correct. Like
`WSS.sweeps`, it is per-checkout state that legitimately does not exist, so it is
not a `WSS.record.*` path and its absence is never a failure — but a selector naming
a lane the manifest does not declare **is** a `wss-doctor.sh` failure.

**The resolution rule, stated once, here:** where a lane is selected and
`WSS.lanes.named.<lane>.records.X` exists, it overrides `WSS.record.X`; in every other
case `WSS.record.X` applies exactly as it does today. Cross-lane reads need no
extra key — every lane's paths sit in this shared manifest, which is tracked
and identical on every branch, and that identity is what removes the
record-file merge conflicts worktree lanes otherwise produce.

**Scope globs also bound what a session may act on.** A request that falls
under another lane's `scope` is announced and routed to that lane rather than
executed where it lands — [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md)'s rule ("Work scoped
to another lane"), stated there because it is about which session may act,
not about which key resolves.

### `audit` — scope control for `--wss-stocktake`

| Key | Type | Notes |
|---|---|---|
| `WSS.audit.dimensions` | array | Strings name a built-in dimension; `{"name": ..., "brief": "path.md#anchor"}` supplies a project's own. Prunes, adds and re-briefs |
| `WSS.audit.invalidates` | map of glob → array | Which dimensions a changed path voids. `"*"` means all. **Only ever widens** the built-in blast radius — see the skill's Phase 0 |

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
| `WSS.suite` | object | `{"version": "0.9.0", "commit": "<sha>"}` — the migration stamp: which suite version, at which suite commit, this tree was last migrated to. Written **only** by `update` and `--wss-adopt`; read by `update` as an accelerator. **Detection from the tree is the authority** — a wrong or stale stamp is overridden by what the tree actually is, and its absence means "detect unaided", which both pre-stamp customers require anyway. The commit is what anchors a tree migrated from a checkout between releases |

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

