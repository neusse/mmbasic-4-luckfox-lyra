# Compiled Binary

`mmbasic-luckfox-lyra-armv7l` is a compiled MMBasic for Linux binary for the
Luckfox Lyra PicoCalc target.

Target:

- Architecture: ARMv7 hard-float Linux
- Runtime: Luckfox/PicoCalc Buildroot image
- Install path used by this project: `/usr/local/bin/mmbasic`

Verify the checksum before installing:

```sh
sha256sum mmbasic-luckfox-lyra-armv7l
```

Expected checksum:

```text
d14cff5780288e1667a02d6f635b1d890d52811e594ffc5fccb3353574d4920d  mmbasic-luckfox-lyra-armv7l
```

For a no-build install, use the release bundle:

```text
mmbasic-luckfox-lyra-release.tar.gz
```

On the PicoCalc:

```sh
tar xzf mmbasic-luckfox-lyra-release.tar.gz
cd mmbasic-luckfox-lyra-release
sh install-picocalc.sh
mmb4l-run-tests
```
