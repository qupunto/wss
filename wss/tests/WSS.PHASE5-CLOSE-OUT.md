# Phase 5 — Close out, and hand the work to its owners

**An audit is not finished when the findings are written. It is finished when
they are committed.** Not optional, and not conditional on the user asking.

**Invoke `--wss-wrap`** — the whole ritual this time, not the narrow hand-off of
Phase 4 step 5. It reconciles the task list, calls `handoff-writer` for the full
currency pass, and commits in coherent pieces through `git-writer`.

**It runs as a dispatched wrap, and its own file says what that means**: your
grant at your scope, no `/clear` declaration, and no milestone question — this
procedure continues afterwards with the Fix-now dispositions below.

**`--wss-health-check --deep`'s TODO resort is standing authorization to commit**,
needing no fresh ask, the same as `--wss-wrap`'s — though its grant does not
extend to a push, unlike `--wss-wrap`'s own. The grant comes from
the flag, not from this file — [`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md) is
where it is stated.

That authorization is **scoped to the audit's own record**: the `WSS.record.stocktake`
entry, the rebuilt `WSS.record.todo`, and any roadmap, decisions, open-decisions or
handoff changes the review produced. It does **not** extend to remediation. A
defect fixed an hour later in the same session is ordinary work under ordinary
rules — commit it, then ask before pushing, or wait for `--wss-wrap`.

Either way the history is written by `git-writer` and never by hand: its rules on
grouping, staging by name, session trailers and whose work a push would publish
are what make this grant safe, and they only apply if you use it. Invoked from
here it inherits the scoped grant above — record only.

Then route what the review produced. Every **Fix now** disposition has an owner,
and it is never this skill. **Where the manifest declares no role for a finding's
kind, the item goes on the session task list as ordinary work** — never to a
different role's agent:

| Finding in | Goes to |
|---|---|
| The schema or its migrations (`WSS.lanes.exclusive`) | `WSS.agents.architecture` to decide the shape, then the manifest's `WSS.onSchemaChange` skill for its mandatory post-edit sequence |
| Routes, services, domain logic | `WSS.agents.implement` |
| Containers, networking, infra scripts, CI workflows | `WSS.agents.infra` |
| A test gap, or missing regression coverage | `WSS.agents.test` |
| A security finding that needs proving before anyone fixes it | `WSS.agents.exploit` |
| A goal or roadmap block to add, reorder or reprioritise, or a milestone in `WSS.record.releases` | `--wss-plan` |
| A version or a tag, or drift between the documents and `git tag` | `--wss-release` — it decides; `changelog-writer` and `--wss-plan` write |
| A stale claim in **this project's** skill or agent file | `--wss-health-check`, which owns them — dispatch, do not fix it here |
| A defect in a file belonging to **this suite** — including one this audit is running | **File it and stop.** Not `--wss-health-check`, not a fix in place — destination and reasoning in [`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session) |
| Anything the user decided not to do now | `--wss-todo` (already done in Phase 3) |

**Prove a defect with a failing test before fixing it wherever possible.**
