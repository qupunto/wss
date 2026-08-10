# The audit-coverage block

**The format `--wss-stocktake` writes into every entry of `WSS.record.stocktake`, and reads back
on the next run to decide what it may skip.** One copy, here, because a format
defined only inside a project's own audit record does not exist until that
project's first audit invents it — and the first audit is exactly the one with no
prior art to copy.

Who may write the record is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md); what the record holds
is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md); the rules every sweep narrows by
are [`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md). This file is about the **shape**
of the audit's own block.

## The block

A fenced block inside each audit entry:

```yaml
audit-coverage:
  baseline: a1b2c3d              # the tree audited; "a1b2c3d+dirty" is legal
  method: incremental            # or: full
  model: <tier actually used>    # the disclosure, machine-readable
  ci: green                      # green | red | none
  test-count: 412                # runtime count from the run's own output; omit if no suite
  dimensions:
    - name: consistency
      covered: ["src/core/**", "src/util/time.*"]
      not-covered: ["src/legacy/**"]
    - name: safety-nets
      covered: []                # never incremental: empty covered claims nothing forward
```

`name` is a stable dimension name — one from the skill's dimension library, or
one the manifest's `WSS.audit.dimensions` declared. Stability is the point: coverage
accounting across audits is a join on this string.

**Which is why the names above are real ones.** `--wss-stocktake` runs `record` and
`consistency` against any repository, `interface` when the shape has a public
API, a CLI or a service, and `safety-nets` always. It deliberately does **not**
run `correctness`, `security` or `data-model` — those belong to a project's own
code-analysis skill and arrive, if at all, through `WSS.audit.dimensions`. This block
is what a project's first audit copies, and a copied name that no dimension ever
emits joins against nothing forever: the next run reads it, matches no dimension,
and silently treats that scope as never covered.

## Four rules, and they are the whole value

**They are not audit-specific.** Every sweep in this workflow narrows itself the
same way, so the rules are stated once, in
[`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md#four-rules-and-they-are-the-whole-value):
the dispatched slice is an upper bound and never the claim; `covered` is what was
demonstrably read; silence is not coverage; a scope that is never incremental
writes `covered: []`.

What they mean **here**, where the reader of a report is an auditor rather than a
script:

- `covered` is the union of what auditors reported under "checked and clean" and
  the paths they cited findings in. Nothing else.
- Anything under "could not check", any dispatched path no report mentions, and
  every dimension that died or was skipped is `not-covered`. **A report vague
  about which paths it read is `not-covered` too** — the cost of a needless
  re-read is one agent, and the cost of a wrong `covered` is code nobody looks at
  again.
- `record` and `safety-nets` always write `covered: []`. They are never
  incremental, so they license nothing forward.

## Why this lives in the record and not in the sweep cache

Every other sweep stamps a *cache* — gitignored, disposable, rebuilt by sweeping
again. This block is written into `WSS.record.stocktake`, which is committed and
permanent, and the difference is deliberate.

An audit entry is evidence about a moment: what was examined, by what, against
which tree, and what that run was worth. Deleting it loses something no later run
can reconstruct. A sweep checkpoint holds only a *current position*, and deleting
it costs one full sweep.

So the two share their rules and not their storage. When both are present, the
audit record is the authority on what the audit covered; the checkpoint never
carries an audit's coverage or its findings.

**A freshness-only entry is not that entry**, and the distinction is the whole
of what the checkpoint may know about an audit: a name, a `baseline` and a date,
so a reader can ask *when did this last run* without opening the permanent
record. It claims no coverage, so it settles no question the audit record owns,
and it licenses no narrowing — [`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md) is
where the shape lives.

## Why it is written down rather than inferred

Incremental auditing is the difference between an audit that gets cheaper as a
project matures and one that costs the same every time. It is also the only part
of an audit that can silently lie: a wrong `covered` produces a clean bill of
health on code nobody read, and nothing downstream can tell the difference.

Written in this shape, it is checkable — a baseline that is a real commit,
globs that parse, dimension names that resolve — which turns the discipline into
a contract something else can verify.
