# The sweep tracker

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md), whose [read-inheritance rule](WSS.WRITERS.md#read-inheritance) this follows. Sole writer of the sweep checkpoint, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

One file, one job. It owns the sweep checkpoint — the cache that lets a sweeping
skill re-read only what changed since it was last approved, instead of paying
full price on every invocation. Which sweeps use it is not listed here: the
entries in the file are the answer, and each one names its own reader.

**Everything about the file's shape, its rules, and how a sweep resolves its
slice from it is [`WSS.SWEEP-CHECKPOINT.md`](../WSS.SWEEP-CHECKPOINT.md).**
That file is the authority; this one is the procedure. Read it before writing an
entry — the four rules there are what stop a checkpoint from licensing a skip
nobody earned.

**Why this is a procedure rather than a paragraph in each sweep** is argued in
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md#one-writer-many-readers--the-sweep-checkpoint),
which is the authority on it.

## Resolve — called at the start of a sweep

The caller names its entry and its scopes. Return, per scope, the slice to sweep
and one line saying why:

1. Read `WSS.sweeps` from `.claude/WSS.WORKFLOW.json`, falling back to
   `.claude/WSS.SWEEPS.json`.
2. Resolve each scope's slice per
   [`WSS.SWEEP-CHECKPOINT.md`](../WSS.SWEEP-CHECKPOINT.md#reading-a-checkpoint).
3. **Say what is being skipped and on what authority** — "docs/ unchanged since
   `9ae2a52`, verified then; sweeping 3 pages" — in one line, not a table. A
   narrowing the user cannot see is one they cannot overrule, and a skill that
   silently does a tenth of its job looks identical to one that did all of it.

**Any doubt resolves to full scope.** A missing file, an unparseable one, a
baseline `git cat-file -e` cannot confirm, an unrecognised `sweep` version, a
scope name that has never appeared: all of them mean sweep everything. None of
them is an error worth stopping for.

## Stamp — called at the end of a sweep

The caller hands over its method and, per scope, the globs it covered and the
globs it did not. **It does not hand over a baseline** — the write step
computes it. A typed baseline can drift from the commit it claims to be; a
computed one cannot, and the drift that closes is one this suite actually had
(`wss/logs/WSS.DECISIONS.md`, "Tooling splits three ways, and the collector is a
script because none of it is judgment").

1. **Refuse a stamp that carries no coverage.** A caller offering only a commit
   id is claiming its whole scope by omission. Ask it for its `covered` and
   `not-covered` lists, and if it genuinely cannot produce them, write
   `complete: false` with `covered: []` — which costs one full sweep next time
   and is the only honest thing to record. (The write step below refuses this
   mechanically for a scoped entry with no `--scopes-file`, or an empty one —
   but *which* paths belong in `covered` versus `not-covered` is still this
   judgment, made before the call.)

   **Unless it asks for a freshness-only entry**, which is the one shape that
   has no coverage to withhold: write the name, `baseline` and `at`, and
   nothing else — no `scopes`, no `method`, no `complete`. It claims nothing by
   omission because it claims nothing at all, and
   [`WSS.SWEEP-CHECKPOINT.md`](../WSS.SWEEP-CHECKPOINT.md) is where that is licensed.
2. **Move the dirty paths to `not-covered`.** A path with uncommitted changes
   was verified in a state the baseline sha does not address, so no later diff
   can reason about it — decide this before calling the write step, per scope.
   The `+dirty` marker on the baseline itself is not this caller's job at all:
   the write step below stamps it automatically whenever `git status
   --porcelain` is non-empty at call time. A freshness-only entry has no
   `covered` to move dirty paths out of and keeps the `+dirty` marker alone.
3. **Call the write step — never hand-edit the file.**

   ```
   wss/scripts/wss-sweep-stamp.sh <entry> --freshness
   wss/scripts/wss-sweep-stamp.sh <entry> --test-run --result <green|red> [--test-count N]
   wss/scripts/wss-sweep-stamp.sh <entry> --method <incremental|full> --complete <true|false> --scopes-file <path>
   ```

   `<path>` is a JSON file holding the array of `{name, covered, not-covered}`
   scopes decided in steps 1–2 above. The script computes `baseline` (`git
   rev-parse --short HEAD`, `+dirty`-suffixed per step 2), fills `at`, and
   replaces any previous entry for that key — the checkpoint is not a log, it
   holds the current position, and the history of what was swept when belongs
   to `WSS.record.stocktake` where a project keeps one. It also re-checks that
   the resolved path is gitignored (next point) and refuses to write if it is
   not, rather than editing `.gitignore` itself. Everything it refuses and why
   is in its own header comment; this procedure does not repeat it.
4. **The file must be gitignored** before the first write — the file the
   *manifest* resolved to in Resolve step 1, never a literal path, or a project
   that declares its checkpoint elsewhere passes this check vacuously and commits
   the real one. The write step checks this itself and refuses rather than
   writing; if it refuses on a fresh project, add the rule to `.gitignore` by
   hand and re-run. A committed checkpoint is read as authoritative on a
   machine that never ran the sweep.

## Reset

Delete the resolved checkpoint file, or the single entry. Both are safe by
construction — the next sweep sees no baseline and runs in full.

Prefer `--wss-full-check` when the intent is "re-verify everything": it sweeps at
full scope *and* leaves fresh entries behind, where deleting the file leaves the
next ordinary sweep to pay for it.

## What this procedure does not do

- **It does not sweep.** It never opens a doc, a record file or a source file to
  check anything. It reads git metadata and one JSON file.
- **It does not judge coverage.** The caller says what it covered; the four rules
  in [`WSS.SWEEP-CHECKPOINT.md`](../WSS.SWEEP-CHECKPOINT.md) constrain the
  caller, not this procedure. The one thing it does refuse is a stamp with no
  coverage at all, because that is a claim rather than a report.
- **It writes no record file, and it does not commit.** The checkpoint is
  gitignored, so there is nothing to commit.
