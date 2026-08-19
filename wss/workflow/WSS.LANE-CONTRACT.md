# The lane contract

**Everything the suite holds about worktree lanes, in one file, because a
project that declares no lanes never needs a line of it.** Read it where lane
mode is on — a `.claude/WSS.LANE` selector is present in this checkout, or the
manifest declares `WSS.lanes.named` — **and when deciding whether to adopt
lanes at all**: that session has no selector and no declaration yet, so no gate
can route it here, and it is the reader that needs this file most.

What each record holds is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md); who
may write each file is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md); which keys a
manifest may set is [`WSS.MANIFEST.md`](WSS.MANIFEST.md). All three defer to this
file on lanes.

## `WSS.lanes.named` — the shape

**`WSS.lanes.named` holds the worktree lanes**, nested so lane names cannot
collide with the partitioning keys beside it, whose rows are
[`WSS.MANIFEST.md`](WSS.MANIFEST.md)'s and which apply with or without lanes. Each entry's `scope` globs are the paths the lane
owns — a `--wss-start` batch running inside that worktree partitions within
them — and its `records` object may redirect a record to a lane-scoped file:

```jsonc
// inside the WSS root, beside "record" and "commands"
"lanes": {
  "named": {
    "backend": { "scope": ["backend/**"],
                 "records": { "todo": "WSS.TODO.backend.md",
                              "openDecisions": "docs/WSS.OPEN-DECISIONS.backend.md",
                              "handoff": "docs/WSS.HANDOFF.backend.md",
                              "roadmap": "WSS.ROADMAP.backend.md" },
                 "transfer": "docs/WSS.TRANSFER.backend.md" },
    "frontend": { "scope": ["frontend/**"],
                  "records": { "todo": "WSS.TODO.frontend.md",
                               "openDecisions": "docs/WSS.OPEN-DECISIONS.frontend.md",
                               "handoff": "docs/WSS.HANDOFF.frontend.md",
                               "roadmap": "WSS.ROADMAP.frontend.md" },
                  "transfer": "docs/WSS.TRANSFER.frontend.md" }
  },
  "conflicts": "WSS.LANE.CONFLICTS.md"
}
```

The example validates as it stands — both lanes split every record they split,
and both declare a queue — because the half-shapes it must not show are
`wss-doctor.sh` failures, described below.

Name lane files by **lane**, which is durable (`WSS.TODO.backend.md`), never by
worktree, which is litter that outlives the worktree — the instance segment
after the FUNCTION, per [`WSS.NAMING.md`](WSS.NAMING.md)'s segment grammar.

## The selector, and the resolution rule

**The selector is a file, not a key: `.claude/WSS.LANE`** — gitignored, one per
worktree, holding the lane name, written once at worktree setup
(`--wss-adopt --lane <name>`). Absence means "unsplit project", the same
degradation as any missing key. It is deliberately **not** derived from the git
branch name: tempting and fragile, where the explicit file is boring and
correct. Like `WSS.sweeps`, it is per-checkout state that legitimately does not
exist, so it is not a `WSS.record.*` path and its absence is never a failure —
but a selector naming a lane the manifest does not declare **is** a
`wss-doctor.sh` failure.

**The resolution rule is owned here:** where a lane is selected and
`WSS.lanes.named.<lane>.records.X` exists, it overrides `WSS.record.X`; in every
other case `WSS.record.X` applies exactly as it does today. Cross-lane reads
need no extra key — every lane's paths sit in the shared manifest, which is
tracked and identical on every branch, and that identity is what removes the
record-file merge conflicts worktree lanes otherwise produce.

**Owned here does not mean stated only here, and the difference is deliberate.**
Dispatching skills restate the rule with the key list inline, so a reader
already at a dispatch site learns which records a selector moves without
following a link. That is a read saving worth several copies — but copies that
agree only by habit are how a contract quietly stops being one. So they are not
left on trust: `wss-doctor.sh` discovers every restatement by its wording,
compares the keys each one names against the set below, and fails on any
disagreement, on a second file claiming to be the authority, or on finding no
restatements at all. The last of those is the load-bearing one, since a
reworded marker would otherwise leave the walk checking nothing and reporting
green.

## Which records may split, and which must never

**Splittable: `todo`, `openDecisions`, `handoff`, `roadmap`** — forward-looking
records, lane-scoped by nature, and the ones every concurrent session wants to
write, which is exactly where the merge conflicts were. **Never: `decisions`,
`audits`, `changelog`, `stocktake`** — the append-only single timelines; three branches
appending at EOF conflict trivially and resolve as "keep both" — **nor
`releases`**, which is the release list and must be singular: the milestones,
the version each intends to ship as and the completion marks live there,
`--wss-release` reads no other planning record, and a per-lane copy would be a
release checkpoint one worktree cut for the whole project
([`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds why the roadmap and the
release list are two records) — **nor `behaviour`, `reference`**, which
describe one system, **nor `toolbelt`** — which tool does a job is a property
of the project, not of a worktree, **nor `backlog`** — one pool a person
cherry-picks from, and a per-lane pool is three places to forget to look. A lane-local decision log is the failure
this rule exists to prevent: the why of a choice fragments across files nobody
reads together.

Under lanes the decision log is fed by promotion, not by lane writes: a lane
appends *candidate* entries to its own openDecisions file, and the merge to the
integration branch is what promotes settled ones into `WSS.record.decisions`.
One writer per file still holds — each lane file has the same owner its unsplit
record has, per [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md)'s matrix.

**Splittable is a subset of `register`, and the intersection with `recordMode`
has no live case.** All four splittable records above are `register` mode, and
every record that is not — `decisions`, `changelog`, `stocktake`, `audits` as
`log`, and the two `generated` ones — is on the never-split list already. So no
rule is needed for "what happens when a `log` record splits": nothing does.
Re-derive rather than trusting this — read `WSS.recordMode` in
`.claude/WSS.WORKFLOW.json` against the two lists above; it is one glance, and
the invariant is a measurement rather than a design constraint, so a future
record could break it without anything objecting.

`wss-doctor.sh` fails on any other key under a lane's `records`, and on a
**half-split**: a splittable record is split for **all** named lanes or none,
because the lanes left out share the unsplit file — two writers on one path,
the exact collision lanes exist to remove, reintroduced one lane at a time.

## The transfer queue — a lane's inbox, and not a record

**A lane never writes another lane's records.** What it writes instead is that
lane's **transfer queue**, declared as `WSS.lanes.named.<lane>.transfer` — a
sibling of `records`, deliberately outside it, because everything under
`records` has exactly one writer and a queue has many. `wss-doctor.sh` fails on
`transfer` appearing under `records`.

| | A record | A transfer queue |
|---|---|---|
| Writers | exactly one | **any lane** |
| Holds | state — what is true, planned or decided | **messages in flight** |
| Steady state | whatever it says | **empty** |
| Write mode | append-only or rewritten in place | append-only, always |
| Consumed by | nothing — it is read | the owning lane's `--wss-start`, which moves each entry into the record it names and deletes it |

**Append-only is what makes many writers safe** — an append is additive, so a
wrong entry is merely wrong and nothing true is lost. **One consumer is what
keeps [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md)'s one-writer invariant intact** — an
entry becomes part of `WSS.record.todo` only when that lane's own session moves
it there, so `todo` still has exactly one writer. **A queue is not a record,
so this is not a carve-out**: a record holds state and is read, a queue holds
messages in flight and is empty in the steady state, and neither queue has a
row in the ownership matrix.

An entry names the record it is bound for, because one queue serves every
destination it can reach:

```
## [todo] <one-line summary>
From: <originating lane> · <what it came from — a block, a conflict, an entry>
Why: <what makes this the receiving lane's work>
```

`[todo]`, `[openDecisions]` and `[roadmap]` are the only targets — the
splittable records other than `handoff`, since a lane's handoff is written by
that lane alone and nothing files into it. **A queue entry is a request, never an
instruction**: the receiving lane's session is what decides the entry belongs,
and an entry it rejects is deleted with a line saying so rather than silently
dropped.

Like the splittable records the queue is **declared for all named lanes or
none** — a lane with no queue is a lane nothing can file to, which reads as
"nobody needs anything from them" and is almost never true. It is tracked,
unlike the `.claude/WSS.LANE` selector, because an entry has to travel to the
worktree it is addressed to.

**Delivery rides the integration branch.** A lane appends on its own branch, so
the entry reaches another worktree only once the writing lane lands on
`WSS.branch.integration` and the receiving one syncs forward. Two lanes
appending to different queues never collide; two appending to the *same* queue
conflict at EOF and resolve as "keep both", which is the trivial case the
append-only records already accept.

## The conflict inbox — `WSS.lanes.conflicts`

**The second queue, and it differs from the first in who it is addressed to.**
A transfer queue is addressed to a *lane*: work one lane believes another owns.
The conflict inbox is addressed to a *skill*: a contradiction between two
lanes' records, noticed by a session that was doing something else, which needs
mediation nobody in that session can perform.

There is **one per project**, not one per lane — a sibling of `named` in the
manifest, never a key inside a lane — because a contradiction is not any single
lane's property, and routing it to one of the two lanes involved would be
picking a side before anyone has ruled. Declaring it without `WSS.lanes.named`
is meaningless and `wss-doctor.sh` says so.

| | Transfer queue | Conflict inbox |
|---|---|---|
| Declared | `WSS.lanes.named.<lane>.transfer`, one per lane | `WSS.lanes.conflicts`, one per project |
| Addressed to | that lane | `lane-record-sync` |
| Consumed by | that lane's `--wss-start` | that skill, on its next run |
| Holds | work believed to be that lane's | a suspected contradiction between two lanes |

Every queue rule above applies unchanged: append-only, any session may write,
empty in the steady state, and an entry is deleted when it has been handled.

```
## <one-line statement of the contradiction>
Lanes: <one lane> vs <the other>
Found: <the lane that filed it> · <what it was doing when it noticed>
Claim: <what each side's record says, cited so it can be checked>
```

**A filed entry is a claim, not a conflict.** The skill re-verifies it against
the records before promoting it — the same second look
[`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md#the-inspector-writes-nothing) requires of
any finding that crosses skills, and for the same reason: a meaningful share do
not reproduce as reported, and one that was already resolved reads exactly like
one that is live. What the reporting session contributes is **evidence**, not a
verdict.

**Nothing else empties it.** A session that files an entry and a session that
would act on it are different sessions, so an inbox nobody consumes is a
contradiction somebody already found and nobody will see again.

## `[critical → why]`

This is the one statement of the marker's rules; every other site points here.

**One priority marker, not a ladder.** Everything else is unmarked — no "high",
no "mid". Two levels rather than four because dependency ordering already
outranks priority when a batch is partitioned, so finer grades mostly lose to
it — and every extra grade is a judgment call on every write, with "mid" and
"unmarked" meaning the same thing in practice. What the marker *does*:
`--wss-start` takes critical items first, before any section ordering applies.

**It lives on the first line of an entry's body, never in a heading or a
section, and consumers read it there.** Same place and shape as `[blocked → …]`
and `[later → …]`, so there is one convention rather than two — and the body is
the only surface a provider-backed backlog preserves: an issue list has no
sections and comes back newest-first, so the marker is read out of the body and
is the only ordering signal that survives there. A file-backed backlog is read
the same way, which is what keeps the two forms one convention.

**A lane may not mark its own request critical in another lane's queue.** The
marker is written only where **the user said so in that turn** —
`lane-record-sync`'s mediation of a conflict, or its *accept as critical*
ruling on a dependency. Priority inflation is the standard failure of every
ladder, and here it is worse than usual: a lane marking its own asks critical is
one lane setting another lane's order. The user setting it is not that, which is
why the rule names the *writer* rather than the route. Downstream of the write,
**a transfer drain carries the marker across unchanged and never adds one** — a
drain moves an entry, it does not re-judge it.

## Work scoped to another lane is announced first, then routed to that lane

The which-session-may-act rule for lane projects — a lane's `scope` globs bound
what a session may act on, not only which key resolves. Where the manifest
declares `WSS.lanes.named` and a `.claude/WSS.LANE` selector names this
session's lane, a request whose scope falls under a *different* lane's `scope`
globs is another worktree's work, and two things hold — both **before any file
is touched**:

- **Warn up front.** Name the session's lane, the owning lane, and where the
  work will happen. The scope globs sit in the shared manifest, so the
  mismatch is detectable the moment the request arrives — detect it then, not
  at commit time, when the only remaining options are both wrong.
- **The work happens in the owning lane's home.** Its worktree, its branch,
  its records. Interactively, offer the switch to a session in that worktree;
  where the user has the work proceed from here anyway, it proceeds *into*
  the owning lane's worktree and branch — absolute paths — and its record
  writes resolve through that lane's `records`, not this one's.
  **Lane-foreign files are never committed to the current worktree's
  branch**: a commit that mixes lanes undoes the partition the lanes exist to
  provide, and the conflict it defers lands on whoever merges next.

A request that straddles two lanes is a partition question, not a licence —
split it, do this lane's share here, and route the rest.
