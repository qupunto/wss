# `WSS.record.todo` in GitHub Issues

**A TODO list provider, read on demand.** Where a project declares one,
`WSS.record.todo` is not a file — it is the repository's open issues. The
decision log's `2026-08-19 (sixty-ninth)` entry rules that these issues are
never read implicitly: not at session start, not as a routine part of a skill
loading the TODO list. They are read **on demand only** — see "On demand, not
implicit" below — and what that read produces is a **triage queue**, not TODO
entries. An issue never enters the TODO list directly.

Declared in `.claude/WSS.WORKFLOW.json`:

```json
"record": {
  "todo": { "provider": "github-issues", "repo": "owner/name", "label": "backlog" }
}
```

`repo` is required. `label` is optional **scoping for a triage read** — narrow
to a subset of issues when triaging a large repository, if there is a
convention for it. It is not a boundary that guards anything: the split
between "this project's work" and "everything else in the tracker" is now the
timing and the person doing the read, not a query term.

## On demand, not implicit

**Demand is a person, explicitly, asking to work through or review this
project's issues** — "let's go through the open issues", "what's on GitHub for
this repo", a person naming the triage pass as the thing to do right now.

It is never:

- a skill loading `WSS.record.todo` as part of routine batch selection —
  `--wss-start`'s Phase 2 does not read this provider at all; a project on it
  contributes nothing to autonomous batch selection, and the batch draws from
  the file records and, failing those, the roadmap
  (`skills/start/SKILL.md::Phase 2`);
- a session-start hook, or any other skill's routine pass over the TODO list.

## Why this exists, and what it does not change

A team that already lives in Issues cannot adopt a workflow whose TODO list is
a markdown file: they would be maintaining two, and the second one loses. This
makes the medium a project decision rather than a condition of adoption — it
does not make the issue tracker a second inbox that feeds the TODO list
automatically. **An issue never enters the TODO list directly.** A person
reads the issues, one at a time, in a triage pass, and picks each one's
disposition:

- **Work on it** — open it and do the work now, or, if the person says so,
  park it through `--wss-todo`, exactly as any other TODO entry is written.
- **Answer it** — reply on the issue. No TODO entry, no decision-log entry,
  unless the answer is itself a decision, which is `--wss-log`'s call as
  always.
- **Close it** — nothing else to do, whether because it was declined or
  because the reply above already settled it.

**Nothing else moves.** `WSS.record.decisions` and `WSS.record.openDecisions` stay
files even here, and that is deliberate — they are prose read months later by
someone reconstructing why, and an issue thread is a conversation rather than
a record. Where `--wss-todo` does write a TODO entry here, the same split it
already enforces applies: **the task goes to the provider, the reasoning goes
to the decision log**, and the issue carries a link to it rather than the
argument itself.

**One writer still.** `record` is the sole writer of issues carrying the
configured label. An issue without that label is somebody else's — a user bug
report, a discussion — and this workflow does not touch it.

## Reading it — a triage pass

```bash
gh issue list --repo "$REPO" ${LABEL:+--label "$LABEL"} --state open \
  --limit 200 --json number,title,body,url,labels
```

**`--limit` is not optional.** `gh` defaults to 30 and says nothing about the
rest, so a triage pass over 45 open issues silently becomes 30 — the person
reviewing them never sees the missing fifteen and has no way to know. Read a
count first and say so if it is at the ceiling.

Work the result one issue at a time — title and body are enough to decide the
disposition above; do not batch-decide from the list view.

### After writing, in the same session, do not read with `--label`

`--label` is served from GitHub's search index, which lags writes by seconds to
tens of seconds: an issue closed a moment earlier is still returned as open,
and an issue *created* a moment earlier is not returned at all. Re-take the
measurement by creating an issue and immediately running both commands below.

This is not a cosmetic lag: within a single triage session — more than one
disposition written back to back — it defeats the **dedupe check** before
creating. An issue just filed sees zero copies of itself in a `--label` read,
so the next disposition in the same session that wants to create an issue can
open the duplicate the one-writer rule forbids.

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
read silently sees an empty triage queue.

**Raise `--limit` when you do**, and mind that it now bounds *every* open issue
rather than the labelled ones — a repository with 400 open bug reports and 20
TODO-relevant items needs a limit above 400 to see all 20. The same ceiling
warning applies, harder.

A fresh session that has written nothing may use the `--label` form, and it is
the cheaper read. **Be precise about what that buys**: nothing *this session*
did can be behind, which is the only race a session can do anything about. The
rule here removes the self-inflicted case, which is the one that turns a
re-run into a duplicate.

## Writing to it

**Creating** — only when a triage disposition is "work on it, and say so."
Check for an open issue with the same title first, **through the client-side
filter above, not `--label`**. A skill that re-runs must not open a second
copy, and the `--label` form cannot see the copy this session just filed:

```bash
gh issue create --repo "$REPO" --title "$TITLE" --body "$BODY" \
  ${LABEL:+--label "$LABEL"}
```

**Closing**, when the work lands:

```bash
gh issue close --repo "$REPO" "$NUMBER" --comment "Landed in <sha>."
```

The comment is the one place a sha belongs — it is what makes a closed issue
traceable without reading the decision log. Closing that ends a triage pass
without landed work behind it — declined, or already settled by a reply —
needs no sha comment; a plain close, or the answer itself, is enough.

## When `gh` is not there, or not authorized

**Say so and write nothing.** Every failure mode here is a network or auth
failure and every one of them is recoverable by the user in a minute; what is
not recoverable is a session that reported an item parked and parked nothing.

- `gh` absent → say the triage read could not happen and name what was not
  reviewed.
- `gh auth status` failing → the same, naming authorization as the cause.
- The repo not resolving → this is a **manifest** fault, not a transient one.
  Report it as drift and dispatch to `--wss-adopt` in amendment mode.

**Never fall back to writing a local `WSS.TODO.md`.** A project that declared a
provider and finds a stray markdown TODO list appearing has two TODO lists, which is
the exact thing this exists to prevent. `wss-doctor.sh` checks the provider resolves
and is the place a broken one surfaces.

## What the sweeps do with it

Nothing. `--wss-health-check`, its `--deep` TODO resort, `--wss-overview`,
`--wss-wrap`'s status report, and `WSS.RECORD-DRIFT.md`'s drift method do not
fetch a provider-declared `WSS.record.todo` — a routine sweep loading the TODO
list is exactly what "On demand, not implicit" above rules out. Each reports
the record `not-covered` (or, where it would otherwise print a count, "TODO
list is a github-issues provider (on-demand triage)") and moves on. The
provider is read only in the triage pass above, by a person, on demand.
