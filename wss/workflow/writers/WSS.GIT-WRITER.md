# Writing the git history

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md), whose [read-inheritance rule](WSS.WRITERS.md#read-inheritance) this follows. Sole writer of commits and tags, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.branch.integration` is
what ordinary work goes to, `WSS.branch.publish` is what `--wss-release` tags, and
`WSS.commitTrailer` names the session trailer. Without a manifest, fall back to the
current branch and say so in one line.

**A backtick in `--message` is substituted by the CALLER's shell, not by this
procedure, and what it eats is gone before the script sees it.** A message
written inside double quotes with `` `contract` `` in it arrives with the word
missing and the commit lands looking fine — the substitution happens at the call
site, so nothing downstream can detect the loss. Quote such a message with
single quotes, or escape every backtick. It has happened: one commit explaining
a classification decision lost the name of the class, and the decision log's
`2026-08-19 (nineteenth)` entry carries the instance.

**The mechanism is [`assets/wss-git-commit.sh`](assets/wss-git-commit.sh).** It
stages by exact name, assembles and verifies the trailer paragraph, and refuses a
force-push refspec — structurally, not by a caller remembering to. What follows is
what that script cannot decide for itself: whose grant this is, when to use it, and
what this procedure will not do regardless.

**`--push-only REFSPEC` is the second, narrower shape the script accepts**: push
without staging or committing anything. This is the normal case after
`--wss-start`, which commits each lane as it lands — a wrap that follows one can
have nothing left to stage and still owe a push, and the commit-then-push form has
no route through that has nothing to commit (`--files` is required precisely so
nothing can reach for `-A`, and that requirement is not what gets relaxed here).
It carries the same leading-`+` refusal and rejected-push handling as `--push`,
and no other flag — mixing it with `--files`/`--message`/`--session`/`--coauthor`/
`--trailer-key`/`--push` is a usage error.

**Push-only verifies no trailer**, deliberately. The commit-then-push form
verifies the trailer it just wrote because that is the one commit this
invocation could have gotten wrong; push-only writes no commit, so there is
nothing of its own to check. Every commit already on the branch was verified
the same way when *it* was made — this script is the sole path to a commit in
this repo, so nothing reaches `HEAD` without having passed the same
`%(trailers:...)` check once — and re-checking `HEAD` here would only
re-verify the tip of whatever range is being pushed (and misfire on a `HEAD`
that is a merge or tag commit with no trailer of its own), not the range
itself. Push-only trusts commits it did not make because each was checked
when it was made, not because checking is skipped on principle.

**No flag of its own**, on the same reasoning as `handoff-writer` and
`sweep-tracker` — and one reason particular to this procedure: a flag is how a user
confers authorization, and this procedure must never confer any. The grant is always
the caller's.

## `terse-messages`: the body shrinks, the record does not

**Check `→WSS.script.wss-toggle.sh --on terse-messages` before composing a commit
body.** While it is on, the body is the subject line and at most a sentence — or
the user's own wording, verbatim, where they supplied any. No narrative, no
rehearsal of the reasoning.

**What makes that safe is the decision log, and nothing else.** This file's
ordinary rule is that a commit message carries *the why*; terse trades that away
deliberately, and it is only affordable because `WSS.record.decisions` already
holds the reasoning and outlives the message. **A project without that record
should not turn this on** — there the commit message is the only place the why
would live.

**It does not touch the trailers.** Those are assembled by the mechanism rather
than composed as prose, and whether `Co-Authored-By` names anyone is
`provenance-off`'s question, not this one. The two toggles meet at that line and
nowhere else.

**It does not license an inaccurate message.** A short message that is wrong is
not terse, it is false; the shape changes and the standard does not.

**Absent means off**, so nothing here fires in a project that has not declared it.

## Why the history has an owner at all

The rules below live here rather than in each caller's file, so that a flag
granting COMMIT grants it to one disciplined writer instead of to whatever the
moment suggested — [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md) is the authority on
which flags grant what.

## The grant is the caller's, always

**Read the grant out of the matrix in
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)**, "Authorization the flag grants" — and never
restate it as a table here. WSS.RECORD-CONTRACT.md's "A concept is stated once"
rule treats a hand-copy of the grant as an ordinary duplicate to eliminate, not
a pair to keep in step by comparison — a table here would be exactly that copy,
restating what the matrix already owns.

Two grants the matrix's row does not spell out, because they belong to the step
rather than to the flag: under `--wss-pr` **the merge** needs a fresh OK of
its own, not just the push; under `--wss-release` so does **the tag**. In both cases
the caller has already obtained it — you are not the one to ask.

**The matrix lists flags, not callers.** A skill reached by dispatch carries the
grant of the flag the *user* typed, however many hops away — a `--wss-docs` invoked
by `--wss-catalog` arrives with `--wss-catalog`'s commit-and-not-push, not with `--wss-docs`'
nothing. Trace back to the flag; do not read an absent row as a refusal.

**A subagent inherits no commit grant, whatever its orchestrator holds.** A
dispatched skill runs in the caller's own context, so the trace back to the
user's flag survives it; a subagent is a different shape — it holds no flag, its
context is discarded on return, and it runs concurrently with its siblings — so
the trace stops at that boundary. **What it inherits is read and write on the
file set its brief declares, and nothing beyond.** Committing is reserved to the
context that can see the whole partition, the only one that knows which files are
which shard's: `--wss-start`'s Phase 5 already commits each shard separately
through this procedure.

**The rule holds when the brief is silent, which is the case it is written for.**
A grant is conferred, never assumed, so a brief that forgot to forbid committing
has not authorized it (`wss/logs/WSS.DECISIONS.md`, "The lane's untrailered commit
stands", for the case that established it).
**Whose session trailer a subagent writes therefore does not arise** — the
trailer distinguishes concurrent sessions, and a subagent is not one.

The cost was weighed and accepted: a lane's work stays uncommitted, and so
exposed to a sibling's mistake, until its orchestrator commits. Do not restore
that protection with an exception here.

If you cannot tell which grant is in force, you are not authorized. Ask.

**Never push under an inherited commit-only grant**, however obvious the push
looks. That distinction is the whole reason the grants are tiered rather than one.

## Commits

**A commit that writes a record carries `--writer`, naming the authority the write
is made under**, verbatim as the ownership matrix spells it. The value is **the
caller's**, never assumed by this procedure — the same rule as the grant itself.
A commit touching no record needs none.

**Coherent commits, not one dump.** Group the working tree the way the work
actually divided, with real messages saying *why*. A single "wrap up session"
commit destroys the only cheap explanation the next reader will ever get.

**The session id and the `Co-Authored-By` line are arguments to the script, never
literals written here or in a caller.** Take the `Co-Authored-By` line the harness
supplies for the running session — a model name hardcoded anywhere in this suite
is wrong the moment the model changes, and wrong in a way nothing detects.

**Be honest about verification.** State whether `WSS.commands.test` and
`WSS.commands.typecheck` actually ran against what is being committed. If they did
not, say so rather than implying green.

**Interrupted work still gets committed** when the caller asks for it — but say
so in the commit message. Never describe unverified work as done.

## Pushes

**Check whose work you are about to publish.** `git push` publishes a *ref*, not
a selection of commits: if another session's commit is an ancestor of yours,
pushing yours publishes theirs too, and cherry-picking cannot avoid it.

```bash
git log origin/<branch>..<branch>
```

Say plainly if it contains commits this session did not make — they have not
been reviewed here. The real fix is one worktree per session, which removes the
shared branch entirely; on a shared checkout, honest reporting is all there is.

**Is the other session still running?** Two signals, in this order:

1. `pgrep -x claude | wc -l` — how many sessions exist at all. **`1` means you
   are alone and no further check is needed.**
2. If more than one, read each foreign commit's `Claude-Session` trailer and
   check that session's transcript:
   `~/.claude/projects/<sanitized-cwd>/<session-id>.jsonl`. A recent mtime means
   live; minutes stale means finished.

A PID cannot be mapped back to a session id — the process environment does not
carry it — which is exactly why the trailer exists.

**Never force-push, and never rewrite a commit this session did not make.** The
flag hook blocks that reach this procedure (`--wss-wrap`, `--wss-release`)
already state why — a rejection usually means another session
pushed first, and that is a merge decision for the caller, not something to
resolve here — so this file does not restate the reasoning as a second copy. The
script enforces the refspec shape; obtaining the caller's OK before overriding
either rule is this procedure's own decision to hold to.

## Tags

Only `--wss-release` calls for one, and only after it has shown the user the commits,
the tag name and the branch and received an explicit OK **in that turn**.

```bash
git tag -a vX.Y.Z -m "<milestone name>"
git push origin <branch>
git push origin vX.Y.Z
```

**This procedure never asks for that confirmation and never proceeds without it.** A
primitive has no channel to ask — the same reason `WSS.agents.release` prepares the
material and never publishes it. If the caller has not said the OK was given in
that turn, stop and hand back.

A tag is the one thing here that cannot be undone: once another checkout has
fetched it, deleting it locally changes nothing.

## What this procedure does not do

- **It does not decide to commit or push.** No judgement about whether the work
  is ready, whether the milestone is done, or whether now is the moment.
**`--refs` is optional and is a transcription, never a lookup.** Where the
caller already knows what the commit is work on — the cycle heading a shard is
working from, a tracker id — pass it and it lands as a `Refs:` footer. **Do not
go and find one.** The field exists so a later check can derive which commits
closed which cycle without anyone keeping a second list of them; a value
guessed at commit time would be exactly the drifting copy that design rejected.
Absent is a correct answer and writes no footer.

- **It does not write any record file.** Not the changelog, not the roadmap,
  not the handoff — those have their own owners, and a commit is not a licence
  to adjust what is in it.
- **It does not rebase, revert or branch.** Those are decisions with a user in
  the loop, and none of them is history this workflow authors. **The one merge
  it does perform** is the one `--wss-pr` hands it, with the method from
  `WSS.branch.mergeMethod` and only once `pr` has the user's OK in that turn —
  [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s `merge` row is the authority,
  and it is the reason a merge commit has an owner at all. **That merge is run
  by hand under this procedure, not through `wss-git-commit.sh`** — the asset
  script commits and pushes and has no merge path at all, so reading "it does
  perform" as "the script does it" finds nothing and concludes the claim is
  dead. The authority is the procedure; the script is one of its instruments.

  **A lane landing on `WSS.branch.integration` is the second thing that looks like a
  merge and is not one.** `--wss-wrap` hands it a push refspec with **no leading
  `+`**, so it resolves as a fast-forward or is refused by the remote — the
  script refuses a leading `+` outright, but **this file is the authority on the
  rule itself**; the lane procedure (`skills/wrap/references/WSS.LANES.md`)
  and the `--wss-wrap` hook block carry working copies that lose any disagreement.
  No working tree is touched, no merge commit is written, `WSS.branch.mergeMethod`
  has nothing to choose, and there is no partial state to unwind. **A refusal is
  handed back, never forced and never resolved here**, which is the ordinary
  rejected-push rule and not a special case: the divergence it reports is a
  merge decision, and the caller is a session that is about to be cleared.

  **The same landing has a main-checkout twin**, handed by
  `/wss:lane-record-sync`'s step 0: `git merge --ff-only <lane-branch>` with
  `WSS.branch.integration` checked out, one lane at a time, fetch first where the
  lanes ride a remote. Local instead of remote, otherwise identical — it moves
  the ref onto commits that already exist, writes no merge commit, pushes
  nothing, and **a branch that cannot fast-forward is refused and handed back**,
  never resolved with a real merge here whatever `WSS.branch.mergeMethod` says.
- **It does not clean the tree.** No `git stash`, no `git checkout --` over
  someone's changes, no deleting untracked files.
