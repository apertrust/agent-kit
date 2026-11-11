---
name: slang-kernels
description: Write, change, build and check Apertrust's GPU kernels in Slang - the binding interface, the parameter-struct / setup / per-pixel-function structure, fp32 and NaN rules, uniform layout, differentiability and the derivative entry points, the known Slang derivative traps, and the exact commands to compile to WGSL, validate with naga and check ΔE, gradients and timings. Use this whenever a task touches a kernel (a .slang file in an operation crate, the engine or apertrust-color, generated WGSL, a kernel's CPU-side setup or the list of operations), a naga or slangc error, a gradient that disagrees with finite differences, a uniform-layout mismatch, or kernel performance, even if the user only says "add a parameter to the kernel", "the gradient check fails" or "why is this pass slow".
---

# Slang kernels

Every Apertrust kernel is written in Slang and compiled to WGSL, because the differentiable features need Slang's autodiff (decision 9). The generated WGSL is committed, so builds and CI never need `slangc`, and wgpu translates it to Metal, Vulkan or DX12.

For a darktable port, the `port-module` skill wraps this one with the spec, the golden case and provenance.

## Where things live

Each operation is a crate of its own (architecture decision 20), and the engine owns the kernels that belong to no operation.

| Item | Path |
| --- | --- |
| An operation's kernel | `crates/op/<name>/slang/<name>.slang` |
| Its generated WGSL (committed) | `crates/op/<name>/generated/<name>.wgsl` |
| Its CPU-side setup | `crates/op/<name>/src/setup.rs`; `src/lib.rs` holds its `KERNEL` |
| The engine's own kernels | `crates/engine/slang/` and `generated/`, listed in `pipeline::KERNELS`: the viewport's downscale, a tile's region copy, an export's resample to its size (decision 56) and the scopes' count |
| Shared colour maths (a Slang module, `import color;`) | `crates/color/slang/color.slang`: `pow0`, Yrg and Ych, JzAzBz both ways, darktable UCS 22 (`ucs_*`) and CIE xyY (`d65_xyz_to_xyy`, `xyy_to_xyz`), `gamut_check_yrg`, `soft_clip`, `rgb_norm` (darktable's RGB norms), `xyz_to_lab_d50` and `lab_to_xyz_d50` (darktable's Lab, D50), matrices; illuminants and chromaticities: `NORM_MIN`, D50 in xy and u′v′, `illuminant_xy_to_xyz`, `xy_to_uv` and `uv_to_xy` with guarded denominators, `away_from_zero`; the CPU side in `crates/color/src/lib.rs`, with the illuminant models in `illuminants.rs`, the cone spaces' matrices and D50 constants in `adaptation.rs`, and darktable's curve interpolation and its extrapolation in `curve.rs`, darktable UCS 22 and xyY in `ucs.rs` |
| darktable's box mean (`import box_filter;`) | `crates/color/slang/box_filter.slang`: `box_mean_line`, one line's running sum in darktable's order, generic over the value (f32, float3) and over where the line is read and written (`IBoxLine`); its Rust restatement `crates/color/src/box_filter.rs`; bloom's `box_mean` pass is the example |
| darktable's recursive Gaussian (`import gaussian;`) | `crates/color/slang/gaussian.slang`: `dt_gaussian_blur`'s order-0 Deriche recursion, the coefficients (`Deriche`) from the uniforms, one `causal` and `anticausal` step for f32 and float2, and `clampf`, darktable's `CLAMPF`, with `MEAN_BLUR_RANGE`, `dt_gaussian_mean_blur`'s ±10⁹; a kernel walks one line per invocation, the causal sums written, then the anticausal ones added; the coefficients and the blur restated on the CPU in `crates/color/src/gaussian.rs`; the colour equalizer's line passes are the example |
| darktable's bilinear resampling between grids (`import bilinear;`) | `crates/color/slang/bilinear.slang`: `interpolate_bilinear`'s corner-aligned taps (`bilinear`, `Taps`) and their sum (`interpolate`, f32 and float2); its Rust restatement `crates/color/src/bilinear.rs`; the colour equalizer's grids are the example |
| The pass header (`import pass;`) | `crates/plugin/slang/pass.slang`, the twin of `PassHeader` in `crates/plugin/src/lib.rs`, whose crate docs define the interface |
| Writing a component chosen at run time (`import components;`) | `crates/plugin/slang/components.slang`: `add_at` and `set_at` for `float2`, `float3`, `float4` and `uint4` (decision 10) |
| The list of operations | `KERNELS` in `crates/operations/src/lib.rs` |
| Simplest complete example | `crates/op/exposure`; a large one, with the shared library and a table: `crates/op/colorbalancergb` |

## The interface

Every image kernel has the same bindings (documented in `src/lib.rs`):

| Binding | Contents |
| --- | --- |
| 0 | input pixels, `StructuredBuffer<float4>`, rows top to bottom |
| 1 | output pixels, `RWStructuredBuffer<float4>` |
| 2 | `ConstantBuffer<Params>`: a `PassHeader pass` (48 bytes: the pass's region size; its origin, the corner of the operation's output region in its stage's image at the pipe's scale; its full size, that stage's extent at full resolution, the developed image's or after a geometry its output's (decision 16); the scale and the repeat count, decision 12; then `input_base` and `output_base`, where the windows of bindings 0 and 1 start, and two reserved words, decision 14), then the operation's parameter struct at offset 48 |
| 3 and up | the module's read-only tables, `StructuredBuffer<…>` |
| 8, 9 | `derivative_in`, `derivative_out`, per pixel `float4`, for the derivative entry points |
| 10 and up | the operation's scratch buffers, shared by its passes and sized in bytes by the operation (decision 21) |

Each pass binds exactly what its entry point uses (wgpu refuses more), and the operation's `prepare` lists those bindings; raw-stage kernels read and write mosaics (`StructuredBuffer<uint>` for the 16-bit mosaic, two values to a word; `float` for the f32 one) instead of `float4`.

**Row strips** (decision 14). A GPU may bind less of a buffer at once than an image takes: lavapipe 128 MiB, a 61 MP float mosaic 244 MB. A pass that sets `Pass::strips` then runs once per band of its rows, the engine binding the window of each image the band reads or writes. The raw-stage passes before demosaic that read or write the mosaic set it, as does the engine's `region` copy, and their kernels must:

- take its first row of invocations from the header: row `params.pass.origin_y + id.y`, with `id.y` below `params.pass.height`, the strip's rows;
- index the whole image less the window's start: `input[i - params.pass.input_base]`, `output[i - params.pass.output_base]`, where `i` is the photosite's place in the whole image (the 16-bit mosaic's base counts words, as its index does);
- compute positions, colours and edges from global coordinates, as now, so a strip needs no alignment to the colour pattern;
- declare in `Strips` how many of its image's rows a row of its invocations covers (`rows`), the rows above and below it reads (`halo`), and, if its workgroups write a partial result each, `granularity: 16`, so strips are whole workgroup rows; it then writes its result at `(group.y + params.pass.origin_y / 16) * across + group.x`, its index in the whole image, and the combination and the statistic stay the whole image's.

Scratch buffers stay whole. A pass that binds only scratch may still set strips, so that a job's export cuts it into steps (highlights' `opposed_dilate`): it then runs in bands of its rows wherever its operation's output is larger than the binding, each as many rows as a strip binding that image's rows with its `rows` would have, and binding no window; its kernel takes its first row from the header's origin, as above, and each invocation's result must depend only on scratch the earlier passes finished, never on another band's. A pass without strips needs its images whole: demosaic, which runs whole or in tiles of its own, and every kernel after the raw stage, whose tiles index their own region.

Entry points, all `[numthreads(16, 16, 1)]`, one invocation per pixel, with a bounds check first:

- `main` (every per-pixel kernel; a multi-pass kernel such as demosaic's names an entry point per pass instead, decision 21): applies the per-pixel function `params.repeat` times (1 normally, more only in benchmarks; a spatial kernel instead runs `repeat` passes over the same input, each shifted so the compiler cannot merge them, as blurs does on branch `blur`). Alpha passes through.
- `<module>_backward`: reverse mode. Reads dLoss/dOutput (RGB) from binding 8, writes up to four parameter gradients to binding 9.
- `<module>_forward_diff`: forward mode. Reads a direction in parameter space from binding 8, writes the output's directional derivative to binding 9. It exists to check reverse mode.

**A whole-image pass** (`PassKind::Reduction` in the code, `PassKind::WholeImage` its planned name; decision 15) computes a result from the whole image at the pipe's scale that later passes read: a statistic, or a grid such as the tone equalizer's mask, of any size, in scratch buffers. A grid's passes walk its lines with one invocation per line where darktable's loops run sequentially, in darktable's order of arithmetic; the pass that reads the grid samples it at the pixel's absolute position (the header's origin plus its coordinates), with the grid's geometry the whole image's at the pipe's scale, from the uniforms. After demosaic the passes form runs, each those that read the operation's input and then those that read only scratch, one first round of an export's tiles per run, and only for an operation that opts in, its input-reading passes writing only the scratch their tile owns (decision 15): keep as few as you can, writing a full-resolution intermediate darktable keeps between iterations once into scratch laid out as an image, which those passes are to bind in row strips (indexing it less a base, as Row strips above; planned, decision 15), rather than reading the input again each iteration. Whole-image passes take a uniform block of their own with only what they read, so a parameter only the later passes use leaves their key unchanged, and the viewport keeps their result in scratch while it holds (decision 15): none of them writes the output, and a later pass, a per-pixel one writing scratch for a pass after it among them (decision 13), writes only scratch they do not write; and a grid's buffers are float2 halves, never float4, since its line passes cannot run in strips and each buffer must fit one binding. The derivative entry points belong to the pass that writes the output and read the same scratch, so they are exact only for parameters no whole-image pass reads; declare a gradient slot only for those, or for one a restructure makes exact (decision 11). **A statistic** (decision 15; `highlights.slang` is the example): WGSL has no float atomics, so it takes at least two whole-image passes, besides any that prepare its input, also of that kind (highlights' mask and dilation): one where each invocation adds up a block of pixels and the workgroup adds up its invocations in `groupshared` arrays, writing one partial result per workgroup to a scratch buffer, and one whose single workgroup (`Pass::size` of 16×16) adds the partial results up and writes the statistic to another scratch buffer, which the later passes bind. `GroupMemoryBarrierWithGroupSync` must be reached by the whole workgroup (naga rejects a barrier in non-uniform control flow): guard the work with an `if`, never return before a barrier. Count in integers where darktable counts in floats; sum in `float`, accepting that the order differs from darktable's threads in the last bits. Every pass that reads the image declares its strips (above), the partial results' pass with `granularity: 16`, so a strip never splits a workgroup; give a pass that walks a grid other than the image's (highlights' masks) a dispatch of the grid's rows, so a band of invocations reads a band of the image.

**A count** (decision 19; the scopes' histogram and totals, `crates/engine/slang/scopes.slang`, an engine kernel outside the plan): integers need no float atomics, so integer atomics add them in one pass, no partial results. Declare `groupshared Atomic<uint>` and `RWStructuredBuffer<Atomic<uint>>` and call `.add`, `.load` and `.store`: slangc refuses `InterlockedAdd` on a plain `uint` for WGSL. Clear the workgroup's counts first, barrier, count, barrier, then add each non-zero count to the storage buffer, which the engine clears before the pass; an element of a `groupshared` array at a run-time index is allowed (decision 10). Put a value in a bin by multiplying by a power of two (`⌊v × 256⌋`), which is exact, and limit it as a float before converting, so every GPU and the CPU agree, and as an integer after, so even a NaN stays inside the counts. A count has no derivatives, but takes `pow0` as every kernel does. **A readout pass** (decision 19; the tone equalizer's `mask_histogram`) is an operation's count for its module's panel, an entry point of the operation's kernel that the engine dispatches in the viewport alone: it computes what the operation's own passes compute at each pixel with the same functions (the tone equalizer's `mask_value`, as `main` calls it), counts it as above, 4 × 4 pixels an invocation, into its counts buffer, which the engine clears, and writes nothing else. Where darktable bins through a transcendental (`log2` of the mask, 32 bins an EV), keep darktable's arithmetic: the value itself comes from the GPU, so exact bins across GPUs are out of reach, and its tests keep values a hundredth of a bin clear of the edges.

Document the parameter order of both derivative entry points in the kernel. The preview kernels (`preview_*`) bend the interface where they must (a packed mosaic as input, a storage texture as output) and have no derivatives. A darktable port has both, except in the raw stage, whose kernels read and write mosaics and export neither (decision 21), and in an operation with no continuous parameter, as orientation (`flip`), input colour (`colorin`) and output colour (`colorout`), which exports none either, its manifest not differentiable (decision 11); `Kernel::derivatives` says which, and the manifest's `differentiable` must agree.

## How a kernel is structured

Keep three parts apart (decision 8), so per-pixel modules can later be fused into one pass that reads and writes the image once:

1. **A parameter struct**, filled by the CPU-side `prepare` from the module's settings.
2. **Once-per-image setup**: on the CPU in `prepare` where possible (matrices, LUTs, normalised values), or a small function in the kernel taking only the parameters.
3. **A pure per-pixel function** of the pixel and the parameters: no buffer indexing by thread id, no writes. `main` and the derivative entry points only wrap it.

```slang
import color;

struct ToneParams : IDifferentiable   // what the derivatives are taken against
{
    float strength;
    float pivot;
};

[Differentiable]
float3 tone(no_diff float3 rgb, ToneParams p)   // the per-pixel function
{
    return p.pivot * pow0(rgb / p.pivot, float3(1.0 + p.strength));
}
```

When only part of the parameters is differentiated (colorbalancergb's `Grading`), keep the rest in a plain struct passed as `no_diff`, and build the differentiable one from it in the entry points.

## Rules, and why

- **fp32 only.** No `double`. darktable's fp64 maths is redesigned for fp32 and the change noted in the port spec.
- **Never rely on NaN or infinity checks.** WGSL implementations may assume they never occur, so `isnan` can compile to `false`. Sanitise at the operation boundary instead: clamp negative input where the maths needs it, guard divisions and logarithms against zero, clamp exponents (`exp(clamp(t, -80, 80))`).
- **Never write a local vector component or array element at an index known only at run time** (`sum[c] += v`, `color[f] = v`; decision 10).
  - **Why:** FXC, the Direct3D 12 shader compiler the engine pins, cannot compile a write to a local vector component at a run-time index. It tries to unroll the loop around the write, and naga's loop bounding stops it, so the kernel fails on Direct3D 12 alone, WARP included, as CI showed. FXC is pinned in `gpu::instance_descriptor`, because wgpu's default, `Auto`, would use any `dxcompiler.dll` it finds, a C++ library (decision 5) and a compiler CI never runs.
  - **Instead:** `import components;` and write `sum = add_at(sum, c, v)` or `color = set_at(color, f, v)`. They compare `c` with every component's index at once and select, so component `c` alone changes and the others keep their values exactly, infinities included. Building a vector from constant components, as `float3(mean(0), mean(1), mean(2))`, is fine where it reads more clearly.
  - **What counts:** a function-local or `static` (private) variable, vector or array, at any run-time index; and a vector component in `groupshared` memory at a run-time index. Only the local vector components are confirmed to fail on Windows CI; local arrays and `groupshared` vector components are refused until tested on Windows.
  - **Allowed:** reading at a run-time index; writing a `groupshared` array's element at one; anything in a storage buffer, which naga writes at a computed offset.
  - **Check:** the engine's naga test (`no_kernel_writes_a_local_at_a_run_time_index` in `crates/engine/tests/naga.rs`) walks every kernel's naga IR, the engine's and every operation's, on any machine. The engine will run the same check on third-party kernels at load.
- **Storage buffers by default.** Textures only where hardware sampling helps: resampling, lens distortion, rotation; geometry interpolates in its kernel with darktable's interpolators, never by hardware filtering, whose precision differs between GPUs (decision 16). A storage texture the kernel writes is `[format("rgba8")] WTexture2D<float4>` with `.Store(xy, value)`: `RWTexture2D` compiles to `read_write` access, which WebGPU only allows for a few 32-bit formats.
- **Keep data on the GPU.** No readback between modules; a readout's counts are the session's to read back (decision 19).
- **Uniform layout.** Lay out parameter structs in 16-byte steps: vectors as `float4` or `uint4` (a `float3` member invites alignment mismatches), scalars in groups of four or padded, arrays only of 16-byte elements. The Rust side writes the bytes field by field, little-endian, in the same order; give it a test that the byte length matches the struct, as `src/preview.rs` does.
- **Scale-aware neighbourhoods.** A radius given in image pixels scales with the processing resolution, as darktable scales it with `roi->scale`, or the preview and the export differ; a branch darktable takes on a scaled length follows the full-resolution length, so every pipe does the export's processing (decision 15; `port-module`); an iterated box mean's passes take radii r and r + 1 below scale 1, so that its variance is the export's (decision 63), each pass's radius in its own uniforms.
- **Tile-aware positions.** A tile renders part of the image (decision 13): a kernel whose maths depends on position adds the pass header's origin, so a tile computes what the whole image would. A spatial kernel after demosaic (decision 13) reads its input region, larger than its output by the operation's reach: it indexes the input from absolute coordinates less the input's origin, which its uniforms carry, treats only the image's edges as edges, from the header's full size, never its region's, and computes each output pixel in an order fixed relative to that pixel (no sums slid across a workgroup, no partial sums shared between pixels whose order depends on where the workgroup starts), so a tile equals the untiled image bit for bit wherever it begins. Raw-stage kernels place their images on the sensor through their own origin parameters instead, and get a header origin of 0, but for a row strip's first row (decision 14).
- **Write workgroup memory before reading it.** Every `groupshared` element a workgroup reads, it writes first, behind a barrier, as a count clears its counts (A count, above); never rely on it starting at zero. WebGPU zero-initialises workgroup memory today, which naga's Metal backend does from one invocation per workgroup and which slowed a pass of haze removal's guided filter from 13 to 140 ms at 10 MP on the M4; the engine is to turn that off per kernel, for a kernel that says it keeps this rule, so one that reads the zeros would then read garbage (`docs/ports/hazeremoval.md`, Workgroup memory's zero-initialisation).
- **Licence header** first in every `.slang` file (AGENTS.md), with darktable's copyright line on ports. `build-kernels.sh` copies it into the generated WGSL.

## Differentiability

The pipeline is meant to be differentiated end to end, so kernels are written for it from the start (`docs/ai.md`, The differentiable pipeline).

- **Continuous parameters, and no unnecessary hard clamps, thresholds or branches.** Where one is genuinely needed (clipping, a mask edge), keep it and note in the spec the smooth approximation an optimiser would use.
- **More values than the four derivative outputs**, as a curve's knots: let the uniform name the four the derivative entry points take (gradient slots), substitute the slots' values for the table's by comparison in the differentiable function, and have `main` pass a literal `false` that skips the substitution, which then costs nothing measurable (`crates/op/rgbcurve`).
- **Mark constants `no_diff`**: the input pixel when only parameters are differentiated, lookup indices (`no_diff floor(x)`, since `floor` and `ceil` have no derivative), and non-differentiated parameter structs.
- **Use `pow0` from the colour library, never `pow`.** Slang's built-in derivative of `pow` is zero for bases below 1e-6, where a power under 1 is steep and colour maths spends much of its time (the JzAzBz curve divides XYZ by 10000). `pow0` carries its own derivatives.
- **Never let a branch decide which table entries a differentiable function reads.** Slang's backward pass saves the entries the forward pass read, but recomputes the branch condition, and on Metal the recomputation is not bit-identical. When the two disagree, the backward pass reads an entry that was never saved, as 0. Interpolate unconditionally instead, as `lookup_gamut` does.
- **Expect capped derivatives near zero** from Slang's `sqrt` (and so `length`), which guards below 1e-7. Usually harmless at neutral chroma; know it when a gradient misbehaves there.
- **A loop reverse mode would checkpoint** (grain's 21-position lattice) needs Slang's checkpoint arrays, written at a run-time index (decision 10). Give the function `[ForwardDerivative]` and `[BackwardDerivative]` of its own instead: the forward one runs the loop with `fwd_diff` of its body, and with one differentiable input the backward one is the forward one's slope times `d_out` (`noise` in `crates/op/grain`).
- **slangc 2026.20 crashes** ("internal error: unexpected IR opcode during code emit", to WGSL and SPIR-V alike) on the forward derivative of a function that builds a vector from a `no_diff` scalar parameter, such as `float3(xy, z)` with `no_diff float z`. Leave such a parameter differentiable and pass it constants, whose derivative is 0 (grain's `simplex`).

## Build and validate

```sh
tools/fetch-slang.sh          # pinned slangc (v2026.20) into tools/, checksum-verified; build-kernels.sh calls it
tools/build-kernels.sh        # every operation's and the engine's slang/*.slang -> generated/*.wgsl, licence header prepended
tools/build-kernels.sh --check   # lists stale or orphaned generated files; changes nothing
cargo test -p apertrust-operations -p apertrust-engine --test naga  # naga validates every kernel: main always, _backward and _forward_diff when the kernel declares derivatives; no write at a run-time index
```

Claude Code's project hook runs the build and naga test after every `.slang` edit and sends failures back (AGENTS.md, Project skills). The hook is Claude-specific. When it is not running, do the same check yourself after editing a `.slang` file: run `tools/build-kernels.sh`, then the naga test above; fix failures before continuing.

Add a new operation's `KERNEL` to `KERNELS` in `apertrust-operations`, or an engine kernel to the engine's list, before testing, or naga never sees it. Commit the generated WGSL with its source: its diff is the review of what changed on the GPU.

## Check results

For a darktable port, with a golden case (`port-module` covers adding one):

```sh
cargo run --release -p apertrust-golden -- run CASE [--heatmaps DIR]       # ΔE2000 against darktable, then timing
cargo run --release -p apertrust-golden -- gradient CASE [--explain]       # reverse vs finite differences vs forward
cargo run --release -p apertrust-golden -- gradient CASE --synthetic       # the same on a hue, saturation and level sweep
cargo run --release -p apertrust-golden -- run CASE --repeat 32            # arithmetic cost, with memory traffic made negligible
```

- The gradient check passes below 1% relative error against finite differences, with forward and reverse mode agreeing per pixel within 1e-4. If the two modes disagree, the generated derivative code is wrong somewhere; read `references/debugging-derivatives.md`.
- Timing: `run` warms the GPU up, then times in rounds with GPU timestamps. Compare medians and minimums over several runs, never single runs; the MacBook Air throttles.

## Performance

- **Simple passes are memory-bound** (decision 8): one full-image pass costs about the same whatever its arithmetic, about 5 ms at 60 MP on the RTX 5060 and 27 ms on the M4 and the Radeon 780M. Fewer passes matter more than cheaper maths.
- **Hence the per-pixel function**: chains of per-pixel modules will be fused into one kernel, and that only works if each module's function is pure and self-contained.
- **Spatial kernels end a chain.** A gather over many taps is bound by its reads; share reads between neighbouring pixels (registers, workgroup memory) when one matters. Stay within WebGPU's default 16 KB of workgroup memory unless a measurement justifies more.
- To measure later: packed RGB at 12 bytes per pixel instead of RGBA at 16 would cut every memory-bound pass by a quarter.
