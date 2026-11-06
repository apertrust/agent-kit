# Port spec: <module name>

Source: darktable (the reference release, commit <commit>), `src/iop/<file>.c` `commit_params()` and `process()`, with helpers from `src/common/<helpers>`. The reference is darktable's CPU path.

Status: draft · reviewed · ported · verified. <What is ported, what is not yet.>

Golden result (case `<case>`, darktable test <NNNN>, <image>, <width>×<height>, <GPU>): ΔE2000 mean <value>, p95 <value>, max <value>.

## Purpose

One paragraph: what the module does for the photographer, in editing terms, and how it achieves it, in one sentence of algorithm terms. Which Apertrust module owns it (`docs/modules/README.md`).

## Pipeline

- **darktable position:** <iop order neighbours>
- **Apertrust slot:** <stage and number, as `docs/engine.md`'s Order table gives it (decision 22); where it is not darktable's place, why>
- **Domain:** scene-referred or display-referred, as the slot's side of the tone mapper says (architecture, Scene and display domains)
- **Input and output:** raw mosaic, camera RGB or working RGB; colour space in and out
- **Assumes earlier modules:** <e.g. white balance applied, demosaic done>
- **Layer support:** yes or background only, and why

## Parameters

darktable params version <n>: <the fields in order, with types>.

| Name | darktable field | Type | Range | Default | Meaning | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

Owner: the module and tab whose controls set the parameter (`docs/modules/README.md`, Owners by operation; one owning module per parameter), or "fixed" with the reason it has no editing meaning. A parameter a layer-capable module owns must not be a tone-mapper parameter (architecture decision 33).

## Parameter versions

| Version | Change | Migration |
| --- | --- | --- |
| | | |

## Setup on the CPU (`commit_params`)

What `commit_params` computes from the parameters (lookup tables, matrices, normalised values), with formulas. This becomes `prepare` in `crates/op/<module>/src/setup.rs`.

## Per pixel (`process`)

Step-by-step, with formulas, in processing order. Name the darktable function for each step (`file.c:function`), so a reviewer can check it against the source.

1.
2.
3.

## Neighbourhood and scale

- **Neighbourhood radius or reach:** <pixels at full resolution, or none; where it depends on the parameters or the scale, `Operation::reach` from `tiling_callback`'s overlap (decision 13)>
- **Scale dependence:** <how radii scale with `roi->scale` / `piece->iscale`, what darktable derives from the scaled lengths, and any branch taken on one, which follows the full-resolution length (decision 15); an iterated box mean's radii at each scale, r and r + 1 matching the variance (decision 63)>
- **Tile overlap needed:** <pixels>
- **Region-of-interest changes:** <`modify_roi_in/out` behaviour>

## Precision and special values

- fp64 maths in darktable and how it is redesigned for fp32
- Clamps, thresholds and divisions that can misbehave
- How darktable handles NaN, infinity and negative values here

## CPU and OpenCL differences in darktable

Any place where `process_cl` and the OpenCL kernel differ from the CPU `process`. Apertrust follows the CPU code.

## Deliberate differences

- <Difference>: <reason>; its size, measured.

A departure from what darktable renders reproducibly is agreed first, and names the setting that keeps darktable's behaviour for the golden harness alone (decision 63).

## Tool binding notes

How the owning modules' controls reach the parameters: transfer functions, units the control shows differently from the engine (an inverted or rescaled value), and why each fixed parameter has no editing meaning. **What is an identity:** the setting where the operation changes nothing, or "none". **darktable's defaults for a new instance:** the values its module starts from; a module darktable leaves off on a new photo is switched, off until a control changes, then on with them (decision 32). The Owner column says who owns a parameter; this says how its control drives it.

## Gradients

The parameters the kernel differentiates against, in its derivative entry points' order. Results of `apertrust-golden gradient` on the case and with `--synthetic`: relative error against finite differences per parameter, and forward against reverse mode per pixel. Any gap, understood and explained. Known non-smooth spots (clips, nodes, kinks).

## Test plan

- **Golden cases:** <darktable integration tests, edited sidecars for modes they lack>
- **Tolerance:** `Tolerance::DARKTABLE` (mean ΔE2000 ≤ 0.767, max ≤ 2.3), or a stricter or looser one with the reason
- **Invariants:** a module that is off is a no-op (decision 32), and one every photo runs untouched at its defaults; finite output for very bright, zero and negative input; <monotonicity or other module-specific properties>; parameter migrations render identically

## Open questions

-
