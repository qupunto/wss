# The routing-health checklist

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What it finds:
a skill that will not be reached when it should be, or will be reached when it
should not. The routing surface is the frontmatter `description` plus the flag —
both claims about ordinary language rather than about the tree — and, for a file
carrying neither, the citations that reach it.

**This is the only check on these files that can push a description longer, and
that is why it exists.** The budget warns above its cap, the prose prune cuts,
and [`WSS.TOKEN-ECONOMY.md`](WSS.TOKEN-ECONOMY.md) trims — every other pressure
runs one way. Nothing measures whether what survives still routes. **A skill that
stops firing raises no error, ever**: the session simply does the work by hand
and no one learns the door closed. The anchor is already stated in that file's
flavour-versus-behavior lens — *a description trimmed below its trigger surface
trades tokens for misrouting, which always loses* — and this method is how that
sentence gets enforced instead of admired.

Each lens is a question, what a hit looks like, the tree's own proven example,
and the drawback that must be outweighed. **The gate is asymmetric on purpose:
bytes are recoverable and a closed door is not**, so a lens that argues for
adding trigger surface needs only to be right, while one that argues for cutting
it needs to be right *and* cheap. A lens with no hit is a result.

## The lenses

1. **Is there a route at all?** Three doors exist — the flag, the trigger clause,
   and a citation from a file the session has already loaded. A skill with none
   of them is reachable only by the model's guess at its first sentence. Proven:
   the flagless primitives are reached because `CLAUDE.md` and the skills that
   dispatch to them name them — **that citation is the route**, so retiring the
   sentence that names one silently orphans it, and the retirement will not look
   like a routing change. Drawback: a skill carrying
   `disableModelInvocation: true` is deliberately unreachable from language, and
   its slash command is the whole route by design. That is not a hit, and
   "fixing" it re-opens a door someone shut on purpose.

2. **Does the advertised door exist?** A description declaring a shorthand the
   hook does not serve degrades in silence: the flag reaches the model as
   ordinary text, and the skill fires only if the model happens to read the
   description and infer it. Proven by shape — a missing hook is the failure that
   `wss-doctor.sh` was written for, where every flag still mostly worked and
   nothing looked wrong. Drawback: none, which is why this lens is a doctor check
   rather than a reading. Run it; do not re-derive it here.

3. **Does the trigger clause name the job the body does?** A job the body
   performs that appears nowhere in the routing surface is one nobody reaches on
   purpose. The pressure is structural rather than careless: **a job added to a
   body costs nothing at write time, and the description is where the budget
   bites**, so growth lands in the body by default and the surface is what gets
   trimmed to pay for it. Drawback: not every job needs its own language. One
   reached only by dispatch from another skill, or only behind a flag, needs no
   trigger — and adding one buys false-positive risk for a door already open.

4. **Does a trigger fire on conversation about the work?** The false-positive
   half, and `wss-doctor.sh` already checks its structural signature — a
   one-word trigger, or a phrase observed to misfire. Run it rather than reading
   for it. **What the doctor cannot check is whether the trigger's casualness
   matches the action's reversibility**: a phrase long enough to be an
   instruction is still a remark when the skill behind it commits and pushes.
   Drawback: over-correcting here is what produces lens 5's cost.

5. **Negative routing is a symptom, not a fix.** "Not X, that is Y" inside a
   description is two skills' overlap being paid for in every session of every
   project, forever, to describe a collision rather than end it. Proven: the
   budget check's own warning names negative routing as what usually grew.
   Drawback: where the overlap is genuine and permanent, one clause is cheaper
   than the misroute it prevents — but that is a ruling to record, with the
   trigger that would reopen it, not a default to reach for.

6. **Two doors to one job, and the wrong one is cheaper to walk through.** Where
   a primitive and an orchestrator both answer a request, the one that fires is
   whichever the user's words matched — not whichever costs less. Proven: a page
   that already exists is handed straight to `docs-writer`, and `--wss-docs`
   keeps only the case that is genuinely a decision, because re-deriving a
   settled placement buys nothing but the cost of loading the skill. Drawback:
   naming the cheap door inside the expensive skill's description spends bytes in
   every session to save them in some. Measure before assuming it wins.

7. **Does the grant behind the door match the invitation?** A trigger is an
   invitation, and it has to match what accepting it authorizes. A casual phrase,
   or one that reports a state rather than requesting an act, is a hit on any
   skill that commits, pushes, tags or deletes. Proven: the flags holding a push
   grant carry an explicit refusal of the words that would otherwise reach them —
   approval and completion are reports, never requests to publish. Drawback:
   none, and the asymmetry is deliberate; a skill with no outward act needs no
   refusal and should not grow one for symmetry.

8. **Does the route survive the install form?** The assembly `wss-publish.sh`
   builds is not this checkout: it copies, then deletes files, blanks records,
   and strips the `wss-` prefix off every skill and command name. A route can
   resolve here and be missing, emptied or renamed there — and **a citation is
   the only route the body-only class has**. Ask lenses 1–3 of the *assembly*.
   Proven: `skills/adopt/SKILL.md` cites `references/WSS.LOCAL-CI.md`, which
   `wss-publish.sh` deletes from the shipped tree. **Pose the question; never
   answer it** — a route only a real install can settle is settled *wrong* by
   reading, so it leaves the sweep as a question for the owner rather than as a
   finding. Drawback: the tree must be built before it can be read, so assemble
   once per sweep.

9. **Does a body assert a route the far end does not serve?** Lens 2's mirror,
   and the direction nothing reads: a body naming a flag, skill, file or heading
   as the way somewhere makes a routing claim, and the reader who follows it
   pays. Proven twice and never by a check — a prose `~/.claude/…` path routes in
   a checkout and resolves to nothing under a plugin, and `wss-doctor.sh` reads
   fenced blocks only, by design. Drawback: naming a skill to say what *not* to
   reach for, or to cite a ruling, is not a route.

10. **Does a door advertising exhaustiveness reach everything?** "End to end",
    "every", "full" are coverage claims, and the reader who walks through one
    stops looking; a door dispatching a subset errors on nothing — lens 1's
    silence, one level up. Proven: `--wss-full-check`, whose door advertises the
    whole while its dispatch reaches only part of `--wss-tools`' jobs.
    Drawback: widening costs every caller, narrowing spends bytes against the
    cap; it is a ruling either way, never an edit made inside the sweep.

This list grows, and a lens added to it re-opens every file checked under the
shorter list — bounded, now, to the classes below.

## Which lenses fire on which file

The classes are the sweeps file's `routing` split (`covered` / `not-covered`)
cut again by whether language is a door. **Read a file only for its row's
lenses:** a lens that cannot fire there is not a pass, and logging it as clean
reports coverage the sweep never had.

| Class | How to tell | Lenses |
|---|---|---|
| Model-invocable | a `description`, no `disableModelInvocation` | all |
| Slash-only | `disableModelInvocation: true`, and every `commands/*.md` | 1, 2, 7–9 |
| Body-only | no frontmatter, and most of the tree | 1, 8, 9 |

Lens 6 takes a pair, so it runs once over the set; lens 10 fires only where a
description claims exhaustive scope. On the body-only class, 1, 8 and 9 are a
search for citations in and route claims out rather than a full read — which is
what makes the rest of this list affordable.

## What is NOT a finding

- **A description over budget because its trigger surface needs the bytes.** The
  budget is a warning, not a cap, and the trade is settled in
  [`WSS.TOKEN-ECONOMY.md`](WSS.TOKEN-ECONOMY.md) — read it rather than
  re-deciding it per skill.
- **A flagless, slash-only skill.** See lens 1's drawback.
- **A job with no trigger that is only ever dispatched to.**
- **An overlap already ruled on**, with the ruling recorded. Re-litigating it
  every sweep is the cost lens 5 was meant to avoid.
- **A description shorter than its neighbours.** Length is not the measure;
  coverage of the language a user would actually use is.

**Scope, disposition and authorization are the runner's** — see
[`WSS.CHECKS.md`](WSS.CHECKS.md). This file says only what counts as a finding.
