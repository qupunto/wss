# User-level context

Loaded in every session, in every project. Keep it short: anything belonging to
one project belongs in that project's own handoff or record files, not here.

## The workflow is global

Most skills live in `~/.claude/skills/` and are shared by every project. They
take project-specific facts from **`.claude/WSS.WORKFLOW.json`** in the working
directory.

**One suite, many projects — and a record holds only its own.** Another project
on this machine reaching a session, through a shared inbox or a question asked
mid-batch or a checkout in the next directory, confers no ownership. Say what
was noticed, then file it in *that* project's record and lane. Never here, and
`decisions` is not an exception. `WSS.RECORD-CONTRACT.md` carries the rule and the
one case that does belong: a change to this project's own machinery, written
from this project's facts and naming no other.

Five files are the authority and settle any disagreement between skills:

- `~/.claude/wss/workflow/WSS.OWNERSHIP.md` — who may write what
- `~/.claude/wss/workflow/WSS.RECORD-CONTRACT.md` — what each record holds, plus
  the one-source-of-truth rule and its exceptions
- `~/.claude/wss/workflow/WSS.MANIFEST.md` — which keys a manifest may set
- `~/.claude/wss/workflow/WSS.SUPERVISION-LADDER.md` — how supervised each
  record write is: when a writer acts alone, cites evidence, or asks first
- `~/.claude/wss/workflow/WSS.ADDRESSING.md` — how one thing names another: the
  `KEY#fragment` scheme, the fragment and ordinal citation forms, and the inline
  marker grammar

**What each one governs, what a project without a manifest falls back to, and
where these paths resolve under a plugin install rather than a clone, is the
`contracts` skill.** It is canonical; the paths above are here so
routing itself costs no lookup. `~/.claude/README.md` covers the `--flag`
shorthands; what each one authorizes is `~/.claude/wss/workflow/WSS.OWNERSHIP.md`'s
matrix.

## The order that settles every trade-off

**Transparency > reliability > efficiency.** Set by the owner and not
situational: where two of them pull apart, the higher wins and the cost is
stated rather than absorbed.

Efficiency is genuinely last. It never buys a silent shortcut, an unstated
assumption, a number quoted without the command behind it, or a value used from
memory instead of from the file that owns it. **The section below optimises the
third of three** — read it as subordinate to the two above it, because a cheaper
call that hides what it did is the wrong call whatever it saved.

## Rules are the owner's to set, and only the owner's

**A session never derives a rule that binds globally. Never, and without
exception.** Not from a pattern, not from one incident generalised, not from
caution. Where a case seems to need a rule that does not exist, say so and ask —
the answer is the rule, and the asking is the whole mechanism.

**This is the mirror of the no-self-authored-exemption rule, and it is the half
nothing catches.** An invented *exemption* looks like a session excusing itself
and gets challenged. An invented *prohibition* looks like prudence, survives
every review, and hardens the longer it sits. So an absolute in a loaded file
with no ruling behind it is suspect on that ground alone: ask where it came
from rather than obeying it and reporting the breach.

## Structure before enforcement

**A new rule or mechanism binds only once the structure that supports it is
fully in place — never retroactively, and never half-built.** When something new
is decided, first establish feasibility, splash and ramifications; then decide
whether it applies now or waits for the system that can carry it. Work done
before a standard existed is not in violation of it. Owner's rule, 2026-08-17;
the reasoning is the suite decision log's entry of that date.

## Tool traffic is the context, not the conversation

Prose is a few percent of the window; tool calls are nearly all of it. Optimise
the calls, not the wording — within the order above, never against it.

- **A script that runs twice gets written once.** Put it in the scratchpad and
  re-run it with arguments; a re-pasted heredoc costs its full length every time.
- **Bound every command's output** — `head`, `wc -l`, `--stat` — rather than
  dumping a file or a full diff and reading past it.
- **Read narrowly and once.** Reach for `offset`/`limit` or a grep over the
  section; never re-read what is already in the window.
- **`Edit` over `Write` on a file that exists**, which re-sends the whole body.

**Delegate the reading, keep the deciding.** A subagent's context is discarded
when it returns, so its reading costs this session nothing and only its report
arrives. Send out anything read-heavy that comes back as a verdict — a check, an
audit, a survey, a skill invoked only to look. Keep anything that needs what this
session lived through: the handoff, the wrap, a decision being logged, a commit.
A fresh context would reconstruct those from diffs, badly. **Brief every agent to
return a verdict with `file:line` citations and no file dumps** — an unbounded
report is where the saving leaks back out.

## Run the doctor rather than trusting an inventory

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/wss/tests/wss-doctor.sh
```

Read-only, and it prints every check it runs — bar the notices, which the result
line counts and only `--notes` prints. Run it rather than believing any count or
list written in a markdown file, including this one.
