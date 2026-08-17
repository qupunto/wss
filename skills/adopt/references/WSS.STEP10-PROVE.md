# Step 10 — Prove it, do not claim it

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/tests/wss-doctor.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
"$S"/wss/tests/wss-doctor.sh
```

Run it and show the output.

**If it fails, fix and re-run.** Adoption is not finished on a failing doctor:
every later skill trusts the manifest without re-verifying it. A failure in the
manifest itself goes back to `manifest-writer` — this skill does not correct that
file directly, however obviously right the one-line fix looks.

**On a passing doctor, stamp the tree** — through `manifest-writer`, never by
hand: `WSS.suite` takes the installed suite's version
(`.claude-plugin/plugin.json`) and its commit, resolved from the install root's
git tree. A fresh adoption is current by construction, and the stamp is what
lets a later `update` start from here instead of from detection alone.
Where no commit is resolvable, leave the stamp unwritten and say so — a guessed
commit is worse than no stamp (`wss/workflow/WSS.MANIFEST.md`'s `WSS.suite` row).

**Then measure it.** Run `bash wss/scripts/wss-tools-inventory.sh`, resolved the same way as
the doctor above, so `.claude/WSS.TOOLS.json` — `WSS.record.tooling.inventory` —
exists from the moment adoption ends, rather than leaving its first measurement
to whoever happens to run `--wss-tidy` or `--wss-catalog` next. It runs last, for
the same reason the stamp does: a derived artifact is only worth writing once
the tree it derives from has already been proven sound.

