# The supervision ladder — how supervised each record write is

**One ordered scale, one assignment table, set by the owner and only the
owner.** Who may write a surface is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md)'s;
what it may hold is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md)'s; which
agent runs a task at which tier is
[`WSS.DISPATCH-LADDER.md`](WSS.DISPATCH-LADDER.md)'s. This file settles the
fourth dimension those three deliberately do not: **how much supervision a
write needs before it is made** — when the writer acts alone, when the write
must cite its authorization, and when the owner answers first. The assignments
are the owner's ruling (`wss/logs/WSS.DECISIONS.md`,
`2026-08-17 (seventeenth)`); a session never reassigns a cell, for the same
reason a session never derives a global rule ([`CLAUDE.md`](../../CLAUDE.md)).

## The scale — four levels, cumulative in requirements

Each level contains every requirement of the one before it and adds one. That
containment is what makes this a ladder rather than a bag of separate rights: a
check can compare levels, and a write cleared at one level satisfies every
level below it.

1. **free** — write within the surface's contract shape, and state what you
   did. The transparency baseline, never waived at any level.
2. **evidence-gated** — all of the above, and the write cites its checkable
   authorization: a decision-log entry, a verification actually run, the
   completed work a deletion claims. The citation is checkable after the fact.
3. **prompted** — all of the above, and the citation must be a ruling obtained
   from the owner in that conversation, before the write, with the concrete
   action named — delete, adapt, re-file, correct in place. Silence is refusal.
   The answer is then recorded through `--wss-log`, so a prompt produces the
   evidence the level below asks for.
4. **forbidden** — the limit case: no compliant write exists. Where a row
   states a named exception, the exception itself sits at prompted.

**Assignment is per surface × action** — add, modify, delete-or-move-out —
because one record can span the whole scale: the append-only logs are free on
add and forbidden on delete, so a single whole-record level would misstate one
end. **A row keys on the surface, never on the writer**: one writer
legitimately owns surfaces at opposite ends — the handoff's `## State` section
is wiped wholesale by design while its hazard overflow is prompted at every
action.

The rows name manifest record keys rather than paths, so this is one table for
every project the suite runs, and a lane worktree's path overrides change
nothing here.

## The assignment table

Approved by the owner as proposed (`2026-08-17 (seventeenth)`), including the
three cells the proposing session flagged least-certain; `behaviour`,
`toolbelt` and the unassigned-surface default followed at
`2026-08-17 (eighteenth)`.

| Surface | add | modify | delete / move out |
|---|---|---|---|
| `backlog` | free | free | evidence-gated; promotion out is prompted, which was already the rule |
| `todo` | free | free | evidence-gated — the re-verified citations are the evidence; reversing an owner deferral is prompted |
| `openDecisions` | free | free | prompted by construction — deletion happens only by settling, and settling is the owner's answer |
| `roadmap` | prompted for goals and blocks; evidence-gated for progress | evidence-gated | prompted |
| `releases` | prompted | the completion mark prompted, which was already the procedure; otherwise evidence-gated | prompted |
| `handoff` — the `## State` section | free — wiped wholesale by design | free | free |
| `setup` | prompted — a row is a permanent per-session cost, like the card; a row in the `## Toggles` table implementing a toggle the owner has already accepted is evidence-gated, the acceptance's decision entry being the citation (owner's ruling, `2026-08-19 (twenty-third)`) | evidence-gated — a stale row is updated with the proof cited, or reported to the user | prompted — removal reverses an owner-approved admission |
| `handoff` — the card, and its overflow `wss/records/WSS.HAZARDS.md` | prompted | prompted | prompted |
| `reference` — every member | evidence-gated — the settling conversation is the evidence | evidence-gated | evidence-gated |
| `decisions`, `changelog`, `stocktake`, `audits` | free — recording is not deciding | forbidden, except the factually-false correction, which is prompted | forbidden |
| `decisionsIndex`, `tooling.inventory` | forbidden by hand; regeneration is free and owed | forbidden by hand | forbidden by hand |
| `tooling.catalog` | free — it mirrors the tree, and the doctor compares them | free | free |
| `behaviour` | evidence-gated — the settling conversation is the evidence | evidence-gated | evidence-gated |
| `toolbelt` | evidence-gated — the adoption's decision entry is the citation | evidence-gated | prompted — removing a tool reverses an adoption a person made |
| the sweeps checkpoint, `.claude/WSS.SWEEPS.json` | free — it stamps a run that happened | free | free |
| the manifest, `.claude/WSS.WORKFLOW.json` | evidence-gated | evidence-gated | prompted |

**An unassigned surface is prompted at every action until the owner assigns
its row** — the owner's rule
(`wss/logs/WSS.DECISIONS.md`, `2026-08-17 (eighteenth)`), fail-closed by
design: work on a surface this table does not
yet cover proceeds only by asking, and the ask is what produces the
assignment. A session never supplies a quieter default, for the same reason a
session never derives a global rule ([`CLAUDE.md`](../../CLAUDE.md)).

## Out of scope, deliberately

- `tooling.sources` — those files are code, governed as ordinary work plus the
  tidy sweeps. A supervision level on source edits would be a second review
  process wearing this table's name.
- **Commits, pushes and tags** — the flag-grant system already tiers them, and
  [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md)'s matrix is its authority.
- **Reading** — never restricted anywhere in this suite, so it is not a level.

## Enforcement — the structure is live, the gate is not

What exists: this file as the canon, a pointer in every writer whose surface
appears in the table, and `wss-doctor.sh`'s coverage section — locate it with
`grep -n 'Supervision ladder coverage' wss/tests/wss-doctor.sh` — which fails
when a declared record key has no row and when a row names a key the manifest
vocabulary does not know.

What deliberately does not exist yet: the commit-time gate that would refuse a
prompted-level write carrying no cited ruling. Structure before enforcement is
the owner's ([`CLAUDE.md`](../../CLAUDE.md); the reasoning is
`wss/logs/WSS.DECISIONS.md`, `2026-08-17 (sixteenth)`): the gate is a named
follow-up only the owner switches on, and until then this ladder binds as
procedure — a writer reads its row before writing — and is never applied
retroactively to work that predates it. Two repairs stand between here and
that gate, both filed in `wss/records/WSS.BACKLOG.md`: the provenance
resolver is blind to object-valued record keys, and it resolves nothing for
the hazard overflow at all.
