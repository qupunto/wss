---
name: report
description: "File a finding about this suite upstream — append it to the machine-local inbox, then, with an explicit OK in that turn, open a GitHub issue on the suite's public repository. SHORTHAND: `--wss-report`. Also trigger on \"report this upstream\", \"file this against the suite\", \"send this to the workflow repo\", \"send the whole inbox\"."
---

# Reporting a suite finding upstream

The inbox flow this mechanizes already exists:
[`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md)'s cross-project rule files every
suite finding into the machine-local `WSS.BUG-REPORTS.md` and stops, and an adopter
with no checkout has "an issue upstream" as their terminal step. This skill is
that step made deterministic — and it is the durability move for the one file
whose loss is unrecoverable: an inbox entry exists on one machine; an issue
exists wherever GitHub does.

The upstream repository is **`qupunto/wss`** — hardcoded, like
the plugin-cache glob, because the plugin name is load-bearing; a fork files
against itself by editing this line.

## The order is: local first, upstream second

1. **Append the entry to the inbox** — `$CLAUDE_CONFIG_DIR/WSS.BUG-REPORTS.md`
   (`~/.claude/WSS.BUG-REPORTS.md` unless that variable is set), in the format
   [`WSS.OWNERSHIP.md`](../../wss/workflow/WSS.OWNERSHIP.md#a-file-belonging-to-the-installation-is-never-edited-from-a-project-session)
   states. **Read that section before writing the entry** — the three template
   lines, where in the file they go, and which SHA the `Found:` line carries are
   all there, and this skill keeps no second copy of them on purpose.

   Filing locally is complete in itself. If everything after this step fails,
   the report exists and the doctor surfaces it; say the upstream half is owed
   rather than retrying into a wall.

2. **Compose the issue, redacted by default.** Title: the one-line summary.
   Body: the `File:` and `Detail:` lines, the config commit, and the install
   form (checkout or plugin). **Never the `Found:` line** — see below.

3. **Show the exact title and body**, then send only on an explicit OK **in
   that turn**. Publishing to a public repository is irreversible — caches and
   notification emails outlive a deleted issue — so a standing "yes" from an
   earlier turn does not carry.

4. **Send**, labelled where the label exists:

   ```bash
   gh label list --repo qupunto/wss --json name \
     --jq '.[] | select(.name == "report") | .name'
   gh issue create --repo qupunto/wss \
     --title "<summary>" --body-file <tmpfile> [--label report]
   ```

   An empty label query means send without `--label` and say so — `gh` errors
   on a label that does not exist, and creating one is the maintainer's call,
   not this skill's. Where `gh` is absent or unauthorized, stop after step 1
   and say the issue is owed; the entry is not lost, only local.

5. **Append the issue URL** as one line at the end of the entry just filed, so
   triage in a checkout can see it was already raised. Appending to your own
   entry in the same action is still filing, not triage.

## Bundling: the whole inbox may travel; hazards travel by name only

Where the user asks for the full picture, one issue may carry **every open
inbox entry**, not only the finding being filed:

- Each bundled entry passes the same redaction — its `Found:` line is
  stripped by default — and the preview shows the complete body, every entry,
  exactly as it will be sent. One OK covers the bundle only after the whole
  thing has been shown.
- Bundling closes nothing. Entries flip to `[closed]` only in checkout
  triage; the issue URL is appended to each bundled entry, as in step 5, so
  triage can see they were raised together.

**Hazards are referenced, never quoted.** The hazards file carries standing
warnings about the repository that wrote them — the exact content
`wss-reset-records.sh` blanks out of the published tree, which is the measure of
how private it is. Where a finding relates to a documented hazard, name the
group and the manifest key that points at it (`WSS.hazards.plugin`, say): the
maintainer opens their own copy, the reference leaks nothing, and a group
name says enough. If the hazard's text itself seems necessary to make the
report intelligible, that is the signal to stop and ask, not to paste.

## The redaction rule is the point, not a nicety

The inbox is machine-local, so its entries safely name the project the session
was working in — that context is useful to triage and harmless on disk. The
upstream repository is **public**. A private project's name, path or details in
a public issue is a leak that outlives deletion. So the `Found:` line **never
travels by default**;
include project context only when the user says to in words, after being shown
what was withheld. When in doubt, the redacted form is always correct — the
maintainer can ask.

## What this skill is not

- **Not triage.** Closing entries is a checkout session's job, per the inbox's
  own header. This skill only adds.
- **Not for project findings.** A defect in the project you are working on
  goes to that project's own records through `--wss-todo`; this skill is only
  for findings about the suite itself.
- **It never edits the suite** — the same cross-project rule that produced the
  inbox applies unchanged.
