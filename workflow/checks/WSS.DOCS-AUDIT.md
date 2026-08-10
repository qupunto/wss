# Auditing docs for drift

> **A shared method, not a skill.** See [`WSS.CHECKS.md`](WSS.CHECKS.md). `--wss-docs` runs it
> over the site it just wrote or was asked to verify; `--wss-full-check` runs it at full
> scope. Every section here is a check; the scope that selects which pages get the
> expensive treatment is the runner's, and deliberately not in this file.

The mechanical half of G9 (verify, don't eyeball) and the detection half of G16 (code wins).
**G-numbers throughout this file are the guardrails in
[`skills/docs/SKILL.md`](../../skills/docs/SKILL.md)**, which is where they are
defined and numbered; cited here by number so a finding can name one in review.

Docs rot silently. Run this when asked to check the docs, or after any refactor that
touched paths, props, or contracts.

## 1. Dead paths

Every backticked path in the docs should exist. Restrict to paths rooted at a real
top-level directory, and drop template placeholders:

```bash
ROOTS='src|docs|public|app|lib|packages|scripts'
grep -rhoE "\`($ROOTS)/[A-Za-z0-9_.\$/-]+\`" docs --include='*.md' \
  | tr -d '`' | grep -v '\.\.\.' | sort -u \
  | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Three classes of hit, and only the first two are bugs:

1. **Renamed or moved** — update the doc.
2. **Deleted** — delete the section, or the doc now describes something that doesn't exist.
3. **False positive** — a template placeholder in a how-to (`src/routes/$lang/route-name.tsx`),
   or a path written in shorthand relative to a directory established earlier on the page
   (`types/endpoints.ts` under a `src/types/` heading). Leave these; the shorthand is
   deliberate and reads better in context.

If a path was never real at all — it was inferred rather than read — rewrite that whole
section from source. One invented path means the surrounding prose is also unverified.

## 2. Broken relative links and anchors

Two link flavours coexist and resolve differently: prose links are **file-relative**
(`[types.md](types.md)`), sidebar/navbar links are **site-root-relative**
(`[Overview](/WSS.OVERVIEW.md)`). Check both accordingly:

```bash
grep -rnoE '\]\(/?[A-Za-z0-9._/-]+\.md' docs --include='*.md' | while IFS=: read -r f _ m; do
  t=${m#*](}
  case "$t" in
    /*) p="docs$t" ;;                 # site-root-relative (sidebar/navbar)
     *) p="$(dirname "$f")/$t" ;;     # file-relative (page prose)
  esac
  [ -e "$p" ] || echo "BROKEN LINK: $f -> $t"
done
```

A file-relative link that only works from the root is the classic symptom of a page copied
into a translation folder without repointing — and of `relativePath: true` missing from
`index.html` (see [`WSS.SITE-SETUP.md`](../../skills/docs/references/WSS.SITE-SETUP.md)).

For anchors, compare the `#slug` in each link against the headings of the target file, in
the target file's own language (see
[`WSS.TRANSLATIONS.md`](../../skills/docs/references/WSS.TRANSLATIONS.md) — a translated file's
anchors are translated too).

## 3. Stale type and prop definitions

The highest-value check, and it cannot be automated. For each type block copied into the
docs, diff it against the source:

```bash
grep -rn "type Props" docs/annex/components.md   # then open each named source file
```

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

```bash
# example: routes documented vs. routes on disk
find src/routes -name '*.tsx' | sed 's|src/routes/||' | sort
grep -oE '`\$?lang?[^`]*\.tsx`' docs/routing.md | tr -d '`' | sort -u
```

## 5. Translation parity

```bash
# files present in one language and not the other
# (_navbar.md legitimately exists only at the root — ignore that one line)
diff <(cd docs && find . -name '*.md' -not -path './ca/*' | sed 's|^\./||' | sort) \
     <(cd docs/ca && find . -name '*.md' | sed 's|^\./||' | sort)

# heading-count mismatch signals a section added to one language only
for f in docs/*.md; do
  b=$(basename "$f"); [ -f "docs/ca/$b" ] || continue
  a=$(grep -c '^#' "$f"); c=$(grep -c '^#' "docs/ca/$b")
  [ "$a" = "$c" ] || echo "HEADING MISMATCH: $b ($a en / $c ca)"
done
```

## 6. Index parity

Every page must appear in `_sidebar.md`, `docs/index.md`, and (if it has a section table)
`README.md` — in every language:

```bash
for f in docs/*.md docs/annex/*.md; do
  b=${f#docs/}
  case "$b" in _*|index.md) continue;; esac
  grep -q "$b" docs/_sidebar.md || echo "NOT IN SIDEBAR: $b"
  grep -q "$b" docs/index.md    || echo "NOT IN index.md: $b"
done
```

## 7. Markdown mechanics

Cheap, fully mechanical, and the checks most often skipped.

Two traps make the naive version useless: grepping `^```` counts *closing* fences as
findings, and a four-backtick outer fence (used to wrap a template containing its own
fences) desynchronizes any checker that just toggles a boolean. Track the fence *length* —
a block opens with N backticks and closes with N or more:

```bash
cat > /tmp/fence.awk <<'AWK'
{
  if (match($0, /^`+/)) {
    n = RLENGTH; info = substr($0, n + 1); gsub(/[ \t]+$/, "", info)
    if (n < 3) next
    if (flen == 0) { flen = n; if (info == "") print F ":" NR ": untagged opening fence" }
    else if (n >= flen && info == "") { flen = 0 }
  }
}
END { if (flen) print F ": UNCLOSED fence" }
AWK
# a directory tree is the one legitimate untagged fence — expect one hit per page that
# draws one, and treat every other hit as a finding
find docs -name '*.md' | while read -r f; do awk -v F="$f" -f /tmp/fence.awk "$f"; done

# unfinished scaffolding
grep -rn '{{' docs

# table rows whose column count differs from their header — usually an unescaped pipe
# inside a type like `string | null`, which silently eats a column
find docs -name '*.md' | while read -r f; do
  awk -v F="$f" '
    /^\|/ { n = gsub(/(^|[^\\])\|/, "&"); if (!w) w = n; else if (n != w) print F ":" NR ": " n " cols, expected " w }
    !/^\|/ { w = 0 }
  ' "$f"
done
```

Then render it. A site that passes every grep can still fail to load — a stray `alias`
entry or a missing `loadSidebar` breaks navigation without touching any markdown:

```bash
npm run docs:dev &   # or pnpm/yarn
sleep 4
for u in / index.md _sidebar.md WSS.OVERVIEW.md; do
  printf "%-16s %s\n" "$u" "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:4000/$u")"
done
```

## 8. Accuracy — do the claims hold?

Sections 1–7 verify *mechanics*: that paths resolve, links work, fences close. **None of them
verify that a stated fact is true.** A page can assert `max: 10` when the pool is 20, name a
function that was renamed six months ago, and pass every check above. Since G1 and G16 are the
whole point of documenting from source, this is the check that matters most — and the only one
that cannot be fully automated.

Mechanical first pass: every code symbol and literal the docs assert should be findable in the
source.

```bash
DOCS=docs; SRC=.
EX=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build
    --exclude-dir="$DOCS" --exclude=package-lock.json --exclude=pnpm-lock.yaml)

# symbols: backticked identifiers shaped like code (camelCase, PascalCase, SCREAMING_SNAKE)
grep -rhoE '`[A-Za-z_][A-Za-z0-9_.]*(\(\))?`' "$DOCS" --include='*.md' | tr -d '`' \
  | sed 's/()$//' | sort -u \
  | grep -E '^([a-z][a-zA-Z0-9]*[A-Z][A-Za-z0-9]*|[A-Z][A-Za-z0-9]*[A-Z_][A-Za-z0-9_]*|[A-Z_]{3,})$' \
  | while read -r sym; do
      grep -rqF "$sym" "$SRC" "${EX[@]}" 2>/dev/null || echo "SYMBOL NOT IN SOURCE: $sym"
    done

# literals: backticked `key: value` / `key = value` assertions
grep -rhoE '`[A-Za-z_][A-Za-z0-9_]* *[:=] *[^`]+`' "$DOCS" --include='*.md' | tr -d '`' \
  | sed 's/  */ /g' | sort -u \
  | while read -r claim; do
      key=${claim%%[:=]*}; key=${key% }; val=${claim#*[:=]}; val=${val# }
      case "$val" in *' '*|''|*'[]') continue;; esac   # prose, empty, or a type annotation
      grep -rqE "$key[^A-Za-z0-9_]+[\"']?${val%%[,;)]*}" "$SRC" "${EX[@]}" 2>/dev/null \
        || echo "LITERAL NOT CONFIRMED: $key = $val"
    done
```

Expect a low single-digit false-positive baseline from these two passes, and
treat a spike as the signal — the baseline is not a failure to silence.

**Three false-positive classes, all structural — do not "fix" the docs to silence them:**

1. **Rejected alternatives.** G4 requires naming the approach that was *not* taken, so
   `LOCATION_ALWAYS` or `AsyncStorage` appear in the docs precisely because they are absent
   from the source. This is the dominant class.
2. **Type annotations read as assignments.** `` `data: Equipment[]` `` is a prop signature, not
   a claim that `data` equals something. The `*'[]'` guard catches most; some slip through.
3. **Claims about code that legitimately does not exist yet**, correctly flagged as a gap by the
   page itself (see the `## Known gaps` pattern).

**Known blind spots.** Space-separated assignments (`minSdk 24` in Gradle, `key value` in
config files) are not matched, and lowercase-hyphenated names (package names) are filtered out
of the symbol pass — those are covered by the dependency-table check in section 4 instead.

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
