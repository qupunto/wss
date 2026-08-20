# The harness this suite runs on

> **This file is `WSS.record.reference`.** Sole writer is `reference-writer`
> ([`WSS.REFERENCE-WRITER.md`](../workflow/writers/WSS.REFERENCE-WRITER.md));
> what it may and may not hold is
> [`WSS.RECORD-CONTRACT.md`](../workflow/WSS.RECORD-CONTRACT.md), the
> authority where the two disagree.

Current-state facts about the runtime this suite executes on — what the
harness does, not why, and not the incident that established it.

## What a session cannot do to itself

Nothing can clear or compact a session — no hook return field resets a
transcript, and there is no `SlashCommand` tool. The rule that replaces it is
a precondition: write the record, and compacting is free.

## The agent registry lags the file

The agent registry refreshes mid-session, but not promptly — an `agents/*.md`
file is undispatchable for some time after it is written. Observed
2026-08-13, both halves inside one session: two probe agents written to
`agents/` and launched in the next tool call failed with `Agent type
'<name>' not found`, the error listing only the types present when the
session began; `agents/wss-survey.md`, written the same way, became
dispatchable roughly forty minutes and many turns later, announced by a
harness notice, and ran normally. **The interval is not established and must
not be inferred from those two points.**

The consequence is a build order: do not assume an agent just written can be
exercised by the batch that wrote it. Ship the file and its callers
together, and treat any same-batch statement about that agent's behaviour as
inferred until the harness announces the type and a dispatch actually
returns. Re-derive by writing a throwaway `agents/zz-probe.md`, dispatching
it immediately — it fails — then dispatching it again later in the same
session.

## A task-notification is not the user

A background task-notification re-enters `UserPromptSubmit`. Observed live
2026-08-10 (pass 13 F2): a subagent's completion notice, whose report quoted
flag names as data, passed through `hooks/wss-shorthand-flags.sh` and
injected roughly 10.3 KB of "unconditional instruction" including
`--wss-start`'s commit authorization, with no user input. Every observed
notification payload begins at position 0 of `.prompt` with the literal
`<task-notification>` banner, and the hook refuses exactly that shape —
start-anchored, so a user pasting a transcript that merely *contains* the
marker mid-message still fires the flags they typed; the both-directions
test sits in `wss/tests/wss-hook-contract.sh` under "A task-notification is
not the user". Whether the harness feeding notifications through this event
is intended is an upstream question, filed as `qupunto/wss#21`.

## A peer session is not the user

`UserPromptSubmit` has a **second** non-user ingress: a cross-session message
from a peer session arrives as `.prompt` too. Observed live 2026-08-20 — a
peer's boundary report reading "route findings to `--wss-tidy`, a flag that is
retiring" fired that flag's whole block through
`hooks/wss-shorthand-flags.sh`, presenting COMMIT authority nobody granted.

**The shape, measured across every delivery in this machine's transcripts
(`grep -rl 'Another Claude session sent a message' ~/.claude/projects
--include='*.jsonl'`, nine sessions, zero exceptions):** `.prompt` begins at
position 0 with the literal sentence `Another Claude session sent a message:`,
the `<cross-session-message from=… from-name=… from-mode=…>` open tag on the
line after it, the peer's text inside, and a trailing harness paragraph about
treating it as a teammate's request. The hook refuses the prose sentence and
that tag together, and the bare tag alone in case a harness change ever drops
the prose — start-anchored both ways, so a user quoting a peer's message
inside a prompt of their own still fires the flags they typed. The
both-directions test sits in `wss/tests/wss-hook-contract.sh` under "A peer
session is not the user", and was watched failing against a hook with the
guard stripped before it counted.

## Two facts only a probe establishes

Two harness facts no session can establish by reasoning, both measured by
probe. A subagent launched with **no** `model` override runs the *session's*
model — it does not silently drop to a cheaper tier — and an explicit
override is honoured, so a tier assignment that is passed does take effect.
And a subagent that reads no files and runs no tools still costs a fixed
spawn price, barely varying by tier — the figure and the method are
`wss/tests/WSS.TOKEN-ECONOMY.md`'s lens 13, not repeated here. Re-measure
both by dispatching a throwaway agent asked only to report its own model.

## Plugin mode

Everything below was measured against a real install rather than read off the
documentation. It is what a plugin install and a checkout differ by, and it
arrived here on 2026-08-18 from the hazard record, which keeps only the part
that bites a machine whose `~/.claude` *is* the checkout.

### Plugin hooks merge with the user's rather than replacing them

A plugin and a user config declaring the same hook events both fire, so every
shared event runs twice from the next session on. Measured 2026-08-02: a
session was asked how many handoff blocks it had been given and answered two.
Re-derive by installing and asking a fresh session to count what it was
injected — reading the documentation does not establish it.

### Uninstalling leaves the marketplace cache on disk

`claude plugin uninstall` clears the plugin out of `settings.json`, and neither
it nor `claude plugin marketplace remove` deletes
`~/.claude/plugins/cache/<marketplace>/`. Established 2026-08-08 by running the
documented teardown and then the gate. Anything keying on that directory rather
than on `settings.json` — `wss/tests/wss-doctor.sh`'s coexistence check does —
still reads the suite as installed after both commands return 0, so the
directory is a third teardown step and `rm -rf` on it is the only thing that
clears it.

**Skipping `marketplace remove` leaves a second residue, in a directory nothing
checks.** Measured 2026-08-18 (`wss/logs/WSS.DECISIONS.md`'s `(thirteenth)`
entry): a registration in `known_marketplaces.json` and a clone under
`plugins/marketplaces/<marketplace>` both survive. Two directories per
marketplace is the shape to remember — `cache/` holds the plugin's files,
`marketplaces/` holds the clone it came from — and only the first is what a
coexistence question is about, since a clone is fetched source that no hook
event reaches. `wss-doctor.sh` keys its coexistence failure on `cache/` for that
reason and carries a separate warn, added 2026-08-18, for the pair left behind
when a teardown skips `claude plugin marketplace remove`.

**A project-scope-enabled plugin refuses a scopeless uninstall**, answering
"enabled at project scope"; pass the scope the install used.

### Installing writes tracked settings, and removing rewrites the whole file

Adding a marketplace and installing write `extraKnownMarketplaces` and
`enabledPlugins` into `settings.json`. Removing both leaves them behind as empty
objects rather than deleting the keys, and rewrites the file to do it — on
2026-08-02 that also silently reordered `permissions.defaultMode`. The file
therefore differs before and after an install-uninstall cycle that kept nothing;
restore it from source control rather than trusting the uninstall to be
reversible.

### `${CLAUDE_PLUGIN_ROOT}` reaches hooks, is empty in a model-run command, and changes on every update

For a git-hosted install the root can only be
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` — measured
2026-08-02 against a git-sourced plugin, whose files including `skills/` exist
there and nowhere else. The version segment is a commit-SHA prefix for some
plugins and a semver for others, and **several versions of one plugin sit side
by side on disk**, which is what "changes on every update" looks like rather
than an argument for it: anything written beneath the root is destroyed by the
next update. A **local-directory** marketplace is the outlier — in the
2026-08-01 experiment it resolved to the marketplace *source* folder with no
version segment, because a local marketplace has a source folder to point at and
a git install has none.

**The variable is empty in a Bash command a model runs.** Measured 2026-08-02
from a real git-hosted install, with the plugin's hooks demonstrably live in the
same session. It reaches hook processes; it does not reach the Bash tool. So use
it in a **hook**, and never in a fenced block a model will execute — resolve the
root directly instead, checkout first and then the versioned cache path.
`contracts` carries the canonical form, and `wss/tests/wss-doctor.sh` fails
on `$CLAUDE_PLUGIN_ROOT` inside any fenced block, with two contract tests behind
that rule.

### The installation and the config directory are two directories that a checkout collapses into one

The *installation* — `skills/`, `workflow/`, `hooks/`, `wss-doctor.sh` — and the
*user's config directory* are the same place in a checkout and different places
under a plugin, which is how one variable did both jobs unnoticed.
`wss/tests/wss-doctor.sh` names them `CLAUDE_DIR` and `CONFIG_DIR` and carries
the reasoning at both sites. The direction that matters: resolving a **written**
file against the installation would put it under the root that every update
destroys. Nothing this suite writes does — the sweep checkpoint resolves to
`$PWD/.claude/WSS.SWEEPS.json`, per project, in whatever directory the user is
working in, and the bug inbox to `$CONFIG_DIR/WSS.BUG-REPORTS.md` (checked
2026-08-01, correcting a claim that both sat under the plugin root).
`${CLAUDE_PLUGIN_DATA}` has never been needed.

**`hooks/wss-session-check.sh` is the one place that resolves the other way on
purpose**, against `${CLAUDE_PLUGIN_ROOT:-$CLAUDE_DIR}`, because the doctor
ships with the installation. Its guard is `[ -x "$doctor" ]`, so a wrong
resolution never errors: the doctor simply never runs from `SessionStart` and
says nothing about not running.

### Install keys are captured at install time, so a rename never reaches an install

Claude Code keys plugins as `<plugin>@<marketplace>` in `installed_plugins.json`
and marketplaces by name in `known_marketplaces.json`, both written at install
time. `/plugin update` fetches new content *into* the existing key and never
rewrites the key, and GitHub's rename redirect keeps an old marketplace source
resolving — so nothing errors and nothing signals, and a machine that installed
this suite before the 2026-08-10 rename still prints
`workflow-secretary-suite:`. Updating cannot fix it. The adopter's route is to
remove and re-add the marketplace, then install `wss@wss`, which gives
`/wss:<skill>` — still namespaced, never bare.

### Skill control is per-plugin, and the one per-skill lever is frontmatter

`skillOverrides` is ignored for plugin skills at both `name-only` and `off`,
under bare and namespaced keys — proven 2026-08-01 in two rounds, the second
because the first had generalised from `name-only` alone. `claude plugin
disable` works and takes every skill in the plugin with it. Two consequences
inside this suite: `wss/tests/wss-doctor.sh`'s dispatch-only check goes inert in
plugin mode — **do not delete it, it stays correct for the checkout shape** —
and a skill that specifies its own self-deactivation cannot have it.

**Half of that has an exception, and it is the dangerous half.** A hook that
reads the overrides itself still honours them whatever the harness does:
`hooks/wss-shorthand-flags.sh` calls `skill_disabled()`, so under a plugin
install `off` **suppresses the flag while the skill stays fully callable** —
half a disabled skill, and the half that survives is the non-deterministic one
(measured on a real install 2026-08-02). `name-only` behaves as documented in
both forms.

**The lever that does reach a plugin skill is its own frontmatter, and which
spelling the harness honours has already changed once, silently.** Measured
2026-08-08 on CLI 2.1.226 with a four-skill probe plugin: the kebab
`disable-model-invocation` hides a skill, the camelCase
`disableModelInvocation` does not, and carrying both hides and is tolerated. On
2.1.224 it was recorded the other way round. **Re-measured 2026-08-18 on CLI
2.1.234** from a project-scoped install, read back twice with different question
shapes: identical readings, so the both-keys hedge is confirmed rather than
merely prudent (`wss/logs/WSS.DECISIONS.md`'s `2026-08-18 (thirteenth)` entry).
**Write both keys** in anything that must stay hidden; no check inside a suite
can detect the next reversal, because the behaviour is external to it and only a
real install reveals it.

**And `claude plugin details`' token figures do not discount hidden skills** —
the kebab probe skill was invisible to the model and still reported its ~40
always-on tokens. Treat the projection as what the plugin *declares*, a ceiling,
never as the realised cost of a tree that hides anything. It is still the right
tool for measuring description cost; counting bytes is not.

### `plugin.json` ignores unknown fields silently

`permissions` and `skillOverrides` are both rejected this way. `claude plugin
validate <path>` names every unknown field and states that Claude Code ignores
it at load time — run it before believing a manifest key exists.
