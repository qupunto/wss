# Workflow Secretary Suite — Documentation

**Workflow Secretary Suite** is a suite of Claude Code skills that act as a *secretary to
coding rather than a coder*: they keep a project's backlog, decision log,
roadmap, documentation and tooling catalog matching what the code actually does.
Anything needing stack knowledge — architecture, correctness, security, the data
model — is deliberately absent, so judge it as a project secretary rather than a
programming assistant. There is no runtime and no build: the project is markdown
instruction files, a handful of shell scripts and two CI workflows — one that
verifies, one that publishes.

The repository **is** `~/.claude`. It does not install into that directory; the
directory is the working tree.

---

## Contents

| File | Description |
|---|---|
| [WSS.OVERVIEW.md](WSS.OVERVIEW.md) | Repository layout, what a session loads and when, what can be switched off and what cannot, the scripts, and the verification commands |
| [domain/workflows.md](domain/workflows.md) | End-to-end journeys through the suite. Currently one: a batch from `--wss-start` to `--wss-wrap`, its ten stages, its three human gates, and the three places the obvious narration is wrong |

## Annex

| File | Description |
|---|---|
| [annex/lane-synching.md](annex/lane-synching.md) | How work crosses between lanes without any lane writing another's records — the transfer queue, the `[critical → why]` marker, and `/wss:lane-record-sync` |
| [annex/WSS.CLAUDE-TOOLING.md](annex/WSS.CLAUDE-TOOLING.md) | Every skill and script, what each is for, the tier diagram, and who invokes whom |
