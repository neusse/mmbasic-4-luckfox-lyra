# PicoCalc Target Notes

These facts were captured from a Luckfox Lyra PicoCalc over ADB and are used to
guide the repeatable MMB4L build and runtime support policy.

## Operating System And ABI

- OS: Buildroot 2024.02
- Kernel: Linux 6.1.99
- Architecture: `armv7l`
- libc: glibc 2.38
- CPU features observed: VFP, VFPv3, VFPv4, NEON, LPAE

The current build target is ARM hard-float using the Luckfox Buildroot SDK
userland compiler, `arm-buildroot-linux-gnueabihf-gcc`.

## Display

- Framebuffer: `/dev/fb0`
- Driver: `ili9488drmfb`
- Mode: `320x320`
- Pixel format: RGB565
- Bits per pixel: `16`
- Stride: `640`
- Observed default device permissions:
  - `/dev/tty0`: `crw-rw---- root tty`
  - `/dev/fb0`: `crw-rw---- root video`

Stock MMB4L uses SDL2. The current Luckfox/PicoCalc build uses SDL2 with
DirectFB for the framebuffer path. If SDL/DirectFB becomes a reliability or
performance blocker, a native framebuffer backend can be added later.

For the current SDL2/DirectFB path, `/etc/directfbrc` should match
`scripts/target/directfbrc`. The important target-specific settings are
`quiet`, `system=fbdev`, `fbdev=/dev/fb0`, `mode=320x320`,
`pixelformat=RGB16`, `no-vt`, `no-vt-switch`, `disable-module=keyboard`, and
`disable-module=linux_input`.

`quiet` suppresses DirectFB backend logs on the physical console. Without it,
DirectFB startup, framebuffer, gamma-ramp, and Fusion diagnostics can remain on
screen after a graphics program exits.

For non-root runs, changing `/dev/fb0` and `/dev/tty0` to mode `666` has been
observed to avoid display permission errors and improve graphics stability:

```sh
chmod 666 /dev/fb0 /dev/tty0
```

This is a broad local workaround. A persistent image-level fix should use a
device permission rule or user/group membership when the final target policy is
defined.

## Keyboard/Input

- Input device: `/dev/input/event0`
- Name: `Picocalc Keyboard`
- Stable path observed: `/dev/input/by-path/platform-ff040000.i2c-event-kbd`

Normal terminal input works for SSH/ADB style use. Direct evdev input remains
the recommended next step for reliable physical-console graphics-mode keyboard
handling.

## Audio

- ALSA card: `picocalcsndpwm`
- PCM output: `/dev/snd/pcmC0D0p`

Try SDL audio over ALSA first. Add a direct ALSA backend only if SDL blocks
progress.

## IO Devices

Observed devices include:

- `/dev/gpiochip0` through `/dev/gpiochip4`
- `/sys/class/gpio/export`
- `/dev/i2c-0`
- SPI devices under sysfs

Real GPIO, I2C, and SPI support needs a PicoCalc-specific pin map before public
commands expose hardware access.

## Revalidation Commands

```powershell
adb devices -l
adb shell 'cat /etc/os-release; uname -a'
adb shell 'cat /proc/fb; fbset -fb /dev/fb0'
adb shell 'cat /etc/directfbrc; ls -l /dev/tty0 /dev/fb0'
adb shell 'cat /proc/bus/input/devices'
adb shell 'cat /proc/asound/cards; ls -l /dev/snd'
adb shell 'ls -l /dev/gpiochip* /dev/i2c* /dev/spidev* 2>/dev/null'
adb shell 'find /usr/lib -maxdepth 2 -iname "*SDL*"'
```

Do not substitute simulated device data for these checks.
