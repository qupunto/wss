# Step 8 — Hand the manifest to `manifest-writer`

Steps 2 through 7 settled *what the values are*. Writing them is
[`manifest-writer`](../../../wss/workflow/writers/WSS.MANIFEST-WRITER.md)'s, which validates each key
against [`WSS.MANIFEST.md`](../../../wss/workflow/WSS.MANIFEST.md), writes, and runs the doctor.

Hand it only keys with real, verified values. A key whose file you are about to
create in step 9 is fine; a key pointing at something aspirational is not, and
`manifest-writer` will refuse it rather than write it.

**Every record handed over carries its write mode.** `WSS.recordMode` is a
sibling of `WSS.record`, one entry per declared record, and the mode comes from
[`WSS.RECORD-CONTRACT.md`](../../../wss/workflow/WSS.RECORD-CONTRACT.md#two-write-modes-every-record-is-a-log-or-a-register)'s
table by record key name — look each key up there rather than classifying from
what the record sounds like. Build the map in the same pass as the record keys,
from that same list, so the two cannot disagree: `WSS.record.tooling` contributes
`tooling.catalog` and `tooling.inventory`, and never `tooling.sources`, which is
a glob list rather than a record.

**Complete or absent — a partial map is worse than none.** An absent map inherits
the contract's table and `wss-doctor.sh` only warns; a map naming some declared
records and not others **fails**, because the ones it names are enforced and the
omitted one is silently exempt. So a record whose mode the table does not settle
does not get skipped over — it stops the map, and adoption hands over no
`recordMode` at all and says which key was unresolvable. `manifest-writer`
refuses a partial map either way.

**Amendment mode reaches this step directly.** Adding or correcting one key in an
existing manifest needs no detection, no search and no questions — steps 2
through 7 are an adoption's work, not an amendment's. **One coupling survives
that shortcut:** an amendment adding a `WSS.record.*` key to a manifest that
already declares `WSS.recordMode` adds that record's mode in the same write, or
it turns a passing doctor into a failing one — and the failure names the record,
not the amendment that caused it.

