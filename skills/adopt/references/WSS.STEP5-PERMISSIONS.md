# Step 5 — Propose `permissions.ask` for the commands that destroy state

Gating is deliberately not a manifest key — a stack's destructive commands
belong in the project's own `.claude/settings.json`, per
[`WSS.MANIFEST.md`](../../../wss/workflow/WSS.MANIFEST.md). `--wss-health-check --deep`'s TODO resort checks for that gate
under `safety-nets`, so a project adopted without it starts life owing a
finding this step can settle while the tooling is already open.

Same sources as step 4, different question: which of the commands this project
*actually declares* destroy something expensive to rebuild — migration resets
and force-syncs, history rewrites, deploys against a shared environment, bulk
deletes against real data. Propose each with the line that declares it, in the
form settings uses:

```json
{ "permissions": { "ask": ["Bash(pnpm db:reset*)", "Bash(git push --force*)"] } }
```

**Only commands the project has.** A pattern matching nothing is noise; one
matching too much teaches the user to approve without reading, which is worse
than no gate.

Merge the approved entries into the **project's** `.claude/settings.json` —
never the user's global one — preserving every key already there, and say what
you added. Where the project already gates them, say so and change nothing.
Where nothing it declares destroys state, say *that*, so the answer is on the
record as considered rather than as an empty list.

