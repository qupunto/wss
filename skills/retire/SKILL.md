---
name: retire
description: "Retire the workflow from the project in $PWD — the reverse of adoption. One checkbox dialog: a full snapshot (WSS.RETIREMENT-PLAN.tar.gz) asked first, then the actions — delete machinery, delete records, wipe records, remove the installation — run in dependency order. Invoke only as /wss:retire; it has no flag and is never inferred from a phrase."
disableModelInvocation: true
disable-model-invocation: true
---

# Retiring a project

Adoption's reverse, run per project. Uninstalling the plugin removes the
skills and hooks and nothing else — it never touches a project — so the
manifest, the sweep cache and the records stay behind without this. The
scripts do the deleting; this skill is the sequence around them: the snapshot
question first, then exactly the boxes the user checked, in dependency order.

**Slash-invoked only, by design.** Like `/wss:lane-record-sync`, it has no
flag and must never fire from a phrase, a batch or another skill — "we should
clean this up" is not a request to delete a project's records. The user types
`/wss:retire` or nothing happens.

## What it is not

**Not the plugin uninstall itself.** That one is the harness's command and the
user's to run; the *checkout* removal is this skill's. Either way it is the
*last* step, not the first — run early it removes the skill mid-walkthrough.

**Not a writer.** Orchestrator, owns nothing —
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md). The scripts delete, the
export script archives; this skill decides, asks and reports. It does not
commit: the deletions land as a dirty tree, and what to do with that tree is
the user's call, stated in the close-out.

**Not for the suite's own repository — as a *project*.** `wss-retire-workflow.sh`
refuses a `--dir` resolving to the suite's tree outright; do not work around
it. `--suite` is a different act on a different target: it removes the
installation rather than retiring a project inside it, and it is the only
route that may touch that tree.

## 0. Resolve the scripts, and say which install form this is

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss-retire-workflow.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
```

Checkout or plugin — say which in one line, because the last step differs: a
plugin install has `claude plugin uninstall` for the user to run, a checkout
has its tracked files to delete. **The `||` above stops at the first form it
finds, so it answers "which scripts do I run", not "what is installed here".**
A machine can carry both — a clone in `~/.claude` and plugin installs in
projects — and this line will name only one. Step 4's `--suite` is what
enumerates them; do not promise the user a complete picture before it runs.

## 1. Dry run first, so the question is concrete

```bash
"$S"/wss-retire-workflow.sh --dir "$PWD"
```

Show the output. It lists what each tier would remove and refuses any path
that resolves outside the project — a refusal here is a manifest problem to
show the user, not something to work around.

## 2. One dialog: the snapshot question, then the checkboxes

One `AskUserQuestion` call, two questions — not a wizard. The snapshot
question is listed **first**, because deciding about the copy before facing
the deletions is what takes the fear out of the second question.

**Question 1 — "Take a full snapshot first?"** Single choice, recommended
**yes**: `WSS.RETIREMENT-PLAN.tar.gz`, every declared record *including the
tracked ones*, the lane files and the docs tree. Name the file in the option
itself.

**Question 2 — "What should go?"** Multi-select, all four:

- **Delete the machinery** — manifest, sweep cache, lane selector. All
  regenerable by `--wss-adopt`; losing them costs nothing.
- **Delete the records** — everything the dry run's records tier listed,
  line by line. The project's own knowledge.
- **Wipe the records** — `wss-reset-records.sh`: content blanked, structure
  and workflow kept. A fresh start, not an exit.
- **Remove the installation** — the suite's own files, whichever form step 0
  found, last. Say which form it means for *this* machine before the user
  checks it: a plugin install is one harness command, a checkout is every file
  `git ls-files` names under the config directory. It is the only box that
  reaches outside `$PWD`.

Whatever is checked, say now what **always survives**: the reference/README,
changelog and tooling files, a handoff at `CLAUDE.md`, the project's
`.claude/settings.json` (its `permissions.ask` entries guard the project, not
the suite), and the docs site. Nothing selected is an answer: stop, delete
nothing.

## 3. Act on the checked set, in dependency order, not pick order

The checked boxes are the authorization — for exactly those actions, in this
turn, nothing wider.

1. **Snapshot** (if question 1 said yes), before anything is deleted:

   ```bash
   "$S"/wss-export-records.sh --all -o WSS.RETIREMENT-PLAN.tar.gz
   ```

   Not the plain export — that skips what a clone would bring, and would be
   empty exactly when the records are tracked. Say both of its exits:
   re-adoption restores it (`--wss-adopt` imports before seeding, its §8b),
   and it is a plain tarball anyone can open by hand. Nothing in this skill
   deletes it — it is not a declared record — and it is a snapshot, not a
   record: keep it somewhere, do not commit it.

2. **Wipe** — but **skip it as redundant when "delete the records" is also
   checked**: blanking a file about to be deleted is motion, not caution.
   Say that it was skipped and why. It runs before the deletions for a
   mechanical reason: `wss-reset-records.sh` reads the manifest to find the
   records, and the machinery delete removes the manifest.

   ```bash
   "$S"/wss-reset-records.sh            # dry run, show it
   "$S"/wss-reset-records.sh --write
   ```

3. **Deletions**, one retire invocation for both tiers:
   `"$S"/wss-retire-workflow.sh --write --dir "$PWD"`, adding `--records`
   when the records box is checked. **Records checked without machinery**
   still runs with both flags only if the user meant that — the script has
   no records-only mode, so say so and confirm before treating it as both.

Show each script's own output rather than summarising it — the remove/keep
lines are the receipt.

## 4. Removing the installation runs last

Only where its box is checked. Last because it removes the skills and hooks
this walkthrough is running on — everything after it is plain conversation.

**Both forms can be present at once**, and step 0's `||` stops at the first,
so do not trust it to have found everything here. `--suite` looks for both
and reports both:

```bash
"$S"/wss-retire-workflow.sh --suite            # dry run, show it
"$S"/wss-retire-workflow.sh --suite --write
```

A **plugin** install it names but never deletes: ripping out the cache
directory leaves an entry in `installed_plugins.json` pointing at nothing.
The user runs the uninstall themselves, and **the command is per install, not
per suite** — `--suite` prints the exact one under each row it found. Relay
those verbatim rather than composing one.

**Never offer a bare `claude plugin uninstall wss`.** That command defaults to
`--scope user`. Typed inside a project that installed at project or local
scope, it removes the *user's* copy and leaves the project's running, so the
symptom the user came to fix survives and a second install they relied on is
gone. Scope lives only in `installed_plugins.json`; the cache path is keyed on
version, so one directory can back installs at two scopes.

**More than one row means asking, not assuming.** The same suite can be
installed at `user` scope and again at `project` or `local` scope in one or
more projects, and "uninstall the plugin" does not say which. Put the rows in
an `AskUserQuestion` — one option per install, labelled with its scope and
project path, multi-select because removing all of them is a normal answer —
before any command is run or handed over.

A **checkout** it removes by `git ls-files`, the only enumeration that cannot
guess wrong about which files under `~/.claude` are the suite's and which are
the user's. `CLAUDE.md` and `settings.json` are kept for the reason the
project tiers keep them — both outlive the suite. `.git` goes with it.

**The script cannot delete itself**, so it prints the leftovers under `REMOVE
THESE BY HAND` with the `rm -rf` line ready. Relay that verbatim: it is the
difference between a removal that finished and one the user believes
finished. Anything else that failed to unlink is listed the same way.

## 5. Close out

Briefly: which tier ran and what it removed, what survived and why, where
`WSS.RETIREMENT-PLAN.tar.gz` sits if one was made, that the deletions are
uncommitted and the tree is the user's to commit or restore, and the way back
in — `--wss-adopt`, importing the snapshot first so nothing is re-seeded
empty.