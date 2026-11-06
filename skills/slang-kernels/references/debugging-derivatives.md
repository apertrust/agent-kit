# Debugging derivatives

How the colorbalancergb `chroma_global` gap was found and fixed (the kernel spike). Use the same method when `apertrust-golden gradient` fails.

## Read the symptoms

`gradient CASE --explain` prints how the gap between reverse mode and finite differences spreads across pixels, and the pixels where forward and reverse mode disagree most.

| Symptom | Likely cause |
| --- | --- |
| Forward and reverse agree, finite differences differ, the gap is the same at steps 1e-4, 1e-3 and 1e-2 and sits in a few pixels | A real jump in the function, or a derivative term autodiff misses (a guard in Slang's library, a `no_diff` in the wrong place) |
| Forward and reverse agree, the gap shrinks with the step | A kink that finite differences straddle: expected near clips and nodes, not a bug |
| Forward and reverse agree, the gap is the same at every step, and the worst pixels sit exactly on a corner (two channels equal, a hue on a sector boundary) | Autodiff takes one side's slope at a corner the pixels sit on, while central differences average both sides (AgX's hue mix at 0, `docs/ports/agx.md`) |
| Forward and reverse disagree on some pixels | The generated derivative code is wrong for those pixels: a recomputed branch, a context field never saved, or a guard that one mode hits and the other does not |
| The gap spreads evenly over all pixels | A missing or wrong term everywhere: a parameter's unit or scale, or the CPU setup's derivative not included |

Rerun on the synthetic sweep (`--synthetic`): it covers every hue, saturation past the gamut, and levels from deep shadow to above white, so the failing region shows up as coordinates ("hue 25°, saturation 1, level 0.18").

## Bisect the kernel by stage

Copy the kernel into a throwaway probe outside the repository (the session's scratchpad), and make the per-pixel function return an intermediate value when a spare uniform slot (an unused parameter, such as colorbalancergb's `saturation_formula`) selects a stage:

```slang
if (p.stage == 4) return float3(jc, h);
```

Compile it with `slangc` (`external/slang/<version>/bin/slangc probe.slang -I crates/color/slang -I crates/plugin/slang -target wgsl -o probe.wgsl`). Then, for a few failing pixels and one parameter, compare per stage and per component: reverse mode (with dLoss/dOutput one-hot on that component), forward mode (direction one-hot on the parameter) and central finite differences. The first stage where they part is where the bug is. Check finite differences at two steps; a noisy one at 1e-3 that settles at 1e-2 is noise, not a bug.

Get exact pixel values from the case's input (`target/golden/<case>/*/input.pfm`), not rounded ones: near a kink or a node, four decimals is a different pixel.

## Read the generated WGSL

Slang names its derivative code predictably:

- `s_fwd_<fn>`: forward mode of a function.
- `s_apply_<fn>`: the reverse pass's forward half, which also fills a `s_minCtx_…` context struct with values the backward half needs.
- `s_bwdProp_<fn>`: the backward half. It recomputes most primal values rather than reading them from the context.
- `_d_<intrinsic>`: Slang's built-in derivatives, where its guards live (`_d_pow` zeroes below 1e-6; `_d_sqrt` caps below 1e-7).

A field of the context that is set only inside a branch, while `s_bwdProp` recomputes that branch's condition from recomputed values, is the lookup-table bug's shape. To see what a context field holds at run time, patch the probe's WGSL to write the field into the derivative output (for example `(*_S475) = ctx.value1_2 * d_out;`) and divide by the known chain factor.

## Fix by cause

- **A guard in Slang's derivative library**: give the function its own derivatives with `[ForwardDerivative(fn)]` and `[BackwardDerivative(fn)]`, as `pow0` does.
- **A recomputed branch**: remove the branch, usually by making the computation unconditional when it gives the same value anyway.
- **Pixels sitting exactly on a corner**: write the function's derivatives out so that near the corner they average the slopes either side, as `hsv_to_rgb` does. The forward pass stays the same arithmetic, so golden results don't move. Detect the corner within a tolerance, never by exact equality: the backward pass recomputes the input, and on Metal not bit-identically.
- **A real discontinuity or kink**: keep it if darktable has it, record it in the port spec's Gradients section, and plan the smooth approximation for the optimisation path.
- **A Slang bug**: write a minimal repro for upstream, and work around it in the kernel meanwhile.

Record what you found in the port spec and, if it is a new trap, in the `slang-kernels` skill.
