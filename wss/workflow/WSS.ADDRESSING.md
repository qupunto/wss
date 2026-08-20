# Addressing: how one thing in this tree names another

**This file is the canon for the `KEY#fragment` scheme and for three other forms
that were load-bearing before anything wrote them down.** It settles how a
citation is *written* and how it *resolves*. What a suite-written file may be
**called** is [`WSS.NAMING.md`](WSS.NAMING.md)'s and is not restated here; which
keys a manifest may set is [`WSS.MANIFEST.md`](WSS.MANIFEST.md)'s; who may write
a record is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md)'s.

**Why one file rather than four.** Each of the four forms below is read by
several skills, enforced by at least one check, and was previously described
nowhere — so each was reconstructed from examples by every session that met it.
The scheme's design and the ruling that widened this file to the other three are
`wss/logs/WSS.DECISIONS.md`'s `2026-08-18 (twenty-fifth)` and
`2026-08-19 (twenty-third)` entries.

## 1. The `KEY#fragment` scheme

**One notation.** `KEY` alone, or `KEY#fragment`. Nothing else addresses a thing
in this tree.

**Two key namespaces, and they never overlap.**

- **`WSS.record.*`** — declared in a manifest. `.claude/WSS.WORKFLOW.json` for
  what ships to adopters, `.claude/WSS.LOCAL-RECORDS.json` for what does not.
- **`WSS.<kind>.<name>`** — derived from the generated inventory,
  `.claude/WSS.TOOLS.json`. The kinds are the inventory's own, assigned by
  `wss/scripts/wss-tools-inventory.sh`'s `kind_of_glob()`; a glob whose kind it
  cannot name is refused rather than walked past.

**Three resolution modes, chosen by the TARGET's kind and never by the citing
author.** This is the part most easily got wrong, because a citation looks like
a choice the writer makes:

| The target is | A fragment resolves against |
|---|---|
| a register, or any file with stable headings | the heading, slugified — §2 |
| a record whose `WSS.recordMode` is `log` | the generated index, not the file — §3 |
| a skill | the skill's whole file set: `SKILL.md` plus its inventoried references |

**A log record's fragment cannot be a heading anchor**, and that is a property of
append-only rather than a preference: anchors cannot be retrofitted into entries
that must not be rewritten, so the index is the addressable surface.

**A reference file carries no key of its own.** The owning skill's key reaches
it. Content moves between a `SKILL.md` and its references as a context-cost
decision rather than an identity change — the router splits and the token-economy
sweeps do exactly that — so per-reference keys would dangle on the suite's most
frequent restructuring.

**Resolution is exactly one match.** A fragment matching zero, or more than one,
heading in the set is a finding — never settled by a precedence order, because a
`SKILL.md`-wins rule would let a citation bind silently to the wrong section.
`wss-doctor.sh`'s "Anchor uniqueness within a skill's set" enforces the
more-than-one half.

### The citation marker: `` `→KEY` `` cites, a bare key names

**A bare `WSS.x.y` is ambiguous by construction and always was.** Prose names
keys constantly and correctly — `WSS.record.tooling.sources` is a glob list,
`WSS.suite.version` a manifest field, `WSS.record.todo.repo` a provider sub-key,
and none of them names a file. Measured on this surface: 18 tokens resolve and 48
do not, and almost none of the 48 is a defect. **So nothing could check a bare
key without failing correct writing.**

**A citation carries a leading `→` inside its code span; a mention does not.**

| Written | Means |
|---|---|
| `` `WSS.record.todo` `` | naming the key — prose about the key itself |
| `` `→WSS.record.todo` `` | citing the file that key resolves to |
| `` `→WSS.contract.WSS.NAMING.md#ownership-is-authorship-not-usage` `` | citing one section of it |

**The arrow is the tree's own**, not a new notation: `[blocked → …]`,
`[critical → …]` and the rest already use it to mean *points at*. It appears
inside a code span nowhere else, so nothing collides.

**What it buys is the whole point of the scheme.** `wss/scripts/wss-resolve.sh
--check` fails on a marked citation that does not resolve, and leaves an unmarked
key alone. Without the marker, only the fragment-bearing minority could ever be
enforced — and a bare key that rots is invisible to a reader *and* to the link
checker, where a wrong path is at least visible to both.

**Adopted on the owner's ruling, ahead of the path-to-key substitution rather
than after it** — that pass turns 147 paths into references, and applying the
marker afterwards would mean a second sweep over everything the first one
touched. The form is this session's proposal within that ruling and is cheap to
reverse: it is one character, and the resolver accepts a citation with or without
it.

## 2. The fragment, and what happens when a heading moves

**A fragment is a heading, slugified.** The slug rule is `wss-doctor.sh`'s
`ANCHOR_PY` and is **cited, never copied** — two slug functions that drift is
precisely the defect the uniqueness check exists to catch, so a second copy of
the regexes would be one. Run that program to answer any question about a
particular heading's slug.

**A heading that changes breaks every fragment naming it.**
`wss-doctor.sh`'s "Link anchors" walks markdown links whose target carries a `#`
fragment and fails an unresolvable one; `wss/scripts/wss-resolve.sh --check`
walks the bare `KEY#fragment` form, which is not a markdown link and which
nothing saw before it.

**Where the target file carries a `wss:` region id (§5), the fragment resolves
to it first** and the heading may then move freely; the slug path above is the
fallback, and the only behaviour in files no migration has reached yet.

**What is still not detected is a bare key with no fragment**, and the reason is
that **nothing in this scheme separates a citation from a mention.** Prose names
manifest keys constantly and correctly — `WSS.record.tooling.sources` is a glob
list and `WSS.suite.version` a manifest field, neither of which names a file — so
a bare token that resolves to nothing is indistinguishable from ordinary writing.
`--check` counts those rather than failing them. **A `#fragment` cannot be a
passing mention**, which is why the fragment-bearing half can be enforced and the
rest cannot.

## 3. The ordinal citation form

**The form is `` `YYYY-MM-DD (ordinal-word)` ``, backticked**, naming one entry
in `WSS.record.decisions`. The ordinal is a word, not a numeral, and it counts
that date's entries from one.

**The backticks are load-bearing, not decoration.** `wss-doctor.sh`'s
prose-date check strips backtick spans before it scans, so an unbackticked
citation inside a rule file is reported as history that belongs in the log. Every
citation on the live surface carries them.

**A citation must resolve to a line in `WSS.record.decisionsIndex`.**
`wss-doctor.sh`'s "Deferral pointers" enforces this for the pointers in
`WSS.record.todo`: a citation naming an entry the index has no row for is a
finding, because a pointer at the *whole log* cannot distinguish a live ruling
from one a later entry superseded.

**The collision rule, which exists because the ordinal is positional.** An
ordinal is assigned by counting that date's existing entries, so **two sessions
appending concurrently compute the same next ordinal** and both are right at the
moment they compute it. Under a shared checkout — which
`wss/records/WSS.HANDOFF.md` names a standing condition — **re-read the log
immediately before appending and take the next unused ordinal**, not the one
computed before the work started.

**A duplicate is detected, and it was not before this file existed.**
`wss-doctor.sh`'s "Decision-log ordinals" walks every entry heading and warns on
a repeated one. Nothing else sees it: `wss-index-decisions.sh` regenerates the
index with two identical rows and `--check` reports it current, because the index
does faithfully match a log that carries the duplicate. **Repairing one means
renumbering an entry in an append-only record**, which is the owner's call — the
check says so rather than implying a session may do it.

## 4. The inline marker grammar

**Markers are read by machines and by `--wss-start`'s eligibility test**, which is
why their spelling is fixed here rather than left to each writer.

| Marker | Means | Where it sits |
|---|---|---|
| `[blocked → <what is undecided>]` | cannot start until a choice is made; names the choice, and points at `WSS.record.openDecisions` | its own line in the file form, the body's first line under a provider |
| `[critical → <why>]` | taken before section ordering applies | same line as the entry it marks |
| `[later → <why>]` | deferred, where there is no `## Later` section to put it in | the body's first line, provider form only |
| `Parked (owner ruled)` | a ruling exists and must not be reversed | the entry's closing line |
| `Parked (session judgment)` | a question addressed to the next `--wss-start`, which is the gate it waits for | the entry's closing line |
| `[defer → <target>]` | an obligation that falls due when `<target>` exists — "when this target exists, this is owed" | the line carrying the link the obligation rides on |
| `[pending → <target>]` | the same obligation, already owed and waiting on `<target>` to be actionable | the line carrying the link the obligation rides on |

**The arrow is `→`, not `->`.** Consumers match the character.

**The last two are the obligation markers, and nothing scans for them yet.**
They are canon — the decision log's `(eighty-fifth)` entry — because the niche none of the other five covers is a link that *carries an
obligation* rather than a state. `--open-loops`, the mode that would report every
`[defer → …]` whose target now exists, stays **unbuilt until instances
accumulate**: writing starts first, so that the check has a history to run
against rather than reporting nothing until someone begins. **Write them; do not
wait for the mode.**

**`[critical → …]` is the only priority marker.** There is one grade and no
others; [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md) holds why.

**A marker's plain reading must not invert its meaning.** `Parked (owner ruled)`
says a ruling already exists; it does not say the owner still owes one. The
previous spelling, `Deferred (owner)`, read the second way and was read that way
on first contact — and the dangerous direction is a session reversing the owner's
parks because the label invited it.

**An unpark is written, not implied.** Lifting a park adds a line naming who
lifted it and citing the entry that did; the original reasoning stays where it
was written and is not rewritten.

## 5. The imprint — one marker carries boundary, anchor and provenance

**Adopted by the owner — the decision log's `2026-08-19 (sixty-first)`
entry — and the grammar ruled as drafted in its `2026-08-19 (sixty-third)`**,
the draft being `wss-imprint-grammar.md`. The imprint unifies the region
boundary, the anchor and the provenance into one marker family. **Enforcement
arrives with its validator and per-class migrations** — `WSS.record.todo`'s
imprint cycles — and until a record class is migrated, the fallbacks in this
file are its live behaviour: structure before enforcement, per class.

**The file imprint, line 1 of a record, is the whole cost of the common
case** — the file is thereby one boundary, and every byte in it is inside a
boundary:

```text
<!-- wss v=1 f=WSS.record.todo w=record -->
```

Regions subdivide it only where a block needs its own anchor, its own writer,
or an entry form:

```text
<!-- wss:pending-outward-acts -->
…
<!-- /wss:pending-outward-acts -->
```

**Fields, all short keys.** The anchor is not a field: it is the token after
the colon, because it is the one thing every region has and the citation
scheme resolves against it. Fields absent on a region inherit from the file
imprint.

| Key | Meaning | Values |
|---|---|---|
| `v` | grammar version | `1`; file imprint only |
| `f` | the record key this file answers to | a manifest key; file imprint only, and it must match the key that resolves to this path |
| `w` | writer — who MAY write | a writer the ownership matrix names; regions carry it only to override the file's |
| `by` | author — who DID write | `owner` · `session:<8-hex>` · absent, which means unknown |
| `at` | when it was written | ISO 8601, date (`2026-08-19`) or instant (`2026-08-19T14:31:02Z`) · absent, which means unknown |
| `via` | the applying session, where it differs from the author | `session:<8-hex>` — the relay case |
| `e` | entry form of a repeating region | `table-row`, … |

**Closes are named and nesting stops at one level.** `<!-- /wss:<id> -->`
repeats the id, so a dropped or duplicated boundary in a file two writers
touch fails pairing with an exact message; regions sit at most one level under
the file imprint, never inside each other.

**Provenance's core is who and when** — the owner's ruling, the decision
log's `2026-08-19 (sixty-seventh)` entry: wherever provenance is written,
`by=` and `at=` travel together, the `at=` in ISO form. Git-borne provenance
already carries its when in the commit; the imprint's fields are for
provenance the file itself must hold.

**Provenance is never invented.** `by=` appears only where the entry's own
text names its author, and `at=` only where the entry's own text dates the
write; absent means unknown and stays that way. Mechanical
entry ids — `e2026-08-19-47`, the date plus that date's ordinal — are
structure rather than provenance, so a migration may stamp them on historical
entries; `by=` and `at=` it may not.

**Markers count at column 0, outside fenced code blocks.** An example in the
docs or the test suite indents or spells a variant — the same rule the
model-override check already applies to forbidden shapes the suite must spell.

**What replaces what.** `<!-- wss:region entry=table-row -->` …
`<!-- wss:region-end -->` is the pre-imprint spelling of a boundary; the
registers migration converts it — `entry=` becomes `e=`, and the close gains
its name. Both spellings are live only until that migration completes.

## What this file does not do

It states no figure, and it names no path that a key already reaches — a path is
written once, in the key table. It does not decide what a record *holds*, which
is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md)'s, nor how supervised a
write is, which is [`WSS.SUPERVISION-LADDER.md`](WSS.SUPERVISION-LADDER.md)'s.
