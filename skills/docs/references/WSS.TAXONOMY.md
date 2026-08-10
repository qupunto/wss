# Taxonomy

The canonical set of subjects an end-to-end application's documentation can cover, in a
fixed hierarchy so that the same concern lands in the same place in every project.

**This is a menu, not a mandate.** A project materializes only the tiers it actually has.
Ten well-filled pages beat forty stubs — an empty or speculative page is a broken promise
(G12), and a tier documented "for completeness" is the fastest way to make the whole site
untrustworthy.

## Two orthogonal axes

Do not conflate them:

- **Subject** — *what* the page is about. That's this document: tiers T1–T11.
- **Document type** — *how* it reads. Two kinds only, matching the existing split:
  - **Guide** (`docs/<page>.md`) — explains how a layer works and why it was built that way.
    Narrative, opinionated, finite.
  - **Annex** (`docs/annex/<topic>.md`) — enumerates that layer's members exhaustively.
    Reference, alphabetical or structural, grows with the codebase.

Every tier can have both. `T4 Client` has a guide (`frontend.md`: how a page is composed)
and annexes (`annex/components.md`: every component's exact props). When a guide page starts
drowning in per-item detail, that detail moves to an annex (G15) — the tier does not change.

## The tiers

Ordered by reading order for a newcomer, not alphabetically. The order is fixed: it is the
sidebar order, and keeping it stable across projects is the point.

| # | Tier | Slug prefix | When |
|---|---|---|---|
| T1 | **Orientation** | — | Always |
| T2 | **Foundations** | — | Always |
| T3 | **Domain** | `domain/` | Any non-trivial business model |
| T4 | **Client** | `client/` or flat | There is a UI (web, mobile, desktop, CLI, TUI) |
| T5 | **Services** | `services/` or flat | There is a server, API, or job runner |
| T6 | **Data** | `data/` or flat | Anything is persisted |
| T7 | **Platform** | — | Always (at minimum auth or config) |
| T8 | **Delivery** | — | It is deployed anywhere |
| T9 | **Quality** | — | More than one person contributes |
| T10 | **Governance** | `governance/` | Regulated, public-sector, or handling personal data |
| T11 | **Annexes** | `annex/` | Any tier has exhaustive per-item detail |

`T1`, `T2`, `T7`, `T8`, `T9`, `T11` are effectively universal. `T4`–`T6` depend on shape.
`T3` and `T10` depend on domain.

---

## T1 — Orientation

The reader has never seen the repo. Always present, always first.

| Page | Covers | When |
|---|---|---|
| `index.md` | Landing: what this is in one paragraph, Contents and Annex tables | Always |
| `WSS.OVERVIEW.md` | Stack tables, quickstart, scripts, env vars, directory tree, key decisions summary | Always |
| `glossary.md` | Domain vocabulary, acronyms, and the terms the code uses differently from the business | Domain has jargon, or the project is bilingual |

`glossary.md` is the most-skipped high-value page. In a project where "equipment", "supply",
and "facility" mean specific different things, it prevents every other page from
re-explaining them.

## T2 — Foundations

Why the system is shaped the way it is. This is the tier that stops documentation from
being a restatement of the code.

| Page | Covers | When |
|---|---|---|
| `architecture.md` | System shape, components and boundaries, request/data flow, deployment topology, diagrams | Always |
| `WSS.DECISIONS.md` or `decisions/` | Design choices with context, alternatives rejected, consequences (ADRs) | Always — inline list when few, one file per decision past ~10 |
| `philosophy.md` | Principles the project optimizes for, explicit **non-goals**, conventions that override defaults | The project has opinions a newcomer would otherwise "fix" |
| `contracts.md` | Where shared types/schemas live and why, the client↔server contract mirror, naming convention, single-source-of-truth rules | Types or schemas are centralized rather than colocated |
| `stack.md` | Dependency inventory with the reason each was chosen | Only when the stack is large enough that `WSS.OVERVIEW.md`'s tables get unwieldy |

**Decisions are the highest-value pages in the whole site.** Format each as: context → the
decision → alternatives considered and why they lost → consequences accepted. One heading
per decision, never edited to hide a reversal — a superseded decision gets a successor
entry that links back, so the reasoning trail survives.

`contracts.md` sits in Foundations rather than under a layer because it is the one page both
sides read: it is the answer to "what must this endpoint return" without reading either the
handler or the component. If the shape is generated from a schema, this page names the
generator and the direction of truth — the most common source of silent client/server drift.

`philosophy.md` earns its place only if it states non-goals. "We optimize for X and
deliberately do not do Y" is useful; a list of virtues is not.

## T3 — Domain

The business model, independent of any framework.

| Page | Covers | When |
|---|---|---|
| `domain/model.md` | Entities, relationships, invariants, identity and ownership rules | The model is non-obvious from the schema |
| `domain/lifecycles.md` | State machines: valid states, transitions, who may trigger them | Anything has a status field |
| `domain/rules.md` | Business rules and calculations, with worked examples | There is arithmetic or eligibility logic anyone could get wrong |
| `domain/workflows.md` | End-to-end journeys across layers: what the user does, what the system does | Multi-step flows exist (onboarding, checkout, approval) |

Past the usual split thresholds (G14/G15), each journey becomes its own
`domain/workflows/<name>.md` in the workflow-page shape — a diagram plus
ordered stages, each stage citing the behaviour record and the implementation —
**→ `references/WSS.WORKFLOW-PAGES.md`**, which owns the shape, the citation
contract and the verified-at stamp.

Keep this tier framework-free. It should stay true if the frontend were rewritten. If a page
here can't be written without naming React or Postgres, its content belongs in T4–T6.

## T4 — Client

Every surface a user touches. Use flat pages (`frontend.md`) for a single client; use
`client/<surface>/` when there are several (web + iOS + Android).

**Web**

| Page | Covers | When |
|---|---|---|
| `frontend.md` | How a screen is composed, layer rules (which layer may fetch), directory conventions | Any web UI |
| `routing.md` | Route definitions, params, guards, loaders, layouts, deep links | Router present |
| `state.md` | Server-state vs client-state, cache keys, invalidation, where state may live | Any non-trivial state management |
| `api-client.md` | How the client talks to the API: request layer, query/cache keys, filter and pagination handling, error and retry policy, which layers may fetch at all | The client consumes a remote API |
| `forms.md` | Validation strategy, error surfacing, submission and optimistic updates | Forms beyond a search box |
| `styling.md` | CSS strategy, token consumption, responsive approach | Non-obvious styling setup |
| `seo.md` | Rendering strategy for crawlers, metadata and structured data, sitemap, canonical URLs | Public, indexable surface |

A promoted group takes a label that fits the project, not the tier name — a mobile app's
promoted T4 pages read better under **App** than under **Client**. Tier membership is what
stays fixed (G17); the sidebar label is presentation.

`api-client.md` (T4) and `api.md` (T5) are different pages with different readers: the first
documents *consuming* a contract — cache keys, invalidation, which layer is allowed to fetch —
and the second documents *offering* one. A frontend-only repo has the first and not the
second; both exist independently in a full-stack repo and neither should restate the other (G6).

**Mobile** — not "frontend with extra pages": navigation graphs, offline sync, permission
timing, background execution, and store release have no web analogue.
**→ `references/WSS.TIER-MOBILE.md`**. Skip unless the project has a mobile app.

**Cross-client**

| Page | Covers | When |
|---|---|---|
| `design-system.md` | Tokens (color, type, spacing, elevation, motion), their source of truth, framework mapping | Any deliberate visual system |
| `i18n.md` | Locale strategy, message catalogs, plural/date/number formatting, RTL, how to add a key | More than one language |
| `accessibility.md` | Target conformance level, keyboard model, focus management, semantics, testing method | Any public-facing UI |

`accessibility.md` (practice) is distinct from `governance/accessibility.md` (T10, formal
conformance statement). Small projects merge them; regulated ones must not.

**Other client shapes** — `cli.md` (commands, flags, exit codes, scripting contract),
`desktop.md` (packaging, auto-update, OS integration), `extension.md` (manifest, permissions,
store review).

## T5 — Services

Everything server-side. Flat pages for a single service; `services/<name>/` in a monorepo.

| Page | Covers | When |
|---|---|---|
| `api.md` | Contract style (REST/GraphQL/RPC), resource conventions, status codes, error envelope, pagination, filtering, idempotency, versioning and deprecation policy | Any API |
| `services.md` | Business-logic layer: module boundaries, transaction ownership, what may call what | Logic lives outside handlers |
| `integrations.md` | Each third party: what it's used for, auth method, failure mode, sandbox vs production, rate limits | Any external dependency |
| `jobs.md` | Queues and schedulers, retry and backoff, idempotency, dead-letter handling, visibility | Background work exists |
| `realtime.md` | WebSocket/SSE protocol, connection lifecycle, auth, reconnection and replay semantics | Live updates exist |
| `webhooks.md` | Inbound and outbound: signature verification, replay protection, delivery guarantees, consumer contract | Webhooks either direction |
| `notifications.md` | Outbound email/SMS/push fan-out, templating, localization of messages, deliverability and bounce handling | The system sends messages to users |
| `files.md` | Upload flow, validation, virus scanning, storage location, signed-URL access | User-supplied files |

`api.md` must state the **versioning and deprecation policy** explicitly. It's the one
promise external consumers depend on and the one most often left implicit.

## T6 — Data

| Page | Covers | When |
|---|---|---|
| `data-layer.md` | Access pattern (repository/ORM/query builder), where SQL may live, connection pooling, transaction boundaries, row-to-domain mapping | Anything queries a store |
| `schema.md` | Tables/collections, relationships, indexes and what each serves, constraints as invariants, ERD | Any relational or structured store |
| `migrations.md` | Tool, forward-only or reversible, naming, how to run, zero-downtime rules for destructive changes | Schema evolves |
| `caching.md` | Layers, key design, TTLs, invalidation triggers, stampede protection, what must never be cached | Any cache |
| `search.md` | Engine, index shape, analyzers, reindex procedure, relevance tuning | Full-text or faceted search |
| `storage.md` | Object storage layout, lifecycle rules, access control, CDN | Blobs/media |
| `analytics.md` | Event taxonomy, pipeline, warehouse models, PII handling in events | Product analytics or a warehouse |

`schema.md` should present constraints as *invariants*, not DDL trivia: a
`check (amount_cents > 0)` is a business rule the database enforces, and saying so is what
makes the page worth reading over `\d+ table`.

Zero-downtime rules in `migrations.md` are the section that prevents outages: expand →
backfill → contract, never rename in place, never drop a column still referenced by the
previous release.

## T7 — Platform

Cross-cutting concerns that belong to no single layer.

| Page | Covers | When |
|---|---|---|
| `auth.md` | Authentication mechanism, session/token lifecycle and refresh, storage, route protection, logout | Any authenticated surface |
| `authorization.md` | Roles, permissions, resource-level rules, where each is enforced, deny-by-default posture | Authorization is more than one boolean |
| `security.md` | Threat model, secret management and rotation, transport and at-rest encryption, security headers, dependency and input-validation posture | Always |
| `configuration.md` | Every setting, its default, precedence order, which are secret, feature flags and their lifecycle | Config beyond three env vars |
| `observability.md` | Log levels and structure, metrics and SLIs, tracing, correlation IDs, dashboards, alert routing | Anything runs in production |
| `resilience.md` | Timeouts, retries with jitter, circuit breakers, graceful degradation, backpressure | Distributed calls exist |
| `performance.md` | Budgets and SLOs, measurement method, known bottlenecks, load-test results | Perf is a stated requirement |
| `errors.md` | Error taxonomy, codes, user-facing messages, reporting pipeline | A defined error contract exists |

Split `auth.md` from `authorization.md` as soon as roles gain nuance — conflating "who you
are" with "what you may do" is where access-control bugs hide.

## T8 — Delivery

| Page | Covers | When |
|---|---|---|
| `environments.md` | Each environment, its URL, its data (real? masked? synthetic?), who can access it, how it differs | More than one environment |
| `ci-cd.md` | Pipeline stages, what gates a merge, required checks, artifact flow, secret handling in CI | Any CI |
| `deploy.md` | Build, containerization, IaC, deployment mechanism, rollback procedure, health checks | Always |
| `release.md` | Versioning scheme, branching model, changelog policy, release checklist, feature-flag rollout | Releases are a process |
| `runbooks/` | One file per operational procedure: symptom → diagnosis → fix → escalation | Anything is on-call |
| `disaster-recovery.md` | Backup schedule and retention, restore procedure **with last-tested date**, RPO/RTO | Data loss would matter |

Two rules earn their keep here. **A rollback procedure that has never been executed is a
hypothesis** — say when it was last exercised. **An untested backup is not a backup** —
`disaster-recovery.md` must carry the date of the last successful restore drill, and an
absent date is itself the finding.

## T9 — Quality

| Page | Covers | When |
|---|---|---|
| `testing.md` | What is tested at which level and why, fixtures and factories, test data, coverage stance, how to run | Tests exist |
| `code-standards.md` | Linting and formatting, naming conventions, patterns that are house style, patterns that are banned and why | Conventions aren't fully machine-enforced |
| `contributing.md` | Branch naming, commit convention, PR expectations, review criteria, definition of done | More than one contributor |
| `local-setup.md` | Full environment bring-up, seed data, common failure modes and fixes | Setup exceeds `install && dev` |

`code-standards.md` should document only what the linter *cannot* enforce. Anything a rule
already catches belongs in the config, not prose.

## T10 — Governance

Compliance, legal, and organizational obligations. **Include a page only when an obligation
actually applies** — a speculative compliance page is a liability, not diligence. Not legal
advice: this tier states the obligation, points at the implementation, points at the evidence.

`governance/licensing.md` (dependency licenses + SBOM) applies to nearly every project;
`privacy.md`, `accessibility.md`, `audit-trail.md`, `data-governance.md` apply on condition.

**→ `references/WSS.TIER-GOVERNANCE.md`** for the page table and the sector framework map
(ISO 27001/SOC 2, PCI DSS, HIPAA, GxP/GLP, 21 CFR Part 11, EU AI Act, CRA, DORA/PSD2,
IEC 62304/MDR, ENS). Load only when one is in scope.

## T11 — Annexes

Exhaustive per-item reference, one page per enumerable set:

`annex/components.md`, `annex/modules.md`, `annex/endpoints.md`, `annex/design-tokens.md`,
`annex/error-codes.md`, `annex/configuration.md`, `annex/cli.md`, `annex/events.md`,
`annex/permissions.md`, `annex/storybook.md`, `annex/WSS.CLAUDE-TOOLING.md`.

`annex/WSS.CLAUDE-TOOLING.md` is the one annex whose source is another skill's record rather than
the codebase: `--wss-tools` owns `WSS.record.tooling.catalog` and hands it over, and this page is the
adaptation. Include it when the project has skills or agents of its own — the catalog it
derives from is addressed to Claude and sits outside the site, so without this page a person
reading the docs finds no account of how the repository is worked on.

An annex exists when the set is large enough that a reader wants lookup rather than
narrative. Below roughly six items, keep it as a table on the guide page (G14).

---

## Assembling a site

### Select

1. Identify the project's shape → pick a profile below.
2. Walk the tiers in order. For each page, ask **does this exist in the codebase today?**
   Not "should it" — G8 forbids documenting intent as fact.
3. Drop every tier that is empty. A CLI tool has no T4-web, no T6, and possibly no T5.
4. Merge aggressively at small scale: a three-file service can carry T5+T6+T7 as three
   `##` sections of one `backend.md` (G14). Split when a page exceeds roughly 250 lines or
   two unrelated audiences.

### Profiles

**Which profile a project is, and the signals behind it, are
[`WSS.PROJECT-SHAPE.md`](../../../workflow/WSS.PROJECT-SHAPE.md)'s** — one detector, so
this skill and `--wss-stocktake` cannot reach different conclusions about the same repo.
What a profile *implies for documentation* is this table's, and stays here.

| Profile | Tiers, minimum viable set |
|---|---|
| **Web app** | T1, T2, `frontend`+`routing`+`state`, `design-system`, `i18n`, `auth`, `deploy`, `testing`, `annex/components` |
| **Mobile app** | T1, T2, `mobile/*` (overview, navigation, offline, platform, release), `design-system`, `auth`, `api` (as consumer), `testing` |
| **API / service** | T1, T2, T3, `api`, `services`, `data-layer`+`schema`+`migrations`, `auth`+`authorization`, `observability`, `deploy`, `testing` |
| **Full-stack product** | All of the above, plus `environments`, `runbooks/`, `governance/privacy` |
| **Library / SDK** | T1, T2, `api` (public surface), `versioning` under `release`, `contributing`, `annex/` reference — no T6, T8-deploy |
| **Data / ETL** | T1, T2, T3, `data-layer`, `schema`, `migrations`, `jobs`, `analytics`, `observability`, `governance/data-governance` |
| **Monorepo** | T1, T2 at root; per-package subtrees mirroring the relevant profile; one `architecture.md` owning cross-package boundaries |

### Promotion

When a tier is the project's center of gravity, promote its pages to top-level sidebar
entries instead of nesting them. A mobile-first product surfaces
`Navigation / Offline / Release` directly rather than burying them under **Mobile**; an API
product promotes `Endpoints / Errors / Versioning`. The taxonomy fixes *which tier a subject
belongs to*, not how deep it sits in the sidebar.

### Naming

- **Files**: lowercase kebab-case, no numeric prefixes (they leak into URLs and reorder
  badly). Sidebar order comes from `_sidebar.md`, which is hand-written and follows tier
  order.
- **Directories**: only when a tier has three or more pages. Two pages stay flat.
- **Never translate filenames** across language mirrors (G13).
- One subject, one page. If two pages both explain caching, one of them is wrong (G6).

### Sidebar assembly

Tier order, with bold non-link group headers and a blank line between groups. Docsify nests
via indentation:

```markdown
- [Home](/)
- [Overview](/WSS.OVERVIEW.md)
- [Glossary](/glossary.md)

- **Foundations**
- [Architecture](/architecture.md)
- [Design decisions](/WSS.DECISIONS.md)

- **Client**
- [Frontend](/frontend.md)
- [Routing](/routing.md)
- [Design system](/design-system.md)
  - [Tokens](/annex/design-tokens.md)

- **Services & data**
- [API](/api.md)
- [Data layer](/data-layer.md)
- [Schema](/schema.md)

- **Platform**
- [Authentication](/auth.md)
- [Observability](/observability.md)

- **Delivery**
- [Deploy](/deploy.md)
- [Runbooks](/runbooks/)

- **Governance**
- [Privacy](/governance/privacy.md)
- [Licensing](/governance/licensing.md)

- **Annex**
- [Components](/annex/components.md)
- [Endpoints](/annex/endpoints.md)
```

Group headers appear only once a group holds two or more pages — a bold header over a single
link is noise. `index.md`'s Contents table mirrors these groups as `##` sections.

## Anti-patterns

- **Tier-shaped emptiness** — a heading per tier with a sentence under each. Worse than
  omitting the tier: it signals coverage that isn't there.
- **Documenting the framework** — `routing.md` explaining what a router is. Document *this*
  project's use of it, and link out for the rest.
- **Compliance theatre** — a `governance/` page restating a regulation without mapping it to
  implementation and evidence.
- **The orphan tier** — pages nobody links to and the sidebar forgot. Every page is reachable
  from `_sidebar.md` and `index.md` (G12).
- **Duplicated caching** — the same concern explained under both T5 and T6 because it
  spans them. Pick the owner, link from the other (G6).
- **Frameworks in T3** — domain pages naming React or Postgres. That content belongs in
  T4–T6.
