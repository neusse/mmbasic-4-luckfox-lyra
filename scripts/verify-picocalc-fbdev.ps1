$ErrorActionPreference = 'Stop'

adb shell 'test -e /dev/fb0 && echo fb0-present'
adb shell 'cat /proc/fb || true'
adb shell 'fbset -fb /dev/fb0 || true'
adb shell 'mmbasic /usr/local/share/mmb4l/tests/picocalc/tst_picocalc_graphics_backend.bas'
adb shell 'mmbasic /usr/local/share/mmb4l/tests/picocalc/tst_picocalc_fbdev_pixels.bas'
