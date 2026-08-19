# APPEND judge — held rules

Rules held by `wss/scripts/wss-append-only.sh`: a check exists today and can detect a breach.

A row moves here from `prospective/WSS.RULES-APPEND.md` when its check is built.

### REC-APPEND-001
**statement:** Never delete a line from, or insert a line into, the body of an entry in a record that `WSS.recordMode` tags `log`.

**kind:** prohibition

**tier:** global

**custody:** APPEND · held

**mechanism:** git-hook

**consequence:** refuse

**evidence:** wss/scripts/wss-append-only.sh:466

### REC-APPEND-002
**statement:** Never delete a line from, or insert a line into, the body of an entry in a record that `WSS.recordMode` tags `log`.

**kind:** prohibition

**tier:** global

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** fail

**evidence:** wss/scripts/wss-append-only.sh:466

### REC-APPEND-003
**statement:** Never reduce the number of entries in a log record.

**kind:** prohibition

**tier:** scoped

**custody:** APPEND · held

**mechanism:** git-hook

**consequence:** refuse

**evidence:** wss/scripts/wss-append-only.sh:519

### REC-APPEND-004
**statement:** Never reduce the number of entries in a log record.

**kind:** prohibition

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** fail

**evidence:** wss/scripts/wss-append-only.sh:519

### REC-APPEND-005
**statement:** Never delete a file that `WSS.recordMode` tags `log`.

**kind:** prohibition

**tier:** scoped

**custody:** APPEND · held

**mechanism:** git-hook

**consequence:** refuse

**evidence:** wss/scripts/wss-append-only.sh:290

### REC-APPEND-006
**statement:** Never delete a file that `WSS.recordMode` tags `log`.

**kind:** prohibition

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** fail

**evidence:** wss/scripts/wss-append-only.sh:290

### REC-APPEND-007
**statement:** Every key `WSS.recordMode` tags `log` must resolve to a path under `WSS.record`.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** git-hook

**consequence:** refuse

**evidence:** wss/scripts/wss-append-only.sh:168

### REC-APPEND-008
**statement:** Every key `WSS.recordMode` tags `log` must resolve to a path under `WSS.record`.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** fail

**evidence:** wss/scripts/wss-append-only.sh:168

### REC-APPEND-009
**statement:** Never report a clean append-only run over an empty set of log records.

**kind:** prohibition

**tier:** scoped

**custody:** APPEND · held

**mechanism:** git-hook

**consequence:** refuse

**evidence:** wss/scripts/wss-append-only.sh:189

### REC-APPEND-010
**statement:** Never report a clean append-only run over an empty set of log records.

**kind:** prohibition

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** fail

**evidence:** wss/scripts/wss-append-only.sh:189

### REC-APPEND-011
**statement:** Never treat a diff base or range that cannot be resolved as a passing append-only run.

**kind:** prohibition

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** fail

**evidence:** wss/scripts/wss-append-only.sh:211

### REC-APPEND-012
**statement:** A log record's declared shape must use a legal value for each of growth direction, entry form and mutable status field.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** script-internal

**consequence:** refuse

**evidence:** wss/scripts/wss-append-only.sh:176

### REC-APPEND-013
**statement:** A log record's declared shape must use a legal value for each of growth direction, entry form and mutable status field.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** script-internal

**consequence:** fail

**evidence:** wss/scripts/wss-append-only.sh:176

### REC-APPEND-014
**statement:** Treat every line above a log record's first entry as the record's instructions rather than as one of its entries.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** silent

**evidence:** wss/scripts/wss-append-only.sh:407

### REC-APPEND-015
**statement:** Treat an `Outcome:` field line and the unbroken block beneath it as a statement about now rather than a claim about the past.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** silent

**evidence:** wss/scripts/wss-append-only.sh:409

### REC-APPEND-016
**statement:** Treat the entry at the end a log record grows at as a draft still being written.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** silent

**evidence:** wss/scripts/wss-append-only.sh:436

### REC-APPEND-017
**statement:** Treat a replaced line whose basename and every other character are unchanged as a pointer kept correct rather than as a rewritten body.

**kind:** requirement

**tier:** scoped

**custody:** APPEND · held

**mechanism:** ci-step

**consequence:** silent

**evidence:** wss/scripts/wss-append-only.sh:464

**Source:** wss/logs/WSS.DECISIONS.md's `2026-08-17 (eighth)` entry.
