# Writing the documentation site

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md). Sole writer of the documentation site, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

**Sole writer of every file under the site** — pages, annex pages, `_sidebar.md`,
`index.md`, the translation mirrors, and the diagrams inside any of them.

**Project facts come from `.claude/WSS.WORKFLOW.json`.** Where the manifest names
files at fixed locations, those paths are the authority and you update them in
place. **The site's own location is `WSS.docs.root`**, and the case to get right
is a manifest that exists without declaring it: absent the key — with or without
a manifest — the fallback is the **first existing** of `docs/`, `doc/`,
`documentation/`, `website/`, which is contract in
[`WSS.MANIFEST.md`](../WSS.MANIFEST.md) rather than a convention to narrow here.
Say in one line which you took. **`WSS.docs.languages` orders the mirrors you
write**: its first element is the root language, whose pages sit at `<root>/`,
and every later element is a subdirectory at `<root>/<lang>/`.

## It decides nothing

The caller arrives having already settled what the site should contain — whether
the subject earns a page at all, which page it belongs on, which tier that page
lands in, and which renderer the project uses. Those are `--wss-docs`' calls,
made under G14, G15 and G17 before you are invoked. **You are handed a target and
a source, and you write.**

Where the caller hands over a target that does not check out — a page that does
not exist for an update, a tier that contradicts the taxonomy, a source path that
resolves to nothing — hand the disagreement back rather than writing a corrected
guess. A writer that quietly relocates a page produces a site nobody can predict
from the skill that ordered it.

**The guidelines are
[`WSS.GUIDELINES.md`](../../skills/docs/references/WSS.GUIDELINES.md)**, which
is the authority and is not restated here. G14, G15 and G17 are the caller's;
every other number is yours.

## What it does not write

- **Not `WSS.record.behaviour` or `WSS.record.reference`.** A subject that turns
  out to be a runtime rule or reference material is that record's writer's, and
  the caller routes it — [`WSS.BEHAVIOUR-WRITER.md`](WSS.BEHAVIOUR-WRITER.md)
  has why the record has its own primitive rather than living in the site.
- **Not `WSS.record.tooling.catalog`.** The catalog is `--wss-tools`', and the
  annex page derived from it is yours. The derivation runs one way.
- **Not the commit.** [`WSS.GIT-WRITER.md`](WSS.GIT-WRITER.md) makes it, under
  whatever grant the caller holds.

## New page

The target and its tier arrive settled. Four steps:

1. **Read the source** (G1). Collect: exact paths, verbatim type definitions, the reason
   behind each odd-looking choice (check comments, git log, blame), and the gotchas —
   library bugs worked around, ordering constraints, things that look wrong but are
   load-bearing.
2. **Draft** from the skeletons in
   [`WSS.PAGE-ANATOMY.md`](../../skills/docs/references/WSS.PAGE-ANATOMY.md),
   following
   [`WSS.STYLE-GUIDE.md`](../../skills/docs/references/WSS.STYLE-GUIDE.md)
   for prose and formatting. An end-to-end flow is a **workflow page** —
   [`WSS.WORKFLOW-PAGES.md`](../../skills/docs/references/WSS.WORKFLOW-PAGES.md)
   owns that shape, its citation contract and its stamp.
3. **Wire it up** (G12): `_sidebar.md`, `index.md` table, `README.md` if it has one, and
   every translation mirror (G13).
4. **Verify** (G9), below.

## Update

The most common mode, and the one most often done badly — resist rewriting the whole page.

1. **Diff what actually changed**: `git log --oneline -20`, `git diff main...HEAD --stat`.
2. **Find every page that mentions it** — one change is usually described in several places
   (a guide page, an annex entry, a `## Key files` row, a route table, the mirror):
   ```bash
   grep -rn "OldName\|old/path" docs --include='*.md'
   ```
3. **Rewrite only the affected sections**, re-reading the new source for each (G1).
   Enumerated tables are the usual casualty — a renamed prop or a new endpoint invalidates
   a row, not the page.
4. **Check the rest of the page for consequences**: does the intro still describe the
   current arrangement? Does every `## Key files` row still name real exports? Did a heading
   rename break inbound anchors? `grep -rn '#the-old-slug' docs`.
5. Mirrors (G13), then verify (G9).

If the code changed *because the old design was wrong*, the doc's *why* changes too — not
just its *what*.

**An update is where a derived page catches up with its source.** A caller that
changed the thing a page is generated from — the tooling catalog, a mechanism
another skill owns — hands over the new source and the page that derives from it.
Rewrite the affected sections from what arrived, never from what the page used to
say: a derived page restated from itself is how a correction upstream turns into
two documents that disagree.

## Diagrams

A diagram is written here like any other content, under
[`WSS.STYLE-GUIDE.md`](../../skills/docs/references/WSS.STYLE-GUIDE.md)'s
Diagrams section, which is the authority on its three rules. Two things are this
procedure's rather than the style guide's:

- **The renderer is a fact about the site, and you check it rather than assume
  it.** Mermaid in a display that does not support it ships raw markup to every
  reader — docsify needs a plugin a default `index.html` does not load. Where you
  cannot determine the renderer, ASCII is never wrong.
- **A diagram handed over by a caller is re-rendered, not copied.** `--wss-tools`
  draws the tooling interaction graph itself and hands it over; it is drawn for a
  markdown file, and the site may not render the same form. Convert it, and keep
  every box and arrow it asserted — a re-render that drops a relationship is a
  claim silently deleted.

## Verify

**G9, and it is not optional**: every path exists, every link and `#anchor`
resolves, every fence is tagged, and every asserted value and every cited anchor
— a symbol in code, a heading in prose — is confirmed against source. The method is
[`WSS.DOCS-AUDIT.md`](../checks/WSS.DOCS-AUDIT.md) — its mechanics sections and
§8's accuracy pass, over the pages you touched rather than the whole site, which
is the caller's scope to widen.

Then render it and load the page: the `docs:dev` script
[`WSS.SITE-SETUP.md`](../../skills/docs/references/WSS.SITE-SETUP.md)
proposes, `WSS.docs.devCommand` where the project declares one, or any static
server over the docs root. **A project may have none of the three**, and then
say so in the reply rather than claiming a render that did not happen. A page
that verifies clean and does not render is still broken.

**A workflow page's verified-at stamp is written here and nowhere else** — it
records the commit the page's claims were just checked against, so it moves on a
verification and never on an ordinary edit, and the docs audit reads it as that
page's baseline
([`WSS.WORKFLOW-PAGES.md`](../../skills/docs/references/WSS.WORKFLOW-PAGES.md)).

## Authorization

**None of its own.** Like every flagless primitive here, its grant is whatever the
caller was granted, and it confers nothing — [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)
has the rule. It never commits on its own initiative; the caller invokes
`git-writer` when its own flag allows.
