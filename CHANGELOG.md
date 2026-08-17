# Changelog

Release notes for **Workflow Secretary Suite** — what changed for people *using*
the suite, in the terms they use it in.

The suite's own engineering log, with contract names, file paths and the
reasoning behind each change, is `WSS.CHANGELOG.md`. This file is deliberately
free of that: if an entry here only makes sense to someone editing the suite, it
belongs in the other one.

## 0.11.1 — 2026-08-17

**If you were waiting on 0.11.0, this is the one to take.** 0.11.0 was tagged but
never actually reached you: the packaging step that builds the public copy
refused it, correctly, and stopped before publishing anything. Everything 0.11.0
described — including the three changes to your project that updating applies —
arrives here instead. Read the 0.11.0 notes below for what those are; nothing in
them changed.

**Nothing in your project needs to change for this release itself.**

## 0.11.0 — 2026-08-17

**This release changes three things inside your project, and updating does all
three for you.** They are applied in the order the releases went out, each one
checked against your tree first — so a mend that is already done is skipped, and
a re-run resumes rather than repeats. You see the full list of what will be
touched before anything is touched.

- **The suite now has to be told which of the files it keeps for you are added
  to and which are rewritten in place.** That is what lets it refuse a change
  that quietly deletes something you wrote months ago. The list is written in
  for you.
- **If you kept your own copies of the suite's rule files inside your project,
  they move one folder deeper.** Most projects never made those copies, and for
  those this does nothing at all.
- **The safety hook installed in your checkout points at a file that has moved,
  and it is re-installed.** This one is worth knowing about: that hook lives
  outside version control, so pulling never fixes it, and nothing in your
  project's checks would have told you. **If you or anyone else has a second
  clone of the project, the update needs running there too** — each clone has
  its own.

**Your written history can no longer be quietly edited.** Deleting a line from
inside an entry you already recorded is now refused outright, rather than being
something you had to notice in a diff. Three things are still allowed, because
each is genuinely not a rewrite: the instructions at the top of a file, an
entry's current status, and the entry you are still writing. Amending anything
else means adding a new entry that says so — which is what you would have wanted
anyway.

**Sessions now default to the high effort level.** This is a change to a setting
that ships with the suite, so it will apply to you unless your own settings say
otherwise, and it costs more per session than the previous default. If you would
rather it did not, set it back — it is your file, and nothing here will
overwrite that choice again.

**One flag you may have typed no longer exists.** `--wss-tools` was doing two
jobs that had nothing to do with each other: tidying up the tooling, and writing
down what the tooling now is. They are `--wss-tidy` and `--wss-catalog` now. The
old flag was removed rather than quietly redirected, so typing it does nothing
rather than doing half of what you meant — and tidying now writes the catalogue
itself when it finishes, so the description can no longer be left describing the
tree from before.

**Your parked ideas are two lists instead of one.** One holds what is genuinely
queued to be done; the other holds what a session noticed on its way to
something else and nobody has committed to. Nothing moves between them without
you saying so, and starting a session never picks work from the second one. The
practical effect is that "how much is outstanding" stops counting things nobody
ever promised to do.

**A parked idea gets closed when you record the answer to it.** Until now the
answer went in, the idea stayed open, and the next session cheerfully described
the same thing a second time. That was the actual cause of the duplicates, and
it is fixed at the cause rather than by adding a duplicate-detector.

**Work handed to a helper now runs at a decided level rather than a felt one.**
There is a single table that says which kind of work runs where, on what, and at
what effort, keyed on things anyone can check — whether the task writes files,
whether someone else depends on its answer, whether the instructions already say
what to read. Nothing chooses its own level any more, and a check refuses a
helper whose settings disagree with the table. **A vaguely-briefed job is now
priced as an expensive one instead of being silently run cheap and badly**, which
means a well-briefed one gets to be genuinely cheap.

**The heaviest commands cost you less to run.** Setting up a project, taking
stock, syncing parallel work streams, and the documentation commands were each
one enormous file that loaded whole; each is now a short router that pulls in
only the step it has reached. Taking stock came in well under half its previous
size. Starting a session gets its mechanical facts from a single call instead of
reading around for them.

**Several things that used to fail quietly now say so.** A settings file that
exists but is broken used to read as though you had configured nothing — it now
tells you it could not be read. Running the checks outside a repository used to
report a messy working tree instead of no repository. Scaffolding a
documentation site ignored the languages you had declared and will now stop
rather than build you the wrong thing. And a batch of internal checks were
reporting all-clear over files they had never opened; they now read them.

**The suite's own files live under one folder.** Nothing you type changes, and
nothing you wrote moves — but if you have ever gone looking inside the
installation, that is where things went.

## 0.10.3 — 2026-08-11

**This release is `0.10.2` plus one fix — `0.10.2` never reached you.** Its
publication stopped at the final safety check and nothing was ever pushed, so
everything listed under it below arrives here instead. If you are updating, this
is the one to take; there is no `0.10.2` to have missed.

**What stopped it.** The step that prepares this repository for publication
rewrites the suite's own commands into their installed form. It mistook a piece
of pattern-matching syntax for one of those commands and rewrote it, which broke
the suite's health check inside the copy being published — while leaving the
original untouched. The check then reported a problem that did not exist, and
the release refused to go out. That refusal was the system working: the copy was
never pushed anywhere.

Fixed, and deliberately fixed narrowly. The obvious broader fix would have
introduced the same kind of mistake in written documentation instead, so the
wider repair is recorded as outstanding work rather than rushed into a patch.

**Nothing you have written, declared or typed is affected**, and nothing needs
doing beyond an ordinary update.

## 0.10.2 — 2026-08-11

**You can now tell the suite where your documentation site is.** Until now the
checks that read your docs assumed one particular layout — a folder called
`docs`, one language, one dev-server command — and quietly did the wrong thing
for anyone whose site was arranged differently. You can now say where the site
lives, which languages it has and which is the main one, and how to start its
dev server. None of it is required: if you say nothing, the suite looks for
`docs`, `doc`, `documentation` and `website` in that order, treats the site as
single-language, and skips the steps it cannot run instead of guessing. Setup
will offer to write these for you.

**Scaffolding a docs site no longer needs to be told the folder.** It works out
where your site goes and tells you where it settled.

**Two more standing checks, and one that can argue in your favour.** The
periodic sweeps gain a look for writing that is true today but built to go stale
— a second copy of something nothing keeps in step, a claim no reader can test —
and a look for parts of the suite paying more of your context than their job
needs. A third check asks whether a command will actually be reached when you
describe your problem in your own words. It is the only one that can conclude a
description is too short: everything else pushes one way, and nothing was
measuring whether what survived still worked.

**The rules are easier to find.** Working across several worktrees, and the
convention for what the suite's own files are called, each have their own page
now instead of being spread across three. Nothing about either rule changed —
only where you read it.

**A settings file no longer arrives with our model choice in it.** The suite
ships a `settings.json`, and a machine-local model preference had been committed
into it — installing the suite would have overridden whichever model you had
chosen. It is gone, and that kind of preference now lives in a file that never
ships.

**Fixes.** A translation folder that was declared but empty used to pass the
translation check instead of failing it. A disabled command could still swallow
another one you had typed alongside it. Several internal notes and counts that
had gone out of date were corrected or removed.

**No action needed.** Nothing you have declared, written or typed changes
meaning in this release. If you are on `0.10.0` or later you are current after
an ordinary update; if you are on anything older, `0.10.0`'s note below still
applies and you need to reinstall rather than update.

## 0.10.1 — 2026-08-10

**You can now ask a project to describe itself.** `wss-tree-survey.sh`, run by
hand from inside a project that uses the suite, prints what that project has
actually declared — where its records live, which flags are wired to what, what
is configured and what is not. Read-only: it changes nothing and writes nothing.
Useful when you have inherited a project, or when you have several and no longer
remember which is set up how. What it prints names your own paths and branches,
so treat the output as private.

**Work split into lanes no longer needs agents configured to get the benefit.**
If your project declares no specialist agents — which is the normal case, and
what setup recommends — a lane used to be worked through in the main session.
Now it goes out to a subagent regardless, which leaves the main session's room
for the work that needs it.

**And you can now ask that of every project at once.** `wss-survey-all.sh` walks
the roots you give it, surveys every adopted tree underneath, and rolls the
answers up into one mapping of which surfaces have a project that could exercise
them. It groups worktrees of the same project together instead of counting them
as separate ones. The same privacy warning applies and applies harder: the
output names every project on the machine, with paths, branches and remotes, so
keep it local and never route it upstream.

**Ending a session now tells you how stale each recurring check has become.**
The wrap's closing report gains one line per periodic sweep: how many commits
have landed since it last covered your tree. Until now that number was visible
only if you went looking, or once it crossed a threshold and the session nudge
fired — which on a fast-moving repository can fail to happen for a long time. It
is a report and nothing else: no figure blocks a wrap or turns into a
recommendation.

**More of the commands that write your records now clean up after themselves.**
Planning, logging a decision, recording an adopted capability, and writing a
behaviour or reference note all now look for the sentences elsewhere in that
record their own write just made false — a count that moved, a "not yet built",
an item still listed as pending — and fix them in the same edit. Previously only
some of them did, so a record could contradict itself the moment it was updated.

**The tooling catalog says when your configured file list leaves things out.**
If the list of files the catalog is built from misses a directory the catalog
claims to cover, you are now told which files fall outside, instead of getting a
sweep that quietly covers less than it reports.

**No action needed.** Nothing you have declared, written or typed changes
meaning in this release. If you are on `0.10.0` you are current after an
ordinary update; if you are on anything older, `0.10.0`'s note below still
applies and you need to reinstall rather than update.

## 0.10.0 — 2026-08-10

**The suite is now called `wss`, and an existing install has to be replaced
rather than updated.** The plugin, its marketplace and its repository all
changed name at once, and the entry recording that the plugin is enabled still
names the old pair. **It keeps working, which is the trap** — the old repository
address redirects, so the stale entry goes on resolving, updates go on arriving,
and the suite goes on running under its former name. Nothing errors, so a
working install is not evidence you are on the current one. Uninstall the old
one and install again:

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
