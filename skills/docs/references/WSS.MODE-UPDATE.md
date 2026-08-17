# Update mode

Already documented, and the code moved. **Nothing here is decided** — the page
exists and its tier was settled when it was created — so this mode is a hand-off
in full. Give [`docs-writer`](../../../wss/workflow/writers/WSS.DOCS-WRITER.md) what
changed and the pages that describe it; the diff, the grep for every mention, the
rewrite of affected sections only, the mirrors and the verify are all its.
`docs-writer`'s own loaded-reference table is [Write mode's](WSS.MODE-WRITE.md) —
same hand-off, not repeated here.

**A caller that changed a source some page derives from reaches the writer
directly and never comes through here** — `--wss-catalog` handing over the tooling
catalog is the standing case. Routing a mechanical re-derivation through this
skill buys nothing but the cost of loading it, and that cost is paid in the
caller's context, at whatever size it has already reached.
