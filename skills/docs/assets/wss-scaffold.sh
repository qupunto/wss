#!/usr/bin/env bash
# Scaffold a docsify documentation site.
#
#   wss-scaffold.sh [--root <dir>] <project-name> [root-lang [translation-lang ...]]
#
#   wss-scaffold.sh "Acme UI"                       # monolingual, no navbar
#   wss-scaffold.sh "SIME UI" en ca                 # root is English, <root>/ca/ is Català
#   wss-scaffold.sh --root website "SIME UI" en ca  # scaffolds website/ instead
#
# The docs root is NOT a positional. It is resolved from `WSS.docs.root` in
# .claude/WSS.WORKFLOW.json, and where the manifest declares nothing, from that key's
# declared fallback chain: the first existing of docs/, doc/, documentation/, website/,
# and docs/ when none of them exists — which is the case a scaffold is for. `--root`
# overrides both. It is a flag rather than an optional leading positional because
# `wss-scaffold.sh "Acme UI"` and `wss-scaffold.sh docs "Acme UI"` are indistinguishable
# once the first argument is optional. The resolved root is always announced: a scaffolder
# and a manifest that disagree in silence is the defect this resolution exists to prevent.
#
# Creates the site SHELL only — index.html, _sidebar.md, index.md, and _navbar.md when
# multilingual. Content pages are deliberately not scaffolded: an empty page in the sidebar
# is a broken promise, so each page is created in the same change that fills it. `annex/`
# is likewise created by the first annex page, not here (git does not track empty dirs).
#
# Refuses to touch an existing docs dir.

set -euo pipefail

USAGE='usage: wss-scaffold.sh [--root <dir>] <project-name> [root-lang [translation-lang ...]]'
MANIFEST=${WSS_MANIFEST:-.claude/WSS.WORKFLOW.json}

# `WSS.docs.root` as declared, or empty. jq where it exists; by hand where it does not,
# because silently ignoring a declared root would reinstate the mismatch this prevents.
#
# Always returns 0. A manifest that cannot be parsed is a loud fallback, never a dead
# scaffolder: jq exits non-zero on a parse error, and letting that reach `$(...)` under
# `set -e` would kill the run with an empty screen and a bare exit code — the same
# silence, one turn later. Scaffolding a site does not require a well-formed manifest;
# it requires being told when the manifest could not be consulted.
declared_root() {
  [ -f "$MANIFEST" ] || return 0
  local val
  if command -v jq >/dev/null 2>&1; then
    if val=$(jq -r '.WSS.docs.root // empty' "$MANIFEST" 2>/dev/null); then
      printf '%s' "$val"
    else
      echo "warning: $MANIFEST is not valid JSON — WSS.docs.root cannot be read" >&2
      echo "         and is being ignored; the root falls back to the declared chain." >&2
      echo "         Fix the manifest: every later check resolves that key too." >&2
    fi
  else
    tr -d ' \n\t' <"$MANIFEST" \
      | grep -o '"docs":{[^}]*}' \
      | sed -n 's/.*"root":"\([^"]*\)".*/\1/p' | head -1
  fi
  return 0
}

ROOT_OVERRIDE=
while [ $# -gt 0 ]; do
  case $1 in
    --root)   ROOT_OVERRIDE=${2:?--root needs a directory}; shift 2 ;;
    --root=*) ROOT_OVERRIDE=${1#--root=}; shift ;;
    --)       shift; break ;;
    -*)       echo "unknown option: $1" >&2; echo "$USAGE" >&2; exit 2 ;;
    *)        break ;;
  esac
done

PROJECT=${1:?$USAGE}
shift
ROOT_LANG=${1:-}
[ $# -gt 0 ] && shift
TRANSLATIONS=("$@")

DECLARED=$(declared_root)
if [ -n "$ROOT_OVERRIDE" ]; then
  DOCS_DIR=$ROOT_OVERRIDE
  ORIGIN="--root"
elif [ -n "$DECLARED" ]; then
  DOCS_DIR=$DECLARED
  ORIGIN="WSS.docs.root in $MANIFEST"
else
  DOCS_DIR=docs
  ORIGIN="fallback: none of docs/ doc/ documentation/ website/ exists yet"
  for d in docs doc documentation website; do
    [ -d "$d" ] && { DOCS_DIR=$d; ORIGIN="fallback: first existing of docs/ doc/ documentation/ website/"; break; }
  done
fi
echo "docs root: $DOCS_DIR   ($ORIGIN)" >&2

if [ -e "$DOCS_DIR" ]; then
  echo "refusing to scaffold: '$DOCS_DIR' already exists" >&2
  echo "an existing site is the authority on its own conventions — read it instead" >&2
  exit 1
fi

# Endonyms — a language switcher labelled with bare ISO codes is unusable.
endonym() {
  case $1 in
    en) echo English   ;; ca) echo Català    ;; es) echo Español  ;; fr) echo Français ;;
    de) echo Deutsch   ;; it) echo Italiano  ;; pt) echo Português;; gl) echo Galego   ;;
    eu) echo Euskara   ;; nl) echo Nederlands;; pl) echo Polski   ;; sv) echo Svenska  ;;
    da) echo Dansk     ;; nb|no) echo Norsk  ;; fi) echo Suomi    ;; cs) echo Čeština  ;;
    ro) echo Română    ;; hu) echo Magyar    ;; tr) echo Türkçe   ;; el) echo Ελληνικά ;;
    ru) echo Русский   ;; uk) echo Українська;; ja) echo 日本語    ;; zh) echo 中文      ;;
    ko) echo 한국어     ;; ar) echo العربية   ;; he) echo עברית    ;; hi) echo हिन्दी     ;;
    *)  echo "$1"      ;;   # unknown code: emit it and let the caller fix the label
  esac
}

MULTILINGUAL=0
[ ${#TRANSLATIONS[@]} -gt 0 ] && MULTILINGUAL=1

mkdir -p "$DOCS_DIR"

# ---------------------------------------------------------------- index.html
{
  cat <<HTML
<!doctype html>
<html lang="${ROOT_LANG:-en}">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$PROJECT — Docs</title>
    <link rel="stylesheet" href="//cdn.jsdelivr.net/npm/docsify@4/lib/themes/vue.css" />
  </head>
  <body>
    <div id="app"></div>
    <script>
      window.\$docsify = {
        name: '$PROJECT docs',
        repo: '',
        loadSidebar: true,
HTML

  if [ $MULTILINGUAL -eq 1 ]; then
    cat <<'HTML'
        loadNavbar: true,
        // without this, every markdown link (including inside _sidebar.md/
        // _navbar.md) resolves relative to the site root instead of the
        // current file — breaks navigation within nested language folders
        relativePath: true,
HTML
  else
    cat <<'HTML'
        // keeps links resolving against the current file rather than the site
        // root; required the moment any page moves into a subdirectory
        relativePath: true,
HTML
  fi

  cat <<'HTML'
        subMaxLevel: 2,
        homepage: 'index.md',
HTML

  if [ $MULTILINGUAL -eq 1 ]; then
    cat <<'HTML'
        // docsify's `homepage` alias only remaps the root `/` — nested
        // language folders need their own explicit alias to the same effect
        alias: {
HTML
    for l in "${TRANSLATIONS[@]}"; do
      printf "          '/%s/': '/%s/index.md',\n" "$l" "$l"
    done
    echo "        },"
  fi

  cat <<'HTML'
        search: {
          placeholder: 'Search...',
          noData: 'No results.',
          depth: 3,
        },
      }
    </script>
    <script src="//cdn.jsdelivr.net/npm/docsify@4/lib/docsify.min.js"></script>
    <script src="//cdn.jsdelivr.net/npm/docsify@4/lib/plugins/search.min.js"></script>
  </body>
</html>
HTML
} >"$DOCS_DIR/index.html"

# ---------------------------------------------------------------- _navbar.md
# Root only, and only when there is more than one language to switch between.
if [ $MULTILINGUAL -eq 1 ]; then
  {
    printf -- "- [%s](/)\n" "$(endonym "${ROOT_LANG:-en}")"
    for l in "${TRANSLATIONS[@]}"; do
      printf -- "- [%s](/%s/)\n" "$(endonym "$l")" "$l"
    done
  } >"$DOCS_DIR/_navbar.md"
fi

# ------------------------------------------------------- _sidebar.md + index.md
write_shell() {
  local dir=$1 prefix=$2
  printf -- "- [Home](%s)\n" "$prefix" >"$dir/_sidebar.md"
  cat >"$dir/index.md" <<INDEX
# $PROJECT — Documentation

{{INTRO: one paragraph — what this project is, who it is for, the stack it is built on.
Bold the product name and expand any acronym. A \`{{\` left anywhere in this tree marks an
unfinished doc.}}

---

## Contents

| File | Description |
|---|---|

## Annex

| File | Description |
|---|---|
INDEX
}

write_shell "$DOCS_DIR" "/"
for l in "${TRANSLATIONS[@]:-}"; do
  [ -z "$l" ] && continue
  mkdir -p "$DOCS_DIR/$l"
  write_shell "$DOCS_DIR/$l" "/$l/"
done

# ---------------------------------------------------------------- next steps
cat <<NEXT

scaffolded $DOCS_DIR/
$(find "$DOCS_DIR" -type f | sort | sed 's/^/  /')

remaining — none of which this script does for you:
  1. add the dev script to package.json, and install the CLI:
       "docs:dev": "docsify serve $DOCS_DIR --port 4000 --open"
       pnpm add -D docsify-cli
  2. write WSS.OVERVIEW.md first — stack, scripts, env vars, directory tree, decisions
  3. add every page to _sidebar.md AND index.md in the same change that creates it
  4. replace every placeholder:  grep -rn '{{' $DOCS_DIR
  5. point README.md at $DOCS_DIR/index.md
NEXT

# A root that only this run knows about is the mismatch again, one release later.
if [ "$DOCS_DIR" != "$DECLARED" ] && [ "$DOCS_DIR" != docs ]; then
  cat <<NOTE
  6. declare it, so every later check resolves the same root:
       "WSS": { "docs": { "root": "$DOCS_DIR" } }   in $MANIFEST
NOTE
fi
