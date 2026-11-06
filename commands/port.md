---
description: Port a darktable module end to end (spec, Slang kernel, golden case, ΔE and gradient checks) with the porter agent in its own worktree, then have it reviewed
argument-hint: <darktable module, e.g. toneequal>
disable-model-invocation: true
---

Port the darktable module `$ARGUMENTS` to Apertrust. Several modules: one porter each, started in the same message.

1. **Check the module.** If none was given, ask which. Confirm it is an iop in darktable (`src/iop/<module>.c` at the reference release's tag, `$DT_TAG`; the `port-module` skill's source map has the commands). See whether a port exists or is under way: `docs/ports/<module>.md`, `crates/op/<module>/`, a case in `crates/golden/src/cases.rs`, a branch named after it (`git branch --list '*<module>*'`). If one does, say what exists and ask whether to continue it, rather than starting over.
2. **Check the worktree's starting point.** A worktree holds only committed work. If `git status` shows uncommitted changes the port depends on (the skills and agents in `.claude/`, the colour library, the harness), tell the user and let them commit first.
3. **Delegate to the `porter` agent** with `isolation: "worktree"`. Give it the module, what steps 1 and 2 found, and any instructions the user gave beyond the module's name.
4. **A spec-only return** (a large module: the porter stops after the spec) goes to the user: the spec's path, the algorithm in brief, the proposed deliberate differences and the open questions. Resume the porter with their answers (SendMessage), never with your own.
5. **A finished port goes to the `reviewer` agent**: give it the worktree's path and the module, not the porter's conclusions.
6. **Report**: ΔE2000 mean and max per case with the GPU; the gradient check per parameter on the case and with `--synthetic`, and forward against reverse mode; the deliberate differences; the reviewer's findings by severity; the worktree's path and branch; anything open. Don't merge, commit or push: the user does.
