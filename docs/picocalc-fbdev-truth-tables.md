# PicoCalc fbdev Truth Tables

These tables define the intended graphics state machine for the Luckfox
PicoCalc target. The release target must not silently fall back to SDL or
DirectFB. If native fbdev cannot be used, MMBasic should fail with a clear
target error.

## Backend Selection

| PicoCalc fbdev detected | `/dev/fb0` openable | Geometry is 320x320 RGB565 | SDL/DirectFB available | Result |
| --- | --- | --- | --- | --- |
| yes | yes | yes | either | Select `FBDEV`, create/select surface N, continue |
| yes | no | either | either | Fail: framebuffer missing or permission denied |
| yes | yes | no | either | Fail: unsupported framebuffer geometry/depth |
| no | either | either | yes | Fail for this PicoCalc release target |
| no | either | either | no | Fail for this PicoCalc release target |

SDL and DirectFB availability must not affect the PicoCalc release backend. They
are legacy/development paths only if a separate non-PicoCalc build explicitly
selects them.

## Display Initialization

| Initialised | Surface N exists | fbdev open | Backend | Action | Valid final state |
| --- | --- | --- | --- | --- | --- |
| no | no | no | none/SDL default | Initialise shared graphics state first | continue |
| yes | no | no | none/SDL default | Create software surface N | continue |
| yes | yes | no | none/SDL default | Open and mmap `/dev/fb0` | continue |
| yes | yes | yes | not `FBDEV` | Set backend to `FBDEV` or fail invariant | `FBDEV`, N selected |
| yes | yes | yes | `FBDEV` | Select N as current write surface | ready |

Forbidden state:

| Surface N exists | fbdev open | Backend | Meaning |
| --- | --- | --- | --- |
| yes | yes | `SDL` | Broken invariant. This is the state that makes presentation silently skip. |

The suspected MMBasic bug is lifecycle ordering: `graphics_ensure_default_display`
opens fbdev and sets `FBDEV`, then surface creation calls `graphics_init`, which
resets the backend to SDL. The standalone harness has a `buggy-order` case to
reproduce that forbidden state without changing MMBasic.

## Presentation

| Backend | fbdev open | Surface N exists | Surface dirty / generation changed | Result |
| --- | --- | --- | --- | --- |
| `FBDEV` | yes | yes | yes | Copy software surface N to `/dev/fb0`, sync if needed, mark presented |
| `FBDEV` | yes | yes | no | No-op success |
| `FBDEV` | no | either | either | Fail: framebuffer not open |
| `FBDEV` | yes | no | either | Fail: visible surface missing |
| not `FBDEV` | either | either | either | Fail invariant on PicoCalc; do not silently skip |

The current upstream-style SDL behavior of “return success when backend is not
fbdev” is wrong for this target because it hides display failures.

## Text, Graphics, And Layer Composition

| Active write surface | Operation | Expected internal result | Expected visible result |
| --- | --- | --- | --- |
| N | `BOX`, `LINE`, `PIXEL`, or other graphics primitive | Surface N changes and is marked dirty | Next present copies N to `/dev/fb0` |
| N | `TEXT` or `PRINT @(x,y)` after graphics | Text pixels overwrite only their glyph area on N | Text appears over existing graphics; background pixels remain |
| F | Graphics primitive | Surface F changes only; N is unchanged | Nothing changes on the panel until copied/merged to N |
| L | `TEXT` or `PRINT @(x,y)` | Surface L changes only; N and F are unchanged | Nothing changes on the panel until layer merge |
| F + L | `FRAMEBUFFER MERGE` with transparent colour | N receives F background plus non-transparent L pixels | Text from L appears over F background |
| N dirty | `FRAMEBUFFER WAIT` / present | N is copied to fbdev using the selected fbdev presenter | Physical screen should match N, subject to panel verification |

Forbidden layer states:

| State | Meaning |
| --- | --- |
| Writing to F or L changes N immediately | Broken framebuffer isolation |
| Text drawn after graphics clears the graphics background | Broken text compositing |
| `FRAMEBUFFER MERGE` loses F background pixels | Broken transparent merge |
| `/dev/fb0` samples match but physical panel does not | Not accepted as display proof; ask for physical screen verification |

The standalone harness case `text-layering` verifies direct text-over-graphics,
`PRINT @(x,y)`-style positioned text, F/L isolation, transparent layer merge,
and sampled fbdev output before MMBasic code changes are accepted.

## Verification Outcomes

| Internal `PIXEL()` result | `/dev/fb0` sample | Direct fbdev write visible | Interpretation |
| --- | --- | --- | --- |
| expected colour | expected colour | yes | Full graphics path works |
| expected colour | black/old console | yes | MMBasic draw surface is correct, presentation is skipped or wrong |
| black/wrong | black/wrong | yes | Drawing or surface selection is wrong before presentation |
| expected colour | expected colour | no | Screenshot sees memory, but physical panel/backlight path needs investigation |
| expected colour | black/old console | no | Physical fbdev visibility is not proven; fix target display first |

## Physical SPI Panel Edge State

The PicoCalc display is an ILI9488 SPI/fbdev display. The kernel driver uses
Linux DRM DBI helper code internally, but the hardware connection is SPI, not
MIPI DSI.

| `/dev/fb0` 320x320 samples | Physical right/bottom edge | Meaning | Cleanup |
| --- | --- | --- | --- |
| black/clean | black/clean | Logical fbdev and visible panel agree | none |
| black/clean | stale colours on 2px right or 5px bottom edge | LCD controller/panel state outside the exposed 320x320 fbdev image retained old pixels | Clear `/dev/fb0` black, then blank/unblank `fb0` |
| non-black where black expected | matching non-black visible pixels | fbdev memory was not cleared | Fix fbdev clear/presentation path |
| black/clean | entire panel blank or invisible | fbdev memory is clean but panel/backlight visibility needs separate debugging | check fb0 blank/backlight/panel power |

## REPL And Screen Ownership

| Launch context | Input path | Text output path | Graphics output path | Expected behavior |
| --- | --- | --- | --- | --- |
| SSH/ADB/pts terminal | stdin | terminal | fbdev | Terminal remains usable while graphics draw on PicoCalc screen |
| physical PicoCalc console | evdev keyboard | fbdev text renderer | fbdev | BASIC owns the screen and keyboard without tty byte confusion |
| X11/GUI terminal | stdin | terminal/window manager dependent | fbdev or unsupported | Not the primary support path; no SDL/DirectFB fallback in PicoCalc release |
