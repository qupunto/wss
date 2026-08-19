# Exercise debt — the contract-tested-only cluster

Standing register: what ships proven only by fixtures, not by a real run.
Shrink a name off this list only on evidence of a real run; add one whenever
something ships proven only by fixtures.

`--wss-todo` (`record`) is the sole writer. `.claude/WSS.LOCAL-RECORDS.json`
declares this file as `WSS.record.exerciseDebt` — a project-local key, since no
other adopting project would read it (`WSS.MANIFEST.md`'s "Not manifest keys").
Reasoning belongs in the decision log (`wss/logs/WSS.DECISIONS.md`), never here.

**Promoted out of `wss/records/WSS.TODO.md` on 2026-08-18**, where it had sat as
a `- [ ] ` entry despite self-labelling as a standing register — a Class 4
misfile (belongs in a standing register, never joined one) caught by that
session's Phase 0 duplicate-read-back survey. The disposition (promote, don't
leave in place) was the owner's ruling on 2026-08-17; this file, its manifest
key and this ownership row are what executes it. See the decision log's
2026-08-17 (twenty-fourth) and 2026-08-18 entries.

---

Standing entry;
shrink a name off this list only on evidence of a real run, and add one
whenever something ships proven only by fixtures. As of 2026-08-09:
`describe` (this repo declares no `WSS.record.behaviour` —
`.claude/WSS.WORKFLOW.json`'s `record` block has no `behaviour` key and this
repo has no runtime rules to put in one, being a suite of skills rather than
a running system, so the flag, its skill, its `block_for()` block and its
ownership row all ship unexercised by daily use. **Do not add a record here
to exercise it** — a record invented to test a flag is a record nobody
reads; exercise it against a project that declares the key. Absorbed
2026-08-13 from a standalone Cycle 8 entry that restated this list item
longhand),
`reference` (used once — possibly twice: `README.md` was rewritten twice inside `v0.10.0..v0.10.1`, through the writer procedure rather than demonstrably through the skill), `/wss:retire` (never run for real),
`lane-record-sync` (**corrected 2026-08-11**: this entry previously
said no lane-splitting tree existed and the blocker was a run rather than
a candidate. That was false — the owner states lanes have run five-wide on
a real project for weeks. **What that testimony did not settle is which
specific artifacts the run exercised, and this entry absorbed that question
on 2026-08-13** — the owner answered per artifact on 2026-08-14 and three
names came off; the paragraph below records who answered and when. What
remains genuinely unproven is narrower still: its step-0 fast-forward
landing, shipped 2026-08-08),
the hook's `lanes_named_()` lane-mode gate
(`hooks/wss-shorthand-flags.sh:216-221`, which decides whether the lane
bullet is injected — **the risky half is the OR**: the selector arm
returns true on its own, so a worktree carrying `.claude/WSS.LANE` while
the manifest declares no `lanes` is the case fixtures cannot settle,
because it is a claim about how a real worktree comes to exist rather than
about how the function reads two inputs),
the GitHub-Issues
TODO list provider, the workflow-page shape (**used once** — the first real
page is `wss/docs/domain/WSS.WORKFLOWS.md`, linked from `wss/docs/_sidebar.md` and
`wss/docs/index.md`. Writing it surfaced three gaps in the shape, all
fixed 2026-08-10 — the decision log carries them. One page is one run, so
the name stays until a second project's page exercises the form),
`WSS.localCI` (the publish exclusion was proven by a real assembly run
2026-08-08; the key itself no project declares yet), and **`update`
plus `--wss-adopt`'s migration mode** (built 2026-08-08 against issue
#16's five bites; the doctor/retire/export detection ran against real
fixtures, but no end-to-end migration has run through the skill — the
two known customer trees are the waiting exercise). The
risk is concentration: a first adopter hits several first-runs at once.
Filed by audit pass 12 (F4). Parked (owner ruled) — see the decision log's 2026-08-14 (eighteenth) entry.

**The blank line above stopped being load-bearing on 2026-08-15**, and
this paragraph records that rather than the rule it replaced. The
deferral-pointer check no longer delimits its unit by blank line: the
unit is a `- [ ] ` entry, closing on the next such line or a `## `
heading, and the capture re-arms on every marker. So this register's
marker no longer opens one blob over the whole entry, and the blank line
is free to be formatting again. **What still keeps the three sub-entry
authorities below out of coverage is the anchor rule, not spacing** —
each is backtick-quoted, and a quoted marker deliberately starts no
span. Locate the check with `grep -n 'Deferral pointers' wss-doctor.sh`
and read its own comment block rather than this paragraph.

**`wss-tree-survey.sh` came off this list on 2026-08-10**, on exactly the
evidence this entry demands: a real run against a genuine adopting tree —
its main checkout and all five of its lane worktrees, exit 0 on each — and
the properties it printed were the ones the surface mapping actually
needed, which is the one thing a fixture could not establish. It also
caught what a fixture could not have posed: six directories that read as
six separate projects and resolved, from their manifests and their shared
origin, to one.
**A candidate tree now exists for the lane-shaped names above, and
`describe` has three** — the first declares five lanes with a transfer
queue each, a conflict inbox, and a behaviour record; two further projects,
surveyed on a second machine on 2026-08-10, each declare a behaviour record
as well. Those are candidates and not runs: every one of those names stays
on this list until work has actually moved through it. **The TODO list
provider and `WSS.localCI` gained nothing from any of them** — none backs
its TODO list with a provider and none declares `WSS.localCI`, so across
three projects on two machines those two have no candidate at all rather
than a delayed one. A new tree, not a re-survey, is what would falsify it.
**`wss-survey-all.sh` joins this list on 2026-08-10** — it ships and
publishes, and the population it reported was assembled from surveys pasted
in by hand rather than from a run of the walker against those roots.
**`WSS.docs` joins it on 2026-08-11**, and it is the third key in the
no-candidate class alongside the TODO list provider and `WSS.localCI`: this
repo deliberately does not declare it, because `docs/` is what the first
fallback already resolves and declaring it would restate the default. So
the *declared* path ships proven by the contract suite and by one live run
against a temp two-language site — which did earn its keep, catching two
real defects in the first draft — while the fallback path is the only one
any real tree has exercised. A project with a translated site, or with its
docs somewhere other than `docs/`, is what would move this.
**`wss-docs-audit.sh` inherits this debt on 2026-08-13 rather than adding
its own.** The script shipped that day resolving the same three keys with
the same fallbacks, so it has exactly this key's coverage: its fallback
path ran against this repo, its declared path against a purpose-built
fixture only. It is not a separate name on this list — one key, now two
readers, and the tree that would retire it retires both at once.
**Two of the wrap restructure's three scripts join on 2026-08-12, and were
narrowed the same day rather than struck.**
`skills/wrap/assets/wss-wrap-status.sh` and
`skills/wrap/assets/wss-handoff-state.sh` ship proven by the contract
suite, and both then ran inside a real `--wss-wrap` — the close-out of the
batch that built them — the status script driving steps 6 and 7, the
handoff script splicing `## State` twice, everything above the card marker
byte-identical each time.
**What is left is another project's tree**, and the workflow-page shape
above is the precedent for keeping the names here: one run is one run. Both
resolve the handoff path, the two splice anchors and every record path from
the manifest, and this repo exercises exactly one spelling of each. A tree
whose handoff sits outside `.claude/`, or whose `## State` sits elsewhere
relative to the card marker, is what would move this.
**Two standalone entries fold in on 2026-08-13**, both admitted by this
list's own rule — each ships proven only by fixtures — and each keeping the
deferral authority it arrived with, which the register's closing
`Parked (owner ruled)` does not override:
**The `wss-publish.sh` pre-strip assertion for `*/wss-<name>`
(`Parked (owner ruled)`).** A glob naming a `wss-<skill>` must carry a trailing
segment; the assertion enforces that convention and fails the assembly
naming file and line. Two constraints an implementer will otherwise
re-break: it must run **pre**-strip, because a post-strip version fired on
five false positives — every file narrating the bug spells the damaged
form — and its regex was deliberately **not** widened for the same reason.
`ae0ba75` scopes it, putting `tests/` out, since the suite must spell the
forbidden shape to prove the gate fires. Exercised against the contract
suite's fixtures and one full local assembly ending `ALL GATES PASS`
(2026-08-12); a real publication was the only thing that could exercise it.
**One ran on 2026-08-17.** `v0.11.1`'s Publish job assembled, gated and
staged `qupunto/wss#23`, so this assertion has executed inside a real
publication rather than a local dry run — and passed, which is the accept
path. Its REFUSE path is still fixture-only, so the name stays with its
scope narrowed to that half. Re-derive its hit count against
`git archive HEAD` rather than the working tree — the assembly is what the
gate reads — and do not write the answer back.
**`wss-reset-records.sh`'s hazards-sibling derivation against a lane tree
(`Parked (session judgment)` — evidence, not a ruling).** `:197` derives a lane's
`WSS.HAZARDS.md` from that lane's handoff directory and `:256` does the same
for the top-level one (`grep -n HAZARDS wss-reset-records.sh`; `:253` sets
the default the next line overrides), so a project mapping its handoff
somewhere unexpected moves its hazards file too.
**The reset run this entry asked for happened on 2026-08-14** — a real
lane tree copied to a scratchpad, 34 declared records blanked, the
manifest's hazard pointers trimmed, idempotent across two runs, exit 0,
source tree verified untouched. So the wait is discharged and what is
left is narrower and differently shaped.
**The blanking body has now run, on a fixture, by the owner's
instruction — 2026-08-14, the twenty-third decision entry that day.** Both
branches no tree on this machine could reach executed: the lane sibling
`:199-207`, and the top-level `:259-271` derived from a handoff declared
**outside** `.claude/` rather than from the hardcoded fallback, which is
the audit pass 9 F7 regression path. The pointer trim dropped three
pointers into blanked files and kept the one into a file the run never
touched; a second `--write` was idempotent at exit 0; and a hazards file
symlinked outside the tree was **refused** at exit 1 with the target
intact.
**That narrows this and does not discharge it, on this register's own
terms** — the whole point being that fixtures already pass, and an
invented fixture is exactly what was built. What the run does remove is
the *derivation* and the *containment refusal* as open questions: both are
now demonstrated correct rather than reasoned about.
**What is left is one observation on a tree someone actually works in.**
Every candidate surveyed carried no `WSS.HAZARDS.md` at all, in its
worktree or its history — **re-derive that with
`find <tree> -iname '*HAZARD*'` against a candidate rather than trusting
this paragraph**, since a lane that later grows one is precisely what
moves this. Nothing further was ordered.
**The third does not join, and the distinction is the point of this list:**
`wss/workflow/writers/assets/wss-git-commit.sh` made all six of that batch's
commits against this repository, with the session trailer read back through
`%(trailers:key=…)` and the staged file list checked per commit. That is a
real run, not a fixture, so it never belonged here.
**Three names come off on 2026-08-14, on the owner's per-artifact
testimony**, which is what this entry asks for rather than the general
statement that lanes have run five-wide for weeks:
`lane-record-sync`'s step-5 return leg, `--wss-wrap`'s step-0
sync-forward, and `wss-remove-lanes.sh` — the last being the one no amount
of *running* lanes could have reached, since it fires only when lane mode
is dismantled. Delete each from the list above rather than treating this
paragraph as the record of their removal; it is here to say who answered
and when. **What their departure unblocks is the entries parked on lane
adoption**, which should be re-read at the next gate rather than assumed
still blocked.
**`lane-record-sync`'s containment is not covered by that answer.** The
skill was restructured into a router plus seven step references on
2026-08-14 and that shape has still never had a real run — a fixture-green
refactor of a never-run skill moves the risk to someone's first real
invocation, which is exactly what this register exists to track. It stays.
**`stocktake`'s router split joins on 2026-08-14, by this list's own
rule.** The skill was restructured that day into a router plus six phase
references and the shape has never had a real run — the same footing as
`lane-record-sync` above and for the same reason: a fixture-green
refactor of a skill nobody has since invoked moves the risk to someone's
first real `--wss-stocktake`. The contract suite and `wss-doctor.sh` both
pass against it, which is exactly the evidence this register treats as
insufficient.
**`adopt`'s and `docs`' router splits join on the owner's ruling,
2026-08-14**, completing the set of four. The record sweep that day found
they had been left off while the other two went on, with no reason recorded
for the asymmetry — the same day, the same shape, the same rule. Recount
what each split added with
`git diff --name-status b2afe37..HEAD -- 'skills/adopt/references/*.md' 'skills/docs/references/*.md'`
rather than from a figure here; both directories also hold older references
the split did not create, so a plain `ls` overcounts.
**These two are the mode-exclusive pair, and that cuts both ways.** It is
why their split is a genuine saving where `stocktake`'s is mostly a
re-routing — the untaken paths are never opened — and it is also what puts
the risk in the routing itself: a sequential router that picks wrong still
reads everything, while one of these opens the wrong reference set and the
step never runs. Nothing tests the choice.
**One near-miss to record before it is mistaken for exercise.** The
2026-08-14 docs sweep read `skills/docs/references/WSS.MODE-AUDIT.md`
directly as a method and ran `wss-docs-audit.sh` against this tree. That is
not a run of the skill — the router was bypassed entirely, which is the one
component at risk. A reference reached by a caller who already knows which
one it wants exercises the reference and never the routing.
What shrinks each: a real `--wss-adopt` against a tree that is adopting,
and a real `--wss-docs` invocation that picks its own mode.
**The lane dispatch note joins on 2026-08-14, by this list's own rule and
on the day it shipped.** It is documented at both ends — the append in
`skills/wrap/references/WSS.LANES.md`, the drain in
`skills/start/references/WSS.LANES.md` — and nothing has ever written
or read one, because this repository declares no lanes. It is weaker than
fixture-proven, which is the class this register was built for: there is
no fixture either, only prose describing a queue entry's content. The
shape it rides was settled rather than guessed, so what is unproven is
whether the three things it carries are the three a receiving session
actually needs to classify a foreign change instead of investigating it.
What shrinks it: one real dispatch into a lane, and the receiving lane's
next `--wss-start` reading it at Phase 0.
**The agents' own `model:` assignments join on 2026-08-15, on the day they
shipped, and the reason is structural rather than incidental.** Three
agents gained a `model:` key and two gained a body line declaring the top
tier by its absence; the session that wrote them could not dispatch a
single one through the new assignment, because the agent registry loads at
session start (`wss/records/WSS.HAZARDS.md`, "The harness itself"). So the
routing change is proven by nothing but reading. It is the same shape as
the Execute row in the per-grant table, which lifted only when a later
session started after the agent file existed. **What shrinks it: one
dispatch per agent from a session that began after these commits**, with
the model each actually ran at read back rather than assumed — the throwaway
report-your-own-model probe `wss/workflow/WSS.DISPATCH-LADDER.md` already
names is the instrument.
**The probe ran on 2026-08-15 and this name comes off the list**, on
exactly the evidence the entry demanded rather than on a dispatch that
merely looked right. All five agents were dispatched from a session that
began after those commits, each asked only to report its own model back,
none carrying a caller override: `wss-survey` and `wss-execute` returned
`claude-haiku-4-5-20251001`, matching the `model: haiku` each declares;
`wss-analyze` and `wss-release-prep` returned `claude-opus-5[1m]`, the top
tier they declare by absence. Five for five against the ladder's table.
**One limit, and it is why this paragraph stays after the name goes.**
`wss-design` could not produce a dated identifier — it reported its tier
from its environment info and said so rather than guessing. So the
read-back is proven at TIER granularity, which is what the ladder's table
actually assigns, and not at the model-ID granularity the other four
returned. An agent whose `model:` key named the wrong build of the right
tier would still pass this probe. Re-run it rather than trusting this
paragraph.

**The relocated no-manifest fallbacks join on 2026-08-15, by this list's
own rule and on the day they shipped.** Every record fallback now resolves
under `wss/`, and the only thing exercising that path is the contract
suite's own fixture trees — this repository declares every key, so its
daily use never takes the fallback branch at all. That is the weakest
footing on this list: not "proven by fixtures rather than by a run", but a
branch this tree structurally cannot reach.
**What shrinks it is also what makes it dangerous**, so read both together:
a real adopted tree that declares no manifest, or omits a key, and picks up
the change. On such a tree the old location simply stops being read, with
no error at the moment it happens — so the first observation may be a
record that looks empty rather than a failure. `update` owes the
migration, and until that exists this name should not come off on the
strength of a tree that survived by declaring everything.

**The relocated `wss/workflow/` and `wss/tests/` join on 2026-08-16, the
day tier 3 landed, and they are the same shape as the fallbacks above.**
Every path this repo resolves now points at the new layout, and the only
thing exercising the OTHER branch is an adopted tree still carrying
`.claude/workflow/`. `wss/tests/wss-doctor.sh` reads both shapes
deliberately, with a paired warn naming `--wss-update`, so the old branch
is live code that this repository structurally cannot reach — it declares
the new shape and always will. **What shrinks it is a real adopted tree
picking up this change**, which is also what would prove the manual mend
bullet in `skills/update/SKILL.md` is followable rather than merely
written. Until then the dual read ships proven one-sided.

**The commit-provenance hooks joined on 2026-08-16, the day they shipped,
and were narrowed the same week rather than struck.** The script's
`--emit`/`--assert`/`--writers` paths ran against disposable fixtures and
against the contract suite; what had NOT run was the pair installed in a
clone anyone works in.
**They are now installed in this clone**, on the owner's ruling of
2026-08-16 and deliberately placed AFTER that batch's code commits, so a
misfire could not block work already finished. `wss-doctor.sh` reports
them present rather than warning; that flip is how you can tell, and it is
cheaper than reading `ls .git/hooks/`.
**THE REFUSAL FIRED FOR REAL ON 2026-08-17, and this half is discharged.**
It was not staged: a commit grouped six files spanning four record
authorities and declared one of them, and `commit-msg` refused it —
"wrong authority — 'writers/WSS.HANDOFF-WRITER.md' is not a writer for any
record in this commit". Correct, and it caught a real mistake rather than
a manufactured one.
**Two things the refusal taught that no fixture had.** A refused commit
leaves the index STAGED, so the next commit sweeps up everything the
refused one had added — which is exactly what happened, producing one
six-file commit instead of the intended split. `git reset` between
attempts. And declaring NOTHING passes where declaring the wrong thing
fails, so the guard catches a mistake and never an omission; that is the
self-declared limit the entry above already records, now observed rather
than reasoned about.

**`WSS.record.backlog` joins on 2026-08-16, and what is unproven about it
is narrower than "unused".** The record, its manifest keys, its ownership
row, its contract rows, its reset-records row and its four assertions all
ship proven by fixtures. **Two entries were filed into it the same day**,
both genuine observations the batch turned up and neither queued — so the
filing half has run once. **The PROMOTION move has now run once too, on
2026-08-16** — the owner promoted the `--wss-adopt` entry at a `--wss-start`
Phase 1 gate and it shipped in that batch, so the half carrying the design
risk is no longer unexercised. It ran as the rule requires: one entry, a
person's explicit say-so, a MOVE rather than a copy.
**What is left is the claim one promotion cannot demonstrate** — that this
is where findings land *over time*, which is a statement about reflex
rather than about a mechanism. **What shrinks it: a later session filing
here by its own judgment rather than by instruction, and a second
promotion nobody had to be prompted into.**

**Both of 2026-08-16's guard changes joined on the day they shipped, each
proven on its ACCEPT path only. The append-only half is no longer
unexercised: it refused real work, in CI, and the refusal was wrong.**
The draft-position narrowing (`aa1df86`) rode three real commits in this
clone that afternoon and let all three through, so the accept path was
never in doubt. What had never happened was a refusal outside a fixture.
It happened at `9ed4e17`: that narrowing introduced a SINGLE-heading
anchor for exemption 3, which is correct only when exactly one entry was
appended, and CI measures from the merge base with `origin/main` — where
this branch has appended some thirty entries in one hunk. It read the
whole run as one rewritten entry and failed the "Logs are append-only"
step against a branch that had done nothing but append. Fixed at
`c4ba710` by widening the anchor from the outermost heading to the whole
appended run. **The half that carried the risk fired, and it fired as a
false refusal rather than a missed one** — the cheaper of the two, and
only because the thing it blocked was CI rather than a person.

**The debt that replaces it is the head-side half, and it is narrower.**
The widened anchor's TAIL branch has two discriminating cases in
`wss/tests/wss-append-only-test.sh`: `append_many` fails against the
pre-fix build and passes after, and `append_many_smuggle` proves the
widening did not blunt the guard — a line smuggled into the old tail
entry is still caught while four new entries are appended alongside it.
The HEAD branch, `post_old_head`, for newest-first records, had neither.
`prepend_many` looks like its test and is not one: its hunk starts above
the first `## ` heading, so exemption 1 takes it before the anchor is ever
consulted, and it passes against the pre-fix build too. This is live
rather than theoretical — `wss/logs/WSS.CHANGELOG.md` is newest-first, so
the next release that adds a version section is what exercises it.
**The head branch gained a case on 2026-08-17 — `smuggle_head` — and the
discriminating case this paragraph used to demand was WITHDRAWN on the
same measurement.** `smuggle_head` adds two entries at the head and
smuggles a line into the body of the entry that used to be the head; it is
refused, attributed to `## Entry 1`. It behaves identically against
`aa1df86`'s build and `c4ba710`'s, so it is real head-branch coverage and
not a discriminator, and the file says so at its own definition rather
than leaving the next reader to re-derive it.
**The demand was withdrawn because, against `c4ba710`, it selected only
defects** — every shape that failed against `aa1df86` and passed against
`c4ba710` was one where `c4ba710` was WRONG, both anchors having been
indexed by TOTAL growth. **That was fixed the same day**, so the
discriminating cases now exist honestly and are in the suite:
`smuggle_head_both_ends` and `smuggle_tail_both_ends` are refused here and
accepted by `c4ba710`, with `grow_both_ends` and
`head_draft_survives_tail_append` guarding the over-refusal direction.
**What must not be re-filed is a discriminating case built against
`c4ba710`'s behaviour**, which would freeze a false accept into an
assertion. The decision log's 2026-08-17 entries carry the arithmetic.
**The shape this paragraph prescribed is separately unbuildable, and that
is worth keeping rather than deleting.** "A draft rewritten into a release
with a fresh draft above it" necessarily DELETES a line at the head, and
once the record has grown a deletion at that end is never exempt — by
design, stated at `wss/scripts/wss-append-only.sh:316-319`. So it fails
both builds and could never have discriminated. Measured over candidate
shapes A–E on 2026-08-17, with and without a record header.
**`WSS_APPEND_ONLY_BIN` remains the instrument** — point it at
`git show aa1df86:wss/scripts/wss-append-only.sh` in a temp file to tell a
real regression case from one that passes both, which is exactly how
`prepend_many` got mistaken for a test.

The exception-2 note checks are the other half and are unchanged: they ran
against this tree's own three condensed copies and passed, so the accept
path has a real run rather than a fixture one, while the refusal was
proven only by fixtures that strip the note. **What shrinks it: a real
record write made under the wrong shape, refused in a clone someone works
in.**
