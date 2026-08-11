# Site setup

Bootstrapping a docsify site in a project that has none. Docsify renders markdown in the
browser with no build step, so the files stay readable on GitHub and diffable in review —
that's the reason for choosing it over a static-site generator.

## Run the scaffold

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
bash "$S"/skills/docs/assets/wss-scaffold.sh "<Project Name>" [root-lang [translation-lang ...]]
```

`assets/wss-scaffold.sh` is the single source of truth for the generated shell — this page
explains its output and rationale, it does not restate the files. Read the script if you
need the exact bytes. It refuses to run against an existing directory.

**The root is resolved, not passed.** The script reads `WSS.docs.root` and falls back down
that key's declared chain ([`WSS.MANIFEST.md`](../../../workflow/WSS.MANIFEST.md)),
printing the root it settled on; `--root <dir>`, before the project name, overrides it.
Every `docs/` below is **one tree's root** — the site of a project that declares none and
takes the first fallback — and every `ca` is **that tree's** translation code, not a path
or a language this script requires.

Resulting shape:

```
docs/
├── index.html          # docsify config — the only non-markdown file
├── index.md            # landing page: intro + Contents/Annex tables
├── _sidebar.md         # navigation
├── _navbar.md          # language switcher — only created when multilingual
├── WSS.OVERVIEW.md         # ← you write this first, it is not scaffolded
├── <concern>.md        # ← one per subsystem that actually exists
└── annex/              # ← created by the first annex page
    └── <topic>.md
```

Content pages are deliberately absent. An empty page in the sidebar is a broken promise, so
each page is created in the same change that fills it (G12). `annex/` is likewise not
pre-created — git doesn't track empty directories.

## The docsify config, and why each option is there

| Option | Why |
|---|---|
| `relativePath: true` | Links resolve against the current file rather than the site root. Without it, every link inside a nested folder (`docs/ca/`, `docs/annex/`) 404s. Non-negotiable the moment any page isn't at the top level. |
| `loadSidebar: true` | Enables `_sidebar.md`. Without it docsify auto-generates navigation from headings only. |
| `loadNavbar: true` | Enables `_navbar.md`, which exists solely for the language switcher. Omitted on a monolingual site — a one-entry switcher is noise. |
| `subMaxLevel: 2` | Sidebar auto-expands the current page's `##` headings, so long pages are navigable without hand-maintaining sub-entries that would then go stale. |
| `alias['/<lang>/']` | `homepage` only remaps `/`. Each nested language folder needs its own alias or visiting `/ca/` renders a blank page. Add one line per language. |
| `search.depth: 3` | Indexes down to `###`, which is the level the specifics live at. |
| `homepage: 'index.md'` | Explicit, so the landing page isn't inferred from `README.md`. |

Keep the inline comments the script emits — they document non-obvious docsify behavior that
will otherwise be "cleaned up" and re-broken later.

## Wiring it into the project

The script prints these; it does not do them. **The two blocks are one project's** — its
root, its package manager, its port. What the script prints carries this project's:

```jsonc
// package.json — ILLUSTRATIVE: one tree's root and package manager
"scripts": {
  "docs:dev": "docsify serve docs --port 4000 --open"
}
```

```bash
pnpm add -D docsify-cli   # or npm i -D / yarn add -D
```

Pick a port that doesn't collide with the app's dev server or Storybook. Add `docsify-cli`
to the dependency table in `WSS.OVERVIEW.md` once that page exists.

## Point `README.md` at it

The README stays short and delegates, but carries its own section table so GitHub visitors
can navigate without running anything. **The block below is one project's README** — a
bilingual English/Català site at `docs/`, run with pnpm — not a template to copy verbatim:

````markdown

## Documentation

All documentation lives in [`docs/`](docs/index.md). It's bilingual — English and Català,
with a language switcher in the docs navbar.

The files render as plain markdown on GitHub, but for the full experience (search, sidebar
navigation, language switcher) run it through docsify:

```bash
pnpm docs:dev   # http://localhost:4000
```

| Section | Content |
|---|---|
| [Overview](docs/WSS.OVERVIEW.md) | Tech stack, scripts, directory structure, key architectural decisions |
````

The README table and the `docs/index.md` tables are separate lists. Both need updating when
a page is added (G12).

## First pages, in this order

Write `WSS.OVERVIEW.md` first — it forces an inventory of the stack, scripts, env vars, and
directory layout, which is the raw material every other page links back to.

1. `WSS.OVERVIEW.md` — tech stack tables, getting started, scripts, env vars, directory tree,
   key architectural decisions
2. One page per subsystem the codebase **actually has** — routing, data layer, auth, i18n,
   state, deploy. Not a page per subsystem you'd expect it to have.
3. `annex/` pages once a top-level page starts drowning in per-item detail (G15)

Before finishing, confirm no placeholders survive:

```bash
grep -rn '{{' docs
```
