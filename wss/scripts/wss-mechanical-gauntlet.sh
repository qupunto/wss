#!/usr/bin/env bash
# wss-mechanical-gauntlet.sh — the deterministic half of
# wss/tests/WSS.MECHANICAL-GAUNTLET.md: doctor, typecheck, the full
# WSS.commands.test suite, and CI resolution on HEAD's sha, in one call
# instead of the several a runner would otherwise retype. That file stays
# the one statement of what each outcome MEANS and why a refusal or a
# carry-forward is handled the way it is; this script only runs the
# commands and prints a `== verdict ==` block.
#
# Under wss/scripts/ because more than one skill invokes the gauntlet
# (full-check, stocktake) — no single skill owns it, the same basis
# wss-tools-inventory.sh has a root row on per wss/workflow/WSS.OWNERSHIP.md.
#
#   wss-mechanical-gauntlet.sh [--test-consent] [--carry-forward REASON]
#
#   --test-consent       The user was asked this session — the ONE attempt
#                         WSS.MECHANICAL-GAUNTLET.md's "consent budget"
#                         allows — and said yes. Only meaningful where the
#                         manifest declares WSS.commands.testConsentEnv; a
#                         project with no such gate always runs the suite.
#                         This script does not ask and does not remember
#                         whether asking already happened — that budget is
#                         the caller's to track.
#   --carry-forward MSG   sweep-tracker licensed skipping the run (per the
#                         contract's "The carry-forward" — ask the tracker,
#                         never read the checkpoint file directly). MSG is
#                         reported verbatim as why. Takes priority over
#                         --test-consent and skips actually running the
#                         suite.
#
# Run from the project directory (PWD) like every WSS.commands.* invocation:
# the manifest read is $PWD/.claude/WSS.WORKFLOW.json. wss-doctor.sh itself
# is found next to this script, not via $HOME/.claude, so this works the
# same from a checkout or a plugin cache.
set -uo pipefail

SUITE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
MANIFEST=".claude/WSS.WORKFLOW.json"
HAVE_JQ=1; command -v jq >/dev/null 2>&1 || HAVE_JQ=0
HAVE_MANIFEST=0; [ -f "$MANIFEST" ] && HAVE_MANIFEST=1

TEST_CONSENT=0
CARRY_REASON=""
while [ $# -gt 0 ]; do
  case "$1" in
    --test-consent) TEST_CONSENT=1; shift ;;
    --carry-forward) CARRY_REASON="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    *) echo "wss-mechanical-gauntlet.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# mget <jq-path> — the value at that path, or empty if unset, undeclared, or
# the manifest/jq is unavailable. Never a fallback default: an undeclared
# WSS.commands.* key means "skipped", not "guess a convention".
mget() {
  [ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 1 ] || { printf ''; return; }
  jq -r "$1 // empty" "$MANIFEST" 2>/dev/null
}

echo "== mechanical gauntlet =="
[ "$HAVE_MANIFEST" = 0 ] && echo "note: no manifest at $MANIFEST — WSS.commands.* below all read as undeclared"
[ "$HAVE_MANIFEST" = 1 ] && [ "$HAVE_JQ" = 0 ] && echo "note: jq unavailable — manifest unreadable, every WSS.commands.* key reads as undeclared"

overall=0

# 1. The doctor. Always, never optional, no checkpoint covers it. It
# inspects both the configuration and the project in $PWD, and catches
# failures that read exactly like working config.
DOCTOR="$SUITE_ROOT/wss/tests/wss-doctor.sh"
echo "--- doctor ---"
if [ -x "$DOCTOR" ]; then
  if "$DOCTOR"; then doctor_verdict=pass; else doctor_verdict=fail; overall=1; fi
else
  echo "wss-doctor.sh not found or not executable at $DOCTOR"
  doctor_verdict=missing; overall=1
fi

# 2. Typecheck.
TYPECHECK_CMD="$(mget '.WSS.commands.typecheck')"
echo "--- typecheck ---"
if [ -n "$TYPECHECK_CMD" ]; then
  if bash -c "$TYPECHECK_CMD"; then typecheck_verdict=pass; else typecheck_verdict=fail; overall=1; fi
else
  echo "WSS.commands.typecheck undeclared — skipped"
  typecheck_verdict=undeclared
fi

# 3. Test — the FULL suite with coverage, never a subset. A green suite
# says nothing about WSS.gate.coverage, which is what CI enforces. Gated by
# consent where the manifest names a token, and by a caller-licensed
# carry-forward; a failure is re-run once in full before being reported as
# one, per the contract.
TEST_CMD="$(mget '.WSS.commands.test')"
CONSENT_ENV="$(mget '.WSS.commands.testConsentEnv')"
echo "--- test ---"
if [ -z "$TEST_CMD" ]; then
  echo "WSS.commands.test undeclared — skipped"
  test_verdict=undeclared
elif [ -n "$CARRY_REASON" ]; then
  echo "carried forward: $CARRY_REASON"
  test_verdict=carried
elif [ -n "$CONSENT_ENV" ] && [ "$TEST_CONSENT" != 1 ]; then
  echo "consent gate WSS.commands.testConsentEnv=$CONSENT_ENV not satisfied — ask once this session, then re-run with --test-consent"
  test_verdict=not-covered
else
  dirty=""
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null || dirty="+dirty"
  else
    dirty="+not-a-repo"
  fi
  if bash -c "$TEST_CMD"; then
    test_verdict=pass
  else
    echo "test run failed once — re-running in full before treating it as a finding"
    if bash -c "$TEST_CMD"; then test_verdict=pass; else test_verdict=fail; overall=1; fi
  fi
  case "$dirty" in
    "+dirty") echo "note: tree is dirty ($dirty) — this run cannot license a carry-forward stamp" ;;
    "+not-a-repo") echo "note: not a git checkout — dirty-tree state unknown ($dirty) — this run cannot license a carry-forward stamp" ;;
  esac
fi

# 4. CI, on the audited commit. A green local run says nothing about
# whether the tests gate anything. Four outcomes, all reported: green, red
# (a finding on its own, outranking most prose findings), no run for this
# sha (never pushed, or the triggers do not cover it), no CI at all (a
# standing finding). Never quietly treat a missing run as a pass.
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
CI_TOOL="$(mget '.WSS.commands.ci.tool')"
CI_WORKFLOW="$(mget '.WSS.commands.ci.workflow')"
CI_CMD_RAW="$(mget '.WSS.commands.ci')"
echo "--- CI ---"
if [ -z "$HEAD_SHA" ]; then
  echo "not a git checkout — cannot resolve a sha"
  ci_verdict=unknown
elif [ "$CI_TOOL" = "gh" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "WSS.commands.ci names gh, but gh is not installed"
    ci_verdict=unknown
  else
    RUNS_JSON="$(gh run list --limit 20 --json headSha,conclusion,workflowName,createdAt 2>/dev/null || echo '[]')"
    if [ "$HAVE_JQ" = 1 ]; then
      if [ -n "$CI_WORKFLOW" ]; then
        MATCH="$(printf '%s' "$RUNS_JSON" | jq -r --arg sha "$HEAD_SHA" --arg wf "$CI_WORKFLOW" '[.[] | select(.headSha==$sha and .workflowName==$wf)] | sort_by(.createdAt) | last // empty')"
      else
        MATCH="$(printf '%s' "$RUNS_JSON" | jq -r --arg sha "$HEAD_SHA" '[.[] | select(.headSha==$sha)] | sort_by(.createdAt) | last // empty')"
      fi
      if [ -z "$MATCH" ] || [ "$MATCH" = "null" ]; then
        TOTAL="$(printf '%s' "$RUNS_JSON" | jq 'length' 2>/dev/null || echo 0)"
        if [ "$TOTAL" = 0 ]; then
          echo "no CI runs at all — standing finding"
          ci_verdict=no-ci
        else
          echo "no run for $HEAD_SHA — never pushed, or the triggers do not cover it"
          ci_verdict=no-run-for-sha
        fi
      else
        CONCLUSION="$(printf '%s' "$MATCH" | jq -r '.conclusion')"
        printf '%s\n' "$MATCH"
        if [ "$CONCLUSION" = "success" ]; then ci_verdict=green; else ci_verdict=red; overall=1; fi
      fi
    else
      echo "jq unavailable — raw gh output follows for manual read"
      printf '%s\n' "$RUNS_JSON"
      ci_verdict=unknown
    fi
  fi
elif [ -n "$CI_TOOL" ]; then
  echo "WSS.commands.ci.tool=$CI_TOOL is not a recognised tool (only \"gh\" is defined) — treating as undeclared"
  ci_verdict=undeclared
elif [ -n "$CI_CMD_RAW" ] && [ "$CI_CMD_RAW" != "null" ]; then
  echo "running the declared WSS.commands.ci shell command:"
  bash -c "$CI_CMD_RAW" || true
  ci_verdict=see-output
else
  echo "WSS.commands.ci undeclared — cannot resolve CI"
  ci_verdict=undeclared
fi

echo
echo "== verdict =="
echo "doctor: $doctor_verdict"
echo "typecheck: $typecheck_verdict"
echo "test: $test_verdict"
echo "ci: $ci_verdict (sha ${HEAD_SHA:-unknown})"

exit "$overall"
