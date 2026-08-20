# Audit mode

Asked to check/verify/audit docs, or a refactor just landed. Run
[`wss/tests/WSS.DOCS-AUDIT.md`](../../../wss/tests/WSS.DOCS-AUDIT.md) in full.

## Audit scope

Resolving it is this skill's job, not the method's — a method that picked its own scope
could not be borrowed by a caller that wants a different one.

Sections 1–7 are shell. They run over the whole site in seconds and there is nothing to
save by narrowing them — **always run them in full.** Section 8's second half is the
expensive one: re-reading source files page by page. That is what the checkpoint is for,
and `--wss-health-check --deep` is what forces every page to be re-read.

Ask `sweep-tracker` to resolve the entry `docs`, with two scopes:

| Scope | Incremental? | `covered` |
|---|---|---|
| `mechanics` | No — the scripts are cheap and a whole-site run is the point | `[]` |
| `accuracy` | Yes | the pages whose claims were re-read against source this run |

**A page needs re-reading when the page changed, or when any source file it names
changed.** G3 is what makes that mechanical — every claim is attributed to a backticked
path at the point it is made, so a page's dependencies are already written down in it:

```bash
BASE=<baseline sha>
CHANGED=$(git diff --name-only "$BASE"..HEAD)
for f in $(find docs -name '*.md'); do
  git diff --quiet "$BASE"..HEAD -- "$f" || { echo "STALE (page edited): $f"; continue; }
  # every backticked path the page attributes a claim to
  deps=$(grep -ohE '`[A-Za-z0-9_.$/-]+/[A-Za-z0-9_.$/-]+`' "$f" | tr -d '`' | sort -u)
  for d in $deps; do
    printf '%s\n' "$CHANGED" | grep -qF "$d" && { echo "STALE (source moved): $f <- $d"; break; }
  done
done
```

Everything that prints is in scope. Everything else was verified at `$BASE` and neither it
nor anything it cites has moved since.

**A page carrying its own verified-at stamp is compared against that stamp, not
`$BASE`.** Workflow pages write one ([`WSS.WORKFLOW-PAGES.md`](WSS.WORKFLOW-PAGES.md)), and it
is the commit that page's claims were last read against — later than the site
baseline whenever the page was verified since the last sweep, so using `$BASE`
for it re-reads sources it has already been checked against. Read the stamp out
of the page's header and substitute it for `$BASE` on that page's dependencies
alone. Its other half does not apply: an edit to a workflow page *is* a
verification, so "the page changed" never puts one back in scope.

**Two things void the narrowing entirely**, because they change what a correct page even
looks like:

- **A page with no backticked source path at all.** It has no detectable dependencies, so
  the diff can never mark it stale. It is `not-covered` unless read — never silently clean.
- **A change to the docs' own conventions** — the taxonomy, the style guide, `_sidebar.md`
  structure. Those invalidate every page's *form*, not just its facts.

**When in doubt, widen.** A page wrongly skipped reports clean while asserting something
false.

Stamp at the end through `sweep-tracker`: the baseline, and per scope what was covered.
The rules constraining what may be claimed are
[`wss/workflow/WSS.SWEEP-CHECKPOINT.md`](../../../wss/workflow/WSS.SWEEP-CHECKPOINT.md).

## Fixing what audit finds

A finding about prose hands off exactly like [Write mode](WSS.MODE-WRITE.md) — same
`docs-writer` call, same loaded-reference table, not repeated here. A finding that the
subject isn't this site's job at all (a runtime rule, reference material) goes to
`behaviour-writer` or `reference-writer` instead, per
["The two records this skill does not write"](../SKILL.md#the-two-records-this-skill-does-not-write).
