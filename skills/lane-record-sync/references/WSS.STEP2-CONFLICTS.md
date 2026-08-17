# Step 2 — Resolve conflicts, before anything is integrated

**Two sources, one set.** The conflicts promoted out of `WSS.lanes.conflicts`
and the ones derived in step 1 are mediated together and to the same
standard — but say which is which when presenting them.

Per conflict: name both sides, both lanes, and what each record actually
says. Then **ask the user to mediate**. This is not step 3's four-way ruling —
it is a question about which of two statements is right, and it has no
default. Neither *defer* nor *decline* is on offer: two records that
contradict each other keep contradicting each other, and a conflict left
unmediated is the one thing this skill must not carry forward silently.

Once resolved, **file the outcome into every affected lane's transfer queue,
marked `[critical → why]`** — legitimate here because the user just ruled,
which is the one condition
[`WSS.LANE-CONTRACT.md`](../../../wss/workflow/WSS.LANE-CONTRACT.md)'s
`[critical → why]` section puts on the marker.

**Never write another lane's records directly**, even where the correction is
one line and obviously right, and even from the main checkout where the files
are reachable. The queue is the only route in; a record has one writer and it
is that lane's own session. Writing it here would make this skill a second
writer of every record in the project at once.
