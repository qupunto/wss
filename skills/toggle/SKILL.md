---
name: toggle
description: "Toggle what each skill costs at session start — set on, name-only, user-invocable-only or off in settings.json skillOverrides, shown as a table of current levels first. Invoke only as /wss:toggle; it has no flag and is never inferred from a phrase. Levels apply from the next session start."
disableModelInvocation: true
disable-model-invocation: true
---

# Toggling skill load levels

`skillOverrides` in `settings.json` sets, per skill, how much of it a session
pays for at start and who may invoke it. This skill edits that block and
nothing else.

| level | startup cost | model can invoke | `/name` works | `--wss-` flag |
|---|---|---|---|---|
| *(no entry)* | full description | yes | yes | fires |
| `name-only` | name only | yes | yes | fires |
| `user-invocable-only` | none | no | yes | inert |
| `off` | none | no | no | inert |

The flag column is this suite's own hook: `skill_disabled()` in
`hooks/wss-shorthand-flags.sh` treats `off` and `user-invocable-only` as
disabled, so those flags stop firing while the slash form (if any) survives.

## Procedure

1. **Read the current state.** `skillOverrides` from
   `$PWD/.claude/settings.json` and
   `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` — a project entry wins
   over a user entry for the same skill. List every skill directory under both
   `skills/` trees beside its effective level, as the table above's rows.
   Present that before changing anything.

2. **Collect the changes.** `/wss:toggle <skill> <level>` applies directly;
   bare `/wss:toggle` asks, with the table as context. `on` means *delete the
   entry* — absence is the enabled state; do not write an `on` value.

3. **Refuse what would break, warn what will change:**
   - A **dispatch-reached skill** — one any other skill invokes, whether or
     not the user also can (check the catalog's who-invokes-whom table) —
     must never go `off` or `user-invocable-only`: both block model
     invocation, which is what a dispatch is, and the break is silent at the
     call site. `name-only` is the floor for these. Refuse and say why —
     `full-check` is the standing example: it has its own flag, yet
     `--wss-release` dispatches to it before every tag.
   - A **flagged skill** moving to `user-invocable-only` or `off` loses its
     flag and its phrase triggers; only the slash form remains (and `off`
     takes that too). Say so before writing.
   - A **plugin skill** cannot be controlled here at all: the harness ignores
     `skillOverrides` for plugin skills under bare and namespaced keys alike.
     Point at `claude plugin disable` (all-or-nothing per plugin) or, for a
     skill you author, the frontmatter key in its own file, which does travel
     with a plugin. **Write both spellings** — `disableModelInvocation: true`
     and `disable-model-invocation: true` — because which one the harness
     honours has already flipped between CLI releases and nothing warns when
     it does. Carrying both hides the skill and is tolerated under either
     spelling; carrying one is a bet that fails silently, and the cost of
     losing it is a description exposed to plugin consumers, who have no
     `skillOverrides` to mask it.

4. **Write at user scope by default** — the description floor is paid in every
   project, so `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` is where a
   toggle earns its keep. Project scope only when asked for it. Never
   `settings.local.json`: the flag hook does not read it for this key, so a
   local entry would make the hook and the harness disagree.

5. **Keep the block alphabetical**, and close by saying the new levels apply
   from the next session start — the running session keeps the listing it
   started with.
