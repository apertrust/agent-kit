---
description: Run the golden-image checks (ΔE2000 against darktable, timing, the gradient check) for the named cases or all of them, and compare with the results recorded in the port specs
argument-hint: [case...]
allowed-tools: Bash(cargo run --release -p apertrust-golden *)
---

Run Apertrust's golden checks for: $ARGUMENTS (every case when empty). The `golden-tests` skill explains the harness and how to read its output. This is a check, not a fix.

1. **Cases.** `cargo run --release -p apertrust-golden -- list`. For a name that is not a case, say so, list the cases, and offer to add one by the skill's "Adding a case"; add it only once the user agrees.
2. **Requirements.** The ΔE check needs darktable-cli and `APERTRUST_TEST_IMAGES`. Without them, run only step 4's synthetic check, and say the ΔE check was skipped and why.
3. **ΔE and timing**: `cargo run --release -p apertrust-golden -- run $ARGUMENTS --heatmaps target/golden-heatmaps`.
4. **Gradients**: `cargo run --release -p apertrust-golden -- gradient $ARGUMENTS`, then the same with `--synthetic`.
5. **Compare with the record**: each module's port spec (`docs/ports/<module>.md`) holds its last golden and gradient results. Flag every ΔE mean or max that moved, and every check that passed before and fails now.
6. **Report** per case: ΔE2000 mean, p95 and max, pixels over max, PASS or FAIL, median time per pass, and the GPU; per parameter, the gradient's relative error and the forward/reverse difference. For a failure, read the heatmap and say where the error sits (the skill's "Reading results"), and name the next diagnostic: `gradient --explain`, or the `slang-kernels` skill's debugging reference.

Never change a case, its sidecar, a tolerance or the harness, and never update a result recorded in a port spec unless the user asks: a changed number is a finding.
