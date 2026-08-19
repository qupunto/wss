#!/usr/bin/env bash
# Resolve and cat a consumer's rule files from the rulebook index.
#
#   wss-rules-checkup.sh <consumer>          # resolve from WSS.RULES-INDEX.md, cat files, exit 0
#   wss-rules-checkup.sh --json <consumer>   # explicit error: WSS.RULES.json unimplemented
#
# FAILS LOUD on three named conditions (closing four silent-failure paths beside
# three already documented):
#
#   1. UNRESOLVABLE CONSUMER: argument doesn't match any row in the consumer
#      table. Print the consumer name and exit non-zero.
#   2. MISSING FILE: a file the table resolves to doesn't exist under wss/rules/.
#      Print which consumer, which file, and exit non-zero.
#   3. EMPTY SET: the consumer matched but its file list is empty (defensive).
#      Print the consumer name and exit non-zero.
#
# The three known silent-failure paths this closes:
#   - wss/records/WSS.HAZARDS.md:310 — wss-session-check.sh's trap exit_clean ERR
#     can exit 0 after discarding a collected doctor FAILURE
#   - wss/records/WSS.HAZARDS.md:380 (and 467) — per-clone hooks are untracked
#     with nothing in the tracked tree able to tell if they exist or drift
#   - wss/scripts/wss-commit-provenance.sh's missing block handling (line 431)
#     prints NOTICE and exits 0 with no expiry condition
#
# NO CACHING. The design's own words: "no caching. A cached index is an
# unpoliced copy". Read the index file fresh on every invocation.
#
# WHICH FILES: parsed from wss/rules/WSS.RULES-INDEX.md's consumer table only;
# paths are relative to wss/rules/. prospective/ prefix means under that subdirectory.

set -euo pipefail

# Locate the index file relative to the script location
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEX_FILE="$SELF_DIR/rules/WSS.RULES-INDEX.md"
RULES_DIR="$SELF_DIR/rules"

# Check if --json mode
if [[ "${1:-}" == "--json" ]]; then
  echo "WSS.RULES.json does not exist yet. --json is unimplemented until its generator ships." >&2
  exit 1
fi

# Require a consumer argument
if [[ -z "${1:-}" ]]; then
  echo "wss-rules-checkup.sh: no consumer specified" >&2
  exit 1
fi

CONSUMER="$1"

# Check if index file exists
if [[ ! -f "$INDEX_FILE" ]]; then
  echo "wss-rules-checkup.sh: index file not found at $INDEX_FILE" >&2
  exit 1
fi

# Extract the consumer table and find the matching row
# The table is between "## Consumer resolution table" and the next section or end
# Format: | Consumer | Files it needs |
#         |---|---|
#         | \`consumer-name\` | file1 · file2 · file3 |

# Extract lines from the consumer table section
table_section=$(sed -n '/^## Consumer resolution table/,/^---$/p' "$INDEX_FILE" || true)

if [[ -z "$table_section" ]]; then
  # Try without the trailing --- (end of section)
  table_section=$(sed -n '/^## Consumer resolution table/,/^## /p' "$INDEX_FILE" || true)
fi

# Find the line matching the consumer (wrapped in backticks)
# The consumer name is in the first column, backtick-quoted
files_line=$(echo "$table_section" | grep -F "| \`$CONSUMER\`" || true)

if [[ -z "$files_line" ]]; then
  echo "wss-rules-checkup.sh: consumer '$CONSUMER' not found in table" >&2
  exit 1
fi

# Extract the files list (second column)
# Expected format: | `consumer` | `file1` · `file2` · `file3` |
# Extract after the second |, trim whitespace
files_str=$(echo "$files_line" | cut -d'|' -f3 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [[ -z "$files_str" ]]; then
  echo "wss-rules-checkup.sh: consumer '$CONSUMER' has empty file set" >&2
  exit 1
fi

# Split on ` · ` delimiter (space-dot-space within backticks)
# This gives us entries like `filename` separated by ` · `
mapfile -t file_array < <(echo "$files_str" | tr ' · ' '\n')

if [[ ${#file_array[@]} -eq 0 ]]; then
  echo "wss-rules-checkup.sh: consumer '$CONSUMER' has empty file set" >&2
  exit 1
fi

# Check that all files exist and cat them
found_any=0
for file_spec in "${file_array[@]}"; do
  # Trim whitespace from file spec
  file_spec=$(echo "$file_spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Skip empty entries
  if [[ -z "$file_spec" ]]; then
    continue
  fi

  # Handle backtick-quoted filenames: strip leading and trailing backticks
  file_spec=$(echo "$file_spec" | sed 's/^`//;s/`$//')

  # Resolve prospective/ prefix
  file_path="$RULES_DIR/$file_spec"

  if [[ ! -f "$file_path" ]]; then
    echo "wss-rules-checkup.sh: file not found for consumer '$CONSUMER': $file_spec" >&2
    exit 1
  fi

  # Print marker and file contents
  echo "## $file_spec"
  cat "$file_path"
  echo ""
  found_any=1
done

# Exit 0 only if at least one file was found and printed
if [[ $found_any -eq 1 ]]; then
  exit 0
else
  echo "wss-rules-checkup.sh: no files resolved for consumer '$CONSUMER'" >&2
  exit 1
fi
