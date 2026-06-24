# Compiled Binary

`mmbasic-luckfox-lyra-armv7l` is a compiled MMBasic for Linux binary for the
Luckfox Lyra PicoCalc target.

Target:

- Architecture: ARMv7 hard-float Linux
- Runtime: Luckfox/PicoCalc Buildroot image
- Install path used by this project: `/usr/local/bin/mmbasic`

Verify the checksums before installing:

```sh
sha256sum -c SHA256SUMS
```

For a no-build install, use the ZIP release bundle:

```text
mmbasic-luckfox-lyra-release.zip
```

On the PicoCalc:

```sh
unzip mmbasic-luckfox-lyra-release.zip
cd mmbasic-luckfox-lyra-release
sh install-picocalc.sh
mmb4l-run-tests
```

The matching `.tar.gz` bundle is also included for systems where `tar` is more
convenient than `unzip`.
