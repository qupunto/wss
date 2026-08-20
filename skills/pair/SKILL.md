---
name: pair
description: "How two sessions share one checkout as designer and executor, and how planning content moves between them through a relay directory. Read when a session starts in a paired checkout, when a relay item needs applying or bouncing, or on \"who is the designer\", \"consume the relay\", \"what can the designer write\". Owns the protocol; it is not a flag and runs nothing."
---

# Two sessions, one checkout

A paired checkout is run by **two sessions with different jobs**. The rulings
are the decision log's `2026-08-19 (forty-seventh)`, `(fifty-second)`,
`(fifty-seventh)`, `(fifty-eighth)` and `(fifty-ninth)` entries.

| Role | Does | Writes in the repo |
|---|---|---|
| **designer** | Designs features, answers decisions in conversation with the owner | **Only relay items.** Nothing else, ever |
| **executor** | Runs the `--wss-start`→`--wss-wrap` loop and every routine write | Everything else |

**Push and commit authority are the executor's**, stated as a rule rather than
left to inference: the designer neither commits nor pushes.

**A direct owner order given in a session overrides that session's defaults
for the ordered act, and the act executes where the consent was given.** That
is not an exception to the roles — it is user authority, which supersedes by
nature (`2026-08-19 (forty-first)`). **Consent does not survive relaying
between sessions**: a session told to do something cannot hand that permission
to the other one, so the ordered act happens where it was ordered, and the
other session learns of it as a fact rather than as an instruction. The
defaults resume immediately afterwards; an override is spent on the act it
named.

**This file is the protocol's one source.** Where prose describing the pairing
lives anywhere else — a session's memory file, a pasted brief — it is
superseded by this file rather than kept in step with it.

## What the relay is, and why it is a directory

`WSS.pair.relay` — `.claude/WSS/RELAY/`, gitignored, per-checkout. The designer
publishes one **item file per handoff**; the executor applies and deletes them.

**A directory of whole files, rather than one shared file**, because the
alternatives both fail on the thing this mechanism exists to survive. A single
file guarded by "no designer writes between loop end and loop start" is mutual
exclusion by clock and message, and the message channel is exactly what proved
unreliable. A single file consumed by rename is closer, and still has a
half-written-item race that atomically-published whole files cannot.

**Publish temp-then-rename.** Write under a temporary name in the same
directory, then rename it in. A partial item is never visible, because a rename
within one filesystem is atomic and a partly-written file never carries the
final name.

## An item

```
target: <record key, e.g. WSS.record.decisions>
kind: <log-entry | amendment>
authority: <whose call the content was, written at authoring time>
title: <for a log-entry>
---
<body, verbatim-ready>
```

**`authority:` is written when the item is authored and never reconstructed
when it is applied.** An applier cannot know whose call something was; it can
only copy what the header says, so a header that guesses is worse than one that
admits session judgment.

## Who holds which role: the claims file

`WSS.pair.claims` — `.claude/WSS/PAIR`, gitignored, **one per checkout or
worktree**. One line per role, and nothing else:

```
executor: <session-id> <inbox-socket-path>
designer: <session-id> <inbox-socket-path>
```

**A session's role is the line carrying its own session id.** The executor
writes its claim when its loop starts; a designer claims the vacant line at
session start. **Where both lines are held by other sessions, a new session
asks rather than assuming one** — there is no third role, and guessing makes
two sessions believe they hold the same one.

**The socket proves DELIVERABILITY, never liveness.** It is named after the
*process*, not the session — one process hosts many sessions in turn, so a
socket outlives every session that ever claimed a role through it. **A socket
that exists tells you a message will arrive; it tells you nothing about who is
there to read it.** Measured, not assumed: a claim was once removed while its
socket still existed, the removal read as a fault, and the socket was simply
that process's PID with a new session behind it.

**So liveness comes from claiming, not from checking.** A session writes its
own claim at session start, overwriting whatever line stood for that role. The
newest claim is the live one, and a line for a session that has ended is
corrected by the next session of that role starting — not by anyone inspecting
it. **Never re-assert a claim on another session's behalf**: it cannot be known
from outside whether that session still exists, and a restored line is
indistinguishable from a current one. That is the whole liveness test: **do not read liveness from
`ListAgents`**, which reports an ancestor as busy and a stopped orphan as idle.
Consumers get the designer's address from this file, never from a label.

**An unrecognised role name is a finding, never a silent default.** A file
holding `reviewer: …` means someone extended the protocol without extending
this skill, and treating the line as noise hides that.

**One file, one checkout** — a worktree gets its own, because roles are held
per working tree and two trees are two pairings.

## Consuming, at each loop boundary

For each item, in filename order:

1. **Read its `target:`** and apply the body **verbatim** through the skill that
   owns that record — `--wss-log`, `--wss-todo`, `--wss-plan`. Placement,
   ordinals, format and the index stay theirs. The relay moves content, never
   authority over where content goes.
2. **Add a line naming the relay item and the authoring session.** Mandatory,
   ruled by the owner when the relay was adopted. An applied entry carries the
   **executor's** commit trailer, so without the line nothing in `git log`
   distinguishes an entry the executor wrote from one it relayed — and that
   distinction is how a transcription error was caught once already.
3. **Delete the item, only after confirming its own apply succeeded.**
   Immediately, in the same pass. Both halves are load-bearing and they guard
   opposite failures: deleting late leaves a **double-apply** window, and
   deleting before confirming leaves a **lost-apply** one. Both have happened.
4. **A malformed item is bounced back untouched** — reported to the designer,
   never repaired. Repairing it silently makes the executor the author of
   content the header attributes to someone else.

**Filename identity is not a guard.** Where the same item exists at two paths,
only the names being equal stops a second apply, and that is an accident rather
than a mechanism. Consume one directory, the one `WSS.pair.relay` names.

## What never rides the relay

**Milestone marks, pushes, merges, tags, and any outward act.** The relay moves
planning content; **consent moves in conversation with the owner and nowhere
else.** A designer that has the owner's word for an outward act performs it
where that word was given, or asks the owner to say it again to whoever will.

## What the pairing needs from the machine

**`crossSessionInbound: "accept"` in the user's settings.** The default holds a
message between a bypass-mode session and a prompting-mode session pending
approval, and drops it after five minutes. **The protocol loses messages in
both directions without it, silently** — the `2026-08-19 (fifty-second)` entry,
found the hard way. Setting it is the owner's; no session edits its own
permissions.

The channel still serves ad-hoc coordination once the relay carries the
planning content, so it is worth having even though nothing routine depends
on a message arriving.

## What this file does not do

- **It is not a flag and runs nothing.** It states the protocol; the loop's
  consume step is `--wss-wrap`'s, behind the `paired-sessions` toggle.
- **It does not decide roles.** A session's role is the claim it holds in
  `WSS.pair.claims`; where both are held by others, a new session asks rather
  than assuming one.
- **It grants nothing.** Every authorization is the caller's, exactly as for
  any other skill.
