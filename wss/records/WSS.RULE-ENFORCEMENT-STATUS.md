# Rule-enforcement status — the ruling system's five rules

Standing statement of why three of the ruling system's five rules have no
mechanical check, not a queue of work. Update in place as a rule's status
changes; do not read an unchecked rule here as a pending task.

`--wss-todo` (`record`) is the sole writer. `.claude/WSS.LOCAL-RECORDS.json`
declares this file as `WSS.record.ruleEnforcementStatus` — a project-local key,
since no other adopting project would read it (`WSS.MANIFEST.md`'s "Not
manifest keys"). Reasoning belongs in the decision log
(`wss/logs/WSS.DECISIONS.md`), never here.

**Promoted out of `wss/records/WSS.TODO.md` on 2026-08-18**, where it had sat
as a `- [ ] ` entry (Cycle 8) despite self-labelling as a standing statement —
a Class 4 misfile (belongs in a standing register, never joined one) caught by
that session's Phase 0 duplicate-read-back survey. The disposition (promote,
don't leave in place) was the owner's ruling on 2026-08-17; this file, its
manifest key and this ownership row are what executes it. See the decision
log's 2026-08-17 (twenty-fourth) and 2026-08-18 entries.

---

The handoff's `!important` list was right that all five were unenforced.
Verified at `HEAD` on 2026-08-15, each with the grep that would have
disproved it; rule 3 was built the same day, **rule 2 was retired as
obsolete at the 2026-08-15 gate**, and the other three stand.
**This entry is now a standing statement of why three rules have no
check**, not a queue of work — do not read it as three pending items. What
would move any of them is named in its own paragraph: a lane-declaring
tree for rule 4, an explicit id field in both records for rule 5, and a
commit-level rather than tree-level home for rule 1.
**Rule 1, one writer per record.** Holds. `wss-doctor.sh`'s "Sole writers"
section validates the ownership matrix's *internal* consistency only —
that no two rows claim one record. A commit-level check cannot live in a
tree checker, which has no baseline to diff against; it belongs in
`wss-append-only.sh`, which already sees the staged set. **The trap:** a
record may span several files (the handoff and `WSS.HAZARDS.md` are one
record) and a file may hold several records, so changed-path-to-writer is
not a 1:1 map and a naive check fires on the handoff every time.
**Rule 2, never write a model name — RETIRED as obsolete at the
2026-08-15 gate, and no longer part of this entry's remaining work.** The
gate asked for the scope ruling this paragraph used to demand. The owner
reversed the question instead: the rule existed so that a model change
would not mean editing every skill that dispatches, and resolving the
model through the ladder achieves that, so banning the name is ineffective
against the problem it was for.
**The LADDER decides, and an agent never chooses its own model** —
`wss/workflow/WSS.DISPATCH-LADDER.md`'s assignment table is the canon, each
`agents/*.md` `model:` is a marked derived copy of its row, and
`wss-doctor.sh` fails either direction of drift. Locate the check with
`grep -n 'Agent model assignments' wss-doctor.sh`.
**The first recording of this ruling was wider than the ruling** — it said
the model was the agent's own — and the correction reached five files. Read
the decision log's 2026-08-15 (tenth) entry, not the (ninth) alone; the
ninth stands unrewritten and carries the overreach.
**What is NOT retired and must not be swept up with it:**
`wss/workflow/writers/WSS.GIT-WRITER.md`'s ban on a hardcoded model in the
commit trailer. That governs a value the tooling emits rather than a
routing rule, it is still correct, and it was left standing deliberately.
See the decision log's 2026-08-15 (ninth) and (tenth) entries.
**Rule 3, `WSS.docs.root` must resolve to the real docs directory — BUILT
2026-08-15 and no longer part of this entry's remaining work.** The doctor
now fails a root that resolves to a real directory holding no `*.md` at
any depth, at the same tier as a root that is not a directory at all;
locate it with `grep -n 'WSS.docs.root' wss-doctor.sh`. `_sidebar.md` was
deliberately NOT required — it is docsify-specific and would fail a valid
site built any other way. **The residual the entry named survives the
build and is the reason this paragraph stays:** if the site generator's
expected structure changes, the check passes silently on a directory that
still holds markdown but is no longer what the generator reads. Also
unenforced, and out of scope by ruling rather than oversight: the whole
`WSS.docs` block is gated on the key being declared, so a
fallback-resolved root gets no check at all. Widening that gate changes
behaviour for every project declaring nothing, this one included.
**Rule 4, no lane-foreign files on a lane branch.** Unchanged and not
buildable here — this repo declares no lanes.
**Rule 5, no entry in both open-decisions and the decision log.** Holds,
and is **not mechanically expressible as the records stand.** The only
field the two files share is the heading text, which is reworded when an
entry is settled and moved, so a comparison yields false negatives on
every properly-settled entry and false positives on any two choices phrased
alike. Closing it needs an explicit id field in both files — a schema
change reaching every adopting project — or it stays a convention. Do not
build a heading comparison: it would report cleanly on exactly the entries
that were handled correctly.
**RULE 1 WAS BUILT 2026-08-16 and is no longer part of this entry's
remaining work — the paragraph above about it not being mechanically
expressible is superseded twice over.** `wss/scripts/wss-commit-provenance.sh`
emits a delimited block from `prepare-commit-msg` and asserts it from
`commit-msg`; the author writes freely before and after, and only the
interior is fixed, which is what defeats the trailer objection that a
reflowed line makes a hand commit a violation. It also took over the
sole-writer matrix parser the doctor held inline, so the two cannot drift.
**Two scope limits survive the build and are the reason this paragraph
stays.** In scope means declared AND claimed, so a path reaching the
manifest under a non-record key is silent BY DECLARATION rather than by
exemption — `wss/records/WSS.HAZARDS.md` (only under `WSS.hazards`) and
`WSS.record.decisionsIndex` (named in matrix prose, never as a key) are
both invisible to it. Closing either needs a manifest change, not a code
change. And the authority line is self-declared, so it catches a mistake
and never misconduct — which is the point, not a shortfall.
**`WSS_WRITER` is wired, on the owner's ruling of 2026-08-16.**
`wss-git-commit.sh --writer` exports it scoped to the commit. An absent or
`UNDECLARED` authority is a notice at rc 0 so untaught commit paths keep
working; a MISMATCH fails, and that is the wrong-skill catch, live.
**Rules 4 and 5 are unchanged and remain standing statements**, not queued
work. See the decision log's 2026-08-15 (third), (ninth) and (fourteenth)
entries.
