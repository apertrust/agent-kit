---
description: Port a darktable module end to end (spec, Slang kernel, golden case, ΔE and gradient checks) with the porter role in an isolated worktree, then have it reviewed
argument-hint: <darktable module, e.g. toneequal>
disable-model-invocation: true
---

Port the darktable module `$ARGUMENTS` to Apertrust. For several modules, use one porter per module; parallelise only when each has an isolated worktree, otherwise work through them one at a time.

1. **Check the module.** If none was given, ask which. Confirm it is an iop in darktable (`src/iop/<module>.c` at the reference release's tag, `$DT_TAG`; the `port-module` skill's source map has the commands). See whether a port exists or is under way: `docs/ports/<module>.md`, `crates/op/<module>/`, a case in `crates/golden/src/cases.rs`, a branch named after it (`git branch --list '*<module>*'`). If one does, say what exists and ask whether to continue it, rather than starting over.
2. **Check the starting point.** If `git status` shows uncommitted changes the port depends on (the skills and agents, the colour library, the harness), tell the user and let them commit first. Create an isolated git worktree for implementation. Use native worktree isolation if the harness provides it; otherwise create it with `git worktree add` and start the worker in that checkout.
3. **Run the porter role** with the module, what steps 1 and 2 found, and any instructions the user gave beyond the module's name. If the harness cannot delegate, follow the porter instructions in the current session.
4. **A spec-only return** (a large module: the porter stops after the spec) goes to the user: the spec's path, the algorithm in brief, the proposed deliberate differences and the open questions. After the user answers, continue the same worker if the harness supports resuming it; otherwise start the porter role again with the spec and the user's answers. Never answer a product question on the user's behalf.
5. **Review a finished port** with the `reviewer` role: give it the worktree's path and the module, not the porter's conclusions. If the harness cannot delegate, follow the reviewer instructions in the current session.
6. **Report**: ΔE2000 mean and max per case with the GPU; the gradient check per parameter on the case and with `--synthetic`, and forward against reverse mode; the deliberate differences; the reviewer's findings by severity; the worktree's path and branch; anything open. Don't merge, commit or push: the user does.
