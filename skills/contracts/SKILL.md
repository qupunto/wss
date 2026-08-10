---
name: contracts
description: "How this suite is wired — its skills are global, project facts come from `.claude/WSS.WORKFLOW.json` in the working directory, and the contract files sit in a known place in a checkout and in a plugin install. Invoke when a session must establish how the workflow is configured, or when a skill cannot resolve a contract path."
---

# How the workflow is wired

One job: say where things are and which file settles a disagreement. Every rule
this skill points at lives in the file named, not here — a second copy is a copy
that drifts.

## The skills are global; the facts are per project

The skills in this suite are shared by every project. Nothing in them names a
project. They take project-specific facts from **`.claude/WSS.WORKFLOW.json`** in the
working directory — which records to write, which commands to run, which branch
integrates and which publishes.

**A project without a manifest still works.** Skills fall back to conventional
filenames, skip what they cannot resolve, and **say in one line that they did**.
A skipped step announced is a step the user can overrule; a skipped step inferred
from a fallback is one nobody sees. When a skill reports falling back, the fix is
`--wss-adopt` (`adopt`), which writes the manifest.

## The three files that settle disagreements

Relative from any skill file, which is what makes them resolve in both install
forms:

- [`../../workflow/WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md) — **who may write
  what.** The invariant: every record file has exactly one writer. An
  orchestrator that needs a record written calls the primitive that owns it, even
  when the edit is one line and obviously correct.
- [`../../workflow/WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md) —
  **what each record holds, and what it must never hold.**
- [`../../workflow/WSS.MANIFEST.md`](../../workflow/WSS.MANIFEST.md) — **which keys a
  project's `.claude/WSS.WORKFLOW.json` may set**, and what each falls back to when
  absent.

Where they resolve to on disk depends on how the suite was installed, and this is
the one place the two forms genuinely differ:

| Installed as | Suite root | Contracts at |
|---|---|---|
| A clone into the config directory | `~/.claude` | `~/.claude/workflow/*.md` |
| A plugin | `${CLAUDE_PLUGIN_ROOT}` | `${CLAUDE_PLUGIN_ROOT}/workflow/*.md` |

**Prefer the relative link over either absolute path.** A skill reaching for
`~/.claude/workflow/WSS.OWNERSHIP.md` is correct in a checkout and wrong in a plugin
install, where the suite is under the plugin cache and the config directory holds
the user's own settings instead. `${CLAUDE_PLUGIN_ROOT}` is set by the harness
only in plugin form, so its absence is what distinguishes the two.

`README.md` at the suite root covers the `--flag` shorthands; what each one
authorizes is `workflow/WSS.OWNERSHIP.md`'s matrix. Neither is loaded automatically
in either form.

## Run the doctor rather than trusting an inventory

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
"$S"/wss-doctor.sh
```

Read-only, and it prints what it checks. Run it rather than believing any count
or list written in a markdown file, this one included.

**Two lines rather than one, because `$CLAUDE_PLUGIN_ROOT` cannot be used
here** — it reaches hook processes, not the Bash tool.

The fallback is the versioned cache path, which is the only place a
git-installed plugin's files exist. The order matters: **a checkout wins**, so a
machine holding both runs the one being worked on. Where neither resolves, `$S`
is empty and the command fails loudly on `/wss-doctor.sh` rather than running
something unintended.

**Do not "fix" this by hard-coding `~/.claude`** — correct in a checkout only,
and `wss-doctor.sh` fails on that inside a fenced block for exactly this reason. The
hooks are the one place the variable *is* right, and they use it.

## What this skill does not do

- **It is not the contracts.** It names them and says where they resolve. Any
  question about who owns a record, what a record may hold, or what a manifest
  key falls back to is answered by opening the file, not by asking here.
- **It writes nothing** — no record, no manifest, no settings. `--wss-adopt` writes a
  manifest; the record writers own the records.
- **It does not decide anything.** A session that needs a choice made goes to the
  project's own open-decisions record, which `--wss-todo` owns.
