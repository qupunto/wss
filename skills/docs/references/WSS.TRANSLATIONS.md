# Translations

A multilingual site keeps the default language at `docs/` root and each translation in a
sibling folder named by language code: `docs/ca/`, `docs/es/`.

**Every example on this page is one project's tree** — an English root at `docs/` with a
Català translation at `docs/ca/`, later joined by `docs/es/`. That is the tree
`WSS.docs.root: "docs"` and `WSS.docs.languages: ["en", "ca"]` describe
([`WSS.MANIFEST.md`](../../../wss/workflow/WSS.MANIFEST.md)); read `docs` and `ca` below as
that project's root and codes, and substitute this one's. The **shape** — root language at
the root, one folder per translation, filenames identical across all of them — is what
transfers, and it is the same shape at any root under any language codes.

```
docs/
├── index.md            # English (default, served at /)
├── auth.md
├── _sidebar.md
├── annex/
│   └── components.md
└── ca/                 # Català, served at /ca/
    ├── index.md
    ├── auth.md
    ├── _sidebar.md
    └── annex/
        └── components.md
```

**Filenames never translate.** `auth.md` stays `auth.md` in every language — only the
content and the sidebar *labels* are translated. This keeps relative links identical across
mirrors, so a link that works in one language works in all of them.

## The mirror is structural, not just textual

Every translated file has:

- the same filename and path
- the same **heading structure**: same count, same nesting, same order (headings' *text* is
  translated)
- the same tables with the same columns and rows
- the same code blocks, **untranslated** — code, identifiers, and file paths stay as they
  are; only surrounding prose and inline code comments get translated
- the same links, pointing at the same relative paths

A reader switching language mid-page should land on the same section.

## The anchor trap

Translated headings produce translated slugs. In-page and cross-page anchor links inside a
translated file must point at **that language's** slugs:

`docs/auth.md`:
```markdown
see [Active user](#active-user) below
see [types.md](types.md#reusing-module-types)
```

`docs/ca/auth.md`:
```markdown
vegeu [Usuari actiu](#usuari-actiu) més avall
vegeu [types.md](types.md#reutilització-de-tipus-de-mòdul)
```

Copying the English anchor into the translated file produces a link that silently does
nothing. Accented characters are legal in the slug (`#protecció-de-rutes`) — lowercase the
translated heading and replace spaces with `-` exactly as for English.

Cheapest way to check every anchor in a translated file resolves:

```bash
# ILLUSTRATIVE — one tree's paths, not a command to run as written. The shape is:
# the anchors a file links to, then the slugs its target actually defines.
grep -oE '\]\([^)]*#[^)]+\)' docs/ca/auth.md
grep -n '^#' docs/ca/auth.md
```

## Translating well

- **Translate meaning, not word order.** These are technical docs in a real language, not
  a gloss of the English.
- **Keep technical terms that the team actually says in the original.** "Routing",
  "Deploy", "Storybook", "queryKey", "debounce" stay as-is where translating them would
  produce something nobody uses out loud. Translate the ones that do have a natural local
  form ("Autenticació", "Mòduls i pàgines", "Tipus", "Serveis i dades").
- **Prose about code still names code in code terms.** "la ruta és propietària de la query
  (`departmentsQuery`)" — the identifier is untouched.
- **Sidebar labels are translated; sidebar paths are not**, and they carry the language
  prefix:

```markdown
<!-- docs/ca/_sidebar.md -->
- [Home](/ca/)
- [Visió general](/ca/WSS.OVERVIEW.md)
- [Mòduls i pàgines](/ca/modules.md)

- **Annex**
- [Mòduls en detall](/ca/annex/modules.md)
```

- **`_navbar.md` lives only at the root** and lists every language:

```markdown
- [English](/)
- [Català](/ca/)
```

## Adding a language

The seven steps are the procedure; the paths, codes and package manager in them are still
that one tree's — adding `es` to a site rooted at `docs/`. Substitute and the order holds.

1. Copy the default-language tree: `cp -r docs/ca docs/es` (copy an existing translation,
   not the English — it's already structured as a mirror)
2. Translate every file, headings included
3. Translate `docs/es/_sidebar.md` labels and repoint every path to `/es/`
4. Fix every in-page anchor to the new language's slugs
5. Add `- [Español](/es/)` to `docs/_navbar.md`
6. Add `'/es/': '/es/index.md'` to `alias` in `docs/index.html` — without it, `/es/`
   renders blank
7. Verify with `pnpm docs:dev`: switch language on several pages, follow a few anchor links

## Never leave a mirror stale (G13)

Editing a page means editing every language's copy of it in the same change. If a
translation genuinely can't be done now, say so explicitly in the response — don't let it
pass silently as done.
