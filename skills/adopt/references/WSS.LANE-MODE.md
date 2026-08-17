# `--lane <name>` — set up a worktree for a declared lane

Reached directly, like amendment — no detection, no search, no questions beyond
the two below. The manifest is the authority on what the lanes are
([`WSS.MANIFEST.md`](../../../wss/workflow/WSS.MANIFEST.md)'s `WSS.lanes.named`); this mode only
builds the checkout that selects one.

1. **The lane must be declared.** If `WSS.lanes.named.<name>` is absent, this is an
   amendment first: settle the lane map with the user — every lane, its scope,
   and the record split for all lanes or none — and hand it to
   `manifest-writer` before any worktree exists. A selector naming an
   undeclared lane is a `wss-doctor.sh` failure, so order matters.
2. **Create the worktree** — `git worktree add <path> <branch>`, asking for the
   path and branch rather than inventing them. One lane, one worktree, one
   branch is the shape; the manifest is tracked and identical on every branch,
   which is what makes the lane files merge cleanly.
3. **Write the selector**: the lane name into `.claude/WSS.LANE` **in the new
   worktree**, and ensure the project's `.gitignore` covers `.claude/WSS.LANE` —
   it is per-checkout state, like the sweep checkpoint, and committing it
   would select the same lane in every checkout.
4. **Seed the lane records empty** — every `WSS.lanes.named.*.records.*` path that
   does not exist yet, heading and nothing else, exactly as step 9 creates the
   unsplit ones. All lanes' files, not just this lane's: a half-split is a
   `wss-doctor.sh` failure.
5. **Honour `worktree.symlinkDirectories`** where the project's
   `.claude/settings.json` sets it — that key lives in settings, not the
   manifest, because it configures the harness rather than the workflow. Say
   which directories it linked, or that the key is absent.
6. **Prove it from inside the worktree**: run the doctor there and show the
   selector line. Then step 12's close-out, scoped to what this mode did.

Project bootstrap beyond that — env files, generated clients, dependency
installs — belongs to the project's own docs behind `WSS.hazards.*`, not here.

