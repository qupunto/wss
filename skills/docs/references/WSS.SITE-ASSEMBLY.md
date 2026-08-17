# Assembling a whole site

Loaded on demand from `WSS.TAXONOMY.md`. Read this in Scaffold mode, when the question is
*what page set does this whole project need, and in what order do the pages sit in the
sidebar*. A New-page or Update decision consults one tier row and never needs this file.

Renderer config — docsify options, the scaffold script, wiring the site into the project —
is `WSS.SITE-SETUP.md`'s. This file is about which pages exist and how they are ordered.

## Profiles

**Which profile a project is, and the signals behind it, are
[`WSS.PROJECT-SHAPE.md`](../../../wss/workflow/WSS.PROJECT-SHAPE.md)'s** — one detector, so
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

A profile names the minimum, not the ceiling: a tier stays out of the set until the thing it
documents exists in the codebase today.

## Sidebar assembly

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

The order is the tier order `WSS.TAXONOMY.md` fixes, which is reading order for a newcomer
and never alphabetical. Keeping it stable across projects is what lets a reader who knows one
project's site navigate the next one.
