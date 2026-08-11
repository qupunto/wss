---
name: full-check
description: "Verify a project's records, docs and tooling are in order — run its mechanical checks, re-read them all at FULL scope ignoring every checkpoint, triage the defect inbox, prune prose, refresh the catalog. SHORTHAND: `--wss-full-check`. Also trigger on \"check everything\", \"triage the bug reports\", \"I don't trust the record any more\"."
---

# The full health check

**This is the run that trusts nothing.** It re-reads every functional file from
scratch, and the checkpoints it leaves behind are what the next weeks of cheap
sweeps rest on. Run it when a checkpoint might be wrong, when a large refactor has
landed, before a release, or on any tree you have not swept in a long time.

Who owns what is [`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md); the checkpoint
format is [`WSS.SWEEP-CHECKPOINT.md`](../../workflow/WSS.SWEEP-CHECKPOINT.md).

**Project facts come from `.claude/WSS.WORKFLOW.json`** — `WSS.record.*`,
`WSS.commands.typecheck`, `WSS.commands.test`, `WSS.commands.testConsentEnv`,
`WSS.commands.indexCheck`. Without a manifest, fall back to conventional names, skip
what you cannot resolve, and say so in one line rather than guessing. Where a
`.claude/WSS.LANE` selector names a lane, `WSS.lanes.named.<lane>.records.X` overrides
`WSS.record.X` for `todo`, `openDecisions`, `handoff` and `roadmap` —
[`WSS.LANE-CONTRACT.md`](../../workflow/WSS.LANE-CONTRACT.md)'s resolution rule. Other lanes'
files are still records with the same owners; sweep them too where the check
covers the whole record.

## What it covers, and what it deliberately does not

**Files with functional value** — ones a reader acts on, and that are therefore
wrong rather than merely old when they stop matching reality:

| Covered | Checked for |
|---|---|
| `WSS.record.todo`, `WSS.record.roadmap` | items already done, claims about state, ordering that no longer reflects dependencies, **a version number or completion mark that does not belong in a roadmap at all** |
| `WSS.record.releases` | a milestone citing a goal that no roadmap holds, an intended version overtaken by a tag, a mark whose milestone is not actually complete |
| `WSS.record.behaviour`, `WSS.record.reference` | claims contradicted by source; updates the code owed and never got |
| `WSS.record.handoff` | resolved warnings still present, pointers that no longer resolve |
| the docs site | every check in `--wss-docs` audit mode, including the page-by-page accuracy pass |
| `WSS.record.toolbelt` | a row whose package is no longer a dependency, an adopted capability since hand-built or replaced, a pointer into `WSS.record.decisions` that no longer resolves |
| `WSS.record.tooling.catalog` and its sources | skills and agents that no longer exist, mutable claims that should be deleted, prose that changes nothing |
| `WSS.record.audits` | its opening prose only — a header claim contradicted by reality, a pointer that no longer resolves; the per-report rows are frozen history, per [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)'s header split. Findings dispatch to `audit-writer` |

**Where `WSS.record.todo` names a provider it is still covered, and read in full.**
The questions are the same — items already done, claims about state — but the
backlog is a set of open issues rather than a file, per
[`providers/WSS.GITHUB-ISSUES.md`](../../workflow/providers/WSS.GITHUB-ISSUES.md#what-the-sweeps-do-with-it).
There is no narrowing to apply and none is wanted here anyway: this flag ignores
checkpoints by definition. Where `gh` cannot reach it, say the backlog was not
checked and why; never read a local file in its place.

**Append-only logs are out of scope, and this is not an omission.**
`WSS.record.decisions`, `WSS.record.stocktake` and `WSS.record.changelog` are records of what was
true when written. There is nothing
to re-verify, and "fixing" one destroys the only history there is.

The one thing worth checking about a log is that it is *generated* correctly where
it has an index: run `WSS.commands.indexCheck` and dispatch a stale index to `--wss-todo`.

**Code and project position are out of scope.** The public interface, the safety
nets and the backlog rebuild are `--wss-full-stocktake`'s, and correctness, security
and the data model belong to a project's own code-analysis skill, which that flag
invokes. Running both against one request pays twice for the same answers. If the
question is "where is this project", that is the flag to use.

## Procedure

### 1. Pin the tree and say what full scope means

`git rev-parse --short HEAD` and `git status --porcelain`. Dirty paths are audited
as they stand and recorded as `not-covered` — a file verified in a state no sha
addresses cannot license a later skip.

Then state, in three or four lines: which files are in scope, that every checkpoint
is being ignored, and roughly how much there is. This is the expensive run; the
user should be able to stop it before it starts.

Then build the task list via `--wss-track`: one task per step below — the
gauntlet, the three readers, the inbox, verification, dispatch, prune and
catalog, the re-run, the stamps — so the user can see where the expensive run
got to without reading the transcript.

### 2. The mechanical half, first

**The method is
[`workflow/checks/WSS.MECHANICAL-GAUNTLET.md`](../../workflow/checks/WSS.MECHANICAL-GAUNTLET.md)**
— the doctor-first sequence, the full-suite rule, the consent budget, the
`test-run` carry-forward and CI's four outcomes. It goes first because the tree
is still clean at this moment — the one point in this skill where a
carry-forward can fire, and the last point before anything here causes an edit.

Fix anything it reports before going further. A later phase editing files while
the hook or the doctor is broken compounds a failure nobody can see.

### 3. Fan out — one reader per area, concurrently

One subagent per area, all in a single message so they run concurrently:
**records**, **the docs site**, **the tooling files**. Give each its file list
and its brief:

- **Records** — [`workflow/checks/WSS.RECORD-DRIFT.md`](../../workflow/checks/WSS.RECORD-DRIFT.md),
  at full scope, with every incremental narrowing ignored.
- **Docs site** — [`workflow/checks/WSS.DOCS-AUDIT.md`](../../workflow/checks/WSS.DOCS-AUDIT.md),
  every section, over every page — the incremental narrowing lives in `--wss-docs`
  and is simply not applied here.
- **Tooling** — [`workflow/checks/WSS.TOOLING-CLAIMS.md`](../../workflow/checks/WSS.TOOLING-CLAIMS.md),
  over every file in `WSS.record.tooling.sources`.

Hand each reader the file, not a skill.

**Delegate reading, keep deciding.** A subagent's context is discarded when it
returns, so only its verdict costs you anything. Readers **report**; they do not
fix, and they do not write.

### 4. Triage the defect inbox

`WSS.BUG-REPORTS.md` in the config directory — defects in this suite's own skills,
contracts and scripts, found by sessions working in other projects, which were
forbidden to fix them and filed instead, per
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).
The session that filed one is long cleared, so triage here is what closes it.

**In scope only when this project *is* that configuration directory.** From
anywhere else, filing is the whole action a session may take —
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md) is the authority, and triaging
another repository's inbox from this one's session is the same mistake one
indirection along. Say in one line that it was skipped and why.

For every `[open]` entry below the append marker:

1. **Check whether it is stale.** Compare the config commit on its `Found:`
   line against the cited file now. If the file moved since, the defect may already be fixed — and
   re-reporting a closed finding is how a live instance of the same class one
   file away gets masked.
2. **Re-verify it.** Read the cited lines
   ([`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing)).
   Where the claim is negative — "nothing does X" —
   [`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#negative-claims)
   applies.
3. **Route it** with the rest of this run's findings, in step 6 — it is a finding
   like any other, and its owner is looked up the same way.
4. **Close it.** `[open]` becomes `[closed]` when the fix lands, and the commit
   says what it was. Delete the entry outright if it did not reproduce, naming in
   the commit what was claimed and why it is false — a wrong report is
   calibration, and dropping it silently teaches nobody anything.

**The inbox has an upstream half: open issues on `qupunto/wss`.**
Adopters cannot reach this machine's inbox, so their filings arrive as issues —
`--wss-report`'s own upstream path ends there too. In the same triage, run
`gh issue list -R qupunto/wss --state open` and take each open
issue through the four steps above; the body is the entry. Closing differs in
two ways: it happens on GitHub
(`gh issue close <n> --comment "<what landed, or why it does not reproduce>"`),
and only once the fix is *published* — an issue closed against a private
commit reads as fixed to an adopter whose install does not carry it. Where
`gh` cannot reach the repository, report the upstream half as **not checked**,
never as empty.

**An empty inbox is a result worth reporting.** "Nothing was filed" and "I did
not look" are different sentences, and only one of them is ever implied by
silence. The same holds for each half separately — a clean local inbox says
nothing about the upstream one.

### 5. Verify before anything reaches the user

Re-check each finding against the cited file and line
([`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing)), and
settle every negative claim with the grep that would disprove it
([`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md#negative-claims)).

Deduplicate: the same drift found by two readers is one finding with two citations.

### 6. Dispatch — this skill writes nothing

Group by owner and hand each finding to the skill that owns that file, per
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md). The owner re-verifies and writes
under its own rules. `--wss-full-check` grants nothing, so **an owner it invokes writes
its file and does not commit** — the grant a skill inherits is the caller's.

**A file with no owner in the matrix is ordinary work in this project**, not a
claim of ownership: edit it directly and say what changed. Scripts, CI, the
harness settings and the `workflow/*.md` contracts are the usual instances.

**A finding about the shape of the workflow rather than a defect in it is not a
finding.** Say so and leave it for a deliberate change.

### 7. Prune, then refresh the catalog

**Run `tools`'s prune job after the dispatch, not before:**

- **After the fixes**, because a fix written in step 6 adds its own justification
  in the house style — exactly the prose the prune exists to catch. Run it first
  and it judges the files as they were before this run touched them.
- **After the doctor**, because a prune that deletes a cited heading needs the
  citation check to have been green beforehand, or you cannot tell which run
  broke it.

It reports and dispatches; it does not cut. `--wss-tools` makes the cut after its own
second look.

Then hand `WSS.record.tooling.catalog` to `--wss-tools`, which owns it: add, edit or
remove a row for anything this run created, renamed, retired or changed the
purpose of. Refreshing it *here* is what keeps it honest — the catalog's
inventory is permitted only because something re-derives it on a schedule.

### 8. Re-verify mechanically

Every step above may have edited the files that make this project work, so run
the gauntlet again — same method. All must pass. A health check that leaves the
hook or the doctor broken has done more damage than the drift it went looking
for.

Two of the method's rules bind hardest at this end of the run: **the suite
re-runs unconditionally, including when step 2 carried it forward** — that
carry-forward was licensed by the tree as it stood *before* the edits and
certifies nothing about the tree they left (where consent was refused or spent,
say plainly that the tree is unverified by it) — and **the test run is never
stamped from here**, because this skill does not commit and a dirty baseline
can never satisfy a later carry-forward.

### 9. Stamp the checkpoints — this is the payoff

Hand `sweep-tracker` one entry per sweep — `record`, `docs`, `tooling`, and
`health` for this run as a whole — with this tree's sha, `method: full`, and per
scope what was genuinely covered.

**The `record` entry's scopes are one per record key, named for it** —
`WSS.record.behaviour`, `WSS.record.reference`, and so on. The vocabulary is
[`--wss-check`](../check/SKILL.md#scope-comes-from-the-checkpoint)'s, because
that skill is the one this stamp is for, and it resolves a scope by record key.
A scope named for a dimension instead — `accuracy` across every record at once —
joins to nothing on the next cheap run: an unrecognised name widens to full
scope, so nothing is wrongly skipped and the whole cost of this run's stamp is
simply wasted. Each scope's `covered` is the record file **plus the code globs
its reader actually read**, and `covered: []` where there were none.

**The `health` entry is what makes this skill visible when it is overdue.** The
session hook nudges on any checkpoint whose baseline has fallen far behind `HEAD`,
so without an entry of its own the one run that verifies everything is the only
one nothing ever asks for. Its scopes are this procedure's own areas —
`mechanical`, `records`, `docs`, `tooling`, `inbox` — and an area that was skipped
or refused is `not-covered`, which is what makes the next nudge honest.

**Only what was read.** An area whose reader died, ran out of context, or returned
a report vague about which files it opened is `not-covered`, and the honest cost of
that is that those files get swept again next time — a stamp not earned is a lie
every later sweep inherits. The rules are
[`WSS.SWEEP-CHECKPOINT.md`](../../workflow/WSS.SWEEP-CHECKPOINT.md).

### 10. Report

What was checked, what was found, what was dispatched to whom, what the inbox
held, what the prune proposed, what changed in the catalog, and **what came back
clean** — clean is a result, and a reader cannot otherwise tell it from "never
looked at".

**Name what you did not cover.** A prune that read four files out of fifteen has
covered four; saying so is the difference between a health check and a claim of
one. Name anything left `not-covered` and why.

## What this skill does not do

- **It changes no code, and writes no record file.** Every write goes through the
  owner, in the owner's own commit.
- **It does not audit source.** Running the project's own checks is not the same
  as reading its code; that is `--wss-full-stocktake`.
- **It does not touch the append-only logs**, beyond checking that a generated
  index is current.
- **It does not commit or push.** Whatever grant the invoking flag carried
  applies; invoked bare, it carries none.
