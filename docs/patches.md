# Build Patches

This project keeps upstream MMB4L as a submodule and stores local build changes
as patch files under `patches/mmb4l/`.

The current patches are documented in
[patches/mmb4l/README.md](../patches/mmb4l/README.md).

## How Patches Are Applied

The build wrapper:

1. Copies `mmb4l/` to `build/mmb4l-luckfox-source`.
2. Normalizes line endings in the generated copy.
3. Applies every `patches/mmb4l/*.patch` file in filename order.
4. Configures CMake against the generated source copy.
5. Builds `build/mmb4l-luckfox-release/mmbasic`.

The `mmb4l/` submodule is not modified.

Deployment also uses the generated patched source copy for BASIC examples and
tests when `build/mmb4l-luckfox-source` exists. That means target-side test
runs exercise the same patch queue as the built binary.

## Why This Model

This keeps attribution and source ownership clear:

- upstream MMB4L remains from `thwill1000/mmb4l`
- local repeatability work lives in this repository
- build fixes are visible as reviewable patches
- future upstream submissions can be made patch by patch

If the patch queue grows large, the next step should be a public fork of MMB4L
plus continued attribution to the original upstream project.
