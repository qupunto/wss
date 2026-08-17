# The checks

**Methods, not skills.** Each file here is one way of finding inconsistency in
something the project has written down — or the structure that will produce one.
A skill that needs to run one **reads the file and applies it** over a scope the
skill itself resolves.

## Why they are not in the skills that own them

Most of these are borrowed. `--wss-full-check` and `--wss-stocktake` run the same
record taxonomy `--wss-check` does; `--wss-full-check` runs `--wss-docs`' audit and `--wss-tidy`'s
claim rule. A method borrowed by **citing another skill's headings** breaks
silently on a rename — the borrower checks nothing while reporting success — so
each method is its own file, and `wss-doctor.sh`'s section-citation check polices
the citations that remain.

## Method and runner

**A method says what counts as a finding. A runner decides the scope, what to do
with a finding, and who fixes it.** The test is **deciding**, not mentioning: a
method may **cite** a runner-owned contract and defer to it — naming
[`WSS.SWEEP-CHECKPOINT.md`](../workflow/WSS.SWEEP-CHECKPOINT.md) and handing the entry
back to its tracker is citation — but a method that decides dispatch, scope,
disposition or authorization has started being a runner. Several runners borrow
each of these files, which is the whole reason they are files; runner detail
baked into one poisons it for the next borrower.

| Method | What it finds | Run by |
|---|---|---|
| [`WSS.RECORD-DRIFT.md`](WSS.RECORD-DRIFT.md) | the classes of drift in a record, and the things that look like drift and are not | `--wss-check`, `--wss-full-check`, `--wss-stocktake` |
| [`WSS.DOCS-AUDIT.md`](WSS.DOCS-AUDIT.md) | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--wss-docs`, `--wss-full-check` |
| [`WSS.TOOLING-CLAIMS.md`](WSS.TOOLING-CLAIMS.md) | mutable claims inside the tooling files, which are deleted rather than corrected | `--wss-tidy`, `--wss-full-check` |
| [`WSS.MECHANICAL-GAUNTLET.md`](WSS.MECHANICAL-GAUNTLET.md) | a non-green result from the project's own verifications — doctor, typecheck, suite, CI — and what each outcome means | `--wss-full-check`, `--wss-stocktake` |
| [`WSS.INBOX-TRIAGE.md`](WSS.INBOX-TRIAGE.md) | which filed defects against this suite reproduce, which went stale under a moving tree, and which were never true — across both halves of the inbox | `--wss-full-check` |
| [`WSS.PROSE-PRUNE.md`](WSS.PROSE-PRUNE.md) | prose in a skill, agent, tooling file or record whose removal changes nothing about what Claude does | `--wss-tidy`; `--wss-full-check` orders that job rather than reading this file |
| [`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md) | what an independent audit pass must carry — the cumulative rubric, and how focuses rotate | the audit ritual, on the owner's ask; no flag |
| [`WSS.TOKEN-ECONOMY.md`](WSS.TOKEN-ECONOMY.md) | a skill, agent or tooling file paying more context than its job needs — each lens with a proven in-tree example and the drawback to outweigh | `--wss-tidy` |
| [`WSS.ROT-RESISTANCE.md`](WSS.ROT-RESISTANCE.md) | writing that is true today and structured to go false — an uncompared copy, a file with two writers, a claim nothing can test, a drift nothing would report | `--wss-tidy` |
| [`WSS.ROUTING-HEALTH.md`](WSS.ROUTING-HEALTH.md) | a skill that will not be reached when it should be, or will be when it should not — the one check that can push a description longer | `--wss-tidy` |

**Scope never comes from here.** Incremental narrowing is the runner's, out of
[`WSS.SWEEP-CHECKPOINT.md`](../workflow/WSS.SWEEP-CHECKPOINT.md), and a full-scope run is a runner
ignoring it. A method that resolved its own scope could not serve both.

**Nor does authorization.** These files write nothing and confer nothing. Who may
write what is [`WSS.OWNERSHIP.md`](../workflow/WSS.OWNERSHIP.md); the grant is always the flag the
user typed.

### The exceptions

One, and it falls out of a row in the table rather than being conceded to a
file. A second is appended here or it does not exist — an exception argued
inline, in the method that wants it, is the runner detail this whole boundary
exists to keep out. Each entry says what the method decides and why no runner
can.

- **[`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md)'s `## Filing` decides disposition** —
  where the report is frozen, which index row it owes, and what remediation may
  not touch. It is the only row above whose *Run by* names neither a flag nor a
  skill: the ritual is triggered by hand, so there is no runner to decide it. A
  method whose row names a runner inherits none of this.
