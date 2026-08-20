# Auditing docs for drift

> **A shared method, not a skill.** See [`WSS.CHECKS.md`](WSS.CHECKS.md). `--wss-docs` runs it
> over the site it just wrote or was asked to verify; `--wss-health-check --deep` runs it at full
> scope. §0 resolves the project's own shape and every later section is a check; the
> scope that selects which pages get the expensive treatment is the runner's, and
> deliberately not in this file.

The mechanical half of G9 (verify, don't eyeball) and the detection half of G16 (code wins).
**G-numbers throughout this file are the guardrails in
[`skills/docs/references/WSS.GUIDELINES.md`](../../skills/docs/references/WSS.GUIDELINES.md)**,
which is where they are defined and numbered; cited here by number so a finding can name one in review.

Docs rot silently. Run this when asked to check the docs, or after any refactor that
touched paths, props, or contracts.

**Every deterministic step below — resolving the project's shape, then each check that is
"run this, read the output" — lives in `wss-docs-audit.sh`, not inlined here.** What stays in
this file is judgment: what a docs audit is looking for, what makes a hit a false positive,
what a finding means once you have it. Resolve and invoke it the same way
[`skills/docs/SKILL.md`](../../skills/docs/SKILL.md)'s scaffold step does:

```bash
# Resolve the suite root: a checkout wins, otherwise the plugin's versioned cache.
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)

bash "$S"/wss/scripts/wss-docs-audit.sh                    # every section below, in order
bash "$S"/wss/scripts/wss-docs-audit.sh dead-paths links    # or name one or more sections
```

Each numbered section below names the subcommand that runs it.

## 0. Resolve the project's shape first

Every check reads `$DOCS`, `$ROOTLANG`, `$TRANSLATIONS[]` and `$DEV`. They come from
`WSS.docs` in the manifest, whose three keys and **declared fallbacks** are
[`WSS.MANIFEST.md`](../workflow/WSS.MANIFEST.md)'s. `wss-docs-audit.sh resolve` (and every other
subcommand, which calls it first) prints what it found:

- the docs root, or a note that none resolves — every check below is then skipped, because
  a root that resolves to nothing makes every check walk an empty set and report a clean
  site, which is the one failure this method cannot survive silently
- the languages, or a note that the project is monolingual — the translation-parity check
  (§5) is skipped
- the dev command, or a note that none is declared — the live-render step (§7) is skipped

**A skipped check is reported, not omitted.** "No translations declared" and "the
parity check found nothing" read identically in a findings list and mean opposite
things.

## 1. Dead paths

Every backticked path in the docs should exist. `wss-docs-audit.sh dead-paths` restricts the
search to paths rooted at a real top-level directory — read from `git ls-files` rather than a
fixed list, so nothing is missed for calling its source directory something a fixed list
didn't expect — and drops template placeholders.

Three classes of hit, and only the first two are bugs:

1. **Renamed or moved** — update the doc.
2. **Deleted** — delete the section, or the doc now describes something that doesn't exist.
3. **False positive** — a template placeholder in a how-to, or a path written in shorthand
   relative to a directory established earlier on the page. Leave both classes; the shorthand is
   deliberate and reads better in context.

If a path was never real at all — it was inferred rather than read — rewrite that whole
section from source. One invented path means the surrounding prose is also unverified.

## 2. Broken relative links and anchors

Two link flavours coexist and resolve differently: prose links are **file-relative**
(`[types.md](types.md)`), sidebar/navbar links are **site-root-relative**
(`[Overview](/WSS.OVERVIEW.md)`). `wss-docs-audit.sh links` checks both accordingly.

A file-relative link that only works from the root is the classic symptom of a page copied
into a translation folder without repointing — and of `relativePath: true` missing from
`index.html` (see [`WSS.SITE-SETUP.md`](../../skills/docs/references/WSS.SITE-SETUP.md)).

The script checks that the target file exists; it does not compare anchors. For those,
compare the `#slug` in each link against the headings of the target file, in the target
file's own language (see
[`WSS.TRANSLATIONS.md`](../../skills/docs/references/WSS.TRANSLATIONS.md) — a translated file's
anchors are translated too). That comparison stays manual: judging whether a translated
heading still matches its slug is not mechanical.

## 3. Stale type and prop definitions

The highest-value check, and it cannot be automated. `wss-docs-audit.sh types` lists every
type/interface/struct/class block the docs copied in — then open each named source file.

Common drift: a prop added, renamed, or made optional in code and never reflected in the
annex. Copy the current definition verbatim, then re-check whether the surrounding bullets
still describe real behavior.

## 4. Stale enumerations

Places where the docs list a complete set — these break whenever the set grows:

- route tables vs. the actual `routes/` tree
- endpoint tables vs. the endpoints object in the service layer
- `Params`/`Response` contract tables vs. the types file
- dependency tables vs. `package.json`
- scripts blocks vs. `package.json` scripts
- env var tables vs. `.env` / `env.ts`
- design token tables vs. the theme file
- directory trees vs. the real directory
- `## Key files` footers vs. the actual exports of those files

The check is always the same two lines — *the real set* against *the set the page lists* —
and only the second is mechanical. **The block below is an illustration from one project's
tree**, not a command to run as written, and not something `wss-docs-audit.sh` can run for
you: the real set's command is different for every enumeration in the list above and every
project's tree. Substitute the enumeration this project documents.

```bash
# ILLUSTRATIVE — one tree's routes. The shape is: real set, then documented set.
find src/routes -name '*.tsx' | sed 's|src/routes/||' | sort
grep -oE '`\$?lang?[^`]*\.tsx`' "$DOCS/routing.md" | tr -d '`' | sort -u
```

## 5. Translation parity

Skipped entirely on a monolingual project — `wss-docs-audit.sh translations` says so rather
than reporting no findings. For each translation it diffs the file listing against the ROOT
language (whose pages sit at `$DOCS` itself, so the root listing excludes every translation
subdirectory — a site-wide `_navbar.md` legitimately exists only at the root; ignore that
line), then flags a heading-count mismatch, which signals a section added to one language
only.

## 6. Index parity

Every page must appear in its own language's `_sidebar.md` and `index.md`, and (if it has a
section table) in `README.md` — **in every language, checked against that language's own
index**, never against the root's. `wss-docs-audit.sh index` walks every language directory
(at the root, treating the translation subdirectories as other languages rather than pages)
and reports any page missing from its own sidebar or index — both are the language's OWN
index; a page listed only in the root's is a finding.

## 7. Markdown mechanics

Cheap, fully mechanical, and the checks most often skipped. `wss-docs-audit.sh mechanics`
runs all of it.

Two traps make the naive version useless: grepping `^```` counts *closing* fences as
findings, and a four-backtick outer fence (used to wrap a template containing its own
fences) desynchronizes any checker that just toggles a boolean. The script tracks the fence
*length* instead — a block opens with N backticks and closes with N or more — and treats a
directory tree (the one legitimate untagged fence) as one expected hit per page that draws
one, every other hit as a finding. It also flags unfinished `{{` scaffolding, and table rows
whose column count differs from their header — usually an unescaped pipe inside a type like
`` `string | null` ``, which silently eats a column.

Then it renders the site. A page that passes every grep can still fail to load — a stray
`alias` entry or a missing `loadSidebar` breaks navigation without touching any markdown.
This is the one step with no grep substitute, so a project that declares no `devCommand`
gets the skip line from §0 rather than a quiet pass. Where it does run, the script starts
the dev command, waits for it, hits the shell and one page per language over HTTP, then
stops the server again.

## 8. Accuracy — do the claims hold?

Sections 1–7 verify *mechanics*: that paths resolve, links work, fences close. **None of them
verify that a stated fact is true.** A page can assert `max: 10` when the pool is 20, name a
function that was renamed six months ago, and pass every check above. Since G1 and G16 are the
whole point of documenting from source, this is the check that matters most — and the only one
that cannot be fully automated.

`wss-docs-audit.sh accuracy` runs the mechanical first pass: every code symbol and literal
the docs assert should be findable in the source. It runs two checks — backticked identifiers
shaped like code (camelCase, PascalCase, SCREAMING_SNAKE) confirmed to appear somewhere
outside `$DOCS`, and backticked `key: value` / `key = value` assertions confirmed against the
same source tree.

Expect a low single-digit false-positive baseline from these two passes, and
treat a spike as the signal — the baseline is not a failure to silence.

**Three false-positive classes, all structural — do not "fix" the docs to silence them:**

1. **Rejected alternatives.** G4 requires naming the approach that was *not* taken, so the
   symbol of the road not taken appears in the docs precisely because it is absent from the
   source. This is the dominant class.
2. **Type annotations read as assignments.** A prop signature (*illustration:*
   `` `data: Equipment[]` ``) is not a claim that the field equals something. The script's
   `*'[]'` guard catches most; some slip through.
3. **Claims about code that legitimately does not exist yet**, correctly flagged as a gap by the
   page itself (see the `## Known gaps` pattern).

**Known blind spots.** Space-separated assignments — `key value` rather than `key: value`,
whatever this stack's config files use (*illustration:* `minSdk 24` in Gradle) — are not
matched, and lowercase-hyphenated names (package names) are filtered out of the symbol pass:
those are covered by the dependency-table check in section 4 instead.

**Then read.** The mechanical pass only proves a token appears *somewhere*. It cannot tell you
that a described flow still happens in that order, that a rationale still applies after a
refactor, or that a `## Key files` row still lists the real exports. For every page whose
subject changed, re-read the source and re-read the page against it. That is the check, and it
is manual.

## Reporting

Report drift as a list of concrete findings — file, what the doc claims, what the source
says — and fix what you can verify. For anything ambiguous (a section describing behavior
you can't locate in the code at all), flag it rather than deleting it: it may document
something that moved rather than something that vanished.

Never "fix" a doc by softening the claim. Either verify and state it precisely, or remove
it.
