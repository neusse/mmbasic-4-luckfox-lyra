# Luckfox Networking Notes

This document tracks the current MMBasic networking surface for the Luckfox
Lyra PicoCalc target and the planned WebMite-compatible work.

## Current Policy

Linux owns WiFi configuration on this target. MMBasic should inspect network
state and provide program network I/O, but it should not directly configure
SSIDs, passwords, AP mode, DHCP, routes, or system time.

Use Linux tools for connection management:

```sh
ip addr
iw dev wlan0 link
wpa_cli status
udhcpc
```

## Implemented In MMBasic

These are implemented by `patches/mmb4l/0012-luckfox-network-status.patch`.

| BASIC surface | Status | Notes |
| --- | --- | --- |
| `MM.INFO$(IP ADDRESS)` | Implemented | Returns the preferred wireless IPv4 address, then the first non-loopback IPv4 address, else `0.0.0.0`. |
| `MM.INFO(IP ADDRESS)` | Implemented | Same value path as the string spelling. |
| `MM.INFO(WIFI STATUS)` | Implemented | Returns `1` when a wireless interface is up, else `0`. |
| `MM.INFO(TCPIP STATUS)` | Implemented | Returns `3` when an IP address exists, `2` when WiFi is up without IP, else `0`. |
| `WEB SCAN` | Partial | Lists SSIDs using Linux `iw`. No array argument yet. Needs compatibility work because it works in the current smoke test but not reliably for all manual use. |
| `SYSTEM command$ [, output$ [, exit_code%]]` | Existing MMB4L feature | Can call Linux helpers such as `wget`, `python3`, or `openssl` and capture stdout. |

Verified on the current target image:

- `wlan0` is the active wireless interface.
- `MM.INFO$(IP ADDRESS)` reported `192.168.1.115` during verification.
- `WEB SCAN` passed `tests/picocalc/tst_picocalc_web_scan.bas` from a file.
- Target tools/libraries include `wget`, `python3`, `openssl`, `libcurl.so.4`,
  `libssl.so.3`, and `libcrypto.so.3`.
- Python reports OpenSSL `3.2.1`.

## WEB SCAN Compatibility Gap

The PicoMite/WebMite manual documents:

```basic
WEB SCAN [array%()]
```

The current Luckfox implementation only supports:

```basic
WEB SCAN
```

It shells out to:

```sh
iw dev wlan0 scan
```

Known gaps:

- `WEB SCAN array%()` is not implemented.
- Output is plain SSID text, not the full PicoMite array result format.
- Manual CLI behavior still needs debugging because user testing reported that
  `WEB SCAN` does not work, while the file-based smoke test works.
- The current implementation depends on `iw` being installed and allowed to
  scan from the current Linux state.

Useful debug commands:

```powershell
adb shell 'iw dev wlan0 scan 2>&1 | sed -n "1,40p"'
adb push .\tests\picocalc\tst_picocalc_web_scan.bas /tmp/tst_picocalc_web_scan.bas
adb shell 'mmbasic /tmp/tst_picocalc_web_scan.bas; echo rc:$?'
```

## Inbound HTTP Server Work

`OPTION WEB MESSAGES` is not the receiver by itself. In the PicoMite/WebMite
manual it controls informational web messages; default is `ON`, and `OFF`
disables those messages.

The actual WebMite-style inbound web server surface is:

| BASIC surface | Purpose on WebMite | Luckfox plan |
| --- | --- | --- |
| `OPTION TCP SERVER PORT n` | Enable/disable TCP server port, commonly 80 for HTTP. | Implement as Linux socket server configuration. |
| `OPTION WEB MESSAGES {ON|OFF}` | Enable/disable informational web messages. | Implement as logging/console verbosity for the Linux web backend. |
| `WEB TCP INTERRUPT sub` | Start server handling and call `sub` when a client request arrives. | Implement with an event/interrupt bridge from accepted sockets into BASIC. |
| `WEB TCP READ cb%, buff%()` | Read request data for client block `cb%`. | Implement by copying socket receive buffers into BASIC longstring arrays. |
| `WEB TCP SEND cb%, data%()` | Send raw response bytes. | Implement with Linux `send()`. |
| `WEB TCP CLOSE cb%` | Close the client connection. | Implement with Linux `close()`. |
| `WEB TRANSMIT PAGE cb%, file$` | Send HTTP header and an HTML file with variable substitution. | Implement after raw TCP server works. |
| `WEB TRANSMIT FILE cb%, file$, content-type$` | Send HTTP header and file contents. | Implement after raw TCP server works. |

Recommended implementation order:

1. Add option storage for `OPTION TCP SERVER PORT` and `OPTION WEB MESSAGES`.
2. Add a minimal nonblocking Linux TCP listener.
3. Add client-handle allocation and `WEB TCP INTERRUPT`.
4. Add `WEB TCP READ`, `WEB TCP SEND`, and `WEB TCP CLOSE`.
5. Add HTTP helpers `WEB TRANSMIT PAGE` and `WEB TRANSMIT FILE`.

## Outbound HTTP And HTTPS

PicoMite/WebMite documents outbound plain TCP client commands:

| BASIC surface | Purpose |
| --- | --- |
| `WEB OPEN TCP CLIENT domain$, port` | Open a TCP client connection. |
| `WEB TCP CLIENT REQUEST query$, inbuf [, timeout]` | Send request text and read response. |
| `WEB CLOSE TCP CLIENT` | Close the TCP client. |
| `WEB OPEN TCP STREAM address$, port` | Open stream client receiver path. |
| `WEB TCP CLIENT STREAM query$, buff%(), r%, w%` | Stream receive/send helper. |

Plain HTTP can be implemented with normal Linux sockets. HTTPS needs TLS. The
target image already has OpenSSL and libcurl, so there are two viable paths:

- Native path: link MMBasic against libcurl or OpenSSL and implement HTTPS in
  the `WEB TCP CLIENT` backend.
- Helper path: use `SYSTEM` to call `wget` or Python for HTTPS and capture the
  result.

The helper path is fastest and lowest risk for early BASIC programs. The native
path is better long term if we want PicoMite-compatible commands, long-running
connections, streams, and fewer shell quoting issues.

Example using `SYSTEM` and `wget`:

```basic
Option Explicit
Dim out$, rc%
SYSTEM "wget -qO- https://example.com", out$, rc%
Print "rc="; rc%
Print out$
```

Example using Python from BASIC:

```basic
Option Explicit
Dim out$, rc%
SYSTEM "python3 -c ""import urllib.request; print(urllib.request.urlopen('https://example.com').read().decode()[:200])""", out$, rc%
Print "rc="; rc%
Print out$
```

## Calling MMBasic From Linux

Bash, Python, or another process can call MMBasic as a normal executable:

```sh
mmbasic /path/to/program.bas
```

Python example:

```python
import subprocess

result = subprocess.run(
    ["mmbasic", "/tmp/task.bas"],
    text=True,
    capture_output=True,
    check=False,
)
print(result.returncode)
print(result.stdout)
print(result.stderr)
```

This is useful for batch jobs. It is not a full replacement for native
`WEB TCP INTERRUPT` server behavior because every run starts a new interpreter
process. For a persistent web service, either MMBasic needs a native server
backend or an external daemon needs a clear file/stdin/stdout/localhost IPC
contract with the BASIC program.
