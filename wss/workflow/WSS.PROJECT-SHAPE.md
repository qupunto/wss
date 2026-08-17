# Project shape

**What kind of project this is, decided once.** Several skills need the answer
and they need the *same* answer: `--wss-docs` maps it to which pages a project owes,
`--wss-stocktake` maps it to which dimensions to run. Detecting it twice means two
detectors that agree until they don't, and nothing that notices when they stop.

So detection lives here. **The mappings stay with the skills that own them** —
what a shape implies for documentation is not what it implies for an audit, and
merging those would be the opposite mistake.

## Signals

Atomic, independent, and each established by evidence in the repo rather than by
asking. A project is a *set* of these, not one label.

| Signal | Present when the repo has |
|---|---|
| `ui` | Rendered views — components, templates, screens, styling systems |
| `service` | Something long-running that listens: an HTTP/RPC server, a queue consumer, a scheduled job runner |
| `persistence` | A schema, migrations, or a configured data store |
| `public-api` | A surface others consume: exported library entry points, a published package, a documented HTTP API |
| `cli` | An argument parser and an executable entry point |
| `pipeline` | Scheduled or triggered data movement — extract/transform jobs, DAGs, batch processing |
| `tests` | A test directory, or a resolvable test command |
| `ci` | Build or CI configuration |
| `multi-package` | Several independently-versioned packages in one repo |
| `mobile` | A native or cross-platform mobile target |

**Absent is a finding, not a silent skip, for `tests` and `ci`.** Every other
signal is simply a fact about the project. Those two are things a project is
usually poorer for lacking, so the skill that notices says so rather than
quietly running one fewer check.

## Profiles

Named combinations, for when a skill wants a shorthand. A profile is a
*starting point* — the signals are the truth, and a project that contradicts its
profile follows its signals.

| Profile | Signals |
|---|---|
| Web app | `ui`, `service`, `persistence` |
| Mobile app | `mobile`, `ui` |
| API / service | `service`, `persistence`, `public-api` |
| Full-stack product | `ui`, `service`, `persistence`, `public-api` |
| Library / SDK | `public-api` |
| CLI tool | `cli` |
| Data / ETL | `pipeline`, `persistence` |
| Monorepo | `multi-package`, plus whatever its packages are |

## Rules

**Detect from evidence, never from the project's name or its README's claims.**
A repo describing itself as a library while shipping a server is a project with
both signals, and possibly a finding.

**Signal names are stable.** Skills key off them, and `--wss-stocktake` records
dimensions derived from them in a record that later audits join against — see
[`WSS.AUDIT-COVERAGE.md`](WSS.AUDIT-COVERAGE.md).

**When a signal is ambiguous, say so and treat it as present.** The cost of
running one extra documentation page or audit dimension is small; the cost of
silently omitting one is a gap nobody knows about.

## Who consumes this

| Skill | Maps shape to |
|---|---|
| `--wss-docs` | Page sets, via its own tier taxonomy |
| `--wss-stocktake` | Which dimensions run, in its Phase 0 |
| `--wss-adopt` | Which records a project needs, and therefore which manifest keys to propose |

A skill consuming this file states which signals it acted on, so a reader can
tell a deliberate omission from an oversight.
