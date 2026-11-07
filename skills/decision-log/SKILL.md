---
name: decision-log
description: Record an architecture decision in Apertrust - its file in docs/decisions/ - when a change counts as architectural, who decides, and how to write the record and update the decision summary, the documents that describe the area, their open questions, the roadmap, AGENTS.md and the project skills so they all agree. Use this whenever a task changes or settles a decision (a dependency choice, a crate's role, the kernel or plugin interface, the threading model, a rule in AGENTS.md), a spike's result settles an open question, the user decides something worth recording, or docs disagree with each other about a decision, even if the user only says "let's go with X instead" or "write that down".
---

# Decision log

`docs/decisions/` holds every architecture decision, one file each (`NNNN-short-title.md`), with its options and reasons, and an index in `docs/decisions/README.md` (decision 66), which opens with the current state by area, the decision summary. `docs/architecture.md` is a short overview pointing to each area's document (`docs/engine.md`, `docs/plugins.md`, `docs/gui.md`, `docs/library.md`, `docs/settings.md`, `docs/session-protocol.md`, `docs/layers.md`, `docs/ai.md`, `docs/testing.md`, `docs/dependencies.md`), which holds the area's design and its open questions; `docs/roadmap.md` holds the plan, and `docs/crates.md` each crate's state. A decision written down in one place but contradicted in three others misleads every agent that reads the others, so recording a decision means updating everything that describes it.

## When a change is architectural

Record a decision when a change:

- picks or changes a dependency of consequence (a decoder, a UI toolkit, a C library, a runtime);
- adds a crate, or changes what a crate owns or depends on;
- changes an interface others build on: the kernel bindings, the plugin manifest, the session protocol, the edit format;
- changes the pipeline: its order, its anchors, where it renders, how passes are fused;
- changes or adds a rule in AGENTS.md's engineering rules, or a convention a project skill encodes;
- settles an open question, or follows from a spike's result;
- changes or narrows an earlier decision.

A bug fix, a refactor inside a crate or a new feature within the existing design is not a decision.

## Who decides

Decisions are the user's. When work runs into one, stop and put the choice to the user with a recommendation and its consequences; record it once they have chosen, or when they ask you to record what they decided. Where the user has delegated technical design (the `architect` agent says which), the architect decides and records it with its options. Never record a decision on your own judgement otherwise, and never quietly code around one.

## How to record it

1. **A new question gets a new file** in `docs/decisions/`, named `NNNN-short-title.md`: the next number after the last decision, zero-padded to four digits, then the title in lower case, apostrophes and punctuation dropped and spaces as hyphens. The file has this form:

   ```markdown
   # NNNN. Title

   ## Context

   ## Decision

   ## Options considered

   ## Consequences
   ```

   - **Context**: what question it settles and what constrains it, in a few short sentences.
   - **Decision**: what is decided, as it stands now, with the names, types, numbers and limits that matter; a part not built yet says "planned". Measured numbers come with their hardware.
   - **Options considered**: each real alternative in a line, with why it was not chosen.
   - **Consequences**: what follows for the code and the docs.

   **Add a line for it to the table in `docs/decisions/README.md`**, under its area: the number linked to the file, and the title. Records cite each other by number and link, `[0018](0018-one-submit-gate-for-the-engine-and-the-window.md)`.
2. **A change to an existing decision edits its record** so that it states what is decided now. A record holds no history, no "amended by" or "superseded by", no dates of who decided what: git keeps the history. Rename its line in the index if the title changes; its number never changes.
3. **Update the decision summary** (`## The current state by area` in `docs/decisions/README.md`): the area's current choice and the main alternative rejected, citing the decision number. Add a row for a new area.
4. **Update the sections that describe the area**, so none of them still argues for the old choice. Search for the old choice's name across `docs/` and fix every place that now contradicts the decision, other records included.
5. **Update the area's `## Open questions`**, in its document (`docs/engine.md`, `docs/gui.md`, `docs/library.md`, `docs/session-protocol.md`, `docs/testing.md`): tick a question the decision settles, with a pointer to where it is described, and correct any entry the decision changes. Update `docs/roadmap.md` where the decision changes the plan.
6. **Update AGENTS.md** if a rule, a command, the crate table or the current phase changed, and `docs/crates.md` if a crate's role or state changed.
7. **Update the project skills** that encode the old convention: they live in the agent kit, so the change there is a pull request to the kit, made once the main repository's change has landed.
8. **Measurements go in this repository's docs**: a decision that follows from measurements gives the numbers that matter in its record, with their hardware, and the method and the rest of the numbers in the port spec or the doc that describes the area (`docs/engine.md`, `docs/gui.md`, `docs/ports/…`).

## Writing

- Plain, specific sentences: the decision, its reasons and its numbers. No hedging once the user has decided.
- Follow AGENTS.md's writing rules: never name commercial raw editors; say "commercial raw editors".
- One decision per file. A question that bundles several choices (threads, viewport drawing and diagnostics, say) can share a file if they were decided together, but each choice must be stated.
- A record describes what is decided now, not how it came to be: no dates, no "the user's" or "decided by", no history.

## Check before finishing

- `grep -rn "<old choice>" docs/ AGENTS.md` finds no place that still presents it as current, and neither does a search of the kit's skills.
- The decision number in the summary, the sections and AGENTS.md matches the record.
- A new file's number follows the last, and its line is in `docs/decisions/README.md`.
- The commit message names the decision ("Record decision 41: …", or "Change decision 41: …") and never mentions files outside the repository; the user commits.
