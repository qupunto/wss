# Style guide

The rules that make these docs verifiable rather than decorative.

## Voice

**Present tense, third person, describing the system.** "The plugin regenerates
`routeTree.gen.ts` on every change." Not "we generate" and not "you will see".

Second person is allowed **only** inside numbered how-to steps: "Create
`src/routes/$lang/route-name.tsx`", "Run `pnpm lint` before committing".

**No filler.** Cut "it is important to note that", "basically", "simply", "as you can
see", "in order to". Cut sentences that restate the heading.

**Em dashes for asides**, not parentheses stacked on parentheses:

> `PersistentLink` works the same way and additionally preserves the current search params
> — it's the convention used by `Breadcrumbs`, `SectionTitle`, and `NavigationMenu`
> instead of a raw `<a href>`.

## Every paragraph earns its place by explaining *why* (G2)

This is the single distinguishing property of these docs. Compare:

❌ `auth.token_type` is used to build the header.

✅ `auth.token_type` (e.g. `"Bearer"`) is used instead of a hardcoded literal, in case the
backend changes the auth scheme in the future.

❌ `Select.Content` uses `min-w-[var(--reference-width)]`.

✅ The dropdown uses `min-w-[var(--reference-width)]` — a **minimum**, not a fixed width.
Ark UI exposes `--reference-width` with the trigger's current width; if `Content`'s exact
width were pinned to that variable, the dropdown would end up as narrow as the trigger at
that moment, and any longer label would wrap onto multiple lines.

Patterns that carry rationale, use them liberally:

- `X instead of Y, because …`
- `… so that …` / `… which is what keeps …`
- `If Z were done the obvious way, it would …` (the rejected alternative)
- `This matters for … : if …, then …` (consequence made concrete)
- `a bug in the library, not in this app's code, triggered by …` (attribute the fault)

## Backtick everything mechanical (G3)

File paths, directories, function names, type names, props, i18n keys, query keys,
`localStorage` keys, URL segments, HTTP method + path, npm package names, CSS classes,
Tailwind tokens, env vars, CLI commands, literal values.

> `refreshAccessToken()` in `src/services/auth.ts` makes a `POST /v1/auth/refresh` with
> the `refresh_token` as the `Authorization` header.

Prose left unbacticked: concept names, product names, and the first introduction of a term
(which gets **bold** instead).

## Bold

- First mention of a concept the page defines: "uses **JWT with a refresh token**"
- The load-bearing word in a sentence that would otherwise be misread: "a **minimum**, not
  a fixed width", "**one flat file per domain**"
- Warnings: "**Do not edit it by hand.**"
- The lead-in of a list item that names a rule: `- **Draft vs. applied selection**: …`

Not for emphasis-as-decoration. Two or three per section, not per paragraph.

## Structure elements

### Numbered lists — for flows and procedures

Each step names the file or function that performs it, so the list doubles as a call graph:

```markdown
1. The user fills in the form at `/$lang/login`
2. `Login.tsx` calls `loginRequest({ username, password })` (`src/services/auth.ts`) via `useMutation`
3. `loginRequest` makes a `POST /v1/auth/token` with the credentials as query params
4. If the response isn't `ok`, it throws a `LoginError(status, detail)` — `Login.tsx` maps
   `status` (400/401/422) to an "invalid credentials" message
```

### Bulleted lists — for sets of independent behaviors

```markdown
- If there's no token → redirects to `/$lang/login`
- If the token has expired → attempts an automatic refresh
- If the refresh fails → clears storage and redirects to `/$lang/login`
- If everything's fine → returns `{ token: access_token }` and lets the route continue
```

`→` for "then" in condition/outcome pairs.

### Tables — for anything enumerable

Always `|---|---|` (no alignment padding needed; docsify and GitHub both handle it).
Recurring shapes:

| Purpose | Columns |
|---|---|
| Dependency list | Package \| Version \| Purpose |
| Route map | File \| URL path \| Description |
| Endpoint contracts | Endpoint \| Params \| Response |
| Props reference | Module \| Props \| Description |
| Design tokens | Token \| Value \| Usage |
| Env vars | Variable \| Required \| Purpose |
| Key files (page footer) | File \| Purpose |

Use `—` in a cell that has no value, with the reason in parentheses:

```markdown
| `auth.logout` | — (reads the token from storage, not an explicit input) | — (no response body; returns `Promise<void>`) |
```

Escape pipes inside cell content: `` `currentPage?: string \| null` ``.

### Code blocks — always tagged, always elided (G5)

Tag with the language the block is in — `typescript` (the default for `.ts` and config),
`tsx` (JSX), `ts` (short snippets), `bash`, `json`, `dockerfile`, `nginx` on a project of
that stack, and whatever the stack at hand actually uses. Untagged fences only for
directory trees.

Show the shape, cut the body:

```typescript
export const periodsQuery = queryOptions({
  queryKey: ["periods"],
  async queryFn() {
    /* ... */
  },
})
```

Elision markers: `/* ... */` in JS/TS, `# ...` in shell/Dockerfile, and a trailing comment
describing what was cut (`# ... pnpm install --frozen-lockfile, pnpm build ...`).

Add an inline comment when a literal needs explaining:

```typescript
{
  expires_in: number   // seconds until expiration
  expire_date: number  // unix timestamp of expiration (computed on the client)
}
```

### Directory trees — plain fence, aligned comments

```
src/
├── main.tsx                  # Entry point: React, Router, and QueryClient
│
├── routes/                   # Route definitions (TanStack Router, file-based)
├── components/               # Agnostic, reusable components — never consume the API
│   └── ui/                   # UI primitives (built on Ark UI + CVA)
├── types/                    # Centralized TypeScript types — see types.md
│   ├── index.ts              # Cross-cutting primitives
│   └── endpoints.ts          # Params/Response contracts per endpoint
└── styles/
    └── theme.ts              # Single source of truth for design tokens
```

Comments point at the page that covers each directory in depth (`— see types.md`). Use a
bare `│` line to group related entries.

### Diagrams

`architecture.md` exists to show shape, so it needs a picture. Draw it here; an ad-hoc
one anywhere else is `--wss-diagram`, which routes back to `docs` rather than to a
skill of its own — choosing a form and laying out boxes is behaviour Claude already has,
so it is served by a hook block that costs nothing until the flag is typed, where a
skill's description would be paid for in every session.

Three rules apply. The first ships a broken page rather than a missing one when you get
it wrong: **check what will render it.** ASCII in a plain fence is the default, and **docsify
needs a plugin the default `index.html` does not load**, so a Mermaid fence chosen without
checking shows raw markup to every reader. The second: every box and arrow is a claim, so draw
from what you read and leave out a direction you cannot establish. The third: stop before the
graph stops being readable — a table is often the better answer.

```
user action ──► SQLite row ──► outbox row ──► drain() ──► API
                    │                                      │
                 UI reads                          server_id written back
```

Put the *why* in the prose underneath. A diagram shows structure; it does not explain a
decision, and a page that asks it to does both jobs badly.

### Blockquotes — for one caveat that would derail the prose

Rare. One per page at most. Reserved for a correction of a natural wrong assumption:

```markdown
> `pnpm check` runs `tsc -b` (build mode with project references), not `tsc --noEmit`. The
> root `tsconfig.json` only has `references` — a plain `tsc --noEmit` on the root compiles
> nothing and always "passes", even with real type errors.
```

### `---` horizontal rules

- Always after the intro paragraph, before the first `##`
- Between top-level `##` sections on pages that are a list of independent topics
  (`WSS.OVERVIEW.md`, `services.md`, `routing.md`)
- Always before the closing `## Key files`

Pages that read as one continuous narrative (a single flow described start to finish) skip
the inter-section rules. Be consistent within a page.

## Cross-links (G6)

Relative paths, always. From `docs/annex/` up with `../`.

```markdown
see [modules.md](modules.md)
see the `components/` vs `modules/` rule in [modules.md](../modules.md)
see [FilterSimple in the annex](annex/modules.md#filtersimple)
see [Active user](#active-user) below
```

Anchor form: lowercase the heading, spaces → `-`, drop punctuation. Backticks in a heading
disappear from the slug (`## \`types/index.ts\` — cross-cutting primitives` →
`#typesindexts--cross-cutting-primitives`) — anchors like that are brittle, so prefer
linking to headings without inline code.

Add `above` / `below` when linking within the same page. Every claim that depends on
another page's detail gets a link rather than a restatement — say it once, link to it
everywhere else.

## Cataloguing what exists vs. what's aspirational (G7)

Mark unused code explicitly so a reader doesn't build on it:

> Some of these types were declared during the project's initial setup based on the design
> specifications, anticipating features that don't exist in the app yet. There's no need to
> delete them — but **before relying on one**, check that the actual design still uses it
> as defined.

Same for generated files:

> `src/generated/routeTree.gen.ts` is auto-generated. **Do not edit it by hand.**

## Things to avoid

- Screenshots and images — the docs are text, diffable and greppable
- Version numbers in prose (they go stale); keep them in the one dependency table
- Duplicating a table or explanation across pages — link instead
- Documenting a private helper no caller outside its file uses
- Changelog entries and dates — that's what git is for
- Hedging: "should probably", "may or may not". Verify, then state it.
