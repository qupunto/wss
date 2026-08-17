# Step 11 — A project with no documentation gets handed to `--wss-docs`

Step 3 already searched for what exists. If it found no documentation — no
`docs/`, no site under another name, no renderer config — **invoke the `docs`
skill** rather than noting the absence and moving on.

Bound it to the scaffold and the overview page.

**The grant it inherits is this skill's, not `--wss-docs`'s.** `--wss-adopt` authorizes
committing what it creates and `--wss-docs` alone authorizes nothing, so the
scaffold may be committed here and nothing may be pushed.

**Absent is not always missing.** A repository that is only tooling, whose
overview genuinely is its README, does not need a site — and `WSS.record.reference`
pointing at that README is the manifest saying so. Take the answer and record
it; do not scaffold something nobody will read. Where the project is unclear,
ask rather than deciding on its behalf.

