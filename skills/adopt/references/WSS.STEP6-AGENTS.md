# Step 6 — Read the roles out of `.claude/agents/`

Where agent files exist, propose the `agents.*` mapping from what they actually
are — an agent named for reviewing infrastructure is `WSS.agents.infra`. Where none
exist, **leave `agents` out entirely.** Every skill already handles undeclared
roles by routing each unit of work to **its rung's own agent** — `wss-survey`,
`wss-analyze`, `wss-design` or `wss-execute`, matching the rung the caller
assigned it — and saying so. **Never a general-purpose subagent, and never a
different role's declared agent**, which is
[`WSS.MANIFEST.md`](../../../wss/workflow/WSS.MANIFEST.md)'s rule rather than this
file's: a guessed mapping sends work to an agent that was never written for it,
and a general-purpose one prices every spawn at the widest grant.

