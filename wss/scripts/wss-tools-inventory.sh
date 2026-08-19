#!/usr/bin/env bash
# Regenerates `.claude/WSS.TOOLS.json` — the measured inventory of this suite's
# tooling. One entry per skill, agent, script, hook, command, check, writer,
# contract and skill reference, carrying only facts a filesystem walk and a
# frontmatter parse can establish: what the file is, what it costs, what it
# names, what it cites, who owns what.
#
# WHAT IT DELIBERATELY DOES NOT HOLD:
#   - what a tool is FOR. That is judgment and belongs in the catalog
#     (`WSS.record.tooling.catalog`, written by `--wss-catalog`).
#   - a global execution order. There is none: which tool runs when depends on
#     which flag was invoked. Edges only.
#   - a budget verdict. This script emits `chainBytes`; `wss-doctor.sh` compares
#     it against `wss/tests/WSS.TOKEN-ECONOMY.md`'s figures and decides.
#
# IDENTITY IS THE NAME, NEVER A PATH:LINE (owner's ruling, 2026-08-13). Every
# cross-reference in the output — `invokes`, `invokedBy`, `methods` — is a
# `name`. `path` is a field of an entry, never a way to reach one.
#
# DETERMINISM IS THE WHOLE MECHANISM. `--check` is a regenerate-and-diff, so any
# run-to-run variation turns the staleness guard into permanent noise. Hence: no
# timestamps, no absolute paths, no `$HOME`, no hostname; `LC_ALL=C` and an
# explicit sort on every entry and every array.
#
# `--check` verifies without writing. Not indexed by sweep freshness: this is a
# filesystem walk and a frontmatter parse, so re-run it and diff.
set -euo pipefail
export LC_ALL=C

# SUITE_ROOT is this installation — where wss/workflow/ actually lives, and never
# repointed by --root. ROOT is what gets ENUMERATED (skills/*/SKILL.md,
# agents/*.md, ...) and defaults to SUITE_ROOT, the case that has always held
# here (this repo is both the suite and its own project). --root overrides
# ROOT alone, for a caller that wants a DIFFERENT tree's skills measured —
# wss-doctor.sh, against a project-local skill under $PWD/.claude — while
# every citation a measured SKILL.md makes into wss/workflow/, wss/workflow/writers/,
# wss/tests/, wss/workflow/providers/ or WSS.OWNERSHIP.md is still
# classified against SUITE_ROOT, because that is where those contracts
# actually live regardless of whose skill cites them. Repointing that
# anchor too would silently reclassify every citation as `other` and report
# every chain as just the SKILL.md's own bytes — the exact failure this
# split exists to avoid.
#
# The manifest ($ROOT/.claude/WSS.WORKFLOW.json) is read from $ROOT, not
# SUITE_ROOT, because its globs are relative to $ROOT: a glob list and the
# tree it is relative to must come from the same place. Using SUITE_ROOT would
# apply this suite's skills to a foreign tree.
SUITE_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
ROOT="$SUITE_ROOT"
TARGET="$SUITE_ROOT/.claude/WSS.TOOLS.json"
REGEN="bash wss/scripts/wss-tools-inventory.sh"

CHECK=0
ROOT_OVERRIDDEN=0
while [ $# -gt 0 ]; do
  case $1 in
    --check) CHECK=1; shift ;;
    --root)
      [ $# -ge 2 ] || { echo "wss-tools-inventory.sh: --root needs a directory" >&2; exit 2; }
      ROOT=$2; ROOT_OVERRIDDEN=1; shift 2 ;;
    *) echo "wss-tools-inventory.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "$ROOT_OVERRIDDEN" = 1 ]; then
  # Fail loudly rather than measure nothing. wss-audit-assets.sh's own
  # comment records why a silent empty root is the failure mode to design
  # against: a chain figure of 0 for a skill that was never found reads as
  # measured, and it is not — worse than an honest "not measured" notice.
  [ -d "$ROOT" ] || {
    echo "wss-tools-inventory.sh: --root $ROOT does not exist" >&2
    exit 1
  }
  ROOT=$(cd -- "$ROOT" && pwd -P) || {
    echo "wss-tools-inventory.sh: --root $ROOT did not resolve" >&2
    exit 1
  }
fi

command -v jq >/dev/null 2>&1 || {
  echo "wss-tools-inventory.sh: jq is required" >&2
  exit 1
}

# ---------------------------------------------------------------- helpers

rel() { printf '%s' "${1#"$ROOT"/}"; }

# Subshell function bodies, so `set +o pipefail` is local to them: `grep` exits 1
# on no match, which is an ordinary result here (a file citing nothing) and must
# not kill the run under errexit — while a real read failure still surfaces as
# empty output rather than a silently wrong number, because every caller of these
# checks the file exists first.

fm_value() ( # file key -> raw frontmatter value, empty if absent
  set +e
  awk -v k="$2" '
    NR == 1 && /^---/ { fm = 1; next }
    fm && /^---/ { exit }
    fm && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      print v; exit
    }' "$1"
)

decode_desc() { # raw YAML scalar -> the string it denotes
  local raw="$1"
  case "$raw" in
    '"'*'"') printf '%s' "$raw" | jq -r . 2>/dev/null || printf '%s' "$raw" ;;
    *) printf '%s' "$raw" ;;
  esac
}

# ------------------------------------------------- the citation walk, moved

# Ported verbatim in behaviour from wss-doctor.sh's "Chain budgets" section, so
# the same number is not computed by two implementations. The doctor keeps the
# JUDGEMENT (budget figures, tier thresholds, the over-budget notice); this
# script keeps the MEASUREMENT. Everything below this banner down to
# chain_bytes() is that measurement.
#
# CITATION FORM: a markdown link to a .md file — `[`Text`](path.md#anchor)` or
# the same without backticks. One regex covers both.
#
# WHAT COUNTS AS THE UNCONDITIONAL SAME-WINDOW CHAIN:
#   - the SKILL.md's own bytes;
#   - every direct citation into wss/workflow/, wss/tests/, wss/workflow/writers/
#     or wss/workflow/providers/ — contracts a dispatch runs inline;
#   - ONE further level, ONLY through wss/workflow/writers/*.md targets.
# EXCLUDED: the citing skill's own references/ (convention-gated), cross-skill
# SKILL.md and agents/ citations (may run in a fresh context), WSS.OWNERSHIP.md
# (a row-scoped authority lookup), and anything outside wss/workflow/.

citations_in() ( # file -> one resolved absolute path per citation, fences excluded
  set +e
  cf="$1"
  [ -f "$cf" ] || exit 0
  cd_=$(dirname "$cf")
  awk '/^[[:space:]]*(```|~~~)/ { fence = !fence; next } fence { next } { print }' "$cf" |
  grep -oE '\[[^]]*\]\([^)]+\.md[^)]*\)' |
  sed -E 's/^\[[^]]*\]\(([^)]+)\)$/\1/; s/[#?].*$//' |
  while IFS= read -r cr_; do
    [ -n "$cr_" ] || continue
    case "$cr_" in http*|/*) continue ;; esac  # external, or site-root-relative
    realpath -m "$cd_/$cr_" 2>/dev/null
  done
)

classify() { # resolved-path citing-skill-dir -> chain class
  case "$1" in
    "$SUITE_ROOT"/wss/workflow/WSS.OWNERSHIP.md) echo authority ;;
    "$SUITE_ROOT"/wss/workflow/writers/*.md) echo writer ;;
    "$SUITE_ROOT"/wss/tests/*.md|"$SUITE_ROOT"/wss/workflow/providers/*.md|"$SUITE_ROOT"/wss/workflow/*.md)
      echo contract ;;
    "$2"/references/*.md) echo reference ;;
    */SKILL.md|"$SUITE_ROOT"/agents/*.md|"$ROOT"/agents/*.md) echo dispatch ;;
    *) echo other ;;
  esac
}

chain_bytes() { # SKILL.md-path -> the same-window chain in bytes
  local f="$1" skilldir total seen writers cite cls w
  skilldir=$(dirname "$f")
  total=$(wc -c < "$f")
  seen="$f
"
  writers=""
  while IFS= read -r cite; do
    [ -n "$cite" ] || continue
    cls=$(classify "$cite" "$skilldir")
    case "$cls" in
      contract|writer)
        printf '%s' "$seen" | grep -qxF "$cite" && continue
        seen="$seen$cite
"
        [ -f "$cite" ] && total=$((total + $(wc -c < "$cite")))
        [ "$cls" = writer ] && writers="$writers$cite
" ;;
    esac
  done < <(citations_in "$f")

  while IFS= read -r w; do
    [ -n "$w" ] || continue
    while IFS= read -r cite; do
      [ -n "$cite" ] || continue
      cls=$(classify "$cite" "$skilldir")
      case "$cls" in
        contract|writer)
          printf '%s' "$seen" | grep -qxF "$cite" && continue
          seen="$seen$cite
"
          [ -f "$cite" ] && total=$((total + $(wc -c < "$cite"))) ;;
      esac
    done < <(citations_in "$w")
  done <<< "$writers"

  printf '%s' "$total"
}

# ------------------------------------------------------------- enumeration

declare -a E_PATH=() E_KIND=() E_NAME=()
declare -A NAME_OF_PATH=()

add_entry() { # abs-path kind name
  local p="$1" k="$2" n="$3" r
  [ -e "$p" ] || return 0
  # Editor and backup residue is not tooling. The globs below walk the
  # filesystem rather than `git ls-files`, deliberately — a new skill must be
  # inventoried before it is committed, or `git add` would itself make the
  # JSON stale. The cost of that choice is that a stray file gets measured,
  # and the failure it produces is worse than it looks: the doctor goes red,
  # regenerating "fixes" it, and the committed artifact then names a file no
  # fresh clone has. Observed with two .bak files left in hooks/.
  # Whether the walk should be tracked-only is a real fork; this list is the
  # narrow half, and it excludes only what is residue under any reading.
  case "${p##*/}" in
    *.bak|*.orig|*.rej|*.tmp|*~|.*.sw?|.#*|\#*\#) return 0 ;;
  esac
  r=$(rel "$p")
  if [ -n "${NAME_OF_PATH[$n]+set}" ]; then
    echo "wss-tools-inventory.sh: duplicate entry name '$n' ($r and ${NAME_OF_PATH[$n]})" >&2
    exit 1
  fi
  NAME_OF_PATH[$n]="$r"
  E_PATH+=("$p"); E_KIND+=("$k"); E_NAME+=("$n")
}

# The manifest's globs, then the executable surface no documentation glob names.
DEFAULT_SOURCES='skills/*/SKILL.md
skills/*/references/*.md
agents/*.md
wss/workflow/*.md
wss/workflow/providers/*.md
wss/workflow/writers/*.md
wss/tests/*.md
commands/*.md'

MANIFEST="$ROOT/.claude/WSS.WORKFLOW.json"
SOURCES=""
[ -f "$MANIFEST" ] && SOURCES=$(jq -r '.WSS.record.tooling.sources // [] | .[] | select(type == "string")' "$MANIFEST" 2>/dev/null || true)
[ -n "$SOURCES" ] || SOURCES="$DEFAULT_SOURCES"

kind_of_glob() { # glob -> "kind namerule", empty if unrecognised
  case "$1" in
    */SKILL.md)                       printf 'skill dirname' ;;
    */references/*.md)                printf 'reference skilldir' ;;
    agents/*.md|*/agents/*.md)        printf 'agent stem' ;;
    commands/*.md|*/commands/*.md)    printf 'command stem' ;;
    */writers/*.md)                   printf 'writer base' ;;
    */checks/*.md|wss/tests/*.md|*/wss/tests/*.md) printf 'check base' ;;
    */providers/*.md|wss/workflow/*.md|*/wss/workflow/*.md) printf 'contract base' ;;
    # A judge file is the same class of content as a workflow contract —
    # normative statements a skill or agent reads to decide what to do — so it
    # takes the same kind rather than a new one. `prospective/` is deliberately
    # NOT admitted: those files are the build queue, their basenames are twins
    # of the live ones (`WSS.RULES-DOC.md` exists in both), and a flat name
    # index cannot hold both under `base`.
    wss/rules/*.md|*/wss/rules/*.md)  printf 'contract base' ;;
  esac
}

while IFS= read -r g; do
  [ -n "$g" ] || continue
  case "$g" in /*|*..*) echo "wss-tools-inventory.sh: refusing an absolute or parent-relative source glob: $g" >&2; exit 1 ;; esac
  spec=$(kind_of_glob "$g")
  [ -n "$spec" ] || { echo "wss-tools-inventory.sh: WSS.record.tooling.sources declares '$g', whose kind this walk cannot name — add a shape to kind_of_glob()" >&2; exit 1; }
  k=${spec%% *}; rule=${spec##* }
  for p in "$ROOT"/$g; do
    [ -f "$p" ] || continue
    case "$rule" in
      dirname)  n=$(basename "$(dirname "$p")") ;;
      skilldir) n="$(basename "$(dirname "$(dirname "$p")")")/$(basename "$p")" ;;
      stem)     n=$(basename "$p" .md) ;;
      base)     n=$(basename "$p") ;;
    esac
    add_entry "$p" "$k" "$n"
  done
done <<< "$SOURCES"
for p in "$ROOT"/wss-*.sh;                     do [ -f "$p" ] && add_entry "$p" script   "$(basename "$p")"; done
for p in "$ROOT"/wss/scripts/wss-*.sh;         do [ -f "$p" ] && add_entry "$p" script   "$(basename "$p")"; done
for p in "$ROOT"/skills/*/assets/*;            do [ -f "$p" ] && add_entry "$p" script   "$(basename "$p")"; done
for p in "$ROOT"/wss/workflow/writers/assets/*;    do [ -f "$p" ] && add_entry "$p" script   "$(basename "$p")"; done
for p in "$ROOT"/wss/tests/*.sh;               do [ -f "$p" ] && add_entry "$p" script   "$(basename "$p")"; done
for p in "$ROOT"/hooks/*;                      do [ -f "$p" ] && add_entry "$p" hook     "$(basename "$p")"; done

# name -> index, and repo-relative path -> name, for edge resolution.
declare -A IDX_OF=() NAME_AT=()
for i in "${!E_NAME[@]}"; do
  IDX_OF[${E_NAME[$i]}]=$i
  NAME_AT[$(rel "${E_PATH[$i]}")]=${E_NAME[$i]}
done

# Basename aliases, so a token written as a path resolves to the entry it names.
# An ambiguous basename (two skills each carrying a references/WSS.LANES.md) is
# dropped rather than guessed — the citation route below resolves those exactly.
declare -A ALIAS=()
for n in "${!IDX_OF[@]}"; do
  b=${n##*/}
  [ "$b" = "$n" ] && continue
  if [ -n "${ALIAS[$b]+set}" ]; then ALIAS[$b]="!"; else ALIAS[$b]="$n"; fi
done
# Say which basenames were dropped and how many. Dropping is correct — guessing
# between two files of one name is worse — but doing it in silence reads exactly
# like there having been none to drop, and a caller who cites one of those
# entries by basename gets no resolution and no reason for it.
# Said when WRITING the inventory and silent under `--check`. The check is a
# regenerate-and-diff whose callers capture it with `2>&1` and print whatever
# comes back as the reason a run failed — so a diagnostic on stderr here is
# read as the cause. It happened: a stale inventory reported itself as
# "stale or missing: ambiguous basename, not aliased: …", which names a
# condition that is neither the failure nor fixable by the person reading it.
# The diagnostic is about the alias map a write produces; a check produces none.
alias_ambiguous=0
for b in "${!ALIAS[@]}"; do
  [ "${ALIAS[$b]}" = "!" ] || continue
  alias_ambiguous=$((alias_ambiguous + 1))
  [ "$CHECK" = 1 ] || printf 'wss-tools-inventory: ambiguous basename, not aliased: %s\n' "$b" >&2
done
[ "$alias_ambiguous" -eq 0 ] || [ "$CHECK" = 1 ] || printf \
  'wss-tools-inventory: %d ambiguous basename(s) dropped — cite those by full path\n' \
  "$alias_ambiguous" >&2

# ---------------------------------------------------- the ownership matrix

# Tier, grant, owned record keys and flags come from wss/workflow/WSS.OWNERSHIP.md's
# matrix, read structurally — never copied into a list here, which would be the
# drift-prone second source WSS.TOKEN-ECONOMY.md's lens 11 forbids. A tool with
# no row is not an error: scripts, hooks and contracts have none by design
# ("a file with no owner in the matrix is not ownerless work — it is ordinary
# work"), and a newly added tool has none yet. Those get null, not a guess.
OWNERSHIP="$SUITE_ROOT/wss/workflow/WSS.OWNERSHIP.md"
MATRIX=""
if [ -f "$OWNERSHIP" ]; then
  MATRIX=$(awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^\| [a-z]/ {
      gsub(/\t/, " ")
      n = split($0, c, "|")
      if (n < 8) next

      # Column 4, "Skill or procedure": its FIRST token is the row subject. A row
      # that mentions a second tool ("docs, which dispatches to
      # writers/WSS.DOCS-WRITER.md") is a row about the first one; the second has
      # its own row and takes its tier from there.
      s = c[4]
      gsub(/\]\([^)]*\)/, "", s); gsub(/\[/, "", s)
      gsub(/`/, "", s); gsub(/\*/, "", s)
      s = trim(s)
      split(s, w, /[ ,]/)
      primary = w[1]
      if (primary == "") next

      tier = trim(c[5])
      if (tier != "primitive" && tier != "orchestrator") tier = ""

      fl = c[3]; flags = ""
      while (match(fl, /--wss-[a-z-]+/)) {
        flags = flags (flags ? "," : "") substr(fl, RSTART, RLENGTH)
        fl = substr(fl, RSTART + RLENGTH)
      }

      # Column 6, "Sole writer of". A cell that says "nothing" owns nothing, and
      # saying so beats scraping a backtick out of the sentence explaining why.
      o = c[6]; owns = ""
      if (o !~ /nothing/) {
        while (match(o, /`[^`]+`/)) {
          t = substr(o, RSTART + 1, RLENGTH - 2)
          if (t ~ /^WSS\./ || t ~ /^\.claude\// || t ~ /^docs\//)
            owns = owns (owns ? "," : "") t
          o = substr(o, RSTART + RLENGTH)
        }
      }

      grant = trim(c[7]); gsub(/\*/, "", grant)
      # US (\x1f), not tab: `read` treats tab as IFS WHITESPACE and collapses a
      # run of them, so an empty middle field (a row with no flag, or an empty
      # Tier) silently shifts every field after it by one.
      printf "%s\037%s\037%s\037%s\037%s\n", primary, tier, flags, grant, owns
    }' "$OWNERSHIP")
fi

declare -A M_TIER=() M_GRANT=() M_FLAGS=() M_OWNS=() FLAG_TO_NAME=()
while IFS=$'\037' read -r primary tier flags grant owns; do
  [ -n "${primary:-}" ] || continue
  key="$primary"
  if [ -z "${IDX_OF[$key]+set}" ]; then
    b=${key##*/}
    if [ -n "${ALIAS[$b]+set}" ] && [ "${ALIAS[$b]}" != "!" ]; then
      key=${ALIAS[$b]}
    elif [ -n "${IDX_OF[$b]+set}" ]; then
      key="$b"
    else
      continue                       # a row about something that is not a file here
    fi
  fi
  # First row wins for tier and grant (matrix order, deterministic); owned keys
  # and flags union across every row of the same subject, since a skill reached
  # by two verbs writes the union of what both rows name.
  [ -n "${M_TIER[$key]+set}" ] || M_TIER[$key]="$tier"
  [ -n "${M_GRANT[$key]+set}" ] || M_GRANT[$key]="$grant"
  M_FLAGS[$key]="${M_FLAGS[$key]:-}${flags:+$flags,}"
  M_OWNS[$key]="${M_OWNS[$key]:-}${owns:+$owns,}"
  if [ -n "$flags" ]; then
    IFS=',' read -r -a fa <<< "$flags"
    for f in "${fa[@]}"; do [ -n "$f" ] && FLAG_TO_NAME[$f]="$key"; done
  fi
done <<< "$MATRIX"

normalize_grant() { # the matrix's authorization cell -> commit | commit+push | none | ""
  local g
  g=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$g" in
    ""|"—"|"-") printf '' ;;
    *none*) printf 'none' ;;
    *"not push"*) printf 'commit' ;;
    *"push needs a fresh ok"*) printf 'commit' ;;
    *push*) printf 'commit+push' ;;
    *commit*) printf 'commit' ;;
    *) printf '' ;;
  esac
}

# ------------------------------------------------------------ measurement

TMPDIR_=$(mktemp -d)
trap 'rm -rf "$TMPDIR_"' EXIT

# Pass 1: per-entry facts and the raw citation set, cached so the edge pass does
# not walk every file a second time.
declare -a READS=() TOKENS=()
for i in "${!E_NAME[@]}"; do
  f=${E_PATH[$i]}
  r=""
  while IFS= read -r cite; do
    [ -n "$cite" ] || continue
    [ -f "$cite" ] || continue
    case "$cite" in "$ROOT"/*) ;; *) continue ;; esac
    r="$r$(rel "$cite")
"
  done < <(citations_in "$f")
  READS[$i]="$r"

  # Every maximal path/flag-shaped token in the file, fences included: an
  # invocation is as likely to sit in a code block as in prose.
  TOKENS[$i]=$( set +e; grep -oE '[A-Za-z0-9_./-]+' "$f" | sort -u )
done

# Pass 2: edges. `invokes` is the union of two mechanical routes — a resolved
# citation whose target is an inventory entry, and a bare token naming an entry
# or a flag the matrix maps to one. It is a REFERENCE graph, the most an
# unaided walk can see; which reference is a dispatch is judgment, and judgment
# is the catalog's.
#
# Only executing kinds originate an edge. A contract, check, writer or reference
# is read inline by whatever dispatched it; it runs nothing itself, and letting
# WSS.OWNERSHIP.md — which names every skill in the suite — originate 23 edges
# would make `invokedBy` mean nothing.
declare -a INVOKES=()
for i in "${!E_NAME[@]}"; do
  self=${E_NAME[$i]}
  case "${E_KIND[$i]}" in
    skill|agent|script|hook|command) ;;
    *) INVOKES[$i]=""; continue ;;
  esac
  acc=""
  while IFS= read -r rp; do
    [ -n "$rp" ] || continue
    [ -n "${NAME_AT[$rp]+set}" ] || continue
    [ "${NAME_AT[$rp]}" = "$self" ] && continue
    acc="$acc${NAME_AT[$rp]}
"
  done <<< "${READS[$i]}"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    cand="$tok"
    while [ "${cand#-}" != "$cand" ]; do cand=${cand#-}; done
    # `---`, `--` and a trailing slash all strip to nothing; an empty associative
    # subscript is a hard error under `set -u`, not a miss.
    [ -n "$cand" ] || continue
    hit=""
    if [ -n "${FLAG_TO_NAME[--$cand]+set}" ]; then hit=${FLAG_TO_NAME[--$cand]}
    elif [ -n "${IDX_OF[$cand]+set}" ]; then hit=$cand
    else
      b=${cand##*/}
      [ -n "$b" ] || continue
      if [ "$b" != "$cand" ] && [ -n "${ALIAS[$b]+set}" ] && [ "${ALIAS[$b]}" != "!" ]; then
        hit=${ALIAS[$b]}
      elif [ "$b" != "$cand" ] && [ -n "${IDX_OF[$b]+set}" ]; then
        hit=$b
      fi
    fi
    [ -n "$hit" ] && [ "$hit" != "$self" ] && acc="$acc$hit
"
  done <<< "${TOKENS[$i]}"
  INVOKES[$i]="$acc"
done

# Pass 3: emit one JSON object per entry.
out="$TMPDIR_/entries.ndjson"
: >"$out"
for i in "${!E_NAME[@]}"; do
  f=${E_PATH[$i]}; kind=${E_KIND[$i]}; name=${E_NAME[$i]}

  raw_desc=$(fm_value "$f" description)
  description=""
  [ -n "$raw_desc" ] && description=$(decode_desc "$raw_desc")

  tools=$(fm_value "$f" tools)

  # spawn floor: what the tools grant makes possible, and nothing more. A grant
  # with no agent-spawning tool in it can only ever occupy one context, so its
  # floor is 1. A grant that CAN spawn has no floor this walk can compute, and a
  # measured-looking number nobody measured is worse than a null.
  spawnFloor=null
  if [ -n "$tools" ]; then
    if printf '%s' "$tools" | grep -qE '(^|[^A-Za-z])(Task|Agent)([^A-Za-z]|$)'; then
      spawnFloor=null
    else
      spawnFloor=1
    fi
  fi

  # Both spellings occur in the tree; either one, set truthy, blocks model
  # invocation. Normalised to one boolean here.
  modelInvocable=null
  if [ "$kind" = skill ]; then
    d1=$(fm_value "$f" disable-model-invocation)
    d2=$(fm_value "$f" disableModelInvocation)
    if [ "$d1" = true ] || [ "$d2" = true ]; then modelInvocable=false; else modelInvocable=true; fi
  fi

  chainBytes=null
  [ "$kind" = skill ] && chainBytes=$(chain_bytes "$f")

  tier=${M_TIER[$name]:-}
  grantRaw=${M_GRANT[$name]:-}
  grant=$(normalize_grant "$grantRaw")

  flags_nl=$(printf '%s' "${M_FLAGS[$name]:-}" | tr ',' '\n')
  owns_nl=$(printf '%s' "${M_OWNS[$name]:-}" | tr ',' '\n')

  # `methods` — the named lenses this tool applies: the check contracts it
  # references. wss/tests/*.md is where a lens is defined, so an edge into
  # one is the tool declaring which method it runs.
  methods_nl=""
  while IFS= read -r nm; do
    [ -n "$nm" ] || continue
    j=${IDX_OF[$nm]:-}
    [ -n "$j" ] || continue
    [ "${E_KIND[$j]}" = check ] && methods_nl="$methods_nl$nm
"
  done <<< "${INVOKES[$i]}"

  jq -nc \
    --arg name "$name" --arg kind "$kind" --arg path "$(rel "$f")" \
    --arg description "$description" \
    --arg tools "$tools" --argjson spawnFloor "$spawnFloor" \
    --arg tier "$tier" --arg grant "$grant" --arg grantRaw "$grantRaw" \
    --argjson modelInvocable "$modelInvocable" \
    --argjson bytes "$(wc -c < "$f")" --argjson chainBytes "$chainBytes" \
    --arg flags "$flags_nl" --arg invokes "${INVOKES[$i]}" \
    --arg reads "${READS[$i]}" --arg owns "$owns_nl" --arg methods "$methods_nl" \
    '
    def lst: if . == "" then [] else (split("\n") | map(select(length > 0)) | unique) end;
    def nul: if . == "" then null else . end;
    {
      name: $name,
      kind: $kind,
      path: $path,
      description: ($description | nul),
      descriptionBytes: (if $description == "" then null else ($description | utf8bytelength) end),
      bytes: $bytes,
      chainBytes: $chainBytes,
      tier: ($tier | nul),
      grant: ($grant | nul),
      grantRaw: ($grantRaw | nul),
      flags: ($flags | lst),
      tools: (if $tools == "" then null
              else ($tools | split(",") | map(sub("^ +"; "") | sub(" +$"; "")) | map(select(length > 0)))
              end),
      spawnFloor: $spawnFloor,
      modelInvocable: $modelInvocable,
      owns: ($owns | lst),
      methods: ($methods | lst),
      invokes: ($invokes | lst),
      invokedBy: [],
      reads: ($reads | lst)
    }' >>"$out"
done

render() {
  jq -s --arg regen "$REGEN" '
    . as $all
    | {
        generated_by: "wss-tools-inventory.sh",
        note: ("Generated by `wss-tools-inventory.sh` — never hand-edit. Regenerate with `"
               + $regen + "`, verify with `" + $regen + " --check`. "
               + "Facts only: what each tool is FOR belongs in the catalog, and there is no global "
               + "execution order here because there is none — it depends which flag was invoked. "
               + "Dependencies are named, never located: reference an entry by `name`, never by path or line."),
        entries: ([ $all[]
                    | . as $x
                    | $x + { invokedBy: ([ $all[]
                                           | select(.invokes | index($x.name) != null)
                                           | .name ] | unique) } ]
                  | sort_by(.name))
      }' "$out"
}

# ------------------------------------------------------------ check / write

if [ "$ROOT_OVERRIDDEN" = 1 ]; then
  # A foreign tree measured on someone else's behalf (wss-doctor.sh, a
  # project-local skill) is never persisted into THIS installation's own
  # TARGET — that file names only this suite's own entries, and writing a
  # project's skill into it would be exactly the drift-prone second source
  # WSS.TOKEN-ECONOMY.md's lens 11 forbids. Print the same JSON to stdout
  # instead, for a caller to query with jq and discard.
  render
elif [ "$CHECK" = 1 ]; then
  [ -f "$TARGET" ] || {
    echo "tools inventory STALE: $(rel "$TARGET") does not exist — run $REGEN" >&2
    exit 1
  }
  # Rendered to a file rather than compared through `diff <(render)`: a process
  # substitution is a subshell, so a failure inside render reaches nothing there
  # and diff simply reports a difference — "STALE" for an inventory that is not.
  tmp=$(mktemp)
  trap 'rm -rf "$TMPDIR_"; rm -f "$tmp"' EXIT
  render >"$tmp"
  if diff "$tmp" "$TARGET" >/dev/null; then
    echo "tools inventory current: $(rel "$TARGET") matches the tree"
  else
    echo "tools inventory STALE: $(rel "$TARGET") does not match the tree — run $REGEN" >&2
    exit 1
  fi
else
  tmp=$(mktemp)
  trap 'rm -rf "$TMPDIR_"; rm -f "$tmp"' EXIT
  render >"$tmp"
  mkdir -p "$(dirname "$TARGET")"
  cat "$tmp" >"$TARGET"   # not `mv`: mktemp's 0600 would follow the file across
  echo "wrote $(rel "$TARGET") ($(jq '.entries | length' "$TARGET") entries)"
fi
