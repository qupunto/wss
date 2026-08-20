---
name: docs
description: "Author and maintain a project's long-form documentation site, every claim anchored to an exact source path. Invoke on `--wss-docs`, `/wss:docs`, \"document this project / feature / module\", \"write docs for X\", \"update the docs after <change>\", \"set up docs\", \"audit docs\", or a request for an ADR, architecture write-up, runbook, glossary, translation or onboarding guide."
---

# docs

Renders as a docsify site by default — plain markdown that also reads correctly on GitHub.

## Invocation

`/wss:docs` invokes this skill by name, and `--wss-docs` fires it through the hook — both are the same
request. (`--wss-diagram` also lands here: a single inline diagram routed into the
site's annex, with the whole procedure carried by that flag's hook block rather
than by a section of this file.) Bare, either means *document what we just worked on*: infer the target from
the conversation — the files touched this session, the feature just built — and say what you
picked before writing. With an argument (`--wss-docs auth`, `--wss-docs the map module`) that's the
target.

**`--wss-adopt` also invokes this** when it finds a project with no documentation at all, wanting
Scaffold mode and the overview page — not a full site. It confers its own grant, which is
commit and not push, so what gets scaffolded there may be committed even though this flag
alone authorizes nothing.

**`--wss-catalog` does not come through here once the page exists.** A changed
`WSS.record.tooling.catalog` is a mechanical re-derivation, so it goes straight to
`docs-writer` with the catalog as the
source — the interaction diagram included, which that procedure re-renders for this
site's renderer rather than reshaping by hand. This skill is reached only when the
**Claude tooling** annex page does not exist yet, because that is a placement
decision (T11) and placement is what this skill is for.

## The two records this skill does not write

`WSS.record.behaviour` and `WSS.record.reference` each have their own primitive —
`behaviour-writer` and `reference-writer`, named here and not linked: this skill
never reads either contract itself, only the owning skill does, the same plain-name
convention the table below already uses for `changelog-writer`, `git-writer` and the
rest. This skill decides what **the site** holds and `docs-writer` writes it; those
two files are records, not pages, and belong to neither.

**Dispatch findings about them straight to the owner** — `--wss-health-check`
and `--wss-start` do this already; the split is
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#when-to-split)'s.

What stays here is the judgement, not the write: **whether a subject belongs on
the site at all**, which tier it lands in (`references/WSS.TAXONOMY.md`, G17), and
whether a page is owed. Where a subject turns out to be a runtime rule or a piece
of reference material rather than a guide page, hand it to the owning primitive
and say so — do not write it into a page instead.

## Not this skill

This skill owns exactly one job: deciding what the
long-form docs site under `docs/` should hold. Hand these back instead of firing:

| Request | Belongs to |
|---|---|
| Docstrings, JSDoc, TSDoc, inline comments | Ordinary code editing — just write them |
| OpenAPI/Swagger annotations in handlers | Ordinary code editing (the *guide* to the API is this skill) |
| `CLAUDE.md` — instructions for agents, not humans | `handoff-writer`, which owns it as the session handoff |
| Changelog entries | `changelog-writer`, which owns `WSS.record.changelog` |
| Commit messages | `git-writer`, which owns the history |
| PR descriptions | `pr` (`--wss-pr`), which drafts the body from the branch range. It is not a record and is never written to a file here |
| A one-line README tweak | Just edit it; no site, no taxonomy — **unless** the manifest maps the README into `WSS.record.reference`, which makes it `reference-writer`'s |
| A runtime rule, or stack/architecture/data-model material | `behaviour-writer` and `reference-writer`, which own `WSS.record.behaviour` and `WSS.record.reference` |
| A project's *append-only* record — TODO list, roadmap, decision log, audit log | The record primitives: `--wss-todo`/`--wss-log`, `--wss-plan`, `--wss-health-check --deep`'s TODO resort for the audit log. Appending a dated entry is not writing a page, and those files are never placed by tier |

**A project-scoped docs skill wins.** If `.claude/skills/` contains a skill that owns this
project's documentation, it encodes conventions this one cannot know — defer to it and say so.
Only step in for the part it explicitly does not cover.

## Modes

Determine the mode first; they don't overlap. Detect the existing setup before anything else:

```bash
ls docs/ doc/ documentation/ website/ 2>/dev/null
ls mkdocs.yml docusaurus.config.* mint.json .vitepress 2>/dev/null   # a different renderer?
ls .claude/skills/ 2>/dev/null                                       # a project docs skill?
cat docs/index.html docs/_sidebar.md 2>/dev/null                     # docsify?
```

**A `WSS.docs` block in `.claude/WSS.WORKFLOW.json` is the authority wherever it is declared,
and the probe above is only the fallback**: `root` names the site directory (absent, the first
of `docs/`, `doc/`, `documentation/`, `website/` that exists), `languages` lists the root
language first and each translation subdirectory at `<root>/<lang>/` after it (absent means
monolingual), and `devCommand` is the live-render command (absent, that step is skipped).

| Condition | Mode | Go to |
|---|---|---|
| A project-scoped docs skill exists | **Defer** — hand off, don't duplicate | — |
| No docs directory anywhere | **Scaffold**, then write the first page | [`references/WSS.MODE-SCAFFOLD.md`](references/WSS.MODE-SCAFFOLD.md) |
| Target has no page or section yet | **New page** (or new `##` section) | [`references/WSS.MODE-WRITE.md`](references/WSS.MODE-WRITE.md) |
| Target is already documented, and code has changed | **Update** — rewrite the affected sections only | [`references/WSS.MODE-UPDATE.md`](references/WSS.MODE-UPDATE.md) |
| Asked to check/verify/audit docs, or a refactor just landed | **Audit** | [`references/WSS.MODE-AUDIT.md`](references/WSS.MODE-AUDIT.md) |
| Asked to add or refresh a language | **Translate** | [`references/WSS.TRANSLATIONS.md`](references/WSS.TRANSLATIONS.md) |

**Read each mode's reference file right before running that mode, and follow it in
full** — each is the whole of what that mode *decides*. What follows below is
cross-mode policy and is read every time; no mode's own procedure is, except
through this table.

**Audit mode is about this site's *internal correctness*** — do the paths exist, do links and
anchors resolve, do enumerations and `## Key files` still match source. It is not about whether
a project's record *owes* an update: "a diff touched the routes and `WSS.BEHAVIOUR.md` never changed"
is `--wss-health-check`'s finding, not this skill's. Don't run both against the same request.

**An existing site is the authority on its own conventions** — read two or three of its pages
first and match them wherever they differ from this skill. When a project states those
conventions machine-readably — `WSS.record.*` in a `.claude/WSS.WORKFLOW.json` naming files at fixed
locations — that declaration is the authority: those files keep their paths, skip tier
placement (G17) and skip sidebar wiring (G12), and you update them in place.

That includes the renderer. Everything in this skill except `references/WSS.SITE-SETUP.md` and the
sidebar/link mechanics is renderer-agnostic: on MkDocs, Docusaurus, VitePress, Mintlify, or a
plain markdown folder, keep the guidelines, the taxonomy, and the audit checks, and swap only
the navigation file and link syntax for that tool's. Never migrate a project to docsify because
this skill prefers it.

## Guidelines

**The guidelines are
[`references/WSS.GUIDELINES.md`](references/WSS.GUIDELINES.md)**, shared with the
writer and the audit method rather than owned here — a numbered list cited from
across the reference set has no business living inside any one of its consumers.

G14, G15 and G17 — extend before adding, push per-item detail to the annex, place
by tier — are this skill's, and settling them is the whole of what it decides
before handing over. Every other number governs the writing and travels with
`docs-writer` — its own per-mode reference file names what it loads.
