# Rules Index

The authority for every checker, hook, and verifier. This is the only file ever loaded without being asked for.

---

## The standing tie-break

> **transparency > reliability > efficiency**

This principle sits above all precedence tiers because it is the function that decides rank. Rules are ordered by this hierarchy; where two of them pull apart, the higher wins and the cost is stated rather than absorbed.

---

## Tier 0 — Global rules

These rules trump everything, at every scope.

| Global rule | Custody today |
|---|---|
| One source of truth — a concept is written once; a copy becomes a pointer | definable |
| No duplication of functionality | definable |
| Every record file has exactly one writer | definable |
| Do not add prose to explain a decision — log it and point at the log | definable |
| A figure carries what recomputes it | DOC · held |
| Logs are never rewritten | APPEND · held |
| A record holds only its own — decisions is not an exception | undefinable |
| Skills are never modified on the fly — file an open decision or a hazard | undefinable |
| Ask for a ruling; never narrow an absolute rule with a self-authored exemption | undefinable |
| A session never derives a rule that binds globally — the mirror of the row above, and the half nothing catches | undefinable |
| Every decision is judged by rules; where none exists, notify and create one | undefinable |
| The appropriate agent at the appropriate model tier | HOOK · held |
| Skill creation goes through the guidelines checklist | definable |

**Source:** The Tier 0 table is canon. It contains 13 global rules. The design source's prose stating "Twelve rules" was inaccurate.

---

## Conflict-type triage and precedence tiers

Before any precedence tier is consulted, answer: **What kind of disagreement is this?**

A rule against its own check is NOT a precedence question. If a rule contradicts the mechanism that should enforce it, the check is defective or the rule moved without it — route to hazard or todo and fix, never resolve by rank. Why this step exists: skipping it is how a broken check wins. A drifted duplicate held CI red for eleven commits while both halves looked authoritative.

A rule against a different rule IS a precedence question. Continue to the tiers.

### Tier 0 — Global

Global rules (the table above) trump everything, at every scope. They are not subject to scoped overrides.

### Tier 1 — Scoped rules

All other rules, ranked by nothing inherent. Ties inside this tier are real and common — two behavioural rules of equal scope pulling opposite ways happen regularly. When two scoped rules collide with no higher tier to break the tie, a per-collision `precedence` field (named in the row schema below) naming the winning rule id stays in the row schema as a tiebreaker.

---

## Consumer resolution table

This is the many-to-many relation: which judge files a given consumer needs to read. This is a worked example from the design spec — extend as consumers are actually resolved. Not yet exhaustive over this project's skills, hooks, and agents.

| Consumer | Files it needs |
|---|---|
| `skills/record` | `WSS.RULES-INDEX.md` · `WSS.RULES-APPEND.md` · `WSS.RULES-PROV.md` · `WSS.RULES-SESSION.md` · `prospective/WSS.RULES-DOC.md` |
| `skills/release` | `WSS.RULES-INDEX.md` · `WSS.RULES-PUB.md` · `WSS.RULES-CI.md` · `WSS.RULES-SESSION.md` |
| `hooks/wss-session-check.sh` | `WSS.RULES-INDEX.md` · `WSS.RULES-DOC.md` |
| `wss/tests/wss-doctor.sh` | `WSS.RULES-INDEX.md` · `WSS.RULES-DOC.md` · `prospective/WSS.RULES-DOC.md` |
| `agents/wss-execute` | `WSS.RULES-INDEX.md` · `WSS.RULES-SESSION.md` |

---

## Row schema

Rules are formatted for machine readability: each rule has a `### <ID>` heading (the immutable id), followed by one bold `**field:**` line per field, with optional fields omitted entirely rather than written empty. This structure provides grep-ability, pipe-safety to downstream tools, and real heading anchors (e.g., `WSS.RULES-APPEND.md#rec-021`) that `wss-doctor.sh`'s existing anchor validation can verify directly.

For example — the placeholder `<ID>` is the same notation the paragraph above
uses, deliberately, so this block carries no rule id. It used to show
`REC-APPEND-001`, whose live row in `wss/rules/WSS.RULES-APPEND.md` had since
been rewritten to a different rule under the same id: two rules, one id, in the
section that declares ids unique and immutable. A worked example is also a
second copy that nothing keeps in step, so this one holds field names and no
values.

```markdown
### <ID>

**statement:** <one imperative sentence>

**kind:** <enum>

**tier:** <enum>

**custody:** <judge> · <state>

**mechanism:** <enum>

**consequence:** <enum>

**evidence:** <path:line or log anchor>
```

When a rule is added to any judge's file, it carries these eleven fields:

- **`id`** (required, immutable): A unique identifier for this rule. Once assigned, never changes. The scheme is `<DOMAIN>-<JUDGE>-<NNN>`: a domain prefix (assigned at Design time), the judge holding the rule when assigned, and a zero-padded three-digit sequence unique within that domain-judge pair. Because the id is immutable, a custody move to a different judge never renumbers it — the `custody` field is the live answer to which judge holds the rule now, while the id's judge segment records which judge held it at assignment.
- **`statement`** (required): One imperative sentence stating the rule itself. The core rule, not explanation or rationale.
- **`kind`** (required, enum): The type of rule: `prohibition` (forbidden), `requirement` (must do), `default` (assumed unless stated otherwise), `routing` (directs which judge or mechanism owns this), or `precedence` (settles a collision between other rules).
- **`tier`** (required, enum): The rule's precedence tier: `global` (trumps everything) or `scoped` (ordinary rule, tied by nothing inherent). There are two, and a third is not to be added — `exception` was withdrawn as a tier that had entered by transcription rather than by decision.
- **`custody`** (required): Which judge holds this rule, plus its state. One of: `DOC · held`, `DOC · definable`, `HOOK · held`, `HOOK · definable`, `APPEND · held`, `APPEND · definable`, `PROV · held`, `PROV · definable`, `PUB · held`, `PUB · definable`, `CI · held`, `CI · definable`, or `undefinable` (SESSION only). The judge and state move a rule between files.
- **`mechanism`** (required if held): The technical means that detects a breach. One of: `doctor-check`, `contract-test`, `ci-step`, `git-hook`, `pretooluse-hook`, `permission-rule`, `publish-gate`, `script-internal`, `checklist`, or `ladder-step`. The last two of the hook family are the harness tool layer — a `PreToolUse` deny hook, and a `settings.json` permission rule — and they file under the HOOK judge rather than a judge of their own.
- **`consequence`** (required per venue): What happens when the rule is broken. One of: `refuse` (stop the operation), `fail` (return exit code 1), `report` (log and continue), or `silent` (observed but not acted on).
- **`precedence`** (optional): A rule id — the winner when this rule ties with another scoped rule of equal scope. Appears only in Tier 1 scoped rules where a specific collision has been observed.
- **`evidence`** (optional): A log anchor or file reference — fetched only when a ruling is unclear, never loaded to apply the rule itself. Used for tracing rationale but not for enforcement.
- **`supersedes`** (optional): Written on a replacement row, names the retired id it replaces. Ids stay immutable and are never reused; a correction to an existing rule stays in place under its own id, while only a genuine replacement gets a new row.

### Domain prefixes

Domain prefixes are assigned at Design time and listed here. Each prefix is paired with a `<JUDGE>-<NNN>` sequence unique to that domain.

| Prefix | Domain it covers |
|---|---|
| `REC` | Records |
| `OWN` | Ownership |

---

**Source:** wss/logs/WSS.DECISIONS.md's `2026-08-17 (eighth)` entry.
