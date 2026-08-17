# Step 9 — Create the missing records — empty

For each record the project needs and does not have, create the file with its
canonical heading and nothing else. Say which you created.

**The name comes from the key table's fallback where there is one, and from
[`WSS.NAMING.md`](../../../wss/workflow/WSS.NAMING.md) where there is not** — this is
the second read the split key/naming contracts cost, and skipping it is how a
project acquires a `stocktake.md` beside a tree of `WSS.` records. A file the
project already has keeps its own name (step 3); only a name this step *invents*
is governed by the grammar, and a genuinely ambiguous one is the owner's to
rule, not this skill's.

**Nothing else goes in them.** Not a placeholder task, not an example decision,
not a "TODO: fill this in". The owning skill writes the first real line, and it
should be a true one.

Where the project genuinely does not need a record — no roadmap because it is a
library with no planned blocks — do not create it, and leave the key out.

**`WSS.record.backlog` is the exception to that, and it is created whenever a
TODO list is.** The two are a pair: the TODO list holds what is queued, the
backlog holds the non-blocking findings a session turns up on its way to
something else. A project has those from its first session, so "it has nothing
to put there yet" is never the reason to skip it — and skipping it is not
neutral. With no backlog those findings land in the TODO list, which is the
single bag the split exists to remove, and they arrive carrying a `- [ ]` that
makes unqueued observations look scheduled. The key table's fallback resolves the
file without a `backlog` key, so declaring one is optional; creating it is not.

**A record under a provider has no file to create.** Where `WSS.record.todo` is a
provider object, creating an empty `WSS.TODO.md` here would hand the project the two
TODO lists the provider exists to prevent — the same fallback
[`providers/WSS.GITHUB-ISSUES.md`](../../../wss/workflow/providers/WSS.GITHUB-ISSUES.md)
refuses. Skip the row and say the TODO list is provider-managed.

