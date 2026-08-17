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
# The LANGUAGES resolve the same way, from the sibling key `WSS.docs.languages` — first
# element the root language, every later one a translation subdirectory — and where the
# manifest declares nothing, from that key's declared fallback: absent means monolingual.
# The trailing positionals stay, as `--root` stays, and override the declaration outright.
# They remain positional rather than a flag because they carry no ambiguity: everything
# after the project name is a language. Both resolutions are announced for the same reason.
#
# A `languages` that IS declared and is not a non-empty array of non-empty strings —
# `wss-doctor.sh`'s criterion, not a second one — is fatal rather than a fallback. That is
# the one place this differs from the root, and the difference is the point: the root's
# fallback covers a manifest that could not be CONSULTED, while a malformed languages was
# consulted and found wrong, and scaffolding past it produces exactly the site/manifest
# divergence the resolution exists to prevent. Stating the languages positionally overrides
# it, loudly — an override is how you proceed while the manifest is being fixed.
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
#
# Sets DECLARED (and NO_JQ_UNREAD) rather than printing, because the jq-less
# branch has something to say that only the caller can finish saying: see below.
DECLARED=
# Set when the jq-less hand parser comes back empty. That branch cannot tell a
# malformed manifest from one that simply never declares the key — nothing short
# of a JSON validator in shell can, which is well past what a jq-absent fallback
# is for. So it reports the doubt instead of falling back in silence. The warning
# waits until the root is resolved, so it can name the root actually being used.
NO_JQ_UNREAD=0
declared_root() {
  DECLARED=
  [ -f "$MANIFEST" ] || return 0
  local val
  if command -v jq >/dev/null 2>&1; then
    if val=$(jq -r '.WSS.docs.root // empty' "$MANIFEST" 2>/dev/null); then
      DECLARED=$val
    else
      echo "warning: $MANIFEST is not valid JSON — WSS.docs.root cannot be read" >&2
      echo "         and is being ignored; the root falls back to the declared chain." >&2
      echo "         Fix the manifest: every later check resolves that key too." >&2
    fi
  else
    # `|| true` is load-bearing: no match makes grep exit 1, and under `pipefail`
    # the pipeline fails with it. The old `DECLARED=$(declared_root)` call ran the
    # body in a command substitution, where bash suppresses errexit; calling the
    # function plainly does not, so without the guard `set -e` kills the run here
    # with an empty screen — the exact silence the jq branch above exists to end.
    DECLARED=$(tr -d ' \n\t' <"$MANIFEST" \
      | grep -o '"docs":{[^}]*}' \
      | sed -n 's/.*"root":"\([^"]*\)".*/\1/p' | head -1) || true
    [ -n "$DECLARED" ] || NO_JQ_UNREAD=1
  fi
  return 0
}

# `WSS.docs.languages` as declared, or empty — the same two branches, in the same order,
# for the same reasons as declared_root above, including the `|| true` on the hand parser's
# grep. Sets DECLARED_LANGS, and LANGS_BAD when the key is declared but unusable; never
# prints, so the caller can decide between fatal and overridden.
DECLARED_LANGS=()
LANGS_BAD=
declared_languages() {
  DECLARED_LANGS=()
  LANGS_BAD=
  [ -f "$MANIFEST" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    # An unparseable manifest makes this false, so it is silently absent here and
    # declared_root's "not valid JSON" warning is the single report of it.
    jq -e '.WSS.docs | has("languages")' "$MANIFEST" >/dev/null 2>&1 || return 0
    if jq -e '.WSS.docs.languages | type == "array" and length > 0
                and (map(type == "string" and length > 0) | all)' \
         "$MANIFEST" >/dev/null 2>&1; then
      local l
      while IFS= read -r l; do DECLARED_LANGS+=("$l"); done \
        < <(jq -r '.WSS.docs.languages[]' "$MANIFEST" 2>/dev/null)
      [ ${#DECLARED_LANGS[@]} -gt 0 ] || LANGS_BAD='could not be read back'
    else
      LANGS_BAD='is not a non-empty array of non-empty strings'
    fi
    return 0
  fi
  # Same hand parser, same `|| true`: `grep -o` exits 1 on no match and takes the
  # pipeline with it under `pipefail`. Calling this function plainly is what makes
  # the guard load-bearing rather than decorative — see declared_root.
  local block list item
  block=$(tr -d ' \n\t' <"$MANIFEST" | grep -o '"docs":{[^}]*}') || true
  case $block in
    *'"languages":'*) ;;
    *) [ -n "$block" ] || NO_JQ_UNREAD=1; return 0 ;;
  esac
  list=$(printf '%s' "$block" | sed -n 's/.*"languages":\[\([^]]*\)\].*/\1/p') || true
  if [ -z "$list" ]; then
    LANGS_BAD='is not a non-empty array of non-empty strings'
    return 0
  fi
  local IFS=,
  for item in $list; do
    case $item in
      '"'*'"') item=${item#\"}; item=${item%\"} ;;
      *) LANGS_BAD='is not a non-empty array of non-empty strings'; DECLARED_LANGS=(); return 0 ;;
    esac
    case $item in
      ''|*'"'*) LANGS_BAD='is not a non-empty array of non-empty strings'
                DECLARED_LANGS=(); return 0 ;;
    esac
    DECLARED_LANGS+=("$item")
  done
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
POSITIONAL_LANGS=("$@")

declared_root
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
if [ "$NO_JQ_UNREAD" = 1 ]; then
  echo "warning: jq is not installed, so $MANIFEST could not be read reliably." >&2
  echo "         The fallback parser found no WSS.docs.root, but it cannot tell a" >&2
  echo "         malformed manifest from one that never declares the key." >&2
  echo "         Scaffolding into '$DOCS_DIR' ($ORIGIN)." >&2
  echo "         Install jq, or pass --root to state the root yourself." >&2
fi
echo "docs root: $DOCS_DIR   ($ORIGIN)" >&2

# Languages: positionals override the declaration, exactly as `--root` overrides `root`.
declared_languages
if [ ${#POSITIONAL_LANGS[@]} -gt 0 ]; then
  ROOT_LANG=${POSITIONAL_LANGS[0]}
  TRANSLATIONS=("${POSITIONAL_LANGS[@]:1}")
  LANG_ORIGIN="positional arguments"
  if [ -n "$LANGS_BAD" ]; then
    echo "warning: WSS.docs.languages in $MANIFEST $LANGS_BAD." >&2
    echo "         The languages given on the command line are being used instead." >&2
    echo "         Fix the key: the parity check and wss-doctor.sh resolve it too." >&2
  fi
elif [ -n "$LANGS_BAD" ]; then
  # Declared and wrong is not the same as undeclared, and must not resolve to the
  # monolingual fallback: that is the site/manifest divergence, silently.
  echo "WSS.docs.languages in $MANIFEST $LANGS_BAD." >&2
  echo "The first element is the root language; every later one is a translation" >&2
  echo "subdirectory under the root. Absent means monolingual — an empty or" >&2
  echo "mistyped list does not, so this run refuses to guess which was meant." >&2
  echo "Fix the key, or state the languages after the project name to override it." >&2
  exit 2
elif [ ${#DECLARED_LANGS[@]} -gt 0 ]; then
  ROOT_LANG=${DECLARED_LANGS[0]}
  TRANSLATIONS=("${DECLARED_LANGS[@]:1}")
  LANG_ORIGIN="WSS.docs.languages in $MANIFEST"
else
  ROOT_LANG=
  TRANSLATIONS=()
  LANG_ORIGIN="fallback: absent means monolingual"
fi
if [ -n "$ROOT_LANG" ]; then
  echo "languages: $ROOT_LANG${TRANSLATIONS[*]:+ ${TRANSLATIONS[*]}}   ($LANG_ORIGIN)" >&2
else
  echo "languages: monolingual   ($LANG_ORIGIN)" >&2
fi

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

# A root — or a language list — that only this run knows about is the mismatch again,
# one release later. The step numbers continue the list above, so they share a counter.
STEP=6
if [ "$DOCS_DIR" != "$DECLARED" ] && [ "$DOCS_DIR" != docs ]; then
  cat <<NOTE
  $STEP. declare it, so every later check resolves the same root:
       "WSS": { "docs": { "root": "$DOCS_DIR" } }   in $MANIFEST
NOTE
  STEP=$((STEP + 1))
fi
if [ $MULTILINGUAL -eq 1 ] && [ "$LANG_ORIGIN" = "positional arguments" ]; then
  cat <<NOTE
  $STEP. declare them, so the translation-parity check resolves the same list:
       "WSS": { "docs": { "languages": ["$ROOT_LANG", "${TRANSLATIONS[0]}"] } }   in $MANIFEST
       (first element is the root language, every later one a subdirectory)
NOTE
fi
