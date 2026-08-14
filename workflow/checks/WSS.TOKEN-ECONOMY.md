# The token-economy checklist

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What it
finds: a skill, agent or tooling file paying more context than its job needs.
Each lens below is a question, what a hit looks like, the tree's own proven
example of the fix, and the drawback that must be outweighed — because the
gate on every lens is the same: **apply it only where the saving beats the
drawbacks, and propose before touching anything structural.** A lens with no
hit is a result, not a failure to look hard enough.

A token finding used to cost a full independent pass to surface. This
checklist makes the same findings incremental — a file is re-examined when
it changes, not when a pass happens to look. The measurements come from
`wss-audit-assets.sh` and the chain-measurement convention in
[`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md);
this file decides what the numbers mean.

## The lenses

1. **Zero-cost shell.** Can the whole job be a script? A procedure whose
   every step is deterministic pays model tokens for arithmetic. Proven:
   `skills/overview/assets/wss-probe.sh` (the overview's whole mechanical
   block), `wss-audit-assets.sh` (the audit pass's measurements),
   `skills/record/assets/wss-index-decisions.sh` (the index). Drawback:
   a script joins the contract surface and the catalog — named maintenance,
   and a fenced nine-line block may be cheaper than a file that travels.

2. **Shellable parts.** Not the whole job — the deterministic steps inside a
   prose procedure: a stamp write, a state read, a fixed verification
   sequence. Proven: `wss-doctor.sh` grew section by section out of prose
   checks. Same drawback as lens 1, per part.

3. **Cheaper-model delegation.** Read-heavy phases that return a verdict go
   to a subagent on the smallest capable tier, low effort, verdict format
   pinned in the brief — citations, counts, no dumps. Proven:
   [`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md)'s "How the measuring is paid
   for". Drawback: judgment quality is the brief's job now; a vague brief
   on a small model returns confident noise.

4. **Split into reusable parts.** A block two skills both need is a method
   file both cite, not two copies — and a method carries no scope,
   disposition or authorization, which stay with each runner. Proven: the
   shared methods in `workflow/checks/` — `WSS.MECHANICAL-GAUNTLET.md` was
   extracted from two runners that had each carried their own copy.
   Drawback: one more mandated read in each runner's chain; extraction
   below ~1 KB of sharing usually loses.

5. **Invoke versus hook.** Does this need a model at all, or is it an event
   with a deterministic response? Proven: `hooks/wss-shorthand-flags.sh`
   (a flag is a dispatch, not a judgment call), `--wss-alerts` (served
   entirely by the hook, no skill exists). Drawback: hooks fire on every
   matching event and their breakage is silent — the contract suite is the
   price of admission.

6. **Content behind references.** Prose only some invocations need loads
   only on those invocations: mode gates, lane gates, provider gates.
   Proven: `docs` gates its references on mode; `start`'s lane
   machinery sits in `WSS.LANES.md` (loads only under a lane selector);
   `adopt`'s amendment mode skips the contracts. Drawback: a gate
   misjudged hides text from a session that needed it — the gate condition
   must be checkable, not vibes.

7. **Sweep-cached.** Does the procedure re-derive what a checkpoint already
   answers? A file swept clean stays clean until it changes — that is
   `workflow/WSS.SWEEP-CHECKPOINT.md`'s contract, enforced, not assumed.
   Proven: the claims and prune sweeps narrow every run to changed files.
   Drawback: the void rules are load-bearing; a cache honoured past its
   contract reports stale work as done.

8. **Delta over full.** Can it read what changed since a baseline instead
   of everything? Proven: `--wss-check` runs incrementally, and a delta
   survey reads the range rather than the series. Drawback: the baseline
   must be recorded somewhere the next run trusts — which is lens 7's machinery,
   not a new one.

9. **Chain accounting.** The honest cost of a flag is its same-window chain
   — body plus every unconditional mandated read, transitively, measured
   under [`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md)'s convention. Hits look
   like: the same contract mandated twice in one window (`WSS.MANIFEST.md`
   in adopt, `WSS.SWEEP-CHECKPOINT.md` repeatedly in a stocktake), or a
   dispatched procedure re-mandating what its caller just read. Drawback: read
   inheritance is a standing owner-deferred proposal — do not apply it per-file
   by local exception; that decision is one rule or none.

10. **Overlap with a sibling.** Does another skill or script already answer
    part of this? Proven by near-miss: `wss-audit-assets.sh` was almost a
    second `wss-probe.sh` — caught at catalog time because the catalog row
    forced the comparison. Drawback: merging two close-but-different
    consumers couples their output shapes; overlap is sometimes the cheaper
    steady state, and saying so is a finding too.

11. **Redundancy.** The same rule stated in N places is either one canonical
    statement plus pointers, or a copy-set sanctioned by a recorded ruling
    with a named extraction trigger — never an unruled drift risk. Proven:
    the `[critical → why]` canon, collapsed to one statement plus pointers;
    the currency clause's copies, owner-ruled with the second-consumer
    trigger recorded.
    Drawback: deciding is the cost; the ruling must be logged or the next
    sweep re-litigates it.

12. **Flavor versus behavior.** Body prose that explains *why* a step exists
    belongs in the decision log; the body keeps what an executor does. A
    `description:` is a trigger surface: it says WHAT the skill does and
    WHEN it fires, never why or how — and a description trimmed below its
    trigger surface trades tokens for misrouting, which always loses.
    Proven: the prose prune's keep test (`WSS.PROSE-PRUNE.md`), the
    description budget (doctor-warned), `track`'s description cut back
    to its triggers and nothing else. Drawback: over-cutting a load-bearing
    warning — the never-cut list in the prune method applies here verbatim.

This list grows, and a lens added here re-opens every file that was checked
under the shorter list — the same property `WSS.ROT-RESISTANCE.md` has, and
the one that makes growth safe rather than retroactively dishonest. The
independent audit pass remains the only thing that finds the lens nobody has
written down yet.

**Scope, disposition and authorization are the runner's** — see
[`WSS.CHECKS.md`](WSS.CHECKS.md). This file says only what counts as a finding.
