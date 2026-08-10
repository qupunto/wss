#!/usr/bin/env bash
# Scaffold a docsify documentation site.
#
#   wss-scaffold.sh <docs-dir> <project-name> [root-lang [translation-lang ...]]
#
#   wss-scaffold.sh docs "Acme UI"              # monolingual, no navbar
#   wss-scaffold.sh docs "SIME UI" en ca        # root is English, docs/ca/ is Català
#   wss-scaffold.sh docs "SIME UI" en ca es     # plus docs/es/
#
# Creates the site SHELL only — index.html, _sidebar.md, index.md, and _navbar.md when
# multilingual. Content pages are deliberately not scaffolded: an empty page in the sidebar
# is a broken promise, so each page is created in the same change that fills it. `annex/`
# is likewise created by the first annex page, not here (git does not track empty dirs).
#
# Refuses to touch an existing docs dir.

set -euo pipefail

DOCS_DIR=${1:?usage: wss-scaffold.sh <docs-dir> <project-name> [root-lang [translation-lang ...]]}
PROJECT=${2:?usage: wss-scaffold.sh <docs-dir> <project-name> [root-lang [translation-lang ...]]}
shift 2
ROOT_LANG=${1:-}
[ $# -gt 0 ] && shift
TRANSLATIONS=("$@")

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
