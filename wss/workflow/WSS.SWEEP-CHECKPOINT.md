# The sweep checkpoint

**The one authority on how a sweeping skill remembers what it already verified.**
A sweep that re-reads everything on every invocation costs the same on its
hundredth run as on its first, and almost all of that hundredth run is re-reading
files nobody has touched since they were approved.

The checkpoint is what turns that into a diff. Written by
[`sweep-tracker`](writers/WSS.SWEEP-TRACKER.md) and **read by everyone else**
— which is what keeps the one-writer invariant in [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md)
literally true rather than needing an exception for shared state.

Who may write what is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md); what each *record* holds is
[`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md). This file is about **shape**, and
about a file that is deliberately not a record.

## It is a cache, not a record

`.claude/WSS.SWEEPS.json` by default; the manifest key is `WSS.sweeps`. **Gitignored, and
that is the design rather than an oversight:**

- It is **derived**. Everything in it can be recomputed by sweeping again.
  Deleting it costs one full sweep and can never cost correctness.
- It describes **what this machine verified**. Committed and shared, one person's
  half-finished sweep would license everyone else's skip — and they would have no
  way to know that is what happened.
- The safe default falls out of it. **No file, no entry, or an unreadable one
  means a full sweep**, so a fresh clone, a CI run, or a second machine degrades
  to exactly the behaviour that existed before checkpoints did. Absence can cost
  tokens. It can never cost truth.

The tracker adds the ignore rule on first write. A checkpoint that is committed
by accident is not a disaster — but it will be read as authoritative on a machine
that never ran the sweep, which is the one thing this file cannot detect about
itself.

## The file

```json
{
  "sweep": "sweeps/v1",
  "entries": {
    "docs": {
      "baseline": "9ae2a52",
      "at": "2026-07-31",
      "method": "incremental",
      "complete": true,
      "scopes": [
        { "name": "site-mechanics", "covered": ["docs/**"], "not-covered": [] },
        { "name": "accuracy", "covered": ["docs/routing.md"],
          "not-covered": ["docs/annex/api.md"] }
      ]
    }
  }
}
```

| Field | Meaning |
|---|---|
| `sweep` | Contract version. A skill that does not recognise it sweeps in full rather than guessing — the same reason `manifest` is required in [`WSS.MANIFEST.md`](WSS.MANIFEST.md) |
| `entries` | One per sweeping skill, keyed by a **stable** name. Coverage accounting across runs is a join on this string, so renaming one silently discards its history |
| `baseline` | The commit the sweep ran against, short sha |
| `at` | The date, for the human who opens the file. Never read by a skill |
| `method` | `incremental` or `full` |
| `complete` | `true` asserts every path in scope is in exactly one of the two lists. A skill that cannot assert that writes `false`, and the next reader treats anything absent from `covered` as unverified |
| `scopes` | The sweep's own subdivisions — a dimension, a record file, a class of check. Flat sweeps write a single scope |
| `covered` / `not-covered` | Globs. What was demonstrably verified, and what was not |

**Reserved entry: `test-run`.** It carries `baseline`, `complete`,
`result: green | red`, and `test-count` where the runner reports one. It has no
`scopes` — a suite is meaningful only in whole, which is also why the entry can
never license running part of one.

**When it permits skipping a run**, and the conditions are all load-bearing: the
`baseline` is *this exact* `HEAD`, the working tree is clean, and `result` is
`green`. Report the previous run's result and count, and say it was carried
forward rather than re-run.

Two things void that even when all three hold:

- **A suite that is not hermetic.** If it touches a shared store, the network or
  the clock, "same commit" does not imply "same result". Where you cannot
  establish it is hermetic, run it.
- **A changed environment** — a dependency install, a runtime upgrade, an
  environment variable. The tree is what the sha addresses; the machine is not.

**A carry-forward is never a subset run.** The temptation is to reach for the
second when the first does not apply, and it does not help: a subset cannot
support a claim about the suite, whatever the checkpoint says.

**Freshness-only entries.** A sweep whose coverage belongs to a permanent record
— [`WSS.AUDIT-COVERAGE.md`](WSS.AUDIT-COVERAGE.md) keeps `WSS.record.stocktake` out of this
cache deliberately — may still stamp an entry holding nothing but its name,
`baseline` and `at`, so that *when did this last run* is answerable without
parsing the record that holds the findings. `--wss-health-check --deep`'s TODO
resort writes one, keyed `stocktake`.

Such an entry carries **no `scopes`, and therefore licenses nothing**: the
reading procedure below resolves a path in neither list as never swept, so the
whole scope comes back exactly as it would with no entry at all. That is what
lets the date be cheap without the cache acquiring a second opinion about
coverage.

Stamp the entry including when the result is **red**. A red result carried
forward is exactly as useful as a green one, and rather more urgent.

## Five rules, and they are the whole value

Rules 1-4 are generalised from [`WSS.AUDIT-COVERAGE.md`](WSS.AUDIT-COVERAGE.md),
which states them for the audit record — same rules, one statement. **Rule 5 is
this cache's own**, and it governs a different question from the other four:
they say what a written stamp may claim, it says whether one is written at all.

**1. The slice a run was given is an upper bound, never the claim.** A sweep can
cover less than it was pointed at. It can never cover more.

**2. `covered` is what was demonstrably read** — the paths a run reported as
checked and clean, plus the paths it cited findings in. Not the paths it meant to
get to.

**3. Silence is not coverage.** Anything a run could not check, anything it was
pointed at and never mentioned, and every path left dirty in the working tree
goes in `not-covered`. A vague report counts as `not-covered` too: the cost of a
needless re-read is a few thousand tokens, and the cost of a wrong `covered` is a
file nobody looks at again.

**4. A scope that is never incremental writes `covered: []`.** It ran in full and
claims nothing forward. Recording its slice as `covered` would let a later run
skip on the strength of a run that never intended to license that.

**A scope with no evidence globs is rule 4's case, not a new rule.** Where a
scope's `covered` would name only the file that was checked and nothing it was
checked *against*, step 2 below resolves it to
`git diff <baseline>..HEAD -- <that same file>` — the file diffed against itself.
It is not a false stamp; it addresses the wrong thing. A record describing code
that moved, where the record itself did not move, comes back unchanged, and only
the runner's own blast radius stands against that. Record scopes are the case
that arises in practice: `covered` is the record file **plus the code globs the
run read to verify it** — the pairing every record-scope check makes — and a
run that verified a record by reading the record has no second half to pair. It claims nothing forward, so it writes `covered: []` and the next
sweep reads that scope in full.

**Where every scope in an entry does that, the entry is `complete: false`.** That
is the shape [`sweep-tracker`](writers/WSS.SWEEP-TRACKER.md) already prescribes
for a stamp that cannot produce coverage, and it is what `wss-doctor.sh` checks
for — `complete: true` beside an empty `covered` is a whole scope claimed by
saying nothing, which rule 3 forbids. An entry with a mix keeps `complete: true`:
the scopes that did pair evidence still claim what they covered.

**5. A stamp is written only for a healthy scope: no findings, or every finding
the run made fixed or dispatched.** A finding left with no home — neither fixed
inline nor handed to the owner that would fix it — withholds the stamp for the
scope it lives in, so that scope's files stay inside every later run's slice
until someone acts. **"Acted upon" includes dispatched**: a finding fixed on the
spot and one filed to its owner both have a home, and neither blocks the stamp.
**This is a health assertion rather than a coverage one**, which is why it sits
beside rules 1-4 rather than inside them — those govern what a stamp may claim
once written, this governs whether writing one is honest. The ruling is the
decision log's `2026-08-19 (eighty-fourth)` entry, which vetoed the drafted
alternative that a stamp records what was *read*: that would let a
known-unhealthy file age out of scope on the strength of having been looked at.

## Reading a checkpoint

The procedure, stated once so no two skills invent their own:

1. **Read the entry.** No file, no entry, an unrecognised `sweep` version, or a
   `baseline` that is not a commit in this repository — sweep in full. Say which
   in one line; a silent fallback to full scope reads as a slow skill rather than
   a cold cache.
2. **Resolve each scope's slice.** It is the union of three things:
   `git diff --name-only <baseline>..HEAD -- <covered globs>`, everything listed
   under `not-covered`, and everything in scope today that appears in neither
   list — a file created since the last sweep has never been looked at.
3. **Apply the skill's own blast radius.** A file being unchanged does not make
   its *meaning* unchanged. Each sweeping skill states what voids its narrowing;
   the tracker does not judge this and cannot.
4. **Report `covered` and `not-covered` honestly, then hand them to the tracker.**
   A sweep that stamps a baseline without saying what it covered is claiming the
   whole scope, which is rule 3 inverted.

**When in doubt, widen.** A sweep that narrowed wrongly reports clean on
something nobody read, and nothing downstream can tell the difference. That
asymmetry is the only reason this mechanism is safe to use at all.

## What it must never hold

- **Findings.** What a sweep *found* goes to the record file that owns it, via
  that file's owner. The checkpoint holds only what was *looked at*.
- **Prose, reasoning, or task lists.** Those are `WSS.record.decisions` and
  `WSS.record.todo`, and a cache that accumulates them becomes a second record that
  nothing keeps current and git does not track.
- **Absolute paths or machine identifiers.** Globs are repo-relative. The file is
  machine-local; its *contents* should still read the same anywhere.
