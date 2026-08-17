# Which method each job reads

**Read the row for the job you are running, and only that row's file.** The five
jobs fire independently — each states its own trigger, and none runs as a side
effect of another — so a run that loads all five methods has read four it will
not use.

| Job | Reads | Fires when |
|---|---|---|
| 2 — stale claims | [`WSS.TOOLING-CLAIMS.md`](../../../wss/tests/WSS.TOOLING-CLAIMS.md) | a false claim is found in a tooling file, or `--wss-check` dispatches one here |
| 3 — prose prune | [`WSS.PROSE-PRUNE.md`](../../../wss/tests/WSS.PROSE-PRUNE.md) | the trigger phrases, or `--wss-full-check` orders it |
| 4 — token economy | [`WSS.TOKEN-ECONOMY.md`](../../../wss/tests/WSS.TOKEN-ECONOMY.md) | the owner's ask, or an audit pass recommends it |
| 5 — rot resistance | [`WSS.ROT-RESISTANCE.md`](../../../wss/tests/WSS.ROT-RESISTANCE.md) | the owner's ask, an audit pass, or a Job 2 finding that is the second instance of one shape |
| 6 — routing | [`WSS.ROUTING-HEALTH.md`](../../../wss/tests/WSS.ROUTING-HEALTH.md) | the owner's ask, an audit pass, **or any Job 3/4/5 run that shortened a `description`** |

**Job 6's third trigger is the one another job creates**, which is why it is the
only row whose condition names a sibling. Everything else here is fired by a
person or by `--wss-full-check`.

**`--wss-full-check` is the exception to the one-row rule**: it runs every method
over every file in `WSS.record.tooling.sources`, so it reads the whole column
rather than a row. It cites this table for that, rather than the five files
individually.

## Why the methods live outside this skill

They are `wss/tests/`'s because they are shared: `--wss-full-check` runs
the same ones, and `--wss-check` dispatches findings against them. A copy here
would be a second statement of a method two runners already read from one place.
This file is the gate, never the content.
