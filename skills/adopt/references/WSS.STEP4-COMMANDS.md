# Step 4 — Read the commands out of the project's own tooling

Never invent a command. Look in whatever declares them — the package manifest's
scripts, a Makefile, a task runner's config, CI workflow steps — and propose:

- `WSS.commands.typecheck`, `WSS.commands.test` (the **full** suite with coverage where
  one exists; a bare test run is not the same key)
- `WSS.commands.indexRegen` where anything generates an index
- `WSS.commands.ci` where a pipeline is configured

If the project has no test command, say so plainly and leave the key out.
`--wss-stocktake` treats an absent suite as a standing finding; that is the correct
outcome and it depends on the key being genuinely absent rather than wrong.

