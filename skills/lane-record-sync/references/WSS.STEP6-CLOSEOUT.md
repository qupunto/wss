# Step 6 — Close the run out through `--wss-wrap`

**Invoke `wrap` and let it run its whole ritual.** The close-out has an
owner; this skill calls it rather than describing what the user ought to do
next.

**Ask for the commit, in that turn.** This skill has no flag, so it has no
grant to pass on —
[`WSS.OWNERSHIP.md`](../../../wss/workflow/WSS.OWNERSHIP.md)'s *authorization
comes from the flag* rule, and a skill that granted itself one by writing it
here would be the exact move that rule forbids. Say what the commit would
cover and ask. A refusal just leaves the tree as it was.

**Never offer the push.** Step 0 landed sibling lanes' branches onto
`WSS.branch.integration` locally and ruled there that publishing them is not
this run's act. Ask for the commit; name what is unpushed; stop.

Everything else is `wrap`'s — the task list, the memory check,
`handoff-writer`'s currency pass, the closing counts. None of it is restated
here, and a change to any of it belongs in that file.

**Step 6 runs even when step 5 skipped every lane.** Steps 0–4 have already
written the queues, the deletions from `WSS.lanes.conflicts` and the audit
entry by then.
