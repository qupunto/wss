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

**Which is why the names above are real ones** — drawn from `--wss-stocktake`'s
own dimension library; its Phase 0 is the authority on which dimensions run
when, and `WSS.audit.dimensions` is how a project adds its own. This block
is what a project's first audit copies, and a copied name that no dimension ever
emits joins against nothing forever: the next run reads it, matches no dimension,
and silently treats that scope as never covered.

## The narrowing rules, and they are the whole value

**They are not audit-specific.** Every sweep in this workflow narrows itself the
same way, so the rules are stated once, in
[`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md#four-rules-and-they-are-the-whole-value).

What they mean **here**, where the reader of a report is an auditor rather than a
script:

- `covered` is the union of what auditors reported under "checked and clean" and
  the paths they cited findings in. Nothing else.
- Anything under "could not check", any dispatched path no report mentions, and
  every dimension that died or was skipped is `not-covered`. **A report vague
  about which paths it read is `not-covered` too.**
- `record` and `safety-nets` always write `covered: []`. They are never
  incremental, so they license nothing forward.

## Why this lives in the record and not in the sweep cache

The audit record and the sweep cache share their rules and not their storage.
This block is written into `WSS.record.stocktake`, which is committed and
permanent; every other sweep stamps a cache that is gitignored and disposable.
When both are present, the
audit record is the authority on what the audit covered; the checkpoint never
carries an audit's coverage or its findings.

**A freshness-only entry is not that entry**, and the distinction is the whole
of what the checkpoint may know about an audit: a name, a `baseline` and a date,
so a reader can ask *when did this last run* without opening the permanent
record. It claims no coverage, so it settles no question the audit record owns,
and it licenses no narrowing — [`WSS.SWEEP-CHECKPOINT.md`](WSS.SWEEP-CHECKPOINT.md) is
where the shape lives.
