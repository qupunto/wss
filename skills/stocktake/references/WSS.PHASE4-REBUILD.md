# Phase 4 — Rebuild `WSS.record.todo`, then record the audit

`WSS.record.todo` is not appended to — it is **restructured**. The restructure is
*decided* here and *written* by `--wss-todo`, which owns that file. This skill
supplies the dispositions and the approved shape.

1. **Propose the restructure before doing it.** Sections you would merge, split,
   rename, reorder or drop, and where new items land — a short list, not a diff.
2. **Then rewrite it through `--wss-todo`, and delegate the transcription.** Hand a
   subagent the dispositions, the approved restructure and the house format, and
   have it return the rewritten file. Ask it for a section inventory first if you
   need one for step 1 — that is a dozen lines, not the whole file. House format:
   new items in the section they belong to (checkbox, bold name, technical
   detail, file paths, no reasoning — reasoning lives in `WSS.record.decisions`),
   reordered within sections so severity is visible from the top. Delete anything
   the audit found already done; `WSS.record.todo` is forward-looking, items are
   removed, never struck through.
3. **Nothing disappears without a home.** Every deleted item is either
   demonstrably done (say where), moved to `WSS.record.decisions`, or moved to
   `WSS.record.openDecisions`. If you cannot name the home, it stays.
4. **`WSS.record.roadmap` and `WSS.record.releases` if priorities moved — propose, don't
   write.** `--wss-plan` is sole writer of both: goals and their order in the first
   — every lane's copy — and milestone boundaries, the version a milestone intends
   to ship as, and the marks in the second. A finding severe enough to reorder a
   roadmap gets its own block; hand the reorder to `--wss-plan` even when you have
   the whole picture and the edit looks trivial. **A version or a completion mark
   found in a roadmap is a finding, not a detail to preserve** — it belongs in
   `WSS.record.releases`, and under lanes it is a release checkpoint one worktree cut
   for the whole project. **A finding about a version or a tag is `--wss-release`'s
   decision**, and a correction to `WSS.record.changelog` is `changelog-writer`'s
   write — including drift between what the documents claim shipped and what
   `git tag` actually has.
5. **`WSS.record.handoff`, narrowly — through `handoff-writer`, which owns it.** Hand
   it only the `!important` warnings this audit *created* or *resolved*: one line
   each plus a pointer, with the resolved ones deleted immediately. Do not write
   the file here, even though it is one line and obviously correct. The broader
   currency pass comes later, when Phase 5's `--wss-wrap` calls the same primitive.
6. **Hand any decision this audit produced to `--wss-log`, and let it regenerate the
   index.** `WSS.record.decisions` and `WSS.record.decisionsIndex` are `record`'s,
   and the index is generated — never hand-run `WSS.commands.indexRegen` here.
7. **`WSS.record.stocktake` last — through [`audit-writer`](../../../wss/workflow/writers/WSS.AUDIT-WRITER.md),
   which owns it.** Hand it the material this audit produced: the tree and
   whether it was clean, the scope, the method, which findings you re-checked by
   hand against which are agent-reported, the test and CI results, the findings,
   the carry-over counts and any `[missed by <date> audit]` annotations.

   **Build `covered` from the auditors' reports, not from your plan**, and hand
   *that* over rather than a summary of your intentions. The four rules that make
   it mechanical rather than a judgement call are
   [`WSS.AUDIT-COVERAGE.md`](../../../wss/workflow/WSS.AUDIT-COVERAGE.md); the one that gets bent
   is *silence is not coverage*, and it gets bent because a wide `covered` list is
   what makes your next run cheap. Separating the claim from the record is what
   keeps it reviewable.

   **Updating `Outcome` later does not come back through this skill.** It is a
   one-field write on an existing entry, and the caller landing the remediation
   goes to `audit-writer` directly — needing a full audit procedure to move a
   status field is the shape this split removed.
8. **Then hand `sweep-tracker` a freshness-only entry** keyed `stocktake` — the
   name, the `baseline` and the date, and nothing else. **No coverage and no
   findings**: those went to `WSS.record.stocktake` in step 7, and
   [`WSS.AUDIT-COVERAGE.md`](../../../wss/workflow/WSS.AUDIT-COVERAGE.md) keeps them out of a
   cache that gets deleted. What this buys is that `--wss-overview` can say when
   this last ran without opening the audit record at all — and it licenses no
   narrowing, because an entry with no scopes leaves the next run's slice
   untouched. The shape is
   [`WSS.SWEEP-CHECKPOINT.md`](../../../wss/workflow/WSS.SWEEP-CHECKPOINT.md)'s.
