# Step 8b — An archive from another machine imports here, before any record is created

Reached from step 1's y/N question, or whenever the user hands an archive over
unprompted — the machine change is the scenario. Run the import the moment the
archive is named, and in every case **before** step 9, so restored records
count as existing and step 9 seeds only what is genuinely absent:

```bash
S="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -x "$S/wss/scripts/wss-export-records.sh" ] || S=$(ls -d "$S"/plugins/cache/*/wss/*/ 2>/dev/null | tail -1)
"$S"/wss/scripts/wss-export-records.sh --import <archive>
```

The order is load-bearing, not stylistic: import refuses to overwrite any
non-empty file, and a record step 9 has already seeded carries its heading —
so the other order refuses the very files the archive exists to restore. A
refusal therefore means this machine has real content the archive would
replace: show both sides and let the user choose `--force`, never choose it
for them.

