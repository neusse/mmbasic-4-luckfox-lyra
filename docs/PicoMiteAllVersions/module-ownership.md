# Module Ownership Map

Date: 2026-06-22

This document assigns logical ownership areas for the current source tree. "Owner" here means the subsystem responsible for design intent, review attention, and regression testing. It does not imply a person owns the files.

## Ownership Principles

- Changes should be reviewed against the owning subsystem, not only the file name.
- Files in the interpreter core should avoid depending on board-specific behavior unless there is no practical alternative.
- Hardware-facing files should expose narrow APIs rather than pulling unrelated interpreter state into every module.
- Vendored/library-style files should be patched only when there is a concrete upstream or firmware integration reason.
- Variant behavior belongs in `CMakeLists.txt` and documented feature gates first, then in C preprocessor checks only where needed.

## Core Ownership Areas

| Area | Primary files | Owns | Review focus |
| --- | --- | --- | --- |
| Build and variants | `CMakeLists.txt`, `pico_sdk_import.cmake`, `BuildPicoMite.bat`, `buildpicomite.bat`, `BuildPicoMiteFR.bat`, `GetHighestHexAddress.py` | Variant selection, board mapping, source inclusion, compile definitions, size checks | Does every variant get the intended board, sources, defines, libraries, heap, and stack? |
| Boot and board runtime | `PicoMite.c`, `configuration.h`, `Version.h`, `gpio.c`, `psram.c` | Startup, reset handling, board init, clocks, console integration, RP2040/RP2350 differences | Does hardware init order remain valid? Are board assumptions isolated? |
| Interpreter core | `MMBasic.c`, `MMBasic.h`, `MMBasic_Includes.h`, `AllCommands.h`, `Commands.h`, `Functions.h`, `Operators.h`, `Custom.h` | Tokenization, command/function dispatch, variables, control flow, interpreter errors | Does command registration remain consistent? Are globals and parser side effects controlled? |
| Core commands | `Commands.c`, `Functions.c`, `Operators.c`, `Custom.c`, `CFunction.c`, `PicoCFunctions.h` | BASIC language commands, functions, operators, CSUB/CFunction integration, PIO assembly commands | Does command behavior match MMBasic syntax and runtime expectations? |
| Runtime services | `MM_Misc.c`, `Memory.c`, `MMtrace.c`, `MATHS.c`, `re.c`, `aes.c` | Options, timers, profiling/cache, memory allocation, math utilities, regex, crypto helper use | Does shared runtime state remain coherent across interrupt and command paths? |
| File systems and storage | `FileIO.c`, `ff.c`, `ff.h`, `ffconf.h`, `ffsystem.c`, `ffunicode.c`, `diskio.h`, `lfs.c`, `lfs.h`, `lfs_util.c`, `mmc_stm32.c` | FAT/littlefs integration, SD/MMC, file commands, storage state | Are file handles, mount state, and storage timing safe across variants? |
| Console, editor, transfer | `Editor.c`, `XModem.c`, `Keyboard.c`, `KeyboardMap.c`, `USBKeyboard.c`, `mouse.c`, `BTConsole.c`, `BTKeyboard.c`, `nus_gatt.gatt` | Console input/output, editor, file manager, transfer protocols, USB/Bluetooth input | Does input routing remain correct for USB, PS/2, CDC, BT console, and BLE HID host variants? |
| Graphics and display | `Draw.c`, `Draw.h`, `DrawInternal.h`, `Draw3D.c`, `DrawFill.c`, `FrameBuffer.c`, `GUI.c`, `SPI-LCD.c`, `SPI-LCD.h`, `SSD1963.c`, `SSD1963.h`, `SSD1963min.c`, `Touch.c`, `VGA222.c`, `VGA222.h`, `RGB121.c`, `RGB121.h`, `Pointer.c` | Drawing primitives, framebuffers, GUI controls, display drivers, touch/pointer behavior | Are memory budgets, display modes, and touch/mouse behavior valid for each display family? |
| Game and visual extensions | `Sprite.c`, `TileMap.c`, `Raycaster.c`, `Raycaster.h`, `Turtle.c`, `Turtle.h`, `Blit.c`, `BmpDecoder.c`, `picojpeg.c`, `picojpeg.h`, `upng.c`, `upng.h` | Sprites, tile maps, raycaster, turtle graphics, bitmap/image decoding | Are optional features included only where memory and framebuffer support exist? |
| Hardware IO | `External.c`, `I2C.c`, `I2C.h`, `SPI.c`, `SPI.h`, `Serial.c`, `Serial.h`, `Onewire.c`, `Onewire.h`, `GPS.c`, `GPS.h`, `goodix.c`, `pio.h`, `pio_instructions.h`, `PicoMiteI2S.pio`, `PicoMiteVGA.pio` | GPIO, pin configuration, buses, serial ports, GPS, PIO support, device protocols | Are pin modes, interrupts, DMA, and timing safe across RP2040/RP2350 and package variants? |
| Audio | `Audio.c`, `Audio.h`, `VS1053.c`, `VS1053.h`, `vs1053b-patches.h`, `dr_wav.h`, `dr_mp3.h`, `dr_flac.h`, `hxcmod.c`, `hxcmod.h` | Audio playback, codecs, VS1053 support, sample/mod playback | Are buffers, interrupts, DMA/PWM/I2S, and storage reads coordinated? |
| Networking and web | `MMMqtt.c`, `mqtt.c`, `MMTCPclient.c`, `MMtcpserver.c`, `MMtelnet.c`, `MMntp.c`, `MMudp.c`, `MMtftp.c`, `tftp.c`, `cJSON.c`, `cJSON.h`, `lwipopts.h`, `lwipopts_examples_common.h`, `mbedtls_config.h` | WebMite networking, MQTT, TCP server/client, Telnet, NTP, UDP, TFTP, TLS, JSON | Are lwIP, TLS, heap, stack, and CYW43 assumptions valid for Web variants? |
| Third-party/library code | `ff*`, `lfs*`, `cJSON.*`, `dr_*.h`, `picojpeg.*`, `upng.*`, `re.*`, `aes.*`, `hxcmod.*` | Imported algorithms or protocol/library implementations | Prefer upstream-compatible patches and clear comments for local changes. |
| Documentation and hardware artifacts | `README.md`, `docs/`, `docs/PicoMite_User_Manual.pdf`, `Pico Computer/` | User manuals, reference documents, PCB/schematic/manufacturing files | Keep setup/build guidance aligned with current CMake variants and external dependency versions. |

## Cross-Cutting Review Rules

### Variant changes

Any change that touches `CMakeLists.txt`, `configuration.h`, `Hardware_Includes.h`, or a compile definition should be reviewed against `docs/variant-build-matrix.md`.

### New MMBasic command or function

Review all of these together:

- Declaration in the relevant header.
- Command/function implementation file.
- Table entry under the correct macro mode.
- Variant guards.
- Documentation update.
- At least one smoke program or host-side parser test, when possible.

### New hardware feature

Review all of these together:

- Pin ownership and conflicts.
- Interrupt/DMA/core usage.
- RP2040 vs RP2350 behavior.
- Memory impact.
- USB/Web/Bluetooth interaction.
- User command/API documentation.

### Vendored file change

Before patching a vendored/library-style file, record:

- Why the local patch is needed.
- Whether upstream has the same fix.
- Which variants exercise the code.
- How to reapply the patch if the library is refreshed.

## Suggested Future Split

If the tree is reorganized later, do it incrementally:

```text
src/
  interpreter/
  runtime/
  commands/
  hardware/
  display/
  filesystem/
  network/
  audio/
  games/
  vendor/
tools/
docs/
boards/
```

Do not move files until the build matrix can be checked automatically. The current flat layout is noisy, but broad moves without build coverage would create unnecessary risk.
