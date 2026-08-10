# Page anatomy

Skeletons. Fill them with real, verified content — never ship a placeholder.

## Guide page (top-level `docs/<concern>.md`)

````markdown
# <Concern>

<1–3 sentences: what this part of the system is, the **key technology or decision** in
bold, the directory it lives in, and a link to the sibling page that owns the adjacent
concern.>

---

## Configuration

<How it's wired up, with the config file named and an elided snippet.>

---

## <Core mechanic>

<Prose + snippet. Explain why, not just what.>

### <Sub-mechanic>

<Detail that only matters once the core mechanic is understood.>

### Adding a new <thing>

1. <Step, naming the file to create>
2. <What happens automatically>
3. <Code the developer must write>

```typescript
/* the minimal shape */
```

---

## Gotchas

<Only if there are real ones. Library bugs, ordering constraints, things that look wrong
but are load-bearing. Attribute the fault: "a bug in the library, not in this app's code".>

---

## Known gaps

<What is missing or unfinished, stated so it is not mistaken for design (G7). One line each:
what is absent, and the consequence. "No token refresh flow — an expired token surfaces as a
401 the drain loop re-throws rather than parks, which can stall the outbox.">

---

## Key files

| File | Purpose |
|---|---|
| `src/<path>` | <What it holds — name the actual exports> |
````

**Opening paragraph examples** (this is the highest-leverage part of the page):

> The app uses **TanStack Router v1** with file-based routing. The Vite plugin reads
> `src/routes/` and generates `src/generated/routeTree.gen.ts` automatically on every change.

> The `src/services/` layer holds the `fetch` functions and TanStack Query `queryOptions`,
> **one flat file per domain**. Each endpoint's `Params`/`Response` types live in
> `src/types/endpoints.ts`, not in the service files — see `types.md`.

> Shared TypeScript types are centralized under `src/types/`, in **three files** with
> different responsibilities. The idea is that a backend developer can open
> `src/types/endpoints.ts` and see exactly what each endpoint expects and must return,
> without having to read the React components.

Note what each one does: names the technology, names the directory, states the organizing
rule, and gives the *purpose* of the arrangement.

## Annex reference page (`docs/annex/<topic>.md`)

Exhaustive, item-by-item. One `##` per item, in the order a reader would meet them (or
alphabetical if there's no natural order).

````markdown
# <Items>

Reference for <the set> in `src/<dir>/` (see the rule that defines this layer in
[<page>.md](../<page>.md)): exact props, behavior, and any non-obvious gotchas. For
<adjacent concern>, see [<other-annex>.md](<other-annex>.md).

---

## <ItemName>

`src/<exact/path>.tsx` is <one sentence: what it is and what it's built on, naming the
underlying library import>.

```typescript
type Props = {
  /* copied verbatim from the source */
}
```

- <Behavior of a specific prop, and what it defaults to.>
- **<Named rule>**: <the non-obvious contract — e.g. draft vs. applied state.>
- <What the component deliberately does *not* do, and whose job it is instead.>

<Usage snippet with a real call site named:>

Controlled usage (example in `src/routes/$lang/_auth/equipments.tsx`):

```tsx
<Item label={t('common.period')} options={options} value={value} onValueChange={setValue} />
```

### <A gotcha with its own heading>

<Mechanism, why the naive approach breaks, what the code does instead.>

---

## <NextItem>

...
````

For items too small for a `##` each, a table is better:

```markdown
| Module | Props | Description |
|---|---|---|
| `Page` | `children` | Outer wrapper — full-height flex column |
| `Header` | `currentPage?: string \| null` | Fixed header: logo, nav, avatar. `currentPage` marks the active item — see [auth.md](../auth.md#active-user) |
```

## Landing page (`docs/index.md`)

```markdown
# <Project> — Documentation

**<ACRONYM>** (<expansion — and its translation if the name isn't English>) is <what it is,
who it's for>. Built with <stack>, it consumes <the API> and presents <the domain>.

---

## Contents

| File | Description |
|---|---|
| [WSS.OVERVIEW.md](WSS.OVERVIEW.md) | Tech stack, scripts, directory structure, key architectural decisions |
| [<page>.md](<page>.md) | <comma-separated list of the page's subjects, no verb> |

## Annex

| File | Description |
|---|---|
| [annex/<topic>.md](annex/<topic>.md) | <what it enumerates> (exact props) |
```

Descriptions are noun phrases listing the page's subjects — "File-based routing with
TanStack Router, router context, loader patterns" — not sentences.

## `docs/_sidebar.md`

Flat list, `/`-rooted paths, blank line + bold non-link entry to open a group:

```markdown
- [Home](/)
- [Overview](/WSS.OVERVIEW.md)
- [Routing](/routing.md)

- **Annex**
- [Modules in detail](/annex/modules.md)
- [Design system](/annex/design-system.md)
```

Order by tier, which is reading order for a newcomer — never alphabetical. Group headers
appear once a group holds two or more pages. `references/WSS.TAXONOMY.md` owns the full tier
order and a complete grouped sidebar example; don't re-derive it here.

## `docs/_navbar.md`

Language switcher only, if the site is multilingual:

```markdown
- [English](/)
- [Català](/ca/)
```

## The `## Known gaps` section

Earns its place on `WSS.OVERVIEW.md` and on any page whose subject is incomplete. It is often the
single most useful section in the site: it is what a newcomer needs in order to distinguish
"deliberately absent" from "nobody has got to it", and it is the honest form of G7.

Two rules. **State the consequence, not just the absence** — "no tests exist" is a fact,
"no tests exist, so the outbox ordering guarantee is upheld by review only" is useful.
And **do not editorialize**: a gap list is not a backlog and not a criticism, so no severity
labels, no "should be fixed ASAP". Where the reason for a gap is genuinely unknown, say
"reason unclear" and leave it (G8) — a plausible explanation invented to fill the space is
worse than the gap itself.

Project-wide gaps collect on `WSS.OVERVIEW.md`. A gap local to one subsystem stays on that
subsystem's page, where the reader hits it in context.

## The `## Key files` footer (G11)

Include it when the page maps onto a concrete set of source files — `auth.md`,
`services.md`, `modules.md`, `i18n.md`, `deploy.md` all have one. Skip it when the page is
already organized by file (`types.md`, an annex reference) or is purely conceptual.

The Purpose column names the **actual exports**, not a vague summary:

```markdown
| File | Purpose |
|---|---|
| `src/services/auth.ts` | `authQuery`, `userQuery`, `refreshAccessToken`, `clearStorage`, `logoutRequest`, `loginRequest`, `LoginError` |
| `src/lib/storage.ts` | Generic `Storage` class and the `authTokenStorage` instance |
| `src/hooks/useUser.ts` | `useUser(enabled?)` hook reading `userQuery` |
```

This table is the most-used part of the page — a reader who knows the concept comes back
only for "which file was that in". Keep it complete and keep it accurate.
