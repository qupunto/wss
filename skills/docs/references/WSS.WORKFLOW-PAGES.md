# Workflow pages

A workflow page documents **one end-to-end flow as its own document**: a Mermaid
diagram plus the ordered stages under it, where each stage cites the project's
behaviour record by the rule's **bolded lead phrase** and the implementation by
`path::symbol`. It restates no policy — the page is a *route through* rules that
live elsewhere, which is G6 applied to a journey instead of a fact. The pages
that earn their keep are the ones where the obvious narration is **wrong
somewhere that matters** — a check the reader assumes happens at step three actually happens
per-request somewhere else entirely — and the page exists to make that one
design choice and its consequences visible.

These are T3 pages: `domain/workflows.md` while the flows fit one page,
`domain/workflows/<name>.md` each once they outgrow it (G14/G15 thresholds).
The citations do not break T3's framework-free rule, and saying why matters:
the *content* — actors, stages, gates, state — stays true if the stack were
rewritten, while the backticked anchors say where each stage lives today, which
is G3 doing its ordinary job. The anti-pattern is prose *about* the framework,
not an anchor into it.

## Enumerate top-down, never from the endpoint list

Workflows are named from the journeys a reader gets lost in — sign-up,
review-and-publish, reporting, checkout — and each workflow then names its
endpoints. Bottom-up from the route table produces one document per endpoint
and no comprehension: **most of an API surface is CRUD with no sequence worth
drawing**, and a hundred routes are not a hundred workflows. A flow earns a
page when it crosses actors or role gates, or when state set in one request
decides a later one. A flow that is one handler reading one table is a
paragraph on the page that owns that subject, not a workflow.

## The diagram

Mermaid, under [`WSS.STYLE-GUIDE.md`](WSS.STYLE-GUIDE.md)'s three diagram rules —
they all still apply, and the first is the one that ships broken pages:
**check what will render it** (docsify needs a plugin the default `index.html`
does not load), every box and arrow is a claim drawn from source you read (G1),
and stop before the graph stops being readable. Number the diagram's nodes to
match the ordered stages below it, so the picture and the prose are one
document rather than two adjacent ones — a reader who cannot run Mermaid still
has the full flow in the stages.

## The citation contract

Each stage carries two anchors, and the form of each is load-bearing:

- **The rule**, cited from the behaviour record (`WSS.record.behaviour`) by its
  **bolded lead phrase**, verbatim. A phrase is greppable, so the audit can
  assert it still appears; a section number or line reference rots silently.
  Where the project declares no behaviour record, cite the source alone and say
  the page is doing both jobs.
- **The implementation**, as `path::symbol` — `backend/src/auth/session.ts::issueSession` —
  never a line number. Symbols survive edits that renumber every line, and a
  symbol that stops resolving is a *detectable* staleness, where a stale line
  number is an undetectable lie.

The page asserts the *order and the gates*; the rule's wording and the code
stay where they live. When writing a stage would mean explaining a rule at
length, the rule is in the wrong file — hand it to the behaviour record's owner
and cite what lands there.

## The verified-at stamp

The page's header carries the commit it was last verified at. It is written at
*verification* time, never bumped by an ordinary code change — so a diff on a
workflow page means exactly one thing: somebody re-verified it. Where the stamp
is present it narrows the audit for this page more precisely than the site-wide
baseline: it is the page's own baseline.

The stamp is what makes staleness mechanical, in two classes:

- **A cited symbol whose last-touch commit is newer than the stamp**
  (`git log -1 -L :symbol:file`) — re-read those stages against source.
- **An endpoint under a path the workflow covers but cites nowhere** —
  functionality grew past the page.

And one class nothing detects, which the page must own rather than imply away:
**behaviour changing inside a symbol whose signature held.** The stamp says when
a person last read the flow, not that nothing moved beneath it.

## The page describes; findings go to the backlog

Writing a workflow page is a close read of a subsystem and **will surface
defects**. The page never carries "this is wrong" — it describes what the
system does, exactly as the behaviour record must (G7 marks what is not live;
G16 says code wins). Each defect found while writing is dispatched to
`--wss-todo` **in the same session**, so the page stays a description and the
finding reaches a record `--wss-start` actually reads. There is no mechanical
check for defect-shaped prose — it false-positives on ordinary explanation —
so this is a procedure rule, and it can afford to be one because the route it
names costs a single call.

## What stays hand-written

A project may generate the endpoint spine — path, method, guards, schema,
response codes, the service symbol each handler calls are all derivable from
route files or a live OpenAPI document — and where one builds that generator it
is project tooling, run at verification time so the regenerated facts and the
stamp move together. **There is deliberately no manifest key for it**: a
key earns its place only when a global skill reads it
([`WSS.MANIFEST.md`](../../../workflow/WSS.MANIFEST.md)'s first rule), and none
does until a real generator exists to run. What no generator covers: the
ordered steps *inside* a service, and any table assembled from several files.
