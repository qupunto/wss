# Changelog

Release notes for **Workflow Secretary Suite** — what changed for people *using*
the suite, in the terms they use it in.

The suite's own engineering log, with contract names, file paths and the
reasoning behind each change, is `WSS.CHANGELOG.md`. This file is deliberately
free of that: if an entry here only makes sense to someone editing the suite, it
belongs in the other one.

## 0.10.0 — 2026-08-10

**The suite is now called `wss`, and an existing install has to be replaced
rather than updated.** The plugin, its marketplace and its repository all
changed name at once, so the entry recording that the plugin is enabled points
at something that no longer resolves. Uninstall the old one and install again:

```bash
claude plugin marketplace add qupunto/wss --scope project
claude plugin install wss --scope project
```

If you installed at project scope, the old name is also written into your
project's `.claude/settings.json` — remove the stale `enabledPlugins` and
`extraKnownMarketplaces` entries when you reinstall, or you will be carrying a
key that points at nothing. Nothing else in your project needs changing: your
manifest, your records and the flags you type are untouched.

**The commands got shorter to type.** Installed as a plugin, the skills are
reached as `/wss:start`, `/wss:plan`, `/wss:docs` — the suite's name supplies the
namespace, so it no longer appears twice. **The flags are exactly as they were:**
`--wss-start` is still `--wss-start`, in every form, so anything you have written
down keeps working.

**Removing the suite now tells you the right command for your install.**
Uninstalling a plugin defaults to your user-level copy, which is the wrong thing
to remove if you installed it into a project — quietly, with no error, leaving
the copy you meant to remove in place. Retiring now reads what is actually
installed and prints the exact command for each one, and says so plainly when it
finds leftovers it cannot identify instead of guessing.

**A safeguard on what gets published was letting private paths through.** The
check that stops a home directory or a private repository name reaching the
public copy was fooled by the new, shorter name. Found by testing the check
rather than by reading it, and fixed.

## 0.9.2 — 2026-08-09

**A project that doesn't use worktree lanes stops paying for them.** The lane
machinery — landing a lane's branch, syncing a worktree forward, the lane
selector — moved out of the two skills that carried it, and is now read only
when your project actually runs lanes: when a lane selector is present, or your
manifest names lanes. Sessions in a single-checkout project no longer load that
material and no longer get lane instructions injected. Nothing changes for a
project that does run lanes, beyond one extra read.

**Turning lanes off is a command now, and it never removes a record.**
`wss-remove-lanes.sh` drops the lane selector and the named-lane declarations
while keeping the collision settings a single checkout still needs, and refuses
to touch a lane record that still holds content unless you say so explicitly. It
shows you the change before making it, and refuses to run against a manifest you
have not committed, so git can always undo it.

**Cutting a release costs your session less.** `--wss-release` now hands the
reading — the release list, the changelog, the backlog, the whole range since
the last tag — to a dedicated agent whose context is discarded when it returns,
so only the proposed version, the entry and anything that looks wrong come back.
The confirmation, the tagging and the pushing stay exactly where they were.

**Sessions spend their context on the work.** The suite's guidance now tells a
session to bound what it reads, edit a file rather than rewrite it, and send
read-heavy checks out to a subagent instead of doing them inline. Measured
rather than assumed: what a session says is a few percent of its context, and
what its tools return is nearly all of it.

**Documentation corrections.** The overview page drew five suite scripts where
six exist, the tooling annex was a row short of its source, and both described a
flag's injected block as depending only on how you phrase the flag — its content
depends on your project too.

## 0.9.1 — 2026-08-09

**Moving a project onto the newest conventions is one command now.**
`--wss-update` updates your suite install, then works out which conventions
your project actually carries and migrates it forward. It detects rather than
assumes, so a tree adopted months ago and one adopted last week both end up
current — and `--wss-adopt` routes you there when it finds a project that has
already been adopted once.

**A project adopted before the renames stops looking unadopted.** The health
check, the export and the retire script all used to report "nothing to find"
over a legacy project with its records sitting on disk. They now recognise it
and tell you what it needs. Silence was the worse failure, because it looked
exactly like a clean bill of health.

**Lane synchronisation finishes what it starts.** It brings each lane's
committed work in before it reads anything — so it reconciles the current
records rather than last week's — sends the reconciled result back out to every
lane once the run is done, and then closes the session out instead of leaving
what it wrote uncommitted for you to notice later. It asks before committing,
and it never pushes.

**Wrapping up inside a lane worktree reads the current state first.** A report
written from a stale base described a lane that no longer existed, and recorded
obligations as outstanding that another lane had already executed.

**Skills you asked to stay quiet stay quiet.** The editor changed which spelling
of the hide-this setting it honours; the affected skills now carry both, so the
next reversal cannot silently un-hide them.

**Releases choose their own version number by rule.** Major only when you ask
for it, in words. Minor when a milestone you set *in advance* is completed — or
when the release carries work your own project must apply to keep working,
whether or not anyone planned it. Everything else is a patch, and the unit is a
release rather than a pull request.

**The suite no longer pins a model.** Sessions use whichever one you are
running.

**Corrections you would otherwise have tripped over.** The flag list on the
landing page was missing `--wss-update`. The lane-synchronisation page described
a shorter process than the one that runs. And one page said a health check
*fails* when two copies of a permission disagree — it warns, which means a
local run still ends in "all checks passed" and only continuous integration
treats it as fatal.

## 0.9.0 — 2026-08-08

**Your handoff gets read even without a manifest.** If your project keeps a
`WSS.HANDOFF.md` but never mapped it — or was never adopted at all — sessions
now start with it injected, exactly as a declared mapping always did.
Previously it was silently unread, and nothing told you.

**`/wss:toggle` controls what each skill costs at session start.** It shows
every skill's current load level, changes it safely — refusing a level that
would break a skill other skills depend on, and warning when a change would
silence one of the `--wss-*` flags — and can only be invoked by name, never by
a phrase.

**Adoption asks about your archive first.** Moving machines? `--wss-adopt` now
asks up front whether there is an export to restore, before it creates
anything, so restored records are never overwritten by empty ones.

**Ask for a diagram inline.** `--wss-diagram` takes the diagram you just asked
about and lands it in your documentation site's annex, correctly rendered for
your site.

**Publishing and resets got sturdier.** The publication gates scan binary
files for private content the same as text, state how many tests the
published copy runs compared to the source, and a records reset refuses a
file it cannot write instead of stopping half-done.

**Projects running their tests on a self-hosted runner can say so** — an
optional `WSS.localCI` manifest key names your runbook, and the health check
recognizes it.

## 0.8.0 — 2026-08-08

**Every file the suite writes now announces itself.** Suite files carry a
`wss-` or `WSS.` prefix, so you can tell at a glance which files in your tree
are yours and which are the suite's. Project configuration nests under one
`WSS` root in the manifest; the health check fails an old flat manifest
loudly instead of misreading it silently.

**There is now a guided way out: `/wss:retire`.** One dialog asks first
whether you want a full snapshot of your records — everything, including what
git already tracks and your docs — then which things should go: the suite's
own machinery, your records, a records wipe, or the plugin itself. The
snapshot can be restored if you ever adopt again, and nothing deletes it.
Retirement can only be invoked by name, never triggered by a phrase in a
sentence.

**A settled fact about what your project is can go straight to your README**
with `--wss-reference` — the counterpart to recording how it behaves.

**Documentation sites can carry workflow pages** — one end-to-end flow per
page, a diagram plus the ordered stages, each stage pointing at the rule and
the code it rides on.

**Audit history is now a log plus an index**, so a list of every independent
audit pass exists in one place.

## 0.7.0 — 2026-08-07

**Roadmaps can now be per-area, and releases are tracked separately.** If your
project has an interface side and a service side that plan in different terms,
each can keep its own roadmap. Milestones and their version numbers moved to a
release list that never splits, so there is still exactly one place that says
what ships next.

**Parallel work sessions can hand each other tasks.** A session working on one
area can file work to another area's queue instead of editing records that
belong to it. The receiving session picks the work up when it next starts.

**Backlog items can be marked critical**, and the marker survives even when the
backlog lives in an issue tracker rather than a file.

## 0.6.0 — 2026-08-06

**Contradictions between areas get a queue of their own**, so a disagreement
found while reconciling two areas is raised for a ruling instead of being fixed
silently by whichever session noticed it.

## 0.5.0 — 2026-08-04

**Work split across several checkouts stays in sync at both ends** — picking up
work syncs forward, and finishing it lands cleanly.

## 0.4.0 — 2026-08-04

**Fewer accidental invocations.** Several commands used to trigger on ordinary
phrases: saying "done" could commit and push, "ship it" could cut a release, and
"where are we" could kick off an expensive review that rewrote your backlog.
They now judge the shape of a request rather than a single word, and the ones
that can push name the phrases they refuse.

**A drawing command was removed** — it cost every session and added nothing the
assistant could not already do.

## 0.3.0 — 2026-08-03

**Installable as a plugin**, so you can use the skills in your own projects
without cloning anything:

```bash
claude plugin marketplace add qupunto/workflow-secretary-suite
claude plugin install workflow-secretary-suite
```

**Every command got a short flag** (`--wss-check`, `--wss-start`, and so on), and
each command's name matches the flag that fires it.

## 0.2.0 — 2026-08-03

**Adopting an existing project maps what it already has** rather than demanding
a fixed layout — your backlog, roadmap and docs keep their current names and
locations.

**Your backlog does not have to be a file.** A project already tracking work in
an issue tracker can point the suite at that instead.

## 0.1.0 — 2026-08-01

First release. A set of skills that keep a project's backlog, decision log,
roadmap, documentation and tooling notes matching what the code actually does —
a secretary to coding, not the coder. Anything needing knowledge of your stack
is deliberately out of scope.
