---
name: update
description: "Update the suite install, then detect what conventions the adopted tree actually carries and migrate it to the newest — the stamp accelerates, detection decides. SHORTHAND: `--wss-update`. Also trigger on \"update the workflow\", \"migrate this project to the new conventions\", or a doctor failure naming a pre-rename manifest."
---

# Updating the suite, and migrating the tree it serves

Two jobs, in order: bring the **install** up to date, then bring the **adopted
project** up to the conventions the updated suite expects. They are separable —
a tree can need migrating under an install that is already current — and Job 2
is the one with teeth.

**Project facts come from `.claude/WSS.WORKFLOW.json`** — or, on exactly the
trees this skill exists for, from a manifest that predates that name. The
authorities this skill answers to:

- [`wss/workflow/WSS.MANIFEST.md`](../../wss/workflow/WSS.MANIFEST.md) — the `WSS.suite`
  stamp key and the current key set.
- [`wss/workflow/WSS.NAMING.md`](../../wss/workflow/WSS.NAMING.md) — the file-naming
  convention with its "would this file exist if the suite were not installed?"
  test. **Both, not either.** A migration renames files *and* rewrites keys in
  one pass, and these are two contracts: reading only the key table leaves every
  rename unjudged.
- [`wss/workflow/WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md) — what
  each record holds, the `- migrate:` line shape in the release list, and the
  never-rewrite rule for append-only records.
- [`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md) — every write
  below that has an owner goes through it: the manifest (stamp included)
  through `manifest-writer`, commits through `git-writer`, records through
  their writers.

## Job 1 — update the install

Say which form this machine runs before touching it; the two update
differently and only one of them is a git tree you may pull.

- **Checkout** — the config directory is a clone of the suite.
  `git -C "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" pull --ff-only`, and a refusal
  is reported as divergence, never merged from here: the checkout may be the
  suite's own development tree, and reconciling it is that project's work.
- **Plugin** — `claude plugin update wss`.

State what moved — version and commit before and after. If the install was
already current, say so and move on; Job 2 does not depend on Job 1 having
found anything.

## Job 2 — detect, then migrate

**Detection is the authority; the stamp only accelerates.** The tree's own
files say which conventions it carries, and every claim the stamp or the
migration lines make is re-verified against the tree before anything is
mended. A wrong or missing stamp changes the starting point, never the outcome;
a tree that predates stamping entirely is migrated from detection alone.

### Read the tree

What to look for:

- **The pre-rename manifest filename** — `.claude/workflow.json`. It reads as
  *cleanly absent* to every current reader; `wss-doctor.sh` fails on it now, and
  this skill is the mend it routes to.
- **The v1 schema** — flat keys, no `WSS` root — under either filename.
- **The pre-reorg local-override directory shape** — `.claude/workflow/`
  (writers, checks, or providers) where `.claude/wss/workflow/` does not yet
  exist. `wss-doctor.sh` reads both shapes and only warns, so a project can
  run un-migrated indefinitely; mend by `git mv .claude/workflow .claude/wss/workflow`
  (creating `.claude/wss/` first if absent) and re-running the doctor to
  confirm the warning clears. Most projects have never populated this
  directory at all and this bullet is a no-op for them.
- **Content-level moves, not just renames**: `record.audits`'s role is
  `record.stocktake` now; `record.releases` may not exist and its milestones
  may be embedded in the roadmap (extracting them is content surgery, done
  with the user, written through `--wss-plan`); lane `transfer` queues and
  `WSS.lanes.conflicts` are mandatory-if-lanes declarations whose files must
  exist before the manifest may declare them.
- **A manifest that declares records and no `WSS.recordMode`** — what every tree
  adopted before that key carries. It is the one shape here the doctor *warns*
  about rather than failing, so it does not announce itself: detect it as
  `.WSS.record` present with no `.WSS.recordMode` sibling, and mend it below.
- **State outside the tracked tree**: `.gitignore` entries naming old paths
  (the sweeps cache, the old `.claude/lane` selector), and **per-worktree
  untracked selector files** — enumerate `git worktree list` and mend each,
  because no pull ever fixes those.
- **A per-clone git hook whose target no longer resolves.** `.git/hooks/` is
  untracked by design, so a hook installed by an earlier version names an
  absolute path on its own machine and travels nowhere — no contract test, no
  CI step and no doctor check covers it, and every existing clone owes the
  re-run. Relocating a suite script is what breaks it: the `/wss` reorg moved
  `wss-append-only.sh` and the very next commit failed outright with
  `exec: …/wss-append-only.sh: not found`. Detect it by reading each installed
  hook's target and testing that the path exists — `tail -1 .git/hooks/pre-commit`
  rather than assuming it is right — and mend by re-running the installer
  (`bash wss/scripts/wss-append-only.sh --install-hook`), which is what that
  hook's own header already tells the reader to do. It fails closed, which is
  loud, but only at the moment someone tries to commit.
- **Generators and their output**: scripts with embedded record paths —
  `WSS.commands.indexRegen`'s among them — and committed *generated*
  artifacts downstream of renamed strings — regenerate through the project's
  own generators, never hand-edit the output.
- **Citations across live surfaces** — record-to-record links, docs pages,
  the session hook's targets.

### The stamp, and the migration lines

`WSS.suite` in the project's manifest records what the tree was last migrated
to: `{"version": …, "commit": …}`. When it is well-formed, read the suite's
own release list (`WSS.RELEASES.md` in the install) for `- migrate:` lines in
every milestone **after** the stamped version, and apply them **in release
order**. Each line names its detect-condition and its mend
([`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md) holds the
shape); a condition that no longer holds means that mend is already done and
is skipped — which is what makes a re-run resume instead of repeat.

No stamp, or a malformed one, means: detect everything from the tree and
treat the full line history as candidates. The doctor already warns on a
malformed stamp; do not repair a stamp by hand — it is rewritten honestly at
the end.

### The gate, and the snapshot

**Migration has its own consent gate, distinct from adoption's amendment
rule.** A key or filename matching a *previous suite convention* is stale
machinery, not a project's choice — correcting it is the point — but nothing
is corrected before the user has seen the plan: every detected mend, in
order, and what each touches. An explicit OK in that turn, once, for the
plan as shown; a mend discovered mid-migration that the plan did not name is
reported and waits, not slipped in.

**Snapshot before the first write, never after it.**
`wss/scripts/wss-export-records.sh --all` reads legacy manifests for exactly this moment;
tell the user where the archive landed before proceeding.

### The boundary judgments

- **Which files take the `WSS.` prefix** is decided per file by
  [`WSS.NAMING.md`](../../wss/workflow/WSS.NAMING.md)'s test — *would this file
  exist if the suite were not installed?* A README, a `CLAUDE.md` serving as
  handoff, a changelog, a docs site's own files keep their names; suite-shaped
  records take the convention. Ask when a file class is genuinely ambiguous,
  and decide per class, not per file — the ruling is the owner's, and that file
  is where it gets written down.
- **Every rename is checked back against the key table.** A file this skill
  renames that a `WSS.record.*` path names must move in the manifest in the same
  mend, through `manifest-writer`. The grammar and the key set are separate
  files, and a mend that reads only one of them is how a tree ends up correctly
  named and unresolvable.
- **Append-only records are never rewritten.** Old names inside historical
  text stay exactly as written — logs keep their original spelling. Every
  verification grep this skill runs for an old name therefore **excludes the
  append-only records** (`decisions`, `audits`/`stocktake` history, the
  changelog), or the migration reads as failed forever.

### The record-mode map, on a tree that has none

A tree without the map is not broken — the mode is inherited from
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md#two-write-modes-every-record-is-a-log-or-a-register)'s
table by record key name, so it classifies exactly as a tree adopted after the
key. The mend makes that classification local and checkable, and it goes into the
plan and waits for the same OK as any other.

The mend, through `manifest-writer`: enumerate the records **the manifest
actually declares**, expanding `WSS.record.tooling`'s sub-keys and dropping
`tooling.sources`, which is a glob list rather than a record; look each key up in
the contract's table; write the map as a sibling of `WSS.record`, never a field
inside it.

**Enumerate from the manifest, never from the table.** The table is the authority
on what a mode *is*; the manifest is the authority on which records this project
has. A map built by walking the table tags records the tree never declared, which
`wss-doctor.sh` fails in its reverse direction — and a project declaring a record
the table does not classify stops the mend rather than skipping the row, because
absent warns and partial fails. In both cases the mend is reported undone and no
map is written; three rows out of four is the one outcome it may not produce.

### Landing it

- **In release order, one mend per commit**, through `git-writer` — this
  flag's grant is commit, not push. A mend that renames and a mend that
  regenerates do not share a commit; the history is the record of what the
  migration did.
- **A partial migration never exits clean.** Report exactly which mends
  landed and which did not, and leave the stamp unwritten — a stamp over a
  half-migrated tree is worse than none.
- **Finish with the doctor.** Run `wss-doctor.sh` and show its output; the
  migration is not complete over a failing doctor.
- **Then measure it.** Run `bash wss/scripts/wss-tools-inventory.sh`, resolved the same
  way as the doctor above, so `.claude/WSS.TOOLS.json` —
  `WSS.record.tooling.inventory` — reflects the tree Job 2 just produced
  rather than the one that predates it. After the doctor, for the same reason
  as the stamp: a derived artifact is only worth writing once the migration it
  derives from has been proven sound.
- **Then write the stamp, through `manifest-writer`**: the installed suite's
  version (`.claude-plugin/plugin.json`) and its commit —
  `git -C <install root> rev-parse --short HEAD` where the install is a git
  tree. Where no commit is resolvable (a plugin cache without git metadata),
  **leave the stamp unwritten and say so** rather than guessing one: the
  stamp is an accelerator, and an absent stamp is legal where a fabricated
  commit is not.

## In the suite's own checkout

Job 1 applies (it is a checkout; pull it). Job 2 does not: the suite's own
tree tracks current conventions by development, and "migrating" it is
ordinary work its own records already govern. The doctor answers for it.

## What this skill does not do

- **It does not push, tag or release.** Publishing the migration commits is
  the user's `--wss-wrap`; versions are `--wss-release`'s.
- **It does not write migration lines.** Those are authored into the release
  list by `--wss-plan` and `--wss-release` when a release ships a structural
  change; this skill only reads them.
- **It does not adopt.** A tree with no manifest under either name has
  nothing to migrate — that is `--wss-adopt`'s ground, and adopt dispatches
  *here* when what it finds is stale rather than absent.
