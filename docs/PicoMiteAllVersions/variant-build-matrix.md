# Variant Build Matrix

Date: 2026-06-22

Source of truth: `CMakeLists.txt`.

The active build is selected with `-DCOMPILE=<variant>`. If `COMPILE` is not supplied, CMake defaults to `WEBRP2350`.

## Valid Variants

| Variant | Platform | Board selected by CMake | Display family | Web/WiFi | USB host | Bluetooth role | GUI controls | Cache | Raycaster | Turtle | Structs/FM |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `PICO` | RP2040 | `pico` | SPI LCD/PicoMite | No | No | No | Yes | Yes | No | Yes | Yes |
| `PICOUSB` | RP2040 | `pico` | SPI LCD/PicoMite | No | Yes | No | Yes | No | No | Yes | Yes |
| `PICOMIN` | RP2040 | `pico` | Minimal SPI LCD | No | No | No | No | No | No | No | No |
| `VGA` | RP2040 | `pico` | VGA | No | No | No | No | No | No | Yes | Yes |
| `VGAUSB` | RP2040 | `pico` | VGA | No | Yes | No | No | No | No | Yes | Yes |
| `WEB` | RP2040 | `pico_w` | SPI LCD/WebMite | Yes | No | No | No | No | No | No | Yes |
| `PICORP2350` | RP2350 | `pimoroni_pga2350` | SPI LCD/PicoMite | No | No | No | Yes | Yes | Yes | Yes | Yes |
| `PICOUSBRP2350` | RP2350 | `pimoroni_pga2350` | SPI LCD/PicoMite | No | Yes | No | Yes | Yes | Yes | Yes | Yes |
| `VGARP2350` | RP2350 | `pimoroni_pga2350` | VGA | No | No | No | Yes | Yes | Yes | Yes | Yes |
| `VGAUSBRP2350` | RP2350 | `pimoroni_pga2350` | VGA | No | Yes | No | Yes | Yes | Yes | Yes | Yes |
| `WEBRP2350` | RP2350 | `pimoroni_pico_plus2_w_rp2350` | SPI LCD/WebMite | Yes | No | No | Yes | No | No | No | Yes |
| `HDMI` | RP2350 | `pimoroni_pga2350` | HDMI | No | No | No | Yes | Yes | Yes | Yes | Yes |
| `HDMIUSB` | RP2350 | `pimoroni_pga2350` | HDMI | No | Yes | No | Yes | Yes | Yes | Yes | Yes |
| `PICOBTRP2350` | RP2350 | `pimoroni_pico_plus2_w_rp2350` | SPI LCD/PicoMite | No | No | BT console | Yes | Yes | Yes | Yes | Yes |
| `PICOBTHRP2350` | RP2350 | `pimoroni_pico_plus2_w_rp2350` | SPI LCD/PicoMite | No | No | BLE HID host | Yes | Yes | Yes | Yes | Yes |
| `HDMIBTH` | RP2350 | `pimoroni_pico_plus2_w_rp2350` | HDMI cutdown | No | Yes | BLE HID host | Yes | Yes | Yes | Yes | Yes |
| `HDMIWEB` | RP2350 | `pimoroni_pico_plus2_w_rp2350` | HDMI cutdown | Yes | Yes | No | Yes | Yes | Yes | Yes | Yes |

Notes:

- `PICOMIN` removes `VS1053.c` and `re.c`, replaces `SSD1963.c` with `SSD1963min.c`, and disables structs and file manager support.
- `WEB`, `WEBRP2350`, and `HDMIWEB` compile `WEB_SOURCES`.
- TLS support is enabled only for `WEBRP2350` and `HDMIWEB`.
- `PICOBTRP2350` is Bluetooth console-oriented.
- `PICOBTHRP2350` and `HDMIBTH` are BLE HID host-oriented.
- `HDMIBTH` and `HDMIWEB` define `HDMICUTDOWN`.
- USB-host variants define `USBKEYBOARD` and use TinyUSB host.

## Source Group Inclusion

| Source group | Files | Included when |
| --- | --- | --- |
| `COMMON_SOURCES` | `PicoMite.c`, `MMBasic.c`, command/runtime/core IO/display/audio files | All variants, with `PICOMIN` removals |
| `DISPLAY_SOURCES` | `SSD1963.c`, `Touch.c` | `WEB`, GUI variants, or `PICOMIN`, except `HDMIWEB` |
| `WEB_SOURCES` | `cJSON.c`, `mqtt.c`, `MMMqtt.c`, `MMTCPclient.c`, `MMtelnet.c`, `MMntp.c`, `MMtcpserver.c`, `tftp.c`, `MMtftp.c`, `MMudp.c` | `WEB`, `WEBRP2350`, `HDMIWEB` |
| Cache | `MMtrace.c` | `PICO`, `PICORP2350`, `PICOUSBRP2350`, `VGARP2350`, `VGAUSBRP2350`, `HDMI`, `HDMIUSB`, `PICOBTRP2350`, `PICOBTHRP2350`, `HDMIBTH`, `HDMIWEB` |
| USB host | `KeyboardMap.c`, `USBKeyboard.c` | `PICOUSB`, `PICOUSBRP2350`, `VGAUSB`, `VGAUSBRP2350`, `HDMIUSB`, `HDMIBTH`, `HDMIWEB` |
| PS/2/basic input | `Keyboard.c`, `mouse.c` | Variants without USB host |
| Bluetooth console | `BTConsole.c`, generated `nus_gatt.h` | `PICOBTRP2350` |
| BLE HID host | `BTKeyboard.c`, `KeyboardMap.c` | `PICOBTHRP2350`, `HDMIBTH` |
| GUI | `GUI.c` | GUI variants, HDMI variants, and RP2350 VGA variants |
| VGA support | `VGA222.c` | `PICOUSBRP2350`, `PICORP2350`, `PICOBTRP2350`, `PICOBTHRP2350` |
| PNG decode | `upng.c` | RP2350 graphics-oriented variants listed in `UPNG_VARIANTS` |
| Turtle | `Turtle.c` | All except Web SPI-LCD and `PICOMIN`; kept for `HDMIWEB` |
| Raycaster | `Raycaster.c` | RP2350 graphics-oriented variants listed in `RAYCASTER_VARIANTS` |
| RP2350 support | `psram.c`, `stepper.c` | All RP2350 variants |

## Common Compile Definitions

All variants receive:

- `NDEBUG`
- `PICO_STDIO_USB_ENABLE_RESET_VIA_VENDOR_INTERFACE=0`
- `PICO_ADC_CLKDIV_ROUND_NEAREST`
- `PICO_XOSC_STARTUP_DELAY_MULTIPLIER=64`
- `PICO_CLOCK_AJDUST_PERI_CLOCK_WITH_SYS_CLOCK`
- `PICO_FLASH_SIZE_BYTES=16777216`
- `PICO_CORE1_STACK_SIZE=0x00`
- `PICO_MALLOC_PANIC`
- `GCODE`

Conditional definitions include:

| Definition | Applies when |
| --- | --- |
| `rp2350`, `PICO_USE_GPIO_COPROCESSOR=1`, `PICO_FLASH_SPI_CLKDIV=4`, `PICO_PIO_USE_GPIO_BASE` | RP2350 variants |
| `PICOMITE` | PicoMite-style variants, including BT/BTH where applicable |
| `PICOMITEMIN` | `PICOMIN` |
| `PICOMITEVGA` | VGA and HDMI display families |
| `HDMI` | HDMI display family |
| `PICOMITEWEB` | Web variants |
| `PICOMITEWEB_TLS` | `WEBRP2350`, `HDMIWEB` |
| `PICOMITEBT` | `PICOBTRP2350` |
| `PICOMITEBTH` | `PICOBTHRP2350` |
| `PICOMITEHDMIBTH` | `HDMIBTH` |
| `PICOMITEHDMIWEB` | `HDMIWEB` |
| `HDMICUTDOWN` | `HDMIBTH`, `HDMIWEB` |
| `USBKEYBOARD` | USB-host variants |
| `STRUCTENABLED` | All except `PICOMIN` |
| `MMBASIC_FM` | All except `PICOMIN`, unless `MMBASIC_ENABLE_FM=OFF` |
| `RAYCASTER` | Raycaster variants |
| `CACHE` | Cache variants |
| `GUICONTROLS` | GUI-capable variants listed in CMake |

## Link Library Matrix

| Library group | Applies when |
| --- | --- |
| Core Pico SDK and hardware libraries | All variants |
| `tinyusb_host`, `tinyusb_board`, `pico_multicore` | USB-host variants |
| `pico_multicore` | `VGA`, `PICO`, `PICOMIN`, `HDMI`, `VGARP2350`, `PICORP2350`, `PICOBTRP2350`, `PICOBTHRP2350` |
| `pico_rand` | RP2350 feature variants listed in `PICO_RAND_VARIANTS` |
| `pico_cyw43_arch_lwip_poll` | Web variants |
| `pico_btstack_ble`, `pico_btstack_cyw43`, `pico_cyw43_arch_none` | BT and BTH variants |
| `pico_lwip_mbedtls`, `pico_mbedtls` | `WEBRP2350`, `HDMIWEB` |

## Build Verification Recommendation

Add a script that configures and builds every `COMPILE` value in a separate build directory:

```powershell
$variants = @(
  "PICO", "PICOUSB", "PICOMIN", "VGA", "VGAUSB", "WEB",
  "PICORP2350", "PICOUSBRP2350", "VGARP2350", "VGAUSBRP2350",
  "WEBRP2350", "HDMI", "HDMIUSB", "PICOBTRP2350", "PICOBTHRP2350",
  "HDMIBTH", "HDMIWEB"
)

foreach ($variant in $variants) {
  $buildDir = "build-$variant"
  cmake -S . -B $buildDir -DCOMPILE=$variant
  cmake --build $buildDir
}
```

Keep each variant in its own build directory. Reusing a build directory across RP2040/RP2350 or board-family changes can hide stale CMake cache behavior.

