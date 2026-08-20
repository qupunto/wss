# The token-economy checklist

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What it
finds: a skill, agent or tooling file paying more context than its job needs.
Each lens below is a question, what a hit looks like, the tree's own proven
example of the fix, and the drawback that must be outweighed — because the
gate on every lens is the same: **apply it only where the saving beats the
drawbacks, and propose before touching anything structural.** A lens with no
hit is a result, not a failure to look hard enough.

**Lens 4 is exempt from that gate, and it is the only one** — see its entry.
Every other lens weighs its saving; extraction is applied on confirmation.

The measurements come from
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

3. **Cheaper-model delegation.** Read-heavy phases that return a verdict
   match [the dispatch ladder](../workflow/WSS.DISPATCH-LADDER.md)'s Survey rung,
   which sets the tier and the effort; what this lens looks for is a phase
   that qualifies and is still run inline. Proven:
   [`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md)'s "How the measuring is paid
   for". Drawback: judgment quality is the brief's job now; a vague brief
   on a small model returns confident noise.

4. **Split into reusable parts.** A block two skills both need is a method
   file both cite, not two copies — and a method carries no scope,
   disposition or authorization, which stay with each runner. Proven: the
   shared methods in `wss/tests/` — `WSS.MECHANICAL-GAUNTLET.md` was
   extracted from two runners that had each carried their own copy.
   Drawback: one more mandated read in each runner's chain.

   **Where duplication is confirmed, extraction is applied, and its cost is
   not weighed** (owner's ruling). This lens alone does not run the gate in
   the header, and the previous form of this entry — retiring an extraction
   "below ~1 KB of sharing" — is what the ruling replaces. The reasoning: a
   shared method that costs slightly more in one run costs less in every
   maintenance pass afterwards, and a second copy is not a steady state but a
   divergence with a date on it. Consistency is a reliability property here,
   and reliability outranks efficiency.

   **Confirmed means byte-level, not impression.** `wss-duplication.sh`
   reports normalised-exact repeats across the declared globs; a paraphrase it
   misses is `WSS.ROT-RESISTANCE.md`'s uncompared-second-copy lens, which is a
   reading pass and keeps its own gate. Two blocks that merely *resemble* each
   other are not a hit here — extracting those is how one method acquires two
   masters.

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
   `wss/workflow/WSS.SWEEP-CHECKPOINT.md`'s contract, enforced, not assumed.
   Proven: the claims and prune sweeps narrow every run to changed files.
   Drawback: the void rules are load-bearing; a cache honoured past its
   contract reports stale work as done.

8. **Delta over full.** Can it read what changed since a baseline instead
   of everything? Proven: `--wss-health-check`'s default mode runs incrementally, and a delta
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

13. **Re-reading across agents.** Is a file read more than once per batch
    across separate agents, and can the orchestrator read it once and quote
    the content into each brief instead of a pointer? Two sub-questions ride
    with it: do agents read the same files in the same slices, so what is
    stable stays stable; and is a subagent warranted at all when its whole
    job is one small edit. Distinct from lens 3, which asks which tier a
    delegated read runs on, and from lens 9, which measures one flag's chain
    in one context — this one measures the same file across *sibling*
    contexts, which no chain measurement sees, because each agent's chain is
    individually reasonable. The mechanism: a subagent starts a fresh context
    sharing no cache with its parent or its siblings, so every pointer in a
    brief is a re-read paid at full price once per shard. **Not a caching
    question** — a `cache_control` breakpoint is for code calling the API
    directly; inside the harness nothing can set one, choose a prefix, or
    share a prefix with a subagent. That limitation is the cause, not an
    obstacle: the fix is the brief, not the cache. Measured by three probes
    reading no files and running no tools — no override → Opus 5 (1M
    context), 20,625 tokens; `model: 'haiku'` → Haiku 4.5, 19,095;
    `model: 'sonnet'` → Sonnet 5, 26,170. **All three varied the model against
    one grant — `Tools: *` — so what they show is that the floor barely moves
    with the tier, not what the floor is.** The floor moves with the *grant*,
    and the per-grant figures are ["Per-grant spawn
    floor"](#per-grant-spawn-floor) below; a shard whose whole job reads less
    than the floor **for the grant it would spawn** is cheaper inline. Recompute by
    dispatching a throwaway subagent that reads nothing and asking it to
    report its own model, per
    [`WSS.RECORD-CONTRACT.md`](../workflow/WSS.RECORD-CONTRACT.md)'s "A figure carries
    what recomputes it" — it reproduces both the floor and the tier actually
    running. Proven: `skills/start/SKILL.md`'s Phase 4 brief-field list.
    Drawback: a quote spends orchestrator context and can go stale where a
    pointer stays correct, so the case closes only for a fact more than one
    shard would otherwise re-derive. A quoted fact is **not** a second site
    under lens 11 — a brief is discarded when the agent returns, so it
    carries no drift risk.

This list grows, and a lens added here re-opens every file that was checked
under the shorter list — the same property `WSS.ROT-RESISTANCE.md` has, and
the one that makes growth safe rather than retroactively dishonest. The
independent audit pass remains the only thing that finds the lens nobody has
written down yet.

## Chain budget figures

Lens 9 states the rule; this table is the number `wss-doctor.sh`'s chain-budget
check reads, so raising a ceiling is a decision recorded in a contract rather
than a silent script edit (`WSS.ROADMAP.md`'s "Make
the cost visible before it grows"). `wss-tools-inventory.sh` sums each
`SKILL.md`'s same-window chain under [`WSS.AUDIT-PASS.md`](WSS.AUDIT-PASS.md)'s
convention and writes it to `.claude/WSS.TOOLS.json` as `chainBytes` — the
doctor reads that number rather than recomputing it (lens 11), and warns —
never fails — over the figure below for its tier.

| Tier | Budget | A skill is this tier when |
|---|---|---|
| primitive | 90 KB | `WSS.OWNERSHIP.md`'s matrix marks it `primitive` |
| runner | 90 KB | the matrix marks it `orchestrator`, and its `SKILL.md` names no parallel fan-out |
| orchestrator | 115 KB | the matrix marks it `orchestrator`, and its `SKILL.md` names fanning out to parallel agents (`in parallel`, `fan-out`, `fans out`, `fan out`) |

**These are outlier thresholds, not targets, and the distinction decides how to
read an overrun.** Each sits just above the heaviest chain in its tier's main
cluster, so a skill that trips one is separated from its peers rather than
merely large. The figures they replaced — 8 / 40 / 80 KB — were aspirational and
unreachable by construction: `WSS.RECORD-CONTRACT.md` overruns an 8 KB budget
several times over on its own (`wc -c wss/workflow/WSS.RECORD-CONTRACT.md`), so any
primitive citing it unconditionally was over before reading anything else, and
most skills overran — `wss/tests/wss-doctor.sh`'s "Chain budgets" section is the current
list. A check that lists almost
everything every run is one nobody reads, and it cannot show growth, which is
what `WSS.ROADMAP.md`'s "Make the cost visible before it grows" actually asks
for. `wss/logs/WSS.DECISIONS.md` carries the recalibration and the three options
rejected.

**What this buys and what it costs.** The check now names the skills with a
standing reason to be heavy rather than the whole tree, and a new entrant shows
up as an outlier the day it lands. The cost, stated rather than absorbed: today's
measured cost becomes the baseline, on a goal named "Cheap to run" — so a tier
whose whole cluster drifts upward together moves under the ceiling undetected.
Only a per-skill baseline warning on growth closes that, and it is not what
these figures do.

**Recompute the distribution before changing any figure here — never read one
out of this paragraph.** Run `wss/tests/wss-doctor.sh` and read its "Chain budgets"
section; to see every skill rather than only the overruns, set all three figures
to `1 KB`, run it, and restore. The tier split is read structurally (the
ownership matrix, then a grep for fan-out language on the orchestrator rows)
rather than kept as a second, hand-written list — a list here would be exactly
the copy lens 11 forbids.

**What the walk counts, and what it knowingly does not**, is stated in
`wss-doctor.sh`'s "Chain budgets" section rather than duplicated here: the
convention is one file's job, the mechanism reading it is another's, and a
prose restatement of a regex is the kind of second copy that goes stale
first.

**This file stops at what counts as a finding.** Scope, disposition and owner
are its runner's; the method/runner boundary, and its one exception, are
[`WSS.CHECKS.md`](WSS.CHECKS.md)'s and are not restated here.

## Per-grant spawn floor

This is the table
[`WSS.DISPATCH-LADDER.md`'s spawn-floor section](../workflow/WSS.DISPATCH-LADDER.md#the-spawn-floor-and-why-a-ladder-rather-than-an-arbiter)
points at rather than restates, and the canon for per-grant spawn cost —
anything that needs a figure below cites this table or runs the recompute, it
does not copy the number. **The floor is set by the tool grant the caller would
dispatch, not by the rung** — and by the **model**, which is the half this table
formerly left out. Measured by dispatching an agent with the prompt "reply with
exactly the word: done" and reading `subagent_tokens` from its usage block — no
files read, no tools run, so the figure isolates the system prompt plus the tool
schemas the grant carries.

**A floor without its model is void, and the unit is tokens plus a cost proxy**
(owner's ruling). Two reasons, and the second is the one that bites:

- The same grant measures differently per model — `Bash, Read, Grep, Glob`
  returns **8,425 on Claude Opus 5** against **9,221 on Claude Haiku 4.5**
  (recompute: dispatch `agents/wss-survey.md` once per model with the prompt
  above and read `subagent_tokens`). An unlabelled figure is not reproducible.
- **Raw tokens do not compare across models at all.** By the same two
  measurements, the Haiku dispatch costs a fraction of the Opus one while
  showing the larger token count — so a table that ranks grants by tokens ranks
  the cheaper dispatch *higher*, inverting the decision the table exists to
  support.

The cost column is **API list price, and this project does not pay it** — it is
the only published cross-tier ratio, so it serves as a proxy for comparison and
nothing else. Where a plan's own metering is what matters, `/usage` attributes
consumption per subagent and is the authority over anything computed here.

| Grant | Carried by | Floor (tokens) | Model | ≈ list-price proxy | Rung it floors |
|---|---|---|---|---|---|
| `Tools: *` (every tool) | `general-purpose`, `claude` — harness built-ins, no `agents/*.md` file to cite | 20,613 | **unrecorded** | — | Analyze, Design |
| `Bash, Read, Grep, Glob` (four tools) | `agents/wss-survey.md:4`, `agents/wss-release-prep.md:4`, `agents/wss-analyze.md:4`, `agents/wss-design.md:4` | 8,425 | Claude Opus 5 | $0.042 | Survey, Analyze, Design |
| " | " | 9,221 | Claude Haiku 4.5 | $0.009 | " |
| `Read, Edit, Write, Bash` | `agents/wss-execute.md:4` — purpose-built, the narrowest grant that can still write | 9,868 | **unrecorded** | — | Execute |
| `Read, Edit` | `statusline-setup` — harness built-in, Execute-rung *proxy* only | 10,309 raw — **not** adopted as the Execute floor (see below) | **unrecorded** | — | Execute |
| `WebFetch`/`WebSearch` | none — nothing in the tree grants either narrowly | unmeasured, no proxy at all | — | — | Analyze |

**The `unrecorded` rows are a real gap, not a formatting placeholder.** Those
figures were taken before the convention named a model, so nothing establishes
which one produced them and inferring it would be a claim this suite's own rules
forbid. Each is recoverable by the recompute above, run twice and labelled —
which is cheap, and is the only thing that makes the rows comparable to each
other again.

Rows 1, 2 and the `statusline-setup` row come from one probe that dispatched
three do-nothing subagents in a single pass: `wss/logs/WSS.DECISIONS.md`,
`2026-08-13 (fourth)` entry. The `Read, Edit, Write, Bash` row was measured
separately by the same technique, and the entry recording it is cited below.

**Why the last row is unmeasured rather than omitted, and why that is a ruling
rather than an oversight.** The agent registry loads once, at session start; no
session can dispatch an agent it just created. Filling the row means writing a
purpose-built agent under `agents/*.md` carrying exactly that grant, then
restarting before the figure can be read back — a scheduling constraint, not a
gap in the method. Nothing in the tree grants `WebFetch` or `WebSearch`
narrowly, so that row has neither an agent nor a proxy: **a new agent, not a
re-run, is what moves it.**

**How the Execute row lifted, which is the worked instance of that.**
`agents/wss-execute.md` shipped carrying exactly
`Read, Edit, Write, Bash`, so the row stopped waiting on someone *writing* an
agent and waited only on a probe dispatched from a session that started after
that file did — which any later session satisfies for free. The next one ran it:
**9,868 tokens**, same do-nothing-subagent technique, no tools used. Recompute
by dispatching `agents/wss-execute.md` with the prompt "reply with exactly the
word: done" and reading `subagent_tokens`; the run is recorded in
`wss/logs/WSS.DECISIONS.md`'s `2026-08-14 (sixth)` entry.

**The `statusline-setup` proxy was right to be refused, and the measurement says
which way it was wrong.** That built-in's raw `Read, Edit` spawn cost is 10,309
tokens (`wss/logs/WSS.DECISIONS.md`, `2026-08-13 (fourth)`) — **dearer than the
purpose-built four-tool Execute agent it stood in for**, by 441 tokens. A proxy
carrying half the tools and costing more is not a conservative estimate of the
real thing; it is a different measurement wearing its name.

**Which is the caveat this table's method carries and did not state until now:
the probe isolates the system prompt *plus* the tool schemas, so a comparison
across two different agents is never a clean comparison of their grants.**
`statusline-setup` is a harness built-in with its own system prompt;
`wss-execute` is ours. The 441-token gap between them is both differences at
once and cannot be attributed to either. The same caution applies to reading
`8,425` against `9,868`: both grants carry four tools and the second is dearer,
which says *which* tools are held matters, not that it costs more to be allowed
to write — `agents/wss-survey.md` and `agents/wss-execute.md` also differ in
system prompt. Compare rows to size a dispatch; do not read a row difference as
the price of a permission.

**The range stated in lens 13 above described only the `general-purpose` case** —
three model overrides against one grant, not three grants; the dispatch ladder
used to cite it as if it were the floor for any subagent. Its own figures are
not repeated a third time here; the `20,613` row above is a same-technique,
same-grant recompute one day later (`wss/logs/WSS.DECISIONS.md`, `2026-08-13 (fourth)`
entry) and sits inside the range lens 13 gives.

**Recompute rather than trust these numbers.** Dispatch an agent with the
prompt "reply with exactly the word: done" — one dispatch per grant needed —
and read `subagent_tokens`. `Explore` and `Plan` emit no usage block and cannot
be measured this way.

**The spawn side is only half of Keep's comparison, and the other half is not
one-shot.** A subagent's cost above is paid once, at dispatch. A read kept
inline instead is not one-time: it sits in the orchestrator's window and is
re-billed on every later turn of that session. This table gives the spawn side
only, and **a one-shot comparison against it is the wrong shape** — the owner
has adopted that correction, so a read held across later turns must clear this
floor divided by the turns it is held for, and every candidate
measured against the one-shot form flipped to Survey. The decision log's
`2026-08-19 (eleventh)` and `(twenty-third)` entries carry the recompute and the
adoption; the verdict consumes the figure's sign, and no figure is published
here or there. **The inline side's per-turn multiplier has been measured once
and is not canon**: it needs the orchestrating session's own token accounting,
separating cached from uncached input, which no single dispatch can see, so the
run was the owner's — and two runs at one file size give one figure with no
error bar. No figure is stated in this file until a second pair supplies one.
Take it from `wss/logs/WSS.DECISIONS.md`'s `2026-08-18 (tenth)` entry, which
carries the figure, the mechanism behind it, and what it does not settle.
