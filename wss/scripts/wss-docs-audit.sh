#!/usr/bin/env bash
# The mechanical half of wss/tests/WSS.DOCS-AUDIT.md: resolve the
# project's docs shape, then run every check that is "run this, read the
# output." Judgment stays in the method file — this script never decides
# whether a finding matters, only surfaces candidates for one to be read
# against.
#
#   wss-docs-audit.sh                # every section, in the method's order
#   wss-docs-audit.sh dead-paths links
#   wss-docs-audit.sh --help
#
# NOT here, and deliberately: §3's "diff against source" (a human/model step),
# §4's stale-enumeration check (illustrative — one project's `src/routes`
# example, not a command any tree can run as written), and all of §8's "then
# read" close. Those stay in wss/tests/WSS.DOCS-AUDIT.md.
#
# Run from the project root being audited. Resolves $DOCS, $ROOTLANG,
# $TRANSLATIONS[] and $DEV from WSS.docs in the manifest — same three keys,
# same declared fallbacks, as wss/workflow/WSS.MANIFEST.md documents and
# wss/tests/WSS.DOCS-AUDIT.md §0 always resolved inline. WSS_MANIFEST
# overrides the manifest path, the same override wss-scaffold.sh honors.
set -u

MANIFEST=${WSS_MANIFEST:-.claude/WSS.WORKFLOW.json}

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

SECTIONS=(dead-paths links types translations index mechanics accuracy)

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

# ------------------------------------------------------------- §0: resolve --
# jq guard: a manifest that cannot be consulted must be announced, not
# silently read as "nothing declared" — that is the one difference between a
# project that opted out of a key and a project whose declaration went unread.
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1
if [ "$HAVE_JQ" -eq 0 ]; then
  echo "warning: jq is not installed — WSS.docs cannot be read from $MANIFEST." >&2
  echo "         Falling back to directory/monolingual defaults; a declared" >&2
  echo "         root, languages or devCommand is being ignored." >&2
elif [ -f "$MANIFEST" ] && ! jq empty "$MANIFEST" >/dev/null 2>&1; then
  echo "warning: $MANIFEST is not valid JSON — WSS.docs cannot be read." >&2
  echo "         Falling back to directory/monolingual defaults." >&2
  HAVE_JQ=0
fi

DOCS=""
DOCS_ORIGIN="fallback: none of wss/docs/ docs/ doc/ documentation/ website/ exists"
if [ "$HAVE_JQ" -eq 1 ]; then
  DOCS=$(jq -r '.WSS.docs.root // empty' "$MANIFEST" 2>/dev/null)
  [ -n "$DOCS" ] && DOCS_ORIGIN="WSS.docs.root in $MANIFEST"
fi
if [ -z "$DOCS" ]; then
  for d in wss/docs docs doc documentation website; do
    [ -d "$d" ] && { DOCS=$d; DOCS_ORIGIN="fallback: first existing of wss/docs/ docs/ doc/ documentation/ website/"; break; }
  done
fi

LANGS=()
LANG_ORIGIN="fallback: absent means monolingual"
if [ "$HAVE_JQ" -eq 1 ] && jq -e '.WSS.docs.languages | type == "array" and length > 0
              and (map(type == "string" and length > 0) | all)' \
     "$MANIFEST" >/dev/null 2>&1; then
  while IFS= read -r l; do LANGS+=("$l"); done \
    < <(jq -r '.WSS.docs.languages[]' "$MANIFEST" 2>/dev/null)
  LANG_ORIGIN="WSS.docs.languages in $MANIFEST"
fi
ROOTLANG=${LANGS[0]:-root}
TRANSLATIONS=()
[ "${#LANGS[@]}" -gt 1 ] && TRANSLATIONS=("${LANGS[@]:1}")

DEV=""
if [ "$HAVE_JQ" -eq 1 ]; then
  DEV=$(jq -r '.WSS.docs.devCommand // empty' "$MANIFEST" 2>/dev/null)
fi

resolve() {
  if [ -n "$DOCS" ]; then
    echo "docs root: $DOCS   ($DOCS_ORIGIN)"
  else
    echo "NOTE: no docs root resolves — this project has no site, and every check below is skipped."
  fi
  if [ "${#TRANSLATIONS[@]}" -gt 0 ]; then
    echo "languages: $ROOTLANG ${TRANSLATIONS[*]}   ($LANG_ORIGIN)"
  else
    echo "NOTE: monolingual — the translation-parity check (translations) is skipped."
  fi
  if [ -n "$DEV" ]; then
    echo "devCommand: $DEV"
  else
    echo "NOTE: no WSS.docs.devCommand — the live-render step (inside mechanics) is skipped."
  fi
}

# A docs root that does not resolve means every later check would walk an
# empty set and report a clean site — the exact silent-pass wss/tests/
# WSS.DOCS-AUDIT.md's own §0 refuses to produce. Stop after the NOTE.
require_docs() {
  [ -n "$DOCS" ] || { echo "SKIPPED: no docs root — see 'resolve'."; return 1; }
  return 0
}

# ------------------------------------------------- records are not site pages --
# A record that merely lives under the docs root is not a page of the site, and
# three sections below produce nothing but noise when they read one. A log-mode
# record cites paths AS THEY WERE, which the dead-path walk reports as breakage;
# a decision log quotes literals it is narrating rather than asserting, which the
# accuracy walk reports as unconfirmed; and neither belongs in `_sidebar.md`,
# which the index walk reports as an omission. On this tree that was 37 of 42
# dead paths, every accuracy literal and every index omission — a check whose
# output is mostly false positives is one its reader learns to skip, which costs
# the findings that are real.
#
# THE MANIFEST DECIDES, NOT A NAME PATTERN. Which files are records is exactly
# what `WSS.record.*` declares, and a pattern over `WSS.*.md` would be wrong in
# both directions: it would catch a site page named that way and miss a record
# that is not. Where jq is unavailable the set is empty and every section reads
# the docs root whole — the pre-existing behaviour, announced by §0's jq guard
# rather than silently narrowing.
DOC_RECORDS=()
if [ "$HAVE_JQ" -eq 1 ] && [ -f "$MANIFEST" ]; then
  while IFS= read -r r; do
    [ -n "$r" ] && DOC_RECORDS+=("$r")
  done < <(jq -r '[.WSS.record // {} | .. | strings] | .[]' "$MANIFEST" 2>/dev/null | sort -u)
fi

is_doc_record_() { # path — true where the manifest declares it as a record
  local p=${1#./} r
  for r in "${DOC_RECORDS[@]}"; do [ "$p" = "$r" ] && return 0; done
  return 1
}

site_pages_() { # NUL-separated *.md under the docs root, declared records dropped
  find "$DOCS" -name '*.md' -type f -print0 2>/dev/null | while IFS= read -r -d '' p; do
    is_doc_record_ "$p" || printf '%s\0' "$p"
  done
}

# ---------------------------------------------------------------- §1: dead paths --
dead_paths() {
  require_docs || return 0
  local roots
  roots=$(git ls-files 2>/dev/null | grep / | cut -d/ -f1 | sort -u | paste -sd'|' -)
  [ -n "$roots" ] || { echo "NOTE: not a git worktree, or nothing tracked — nothing to check."; return 0; }
  site_pages_ | xargs -0 -r grep -hoE "\`($roots)/[A-Za-z0-9_.\$/-]+\`" 2>/dev/null \
    | tr -d '`' | grep -v '\.\.\.' | sort -u \
    | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
}

# ------------------------------------------------------ §2: broken links/anchors --
links() {
  require_docs || return 0
  grep -rnoE '\]\(/?[A-Za-z0-9._/-]+\.md' "$DOCS" --include='*.md' 2>/dev/null | while IFS=: read -r f _ m; do
    t=${m#*](}
    case "$t" in
      /*) p="$DOCS$t" ;;
       *) p="$(dirname "$f")/$t" ;;
    esac
    [ -e "$p" ] || echo "BROKEN LINK: $f -> $t"
  done
}

# --------------------------------------------------- §3: type/prop candidates --
types() {
  require_docs || return 0
  grep -rnE '^(export )?(type|interface|struct|class) [A-Z][A-Za-z0-9_]*' "$DOCS" --include='*.md' 2>/dev/null
}

# ------------------------------------------------------- §5: translation parity --
translations() {
  require_docs || return 0
  if [ "${#TRANSLATIONS[@]}" -eq 0 ]; then
    echo "SKIPPED: monolingual — no translations declared."
    return 0
  fi
  local excl=() lang
  for lang in "${TRANSLATIONS[@]}"; do excl+=(-not -path "./$lang/*"); done
  for lang in "${TRANSLATIONS[@]}"; do
    echo "== $ROOTLANG vs $lang"
    diff <(cd "$DOCS"       && find . -name '*.md' "${excl[@]}" | sed 's|^\./||' | sort) \
         <(cd "$DOCS/$lang" && find . -name '*.md'              | sed 's|^\./||' | sort)
    local f b a c
    for f in "$DOCS"/*.md; do
      [ -e "$f" ] || continue
      b=$(basename "$f"); [ -f "$DOCS/$lang/$b" ] || continue
      a=$(grep -c '^#' "$f"); c=$(grep -c '^#' "$DOCS/$lang/$b")
      [ "$a" = "$c" ] || echo "HEADING MISMATCH: $b ($a $ROOTLANG / $c $lang)"
    done
  done
}

# ------------------------------------------------------------- §6: index parity --
index_parity() {
  require_docs || return 0
  local lang d sub b
  for lang in "" "${TRANSLATIONS[@]}"; do
    d=$DOCS${lang:+/$lang}
    [ -d "$d" ] || { echo "MISSING TRANSLATION DIR: $d"; continue; }
    sub=()
    [ -z "$lang" ] && for t in "${TRANSLATIONS[@]}"; do sub+=(-not -path "$d/$t/*"); done
    find "$d" -name '*.md' "${sub[@]}" | sed "s|^$d/||" | while read -r b; do
      case "$b" in _*|index.md) continue;; esac
      is_doc_record_ "$d/$b" && continue
      grep -q "$b" "$d/_sidebar.md" 2>/dev/null || echo "NOT IN SIDEBAR [${lang:-$ROOTLANG}]: $b"
      grep -q "$b" "$d/index.md" 2>/dev/null    || echo "NOT IN index.md [${lang:-$ROOTLANG}]: $b"
    done
  done
}

# --------------------------------------------------------- §7: markdown mechanics --
mechanics() {
  require_docs || return 0
  local fence_awk
  fence_awk=$(mktemp)
  cat > "$fence_awk" <<'AWK'
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
  # a directory tree is the one legitimate untagged fence — expect one hit per
  # page that draws one, and treat every other hit as a finding
  site_pages_ | while IFS= read -r -d '' f; do awk -v F="$f" -f "$fence_awk" "$f"; done
  rm -f "$fence_awk"

  # unfinished scaffolding
  site_pages_ | xargs -0 -r grep -n '{{'

  # table rows whose column count differs from their header — usually an
  # unescaped pipe inside a type like `string | null`, which silently eats a
  # column
  site_pages_ | while IFS= read -r -d '' f; do
    awk -v F="$f" '
      /^\|/ { n = gsub(/(^|[^\\])\|/, "&"); if (!w) w = n; else if (n != w) print F ":" NR ": " n " cols, expected " w }
      !/^\|/ { w = 0 }
    ' "$f"
  done

  # Then render it. A site that passes every grep can still fail to load — a
  # stray `alias` entry or a missing `loadSidebar` breaks navigation without
  # touching any markdown. This is the one step with no grep substitute, so a
  # project that declares no devCommand gets the skip line rather than a
  # quiet pass.
  if [ -n "$DEV" ]; then
    eval "$DEV" &
    local pid=$!
    sleep 4
    # the port the declared command serves on — read it off that command's
    # own startup line. 4000 is only the default the suite's own scaffold
    # writes (skills/docs/assets/wss-scaffold.sh), not a property of
    # every site.
    local port=${DOCS_PORT:-4000}
    local pages=(/ index.md _sidebar.md "$(cd "$DOCS" && ls *.md 2>/dev/null | grep -v '^_' | head -1)")
    local t
    for t in "${TRANSLATIONS[@]}"; do pages+=("$t/index.md"); done
    local u
    for u in "${pages[@]}"; do
      printf "%-24s %s\n" "$u" "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/$u")"
    done
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  else
    echo "SKIPPED: no WSS.docs.devCommand — the live-render step is skipped."
  fi
}

# --------------------------------------------------- §8: accuracy, mechanical pass --
accuracy() {
  require_docs || return 0
  local src=. ex=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build
      --exclude-dir="$DOCS" --exclude=package-lock.json --exclude=pnpm-lock.yaml)

  # symbols: backticked identifiers shaped like code (camelCase, PascalCase,
  # SCREAMING_SNAKE)
  site_pages_ | xargs -0 -r grep -hoE '`[A-Za-z_][A-Za-z0-9_.]*(\(\))?`' | tr -d '`' \
    | sed 's/()$//' | sort -u \
    | grep -E '^([a-z][a-zA-Z0-9]*[A-Z][A-Za-z0-9]*|[A-Z][A-Za-z0-9]*[A-Z_][A-Za-z0-9_]*|[A-Z_]{3,})$' \
    | while read -r sym; do
        grep -rqF "$sym" "$src" "${ex[@]}" 2>/dev/null || echo "SYMBOL NOT IN SOURCE: $sym"
      done

  # literals: backticked `key: value` / `key = value` assertions
  site_pages_ | xargs -0 -r grep -hoE '`[A-Za-z_][A-Za-z0-9_]* *[:=] *[^`]+`' | tr -d '`' \
    | sed 's/  */ /g' | sort -u \
    | while read -r claim; do
        key=${claim%%[:=]*}; key=${key% }; val=${claim#*[:=]}; val=${val# }
        case "$val" in *' '*|''|*'[]') continue;; esac
        grep -rqE "$key[^A-Za-z0-9_]+[\"']?${val%%[,;)]*}" "$src" "${ex[@]}" 2>/dev/null \
          || echo "LITERAL NOT CONFIRMED: $key = $val"
      done
}

# ---------------------------------------------------------------------- driver --
run_section() {
  case "$1" in
    resolve)      resolve ;;
    dead-paths)   dead_paths ;;
    links)        links ;;
    types)        types ;;
    translations) translations ;;
    index)        index_parity ;;
    mechanics)    mechanics ;;
    accuracy)     accuracy ;;
    *) echo "wss-docs-audit.sh: unknown section '$1'" >&2
       echo "  known: resolve ${SECTIONS[*]}" >&2
       exit 2 ;;
  esac
}

echo "== resolve =="
resolve

# resolve always runs first, above — drop it from the explicit list so asking
# for it by name doesn't print it twice.
ARGS=()
for a in "$@"; do [ "$a" = resolve ] && continue; ARGS+=("$a"); done

if [ "${#ARGS[@]}" -eq 0 ] && [ $# -gt 0 ]; then
  : # only "resolve" was asked for; already printed above
elif [ $# -eq 0 ]; then
  for s in "${SECTIONS[@]}"; do
    echo
    echo "== $s =="
    run_section "$s"
  done
else
  for s in "${ARGS[@]}"; do
    echo
    echo "== $s =="
    run_section "$s"
  done
fi
