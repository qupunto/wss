# Triaging the defect inbox

**A method, not a skill** — see [`WSS.CHECKS.md`](WSS.CHECKS.md). What it finds:
which filed defects against this suite are real, which are stale, and which
never reproduced. **Whether the running session may triage at all is
authorization and stays with its runner**, per that file — as does where a
confirmed finding routes and who commits the close.

## What an entry is, and why it needs triage rather than reading

A defect in this suite's own skills, contracts or scripts, found by a session
working in **some other project** — which was forbidden to fix it and filed it
instead, per
[`WSS.OWNERSHIP.md`](../workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session).

That provenance is the whole reason this is a method rather than a read. **The
session that filed the entry is long cleared**, so nobody can be asked what they
meant; the entry is all there is, it was written against a tree that has since
moved, and its author could not verify the fix because they were not allowed to
make one. An entry is therefore a *claim awaiting verification*, never a work
item — and treating it as a work item is how a stale report gets re-fixed and a
live one gets closed.

## The inbox has two halves and they are reported separately

- **The machine-local file** — `WSS.BUG-REPORTS.md` in the configuration
  directory, holding what sessions on this machine filed.
- **Open issues on the suite's public repository.** Adopters cannot reach a
  machine-local inbox, so their filings arrive as issues; `--wss-report`'s own
  upstream path ends there too.

**A clean result on one half says nothing about the other**, and where the
public repository could not be reached, that half is reported **not checked** —
never as empty.

## Per entry

1. **Establish whether the tree moved under it.**
   `git log --oneline <the entry's Found: commit>..HEAD -- <the cited path>`,
   rather than by reading either end. Any output means the file changed since
   the entry was written, so the defect may already be gone. **This step
   establishes only that there was movement** — what the movement *means* is the
   next step's, and collapsing the two is how a coincidental edit gets read as a
   fix.
2. **Re-verify against the cited lines.** Read them
   ([`WSS.OWNERSHIP.md`](../workflow/WSS.OWNERSHIP.md#the-inspector-writes-nothing)).
   Where the claim is negative — "nothing does X" —
   [`WSS.RECORD-CONTRACT.md`](../workflow/WSS.RECORD-CONTRACT.md#negative-claims) applies,
   and the grep that would disprove it is what settles it.
3. **Classify.** An entry is *confirmed* (reproduces now), *stale* (the cited
   defect is gone), or *did not reproduce* (it was never true). These are
   different outcomes with different consequences, and merging the last two
   loses the only calibration signal the inbox produces.

**Re-reporting a closed finding is the failure mode to watch for**, because it
masks a live instance of the same class one file away — the reader sees a name
they recognise and stops.

## What closing requires

Criteria only; the act belongs to the runner.

- **A confirmed entry closes when the fix lands** — and for the upstream half,
  **only once the fix is *published***. An issue closed against an unpublished
  commit reads as fixed to an adopter whose install does not carry it, which is
  worse than leaving it open.
- **An entry that did not reproduce is removed, and what it claimed is stated
  where the removal is recorded.** A wrong report is calibration; dropping it
  silently teaches nobody anything, and the next session files it again.

## An empty inbox is a result

"Nothing was filed" and "I did not look" are different sentences, and only one
of them is ever implied by silence. Report which, per half.
