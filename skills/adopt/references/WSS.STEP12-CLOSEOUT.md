# Step 12 — Close out

Say, briefly:

- what the manifest now declares, and what `manifest-writer` left out and why;
- which files were created empty, and which skill fills each one first;
- what `permissions.ask` now gates, or that nothing the project declares
  needed it;
- the doctor result;
- the one next step — usually `--wss-check` to see what the record already gets
  wrong, or `--wss-plan` if the project has no roadmap yet.

**Then the cadence card**, which is [`SKILL.md`](../SKILL.md)'s "The cadence
card" and is not repeated here — `wss-doctor.sh` compares that table's flag
column against `README.md` by a hardcoded path, so a second copy in this file
would be a third site nothing checks.

Say plainly that nothing here nags on a schedule: the SessionStart hook
speaks when something has genuinely fallen behind or broken — a failing
health check, a record or sweep gone stale — and injects the handoff, so the
cadence is theirs to keep.

Then have `git-writer` commit it. `--wss-adopt` authorizes committing what it
created and nothing more, and that grant is what the primitive inherits;
publishing is the user's call or `--wss-wrap`'s.
