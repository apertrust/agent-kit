---
description: Draft a commit message for the staged changes, or for every uncommitted change when nothing is staged, in the style of the project's history. Drafts only; the user commits
argument-hint: [what to include, or a hint about the change]
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git log *), Bash(git show *), Bash(tools/check-license-headers.sh)
---

Draft a commit message for this change. $ARGUMENTS

1. **Scope.** The staged changes (`git diff --cached`) if anything is staged; otherwise every uncommitted change: `git status --short`, `git diff HEAD`, and the untracked files themselves. The arguments can narrow it ("only the hooks"). Read the diff itself, not only its stat.
2. **Style.** Short and plain, the way a person writes a commit message. Earlier messages in `git log` run long: don't copy their length.
   - **Subject**: what the change does, in sentence case: imperative ("Port AgX from darktable") or, for an architecture decision, "Record decision N: …". No type prefix, no full stop, ideally under 60 characters, never over 72.
   - **Body**: why the change was made, and what the diff doesn't show. Usually two to five sentences; a small fix may need none. Wrap at 72 columns. No list of the files or docs touched, no restating the subject, no closing summary; bullets only for a real list.
   - **Numbers**: only the one that matters (a ΔE, a timing), with its hardware. Point to the doc in this repository that has the details (`docs/ports/…`, `docs/engine.md`) instead of repeating them.
   - **Nothing private**: never mention working material or any file outside this repository; the message stands on what the repository holds.
   - **Voice**: plain words and short sentences, as you would explain the change to a colleague. No chains of semicolons, no hedging, no "This commit…".
   - British spelling, as in the docs; never the names of commercial raw editors. The one trailer is the sign-off, `Signed-off-by:` with the committer's name and address from git's identity (the DCO, the Developer Certificate of Origin), which `git commit -s` adds. Other trailers follow `AGENTS.local.md` where it exists.

   For example:

   ```text
   Port grain from darktable

   The kernel follows darktable's noise and its mid-tones bias, and the
   module plans the operation only while Strength is off zero, so an
   untouched photo renders as before.

   The five golden cases match within a mean ΔE2000 of 0.0008 on the
   M4 (docs/ports/grain.md).

   Signed-off-by: Your Name <your email address>
   ```

3. **Flag, don't fix**, above the message, anything that should not go into this commit:
   - unrelated changes mixed in: propose a split, with the files for each commit;
   - a `.slang` change without the matching change in `generated/`, files git should ignore (raws, models, `test-images/`), secrets, debugging leftovers;
   - a missing licence header (`tools/check-license-headers.sh`).
4. **Output** the message in one fenced `markdown` block, ready to copy, and nothing more than a line about any flag. Never stage, commit or amend: the user commits.
