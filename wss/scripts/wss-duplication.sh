#!/usr/bin/env bash
# Emits the deterministic half of two sweeps, so a model pays only for the
# judgment. Read-only: it walks `WSS.record.tooling.sources` and prints
# candidates. It decides nothing — every candidate is a hypothesis a runner
# re-checks against the method that owns it.
#
#   ./wss-duplication.sh              # both scans, over the tooling files
#   ./wss-duplication.sh --duplicates # repeated paragraphs only
#   ./wss-duplication.sh --claims     # mutable-claim candidates only
#   ./wss-duplication.sh --min 200    # duplicate paragraph floor, in chars
#   ./wss-duplication.sh --root /path/to/project
#   ./wss-duplication.sh --scope records   # every MUTABLE record instead
#   ./wss-duplication.sh --scope all       # tooling files and records together
#   ./wss-duplication.sh --paths 'wss/records/*.md'   # an explicit one-off set
#
# WHAT --scope records DOES NOT DO, stated here because the gap is the whole
# reason to read this block. It finds a paragraph RESTATED VERBATIM in two
# records. It does NOT find the same fact written twice in different words —
# see "WHY EXACT-NORMALISED RATHER THAN FUZZY" below, which is a deliberate
# property and not a limitation to fix here. The pair that motivated this scope
# (one entry describing a thing, another describing the same thing differently,
# contradicting it on whether its shape was settled) returns ZERO hits from this
# script and always will. A pre-write check that has to catch a PARAPHRASE needs
# retrieval by subject, not hashing by paragraph, and it is not this script.
#
# WHO CONSUMES WHAT:
#   --duplicates → `wss/tests/WSS.ROT-RESISTANCE.md`'s "uncompared second
#     copy" lens, and `WSS.TOKEN-ECONOMY.md`'s lens 4 (split into reusable
#     parts). Both currently find these by reading; this finds them by hashing.
#   --claims → `wss/tests/WSS.TOOLING-CLAIMS.md`. That method's rule is
#     *delete the mutable claim rather than correcting it*, and its named
#     failure mode is deleting a RULE that merely reads as absolute. This script
#     cannot tell those apart and does not try — it narrows where to look.
#
# WHY EXACT-NORMALISED RATHER THAN FUZZY. Near-duplicate scoring would find more
# and would not be reproducible run to run, which turns a sweep input into
# permanent noise. Two paragraphs match here only if they are identical after
# normalisation. A paraphrase is therefore a MISS, by design — the reading pass
# in `WSS.ROT-RESISTANCE.md` remains the authority, and this is a cheap first cut
# under it, never a replacement.
#
# DETERMINISM IS THE WHOLE MECHANISM, as with `wss-tools-inventory.sh`: no
# timestamps, no absolute paths, no hostname; `LC_ALL=C` and an explicit sort on
# every group and every line. Two runs over one tree produce byte-identical
# output or this script is broken.
set -euo pipefail
export LC_ALL=C

ROOT="${PWD}"
MIN_CHARS=120
DO_DUPES=1
DO_CLAIMS=1
SCOPE=tooling
PATHS_OVERRIDE=()
explicit=0

while [ $# -gt 0 ]; do
  case "$1" in
    --duplicates) DO_DUPES=1; [ "$explicit" -eq 0 ] && DO_CLAIMS=0; explicit=1 ;;
    --claims)     DO_CLAIMS=1; [ "$explicit" -eq 0 ] && DO_DUPES=0; explicit=1 ;;
    --min)        MIN_CHARS="${2:?--min needs a value}"; shift ;;
    --root)       ROOT="${2:?--root needs a path}"; shift ;;
    --scope)      SCOPE="${2:?--scope needs tooling|records|all}"; shift ;;
    --paths)      PATHS_OVERRIDE+=("${2:?--paths needs a glob}"); shift ;;
    -h|--help)    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

cd "$ROOT"

# Validated here rather than inside the resolver, so a typo produces ONE message
# naming the accepted values instead of a resolver error followed by a
# "matched no files" that reads like an empty tree.
case "$SCOPE" in
  tooling|records|all) ;;
  *) echo "FAIL: --scope must be tooling, records or all (got '$SCOPE')" >&2; exit 2 ;;
esac

MANIFEST=".claude/WSS.WORKFLOW.json"
[ -f "$MANIFEST" ] || { echo "FAIL: no $MANIFEST under $ROOT" >&2; exit 1; }

# The globs are the manifest's, never this script's. A project that declares a
# different set gets its own set swept; a project that declares none is a
# refusal rather than a guess, because silently sweeping a default would report
# coverage over files the manifest never claimed.
#
# WHY --scope RESOLVES FROM THE MANIFEST RATHER THAN TAKING A RAW PATH. A path
# typed on the command line is a fourth place the record set is written down,
# and it goes stale the first time a record moves — which is exactly the class
# of defect this script exists to find. `--scope records` therefore asks
# `WSS.recordMode` which keys are `register` and resolves each through
# `WSS.record`, so a moved or renamed record is followed rather than missed.
# `--paths` exists for the one-off case and is deliberately NOT the default.
#
# RECORDS ARE THE MUTABLE ONES, and that is the whole reason the scope splits
# this way. A `log` is append-only and a repeated paragraph in one is history
# rather than drift; a `generated` file is rewritten wholesale from its source.
# Sweeping either would report hits nobody may act on.
if [ "${#PATHS_OVERRIDE[@]}" -gt 0 ]; then
  GLOBS=("${PATHS_OVERRIDE[@]}")
else
  mapfile -t GLOBS < <(python3 - "$MANIFEST" "$SCOPE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
scope = sys.argv[2]
if scope not in ("tooling", "records", "all"):
    sys.exit("FAIL: --scope must be tooling, records or all")
wss  = d.get("WSS", {})
rec  = wss.get("record", {})
mode = wss.get("recordMode", {})
out  = []

if scope in ("tooling", "all"):
    out += (rec.get("tooling", {}) or {}).get("sources") or []

if scope in ("records", "all"):
    def resolve(dotted):
        node = rec
        for part in dotted.split("."):
            if not isinstance(node, dict):
                return None
            node = node.get(part)
        return node
    for key, kind in sorted(mode.items()):
        if kind != "register":
            continue
        val = resolve(key)
        if isinstance(val, str):
            out.append(val)
        elif isinstance(val, list):
            out += [v for v in val if isinstance(v, str)]

if not out:
    sys.exit(3)
for entry in out:
    print(entry)
PY
  ) || { echo "FAIL: $MANIFEST declares nothing for --scope $SCOPE" >&2; exit 1; }
fi

FILES=()
for glob in "${GLOBS[@]}"; do
  for f in $glob; do
    [ -f "$f" ] && FILES+=("$f")
  done
done
[ "${#FILES[@]}" -gt 0 ] || { echo "FAIL: the declared globs matched no files" >&2; exit 1; }

# The file list travels in argv, never on stdin: a `python3 - <<'PY'` heredoc IS
# stdin, so a piped list is silently discarded and every scan reports zero hits
# with no error. Caught by execution, and the shape is worth naming — a scan
# that finds nothing looks exactly like a clean tree.
python3 - "$MIN_CHARS" "$DO_DUPES" "$DO_CLAIMS" "${FILES[@]}" <<'PY'
import hashlib, re, sys

min_chars = int(sys.argv[1])
do_dupes  = sys.argv[2] == "1"
do_claims = sys.argv[3] == "1"
paths     = sorted(sys.argv[4:])
if not paths:
    sys.exit("FAIL: no paths reached the scanner")

# --- normalisation -------------------------------------------------------
# Everything that varies without changing meaning comes out: markdown emphasis,
# list markers, heading hashes, link targets (the TEXT is the content; two files
# citing the same prose via different relative paths are still one copy), and
# all whitespace runs.
LINK   = re.compile(r"\[([^\]]*)\]\([^)]*\)")
MARKER = re.compile(r"^\s*(?:[-*+]|\d+\.|#{1,6}|>)\s+", re.M)
EMPH   = re.compile(r"[*_`]+")
WS     = re.compile(r"\s+")

def normalise(text):
    text = LINK.sub(r"\1", text)
    text = MARKER.sub("", text)
    text = EMPH.sub("", text)
    return WS.sub(" ", text).strip().lower()

def paragraphs(path):
    """Yield (start_line, raw_text, in_fence). Fenced blocks stay whole."""
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    buf, start, fence = [], 1, False
    for n, line in enumerate(lines, 1):
        if line.lstrip().startswith("```"):
            if fence:
                buf.append(line)
                yield start, "\n".join(buf), True
                buf, fence = [], False
                continue
            if buf:
                yield start, "\n".join(buf), False
            buf, start, fence = [line], n, True
            continue
        if fence:
            buf.append(line)
            continue
        if line.strip() == "":
            if buf:
                yield start, "\n".join(buf), False
            buf = []
            continue
        if not buf:
            start = n
        buf.append(line)
    if buf:
        yield start, "\n".join(buf), fence

# --- scan 1: repeated paragraphs ----------------------------------------
if do_dupes:
    groups = {}
    for path in paths:
        for start, raw, fenced in paragraphs(path):
            norm = normalise(raw)
            if len(norm) < min_chars:
                continue
            key = hashlib.sha256(norm.encode()).hexdigest()[:12]
            groups.setdefault(key, {"len": len(norm), "fenced": fenced,
                                    "text": norm, "sites": []})
            groups[key]["sites"].append((path, start))

    repeated = {k: v for k, v in groups.items()
                if len({p for p, _ in v["sites"]}) > 1}

    print("=== REPEATED PARAGRAPHS ===")
    print(f"# {len(repeated)} group(s) appearing in more than one file, "
          f"normalised-exact, floor {min_chars} chars")
    if not repeated:
        print("# none — a clean result, not a failure to look hard enough")
    for key in sorted(repeated, key=lambda k: (-groups[k]["len"], k)):
        g = repeated[key]
        kind = "fenced" if g["fenced"] else "prose"
        print(f"\n[{key}] {g['len']} chars, {kind}, "
              f"{len(g['sites'])} sites, ~{g['len'] * (len(g['sites']) - 1)} "
              f"chars recoverable")
        for path, start in sorted(g["sites"]):
            print(f"    {path}:{start}")
        print(f"    | {g['text'][:150]}"
              f"{'...' if len(g['text']) > 150 else ''}")

# --- scan 2: mutable-claim candidates ------------------------------------
# Each pattern is a SHAPE that a mutable claim tends to take, never a verdict.
# The rule-versus-claim call is the reading pass's and cannot be regexed.
#
# TUNED AGAINST THIS TREE'S MEASURED HITS, not against intuition. Two patterns
# were tried and cut for precision, and they are named here so nobody re-adds
# them believing they were overlooked:
#   - `already` alone produced 174 of 351 total hits — half the output — and
#     essentially all of it ordinary prose ("the deciding is already done").
#   - `one <noun>` produced ~40 more, all article-like ("one file, here",
#     "one row per report"): a statement of design, not a count of state.
# A pre-filter whose output nobody reads has the same value as no pre-filter.
CLAIM_PATTERNS = [
    ("date",     re.compile(r"\b\d{4}-\d{2}-\d{2}\b")),
    ("version",  re.compile(r"\bv?\d+\.\d+(?:\.\d+)?\b")),
    ("count",    re.compile(r"\b(?:currently|so far|to date|at present|as of)\b", re.I)),
    ("count",    re.compile(r"\b(?:two|three|four|five|six|seven|eight|nine|ten|"
                            r"eleven|twelve|thirteen|fourteen|fifteen|twenty)\s+"
                            r"(?:skills?|agents?|files?|records?|checks?|writers?|"
                            r"scripts?|hooks?|lenses|methods?|entries|rows?|"
                            r"passes|sweeps?|jobs?|flags?|commands?)\b", re.I)),
    ("count",    re.compile(r"\b\d+\s+(?:skills?|agents?|files?|records?|checks?|"
                            r"writers?|scripts?|hooks?|lenses|methods?|entries|"
                            r"rows?|passes|sweeps?|jobs?|flags?|commands?)\b", re.I)),
    ("tense",    re.compile(r"\b(?:no longer|now names|not yet|"
                            r"has since|used to)\b", re.I)),
]

if do_claims:
    hits = []
    for path in paths:
        fence = False
        for n, line in enumerate(
                open(path, encoding="utf-8", errors="replace").read().split("\n"), 1):
            if line.lstrip().startswith("```"):
                fence = not fence
                continue
            if fence:
                continue          # fenced text is never cut; see WSS.PROSE-PRUNE.md
            for kind, pattern in CLAIM_PATTERNS:
                m = pattern.search(line)
                if m:
                    hits.append((path, n, kind, m.group(0), line.strip()[:110]))
                    break

    print("\n=== MUTABLE-CLAIM CANDIDATES ===")
    print(f"# {len(hits)} line(s) carrying a shape a mutable claim tends to take.")
    print("# NOT findings. WSS.TOOLING-CLAIMS.md decides, and its named failure")
    print("# mode is deleting a RULE that merely reads as absolute.")
    if not hits:
        print("# none")
    for path, n, kind, matched, context in sorted(hits):
        print(f"{path}:{n}  [{kind}: {matched}]  {context}")
PY
