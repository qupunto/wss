# `WSS.record.todo` in GitHub Issues

**A backlog provider.** Where a project declares one, `WSS.record.todo` is not a
file — it is a set of open issues, and `--wss-todo` writes there instead.

Declared in `.claude/WSS.WORKFLOW.json`:

```json
"record": {
  "todo": { "provider": "github-issues", "repo": "owner/name", "label": "backlog" }
}
```

`repo` is required. `label` is optional; without it the backlog is **every open
issue in the repository**, which is usually wrong for a repo that also takes bug
reports from users — declare a label unless you mean that.

## Why this exists, and what it does not change

A team that already lives in Issues cannot adopt a workflow whose backlog is a
markdown file: they would be maintaining two, and the second one loses. This
makes the medium a project decision rather than a condition of adoption.

**Nothing else moves.** `WSS.record.decisions` and `WSS.record.openDecisions` stay files
even here, and that is deliberate — they are prose read months later by someone
reconstructing why, and an issue thread is a conversation rather than a record.
The split `--wss-todo` already enforces is the same one: **the task goes to the
provider, the reasoning goes to the decision log**, and the issue carries a link
to it rather than the argument itself.

**One writer still.** `record` is the sole writer of issues carrying the
configured label. An issue without that label is somebody else's — a user bug
report, a discussion — and this workflow does not touch it.

## The mapping

| Markdown backlog | Here |
|---|---|
| an unchecked `- [ ]` item | an **open** issue with the label |
| the bold short name | the issue **title** |
| the technical detail beneath it | the issue **body** |
| deleting an item once it is done | **closing** the issue |
| `[blocked → what is undecided]` | the same marker, first line of the body |
| a `## Later` section, or any deferral by placement | `[later → why]`, first line of the body, same as blocked |
| `[critical → why]` | the same marker, first line of the body |

**Two things a file backlog carries in its shape do not survive the move, and
both are load-bearing for `--wss-start`.**

**Order is not priority here.** A markdown backlog is severity- and
dependency-ordered top to bottom, and that ordering *is* data. `gh issue list`
returns newest first, which is not merely different — it is close to reversed,
since the oldest and most-deferred items sink to the bottom while whatever was
filed a minute ago leads. **Never read list position as rank.** Judge each item
on its content, and where genuine dependencies exist, say so in the body rather
than hoping for it to be inferred from sequence.

**Deferral has no placement to express it**, which is why the marker row above
exists. In a file, moving an item under `## Later` is how a decision not to build
it yet is recorded, and `--wss-start` refuses to pick from there. An issue has no
such position, so a deliberately-parked item is otherwise indistinguishable from
an active one — and the first thing `--wss-start` would reach for is the most
recently filed, which under `--wss-todo` is precisely the thing that was *just
deferred*. Mark it, or the deferral silently reverses itself.

**Closing is the delete.** Do not comment "done" and leave it open, and do not
edit the title to say DONE — the markdown rule is that a backlog is
forward-looking and a finished item leaves it, and a closed issue is how that
reads here. What was built is recorded in `WSS.record.decisions` and
`WSS.record.changelog`, exactly as with a file.

## Reading it

```bash
gh issue list --repo "$REPO" ${LABEL:+--label "$LABEL"} --state open \
  --limit 200 --json number,title,body,url,labels
```

**`--limit` is not optional.** `gh` defaults to 30 and says nothing about the
rest, so a backlog of 45 silently becomes 30 — the failure class this whole
workflow is built to refuse. Read a count first and say so if it is at the
ceiling.

### After writing, in the same session, do not read with `--label`

`--label` is served from GitHub's search index, which lags writes by seconds to
tens of seconds: an issue closed a moment earlier is still returned as open,
and an issue *created* a moment earlier is not returned at all. Re-take the
measurement by creating an issue and immediately running both commands below.

This is not a cosmetic lag. It defeats the two rules on this page that matter
most, and it defeats them silently:

- the **dedupe check** before creating sees zero copies of the item it just
  filed, so a skill that re-runs opens the second copy the rule forbids;
- a **count read after closing** — which is exactly what `--wss-wrap` does, landing
  work and then reporting where the project stands — over-reports by however
  many items just left the backlog.

So once this session has created or closed anything, filter client-side instead.
The plain issues API is immediately consistent:

```bash
gh issue list --repo "$REPO" --state open --limit 500 --json number,title,body,url,labels \
  | jq --arg L "$LABEL" '[.[] | select($L == "" or (.labels
      | any((.name | ascii_downcase) == ($L | ascii_downcase))))]'
```

**The `ascii_downcase` on both sides is not decoration.** GitHub matches
`--label` case-insensitively — a manifest saying `Backlog` against a label named
`backlog` returns the full list server-side. A case-exact client filter returns
**nothing** for the same manifest, so the two reads would disagree in the worst
possible direction: the cheap read looks healthy while every correctness-critical
read silently sees an empty backlog, which reads as "no duplicate, file it again"
and "0 items remaining".

**Raise `--limit` when you do**, and mind that it now bounds *every* open issue
rather than the labelled ones — a repository with 400 open bug reports and 20
backlog items needs a limit above 400 to see all 20. The same ceiling warning
applies, harder.

A fresh session that has written nothing may use the `--label` form, and it is
the cheaper read. **Be precise about what that buys**: nothing *this session* did
can be behind, which is the only race a session can do anything about. A
teammate who closed three issues a moment ago races the index exactly the same
way, and no read command fixes that — every reader races other writers. The rule
here removes the self-inflicted case, which is the one that turns a re-run into
a duplicate.

## Writing to it

**Creating** — check for an open issue with the same title first, **through the
client-side filter above, not `--label`**. A skill that re-runs must not open a
second copy, and the `--label` form cannot see the copy this session just filed:

```bash
gh issue create --repo "$REPO" --title "$TITLE" --body "$BODY" \
  ${LABEL:+--label "$LABEL"}
```

**Closing**, when the work lands:

```bash
gh issue close --repo "$REPO" "$NUMBER" --comment "Landed in <sha>."
```

The comment is the one place a sha belongs — it is what makes a closed issue
traceable without reading the decision log.

## When `gh` is not there, or not authorized

**Say so and write nothing.** Every failure mode here is a network or auth
failure and every one of them is recoverable by the user in a minute; what is
not recoverable is a session that reported an item parked and parked nothing.

- `gh` absent → say the backlog could not be reached and name the item that was
  not filed, so it can be filed by hand.
- `gh auth status` failing → the same, naming authorization as the cause.
- The repo not resolving → this is a **manifest** fault, not a transient one.
  Report it as drift and dispatch to `--wss-adopt` in amendment mode.

**Never fall back to writing a local `WSS.TODO.md`.** A project that declared a
provider and finds a stray markdown backlog appearing has two backlogs, which is
the exact thing this exists to prevent. `wss-doctor.sh` checks the provider resolves
and is the place a broken one surfaces.

## What the sweeps do with it

`--wss-check` and `--wss-stocktake` read the backlog the same way, through the list
command above, and dispatch findings to `--wss-todo` as always. The one difference
worth knowing: **a checkpoint cannot narrow an issue sweep the way it narrows a
file sweep.** A file's staleness is a diff against a baseline commit; an issue's
is not visible in the git history at all, so an issue backlog is always read in
full. That is a cost, not a defect, and it is why the item count matters.
