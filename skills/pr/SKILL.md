---
name: pr
description: "Assemble a release branch and ship it to publish through a pull request — draft the body from the real range, open it, watch CI, merge once the user confirms. SHORTHAND: `--wss-pr`. Also trigger on \"open a PR\", \"raise a pull request\", \"is the PR green yet\", \"merge that PR\", \"cut a release branch\". MERGES TO PUBLISH — never infer it from \"looks good\"."
---

# Moving work onto the publish branch

`WSS.branch.integration` is the **disposable test bench** where work is proved;
`WSS.branch.release` names the branch a release is assembled on; `WSS.branch.publish`
is what the project ships from. **The PR comes from a release branch, never from
the integration branch** — that is what lets the bench be reset or discarded
without a release losing anything. This skill is the only thing in the workflow
that moves work onto the publish branch.

**The flow this file describes binds once the branch-flow cycles land.** Until
then the tree may still be running integration→publish; say which you actually
did rather than reporting the model.

**This skill writes nothing** — not a record, not the history. The commits and
the merge go through `git-writer`. Who owns what is
[`wss/workflow/WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md).

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.branch.integration`,
`WSS.branch.release`, `WSS.branch.publish`, `WSS.branch.mergeMethod` and
`WSS.commands.ci`. `WSS.branch.release` is a **pattern** — `<version>` is
substituted at branch-creation time — and where it is undeclared the fallback is
`release/v<version>`, said out loud like any other fallback. Without a manifest,
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

## 0. Assemble the release branch

**The PR's head is a release branch, so it has to exist before §1 can measure a
range.** Where the user names an existing one, use it and skip to §1.

1. **Compose the name.** `WSS.branch.release` with `<version>` substituted —
   `release/v0.16.0`, not `release/0.16.0` or `release-v0.16.0`. **Naming is a
   rule and it is applied always**, alongside the conventional-commit title
   profile ([the decision log's `2026-08-19 (fortieth)` entry]). **A
   user-supplied name is taken in its place** — that is the user's authority
   superseding the rule, not an exception written into it, and it is not a
   precedent for composing a different name unasked (`(forty-first)`).
2. **Create it from `WSS.branch.publish`**, never from the integration branch.
   Assembling from publish is what keeps the bench disposable: nothing on the
   bench is load-bearing for the release unless it was deliberately merged in.
3. **Merge the chosen typed branches into it**, in the order the user gives.
   `git rerere` replays the conflict resolutions already settled on the bench,
   so a conflict resolved once during development is not re-litigated here — but
   **a resolution rerere replays is still a resolution: show it and say it was
   replayed**, never let it pass as a clean merge.
4. **Say what went in and what did not.** The chosen set is the user's, and a
   branch silently omitted is a release that quietly ships less than it claims.

**These merges are run by hand under `git-writer`'s authority, not by
`wss-git-commit.sh`** — that script commits and pushes and has no merge path at
all. The distinction is the same one
[`WSS.GIT-WRITER.md`](../../wss/workflow/writers/WSS.GIT-WRITER.md) draws for
the PR merge itself: the authority is the procedure, the script is one of its
instruments. **This closes the register entry reading "the merge chain
`--wss-pr` names has no implementation"** — the chain was always the procedure's
and never the script's, and both ends now say so.

**Where the `staging-branch` toggle is on** — read it with
`bash wss/scripts/wss-toggle.sh --on staging-branch`, and **absent means off** —
the release merges into `staging` first and the PR this skill opens is
`staging`→publish, gated on QA approval. Off or absent, which is the ordinary
case, the PR is release→publish directly. Rulings: the decision log's
`2026-08-19 (thirty-sixth)` and `(thirty-seventh)` entries.

## 1. The precondition is a pushed branch, not a clean tree

`git log origin/<publish>..origin/<release>` is the range — the release branch
assembled in §0, or `staging` where the toggle is on. Three cases:

- **Empty** — there is nothing to open a PR for. Say so and stop.
- **Local commits not on the remote** — stop. Pushing is not this flag's grant,
  and a PR opened over an unpushed branch describes a range the reviewer cannot
  see. Say what is unpushed and let the user push, or `--wss-wrap`.
- **A PR is already open for this branch** — do not open a second one. `gh pr
  list --head <release>` answers it. Go to §4.

**Say plainly whose work is in the range.** A PR publishes a whole branch, so
another session's commits ride along in it exactly as they would in a push. The
user should see that before the body is written, not after it merges.

## 1a. Run the checks BEFORE drafting, and tick only from results

`.github/PULL_REQUEST_TEMPLATE.md` carries a Checks section, and
`WSS.prChecks` maps each box to the `WSS.commands.*` key that answers it. **Run
them first.** A box ticked from memory is worth less than an empty one, because
an empty box reads as "not done" while a wrong tick reads as evidence.

- **Tick from the result, and cite the command in the row** — the command and
  what it returned, not a bare tick. This is the suite's "no number without the
  command behind it" applied to a checkbox.
- **A failing check stays unticked with its failure line quoted.** The PR is
  still opened. Hiding the failure by omitting the row is the one outcome worth
  refusing: the reviewer cannot see a gap that was never written down.
- **A check that does not apply is struck through with its reason**, rather than
  left empty — an empty box must always mean "considered and not done".
- **Never tick an Attestation.** Those rows are human-only by construction; ask
  the user or leave them, and delete the ones that do not apply.
- **Where `WSS.prChecks` is undeclared, say so and leave the section for the
  user** rather than guessing which command answers which box.

**The mapping is a manifest key rather than a file beside the template**, so
each command is written down once and `wss-doctor.sh` fails a mapping whose
command no longer exists. What it cannot detect is the attestation list drifting
from what the project actually attests, or the QA idiom going stale — those are
reviewed prose, and nothing checks them.

## 2. Draft the body from the range, never from memory

Read `git log origin/<publish>..origin/<release>` with `--stat`. A body
written from what this session remembers doing omits every commit it did not
make, and those are the ones a reviewer most needs named.

What the body is for: **what changed and why**, at the altitude of the reviewer.
Not a pasted commit log — they can read that in the PR itself — and not a
restatement of the diff.

**Where `→WSS.script.wss-toggle.sh --on terse-messages` succeeds, this section's
shape changes and its sourcing does not.** The body becomes the range and what
changed, without the narrative: still read from `git log`, never from memory,
because the reason that rule exists — a body written from memory omits the
commits this session did not make — is untouched by how much prose the body
carries. Cite the decision entries and stop.

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

`gh pr create --base <publish> --head <release>`, with the body from §2 in a
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

**Deleting the merged release branch afterwards is the ordinary case** — a
release branch is created per version and has no life after its PR merges. The
integration branch is never the PR head now, so it is never the branch in
question here; it is long-lived and deleted by nobody. **Ask
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
