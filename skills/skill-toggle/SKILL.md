---
name: skill-toggle
description: "Toggle what each skill costs at session start — set on, name-only, user-invocable-only or off in settings.json skillOverrides, shown as a table of current levels first. Invoke only as /wss:skill-toggle; it has no flag and is never inferred from a phrase. Levels apply from the next session start."
disableModelInvocation: true
disable-model-invocation: true
---

# Toggling skill load levels

`skillOverrides` in `settings.json` sets, per skill, how much of it a session
pays for at start and who may invoke it. This skill edits that block and
nothing else.

[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md) lists `toggle` in its
matrix, and its [resolve-pointers
rule](../../wss/workflow/WSS.OWNERSHIP.md#a-skill-resolves-its-pointers-before-it-runs)
governs the read below: take `skillOverrides` fresh from both files on every
run, never from earlier in this session.

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

1. **Read the current state**, in one call, from the project directory:

   ```bash
   S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
   [ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
   bash "$S"/skills/skill-toggle/assets/wss-skill-levels.sh
   ```

   Those two resolution lines are [`contracts`](../contracts/SKILL.md)'
   canonical form. The script reads both settings files — a project entry wins
   over a user entry for the same skill — and both `skills/` trees, and prints
   one row per skill: its effective level, which file set it, which tree it
   lives in, and whether its own frontmatter hides it. **Present that table
   before changing anything**, and read each `level` against the legend above.
   A `hidden` frontmatter row is model-uninvocable whatever its level says.
   The script refuses rather than rendering a table it cannot trust: no `jq`,
   unreadable settings, or no skills tree at all exits 1 with the reason.

2. **Collect the changes.** `/wss:skill-toggle <skill> <level>` applies directly;
   bare `/wss:skill-toggle` asks, with the table as context. `on` means *delete the
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
