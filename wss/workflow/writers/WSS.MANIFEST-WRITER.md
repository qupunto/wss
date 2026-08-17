# Writing the manifest

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md), whose [read-inheritance rule](WSS.WRITERS.md#read-inheritance) this follows. Sole writer of `.claude/WSS.WORKFLOW.json`, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

Which keys may exist at all is [`WSS.MANIFEST.md`](../WSS.MANIFEST.md), the
authority this procedure validates against.

**It decides nothing.** The caller arrives having already settled what the value
should be — which file plays which role, which command runs the tests, whether a
key belongs at all. This skill checks that the key is real, that its value
resolves, and writes. Where the caller hands over a value that does not check
out, it hands the disagreement back rather than writing a corrected guess.

## Why this is not part of `--wss-adopt`

Its callers want different amounts of work, which is
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s split test:

- **`--wss-adopt`, adopting** — a whole manifest written once, after detection,
  searching and a round of questions.
- **`--wss-adopt`, amending** — one key added or corrected in a manifest that
  already exists. No detection phase, nothing to ask.
- **`update` (and `--wss-adopt` at its finish) — the `WSS.suite` stamp**: the
  version-and-commit object written after a passing doctor, and the manifest
  key renames a migration lands. Same rules as any amendment, with one
  addition: a stamp with an unresolvable commit is not written at all —
  [`WSS.MANIFEST.md`](../WSS.MANIFEST.md)'s `WSS.suite` row carries why.

A one-key amendment should not have to run an adoption to get written. The
detection and the asking stay with `--wss-adopt` because **a primitive has no channel
to reach the user**; everything downstream of the answer is here.

## What it writes

`.claude/WSS.WORKFLOW.json` and nothing else. In particular:

- **Not the record files.** `--wss-adopt` creates those empty. Creating a container
  is not writing a record, and this procedure does not even do that much.
- **Not `permissions.ask`.** That is a merge into the project's
  `.claude/settings.json`, which is not a record, has no single owner, and stays
  with `--wss-adopt`.
- **Not `.claude/WSS.SWEEPS.json`.** That is `sweep-tracker`'s, and it is not a
  manifest key — [`WSS.MANIFEST.md`](../WSS.MANIFEST.md) says why `WSS.sweeps`
  names the path rather than holding the state.

## Procedure

### 1. Establish which mode the caller is in

A manifest present means **amendment**: read it first, and report what it already
declares. A key the project already chose is never overwritten silently — if the
caller's value differs from the one on disk, that is a disagreement to hand back,
not a correction to make.

Absent means **first write**. Say which in one line; the two have different blast
radii.

### 2. Validate every key against `WSS.MANIFEST.md`

Three checks, and all three are cheap:

- **The key is documented.** A key with no row in
  [`WSS.MANIFEST.md`](../WSS.MANIFEST.md) is dead config — nothing reads it,
  and it will outlive everyone's memory of why it was added. Refuse it and say
  which row is missing.
- **The value resolves.** Every path must exist at the moment it is written, and
  every `#anchor` must be findable in the file it names. A key pointing at
  something aspirational misdirects every skill that reads it, silently, which is
  worse than the key being absent.

  **`WSS.record.todo` may be a provider object rather than a path**, and then this
  check is a different one — there is no file to stat. Key on the presence of a
  `provider` key, not on the value being an object (`WSS.record.tooling` is an object
  too). Resolving one means: the named provider is implemented in
  [`providers/`](../providers/), and its required keys resolve —
  for `github-issues`, `repo` is present and `gh repo view` finds it. That is
  what `wss-doctor.sh` checks, and the two must agree. An unimplemented provider or a
  repo that does not resolve is a failed key like any other: leave it out and say
  which. **`gh` being absent or unauthorized is not a failed key** — it is a
  property of this machine, the manifest is still correct, and doctor warns about
  it every run. Write the key and say that `--wss-todo` cannot reach the TODO list from
  here until `gh auth login`.

  **`WSS.lanes.named.*.records` paths are record paths like any other**, with three
  constraints of their own that `wss-doctor.sh` enforces: only the keys
  [`WSS.LANE-CONTRACT.md`](../WSS.LANE-CONTRACT.md) declares splittable may appear, every declared
  path exists, and each record splits for **all** named lanes or none. Refuse a
  lane map that breaks any of the three rather than writing it.

  **`transfer` is a sibling of `records`, never a key inside it** — a lane's
  queue, which many lanes write and `records` never does. It carries the same
  all-lanes-or-none rule and its path must exist.
  [`WSS.MANIFEST.md`](../WSS.MANIFEST.md) is the authority on both.

  **`WSS.recordMode` is a sibling of `WSS.record`, and is written whole or not at
  all.** Refuse it nested inside `WSS.record`: every skill reads
  `WSS.record.todo` as a scalar, and `wss-doctor.sh` walks every string under
  that key as a path that must exist, so a nested `"mode": "log"` comes back as a
  missing file. Then check it against the records being written —
  `WSS.record.tooling` expands to its sub-keys less `sources` — in **both**
  directions: a declared record with no entry, or an entry for a record nothing
  declares, refuses the whole key rather than that one row. Absent, the map falls
  back to [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#two-write-modes-every-record-is-a-log-or-a-register)'s
  table and the doctor warns; present and partial, the doctor **fails** — so
  writing three rows of four is the single outcome this check exists to prevent,
  and refusing a whole map that a caller got nearly right is the correct
  behaviour rather than an over-reaction.

  **`WSS.docs` holds one path and two things that are not paths.** `root` is a
  **directory** and must exist — a file at that path passes a bare `-e` and then
  every docs check walks nothing. `languages` is an array whose **first element
  is the root language**, so a caller handing over a translation-first list is
  handing over an inverted parity check, not a reordering: confirm the order
  rather than writing it as given. `devCommand` is a command, so there is nothing
  to stat; refuse it only when it is not a non-empty string.

  **Leave `root` out where the fallback already resolves it** — `docs/`, `doc/`,
  `documentation/`, `website/`, first existing. Writing a key that restates the
  default is not harmless here: it is a second place the site's location has to
  be kept true. Same for a `languages` list of one, which says exactly what
  absence says.
- **The name is the existing one where one fits.** Two names for one concept is
  the failure `WSS.MANIFEST.md` exists to end. Check the key against that
  contract's tables before coining one: a name that is merely *near* a
  documented key is the case to catch, and a genuine distinction —
  `indexRegen` rewrites, `indexCheck` verifies without writing — is not one.

**A key that fails any of these is left out**, and the caller is told which and
why. A missing key degrades gracefully and every skill says so in one line; a
wrong one does not.

### 3. Write

Ordered as [`WSS.MANIFEST.md`](../WSS.MANIFEST.md) presents them, so two
manifests written a year apart still diff cleanly. `manifest` first — without it
a global skill cannot tell which shape it is holding, so a renamed key reads as
absent rather than as an error.

Removing a key is the same operation and gets the same care: **a key deleted here
may still be whitelisted in `wss-doctor.sh`'s `KNOWN_KEYS`**, and the two must move
together or the unknown-key warning fires on a manifest that is now correct.

**A `WSS.record.*` key and its `WSS.recordMode` entry move together, on a
manifest that declares the map.** Adding a record without its mode, or leaving a
mode behind when its record goes, breaks a manifest that was passing — and the
doctor's failure names the record, not the write that caused it. Where the
manifest declares no map, both operations are unaffected: nothing to keep whole.

### 4. Prove it, do not claim it

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
"$S"/wss/tests/wss-doctor.sh
```

Run it and show the output. It checks that every declared path and `#anchor`
resolves and that every key is one `WSS.MANIFEST.md` documents — exactly the set of
mistakes this procedure can make.

**If it fails, fix and re-run.** Every later skill trusts the manifest without
re-verifying it, so a failing doctor here is a failure that surfaces somewhere
else entirely, weeks later.

### 5. Report back

To the caller, briefly: which keys were written, which were refused and why, and
the doctor result. The caller owns what happens next — the commit included.

## Authorization

**None of its own.** Like every flagless primitive here, its grant is whatever
the caller was granted, and it confers nothing —
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md) has the rule. It never commits on
its own initiative; the caller invokes `git-writer` when its own flag allows.
