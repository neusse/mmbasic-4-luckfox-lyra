# PicoCalc REPL And Graphics Usage

MMBasic has one command prompt and one graphics output surface.

On the Luckfox PicoCalc build, the prompt is the terminal that started
`mmbasic`: SSH, ADB shell, an X11 terminal, or the physical Linux console.
Graphics commands draw to the PicoCalc framebuffer. GUI/X11 desktop use is not
the primary support target; depending on the host display stack, it may behave
differently from the PicoCalc Linux console/text environment.

## Starting MMBasic

Interactive prompt:

```sh
mmbasic
```

Run a program:

```sh
mmbasic program.bas
```

Exit the prompt:

```basic
QUIT
```

Interrupt a running BASIC program from the terminal with `Ctrl+C`. On the
physical PicoCalc console, graphics-mode input is read from the PicoCalc evdev
keyboard, so `/dev/input/event0` must be readable by the user running MMBasic.

## Console Versus Graphics

Use terminal input for the REPL even when a graphics window or framebuffer is
visible. If graphics has covered the physical console, the prompt may still be
accepting input even though the framebuffer is showing BASIC graphics.

Common commands:

```basic
CLS CONSOLE
```

Clears the terminal console.

```basic
CLS
```

Clears the terminal console when no graphics surface is already open. After a
graphics surface exists, bare `CLS` clears the active graphics surface.

```basic
CLS RGB(BLACK)
```

Creates/selects the PicoCalc graphics display when needed and clears it to the
given colour.

```basic
GRAPHICS CLOSE 0
```

Closes graphics surface 0 when a graphics window/framebuffer surface is open.

```basic
SYSTEM "clear"
```

Uses the Linux shell to clear the terminal.

## Why A Blank Window Can Happen

PicoMite programs commonly start drawing without an explicit `GRAPHICS WINDOW`
command. To support those programs, this build automatically creates the
320x320 PicoCalc display surface when a graphics command needs it.

The important detail is that graphics output is not a second terminal. If a GUI
environment opens a separate graphics window, focus or return to the shell that
launched `mmbasic` and keep typing there.

## Device Access

The installer does not change device permissions by default. For a quick
development-only non-root test:

```sh
chmod 666 /dev/fb0 /dev/tty0 /dev/input/event0
```

Set `MMB4L_APPLY_DEVICE_PERMS=1` to have the installer apply that workaround.
This is a practical target workaround, not a final security policy. A future
image should replace it with proper user/group or device-manager rules.

The old SDL/DirectFB setup is now a legacy test path. Normal PicoCalc releases
use the native fbdev display presenter and evdev keyboard backend.
