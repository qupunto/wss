# Phase 0 — Scope

1. **Pin the tree.** `git rev-parse --short HEAD` and `git status --porcelain`.
   Findings are only ever true against a specific tree. If the working tree is
   dirty, say so in one line and audit `HEAD` plus the dirty files, recording the
   entry as `<sha>+dirty` — don't ask the user to commit and don't stall.
2. **Choose the dimensions from the project's shape.** Detect the shape per
   [`WSS.PROJECT-SHAPE.md`](../../wss/workflow/WSS.PROJECT-SHAPE.md), which owns the signals
   and what evidence establishes each.

   **`record`, `consistency` and `safety-nets` apply to any repository.** One
   more runs when its signal is present:

   | Extra dimension | Runs when the shape has |
   |---|---|
   | `interface` | `public-api`, `cli`, or `service` |

   **`safety-nets` always runs, and it is a presence check rather than a
   review.** Does a test suite exist and pass, does CI exist and gate anything,
   is there a lockfile. **A missing suite is not a skipped dimension — it is a
   standing `high` finding**, verified by the absence itself and carried into
   every stocktake until the user dispositions it. Same for absent CI. Whether
   the tests are any *good* is the project skill's question, not this one's.

   **`correctness`, `security`, `data-model` and test *quality* are not run
   here.** They are the project code-analysis skill's. Where the project has no
   such skill they are simply not covered, and step 7 says so out loud.

   **Where the manifest declares `WSS.audit.dimensions`** it prunes, adds or
   re-briefs: a string names one from the set above; an object
   `{"name": ..., "brief": "path.md#anchor"}` supplies a project's own. Manifest
   entries win over inference. Dimension names are stable — coverage accounting
   across audits joins on them.
3. **Narrow the two dimensions that can be narrowed.** `record` is invalidated by
   the **code** changing rather than the doc, and `safety-nets` asks a question no
   diff can narrow; both always run full and both write `covered: []`. That
   leaves `consistency` and `interface`.

   For each, read `WSS.record.stocktake` newest-first: a path's governing baseline is the
   newest audit listing it under `covered`, and
   `git diff --name-only <baseline>..HEAD -- <globs>` is the slice. A path that
   appears only under `not-covered`, or in no block at all, has never been audited
   and is fully in scope, no diff. **Delegate this read to
   [`wss-survey`](../../agents/wss-survey.md)** — the floor comparison is
   against the floor divided by the turns the read is held, not the floor, and a
   whole-record read in an audit clears that (SKILL.md's floor paragraph) — brief:
   `WSS.record.stocktake`, named up front; verdict:
   one line per path, its governing baseline commit or `none`.

   The block's format, and the four rules constraining what you may skip, are
   [`WSS.AUDIT-COVERAGE.md`](../../wss/workflow/WSS.AUDIT-COVERAGE.md)'s.
4. **Apply the blast radius, strictly.** A file being unchanged does not mean its
   *behaviour* is unchanged. If any of these changed since a dimension's
   baseline, that dimension's narrowing is void and it returns to full scope.

   **The default set applies always, including with no manifest at all:**

   | Changed | Voids the narrowing for |
   |---|---|
   | a schema, its migrations, or whatever else defines the shape of stored data | **every** dimension |
   | the dependency manifest or its lockfile | correctness, consistency, security |
   | anything touching authentication, roles or ownership | security, **always** |

   **`correctness` and `security` are defaults for a project that supplies
   them** — through `WSS.audit.dimensions`, or its own code-analysis skill. This
   skill runs neither, here or in the `lanes` rule below. The schema row's
   **every** does include the dimensions it does run.

   **Where the manifest declares `WSS.audit.invalidates`** — a map of glob to the
   dimensions that glob voids, with `"*"` meaning all of them — those entries are
   **added** to the default set. A project can widen this rule and cannot narrow
   it.

   **Where `WSS.lanes.exclusive` or `WSS.lanes.serialize` exist, fold their paths in too**
   — exclusive voids every dimension, serialize voids correctness, consistency and
   security. Treat them as extra evidence, never as the definition: the default
   set stands with or without a manifest.

   **When in doubt, widen.** An audit that narrowed wrongly reports a clean bill of
   health it did not earn.
5. **Under `--wss-full-stocktake`, skip steps 3 and 4.** Everything is in scope,
   including every path previous audits listed as `not-covered`. Step 2 still
   runs — full scope means every dimension the repo has evidence for, not every
   dimension imaginable.
6. **Build the carry-over list — what previous audits already found.** From
   `WSS.record.stocktake`, take each previous audit's `Findings` and `Outcome` and sort
   them into:

   - **Fixed** — the remediation landed. These are **regression targets**: name
     them to the relevant auditor and have it re-check the fix is still there.
   - **Still open** — logged and not yet done. Do not let an auditor re-report
     these as new. Count how many audits have now reported each one; **two or
     more is itself a finding**, and a higher-severity one than the original.
   - **Disputed or dropped** — the user decided against it. Don't resurface it
     unless the tree changed underneath the reason. If you do, say which audit
     dropped it and why.

   Give every auditor the slice of this list touching its dimension.
   **Delegate this read to [`wss-survey`](../../agents/wss-survey.md)**, on
   the same divided-floor comparison SKILL.md states — brief:
   `WSS.record.stocktake`, named up front; verdict: the three lists above, each
   line naming the finding, its dimension and, for still-open items, its repeat
   count.
7. **State the plan in three or four lines before spending anything**: which
   dimensions run and on what evidence, each one's baseline and slice size, what
   is left out and why, and how many carry-over items came back. This is the
   user's chance to veto a dimension — but it is a statement, not a request for
   approval. Name a dimension left out for lack of evidence in the final report
   too: a reader cannot tell "clean" from "never looked at".
8. **Create the task list up front**, per `track`: one task per
   dimension, plus verification, the test run, the review and the rebuild. Mark
   each one as it moves — never batch the completions at the end.
