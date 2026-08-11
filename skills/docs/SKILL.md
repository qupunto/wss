---
name: docs
description: "Author and maintain a project's long-form documentation site, every claim anchored to an exact source path. Invoke on `--wss-docs`, `/wss:docs`, \"document this project / feature / module\", \"write docs for X\", \"update the docs after <change>\", \"set up docs\", or a request for an ADR, architecture write-up, runbook, glossary, translation or onboarding guide."
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

**`--wss-tools` does not come through here once the page exists.** A changed
`WSS.record.tooling.catalog` is a mechanical re-derivation, so it goes straight to
[`docs-writer`](../../workflow/writers/WSS.DOCS-WRITER.md) with the catalog as the
source — the interaction diagram included, which that procedure re-renders for this
site's renderer rather than reshaping by hand. This skill is reached only when the
**Claude tooling** annex page does not exist yet, because that is a placement
decision (T11) and placement is what this skill is for.

## The two records this skill does not write

`WSS.record.behaviour` and `WSS.record.reference` each have their own primitive —
[`behaviour-writer`](../../workflow/writers/WSS.BEHAVIOUR-WRITER.md) and
[`reference-writer`](../../workflow/writers/WSS.REFERENCE-WRITER.md). This skill decides
what **the site** holds and [`docs-writer`](../../workflow/writers/WSS.DOCS-WRITER.md)
writes it; those two files are records, not pages, and belong to neither.

**Dispatch findings about them straight to the owner** — `--wss-check`,
`--wss-full-check`, `--wss-start` and `--wss-stocktake` do this already; the split is
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md#when-to-split)'s.

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
| A project's *append-only* record — backlog, roadmap, decision log, audit log | The record primitives: `--wss-todo`/`--wss-log`, `--wss-plan`, `--wss-stocktake`. Appending a dated entry is not writing a page, and those files are never placed by tier |

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
| No docs directory anywhere | **Scaffold**, then write the first page | [Plan](#plan), then [Scaffold](#scaffold), plus `references/WSS.SITE-ASSEMBLY.md` — the only mode that reads it |
| Target has no page or section yet | **New page** (or new `##` section) | [Write](#write) |
| Target is already documented, and code has changed | **Update** — rewrite the affected sections only | [Update](#update) |
| Asked to check/verify/audit docs, or a refactor just landed | **Audit** | [`workflow/checks/WSS.DOCS-AUDIT.md`](../../workflow/checks/WSS.DOCS-AUDIT.md) |
| Asked to add or refresh a language | **Translate** | `references/WSS.TRANSLATIONS.md` |

**Audit mode is about this site's *internal correctness*** — do the paths exist, do links and
anchors resolve, do enumerations and `## Key files` still match source. It is not about whether
a project's record *owes* an update: "a diff touched the routes and `WSS.BEHAVIOUR.md` never changed"
is `--wss-check`'s finding, not this skill's. Don't run both against the same request.

### Audit scope

Resolving it is this skill's job, not the method's — a method that picked its own scope
could not be borrowed by a caller that wants a different one.

Sections 1–7 are shell. They run over the whole site in seconds and there is nothing to
save by narrowing them — **always run them in full.** Section 8's second half is the
expensive one: re-reading source files page by page. That is what the checkpoint is for,
and `--wss-full-check` is what forces every page to be re-read.

Ask `sweep-tracker` to resolve the entry `docs`, with two scopes:

| Scope | Incremental? | `covered` |
|---|---|---|
| `mechanics` | No — the scripts are cheap and a whole-site run is the point | `[]` |
| `accuracy` | Yes | the pages whose claims were re-read against source this run |

**A page needs re-reading when the page changed, or when any source file it names
changed.** G3 is what makes that mechanical — every claim is attributed to a backticked
path at the point it is made, so a page's dependencies are already written down in it:

```bash
BASE=<baseline sha>
CHANGED=$(git diff --name-only "$BASE"..HEAD)
for f in $(find docs -name '*.md'); do
  git diff --quiet "$BASE"..HEAD -- "$f" || { echo "STALE (page edited): $f"; continue; }
  # every backticked path the page attributes a claim to
  deps=$(grep -ohE '`[A-Za-z0-9_.$/-]+/[A-Za-z0-9_.$/-]+`' "$f" | tr -d '`' | sort -u)
  for d in $deps; do
    printf '%s\n' "$CHANGED" | grep -qF "$d" && { echo "STALE (source moved): $f <- $d"; break; }
  done
done
```

Everything that prints is in scope. Everything else was verified at `$BASE` and neither it
nor anything it cites has moved since.

**A page carrying its own verified-at stamp is compared against that stamp, not
`$BASE`.** Workflow pages write one (`references/WSS.WORKFLOW-PAGES.md`), and it
is the commit that page's claims were last read against — later than the site
baseline whenever the page was verified since the last sweep, so using `$BASE`
for it re-reads sources it has already been checked against. Read the stamp out
of the page's header and substitute it for `$BASE` on that page's dependencies
alone. Its other half does not apply: an edit to a workflow page *is* a
verification, so "the page changed" never puts one back in scope.

**Two things void the narrowing entirely**, because they change what a correct page even
looks like:

- **A page with no backticked source path at all.** It has no detectable dependencies, so
  the diff can never mark it stale. It is `not-covered` unless read — never silently clean.
- **A change to the docs' own conventions** — the taxonomy, the style guide, `_sidebar.md`
  structure. Those invalidate every page's *form*, not just its facts.

**When in doubt, widen.** A page wrongly skipped reports clean while asserting something
false.

Stamp at the end through `sweep-tracker`: the baseline, and per scope what was covered.
The rules constraining what may be claimed are
[`WSS.SWEEP-CHECKPOINT.md`](../../workflow/WSS.SWEEP-CHECKPOINT.md).


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

## Plan

Two modes decide something before anything is written, and they ask different questions.

**New page is one line — decide the tier row, write the page, wire it up.** The site already
exists, which is what makes the mode New page rather than Scaffold, so there is no page set to
settle and no tier walk to do: [Write](#write) is that line end to end, and the mode table
routes straight to it. `references/WSS.SITE-ASSEMBLY.md` is never loaded here, and nothing
numbered below applies.

**Scaffold decides a page *set*, and the numbered procedure is its alone.**
`references/WSS.TAXONOMY.md` defines the canonical tiers (T1–T11), the pages under each, and
an include-when rule per page; the minimum viable set per project profile is
`references/WSS.SITE-ASSEMBLY.md`'s, which only this mode loads.

1. Identify the project's shape ([`workflow/WSS.PROJECT-SHAPE.md`](../../workflow/WSS.PROJECT-SHAPE.md)),
   pick the closest profile, and take its minimum viable set from
   `references/WSS.SITE-ASSEMBLY.md`.
2. Walk the tiers in order, keeping a page **only if the thing it documents exists in the
   codebase today** — not if it should (G8). Drop every tier that comes up empty: a CLI
   tool has no T4-web, no T6, and possibly no T5.
3. Merge at small scale, split at large: below ~6 items keep a table on the guide page;
   past ~250 lines or two audiences, split (G14, G15).
4. **State the proposed page set before writing it**, in tier order, and say what you
   dropped and why. Then write pages one at a time, wiring each up as you go (G12).

Never emit the whole tier list as headings-with-a-sentence — the walk's own failure mode, and
no other mode walks it. Tier-shaped emptiness signals coverage that isn't there and discredits
the pages that are real.

**Whichever mode is owed them, pages decided and not yet written are state, and this skill
stores none.** Hand the unwritten ones to `--wss-todo` so they outlive the session in the
project's backlog, and `--wss-track` them within it. Never keep the plan only in the reply —
on a large site that is how half a documented codebase silently becomes the whole record of
what was intended.

## Guidelines

**The guidelines are
[`references/WSS.GUIDELINES.md`](references/WSS.GUIDELINES.md)**, shared with the
writer and the audit method rather than owned here — a numbered list cited from
across the reference set has no business living inside any one of its consumers.

G14, G15 and G17 — extend before adding, push per-item detail to the annex, place
by tier — are this skill's, and settling them is the whole of what it decides
before handing over. Every other number governs the writing and travels with
[`docs-writer`](../../workflow/writers/WSS.DOCS-WRITER.md).

## Scaffold

Only when no docs directory exists. The script creates the shell — never content:

```bash
# Resolve the suite root: a checkout wins, otherwise the plugin's versioned
# cache. Why it is done this way rather than from a variable — the variable
# reaches hooks, never the Bash tool — is recorded in the `contracts` skill.
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)

bash "$S"/skills/docs/assets/wss-scaffold.sh "<Project Name>" [root-lang [translation-lang ...]]
```

**The docs root is not an argument.** The script resolves it from `WSS.docs.root` and that
key's declared fallback chain ([`WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md)), and
announces the root it resolved — passing a literal `docs` here is how a project whose
manifest says `website` gets scaffolded into the wrong tree. Override it only to scaffold
somewhere the manifest does not yet describe, with `--root <dir>` before the project name.

```bash
bash "$S"/skills/docs/assets/wss-scaffold.sh "Acme UI"                # monolingual
bash "$S"/skills/docs/assets/wss-scaffold.sh "SIME UI" en ca          # root English, <root>/ca/ Català
bash "$S"/skills/docs/assets/wss-scaffold.sh --root website "Acme UI" # override the resolved root
```

It refuses to touch an existing directory, skips `_navbar.md` unless multilingual, and
prints the remaining steps it deliberately does not do: the `docs:dev` script and
`docsify-cli` dependency, the README pointer, and the `{{INTRO}}` placeholder. Do those,
then continue into [Write](#write) — starting with `WSS.OVERVIEW.md`, which inventories the
stack, scripts, env vars, and directory tree that every later page links back to.

Config rationale and the manual equivalent: `references/WSS.SITE-SETUP.md`.

## Write

**This skill places; the writer writes.** Placement is the only decision here.

1. **Place it** (G17, then G14/G15). Find the subject's tier in
   `references/WSS.TAXONOMY.md`. Then: guide page → `docs/<concern>.md`;
   exhaustive item-by-item reference → `docs/annex/<topic>.md`; too small for
   either → a `##` on the closest existing page. An end-to-end flow past the split
   thresholds is a **workflow page** — `references/WSS.WORKFLOW-PAGES.md` owns that
   shape, its citation contract and its stamp.
2. **Hand the target and its source to
   [`docs-writer`](../../workflow/writers/WSS.DOCS-WRITER.md)** — which reads the
   source, drafts from the skeletons, wires up `_sidebar.md`, `index.md` and every
   mirror, and verifies. Name the page and the tier you chose; it hands back a
   target that contradicts the taxonomy rather than relocating it quietly.

## Update

Already documented, and the code moved. **Nothing here is decided** — the page
exists and its tier was settled when it was created — so this mode is a hand-off
in full. Give [`docs-writer`](../../workflow/writers/WSS.DOCS-WRITER.md) what
changed and the pages that describe it; the diff, the grep for every mention, the
rewrite of affected sections only, the mirrors and the verify are all its.

**A caller that changed a source some page derives from reaches the writer
directly and never comes through here** — `--wss-tools` handing over the tooling
catalog is the standing case. Routing a mechanical re-derivation through this
skill buys nothing but the cost of loading it, and that cost is paid in the
caller's context, at whatever size it has already reached.

## References

**What this skill loads**, being everything it needs to decide:

| File | Read it when |
|---|---|
| `references/WSS.GUIDELINES.md` | Always, in practice — G-numbers are cited here and in every other reference, so the gate is never false. It is a separate file because several consumers cite it and none owns it, not because it can be skipped; G14, G15 and G17 are this skill's, the rest the writer's |
| `references/WSS.TAXONOMY.md` | Deciding what pages a project needs, and which tier a subject belongs to |
| `references/WSS.SITE-ASSEMBLY.md` | **Scaffold mode only** — the minimum page set a profile implies, and how the sidebar is assembled. New page and Update decide one page against one tier row and never load it (loaded from taxonomy, skip otherwise) |
| `references/WSS.TIER-MOBILE.md` | The project has a mobile app (loaded from taxonomy, skip otherwise) |
| `references/WSS.TIER-GOVERNANCE.md` | A compliance, legal, or regulatory obligation applies |
| `references/WSS.SITE-SETUP.md` | Scaffolding, or changing docsify config |
| `references/WSS.TRANSLATIONS.md` | The site is or should be multilingual — mirror rules, the anchor trap |
| [`workflow/checks/WSS.DOCS-AUDIT.md`](../../workflow/checks/WSS.DOCS-AUDIT.md) | Verifying anything, or hunting drift after a refactor |
| `assets/wss-scaffold.sh` | Creating the site shell |

**What [`docs-writer`](../../workflow/writers/WSS.DOCS-WRITER.md) loads**, which this
skill reaches for only in Audit mode when the finding is about prose:

| File | Read it when |
|---|---|
| `references/WSS.STYLE-GUIDE.md` | Writing or reviewing prose — voice, formatting, the *why*-per-paragraph rules, and the three diagram rules |
| `references/WSS.PAGE-ANATOMY.md` | Starting a page — skeletons for guide pages, annex references, index, sidebar |
| `references/WSS.WORKFLOW-PAGES.md` | Documenting an end-to-end flow — the diagram-plus-stages shape, its citation contract, the verified-at stamp |

**That split is the whole point of the hand-off.** A caller that has already
settled where a page goes should not pay for the prose rules to be loaded into a
context that is not going to write the prose.
