# PicoCalc Target Notes

These facts were captured from a Luckfox Lyra PicoCalc over ADB and are used to
guide the first repeatable MMB4L build.

## Operating System And ABI

- OS: Buildroot 2024.02
- Kernel: Linux 6.1.99
- Architecture: `armv7l`
- libc: glibc 2.38
- CPU features observed: VFP, VFPv3, VFPv4, NEON, LPAE

The first build target should be ARM hard-float using the Luckfox Buildroot SDK
userland compiler, `arm-buildroot-linux-gnueabihf-gcc`.

## Display

- Framebuffer: `/dev/fb0`
- Driver: `ili9488drmfb`
- Mode: `320x320`
- Pixel format: RGB565
- Bits per pixel: `16`
- Stride: `640`

Stock MMB4L uses SDL2. The target has SDL2 runtime libraries, so SDL should be
tested first. If SDL/DirectFB is not usable, a native framebuffer backend can be
added later.

## Keyboard/Input

- Input device: `/dev/input/event0`
- Name: `Picocalc Keyboard`
- Stable path observed: `/dev/input/by-path/platform-ff040000.i2c-event-kbd`

The first console milestone can use normal terminal input. A later handheld
mode can read evdev directly.

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
adb shell 'cat /proc/bus/input/devices'
adb shell 'cat /proc/asound/cards; ls -l /dev/snd'
adb shell 'ls -l /dev/gpiochip* /dev/i2c* /dev/spidev* 2>/dev/null'
adb shell 'find /usr/lib -maxdepth 2 -iname "*SDL*"'
```

Do not substitute simulated device data for these checks.
