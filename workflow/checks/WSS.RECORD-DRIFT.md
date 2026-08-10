# Record drift — what to look for

> **A shared method, not a skill.** See [`WSS.CHECKS.md`](WSS.CHECKS.md). The runners that
> borrow it are `--wss-check` (incremental, records only), `--wss-full-check` (full scope,
> records + docs + tooling) and `--wss-stocktake` (the record dimension of a whole-project
> audit). Each supplies its own scope and decides what to do with a finding; this file
> is only the taxonomy of what counts as one.

## What to look for

### 1. Claims that were true when written

The highest-yield check, because nothing forces an update when the underlying
reality changes. Grep for **absolute-sounding claims about state that moves**:

- "no migration", "no real data", "hasn't been built", "not yet"
- "nothing sets / reads / enforces X"
- "currently X" followed by a specific list or count
- any count at all: tables, endpoints, tests, entries, languages, tokens

**A negative claim is the highest-risk kind**, and gets the disproving grep in
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#negative-claims) before
you trust it. Two shapes worth checking for specifically here, because both
redirect work before anyone notices:

- **A claim about the whole codebase drawn from part of it** — "nothing sets X"
  when the layer that sets it was not the layer that was read.
- **A count that described one environment and is read as describing another** —
  seed or fixture totals in particular, which differ per environment by design.

### 2. Updates the code owes but never got

No other check covers this, and it is why the trigger table is stated
diff-shaped: a diff-shaped obligation is mechanically checkable.

| A diff touching | Owes an update to |
|---|---|
| routes, services, domain logic — where it changes an auth rule, an ownership rule, a state transition, a visibility rule, an error status, or ordering | `WSS.record.behaviour` |
| the schema | `WSS.record.reference` (data model) |
| container, deployment or proxy config, operational scripts, or a stated convention | `WSS.record.reference` (overview) |
| a commit that implements what a backlog item describes, or that clears the blocker one is parked on | `WSS.record.todo` — the lane's, where a `.claude/WSS.LANE` selector resolves one. Where it names a provider there is no file to diff; the paragraph below applies |
| block scope, order or dependencies | `WSS.record.roadmap` — the lane's, where a `.claude/WSS.LANE` selector resolves one |
| a milestone's scope, its intended version, or which goals it comprises | `WSS.record.releases` |
| a dependency added, removed or replaced where the stack declares them, or a capability hand-built that a registry row says a library already covers | `WSS.record.toolbelt` |
| a skill or agent file added, removed, or changed in purpose | `WSS.record.tooling.catalog`, and the docs site's Claude-tooling annex page, which is derived from it |

The last row is two findings, not one: the catalog and the annex page derived
from it are separately owned. A catalog that moved while the page did not is
the ordinary failure of any derived copy, and it is invisible from either file
alone.

So: what changed since the last time each record file did? `git log` the record
file, `git log` the code it describes, and compare. A code path that moved after
its record last did is a finding — **a candidate, not a defect**, since the
change may genuinely not have been observable.

**This method needs a file, and `WSS.record.todo` may not be one.** A provider-backed
backlog has no git history in this repository, so there is no "last time it
changed" to compare against and the comparison is simply unavailable — read the
open issues in full and judge them on their content instead, per
[`providers/WSS.GITHUB-ISSUES.md`](../providers/WSS.GITHUB-ISSUES.md). Do not report the
absence as drift; it is the declared shape, not a fault.

### 3. Mutable claims in the tooling files

What `WSS.record.tooling.sources` — the skill and agent files — may and may not carry
is
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#the-mutable-claim-rule),
which is the authority; read it rather than a copy here.

A claim these files may not carry is a finding.

### 4. Generated files that are out of date

Where the manifest names a check command (`WSS.commands.indexCheck`), run
it. A generated file cannot drift, only lag — and that is detectable, which is
exactly why it is generated.

**A stale result is a finding, never a fix**: running the regen command is a
write, and this method is read-only.

### 5. Dangling cross-references

A skill or agent citing another that does not resolve. These read exactly like
live references, which is why they survive. The suite's `wss-doctor.sh` checks this
mechanically; run it rather than reading for it.

### 6. Release drift — documents claiming what no tag resolves

```bash
git tag -l
git ls-remote --tags origin
```

Both, because they answer different questions: a tag that exists locally and
not on the remote means nothing to anyone else's checkout. Compare against the
versions `WSS.record.changelog` and `WSS.record.releases` claim shipped.

**Include a public `CHANGELOG.md`** where one exists and is not what
`WSS.record.changelog` points at — that test is `--wss-release`'s own, and it is
the only way to identify the file, since no manifest key names it. It is not a
record and has no owner, which is why nothing else looks at it; it is still a
per-version claim about what shipped, and a tag with no entry, or an entry no tag
resolves, is the same finding as in either record above. **Only the version
headings are in scope** — the entries themselves are an append-only log, so the
prose is history rather than a claim to re-verify, and the exemption above
applies to it for that reason rather than for its not being a record.

Three distinct findings live here:

- `WSS.record.changelog` describes a version no tag resolves — the entry's
  released status is wrong.
- `WSS.record.releases` claims a milestone *shipped*, rather than that it is
  *completed* — a tag is the only proof a version shipped.
- **A roadmap carries a version number or a completion mark.** Neither belongs
  in that record, and under lanes it is a release checkpoint one worktree cut
  for the whole project. `wss-doctor.sh` catches this mechanically; report it here
  when a sweep reads the file anyway, and dispatch it to `--wss-plan` like any
  other finding about its records.

**Report it; never resolve it by tagging.** Choosing between tagging the commit
a milestone completed at and recording the work as unreleased is a release
decision the user makes. This dimension exists so the drift is found on an
ordinary sweep rather than only when someone happens to cut a release — which
is exactly when nobody is releasing.

**No baseline narrows this dimension.** Tags move without any commit touching
the repository, so a scope computed from commits cannot tell you it is
unchanged. It is two git commands; run them every sweep.

## What is NOT a finding

Getting these wrong turns the inspector into noise, and an inspector nobody
trusts is worse than none.

- **History is not staleness.** Never report a "fix" for an entry in
  `WSS.record.decisions` that a later entry reversed — it is correct as written, per
  [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md)'s rule 4. Stated here rather than
  only cited, because this is the guard that stops an inspector reporting and it
  has to fire before anyone opens another file.
- **Personal and environment facts** — dev machine, IDE, personal tooling paths
  — cannot be verified from the repo. Ask; do not infer, and do not report a
  guess.
- **Decided-but-unbuilt behaviour** belongs in `WSS.record.decisions` and is not
  missing from `WSS.record.behaviour`.
- **A rejected alternative** named in documentation is *supposed* to describe
  something absent from the source. Do not report it as a dead reference.
- **Aspirational or unused code marked as such** is correctly documented.

