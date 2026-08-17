# The mechanical gauntlet

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). The cheap,
already-written half of any health pass: run the project's own verifications
and read CI's verdict on the audited commit. A finding here is any non-green
result, and it outranks prose findings — drift describes the tree; a red suite
describes the product.

This file is the one statement of the gauntlet's rules; a runner keeps only what
is genuinely its own — scope, where in its procedure the gauntlet runs, and what
to do with a failure. The execution — running the doctor, the typecheck and
test commands, and resolving CI, then assembling the verdict block — is
[`wss-mechanical-gauntlet.sh`](../../wss/scripts/wss-mechanical-gauntlet.sh), at the repo
root because more than one skill invokes it.

## The sequence

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
"$S"/wss/scripts/wss-mechanical-gauntlet.sh [--test-consent] [--carry-forward REASON]
```

— doctor, `WSS.commands.typecheck`, the full `WSS.commands.test` suite gated
per "The consent budget" and "The carry-forward" below, and CI resolved per
"CI, on the audited commit" below, in one call. The flags are how a runner
hands in those two sections' judgment calls; the script makes neither itself.

**The doctor is never optional and no checkpoint covers it.** It inspects both
the configuration and the project in `$PWD`, and it catches the failures that
read exactly like working config — a record path that no longer exists being the
shape to picture.

**Always the full suite, and always the coverage command rather than a bare
test run** — a green suite says nothing about `WSS.gate.coverage`, which is what CI
enforces. If the suite fails, re-run once in full before treating any failure
as a finding.

## The consent budget

Where `WSS.commands.testConsentEnv` gates the suite behind a token only the user
can supply, there is **one** attempt in a session: ask once, say what the run
would cost if refused. A refusal is not a blocker — it makes the suite
`not-covered`, and everything else still runs.

## The carry-forward

The test run is the only step here that may be skipped, and only when
`sweep-tracker`'s `test-run` entry licenses it — the conditions, and the two
things that void them, are
[`WSS.SWEEP-CHECKPOINT.md`](../workflow/WSS.SWEEP-CHECKPOINT.md)'s. Ask the tracker rather
than reading the checkpoint file. A carried result is reported as carried, with
the previous count — never as if it ran.

**A runner that has edited files re-runs and does not stamp.** A dirty tree
stamps as `<sha>+dirty`, which can never satisfy a later carry-forward; the
rule is unconditional so nobody judges tree state mid-run. Stamping the
`test-run` entry is for a run made on a clean tree, handed to `sweep-tracker`
with the sha, the result and the runtime count.

## CI, on the audited commit

A green local run says nothing about whether the tests gate anything. The same
`wss-mechanical-gauntlet.sh` call resolves the audited SHA against
`WSS.commands.ci` — GitHub Actions via `gh run list --limit 20 --json
headSha,conclusion,workflowName,createdAt`, or a declared shell command.

Four outcomes, all of them reported. **Green** — say so. **Red** — a finding on
its own, outranking most prose findings. **No run for this SHA** — the commit
was never pushed, or the triggers do not cover it; say which. **No CI at all** —
a standing finding, carried. Never quietly treat a missing run as a pass.
