# Workflows

End-to-end journeys through the suite. The domain here is the workflow itself:
this project's "business model" is what happens between a person typing a flag
and a record being true afterwards.

> **Verified at `c527d2e`.** The stamp moves when someone re-reads this flow
> against source, never when the source changes — so a diff on this page means
> exactly one thing: somebody checked.

This project declares no `WSS.record.behaviour`, so each stage below cites its
**source alone** rather than a rule phrase plus an implementation. The page is
doing both jobs — stating what the rule is *and* where it lives — which is the
fallback the workflow-page shape names for a project without a behaviour
record.

---

## A batch, from `--wss-start` to `--wss-wrap`

The journey a session takes when it picks up pending work and does it. It
crosses three actors — the person, the orchestrating skill, and the primitives
that own each record — and it is gated three times by a human.

**Why this flow earns a page.** Narrated from the outside it sounds like one
actor doing ten things in order: the skill reads the records, builds the code,
runs the tests, writes the records, commits and pushes. Three of those are
wrong, each in a way that only shows up when it has already gone wrong:

- **The orchestrator writes no record.** It decides every word that lands, then
  hands each one to the primitive that owns that file. The decision and the
  write are deliberately different actors.
- **Committing happens before the tests, not after.** The order looks careless
  and is the opposite.
- **Authority does not accumulate down the call chain, and does not flow back
  up.** A batch can commit and can never push, no matter how much of it
  succeeds — and it cannot acquire push by invoking something that has it.

```
   person                orchestrator              owners / git
   ──────                ────────────              ────────────

 1 --wss-start ────────▶ flag resolves
                         grant injected: commit, NOT push
                              │
 2                       Phase 0  orient ──────────▶ --wss-track
                         tree · CI · 3 records         (task list)
                              │
 3 ◀── asks ─────────────Phase 1  open decisions
   answers ─────────────▶     │ each ruling ───────▶ --wss-log
        [GATE 1]              │                       (decisions)
 4                       Phase 2  choose batch
                              │ nothing eligible? ──▶ --wss-plan
                              │                       (roadmap)
 5                       Phase 3  partition
                              │ write sets AND read sets
 6                       Phase 4  run the wave
                              │ lanes, concurrent, no records
 7                       Phase 5  integrate
                              │ regen → typecheck ──▶ git-writer
                              │                       (commit per lane)
 8 ◀── asks ─────────────     │ suite, once
   consents ────────────▶     │ result ─────────────▶ sweep-tracker
        [GATE 2]              │                       (stamp)
 9                       Phase 6  record ───────────▶ each record's owner
                              │                       one at a time
                              │
10 --wss-wrap ──────────▶ close out ────────────────▶ git-writer
        [GATE 3]           push happens here, and only here
```

### 1 — The flag resolves, and the grant is injected rather than assumed

Typing `--wss-start` does not load a skill directly. A hook matches the token,
finds the skill that owns it, and injects a block stating what that flag
authorizes. The authority is *data the session is handed*, not something the
skill asserts about itself.

`hooks/wss-shorthand-flags.sh::block_for`, with `::decompose` splitting a
combined token and `::skill_for` resolving flag to skill. The grant it injects
must agree with the matrix in `workflow/WSS.OWNERSHIP.md` — `wss-doctor.sh`
compares the two copies and **warns** when they drift, which is why neither file
restates the other per skill. It warns rather than fails, and that distinction
matters for how the output reads: a drifted grant still ends a local run in
`all checks passed`, because warnings only become fatal under `--strict` —
which CI gives and a person at a terminal does not.

For this flow the grant is the row `workflow/WSS.OWNERSHIP.md::build`:
**commit, not push.**

### 2 — Orient before adding to anything

Pin the tree, check the pipeline is not already red, read the three planning
records, and build the task list.

`skills/wss-start/SKILL.md::Phase 0 — Orient`. The pipeline check comes before
the work for a reason the stage order makes invisible otherwise: a batch merged
onto a red pipeline hides which change broke it, so a red CI *becomes* the
batch rather than being noted beside it.

The task list is built through `--wss-track` rather than written here —
`skills/wss-track/SKILL.md` — because the ordering doctrine that governs it
(ramification first, then batch by expensive tail) is one thing in one place.

### 3 — Open decisions are settled first, because they get made anyway

Every entry in the open-decisions record, in file order, put to the person with
its options and what it blocks. This is the first human gate.

`skills/wss-start/SKILL.md::Phase 1 — Settle the open decisions`. The reason
this precedes the work rather than being scheduled alongside it: an open
decision is not a task that can wait, it is a choice that gets made silently by
whoever writes the first line of code depending on it.

Each ruling is handed to `--wss-log` (`skills/wss-record/SKILL.md`), which owns
deleting the entry from the open-decisions record and appending the outcome —
including the options rejected — to the decision log. An entry never lives in
both; `workflow/WSS.RECORD-CONTRACT.md` rule 3.

### 4 — Choosing the batch, and what happens when there is nothing

Critical-marked items first, then section order, minus everything ineligible —
deferred, blocked, production-touching, credential-needing.

`skills/wss-start/SKILL.md::Phase 2 — Choose the batch`. Two properties are
easy to miss. Backlog order is only meaningful when the backlog is a *file*:
under a provider the list arrives newest-first, which is close to the inverse
of the intended ordering, so rank must be read out of item bodies
(`workflow/providers/WSS.GITHUB-ISSUES.md`). And when the backlog yields
nothing, the fallback is not improvisation — the roadmap's first open block
goes to `--wss-plan` (`skills/wss-plan/SKILL.md`) to become concrete items,
because a roadmap block is a paragraph and a lane needs a file list.

### 5 — Partition by file sets, counting reads as well as writes

Lanes run concurrently in one working tree, so the unit of parallelism is the
file set rather than the task.

`skills/wss-start/SKILL.md::Phase 3 — Partition into lanes that cannot collide`.
The non-obvious half is the read set. Two lanes where one *reads* what another
*writes* corrupt nothing — which is exactly the danger, because nothing looks
broken. The output is a confident, well-cited, wrong report citing a file where
the evidence genuinely was a moment earlier.

Which paths are dangerous is declared, not guessed: `WSS.lanes.exclusive`
admits at most one lane in the whole batch, `WSS.lanes.serialize` covers shared
machinery, `WSS.lanes.generated` belongs to nobody —
`workflow/WSS.MANIFEST.md`. Every record file is off-limits to every lane.

### 6 — The wave runs, and no lane touches a record

All lanes of a wave dispatched in one message so they are genuinely concurrent,
each with its write list, its read list, the decision entries that bear on it,
and whether it may run the test suite at all.

`skills/wss-start/SKILL.md::Phase 4 — Run the wave`. Where the project declares
a consent-gated suite (`WSS.commands.testConsentEnv`,
`workflow/WSS.MANIFEST.md`), a lane cannot run it — not the whole suite, not one
file, not a single filter, because the gate is in the harness rather than in the
command. A brief saying "do not run the full suite" reads as though a targeted
run were the sanctioned alternative, and a lane discovering otherwise has
already spent the attempt.

### 7 — Integrate, and commit before testing

Read every lane's diff, regenerate anything generated, typecheck, then commit
each lane separately.

`skills/wss-start/SKILL.md::Phase 5 — Integrate and verify, once`, and
`workflow/writers/WSS.GIT-WRITER.md` for the commits. Committing before the
suite rather than after is deliberate: the suite may reset state destructively,
and a crash mid-run should cost the run rather than the work.

Typecheck sits here and nowhere else because cross-lane type breakage is the
one failure no individual lane can see — each lane's own transcript is green.

A lane that dies without reporting is treated as **suspect rather than
incomplete**: lanes are told to prove a guard by breaking the code on purpose,
so one killed mid-cycle may have left a plausible-looking, cleanly-typechecking
mutation behind.

### 8 — The suite runs once, with consent, and the stamp follows the result

The second human gate. One full run of `WSS.commands.test`, read rather than
assumed, then stamped.

`skills/wss-start/SKILL.md::Phase 5 — Integrate and verify, once` steps 4–5, and
`workflow/WSS.SWEEP-CHECKPOINT.md` for the checkpoint's fields. The stamp goes
through `workflow/writers/WSS.SWEEP-TRACKER.md` and is written **only** after a
full consented run whose result was read. Refused consent, a run that died
part-way, or a subset all mean no stamp at all — a red result is stamped, as
red.

The asymmetry has a cause: `--wss-stocktake` skips its own suite run on the
strength of this entry, so a stamp no run earned is worse than no stamp.

### 9 — Recording, one owner at a time

What shipped leaves the backlog, non-obvious calls reach the decision log,
behaviour and reference records take what the code changed, and the handoff is
refreshed last.

`skills/wss-start/SKILL.md::Phase 6 — Record through the owners, then close out`,
against the matrix in `workflow/WSS.OWNERSHIP.md`.

These run **sequentially, never concurrently**, and the reason inverts the
usual intuition. Their write sets look perfectly disjoint — one primitive per
record — which is exactly what makes parallelising them tempting. But every
record writer re-verifies its claims against the *other* records before
writing, so each one's read set is all of them. It is stage 5's read/write race
in the one place the file lists suggest there cannot be one.

### 10 — The session ends on the person's word, not the batch's

Phase 6 refreshes the handoff through `workflow/writers/WSS.HANDOFF-WRITER.md`
and stops. It does not call `--wss-wrap`.

`skills/wss-start/SKILL.md::What this skill does not do`, and
`workflow/WSS.OWNERSHIP.md::hand off` for the contrasting grant. An invoked
skill inherits its caller's grant, so a batch calling the closing ritual would
end the session on `--wss-start`'s authority — commit-only — rather than on the
person's. The push in `skills/wss-wrap/SKILL.md::Committing and pushing` exists
because somebody typed `--wss-wrap`, and there is no path by which a batch
acquires it by succeeding.

---

## What this page does not cover

- **The lane variant of this flow.** A worktree carrying a `.claude/WSS.LANE`
  selector syncs forward, drains a transfer queue, and lands its branch back on
  the integration branch at wrap. That is a second journey, and it belongs on
  its own page once written rather than as branches inside this one.
- **What each record may hold.** `workflow/WSS.RECORD-CONTRACT.md` owns that.
  This page asserts the order and the gates; the rules stay where they live.
- **The cadence flags.** `--wss-check`, `--wss-stocktake` and `--wss-full-check`
  are separate journeys that read what this one wrote.
