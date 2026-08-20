# The caller contract for a dispatched wrap

**Read this only where `--wss-wrap` was reached by dispatch, not typed
directly.** A user-typed `--wss-wrap` skips this file entirely.

**A caller reaches this skill to close out its own procedure, and the catalog's
who-invokes-whom table is where the current set of them is recorded** — not a
list here, which would be a second copy going stale against the first. What is
*this* file's is the rule: a dispatched wrap differs from a typed one in three
ways, and **the caller states each of them when it invokes.**

- **The grant is the caller's, at the caller's scope, and never wider than the
  tree happens to contain.** `--wss-health-check --deep`'s TODO resort grants
  commit — never push — **for the audit's own record only** — the audits
  entry, the rebuilt TODO list and the records the review touched, never
  remediation code written in the same session. **A flagless caller has no
  grant to pass on at all**
  ([`WSS.OWNERSHIP.md`](../../../wss/workflow/WSS.OWNERSHIP.md)'s *authorization
  comes from the flag*), so a wrap dispatched from one asks the user for the
  commit in that turn, at the scope the caller names, and treats a refusal as
  an ordinary outcome rather than a failure.
- **Declare the session safe to `/clear` only where the caller says it is
  finished.** Step 8 is written for a user who typed the flag and has nothing
  left. A caller that routes more work *after* this — `--wss-health-check --deep`'s
  TODO resort places its Fix-now dispositions there — is mid-procedure, and telling the user to
  clear throws away the context the rest of it needs. A caller whose close-out
  is genuinely its last step is not, and the framing is honest. **The caller
  says which; do not infer it from how finished the tree looks.**
- **Skip step 6.** Whether the caller's work closed a milestone is the caller's
  question to raise, not a second opinion offered from inside its close-out.
