#!/usr/bin/env bash
#
# Resolve a `KEY[#fragment]` citation to a `path:line`, and check the ones
# written down. The scheme is `wss/workflow/WSS.ADDRESSING.md`'s; this script
# implements it and states none of it.
#
#   ./wss-resolve.sh WSS.record.todo                 # -> path:1
#   ./wss-resolve.sh WSS.contract.WSS.ADDRESSING.md#3-the-ordinal-citation-form
#   ./wss-resolve.sh --check                         # every citation in scope
#
# EXIT: 0 resolved (or --check found nothing wrong), 1 unresolvable with a
# reason on stderr, 2 usage.
#
# WHY A KEY RESOLVING TWICE IS FATAL RATHER THAN RANKED. Three registries can
# name one key. If two name it and disagree about the path, ranking them picks
# an answer and hides the disagreement — and the whole point of addressing by
# key is that one name means one thing. So a conflict stops, and says both.
#
# `WSS.TOOLS.json` IS GENERATED, so this runs its `--check` before trusting it:
# every answer from a stale inventory is against yesterday's tree.

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MANIFEST="$ROOT/.claude/WSS.WORKFLOW.json"
LOCAL="$ROOT/.claude/WSS.LOCAL-RECORDS.json"
TOOLS="$ROOT/.claude/WSS.TOOLS.json"

command -v jq >/dev/null 2>&1 || { echo "wss-resolve.sh needs jq" >&2; exit 2; }

usage() {
  echo "usage: $0 KEY[#fragment]" >&2
  echo "       $0 --check" >&2
  exit 2
}

# --- the three registries, each key -> path, with their source named ---------
# Emitted as `key<TAB>path<TAB>registry` so a conflict can name both sides.
registries_() {
  # `record` NESTS — `tooling.catalog` is a key, not a key called `tooling` with
  # a suffix — so the walk is recursive and the key is the dotted path to a
  # STRING. An ARRAY member is part of one key's set, not a rival for it.
  local rec_jq='
    def walk($prefix):
      to_entries[]
      | ($prefix + "." + .key) as $k
      | (.value
         | if   type=="object" then (. | walk($k))
           elif type=="array"  then (.[] | select(type=="string") | "\($k)\t\(.)")
           elif type=="string" then "\($k)\t\(.)"
           else empty end);
    (.WSS.record // {}) | walk("WSS.record")'
  [ -f "$MANIFEST" ] && jq -r "$rec_jq" "$MANIFEST" 2>/dev/null | sed 's|$|\tWSS.WORKFLOW.json|'
  [ -f "$LOCAL" ] && jq -r "$rec_jq" "$LOCAL" 2>/dev/null | sed 's|$|\tWSS.LOCAL-RECORDS.json|'
  [ -f "$TOOLS" ] && jq -r '
    (.entries // [])[] | select(.kind and .name and .path)
    | "WSS.\(.kind).\(.name)\t\(.path)\tWSS.TOOLS.json"' "$TOOLS" 2>/dev/null
}

# --- resolve one key to a path, or fail loudly -------------------------------
resolve_key_() { # key -> path on stdout
  local key=$1 hits path
  hits=$(registries_ | awk -F'\t' -v k="$key" '$1 == k')
  [ -n "$hits" ] || { echo "wss-resolve.sh: no registry declares '$key'" >&2; return 1; }
  # A KEY WHOSE VALUE IS AN ARRAY NAMES A SET, not rivals — `WSS.record.reference`
  # is two files and both are it. The conflict this refuses to rank is the same
  # key resolving DIFFERENTLY IN DIFFERENT REGISTRIES, which is one name meaning
  # two things.
  local regs
  regs=$(printf '%s\n' "$hits" | cut -f3 | sort -u | wc -l)
  if [ "$regs" -gt 1 ]; then
    local perreg
    perreg=$(printf '%s\n' "$hits" | awk -F'\t' '{print $3}' | sort -u | while read -r r; do
      printf '%s\n' "$hits" | awk -F'\t' -v r="$r" '$3==r{print $2}' | sort | tr '\n' ' '; echo
    done | sort -u | wc -l)
    if [ "$perreg" -gt 1 ]; then
      echo "wss-resolve.sh: '$key' resolves differently in two registries, which is not a precedence question:" >&2
      printf '%s\n' "$hits" | awk -F'\t' '{printf "  %s  (%s)\n", $2, $3}' >&2
      return 1
    fi
  fi
  local missing=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ -e "$ROOT/$path" ] || { echo "wss-resolve.sh: '$key' declares '$path', which does not exist" >&2; missing=1; }
  done < <(printf '%s\n' "$hits" | cut -f2 | sort -u)
  [ "$missing" -eq 0 ] || return 1
  printf '%s\n' "$hits" | cut -f2 | sort -u
}

# --- the fragment's mode comes from the TARGET, never from the citing text ---
# A `log` record's entries cannot carry heading anchors — they must not be
# rewritten to gain one — so its addressable surface is the generated index.
record_mode_() { # key -> log|register|generated|"" 
  case "$1" in WSS.record.*) ;; *) return 0 ;; esac
  local short=${1#WSS.record.}
  for f in "$MANIFEST" "$LOCAL"; do
    [ -f "$f" ] || continue
    jq -r --arg k "$short" '
      (.WSS.recordMode // {})[$k] // empty
      | if type=="object" then .mode else . end' "$f" 2>/dev/null | head -1 | grep . && return 0
  done
  return 0
}

# --- find a fragment's line in a file ----------------------------------------
fragment_line_() { # file, fragment -> line number
  python3 - "$1" "$2" <<'PY' 2>/dev/null
import re, sys
def slug(t):
    a = t.lower()
    a = re.sub(r"[`*_\[\]()]", "", a)
    a = re.sub(r"[^\w\s-]", "", a)
    return re.sub(r"\s", "-", a.strip())
path, want = sys.argv[1], sys.argv[2]
fence = False
for n, line in enumerate(open(path, encoding="utf-8", errors="replace").read().splitlines(), 1):
    st = line.lstrip()
    if st.startswith("```") or st.startswith("~~~"):
        fence = not fence
        continue
    if fence or not line.startswith("#"):
        continue
    if slug(line.lstrip("#").strip()) == want:
        print(n); break
PY
}

resolve_one_() { # [→]KEY[#fragment]
  local ref=$1 key frag path mode target line
  # THE CITATION MARKER IS STRIPPED HERE AND NOWHERE ELSE. `→KEY` and `KEY`
  # resolve identically; the marker says "this is a citation", which matters to
  # --check and not to resolution.
  ref=${ref#→}
  key=${ref%%#*}
  frag=""
  case "$ref" in *#*) frag=${ref#*#} ;; esac
  path=$(resolve_key_ "$key") || return 1
  # A key may name a SET, so answer one `path:line` per member. Line 1 is the
  # honest answer for a bare key: the citation named the file, not a place in it.
  if [ -z "$frag" ]; then printf '%s\n' "$path" | sed 's|$|:1|'; return 0; fi

  if [ "$(printf '%s\n' "$path" | wc -l)" -gt 1 ]; then
    echo "wss-resolve.sh: '$key' names more than one file, so a fragment cannot say which:" >&2
    printf '%s\n' "$path" | sed 's|^|  |' >&2
    return 1
  fi
  mode=$(record_mode_ "$key")
  if [ "$mode" = "log" ]; then
    # A LOG RECORD IS ADDRESSED THROUGH THE INDEX, and the index is a lookup
    # rather than the destination: each row carries the entry's line in the log,
    # so resolving through it answers with the entry itself. The fragment is the
    # ordinal citation — `YYYY-MM-DD (ordinal)` — in either its written form or
    # the hyphenated form a URL fragment can carry.
    local idx cite
    idx=$(resolve_key_ "WSS.record.decisionsIndex") || {
      echo "wss-resolve.sh: '$key' is a log record, so its fragment resolves through the index — which does not resolve" >&2
      return 1; }
    cite=$(printf '%s' "$frag" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.+)$/\1 (\2)/')
    line=$(grep -nF -- "$cite" "$ROOT/$idx" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -z "$line" ]; then
      echo "wss-resolve.sh: '$cite' names no entry in $idx" >&2
      return 1
    fi
    # The row's own `L<n>` is the entry's line in the log.
    local logline
    logline=$(sed -n "${line}p" "$ROOT/$idx" | grep -oE '^- L[0-9]+' | tr -dc '0-9')
    if [ -n "$logline" ]; then printf '%s:%s\n' "$path" "$logline"; else printf '%s:%s\n' "$idx" "$line"; fi
    return 0
  fi
  line=$(fragment_line_ "$ROOT/$path" "$frag")
  if [ -z "$line" ]; then
    echo "wss-resolve.sh: '$frag' matches no heading in $path" >&2
    return 1
  fi
  printf '%s:%s\n' "$path" "$line"
}

# --- --check: every citation written down, in scope --------------------------
# SCOPE IS THE LIVE SURFACE. Logs and generated files are excluded: a log
# records what a citation said when it was written, and rewriting one to keep a
# reference current is the thing the append-only rule forbids.
check_() {
  # SCOPE IS THE LIVE SURFACE. Logs and generated files are excluded: a log
  # records what a citation said when it was written, and rewriting one to keep
  # a reference current is what the append-only rule forbids.
  #
  # WHAT MAKES A CITATION CHECKABLE IS THE MARKER, OR A FRAGMENT. Prose names
  # keys constantly and legitimately — `WSS.record.tooling.sources` is a glob
  # list, `WSS.suite.version` a manifest field, neither of which names a file —
  # so an UNMARKED token that resolves to nothing is correct writing and is
  # counted rather than failed. A leading `→` says the token cites a file, and a
  # `#fragment` cannot be a passing mention; both are checked and failed.
  local bad=0 seen=0 unknown=0
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in
      →*|*\#*)
        # MARKED, OR CARRYING A FRAGMENT — either way it is a citation and not a
        # passing mention, so it is checked and failed.
        seen=$((seen + 1))
        if ! resolve_one_ "$ref" >/dev/null 2>&1; then
          bad=$((bad + 1))
          echo "FAIL '$ref' is a citation and does not resolve" >&2
        fi ;;
      *)
        if resolve_one_ "$ref" >/dev/null 2>&1; then
          seen=$((seen + 1))
        else
          unknown=$((unknown + 1))
        fi ;;
    esac
  done < <(cd "$ROOT" && git grep -ohE '→?\bWSS\.(record|[a-z]+)\.[A-Za-z0-9._-]*[A-Za-z0-9](#[a-z0-9-]+)?' \
             -- ':!wss/logs' ':!wss/generated' ':!*.json' 2>/dev/null | sort -u)
  # `seen` counts citations ATTEMPTED, so the resolving count is seen minus the
  # failures — saying "N resolve" while N includes one that did not is the kind
  # of false count this suite treats as a defect rather than a rounding.
  echo "ok   $((seen - bad)) of $seen citation(s) resolve; $unknown unmarked token(s) resolve to no key"
  echo "     An UNMARKED token that resolves to nothing is not a finding — it is"
  echo "     prose naming a key. A citation carries a leading arrow or a fragment,"
  echo "     and those are checked. WSS.ADDRESSING.md section 1 has the form."
  if [ "$bad" -gt 0 ]; then
    echo "$bad fragment-bearing citation(s) do not resolve" >&2
    return 1
  fi
  return 0
}

[ $# -ge 1 ] || usage
case "$1" in
  --check)
    if ! bash "$ROOT/wss/scripts/wss-tools-inventory.sh" --check >/dev/null 2>&1; then
      echo "wss-resolve.sh: .claude/WSS.TOOLS.json is stale — regenerate it, or every answer is against yesterday's tree" >&2
      exit 1
    fi
    check_ ;;
  -h|--help) usage ;;
  *) resolve_one_ "$1" ;;
esac
