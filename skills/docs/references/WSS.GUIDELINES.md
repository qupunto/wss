# The documentation guidelines

**The shared authority on how a page is written.** Three consumers cite these
numbers and none of them owns the list: `--wss-docs` decides what the site should
contain, [`WSS.DOCS-WRITER.md`](../../../workflow/writers/WSS.DOCS-WRITER.md)
writes it, and [`WSS.DOCS-AUDIT.md`](../../../workflow/checks/WSS.DOCS-AUDIT.md)
checks it afterwards. They live here, beside the reference files that cite them
most, rather than inside any one of the three.

Numbered so they can be cited in review. **G1, G2, and G8 are what make these docs worth
having**; the rest are mechanics.

> Numbers are **append-only**. They are cited from across this skill's reference files, from
> the writer and from the audit method, so renumbering silently invalidates those citations.
> A new guideline takes the next free number regardless of where it belongs thematically; a
> retired one keeps its number and is marked retired rather than removed.

**Content**

- **G1 — Read the source first.** Open every file you will name. Copy type definitions
  verbatim. Never document from inference; a plausible-but-wrong doc is worse than none.
- **G2 — Every paragraph carries a *why*.** State the mechanism, then why it is that way:
  `because`, `so that`, `instead of`, `otherwise`. A sentence with no *why* usually restates
  the code — cut it.
- **G3 — Name the file, inline, in backticks.** Every function, type, and behavior is
  attributed to `src/where/it/lives.ts` at the point it is described.
- **G4 — Record the rejected alternative.** When a choice looks arbitrary, document what the
  obvious approach would have broken.
- **G5 — Elide code.** Show the shape that matters; cut the rest with `/* ... */` or `# ...`.
  Never paste a whole file.
- **G6 — Cross-link instead of restating.** Say a thing once, on the page that owns it; link
  to it from everywhere else, anchor-deep where useful.
- **G7 — Mark what isn't live.** Unused or aspirational code gets flagged as such; generated
  files get a loud **Do not edit it by hand.**
- **G8 — Never invent rationale.** Can't find why? Write "reason unclear" or leave it out.

**Mechanics**

- **G9 — Verify before declaring done.** Every path exists, every link and `#anchor` resolves,
  every fence is tagged — and every asserted symbol and value is confirmed against source
  (`workflow/checks/WSS.DOCS-AUDIT.md` §8). Mechanics can be checked by script; accuracy needs re-reading the source.
  Don't eyeball either.
- **G10 — Tables for anything enumerable.** Routes, endpoints, props, tokens, env vars,
  dependencies, key files.
- **G11 — Close file-mapped pages with `## Key files`**, naming the actual exports.
- **G12 — A page enters `_sidebar.md` and `index.md` in the same change that creates it.**
  Never scaffold an empty page; never add content without its index entries.
- **G13 — Every translation mirror updates in the same change.** One stale language is worse
  than one language.

**Scope**

- **G14 — Extend before adding.** A new top-level page is justified only when a reader would
  look for that concern by name in the sidebar. Otherwise it's a `##` on the nearest page.
- **G15 — Push per-item detail to `annex/`** once it crowds out the concept the page teaches.
  Guide pages explain how a layer works; annex pages enumerate its members exhaustively.
- **G16 — Code wins.** Where docs and source disagree, the source is right. Fix the doc and
  report the drift you found.
- **G17 — Place by tier, not by convenience.** [`WSS.TAXONOMY.md`](WSS.TAXONOMY.md) fixes which tier a
  subject belongs to, so the same concern lands in the same place in every project. Sidebar
  depth is negotiable; tier ownership is not.

**G14, G15 and G17 are the decisions**, and they are `--wss-docs`' rather than the
writer's — which page a subject belongs on, and which tier that page lands in, is
settled before anything is written. The writer arrives with the target already
chosen and follows the rest.
