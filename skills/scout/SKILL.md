---
name: scout
description: "Search the stack's public registries (npm, pip, crates, …) for an existing library before a capability gets hand-built, explain the candidates, and keep the project's toolbelt registry of adopted tools. SHORTHAND: `--wss-scout`. Also trigger on \"is there a library for\", \"what package does\", or when a task means implementing something that smells like a solved problem."
---

# The tooling scout

A session biased toward solving in-context will hand-author three failed
attempts at a solved problem before anyone searches the ecosystem. This skill
is the search — and the registry that makes each search's answer permanent.

**Advise, do not implement.** The deliverable is candidates and an explanation:
what each package does, how closely it fits the task shape, and what adopting it
would displace. Doing the task with the chosen tool is the session's work, not
this skill's.

**Project facts come from `.claude/WSS.WORKFLOW.json`**: `WSS.record.toolbelt` is the
registry, fallback `WSS.TOOLBELT.md`. An absent file is an empty registry, not an
error. This skill is its **sole writer** —
[`WSS.OWNERSHIP.md`](../../workflow/WSS.OWNERSHIP.md).

## Job 1 — Consult, before any search

Read the registry first. A row whose task shape matches the request answers it:
name the package, point at its decision entry, stop. The search below is
expensive and deliberate; the lookup costs nothing and must happen every time.

## Job 2 — Scout

When the registry has no answer and the task is capability-shaped — convert,
parse, render, diff, OCR, anything that smells like a solved problem — search
the stack's public registries before anyone writes an implementation.
Candidates are judged on fit to the task shape, maintenance signal, and how much
they displace; present the top few with a recommendation, and say plainly when
building in-context genuinely is the better call. Adoption is the user's
decision, not this skill's.

## Job 3 — Register the adoption

When the user adopts a candidate, two writes, split exactly as
[`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md) requires:

- **The row, here.** Task shape → package → pointer into `WSS.record.decisions`.
  Lean — the registry is a lookup table, not a second decision log.
- **The reasoning, through `--wss-log`** (`record`): what was searched, what
  was rejected, why this one — the verbose entry the row points at.

**One registry per project, never lane-split** — which tool does a job is a
property of the project, not of a worktree
([`WSS.RECORD-CONTRACT.md`](../../workflow/WSS.RECORD-CONTRACT.md)). Where the registry
pointer names a decision entry, use its heading, which is stable in an
append-only log; where the manifest declares `WSS.record.decisionsIndex`, the index
is the cheap way to it.

## What this skill does not do

- **It does not install or integrate anything.** Advice and the registry row;
  the build is ordinary session work.
- **It does not decide.** A recommendation is not an adoption — the row is
  written only on the user's word.
- **It does not write the reasoning.** That is `record`'s file, reached
  through `--wss-log`.
