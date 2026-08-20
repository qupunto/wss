# Conventions

> **This file is a member of `WSS.record.reference`.** Sole writer is
> `reference-writer`
> ([`WSS.REFERENCE-WRITER.md`](../workflow/writers/WSS.REFERENCE-WRITER.md));
> what it may and may not hold is
> [`WSS.RECORD-CONTRACT.md`](../workflow/WSS.RECORD-CONTRACT.md), the authority
> where the two disagree. Write mode: register — rewritten in place to stay
> true now.

**This file holds conventions only: definitions followed mechanically.** The
admission test is the first boundary below — anything two honest readers could
apply and disagree on is a *rule*, belongs to the rulebook (`wss/rules/`), and
is bounced from this file at write time. The reasoning behind each convention
is the decision log's, cited tersely and never restated.

## Index

One line per boundary, kept one-to-one with the `## ` headings below (the
detector for that claim is parked in `WSS.record.todo`):

- `#conventions-against-rules` — convention, rule, arbiter, executor, venue, disagreement test
- `#the-record-vocabulary` — records, the record, registers, logs, generated, mutable
- `#name-collisions-the-sense-test` — sense, sense-fork, scope, role-nouns
- `#reserved-words` — archive, surface, state
- `#false-friends` — coinage, translation, interference
- `#abbreviations` — wss
- `#file-names` — WSS.*, SKILL.md, wss-*.sh, writers
- `#flags` — --wss- prefix, shorthand, grammar
- `#addressing` — KEY#fragment, ordinal, marker, imprint

## Conventions against rules

A **convention** is followed, mechanically: given the case, the outcome is
fixed, and two honest sessions cannot apply it and disagree. A **rule**
requires judgment: an **arbiter** judges the case, an **executor** carries out
the verdict — a script, a ladder, a checklist, or freeform — and the **venue**
is where and when it fires, kept separate from the judge.

Mechanical-to-follow and mechanical-to-detect are different axes: a convention
stays a convention even where no grep can police it. Detectors are optional
accessories on conventions; arbiters are constitutive of rules. Composites
split rather than straddle — a row's *format* is a convention, its content
*standard* is a rule — so one feature may contribute a line to each home
without duplication, because each holds a different sentence.

## The record vocabulary

- **records** — the umbrella: every declared surface the manifest's
  `WSS.record.*` namespace names, whatever its class. Collective singular:
  **the record** ("for the record" — everything entered, live and historical).
- **registers** — mutable records, rewritten in place to stay true *now*:
  the TODO, roadmap, handoff, setup, toggles, this file.
- **logs** — append-only, true *then*: decisions, changelog, stocktake,
  audits. Never rewritten; a correction is a new entry.
- **generated** — derived, regenerated never hand-edited: the decisions
  index, the tooling inventory.

The canonical encoding is the manifest's `recordMode` value set —
`log` | `register` | `generated`
([`WSS.MANIFEST.md`](../workflow/WSS.MANIFEST.md)'s row; the class split is
[`WSS.RECORD-CONTRACT.md`](../workflow/WSS.RECORD-CONTRACT.md)'s). The
two-word form "mutable records" gives way to "registers". Ruling: the
decision log's `2026-08-20 (fourteenth)`.

## Name collisions: the sense test

A name collides only when **senses fork** — one word carrying two meanings in
the same tree. Shared sense across scopes is coherence, not collision.

- **Role-nouns are sense-stable by design**: writer, executor, arbiter,
  designer, owner. Each means the same kind of actor everywhere; *which*
  orders, files or judgments it serves is scope, and scope resolves from
  context. The hub's executor and a rule's executor share the noun the way
  `handoff-writer`, `reference-writer` and `git-writer` share theirs.
- A new coinage may **widen a word's scope, never fork its sense**. Before
  adopting a name, read the existing occurrences for their sense rather than
  counting them: occupancy in the same sense is the canon agreeing.

## Reserved words

- **archive** — the lifecycle endpoint (where material goes when it leaves
  active use) and the bundle sense the ecosystem owns (`git archive`, tar).
  Never the umbrella over live records.
- **surface** — the supervision ladder's word for anything a write lands on
  ([`WSS.SUPERVISION-LADDER.md`](../workflow/WSS.SUPERVISION-LADDER.md)).
  The ladder's term, not the umbrella.
- **state** — the ordinary current-condition sense everywhere (the handoff's
  `## State`, the cycle states, `cycle-state` inbox items). Never a
  file-class name.

## False friends

A coinage reached through another language gets a sense-check before it
hardens: confirm the English sense in place matches the intended one. The
check is cheap, and either confirms the word or catches a sense-fork early —
both outcomes have occurred here.

## Abbreviations

- **wss** — the Workflow Secretary Suite. Lowercase in file and flag names
  (`wss-doctor.sh`, `--wss-log`), uppercase in record file names and manifest
  keys (`WSS.TODO.md`, `WSS.record.todo`).

## File names

The observable patterns, verifiable with `ls` against each directory:

- **Records, logs, workflow contracts**: `WSS.<NAME>.md`, uppercase —
  `wss/records/`, `wss/logs/`, `wss/workflow/`.
- **Writer procedures**: `WSS.<NAME>-WRITER.md` under `wss/workflow/writers/`.
- **Skills**: `skills/<lowercase-kebab>/SKILL.md`.
- **Scripts and hooks**: `wss-<lowercase-kebab>.sh` under `wss/scripts/`,
  `wss/tests/`, `hooks/`.
- **Generated files**: under `wss/generated/`, never hand-edited.

## Flags

Definitions live at their sources; this boundary is the pointer set. Shape:
`--wss-` prefixed, and no flag is a prefix of another — the doctor's
flag-prefix check is the detector. The shorthand list is `README.md`'s; what
each flag authorizes is
[`WSS.OWNERSHIP.md`](../workflow/WSS.OWNERSHIP.md)'s matrix.

## Addressing

How one thing in this tree names another — the `KEY#fragment` scheme, the
fragment and ordinal citation forms, the inline marker grammar, the imprint —
is [`WSS.ADDRESSING.md`](../workflow/WSS.ADDRESSING.md)'s, whole. This
boundary exists so the index finds it.
