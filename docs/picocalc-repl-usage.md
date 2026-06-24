# PicoCalc REPL And Graphics Usage

MMBasic has one command prompt and one graphics output surface.

On the Luckfox PicoCalc build, the prompt is the terminal that started
`mmbasic`: SSH, ADB shell, an X11 terminal, or the physical Linux console.
Graphics commands draw to the PicoCalc framebuffer. In an X11 desktop session,
that framebuffer may appear as a separate non-resizable window named
`PicoCalc`. That window is graphics output only; it is not the BASIC prompt.

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

Interrupt a running BASIC program from the terminal with `Ctrl+C`. If keyboard
input seems unreliable from the physical PicoCalc console, confirm that
`/etc/directfbrc` contains the project input settings from
[deploy.md](deploy.md). DirectFB should not grab the PicoCalc keyboard; MMBasic
reads console input from stdin.

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

In a BASIC program, clears the PicoCalc graphics display. At the immediate
prompt, a bare `CLS` stays on the terminal when no graphics surface is already
open.

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

The important detail is that the created `PicoCalc` window or framebuffer is
not a terminal. If it is blank, focus or return to the shell that launched
`mmbasic` and keep typing there.

## Recommended DirectFB Configuration

The installed `/etc/directfbrc` should include:

```text
quiet
no-cursor
no-banner
no-debug
system=fbdev
fbdev=/dev/fb0
wm=default
mode=320x320
depth=16
pixelformat=RGB16
no-vt
no-vt-switch
no-linux-input-grab
disable-module=keyboard
disable-module=linux_input
```

The `quiet`, `no-banner`, and `no-debug` options suppress DirectFB startup
output. The input options keep DirectFB from consuming PicoCalc keyboard events
that should go to the terminal running MMBasic.

The current installer also applies this tested device-permission workaround:

```sh
chmod 666 /dev/fb0 /dev/tty0
```

This is a practical target workaround, not a final security policy. A future
image should replace it with proper user/group or device-manager rules.
