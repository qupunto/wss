# The checks

**Methods, not skills.** Each file here is one way of finding inconsistency in
something the project has written down — or the structure that will produce one.
A skill that needs to run one **reads the file and applies it** over a scope the
skill itself resolves.

## Why they are not in the skills that own them

Most of these are borrowed. `--wss-full-check` and `--wss-stocktake` run the same
record taxonomy `--wss-check` does; `--wss-full-check` runs `--wss-docs`' audit and `--wss-tools`'
claim rule. A method borrowed by **citing another skill's headings** breaks
silently on a rename — the borrower checks nothing while reporting success — so
each method is its own file, and `wss-doctor.sh`'s section-citation check polices
the citations that remain.

A method in its own file also keeps every runner thin: the taxonomy lives here
once, instead of swelling whichever skill happened to write it first.

## Method and runner

**A method says what counts as a finding. A runner decides the scope, what to do
with a finding, and who fixes it.** Keep new material on the right side of that
line — a method that mentions dispatch, or a checkpoint, or a flag's
authorization, has started being a runner and will not survive being borrowed by
the next one.

| Method | What it finds | Run by |
|---|---|---|
| [`WSS.RECORD-DRIFT.md`](WSS.RECORD-DRIFT.md) | the classes of drift in a record, and the things that look like drift and are not | `--wss-check`, `--wss-full-check`, `--wss-stocktake` |
| [`WSS.DOCS-AUDIT.md`](WSS.DOCS-AUDIT.md) | a docs site's internal correctness — paths, links, anchors, enumerations, page-level accuracy against source | `--wss-docs`, `--wss-full-check` |
| [`WSS.TOOLING-CLAIMS.md`](WSS.TOOLING-CLAIMS.md) | mutable claims inside the tooling files, which are deleted rather than corrected | `--wss-tools`, `--wss-full-check` |
| [`WSS.MECHANICAL-GAUNTLET.md`](WSS.MECHANICAL-GAUNTLET.md) | a non-green result from the project's own verifications — doctor, typecheck, suite, CI — and what each outcome means | `--wss-full-check`, `--wss-stocktake` |
| [`WSS.PROSE-PRUNE.md`](WSS.PROSE-PRUNE.md) | prose in a skill, agent or tooling file whose removal changes nothing about what Claude does | `--wss-tools`; `--wss-full-check` orders that job rather than reading this file |
| [`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md) | what an independent audit pass must carry — the cumulative rubric, and how focuses rotate | the audit ritual, on the owner's ask; no flag |
| [`WSS.TOKEN-ECONOMY.md`](WSS.TOKEN-ECONOMY.md) | a skill, agent or tooling file paying more context than its job needs — each lens with a proven in-tree example and the drawback to outweigh | `--wss-tools` |
| [`WSS.ROT-RESISTANCE.md`](WSS.ROT-RESISTANCE.md) | writing that is true today and structured to go false — an uncompared copy, a file with two writers, a claim nothing can test, a drift nothing would report | `--wss-tools` |
| [`WSS.ROUTING-HEALTH.md`](WSS.ROUTING-HEALTH.md) | a skill that will not be reached when it should be, or will be when it should not — the one check that can push a description longer | `--wss-tools` |

**Scope never comes from here.** Incremental narrowing is the runner's, out of
[`WSS.SWEEP-CHECKPOINT.md`](../WSS.SWEEP-CHECKPOINT.md), and a full-scope run is a runner
ignoring it. A method that resolved its own scope could not serve both.

**Nor does authorization.** These files write nothing and confer nothing. Who may
write what is [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md); the grant is always the flag the
user typed.
