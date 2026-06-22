# WSL Cross Compiler Setup

Use WSL to build ARM hard-float binaries for the Luckfox Lyra PicoCalc.

The current target is:

- WSL distro: `Ubuntu-22.04`
- Preferred compiler family: `arm-buildroot-linux-gnueabihf`
- Target ABI: ARMv7 hard-float
- Preferred source: the Luckfox Buildroot SDK host toolchain

## Preferred SDK Toolchain

The userland toolchain comes from the Luckfox SDK. Set the SDK location in WSL
when it is not in a default discovery location:

```sh
export LUCKFOX_SDK_DIR=/path/to/picocalc-luckfox-lyra/SDK
```

The discovery script also checks these conventional locations under the current
WSL user's home directory:

```text
$HOME/luckfox-lyra-build/picocalc-luckfox-lyra/SDK
$HOME/luckfox-lyra-archive/pre-latest-sdk-*/luckfox-lyra-build/picocalc-luckfox-lyra/SDK
```

The compiler should be under:

```text
SDK/buildroot/output/rockchip_rk3506_picocalc_luckfox/host/bin/arm-buildroot-linux-gnueabihf-gcc
```

The sysroot should be under:

```text
SDK/buildroot/output/rockchip_rk3506_picocalc_luckfox/host/arm-buildroot-linux-gnueabihf/sysroot
```

## Verify Toolchain

From Windows PowerShell:

```powershell
$wslRepo = (wsl.exe wslpath -a (Get-Location).Path).Trim()
wsl.exe -d Ubuntu-22.04 -- sh -lc "cd '$wslRepo' && bash scripts/setup-wsl-cross-compiler.sh"
```

Or run the discovery script directly:

```powershell
$wslRepo = (wsl.exe wslpath -a (Get-Location).Path).Trim()
wsl.exe -d Ubuntu-22.04 -- sh -lc "cd '$wslRepo' && bash scripts/find-wsl-toolchain.sh"
```

Expected machine:

```text
arm-buildroot-linux-gnueabihf
```

## Generic Apt Fallback

The generic Ubuntu `arm-linux-gnueabihf` compiler is not the default because it
does not guarantee the same sysroot as the Luckfox Buildroot image.

Install it only as an explicit fallback:

```powershell
$wslRepo = (wsl.exe wslpath -a (Get-Location).Path).Trim()
wsl.exe -d Ubuntu-22.04 -- sh -lc "cd '$wslRepo' && bash scripts/setup-wsl-cross-compiler.sh --install-apt-fallback"
```

## ABI Probe

After ADB works from Windows, build and run a tiny target binary:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-armhf-probe.ps1
```

Expected result:

```text
probe_exit:42
```

## Sysroot Caution

The PicoCalc image uses Buildroot and glibc 2.38. Ubuntu cross packages may be
enough for a first probe, but a matching Luckfox or Buildroot SDK sysroot is the
safer long-term build source for SDL2 and runtime compatibility.
