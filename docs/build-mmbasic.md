# Build MMBasic

This page documents the repeatable MMB4L build flow for a Luckfox Lyra PicoCalc.

## Prerequisites

- Clone this repository with submodules:

  ```powershell
  git clone --recurse-submodules <this-repo-url>
  ```

- Build or install the Luckfox Lyra PicoCalc SDK in WSL.
- Set `LUCKFOX_SDK_DIR` if the SDK is not in one of the default discovery
  locations:

  ```sh
  export LUCKFOX_SDK_DIR=/path/to/picocalc-luckfox-lyra/SDK
  ```

The build expects the SDK to provide:

- `buildroot/output/rockchip_rk3506_picocalc_luckfox/host/bin/arm-buildroot-linux-gnueabihf-gcc`
- `buildroot/output/rockchip_rk3506_picocalc_luckfox/host/bin/arm-buildroot-linux-gnueabihf-g++`
- `buildroot/output/rockchip_rk3506_picocalc_luckfox/host/arm-buildroot-linux-gnueabihf/sysroot/usr/include/SDL2/SDL.h`
- `buildroot/output/rockchip_rk3506_picocalc_luckfox/host/arm-buildroot-linux-gnueabihf/sysroot/usr/lib/libSDL2.so`
- `buildroot/output/rockchip_rk3506_picocalc_luckfox/host/arm-buildroot-linux-gnueabihf/sysroot/usr/include/curl/curl.h`
- `buildroot/output/rockchip_rk3506_picocalc_luckfox/host/arm-buildroot-linux-gnueabihf/sysroot/usr/lib/libcurl.so`

## Verify Environment

From the repository root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-environment.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\run-armhf-probe.ps1
```

The probe should print:

```text
probe_exit:42
```

## Build

From Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-mmbasic.ps1
```

From WSL:

```sh
bash scripts/build-mmbasic-wsl.sh
```

The binary is written to:

```text
build/mmb4l-luckfox-release/mmbasic
```

## Smoke Test On PicoCalc

With the PicoCalc connected over ADB:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-test-mmbasic.ps1
```

The smoke test pushes the binary to `/tmp/mmbasic`, runs `--help`, runs
`--version`, creates a tiny BASIC program under `/tmp`, runs it, and removes the
temporary target files.

Expected BASIC output includes:

```text
hello from mmbasic on picocalc
 42
smoke_exit:0
```

## Notes

The upstream MMB4L CMake project defaults to desktop SDL2 paths and defines many
test targets. The wrapper copies `mmb4l/` into `build/mmb4l-luckfox-source`,
applies patches from `patches/mmb4l/`, builds only the `mmbasic` target, and
passes the SDK SDL2 include/library paths without editing the upstream
submodule.

The current build patches are documented in [patches.md](patches.md).

After building, install the binary and upstream BASIC examples/tests on the
PicoCalc with [deploy.md](deploy.md).
