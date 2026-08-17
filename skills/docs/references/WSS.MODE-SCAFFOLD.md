# Scaffold mode

Only when no docs directory exists at all. Decides a page **set** — the numbered
procedure below is this mode's alone; no other mode walks it.
[`WSS.TAXONOMY.md`](WSS.TAXONOMY.md) defines the canonical tiers (T1–T11), the pages
under each, and an include-when rule per page; the minimum viable set per project
profile is [`WSS.SITE-ASSEMBLY.md`](WSS.SITE-ASSEMBLY.md)'s, which only this mode loads.
Tiers with a mobile or governance page pull in
[`WSS.TIER-MOBILE.md`](WSS.TIER-MOBILE.md) and
[`WSS.TIER-GOVERNANCE.md`](WSS.TIER-GOVERNANCE.md) themselves — never cited
separately here.

## Plan

1. Identify the project's shape
   ([`wss/workflow/WSS.PROJECT-SHAPE.md`](../../../wss/workflow/WSS.PROJECT-SHAPE.md)),
   pick the closest profile, and take its minimum viable set from
   `WSS.SITE-ASSEMBLY.md`.
2. Walk the tiers in order, keeping a page **only if the thing it documents exists in the
   codebase today** — not if it should. Drop every tier that comes up empty: a CLI
   tool has no T4-web, no T6, and possibly no T5.
3. Merge at small scale, split at large: below ~6 items keep a table on the guide page;
   past ~250 lines or two audiences, split (G14, G15).
4. **State the proposed page set before writing it**, in tier order, and say what you
   dropped and why. Then write pages one at a time, wiring each up as you go (G12).

Never emit the whole tier list as headings-with-a-sentence — the walk's own failure mode, and
no other mode walks it. Tier-shaped emptiness signals coverage that isn't there and discredits
the pages that are real.

**Pages decided and not yet written are state, and this skill stores none.** Hand the
unwritten ones to `--wss-todo` so they outlive the session in the project's TODO list, and
`--wss-track` them within it. Never keep the plan only in the reply — on a large site
that is how half a documented codebase silently becomes the whole record of what was
intended.

## Scaffold

The script creates the shell — never content:

```bash
# Resolve the suite root: a checkout wins, otherwise the plugin's versioned
# cache. Why it is done this way rather than from a variable — the variable
# reaches hooks, never the Bash tool — is recorded in the `contracts` skill.
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)

bash "$S"/skills/docs/assets/wss-scaffold.sh "<Project Name>" [root-lang [translation-lang ...]]
```

**Neither the docs root nor the languages is an argument.** The script resolves them from
`WSS.docs.root` and `WSS.docs.languages` and those keys' declared fallbacks
([`wss/workflow/WSS.MANIFEST.md`](../../../wss/workflow/WSS.MANIFEST.md)), and announces both — passing a
literal `docs` here is how a project whose manifest says `website` gets scaffolded into the
wrong tree, and passing `en` is how one whose manifest says `["en","ca"]` gets a site with
no Català. Override only to scaffold what the manifest does not yet describe: `--root <dir>`
before the project name, the languages after it. A declared `languages` that is not a
non-empty array of non-empty strings exits 2 rather than falling back to monolingual.

```bash
bash "$S"/skills/docs/assets/wss-scaffold.sh "Acme UI"                # root and languages, both resolved
bash "$S"/skills/docs/assets/wss-scaffold.sh "SIME UI" en ca          # override: root English, <root>/ca/ Català
bash "$S"/skills/docs/assets/wss-scaffold.sh --root website "Acme UI" # override the resolved root
```

It refuses to touch an existing directory, skips `_navbar.md` unless multilingual, and
prints the remaining steps it deliberately does not do: the `docs:dev` script and
`docsify-cli` dependency, the README pointer, and the `{{INTRO}}` placeholder. Do those,
then continue into [Write mode](WSS.MODE-WRITE.md) — starting with `WSS.OVERVIEW.md`,
which inventories the stack, scripts, env vars, and directory tree that every later page
links back to.

Config rationale and the manual equivalent: [`WSS.SITE-SETUP.md`](WSS.SITE-SETUP.md).
