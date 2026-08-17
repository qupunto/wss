---
name: pr
description: "Move work from the integration branch to the publish branch through a pull request — draft the body from the actual range, open it, watch its CI, and merge once the user confirms. SHORTHAND: `--wss-pr`. Also trigger on \"open a PR\", \"raise a pull request\", \"is the PR green yet\", \"merge that PR\". MERGES TO PUBLISH — never infer it from \"looks good\" or \"that's done\"."
---

# Moving work onto the publish branch

`WSS.branch.integration` is where work accumulates; `WSS.branch.publish` is what the
project ships from. This skill is the only thing in the workflow that moves work
between them.

**This skill writes nothing** — not a record, not the history. The commits and
the merge go through `git-writer`. Who owns what is
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md).

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.branch.integration`,
`WSS.branch.publish`, `WSS.branch.mergeMethod` and `WSS.commands.ci`. Without a manifest,
fall back to the current branch against `main`, a merge commit, and no CI check
— and say which fallbacks you took, because "CI was not checked" and "CI passed"
are not the same report.

## The `--wss-pr` shorthand

Where a flag counts is [`README.md`](../../README.md) — including why the token
is spelled out and not `--pr`; what it authorizes is the block
`wss-shorthand-flags.sh` injects and
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md)'s matrix.

Invoking without confirmation is safe because everything up to §5 is local or
reversible.

## 1. The precondition is a pushed branch, not a clean tree

`git log origin/<publish>..origin/<integration>` is the range. Three cases:

- **Empty** — there is nothing to open a PR for. Say so and stop.
- **Local commits not on the remote** — stop. Pushing is not this flag's grant,
  and a PR opened over an unpushed branch describes a range the reviewer cannot
  see. Say what is unpushed and let the user push, or `--wss-wrap`.
- **A PR is already open for this branch** — do not open a second one. `gh pr
  list --head <integration>` answers it. Go to §4.

**Say plainly whose work is in the range.** A PR publishes a whole branch, so
another session's commits ride along in it exactly as they would in a push. The
user should see that before the body is written, not after it merges.

## 2. Draft the body from the range, never from memory

Read `git log origin/<publish>..origin/<integration>` with `--stat`. A body
written from what this session remembers doing omits every commit it did not
make, and those are the ones a reviewer most needs named.

What the body is for: **what changed and why**, at the altitude of the reviewer.
Not a pasted commit log — they can read that in the PR itself — and not a
restatement of the diff.

- Lead with the outcome and the reason, in a couple of sentences.
- Name the decision entries in `WSS.record.decisions` that this range implements, so
  the reasoning is one click away rather than re-argued in review.
- Say what is deliberately **not** in the range, where the branch touched
  something it did not finish.
- Where the repository has a `.github/pull_request_template.md`, fill that shape
  rather than replacing it.

Show the user the draft body and the target branch before opening. This is not
the merge gate — it is cheaper to fix a title here than to edit it after (§3).

## 3. Open it

`gh pr create --base <publish> --head <integration>`, with the body from §2 in a
file rather than inline, so newlines and backticks survive the shell.

**Known failure, and it is not yours to fix.** On a repository still carrying a
classic Projects association, `gh pr edit` fails with a GraphQL deprecation
error — including the `gh pr create` paths that touch the same mutation. The
working substitute for edits is the REST endpoint:

```bash
gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -f title='…' -f body='…'
```

Do not retry the failing command with different arguments; it fails on the
repository, not on the input.

## 4. Watch the CI, do not assume it

Query `WSS.commands.ci` for the PR's run. Where the manifest declares none, say that
CI was not checked rather than reporting the PR as ready.

- **Green** — go to §5.
- **Red** — report which job failed and stop. Fixing it is ordinary work: commit
  under this flag's grant, but the push that carries the fix to the PR needs the
  user's OK, the same as any other push here.
- **Still running** — say so and stop, with the run's URL. Do not poll a long
  pipeline inside the turn; the user can come back to `--wss-pr`, which
  will find the open PR at §1 and resume here.
- **Never `--admin`**, and never merge past a failing required check. A gate
  bypassed once stops being a gate.

**A red base is not a red PR.** Where `WSS.branch.publish` was already failing before
this range existed, the PR's red tells you nothing about the range — check
whether the same job fails on the base commit, and say which of the two it is.

## 5. Merge — the gate

**Stop and show the user exactly what is about to land**: the PR number and
title, the base branch, the commit count, and the CI result you actually read.
Wait for an explicit OK **in that turn** — not one inherited from earlier in the
conversation, and never implied by the CI going green.

Then hand the merge to `git-writer` with the method from `WSS.branch.mergeMethod`,
telling it the OK was given in this turn. Where the key is undeclared, use a
merge commit and say so — squashing is not a safe default, because it discards
the individual commit messages the history is the record of.

Deleting the remote branch afterwards is only correct where `WSS.branch.integration`
is short-lived. A long-lived integration branch is deleted by nobody; **ask
rather than inferring it from the merge succeeding.**

## 6. Sweep the review threads nobody resolved

**Do this after the merge.** This is the one thing in a merge that has no other
owner.

**Resolution state is GraphQL-only.** `gh api repos/O/N/pulls/N/comments` returns
no resolved field at all — checked, it is simply not in the payload — so a
sweep built on REST reports every thread as unresolved and floods the TODO list:

```bash
gh api graphql -f query='
query($o:String!,$n:String!,$p:Int!){
  repository(owner:$o,name:$n){ pullRequest(number:$p){
    reviewThreads(first:100){ nodes{
      isResolved isOutdated path line
      comments(first:1){ nodes{ author{login} body url } } } } } }
}' -f o=OWNER -f n=NAME -F p=NUMBER \
 --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
```

**Propose; do not file.** A meaningful share of unresolved threads is chatter,
and a TODO list that costs more to prune than it saves is abandoned; the volume is
low enough that asking is cheap.

So: list what you found, one line each, with the file and line and a link, and
say which you think are actionable and why. **The user picks.** Confirmed items
go to `--wss-todo`, which owns the TODO list and writes it wherever this project
declares — a file or a provider.

**`isOutdated` is a separate column, not a filter.** It means the code under the
thread has changed since the comment, so the point may already be addressed —
or may have been silently dropped by the very edit that moved the line. Say
which ones are outdated and re-read those before proposing them; do not quietly
skip them.

**Never resolve a thread on GitHub.** Marking someone's comment resolved is
their act, and doing it on their behalf destroys the only signal that the
question was never answered. Filing a TODO list item is the response; clicking
resolve is not.

Where the repository has no threads, or none unresolved, **say so in one line**
rather than staying silent — "nothing was left unresolved" is a result, and its
absence reads as a step that was skipped.

## 7. Close out

Say what merged, at which commit on `WSS.branch.publish`, and what the range
contained. Then check whether it made anything else due:

- **A milestone whose last block just landed** — that is `--wss-plan`'s question to
  put to the user, not an inference from a merge.
- **A version worth tagging** — name `--wss-release` as the next step. This skill
  never tags; `WSS.branch.publish` moving is not a release.

## What this skill does not do

Who owns what is [`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md); what each record
holds is [`WSS.RECORD-CONTRACT.md`](../../wss/workflow/WSS.RECORD-CONTRACT.md).

- **It does not write any record file.** The body drafted in §2 is not a record
  and is never written to a file in the repository.
- **It does not merge, commit or push by hand.** Those go through the history's
  owner, which will not merge without being told the confirmation was given in
  that turn.
- **It does not tag, and does not end the session.** A version is the release
  flag's, on `WSS.branch.publish` and behind a milestone mark rather than a merge;
  the closing ritual is `--wss-wrap`'s.
