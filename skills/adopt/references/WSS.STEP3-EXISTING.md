# Step 3 — Find what already exists — search, do not assume

Conventional names are a starting guess, not an answer. A project that has been
running for a year has a TODO list somewhere, and it is as likely to be
`docs/WSS.TODO.md` or `PLANNING.md` as `WSS.TODO.md`.

For each record in [`WSS.RECORD-CONTRACT.md`](../../../wss/workflow/WSS.RECORD-CONTRACT.md),
look for a file that already plays that role — by name, then by content. Report
the mapping as a table before writing anything, and mark each row **found**,
**ambiguous**, or **absent**. Ambiguous means two candidates; ask rather than
picking.

**A file that already holds the right content is the answer, whatever it is
called.** Renaming a project's files to suit the workflow is backwards — the
manifest exists precisely so that it does not have to.

**The TODO list row is the one that may not be a file at all.** A team already
running on GitHub Issues has no `WSS.TODO.md` and never will, and the row comes back
**absent** for a project whose TODO list is in fact busy. Before recording it as
absent, look: `gh issue list --limit 5` against the origin repo, and the labels
that come back. Open issues here mean the row is a **provider** question rather
than a missing file — carry it to step 7 rather than proposing an empty
`WSS.TODO.md`. The mapping is
[`providers/WSS.GITHUB-ISSUES.md`](../../../wss/workflow/providers/WSS.GITHUB-ISSUES.md).

