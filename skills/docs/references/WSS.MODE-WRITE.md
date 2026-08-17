# New page mode (Write)

Already-existing site, target has no page or section yet. **This skill places; the
writer writes.** Placement is the only decision here — one line end to end: decide
the tier row, write the page, wire it up.

1. **Place it** (G17, then G14/G15). Find the subject's tier in
   [`WSS.TAXONOMY.md`](WSS.TAXONOMY.md). Then: guide page → `docs/<concern>.md`;
   exhaustive item-by-item reference → `docs/annex/<topic>.md`; too small for
   either → a `##` on the closest existing page. An end-to-end flow past the split
   thresholds is a **workflow page** — [`WSS.WORKFLOW-PAGES.md`](WSS.WORKFLOW-PAGES.md)
   owns that shape, its citation contract and its stamp.
2. **Hand the target and its source to
   [`docs-writer`](../../../wss/workflow/writers/WSS.DOCS-WRITER.md)** — which reads the
   source, drafts from the skeletons, wires up `_sidebar.md`, `index.md` and every
   mirror, and verifies. Name the page and the tier you chose; it hands back a
   target that contradicts the taxonomy rather than relocating it quietly.

**What `docs-writer` loads**, so a caller landing here knows what the hand-off
actually costs — reached in full whenever this mode runs, and by
[Audit mode](WSS.MODE-AUDIT.md) only when the finding is about prose:

| File | Read it when |
|---|---|
| [`WSS.STYLE-GUIDE.md`](WSS.STYLE-GUIDE.md) | Writing or reviewing prose — voice, formatting, the *why*-per-paragraph rules, and the three diagram rules |
| [`WSS.PAGE-ANATOMY.md`](WSS.PAGE-ANATOMY.md) | Starting a page — skeletons for guide pages, annex references, index, sidebar |
| [`WSS.WORKFLOW-PAGES.md`](WSS.WORKFLOW-PAGES.md) | Documenting an end-to-end flow — the diagram-plus-stages shape, its citation contract, the verified-at stamp |

**That split is the whole point of the hand-off.** A caller that has already
settled where a page goes should not pay for the prose rules to be loaded into a
context that is not going to write the prose.
