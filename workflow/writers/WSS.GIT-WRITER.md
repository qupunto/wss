# Writing the git history

> **A procedure, not a skill** — see [`WSS.WRITERS.md`](WSS.WRITERS.md). Sole writer of commits and tags, per [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

**Sole writer of commits and tags.** Every skill in this workflow that needs
either calls this one; who owns what is
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md).

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.branch.integration` is
what ordinary work goes to, `WSS.branch.publish` is what `--wss-release` tags, and
`WSS.commitTrailer` names the session trailer. Without a manifest, fall back to the
current branch and say so in one line.

**No flag of its own**, on the same reasoning as `handoff-writer` and
`sweep-tracker` — and one reason particular to this procedure: a flag is how a user
confers authorization, and this procedure must never confer any. The grant is always
the caller's.

## Why the history has an owner at all

The history is a record, and this workflow's invariant is that every record has
exactly one writer — [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md) is the
authority on that and on which flags grant what. The rules below live here rather
than in each caller's file so that a flag granting COMMIT grants it to one
disciplined writer instead of to whatever the moment suggested.

Every rule here exists because breaking it is **silent**. A trailer in the wrong
paragraph makes the liveness check find nothing. A `git add -A` publishes
whatever else was in the tree. A push carries another session's unreviewed
commits along with yours, and reports success.

## The grant is the caller's, always

**Read the grant out of the matrix in
[`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)**, "Authorization the flag grants" — and never
restate it as a table here. `wss-doctor.sh` compares exactly two copies of the
grants, the matrix and the block `wss-shorthand-flags.sh` injects; any third copy
is compared against nothing and drifts silently while reading as authoritative.

Two grants the matrix's row does not spell out, because they belong to the step
rather than to the flag: under `--wss-pr` **the merge** needs a fresh OK of
its own, not just the push; under `--wss-release` so does **the tag**. In both cases
the caller has already obtained it — you are not the one to ask.

**The matrix lists flags, not callers.** A skill reached by dispatch carries the
grant of the flag the *user* typed, however many hops away — a `--wss-docs` invoked
by `--wss-tools` arrives with `--wss-tools`' commit-and-not-push, not with `--wss-docs`'
nothing. Trace back to the flag; do not read an absent row as a refusal.

If you cannot tell which grant is in force, you are not authorized. Ask.

**Never push under an inherited commit-only grant**, however obvious the push
looks. That distinction is the whole reason three grants exist rather than one.

## Commits

**Coherent commits, not one dump.** Group the working tree the way the work
actually divided, with real messages saying *why*. A single "wrap up session"
commit destroys the only cheap explanation the next reader will ever get.

**Stage files by name. Never `git add -A`.** The tree may hold another session's
work, a scratch file, or a record this caller does not own.

**Stamp every commit with the session that made it**, using the trailer the
manifest names in `WSS.commitTrailer` and the first block of the session id, always
available in the scratchpad path. Without it, commits from concurrent sessions
are indistinguishable — same author, same branch, interleaved by time.

It must sit in the **same final block** as `Co-Authored-By`, with no blank line
between them:

```
Claude-Session: 9a933d25
Co-Authored-By: <the attribution line this session was given>
```

Do not copy a model name out of this file — take the `Co-Authored-By` line the
harness supplies for the running session. A name written down here is wrong the
moment the model changes, and wrong in a way nothing detects.

Git parses only the last paragraph of a message as trailers. A blank line above
`Co-Authored-By` demotes the session trailer to ordinary body text — a
`%(trailers:key=…)` query then returns empty and the liveness check below
silently finds nothing. Verify rather than assuming:

```bash
git log -1 --format='%(trailers:key=Claude-Session,valueonly)'
```

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

**Never force-push, and never resolve a rejected push by force.** A rejection
usually means another session pushed first, and that is a merge decision for the
caller to take back to the user, not something to resolve here. No `--amend`, no
`--no-verify`, no `--no-gpg-sign`.

**Never rewrite a commit you did not make** unless the user said so explicitly,
naming the commit. Rewriting under a session that turns out to be live desyncs
it, and "finished" is an inference. A stale transcript is evidence, not proof.

## Tags

Only `--wss-release` calls for one, and only after it has shown the user the commits,
the tag name and the branch and received an explicit OK **in that turn**.

```bash
git tag -a vX.Y.Z -m "<milestone name>"
git push origin <branch>
git push origin vX.Y.Z
```

**This skill never asks for that confirmation and never proceeds without it.** A
primitive has no channel to ask — the same reason `WSS.agents.release` prepares the
material and never publishes it. If the caller has not said the OK was given in
that turn, stop and hand back.

A tag is the one thing here that cannot be undone: once another checkout has
fetched it, deleting it locally changes nothing.

## What this procedure does not do

- **It does not decide to commit or push.** No judgement about whether the work
  is ready, whether the milestone is done, or whether now is the moment.
- **It does not write any record file.** Not the changelog, not the roadmap,
  not the handoff — those have their own owners, and a commit is not a licence
  to adjust what is in it.
- **It does not rebase, revert or WSS.branch.** Those are decisions with a user in
  the loop, and none of them is history this workflow authors. **The one merge
  it does perform** is the one `--wss-pr` hands it, with the method from
  `WSS.branch.mergeMethod` and only once `pr` has the user's OK in that turn —
  [`WSS.OWNERSHIP.md`](../WSS.OWNERSHIP.md)'s `merge` row is the authority,
  and it is the reason a merge commit has an owner at all.

  **A lane landing on `WSS.branch.integration` is the second thing that looks like a
  merge and is not one.** `--wss-wrap` hands it
  `git push origin <worktree-branch>:<WSS.branch.integration>` — **never with a
  leading `+`** — so it resolves as a fast-forward or is refused by the remote.
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
