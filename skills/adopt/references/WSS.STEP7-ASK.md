# Step 7 — Ask only what cannot be inferred

Batch these with `AskUserQuestion` — four at a time, recommended option first.
Everything answerable from the repo should already be answered by now.

- **`WSS.record.todo` as a file or a provider** — ask only where step 3 found open
  issues. "Your TODO list: a `WSS.TODO.md` in the repo, or the issues you already
  have?" Choosing issues needs the `repo` slug and a **label** — press for the
  label, because without one the TODO list is every open issue including user bug
  reports, which is almost never meant. Say plainly that the file form is the
  battle-tested path and the provider is newer, so the choice is informed.
  Where step 3 found no issues, do not raise it: a project with one TODO list does
  not need to be told it could have a different one.
- **`WSS.branch.integration` and `WSS.branch.publish`** — inferable from the current
  branch and the remote's default, but worth confirming; `--wss-wrap` pushes one of
  them.
- **`WSS.gate.coverage`** — only where a coverage tool is configured. Ask for the
  thresholds CI actually enforces, not aspirations.
- **The rulebook, where the tree carries `wss/rules/`** — "This suite ships a
  rulebook of judged rules, accumulated on the machine it came from. Inherit
  them as your starting rules, or start your own rulebook with the same
  structure and no rows?" **Offer inherit first**, and say why: inheriting and
  truncating later is one command, while starting fresh and wanting them back
  means going to the published tree. Step 9c carries the answer out. Where the
  tree has no `wss/rules/`, do not raise it.
- **`WSS.commitTrailer`** — offer `Claude-Session`; it is what `--wss-wrap` stamps and
  what makes concurrent sessions distinguishable.
- **`WSS.commands.testConsentEnv`** — only if the suite is gated behind a token.
- **`WSS.lanes.*`** — the paths where two concurrent edits collide. Worth asking
  only for projects that will use `--wss-start`; skip it otherwise and say so.
- **`WSS.lanes.named`** — only where the project is worked on from **several git
  worktrees at once**, or the user says it will be. One entry per lane with its
  `scope` globs, and the splittable records redirected to lane files, plus that lane's `transfer` queue for
  **all** lanes or none — the resolution rule and the all-or-none constraint
  are [`WSS.LANE-CONTRACT.md`](../../../wss/workflow/WSS.LANE-CONTRACT.md)'s. A single-worktree project
  never needs this; do not raise it unprompted.
- **`WSS.hazards.*`** — where the project's known traps are already written, as
  `file#anchor`. Do not write the traps themselves; the manifest holds pointers.
- **`WSS.localCI`** — only where the user says integration-branch CI runs, or
  should run, on a self-hosted runner; never raise it unprompted. The value is
  the project's own prepare-never-perform runbook script — confirm the path
  resolves before handing it over. The doctrine (what generalizes, what stays
  the project's) is `references/WSS.LOCAL-CI.md`, tracked-private in the
  suite's source tree and absent from a published copy; where that file is
  absent, the key's row in `WSS.MANIFEST.md` is all there is, and that is
  enough to record a runbook the project already has.

**Do not ask about `audit.*`.** Both keys exist to override defaults that are
correct for a new adopter, and a question nobody can answer well on day one is a
question that produces a wrong answer.

