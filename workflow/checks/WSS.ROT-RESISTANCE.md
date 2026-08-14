# The rot-resistance checklist

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What it finds:
writing that is **true today and shaped to go false** — a second copy nothing
keeps in step, a file two procedures write, a claim no reader can test, a drift
nothing would report.

Its siblings find rot that has already happened —
[`WSS.RECORD-DRIFT.md`](WSS.RECORD-DRIFT.md) in the records,
[`WSS.TOOLING-CLAIMS.md`](WSS.TOOLING-CLAIMS.md) in the skill and contract files.
**A hit here is correct as written**, which is why neither of them reports it and
why the fix is structural rather than a correction. Left alone it becomes their
finding later, in a session with less context than this one.

Each lens is a question, what a hit looks like, the tree's own proven example,
and the drawback that must be outweighed — because the gate on every lens is the
same: **the structure has to be likelier to diverge than the fix is to cost, and
anything structural is proposed before it is touched.** A lens with no hit is a
result, not a failure to look hard enough. **The examples are in scope like
anything else here** — they name other files by path, and they go stale exactly
as the text they argue about does.

## The lenses

1. **One canonical statement.** Is this rule stated anywhere else in its own
   words? Two independent statements of one rule diverge on the first edit that
   reaches only one of them, and both keep reading as authoritative. The fix is
   one statement plus pointers. Proven: the record taxonomy lives in
   `WSS.RECORD-DRIFT.md` once rather than in whichever runner wrote it first. Drawback: a pointer costs a file open the copy did not,
   and a rule needed *at the moment of acting* may be worth restating — that is
   the copy-set case, and it needs lens 3 behind it.
   [`WSS.TOKEN-ECONOMY.md`](WSS.TOKEN-ECONOMY.md)'s redundancy lens finds the same
   shape on a cost gate; the two gates are independent, and a copy-set cheap
   enough to pass there can still fail here.

2. **One writer.** Does exactly one procedure write this file? Two writers each
   maintain the half they know about, and neither is wrong about it. Proven:
   [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s sole-writer column, and its
   inspector-writes-nothing rule, which routes a finding to the owner rather than
   letting the finder edit. Drawback: many writers is safe where they cannot
   contradict each other — an append-only queue is the sanctioned shape, not an
   exception to argue for a file that gets rewritten in place.

3. **A copy is generated or compared, never merely kept in step.** Where a second
   copy has to exist, what makes the two agree? "Whoever edits one remembers the
   other" is nothing. Proven: `wss-doctor.sh` compares the check-method table
   against the catalog's copy of it column for column, the two cadence tables on
   their flag column alone, and the flag grants as a derived commit/push
   signature; `skills/record/assets/wss-index-decisions.sh` generates rather
   than compares. Drawback: a comparison has to name what is free to differ —
   the cadence tables address different readers, so their wording is exempt, and
   the method table's href is exempt because the two files sit at different
   depths — and one that compares too much reports formatting as drift until
   someone silences it.

4. **Point, don't paraphrase.** Does this text summarise an authority it also
   links? The summary reads as current after the authority moves, and it is the
   one a hurried reader stops at. Link and stop, or restate **one line** marked
   as the override-the-instinct case. Proven:
   [`WSS.TOOLING-CLAIMS.md`](WSS.TOOLING-CLAIMS.md) links the mutable-claim rule
   and keeps exactly one line of it; `WSS.RECORD-DRIFT.md`'s tooling-claims
   dimension says "read it rather than a copy here". Drawback: the one-line form
   is a settled compromise for rules that must fire before another file is
   opened, not a licence to keep the paragraph.

5. **Write the form that cannot go false.** Is this a rule, or a state? Counts,
   inventories, "currently X", negative claims and incident citations are the
   catalogued shapes — the authority is the mutable-claim rule in
   [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md#the-mutable-claim-rule),
   and `WSS.TOOLING-CLAIMS.md` is where they are found and deleted. What this
   lens adds is the replacement: **prefer the predicate to the enumeration.**
   "Every file the manifest's `sources` globs reach" survives what "the skill
   files and the agent files" does not. Proven: `wss-doctor.sh` enumerates flags
   from the hook's own `FLAGS` array at runtime rather than from a list in prose.
   **And a cardinality lives with its items.** The predicate stops at the file
   boundary — nothing can quantify over another file's headings — so *"the four
   rules there"* counts a set its writer cannot see, and adding a fifth leaves
   every citing site wrong while breaking nothing: the anchor still resolves, and
   a rename is all the doctor's anchor check can see. Cite the section, not how
   many things are in it; where the number must be said it belongs in the file
   that holds them, and nowhere else. Proven by failure:
   [`WSS.SWEEP-CHECKPOINT.md`](../WSS.SWEEP-CHECKPOINT.md)'s four-rules heading,
   restated verbatim as a heading in
   [`WSS.AUDIT-COVERAGE.md`](../WSS.AUDIT-COVERAGE.md) and cited by number from
   files that cannot see the set it counts.
   Drawback: a predicate the reader cannot evaluate in their head hides the set —
   where seeing the set is the point, generate it, which is lens 3.

6. **Every claim carries its re-check.** Can a reader disprove this in one
   command? A claim with no path, grep or script beside it is not cheap enough to
   test, so nobody tests it, and it is still there three changes later. Proven:
   the disproving grep the record contract requires of every negative claim; this
   suite's own instruction to run `wss-doctor.sh` rather than believe an
   inventory written in a markdown file. Drawback: the command is itself a claim
   about the tooling and rots with it — cite the script that exists, not a
   pipeline invented for the paragraph.

7. **Name the detector, including when it is nobody.** When this goes false, what
   reports it — a doctor check, a CI step, a sweep entry, or a person who happens
   to look? "A careful reader" is nothing. Proven: `wss-doctor.sh` exists because
   failures cost real time and none of them had a symptom, which is stated in the
   script's own header. Drawback: a detector is a maintained thing and
   earns its place like anything else — so **"nothing detects this" is a
   legitimate outcome, and then it is written where the reader will be**, not
   filed somewhere tidier.

8. **Freshness is stamped, not remembered.** Can *when was this last verified* be
   answered without doing it again? A check whose last run is unknowable is
   re-run in full forever or skipped on vibes. Proven:
   [`WSS.SWEEP-CHECKPOINT.md`](../WSS.SWEEP-CHECKPOINT.md)'s freshness-only
   entries, which carry a date and license nothing. Drawback: that file's
   coverage rules are load-bearing — a stamp that overclaims coverage is worse
   than no stamp, because every later sweep inherits a clean report on files
   nothing read.

9. **Count the update fan-out.** Adding one thing of this kind forces an edit in
   how many files? Each one past the first is a place the next person forgets,
   and forgetting is silent. Proven: a new check method costs a row in
   `WSS.CHECKS.md` and a row in the catalog — and the doctor asserts they agree,
   which is what makes two acceptable. Drawback: driving the count to one by
   merging can destroy the reason the second copy exists — the catalog exists so
   a reader sees the whole tooling at a glance, and a row pointing elsewhere
   defeats it. A compared pair is the answer there, not a merge.

10. **Citations survive renames.** Does this reference something whose name can
    change without the break being visible? A heading cited by name, a flag named
    in prose, a skill named in another skill's body — all read exactly like live
    references after the target is gone. Proven: the doctor's cross-reference,
    section-citation, link-target and anchor checks, which exist for precisely
    that failure. Drawback: the rename stops at the live surface —
    [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md) forbids rewriting the
    logs, so a citation left correct-for-its-time in an append-only record is
    history, not a dangling reference, and repairing it is the error.

11. **Orphans — the reverse of a dangling reference.** Is anything here reached by
    nothing? A heading no file cites, a reference file no gate opens, a method no
    runner runs, a manifest key nothing reads. Nothing breaks, which is exactly
    why it survives and quietly stops being true. Drawback: reachability is
    measured from the intended entry point, not from this tree's own links — a
    flag the user types, or a contract an adopter reads, is reachable without any
    file pointing at it. And removing one is a behaviour change: report it,
    propose it, do not tidy it away.

12. **The write mode matches the content.** Is this history, or state? A log
    edited to stay current destroys the only copy of what was true; a state file
    that appends accumulates entries no reader can tell from the current one.
    Proven: [`WSS.RECORD-CONTRACT.md`](../WSS.RECORD-CONTRACT.md)'s two write
    modes, and why they do not share an owner. Drawback: the boundary is finer
    than the file — append-only constrains the entry's body, not its status
    field, and getting that backwards produces a log that cannot record an
    outcome.

13. **One project's facts stay in that project.** Does this file hold a fact
    maintained somewhere else — another project's finding in this project's
    records, or a single project's detail in a file every project loads? It rots
    because nobody who maintains that fact ever opens this file. Proven: the
    one-suite-many-projects rule, and the load-bearing-name exception recorded
    against it — a fact about *this* tree that is the needle a stated command is
    run with stays, or the instruction it serves becomes unactionable.

This list grows, and a lens added to it re-opens every file that was checked
under the shorter list — the same property `WSS.TOKEN-ECONOMY.md` has, and the
one that makes growth safe rather than retroactively dishonest. The independent
audit pass remains the only thing that finds the lens nobody has written down
yet.

## What a finding says

Two runs agree on what they found only if a finding is a fixed shape: **the lens,
the `file:line`, the edit that would make it diverge, what reports that (or
`nothing`), and the proposal.** One that cannot name the diverging edit is a
preference, and the gate above has already refused it.

**Order by silence, and grade nothing.** The ones nothing would report come
first, multi-site before single-site; the ones a named detector would catch come
last, however large they look. Grades past that ordering are a fresh judgment
call on every finding and lose to it — the same reason
[`WSS.LANE-CONTRACT.md`](../WSS.LANE-CONTRACT.md) allows one marker and no
ladder.

## What this method is not

Getting these wrong turns a design review into a demand for uniformity, and the
tree has ruled against several of them already.

- **Duplication that a recorded ruling sanctions is not a hit.** The ruling names
  the trigger that would reverse it; re-litigating it every sweep is the cost
  lens 1 was supposed to avoid. **Reading the trigger is not re-litigating it** —
  a ruling holds on premises that are claims about today, and one whose trigger
  has fired is a hit whose finding is the trigger, not the copies.
- **Duplication a runtime constraint makes irreducible is not a hit.** Where the
  reader is a machine that never opens the file — the router matching a
  `description:` before anything loads — a pointer cannot be followed, so one
  statement per flag is the shape rather than a copy-set. Name the constraint or
  it is an excuse; and irreducible is not unguarded, so lens 3 still asks what
  compares them.
- **A rule stated absolutely is not a mutable claim.** Deleting one because it
  reads as too confident is the failure mode of lens 5 specifically, and it
  removes behaviour.
- **History is not a hit under any lens.** An entry a later one reversed, a
  citation to a name that has since changed inside an append-only record, a dated
  measurement in the decision log — all correct as written.
- **A drawback stated and accepted is a result.** A lens whose fix was weighed and
  refused is answered; record the ruling and move on, or the next run pays for
  the same argument.

**Scope, disposition and authorization are the runner's** — see
[`WSS.CHECKS.md`](WSS.CHECKS.md). This file says only what counts as a finding.
