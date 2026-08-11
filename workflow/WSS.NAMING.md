# The file-naming convention — which files are the suite's, and in what form

**The one authority on the names of files the suite creates.** Without it the
form is implied by whatever each writer happened to copy from its neighbour, and
a tree ends up with two spellings of the same role — which defeats the whole
point, since the form exists to be read at a glance.

Which keys a manifest may set is [`WSS.MANIFEST.md`](WSS.MANIFEST.md); who may
write each record is [`WSS.OWNERSHIP.md`](WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](WSS.RECORD-CONTRACT.md). This file is about
**filenames**, and settles nothing about keys, contents or writers.

**Read this together with [`WSS.MANIFEST.md`](WSS.MANIFEST.md), never instead of
it, in any pass that settles filenames and key names together** — `--wss-adopt`
and `update` are both such passes, and for them this is a second read rather
than a saving. The split makes neither contract optional: a filename decided
without the key table produces a record nothing resolves, and a key declared
without this file produces a path that resolves to a name the tree will not
keep.

## The convention, and what it does NOT cover

Every file **the suite creates in order to run** carries a prefix, so a user can
tell at a glance which files in their tree are theirs and which are the suite's.
That is a transparency property: a file that looks like the user's but is
written by machinery is the shape a hostile change would take.

**The form follows the file's ROLE, not its extension.** Extension is a poor
proxy: `.json` is caps for the manifest, which people read, and would be a
hidden lowercase file if it were a cache.

| Role | Form | Examples |
|---|---|---|
| A name the harness resolves as an identifier | `wss-<name>`, lowercase — the filename *is* the invocation | `skills/check/`, `commands/log.md` |
| Executable | `wss-<name>.sh`, lowercase | `wss-doctor.sh`, `hooks/wss-alert.sh` |
| Anything a person is meant to read or notice | `WSS.<FUNCTION>` | `WSS.TODO.md`, `.claude/WSS.WORKFLOW.json`, `WSS.ALERTS-ON` |
| Machine bookkeeping with no reader | `.wss-<name>`, hidden | `.wss-alert.stamp` |

**Caps are a channel, not decoration**, which is why that last row is not an
oversight. Caps mean *a human should notice this*, borrowed from `README`,
`TODO` and `LICENSE`. A debounce timestamp has no reader, so shouting at nobody
would be noise — and the same test is what keeps a cache from becoming
`WSS.CACHE.json`.

## The segment grammar

**A dot is navigation — it narrows to a subset.** A hyphen joins words inside
one concept and never navigates.

```
WSS . <GROUP> . <FUNCTION> . <instance> . <ext>
      CAPS       CAPS         lowercase
      optional                optional
```

- **The FUNCTION segment is caps**, hyphenated only where the concept itself
  needs several words: `WSS.AUDIT-COVERAGE.md`. Hyphens do not group files.
- **A GROUP segment is caps and names a subsystem** whose files belong together:
  `WSS.LANE.CONFLICTS.md`. Reading left to right narrows — suite, then lane
  machinery, then which file.
- **An instance segment is lowercase and follows the FUNCTION it instantiates**,
  appearing only where the file is one of many: `WSS.TODO.frontend.md` beside
  the unsplit `WSS.TODO.md`. The unsplit name is a prefix of every split one, so
  the lane variants sort beside their twin and one glob — `WSS.TODO.*` — catches
  the whole family.

**Case is what tells a group from an instance**, and position alone cannot be
trusted to. Lane names are user-chosen, so a lane may be called `docs`, `state`
or `todo`. `WSS.LANE.CONFLICTS.md` and `WSS.TODO.frontend.md` are unambiguous at
a glance; their all-lowercase equivalents are not. That is why the convention is
cased.

**A file about a subsystem takes no instance segment** — its subject is the
machinery, not one member. `WSS.LANE.CONFLICTS.md` is one per project and
addressed to `lane-record-sync`; only a genuinely per-lane file, like that
lane's transfer queue, carries a lane name.

## Manifest keys are not filenames

`WSS.record.todo`, `WSS.lanes.named`, `WSS.commands.indexRegen` are keys inside
`.claude/WSS.WORKFLOW.json` — [`WSS.MANIFEST.md`](WSS.MANIFEST.md)'s subject, not
this file's. **The `WSS` root carries the namespace once; every key below it
takes no prefix and no caps.** Prefixing each key would restate the namespace on
every line and buy nothing — below the root there is nothing foreign to separate
from, and keys already navigate by dot, which is the same idea one level down.
The caps root against the lowercase keys is the same group-versus-instance
casing the filename grammar uses.

## Ownership is authorship, not usage

Using a file, or even being its sole writer, does not make it ours — that is
governance. The prefix marks files whose *format we invented*. A file whose name
belongs to somebody else's tool keeps that name, however much the suite writes
it:

- `SKILL.md`, `hooks.json`, `plugin.json`, `marketplace.json`, `settings.json` —
  the harness resolves these by name.
- `README.md`, `CHANGELOG.md`, `LICENSE`, `.gitignore` — the ecosystem's.
- `index.md`, `_sidebar.md`, `index.html` — docsify's, even though the suite's
  own scaffold writes them.

**Where the two tests disagree, authorship of the *name* wins.** `index.md` is
produced on every docs scaffold and is still not ours, because docsify defined
it. Conversely a page the suite always emits under a name of its own —
`WSS.OVERVIEW.md` — is ours, while a topic annex a project chose to write
(`annex/lane-synching.md`) is that project's.

## A boundary case is the owner's to rule, not this file's

**The test for a new file: would this file exist if the suite were not
installed?** If yes, it is not ours to rename. If no, it takes the prefix.

Where that is genuinely unclear, **ask the owner** and record the ruling here
rather than guessing — the boundary is the kind of thing that has to be decided
once. The authority is the owner's; this file is only where the answer is
written down, and it is written down in one place so that a second reading of
the same case cannot be produced by opening a different file.
