# Phase 3 — Review with the user, one finding at a time

Open with a **compact index**: every finding as one numbered line, grouped by
severity, with its kind and verification mark. Include the test, typecheck and CI
results, and the dimensions that came back clean — clean is a result.

### Split the list first: does the answer change anything?

**Auto-accept, don't ask** — a `[verified]` `defect` at `critical` or `high`
severity, or any **regression** of something a previous audit closed. Log these
straight to `WSS.record.todo`, list them in the index with citations, and say in one
line: *"these N were auto-accepted as verified defects — say the word and we'll
walk any of them."* The override must be genuinely available, not merely offered.

**Ask, one at a time** — everything else:

- every `suggestion`, `inconsistency` and `risk`, where the whole question is
  whether it is worth the complexity;
- every `gap` and schema/scale finding, where the answer depends on a product
  direction the auditor cannot see;
- anything `[reported]` rather than `[verified]` — you are asking the user to
  trust an unverified claim, so let them weigh it;
- **every carry-over item at two or more audits**, where the question is not
  "should we fix this" but "this keeps coming back — is it actually not going to
  happen, and should it stop being on the list?"

If in doubt about which pile something belongs in, ask. Auto-accepting is the
concession; individual review is the default.

### Then walk the ask-pile

Most severe first, via `AskUserQuestion` — one question per finding, showing the
citation and the one-line direction. Dispositions:

- **Fix now** — becomes a `TaskCreate` item, worked this session after the audit
  closes.
- **Log it** — into `WSS.record.todo` as a checkbox with technical detail.
- **Defer with reasoning** — hand to `--wss-todo`: task to `WSS.record.todo`, reasoning
  to `WSS.record.decisions`. A deferral is a decision.
- **It's an open decision** — to `WSS.record.openDecisions` with options and what it
  blocks, not to `WSS.record.todo`.
- **Drop it** — the finding is wrong, already handled, or deliberately not a
  problem. Record it as disputed in the audit entry with the user's reason. Never
  silently discard.

Two concessions to the user's time, and only two. **Batch the genuinely
identical**: the same defect in five routes is one question. And **honour a
blanket answer** — if the user says "log the rest of the mediums", stop asking and
log them, noting in the audit entry that those were dispositioned as a group.

Everything else in the ask-pile gets asked. If you find yourself auto-accepting
more than about a third of the findings, the classification is wrong — check
whether you are marking things `[verified]` that you only skimmed.
