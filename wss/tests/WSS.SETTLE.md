# Settling a batch of candidate findings

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What a runner
owes a batch of candidate findings before any of them reaches dispatch, a fix,
or the user: a reader's report is a hypothesis, not a fact, until this step
runs.

**Re-verify every candidate against its cited file and line**
([`WSS.OWNERSHIP.md`](../workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing)).
A finding a reader filed is checked here the same way it will be checked
downstream — by looking, not by trusting the report that raised it.

**Settle every negative claim with the grep that would disprove it**
([`WSS.RECORD-CONTRACT.md`](../workflow/WSS.RECORD-CONTRACT.md#negative-claims)).
A claim that nothing is true of the tree gets the same treatment as a positive
one: run the check that would prove it false before it survives to the next
step.

**Dedup across shards.** The same drift found by two readers is one finding
with two citations, not two findings.

## Where this step also carries the last-statement check

**Where settling is also the step that authorizes a prune cut, the
last-statement check runs here too, centrally.** A shard holds a fraction of
the tree and structurally cannot know whether a rule it wants cut is stated
in some other file — so a shard returns `candidate cut`, never `cut`, and
this step greps the whole of `WSS.record.tooling.sources` for the rule's last
statement before any cut lands. This is the check whose absence an audit is
instructed to hunt for.

**Where a runner instead hands the prune itself to a separate owner rather than
cutting inline, the last-statement check belongs to that owner's own second
look, and this step does not repeat it.** The difference is whether settling
here is also what authorizes the cut. Where it is not — where a downstream
owner re-checks before cutting — duplicating the grep buys nothing the
downstream owner does not already do.
