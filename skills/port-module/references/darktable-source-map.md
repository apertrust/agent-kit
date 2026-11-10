# Where things live in darktable's source

A guide for the spec-extraction step. Paths are relative to the darktable checkout (`$DARKTABLE_SRC`). Read them as they are in the reference release, not in the checkout's working tree, which is usually a newer master:

```sh
git -C "$DARKTABLE_SRC" show $DT_TAG:src/iop/<name>.c
```

`$DT_TAG` is the reference release's tag, set in the skill's Step 1. darktable reorganises files occasionally, so check paths against that tag.

## The module file: `src/iop/<name>.c`

A processing module is one C file. The parts that matter for a port:

| Part | What to extract |
| --- | --- |
| `dt_iop_<name>_params_t` | The parameter struct. Comments such as `// $MIN: 0.0 $MAX: 1.0 $DEFAULT: 0.5 $DESCRIPTION: "..."` drive darktable's introspection and give ranges, defaults and labels. |
| `DT_MODULE_INTROSPECTION(<version>, ...)` | The current parameter version. |
| `legacy_params()` | Migration from every older parameter version. |
| `default_colorspace()` | The colour space the module works in (raw, RGB or Lab). |
| `commit_params()` | Turns user parameters into processing data (`dt_iop_<name>_data_t`). |
| `init_pipe()`, `cleanup_pipe()` | Per-pipeline state. |
| `process()` | The CPU implementation: the reference behaviour. May call SSE or other vectorised variants; follow the plain path. |
| `process_cl()` | The OpenCL host code, which sets up kernels from `data/kernels/`. |
| `modify_roi_in()`, `modify_roi_out()` | Region-of-interest changes and neighbourhood requirements. |
| `tiling_callback()` | Memory and overlap needs for tiled processing; its overlap, from the parameters and the scale, becomes the operation's reach, `Operation::reach` (decision 13). |
| `reload_defaults()` | Defaults that depend on the image (camera, raw or not). |
| `gui_*` functions | User interface only. Ignore for the port, but they can explain what a parameter means. |

## OpenCL kernels: `data/kernels/*.cl`

Kernels for `process_cl`, often grouped by theme (`basic.cl`, `colorspaces.cl`, and so on). Compare with the CPU code and note differences in the spec.

## Shared code: `src/common/`

Helpers many modules use. Common ones:

- colour space conversions and inline colour maths (look for `colorspaces_inline_conversions.h`);
- maths helpers and fast approximations (`math.h` and similar);
- image and buffer helpers;
- filters used by several modules, such as guided filters, bilateral grids and Gaussian blurs.

When a module calls a shared helper, port the helper as a Slang module of its own rather than inlining it, so other ports can reuse it: inside the port's crate, with its Rust reference beside it, until a second port needs it, which then moves it to a shared crate (decision 65).

## The pipeline: `src/develop/`

- **`imageop.c` / `imageop.h`:** the module interface.
- **`pixelpipe_hb.c`:** how modules are chained, including preview and full pipes.
- **`blend.c`:** blending and masks. Apertrust handles these in its layer system, so read only to understand how a module's output gets blended.
- **`src/common/iop_order.c`** (not under `src/develop/` in the reference release): the default module order (`v50_order`), the basis for each operation's slot: its stage and order number (decision 21). Its list order, not the numbers, is darktable's real order: lut3d, numbered 36, is listed after filmic rgb (46). In the first pass every operation keeps darktable's place, as `crates/operations/order.md`'s table lists them (decision 22).

## Finding where a parameter is used

Search for the parameter's field name across the module file and its kernels, at the reference release:

```sh
git -C "$DARKTABLE_SRC" grep -n "<field>" $DT_TAG -- src/iop/<name>.c 'data/kernels/*.cl'
```

## Finding when a module last changed

```sh
git -C "$DARKTABLE_SRC" log --oneline $DT_TAG -- src/iop/<name>.c data/kernels/<file>.cl
```

And what changed after the reference release, for a spec's open questions (`upstream` being the remote that points at darktable-org/darktable):

```sh
git -C "$DARKTABLE_SRC" log --oneline $DT_TAG..upstream/master -- src/iop/<name>.c
```
