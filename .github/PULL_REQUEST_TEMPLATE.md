<!-- Summary first, before any heading: what changed and why, at decision level.
     One bullet per non-obvious call. A reviewer should be able to stop here and
     know whether to keep reading. -->

## Type

Feature | Fix | Refactor | Docs | Build | Chore

<!-- Keep the applicable ones, delete the rest. -->

## Related issue

<!-- A link, or "none". -->

## Checks

<!-- Run these BEFORE drafting this body, and tick each one from its result with
     the command cited. A check that failed stays unticked with its failure line
     quoted — the PR is still opened, and the gap is visible rather than absent.
     A check that does not apply is struck through with the reason. -->

- [ ] tests pass — `<command>`, `<N>` passed
- [ ] typecheck clean — `<command>`
- [ ] doctor clean — `wss/tests/wss-doctor.sh`, 0 failures
- [ ] records current — `--wss-health-check`

## Attestations

<!-- Human-only: nothing may tick these for you. Delete any row that does not
     apply rather than leaving it unticked, so an empty box always means
     "considered and not done" rather than "not applicable". -->

- [ ] one logical piece of work
- [ ] edge cases considered
- [ ] acceptance criteria checked

## QA instructions

<!-- Concrete steps a reviewer can follow, per surface touched. Name the
     evidence where it exists rather than asserting the outcome. -->

## [optional] Post-merge tasks
