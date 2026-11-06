---
name: golden-tests
description: Apertrust's golden-image harness (apertrust-golden) and its other baselines - adding a case from darktable's integration tests, rendering darktable-cli references, running a kernel against them, reading ΔE2000 results and heatmaps, the gradient check, timing, tolerances, and when a baseline may change (never automatically). Also the raw decoding corpus's expectations. Use this whenever a task adds or changes a golden case, runs or interprets `apertrust-golden`, asks why a module differs from darktable, touches a tolerance, re-renders references, or blesses changed expectations, even if the user only says "does exposure still match darktable" or "the colorbalancergb case fails".
---

# Golden tests

Image quality in Apertrust is judged by numbers, never by eye: during the migration, each ported module's output is compared with darktable's render of the same module on the same input, in CIEDE2000 (AGENTS.md, Correctness). The migration ends once, for the whole project, when every first-pass module is in the app and passes its comparisons, at the end of Phase 3; from then on the baselines are Apertrust's own renders (decision 2, below). The harness is `crates/golden`; it runs locally, because it needs darktable itself (decision 61).

## What a case is

A case isolates one darktable module (operation) on one raw. darktable renders two images from the case's sidecar, full resolution, linear Rec2020 PFM:

- **input**: the sidecar's history with the module switched off, the module's input;
- **expected**: with the module on.

Apertrust runs its kernel on *input* and compares with *expected*. Everything else in the pipeline is darktable's in both, so the comparison measures only the module.

Cases live in `crates/golden/src/cases.rs`, sidecars in `crates/golden/cases/<case>.xmp`, and the translation from darktable's parameters to the kernel's inputs in `src/ports.rs`.

| `Case` field | Meaning |
| --- | --- |
| `name` | the case's name on the command line |
| `operation` | the darktable module under test, which also selects the kernels in `KERNELS` |
| `image` | a raw from darktable's integration-test images |
| `xmp` | the sidecar, embedded with `include_str!` |
| `disable` | later modules switched off in both renders, such as `filmicrgb`, so they don't distort the comparison |
| `unmask_like` | when the test applies the module through a drawn mask, an unmasked operation whose blend settings replace the module's, so the case covers the whole image (masks belong to Apertrust's layer system) |
| `tolerance` | mean and max ΔE2000; `Tolerance::DARKTABLE` (mean 2.3/3 ≈ 0.767, max 2.3, darktable's own test thresholds) unless argued otherwise |

## Requirements

- **darktable-cli** at the reference release, darktable's latest stable release (`REFERENCE_VERSION` in `crates/golden/src/darktable.rs`, decision 3), found through `DARKTABLE_CLI`, then `PATH`, then the platform's default install location. The harness refuses any other version.
- **`APERTRUST_TEST_IMAGES`**: darktable's integration-test images, e.g. `$DARKTABLE_SRC/src/tests/integration/images` in a clone of darktable.
- `--release` for everything: ΔE over a 10 MP image is slow in debug builds.

## Commands

```sh
cargo run --release -p apertrust-golden -- list
cargo run --release -p apertrust-golden -- render [CASE...]                 # references, cached under target/golden
cargo run --release -p apertrust-golden -- run [CASE...] [--heatmaps DIR]   # ΔE against darktable, then timing
cargo run --release -p apertrust-golden -- gradient [CASE...] [--explain] [--synthetic]
cargo run --release -p apertrust-golden -- compare EXPECTED.pfm ACTUAL.pfm --case NAME --heatmap diff.png
cargo test --release -p apertrust-golden -- --ignored                      # end-to-end check of the harness itself
```

References are cached in `target/golden/<case>/<key>/`, keyed by the reference version, the render options, both sidecars and the raw. Changing a case re-renders it on the next run; nothing needs clearing by hand.

## Adding a case

1. **Start from darktable's integration tests**, `src/tests/integration/<NNNN>-<name>/<name>.xmp` in the darktable checkout: they exercise the module on a known image. Copy the sidecar to `cases/<case>.xmp` and note the test number in a comment on the `Case`.
2. **Isolate the module**: list later modules that change the result in `disable`, and set `unmask_like` if the test masks the module.
3. **Cover what the tests don't**: to test a mode no integration test uses, copy a sidecar and edit the module's `params` (hex, or `gz` + base64 zlib), as the `blurs-motion` case on branch `blur` swaps a lens blur for a motion blur. Say in the `Case`'s comment what was changed.
4. **Render and check the module's effect**: `render <case>` prints the ΔE between input and expected. Near zero means the case isolates nothing: wrong operation, the module disabled in the sidecar, or a later module undoing it.
5. **Translate the parameters** in `ports.rs`: decode every params version the case can contain, and return the kernel's `KernelInputs`, or, for a case of several passes, `plan_values` and `perturbed_values`; add `gradient_parameters` and `perturbed_inputs` for the gradient check.

**Cases of several passes** (decision 15). An operation whose `prepare` returns more than one pass or any scratch buffer, such as the tone equalizer's filtered masks, cannot run as one kernel's `main`. `ports::plan_values` returns its schema values instead, decoded from darktable's params, as colour balance rgb's case already builds them, and `ports::perturbed_values` those values with a gradient parameter moved. `run` plans the operation as a one-instance plan of the engine (`pipeline::plan` on the case's RGBA input, the export pipe), its context from `ports::plan_context`, the input's size with the case raw's camera from rawler (its identity included, decision 24), since the tone equalizer measures its radius on the raw's readout as darktable does, and its input descriptor from `ports::plan_input`, which sets what darktable's pipe carries at the module from the sidecar's earlier modules, temperature's coefficients as `white_balance` for denoise (decision 15); renders it, compares its output and times whole renders, summing the passes' GPU timestamps. `gradient` takes the derivatives of the pass that writes the output, which the engine dispatches with that pass's bindings and the derivative buffers over the scratch the forward render left. Single-pass cases keep the kernel path until they move, and their numbers must not change when they do.

**A case's output profile** (decision 26). Where an operation reads the pipe's output profile (filmic rgb's v6 and v7, AgX's "export profile"), a case can set one: darktable-cli renders the expected output with `--icc-type` set to it, the case's plan appends colorout of that `type`, so the planner hands the operation the profile through colorout's hook, and both sides are decoded from that profile to linear Rec2020 before ΔE2000, the comparison after colorout. Without one, a case renders linear Rec2020, the working profile, as every case before did. `filmicrgb-v7-srgb` (test 0138 in sRGB, where the working profile's stand-in differs from darktable by up to 10.15 ΔE2000) and `agx-export-profile` are the first.

**darktable's behaviour behind a harness-only setting** (decision 63). Where an agreed departure changes what a port's export renders against darktable-cli's, the case runs darktable's behaviour, through a setting only the harness reaches. The first pass has no such departure: the tone equalizer renders darktable's curve. The pattern, for an agreed departure: the operation crate exposes it to `apertrust-golden` as a typed setting outside the schema that only `ports.rs` sets, never through the schema, an edit or a module. The case then checks everything but the departure against darktable, and the operation's invariant tests check the departure. Say in the `Case`'s comment that it runs darktable's behaviour, and why.

## Reading results

`run` prints, per case: time per pass, and ΔE2000 mean, p95 and max, with how many pixels exceed the max tolerance.

- **The mean** says whether the maths is right overall; a port with a real error shows a mean well above zero.
- **The max and its pixels** say where it is wrong: write heatmaps with `--heatmaps DIR` and look at where the large values sit. Saturated colours point at gamut handling, edges at a neighbourhood or scale problem, dark areas at black handling or a `pow` near zero, everything uniformly at a matrix or a parameter's units.
- Existing results to compare with are recorded in each port spec (`docs/ports/<module>.md`); colorbalancergb, for example, is mean 0.0057 and max 0.65.

`gradient` checks the kernel's derivatives, the loss being the sum of the output's RGB: reverse mode against central finite differences (passes below 1% relative error) and against forward mode per pixel (within 1e-4). The finite differences step each parameter by 1e-3 in its own units, or by a case's own step from `ports::gradient_step`: the tone equalizer's filtered cases take 3e-2 EV, since at 1e-3 the f32 rounding of two whole renders outweighs their smallest totals; `--step` sets one step for every case. `--synthetic` runs on a hue, saturation and level sweep that needs no darktable, and `--explain` shows where a gap sits. The `slang-kernels` skill's debugging reference covers failures. The loss cannot see a parameter that keeps the channels' mean (vignette's saturation): check it in the port's GPU tests with unequal channel weights, as `crates/golden/tests/vignette.rs` does. Where the case's own image sees such a parameter but the synthetic sweep, grey on average, does not (rgb primaries' hues and purities, since grey maps to the white whatever the primaries), keep it in the case's slots and name it in `ports::sweep_blind` with the reason: `gradient --synthetic` skips it and reports it as sweep-blind, `gradient` on the case still checks it, and the GPU tests check it per pixel. Nor can its f32 finite differences resolve a parameter whose step moves values every pixel shares by less than their rounding (grain's mid-tones bias, through its table), or whose total is what is left of per-pixel terms of both signs (grain's size, a noise's scale): check those per pixel against a float64 model of the kernel in the port's GPU tests, as `crates/golden/tests/grain.rs` does, name them in no case's slots, and say why in `ports.rs` and the spec.

Timing: `run` checks ΔE first, then warms the GPU up (`--warmup-ms`, 500 by default) and times the kernel in rounds (`--rounds`, `--iterations`), with GPU timestamps where the device has them. `--repeat 32` measures arithmetic rather than memory traffic. A case run as a plan is timed by whole renders, and `--repeat` does not apply to it. Compare medians and minimums over several runs, never single runs: the passively cooled MacBook Air throttles. `WGPU_POWER_PREF=low` selects an integrated GPU over a discrete one.

## Raw-stage operations (decisions 21 and 23)

A case switches its module off and on, which demosaic does not allow, and darktable cannot export a mosaic, so raw-stage operations (rawprepare, temperature, highlight reconstruction, demosaic) are compared as a chain, through demosaic's photosite-colour passthrough: darktable renders each photosite, black-subtracted, scaled and white balanced, in its own colour's channel, with colorin set to linear Rec2020 (an identity) and everything after it off (`src/raw_stage.rs`). Four commands. The three raw-stage ones take names in `APERTRUST_TEST_IMAGES` or paths (every raw at its top level by default; pass the corpus through `find … -print0 | xargs -0`); `pipeline` needs the raw.pixls.us corpus, not the integration images (`test-images/raw.pixls.us`, or `APERTRUST_RAW_CORPUS`), and takes paths or corpus names, `<Make>/<Model>/<file>`; by default every sample its manifest, `crates/raw/tests/corpus/files.sha256`, lists, so a sample missing from disk fails. A raw is skipped only when it is not a 16-bit colour mosaic, rawler cannot decode it, or darktable-cli's loader rejects it. A rejection is darktable's exact rawspeed line for the file: `[rawspeed] Unsupported camera model for FILE` or `[rawspeed] FILE corrupt: …`. Any other darktable failure, such as a crash or a history it cannot open, is a FAIL. So is any other error. `pipeline` also fails a skip of any sample not in `EXPECTED_SKIPS` (`src/main.rs`), or one skipped for another reason than its listed one, and notes an entry that has gone stale. A run passes only when it checked at least one raw and none failed; its last line counts the raws checked, passed, failed and skipped.

- **`raw-passthrough`** needs no port: rawler's crop, black levels, white point and as-shot coefficients go into darktable's rawprepare and temperature, and the harness compares the render with a CPU computation from rawler's decode. It confirms that darktable crops the same uncropped mosaic as rawler and that colorin is an identity.
- **`raw-run`**, the kernel cases: the raw stage's ports (rawprepare, temperature, highlight reconstruction, demosaic) and colorin run on the GPU with their defaults for each image, and the same parameters go into darktable's history: rawprepare's crop and levels, temperature's coefficients and preset, highlights' method and threshold, demosaic's method and colorin's profile (the embedded matrix for a DNG, the standard one otherwise). Temperature's preset is Apertrust's default, "as shot to reference" wherever the camera has a colour matrix (decision 27), so it checks colorin's late correction, highlight reconstruction's weighting by it and a DNG's CameraCalibration (decision 24); `--as-shot` sets "as shot" on both sides, so the path without the correction keeps a check against darktable. It compares over the declared crop: a mosaic must agree within 1e-5 everywhere; a demosaiced image passes when its mean difference is under 1e-6 and under 0.05% of its pixels differ by more than 1e-4, where rounding tips a demosaic direction choice (decision 21). A difference here is the kernels'. Each raw-stage port joins this chain.
- **`raw-defaults`**, the decoder cases: rawprepare is removed from darktable's history, so darktable uses its own defaults for the image, and the harness recovers them from the render, fitting a line through the raw values per parity position (black and white) at the crop where the lines fit best, and compares them with Apertrust's. A difference here is the decoders'.
- **`pipeline`**, Phase 1's exit test (decisions 22, 23 and 62): each raw through Apertrust's whole pipeline with its defaults, never a saved edit, as `apertrust-cli export` renders it, tiled when it would not fit, and through darktable-cli with Apertrust's crop, levels, white balance, highlight and demosaic settings and input profile, exposure written as version 7 at Apertrust's effective value with both of darktable's compensations off (the camera's exposure bias, already in that value, and highlight preservation, which Apertrust does not port, decision 21), AgX written as version 7 from Apertrust's parameters, color calibration written as version 3 from Apertrust's parameters too (As shot as darktable's `reload_defaults` snaps it, under CAT16), with temperature "as shot to reference" on both sides (decision 27), and orientation off. Color balance rgb stays off on both sides, since neither runs it on an unedited photo (decision 32). darktable writes a 16-bit PNG (`plugins/imageio/format/png/bpp=16`) in colorout's output profile (sRGB by default; linear Rec2020 and Rec709 are supported, any other is refused). Apertrust's side is the engine's output before the CLI rounds it to 8 bits, clipped to 0 to 1 as a PNG is: 8-bit rounding alone costs a mean ΔE2000 of about 0.2, so never judge the exit test from the CLI's PNG. CIEDE2000 decodes both from the output profile, within the declared image. darktable renders first, so a raw its loader rejects is skipped before the export. Renders are cached as the raw-stage ones are, about 5 bytes a pixel. It passes at a mean ΔE2000 of at most 0.01 and at most 0.01% of pixels over 2.3, the tolerance the user agreed (decision 62). With `--width` or `--height` (and `--hq`, `--upscale`, darktable-cli's flags) it measures an export at a size instead (decision 56, `docs/ports/finalscale.md`): rawprepare crops the raw to its declared image on both sides, so both scale the same image, finalscale moves to darktable's v5.0 place before colorout, since the base history's custom order has it after colorout, and darktable-cli's size must equal Apertrust's; reported without a bound, the user's to set. `--add CASE` puts a case's module on both sides (grain, vignetting, the tone equalizer, haze removal, the colour equalizer, colour balance rgb, local contrast, bloom, soften), and `--darktable-hq BOOL` sets darktable's side's `--hq` apart from Apertrust's, so an export without high quality can be read against darktable's with it (decision 15; `docs/ports/finalscale.md`, Results).

Renders are cached in `target/golden/raw-stage/<image>/<hash>`, keyed by the sidecar and the raw, as float PFMs of 12 bytes a pixel: 1.1 GB for a 96 MP raw, about 14 GB for a new sidecar over the whole corpus. Check the free disk space before a run that changes the sidecar; a change that only matters where photosites clip can run on the raws that have clipped photosites (`docs/ports/highlights.md`).

**Judging a decoder difference** (decision 23). darktable is the reference for processing, not for camera data, so a difference `raw-defaults` reports is a rawler bug only when the evidence says so:

1. **rawler's intent:** its source and comments in `~/.cargo/registry/src/*/rawler-<version>/` (the decoder in `src/decoders/`, the camera file in `data/cameras/`). Code that means one thing and reads another is a bug (ColorData version 48 read its white level one word off).
2. **The manufacturer's metadata,** read independently: `exiftool -s -G1 -a FILE`, `-v3` for the offsets of maker-note fields.
3. **The photosites:** the histogram's floor (noise below a non-zero black) and its clip (where saturated photosites pile up); for a crop, whether the strip in question holds image data, at levels well above black and correlating with the line two steps in.
4. **Upstream:** the file on dnglab's main branch, its history and issues (`gh api repos/dnglab/dnglab/...`), since a fix may already be there.

A bug goes upstream as a fix; a deliberate choice whose reason is unknown goes upstream as a question with the evidence. Nothing is patched locally, and filing anything upstream is the user's call: write the report for the user in plain words, naming the upstream project and the issue, and do not file it yourself. Record each verdict in the port spec's results.

What they found (decisions 21 and 23), and what a raw-stage result should be read against:

- rawprepare's kernel matches darktable within 7.2e-7 on 30 of the 33 mosaics; the other three are Sony's lossy ARWs.
- **darktable's own crop and levels differ from rawler's** on most cameras: the crop on 27 of 33 raws (darktable uses rawspeed's, the DNG default crop on DNGs), white on 5 (the R6 Mark II by 10%), black on 5 (the 40D's, which darktable measures from the masked areas with a known bug, and the NX1's by 128). Apertrust trusts rawler's camera data, its errors fixed upstream, and its final image is the manufacturer's declared size, so crop differences are by design (decision 23); black is the levels the raw stores, so a camera darktable measures differs by a few units (decision 23). Kernel cases are unaffected, since both sides get the same parameters; the whole-pipeline test is not.
- darktable applies a DNG's **gain maps** by default (the Pixel 4a); rawler does not read them.
- **Sony's lossy ARWs** differ by up to 3e-3 on about half the pixels: both decoders dither Sony's lossy curve, but rawler seeds the dither from 16 bits of each row where darktable's decoder takes 24 (decision 23). Don't use them for kernel cases until rawler carries the upstream fix; lossless ARWs match exactly.
- Sensors other than red, green and blue (`bayer4.crw`) are skipped.

## Baselines and tolerances

- **During the migration, the references are darktable's renders, not ours.** They change only when the reference release changes (`REFERENCE_VERSION` in `src/darktable.rs`), which is a project decision for the decision log, followed by re-rendering every case and re-checking every port.
- **After the migration, the baselines are Apertrust's own renders** (decision 2), taken at the commit that completes it and checked with the same tolerances, per GPU. A baseline then changes only by a deliberate change to the processing: a decision in the log that says what changed and why, its size measured (mean and max ΔE2000 per case, per GPU) and stated in the spec, the new renders reviewed like any change before they replace the old. Never re-render to make a check pass. Where these baselines are kept and what the cases' inputs become is still open (`docs/architecture.md`, Open questions); until it is settled the harness works as during the migration. After the migration, docs and results no longer present darktable as the reference.
- **Never change a case, its sidecar or its tolerance to make a port pass.** A stricter tolerance is fine; a looser one needs a written reason in the port spec and the user's agreement.
- **Record results where they belong**: the port spec's golden result and gradient sections, with the GPU used.

The raw decoding corpus is the other baseline: `crates/raw/tests/corpus/expected.txt` pins a fingerprint of every decode of 40 raw.pixls.us samples (`tools/fetch-raw-corpus.sh`, then `cargo test --release -p apertrust-raw -- --ignored`). After a deliberate change, such as a rawler update, `APERTRUST_BLESS=1` rewrites the expectations. Review the diff line by line, and explain every changed file in the commit; never bless to silence a failure you don't understand.
