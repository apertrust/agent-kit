---
description: Draft a pull request's title and description for the current branch against main, with the results and checks a reviewer needs. Drafts only; opens the PR only when the user asks
argument-hint: [base branch, or a hint about the change]
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git log *), Bash(git show *), Bash(git branch *), Bash(git rev-parse *), Bash(cargo run --release -p apertrust-golden *), Bash(cargo test --release -p apertrust-raw *)
---

Draft a pull request for the current branch. $ARGUMENTS

1. **Scope.** The commits on this branch that its base lacks: `git log --format=%B main..HEAD` and `git diff main...HEAD`, with another base if the arguments name one. On `main`, or with no commits ahead, say so: a pull request needs a branch, so suggest a name and stop. Uncommitted changes are not part of it; list them as such.
2. **Title**: like a commit subject (`/draft-commit`'s style): sentence case, no prefix, no full stop, at most 72 characters. For a single-commit branch, that commit's subject.
3. **Description**: short and plain, the way a person writes one for a reviewer; it should fit on one screen. GitHub markdown, with only the sections that have something to say:
   - **Summary**: what the branch does and why, in a few sentences. Name any architecture decision it records by number here.
   - **Changes**: a handful of bullets, only when the branch touches several areas, each saying what changed, not which files.
   - **Results**: the numbers that matter, each with the GPU or machine that produced it: ΔE2000 per golden case, the gradient check, timings, the raw corpus.
   - **Checks**: one line per check, saying what it said. CI runs lint, cargo deny and tests on Linux, Windows and macOS, but not the golden harness or the raw corpus, which need local data. When the branch changes the kernels, the engine or the golden harness, run `apertrust-golden run` and `gradient` for the cases it touches, unless this session already ran them on this code; when it changes the decoder, run the corpus test, or say plainly that it was not run. Never report a check that did not run.
   - **Open**: only if something is: what remains, or what the reviewer should look at closely.

   No restating the title, no list of the docs updated, no closing summary. British spelling, as in the docs; never the names of commercial raw editors. An AI disclosure line is allowed but never required: AI help is disclosed once, in the README and the AI policy; `AGENTS.local.md` may say more. Never mention working material or any file outside this repository. If a commit on the branch lacks its `Signed-off-by:`, say so above the draft, since the DCO asks one on every commit.
4. **Write `PR.md`** at the project root, which git ignores: the title as its first line (`# <title>`), a blank line, then the description. If the file exists, read it first: when it drafts this branch, keep the user's edits and change only what the branch's new changes require; otherwise replace it. Reply with the file's path and the title, not its contents.
5. **Don't push or open the PR.** When the user asks you to open it, push the branch and run `gh pr create --draft`, with the title from `PR.md`'s first line and the rest of the file as the description (`--body-file`, through a temporary file), unless they ask for a ready PR.
