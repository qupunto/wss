# Step 4 — Record the run

**Hand [`audit-writer`](../../../wss/workflow/writers/WSS.AUDIT-WRITER.md) an
entry**: what was examined, at which commit, how many lanes, the conflicts
found and how each was mediated, and the dependencies found with how many
were approved and how many declined. That record is `WSS.record.stocktake`,
which exists for exactly this — what was examined, when, against which
commit, and what was found.

**Report the conflict inbox's movements: how many entries were promoted into
mediation, and how many deleted as not reproducing, each with its reason.**
Both halves are required.

**Report the four rulings separately — accepted, accepted as critical,
deferred, declined.**

**The declines are also a second write, and it is not this one.** They go to
`WSS.record.decisions` through `--wss-log` — one entry for the run — and the
audit entry says how many, not what they were.

**Do not write a documentation page describing this run.** The mechanism is
documented once, in the docs site's lane-synching annex, and a page carrying
one run's actions is stale the moment the next run happens with nothing to
re-derive it —
[`WSS.RECORD-CONTRACT.md`](../../../wss/workflow/WSS.RECORD-CONTRACT.md#the-mutable-claim-rule).
Where the *mechanism* itself changed, that is `docs-writer`'s page to update.
