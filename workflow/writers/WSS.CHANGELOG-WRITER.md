# Writing the changelog

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md). Sole writer of `WSS.record.changelog`, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

What this file may and may not hold is
[`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md), the authority where the
two disagree.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.changelog` is the
file, falling back to `WSS.CHANGELOG.md` — say in one line that you used the
fallback. `WSS.record.releases` is where a version number comes from when a caller
does not supply one; a roadmap never carries one. A project that declares neither and has no `WSS.CHANGELOG.md`
has no changelog: say so and write nothing rather than creating one, because
which projects keep a changelog is a decision, not a default.

## Two changelogs, and only one of them is this procedure's

`WSS.record.changelog` is the **engineering log** — contract names, file paths, the
reasoning, and any marker the suite's own machinery reads. It is a record, so it
is blanked when the tree is published: it holds one project's history, and an
adopter reading an inherited one would believe it.

A project may also keep a **public changelog** at the conventional
`CHANGELOG.md`, written for people *using* it rather than building it. That file
is **not** a record, is not declared in the manifest, and is **not** blanked —
which is the entire point. It is the one that survives publication and the one
changelog tooling resolves by name.

**This procedure writes the record, and the public file only when a release asks
for it.** `--wss-release` invokes it once for each — it writes nothing itself.
Outside a release, the public file is not this procedure's to touch. The test for which entry goes
where: *if it only makes sense to someone editing the project, it is the
record's.* A public entry names the behaviour that changed and never the file
that changed.

Where a project keeps only one changelog, that one is the record and there is
nothing to reconcile. Do not create the public file to satisfy this section.

**No flag of its own**, on the same reasoning as `handoff-writer` and
`sweep-tracker`: nobody wants "write a changelog entry", they want a release cut
or a false claim corrected. This is the step inside those.

## Not the decision log

The nearest neighbour is `--wss-log`, and the two are easy to collapse into each
other because both are dated, append-only histories. They have different
readers, and that is the whole test:

| | `WSS.record.decisions` (`--wss-log`) | `WSS.record.changelog` (this procedure) |
|---|---|---|
| Answers | why a choice was made | what a user of the software notices |
| Read by | whoever maintains the project | whoever consumes it |
| Keyed to | a date | a version |

They come apart in both directions, which is why one file cannot serve both. A
refactor with no user-visible effect earns a decision entry and **no changelog
line**. A dependency bump users feel earns a changelog line and **no decision
entry**. Something can earn both — but never for the same reason, so neither
entry is a copy of the other.

The failure to watch for is a changelog entry that starts explaining *why*. That
is a decision entry in the wrong file, and it makes the changelog unscannable
for the one question it exists to answer.

## Form

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/): newest version first,
grouped **Added / Changed / Fixed / Removed**. Omit an empty group rather than
writing "none".

Each line describes the change **from outside** — what a user can now do, or
what stopped happening to them. Not the file that changed, not the mechanism.
If a line cannot be written that way, it is a strong sign the change belongs in
`WSS.record.decisions` instead and nowhere here.

## The unreleased status is a real state

`WSS.record.changelog` holds released versions, so an entry describing a version
that no tag resolves is a false claim, not a formatting problem. The contract
declares a [status field](../WSS.RECORD-CONTRACT.md#status-fields) for
exactly this: an entry may be marked unreleased in place, and doing so is
sanctioned rather than a breach of append-only.

**Never invent a tag boundary to make the claim true.** Recording plainly that a
version was never tagged is better than retro-tagging a guessed commit — the
first is honest and reversible, the second is permanent and probably wrong.
Which of the two happens is the user's call, and `--wss-release` is where it gets
asked.

## Scope: do what the caller asked for and stop

| Called by | Write |
|---|---|
| `--wss-release` | The entry for the version being cut, under the version and date the caller supplies |
| `--wss-check` | The one drift finding it dispatched — re-verified first — usually marking an entry unreleased |

**A caller with no row gets the `--wss-check` row**: write the findings you were
handed and stop. Say in one line that the caller was not listed, so the row can
be added rather than guessed at again.

**Re-verify a dispatched finding against `git tag -l` before changing anything** —
that is what settles a release-drift claim here. The rule is
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md#the-inspector-writes-nothing).

**Write what was asked and stop.** No version bump, no tag, no commit — a caller
that wanted a release would have run `--wss-release`.

## What this procedure does not do

- **It does not decide the version.** The number comes from the caller, which
  gets it from `WSS.record.releases` for a milestone or derives a patch. If a caller
  supplies none and the release list names none, ask rather than deriving one.
- **It does not tag, commit or push.** Tags are `--wss-release`'s and nothing else
  in this workflow writes one. The caller commits under the caller's grant; this
  skill confers nothing, so dispatched from `--wss-check` it writes the file and
  stops there.
- **It does not write any other record.** Reasoning goes to `WSS.record.decisions`
  via `--wss-log`; a milestone's completion is `--wss-plan`'s mark.
