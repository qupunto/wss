---
name: release
description: "Cut a release — confirm the version, have the changelog written, tag, push. Needs a completed milestone in `WSS.record.releases`, or a release list that has ended milestones. SHORTHAND: `--wss-release`. Always asks before pushing. Also on \"cut a release\", \"tag this version\". TAGS AND PUSHES — not to be inferred from \"ship it\", which is approval, not a request to publish."
---

# Cutting a release

**This skill writes nothing.** It is the only one that may *decide* to tag, but
the tag itself is written by `git-writer`, the changelog by `changelog-writer`,
and the milestone mark by `--wss-plan`. Who owns what is
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md).

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.releases`,
`WSS.record.changelog`, `WSS.record.stocktake`, `WSS.branch.publish`, and `WSS.agents.release` —
the agent that prepares the material. Without a manifest, fall back to
`WSS.CHANGELOG.md`, `WSS.RELEASES.md` and the current branch, and say so.

**`WSS.record.releases` is the only planning record this skill reads, and that is
load-bearing.** `WSS.record.roadmap` splits by lane and holds goals; it carries no
version and no completion mark, so there is nothing in it for a release to act
on — [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md) holds that rule.
A project may run any number of lane roadmaps and still have exactly one release
checkpoint. Reading a roadmap here would undo that.

Where a `.claude/WSS.LANE` selector names a lane, `WSS.lanes.named.<lane>.records.todo`
overrides `WSS.record.todo` — [`WSS.LANE-CONTRACT.md`](../../wss/workflow/WSS.LANE-CONTRACT.md)'s
resolution rule; the changelog and the release list never split.

## The `--wss-release` shorthand

Invoking without confirmation is safe: everything up to the push is local and
reversible, and the push has its own gate below. Where a flag counts is
[`README.md`](../../README.md); what it authorizes is the block
`wss-shorthand-flags.sh` injects and
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md)'s matrix.

## 1. The precondition is a mark, not a word

**While a project still has milestones ahead of it, a release requires one marked
completed in `WSS.record.releases`.** That is `--wss-plan`'s to write: checkable by
reading one file, and still true after a `/clear` — which a spoken approval is
not. **One file, whatever the project's lane count** — a mark exists nowhere
else, so there is never a second place to look or a second answer to reconcile.

Four cases:

- **Marked completed, no tag for it** — that is the release. Go.
- **Looks complete but is not marked** — do not tag it. Hand to `--wss-plan`, which
  asks the user and marks it, then come back. Marking it here would be writing
  another skill's record, and it skips the disqualifier checks `--wss-plan` runs
  (an open blocking decision; unremediated high-severity audit findings).
- **A patch on an already-tagged version** (§4) — no milestone needed.
- **The release list has declared an end to milestones** — see below.

Never infer the milestone from recent commits, and never from a roadmap — a goal
being met is not a milestone being complete, and the roadmap has no way to say
otherwise.

### A project that has run out of milestones

The release list may say, in its own words, that the planned work is done and
what follows is maintenance on evidence rather than a next version. Once it does,
**every milestone in it is both completed and already tagged, permanently**, so
"marked completed, no tag for it" can never be true again and the rule above
would forbid every future release.

That is not a reason to stop. It is a different gate:

- **The release list must say so itself.** A section declaring the end of
  milestones, written by `--wss-plan`. Not an empty next-up list, not an inference
  from the last milestone being tagged, and **not an empty roadmap** — those are
  the ordinary state of a project between blocks, and treating them as this case
  is how the mark gets skipped while milestones are still owed. Goals keep being
  set after milestones end, so a busy roadmap is no evidence either way.
- **The evidence goes in the release, not in the reply.** What is being shipped
  and why now — an inbox entry, a defect, an owed publish, accumulated fixes to
  shipped files. `WSS.record.todo` is where an owed outward act is recorded, so it is
  the thing to read.
- **§2 and §5 are unchanged and matter more here**, because no milestone review
  happened. The full health check and the explicit in-turn OK are the whole gate.
- **It is a patch, unless this version owes a `- migrate:` line.** No milestone
  means minor's first trigger cannot fire, so §4's default applies — and its
  compatibility floor is the one thing that still promotes a maintenance
  release to minor. Ask whether an adopted tree must change, per §4; a
  migration shipping as a patch is the failure that floor exists to prevent.

**Say which case this is, every time.** A maintenance release that does not name
itself as one is indistinguishable from a milestone release whose precondition
was skipped, and nothing downstream can tell them apart afterwards.

## 2. Check that everything is in order before releasing on top of it

**Invoke `--wss-full-check`.** A tag is a claim that the tree it names is sound, and
this is the last point at which that claim is cheap to test. It runs the
project's mechanical checks, re-reads every record, docs page and tooling file at
full scope, and dispatches what it finds to the owner of each file.

Release drift is one of the dimensions it covers: what `WSS.record.releases` and
`WSS.record.changelog` claim shipped, against what `git tag` actually resolves,
locally and on the remote. Do not reimplement that comparison here — a second
copy of a check is a second thing to keep true.

`--wss-full-check` rather than `--wss-check`, deliberately — the incremental
sweep's `covered` trust is exactly what a release should not extend, and it
subsumes `--wss-check` anyway, so invoking both pays twice for the same answers.

It does
spend the session's one consented test run where the project gates its suite
behind `WSS.commands.testConsentEnv`; that is the right place to spend it.

**Drift is a release decision, not cleanup.** The usual shape is a document
describing a shipped version that no tag resolves, and there are two honest
outcomes — tag the commit that milestone completed at, or record the work as
unreleased. **Ask which.** Retro-tagging a guessed boundary is worse than
recording plainly that a version was never tagged. Whichever the user picks,
the write goes through the file's owner.

**A health check that comes back red stops the release.** Not because a tag
cannot be cut on top of a known failure, but because the decision to do so is the
user's and needs to be made in words rather than by omission. Report what failed
and ask.

## 3. Prepare — delegate this

Hand the manifest's `WSS.agents.release` the milestone being released and have it
return: the version bump it proposes and why, the changelog entry text, and any
drift it found. It reads `WSS.record.releases`, `WSS.record.changelog`, `WSS.record.todo`,
`WSS.record.stocktake` and the git history — **plus the roadmaps the milestone's entry
cites**, which is where the user-visible substance of the release actually is,
and under lanes is several files rather than one. Letting it do that in its own
context keeps several thousand tokens of history out of yours.

**In the maintenance case there is no milestone to hand over** — say so rather
than naming one, and the roadmap read has no entry to resolve, so the substance
comes from `WSS.record.todo` and the git range since the last tag, which is the
evidence §1 already requires.

Where a project declares no release agent, do the reading here and say that you
did — it costs context, and the user should know why this turn was expensive.

Sanity-check what comes back rather than pasting it through — the version
number and the user-visible framing are the two things worth your own eyes.

## 4. Version

Semantic versioning. Below `1.0.0` the leading zero is doing real work:
**deployed** is not **stable**, and a pre-1.0 project may still change its data
model or API incompatibly.

**Decide the tier from the triggers below, never from how big the range feels.**
A diff's size is not a compatibility claim. Momentum is the failure mode here:
absent a rule, a maintenance release drifts into a minor bump because the last
one took one, and the field that is supposed to tell an adopter something stops
telling them anything.

| Tier | Fires when |
|---|---|
| **major** | the user asks for it, in words, in this turn |
| **minor** | a milestone **set beforehand** in `WSS.record.releases` is marked completed — **or** *this version's own entry* in `WSS.record.releases` carries a `- migrate:` line |
| **patch** | everything else. This is the default, not a category |

**Major never fires by inference** — not from a large range, however
significant it feels. `1.0.0` is a claim about *stability* rather than about
size — that the data model and the interface will not change incompatibly
without another major — and only the user can make it.

**Minor's first trigger is a mark, and *beforehand* is the load-bearing word.**
The milestone must have existed before the work closed it, which is what stops
one being written after the fact to justify a bigger number. `WSS.record.releases`
already names the version that milestone intended to ship as — **confirm that
number rather than deriving a new one**, and if you disagree with it, say so
and ask.

**Minor's second trigger is a compatibility floor, and it overrides the
absence of a milestone.** A `- migrate:` line is work an *adopted* tree must
apply, per
[`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md)'s releases row.
Where this version owes one, the release is a compatibility event whether or
not anyone planned it, and pre-1.0 the minor field is the channel that says so.
Ask it of the work, not of the diff: does an adopted tree have to change to
keep working? Do not assume a maintenance release owes nothing: a version with
no milestone behind it can still rename a key every adopted tree carries.

**And read the entry, never the diff.** `git log -S'- migrate:'` over the range
answers a different question. Those lines are written *retroactively* — a
version's entry can gain them long after its tag, so that `update` can mend
a tree stamped before it — which means a range can add a pile of them that all
belong to versions already shipped. That is documentation catching up with its
reader, not a migration going out now. The floor fires on **this version's own
entry** owing one.

**Patch is what a release is unless one of the two above fires.** Stating it as
the default rather than as "a fix or small adjustment" is deliberate: work
enters a maintenance project on *evidence* — an inbox entry, a `--wss-report`
issue, a defect a check surfaced — and none of that need touch a roadmap or a
milestone. A tier defined by what it is not can never leave a release
untierable.

**The unit is a release, not a pull request.** Whatever has accumulated since
the last tag is bundled into one patch. A change split across two PRs for
review reasons is one thing shipping, and burning two version numbers on it
tells an adopter about this project's branch hygiene rather than about their
upgrade.

Unsure? Ask. A wrong version number is permanent in a way a wrong commit
message is not.

**Where the tree is a plugin — `.claude-plugin/plugin.json` exists — bump its
`version` to the confirmed number in the same change as the changelog entry,
before the tag is cut.** The plugin cache path keys on that field
(`plugins/cache/<marketplace>/<plugin>/<version>/`), so two vintages published
under one version overwrite one directory instead of sitting side by side —
and the Publish action assembles from the tagged commit, so a bump landing
after the tag ships a tree claiming the previous version. `wss-doctor.sh` warns
when the manifest trails the newest tag.

## 5. Have the entry written, commit, then stop

**Invoke `changelog-writer`** with the version, the date and the material from
§3. It owns `WSS.record.changelog`; do not write that file here even when the entry
is one line and the agent already drafted it. Then have `git-writer` commit it —
the history is its record, and this skill does not write one by hand.

**A resumed release re-checks the entry, not just the tag.** Where an entry for
the confirmed version already exists, compare the commit it was written at
against the range the tag will contain. If the range has grown since, re-invoke
`changelog-writer` before tagging: an entry describes a range, and a tag placed
past the commits it summarised ships work no entry mentions.

**Then the public changelog, if the project keeps one.** Where a conventional
`CHANGELOG.md` exists *and is not what `WSS.record.changelog` points at*, it is the
user-facing log and it needs its own entry for this version. **It goes through
`changelog-writer` too**, not written here: the file is not a record, but this
skill writes nothing at all ([`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#the-matrix)),
and the writer is the one place both entries' split is stated.

It is a **different entry, not a copy**. `WSS.record.changelog` says which contract
moved and why; this one says what someone using the project would notice, in
their terms. Anything that only parses for a person editing the project — a file
path, a manifest key, a writer's name — is the tell that the sentence belongs in
the record instead. Ship no entry at all rather than a rephrased internal one:
an empty public changelog is honest, and a public log full of internals is what
this split exists to prevent.

**Both files are one commit**, so a release never lands with the two disagreeing
about what shipped.

`WSS.record.releases` already marks the milestone completed — that was the
precondition, and it is `--wss-plan`'s file. Do not edit it here either, and do
not touch a roadmap: a goal met is that record's business, not a release's.

Then **stop and show the user exactly what is about to go out**: the commits,
the tag name, and the branch. Wait for an explicit OK **in that turn** — not one
inherited from earlier in the conversation, and never implied by the milestone
mark. Completing a milestone and publishing a tag are two decisions.

Before showing it, run `git log origin/<branch>..<branch>` and say plainly if
it contains commits this session did not make. A push publishes a whole ref,
so another session's work rides along.

## 6. Tag and push, once confirmed

**Hand the tag name, the message and the branch to `git-writer`**, telling it
the OK was given in this turn — it will not tag otherwise, and it holds the
rules against forcing, amending and skipping hooks. This skill obtains the
confirmation; that skill performs the act.

## 7. Close out

Say what shipped, at which tag, and what the next milestone is per
`WSS.record.releases`. If the release surfaced anything unresolved — drift you
corrected, a milestone that wasn't as complete as its mark claimed — say so
here.

## What this skill does not do

Who owns what is [`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md).

- **It does not mark a milestone completed.** That mark is this skill's
  precondition, not its output.
- **It does not write the changelog entry.** It supplies the version and the
  material to that file's owner and never edits the file.
- **It does not commit, tag or push by hand.** Those go through the history's
  owner, which will not tag or push without being told the confirmation was
  given in that turn.
- **It does not prepare its own material** where the project declares
  `WSS.agents.release`.
