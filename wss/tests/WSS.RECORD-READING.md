# Reading a record before acting on it

> **A shared method, not a skill.** See [`WSS.CHECKS.md`](WSS.CHECKS.md). The runner
> that borrows it is `--wss-start`, at the Phase 2 gate where it selects work from
> `WSS.record.todo` and `WSS.record.roadmap` against `WSS.record.openDecisions`.
> This file decides no scope, no disposition and no authorization — only what
> counts as a finding when reading a record before acting on what it says.

Both directions matter. A finding is an entry that reads actionable and is not —
a citation gone stale, a count with nothing behind it — or reads ineligible and
is not — a blocker sitting somewhere the selection procedure never reads. An
entry that is neither is not a finding; trusting either an entry or a record's
current state without re-checking it is the mistake this method exists to
catch.

## A citation is a hypothesis

**A TODO list entry that cites two files can be half true, and reads as
clear.** Check **every** citation an entry makes before
deleting it, not the one that is easiest to check — `git grep` for the subject,
and only delete when nothing comes back (`wss/logs/WSS.DECISIONS.md`'s
`2026-08-02 (third)` entry). `WSS.record.todo`'s own header states this
rule.

**A `[agent-reported]` marker means the finding was never re-checked.**
`WSS.record.todo`'s header explains the convention: re-verify before acting, because
a finding carrying the marker is a hypothesis, not a fact. Run
`grep -c 'agent-reported' <the file>` rather than believing a claim about
whether the marker is currently in use anywhere — a hit inside the file's own
explanatory text is not an entry.

**An entry can cite a count whose content was never written down.** A TODO
list entry once promised a specific number of proposals and turned out to hold
only the number: the pass that formed them was a subagent report, discarded
when it returned, and only a few survived by quotation elsewhere. The tell is
an entry that quantifies without citing — a share, a byte figure, or a count
with no `file:line` and no command behind it. Re-run the method against the
file rather than hunting for a lost report; a report is not storage, and only
what a batch writes into a record survives (`wss/logs/WSS.DECISIONS.md`'s
`2026-08-12 (fifth)` entry).

## Where a blocker hides when the open-decisions file reads empty

A blocking decision can sit outside `WSS.record.openDecisions` entirely, and the
record itself gives no signal that this has happened. Read a TODO list entry's
body before starting it, and treat a gate you cannot evaluate as a decision
nobody has taken rather than as a blocker — a `--wss-start` Phase 2 run once
found nothing eligible in the whole TODO list while two choices were actually
blocking it, and neither existed in any record at all
(`wss/logs/WSS.DECISIONS.md`'s `2026-08-01 (eighth)` entry). Known locations for
where a blocker hides:

- **Inside a working document that collects decisions**, kept outside the
  declared record set. A file like that is exactly where a blocker hides from
  `--wss-start`, whether or not it still exists.
- **Inside a `WSS.record.todo` entry**, where the entry names something that itself
  has no home yet.
- **Inside `WSS.record.roadmap`'s own gate wording.** A phrase like "gated on the
  backlog being genuinely clear" can be an unmade decision dressed as a
  condition.
- **Inside `WSS.record.handoff` itself**, phrased as an observation rather than a
  question — "no ruling yet" or "no decision entry carries these rulings yet"
  reads as a status report, not as pending work, which is what lets it sit
  there while `WSS.record.openDecisions` reads empty. This is the nastiest location,
  because the handoff is the file a session is most likely to have read and
  least likely to re-read as a source of pending work. **Grep the handoff for
  "no ruling", "not yet", "unrecorded" and "until someone runs" when the
  records come up dry** (`wss/logs/WSS.DECISIONS.md`'s `2026-08-08 (sixteenth)`
  entry).
- **Inside `WSS.record.decisions` itself**, which the grep above cannot reach because
  it greps the handoff and the choice was in the decision log. A parked choice
  can carry the identical formula: *"the deferrals are this session's
  judgment, standing only until the owner's next gate; nothing here was
  ordered."* That sentence is a question addressed to the owner, written in a
  file nothing else re-reads for pending work. **The distinguishing question is
  whose judgment a deferral names**: the owner's is a decision `--wss-start`
  Phase 2 must not reverse; a session's own says so in its text and is
  answerable at the next gate — and running `--wss-start` *is* that gate
  (`wss/logs/WSS.DECISIONS.md`'s `2026-08-10 (ninth)` entry).

**An empty `WSS.record.openDecisions` is not proof that nothing blocks a batch.**
`--wss-start` reads that record first and treats empty as clear, yet a blocker
can sit outside it with nothing to detect that. Read the file rather than any
sentence describing it — a claim about a record's current state rots between
sessions.

**The signature is an empty open-decisions file plus a TODO list that yields
nothing eligible.** That combination does not mean there is nothing to do; it
means the blocker is written somewhere that is not a record.

## The greps are necessary and not sufficient

The name-greps above are necessary and not sufficient: they can come back
clean while a blocker waits in `WSS.record.decisions`, which they do not reach
(see above). **Also read every deferral pointer's authority** before concluding an
entry is ineligible — each TODO list pointer carries it inline: a *session*
deferral is a question addressed to you, and running `--wss-start` is the gate
it was waiting for; only an *owner* deferral is a decision not to reverse.
The markers are `Parked (session judgment)` and `Parked (owner ruled)`; older
entries carry the previous `Deferred (session|owner)` spelling, and the logs keep
it permanently.

## A dead citation and a blocker are indistinguishable at selection time

**An entry whose cited paths no longer resolve reads as BLOCKED rather than as
stale.** A `--wss-start` Phase 2 can go through every entry and every roadmap
block and select nothing — correctly, on what it can see — while the real
state is that a completed move left entries citing files at paths that no
longer existed, including an entry for work that had already fully landed.
Every grep above can run and come back clean, because they look for hidden
decisions rather than for dead citations, and a stale entry and a blocked one
are indistinguishable at selection time (`wss/logs/WSS.DECISIONS.md`'s
`2026-08-15 (fourteenth)` entry).

**The check is cheap and it is not any of the greps above.** When a batch comes
up empty, take a handful of the paths the entries cite and confirm they exist
— `git grep -l` for the subject, or `ls` the cited file. An entry citing a
path that resolves to nothing is a hypothesis about a tree that may be gone,
not a blocker. This is the same rule as "re-verify every citation" one step
earlier; apply it BEFORE concluding there is no eligible work, not only before
deleting an entry.

## Reading the venue, not the verdict

**A red CI run may mean CI stopped checking, not that one check failed.** A
failed step halts the job, so every step below it is reported `skipped` rather
than run. Read the step list on a failure (`gh run view <id> --json jobs`)
before concluding only the named check is broken, and treat a step naming an
optional path as the likely culprit.

**A green pre-commit says nothing about CI for `wss-append-only.sh`, because
the two venues hand the same script different evidence.** The hook runs it
against `--staged`, which on this repo is always one appended entry — the
single-entry case. CI runs it against `--base origin/main`, which is every
entry the branch has added since the merge base, arriving with `-U0` as one
hunk with no unchanged line between them. Any defect in how the exemptions
attribute added lines to entries is therefore structurally invisible to the
venue that fires on every commit (`wss/logs/WSS.DECISIONS.md`'s
`2026-08-16 (tenth)` entry). When you change an exemption, run it both ways
before believing either — `wss-append-only.sh` with no arguments for the
staged form, and `--base origin/main` for the CI form.

**A `pre-commit` hook may or may not be installed in this clone, and it is the
only local guard on the append-only logs.** Where installed it rejects a
commit that deletes a line from an append-only log; it enforces a rule that
already exists, so following it is invisible, and it announces itself on
every commit, which is how you notice it exists. It is untracked and
per-clone — `.git/hooks/` travels nowhere — so another clone has none until the
hook is installed there, and CI is what actually enforces the rule regardless.
`wss-doctor.sh` reports which of the two a clone has, as a warn rather than a
failure and silent under CI, so a checkout guarded by CI alone reads as
guarded instead of reading exactly like an unguarded one. Read the doctor
rather than checking the hook file directly, though either answers it.

## What is not a finding

**A lane worktree carries its own manifest, so directory names and manifest
counts both lie about how many trees exist.** A search for adopted trees on a
machine can return several directories, each with a `.claude/WSS.WORKFLOW.json`
and each named for a different concern, that all resolve to **one** project — a
main checkout holding the unsplit records plus lane worktrees. Only the
remote and the `.claude/WSS.LANE` selector discriminate, and
[`wss-tree-survey.sh`](../scripts/wss-tree-survey.sh) prints both. Counting the
directories reports surfaces unblocked that a single tree cannot independently
exercise; run the survey rather than counting manifests, since tree identities
are deliberately written down nowhere in the repo.

**A standing hazard parked in `WSS.record.handoff`'s `## State` section is a
filing error, not a finding to reproduce.** `## State` is superseded wholesale
by every wrap, and [`WSS.HANDOFF-WRITER.md`](../workflow/writers/WSS.HANDOFF-WRITER.md)
tells a wrap not to read it first, so a standing hazard parked there is
destroyed by the next wrap that follows its own rule — the retention rule that
makes it so was set per-section in `wss/logs/WSS.DECISIONS.md`'s
`2026-08-11 (twenty-first)` entry. A hazard answerable by
"am I about to touch that file?" belongs in the hazards record; only one that
must be known before touching anything stays in the card.
