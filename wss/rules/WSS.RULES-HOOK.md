# HOOK judge — held rules

Rules held by `wss/tests/wss-hook-contract.sh`: a check exists today and can detect a breach.

**This judge also covers the harness tool layer** — rules enforced by a
`PreToolUse` deny hook or by a `settings.json` permission rule, carrying the
`pretooluse-hook` and `permission-rule` mechanisms. They file here rather than
under a judge of their own: a separate TOOL judge would cost two files and a
roster, and splitting one out later costs nothing if this venue's rows outgrow
the file.

A row moves here from `prospective/WSS.RULES-HOOK.md` when its check is built.

**Source:** wss/logs/WSS.DECISIONS.md's `2026-08-17 (eighth)` entry.
