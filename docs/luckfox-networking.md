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

These are implemented by `patches/mmb4l/0012-luckfox-network-status.patch`
and `patches/mmb4l/0019-luckfox-https-rest-client.patch`.

| BASIC surface | Status | Notes |
| --- | --- | --- |
| `MM.INFO$(IP ADDRESS)` | Implemented | Returns the preferred wireless IPv4 address, then the first non-loopback IPv4 address, else `0.0.0.0`. |
| `MM.INFO(IP ADDRESS)` | Implemented | Same value path as the string spelling. |
| `MM.INFO(WIFI STATUS)` | Implemented | Returns `1` when a wireless interface is up, else `0`. |
| `MM.INFO(TCPIP STATUS)` | Implemented | Returns `3` when an IP address exists, `2` when WiFi is up without IP, else `0`. |
| `WEB SCAN` | Implemented | Lists SSIDs using Linux `iw`. |
| `WEB SCAN array%()` | Implemented | Writes visible SSIDs separated by CRLF into a longstring-compatible integer array. This is useful for programs that expect a captured scan result. |
| `OPTION WIFI ssid$, password$` | Read-only compatibility | Succeeds only when Linux is already connected to `ssid$`; otherwise errors with guidance to use Linux networking tools. The password argument is parsed but not used. |
| `WEB NTP [offset [, server$]]` | Compatibility no-op | Parses the arguments and succeeds because Linux owns system time synchronization. |
| `WEB REST CLEAR HEADERS` | Implemented | Clears the per-process outbound REST header list. |
| `WEB REST HEADER name$, value$` | Implemented | Adds or replaces one outbound REST header. Up to 16 headers are retained. |
| `WEB REST GET url$, response%() [, status%] [, timeout%]` | Implemented | Fetches HTTP/HTTPS using libcurl/OpenSSL, follows redirects, writes body bytes into a longstring integer array, and optionally writes HTTP status. |
| `WEB REST POST url$, body$, response%() [, status%] [, contentType$] [, timeout%]` | Implemented | Sends a string body with libcurl/OpenSSL. The default content type is `application/json`. |
| `SYSTEM command$ [, output$ [, exit_code%]]` | Existing MMB4L feature | Can call Linux helpers such as `wget`, `python3`, or `openssl` and capture stdout. |

Verified on the current target image:

- `wlan0` is the active wireless interface.
- `MM.INFO$(IP ADDRESS)` reported `192.168.1.115` during verification.
- `WEB SCAN` passed `tests/picocalc/tst_picocalc_web_scan.bas` from a file.
- `WEB SCAN array%()` is covered by
  `tests/picocalc/tst_picocalc_web_scan_array.bas`.
- HTTPS REST is covered by
  `tests/picocalc/tst_picocalc_web_rest_https.bas` when
  `MMB4L_TEST_REST=1`.
- Target tools/libraries include `wget`, `python3`, `openssl`, `libcurl.so.4`,
  `libssl.so.3`, and `libcrypto.so.3`.
- Python reports OpenSSL `3.2.1`.

## WEB SCAN Compatibility

The PicoMite/WebMite manual documents:

```basic
WEB SCAN [array%()]
```

The Luckfox implementation supports both:

```basic
WEB SCAN
WEB SCAN array%()
```

It shells out to:

```sh
iw dev wlan0 scan
```

Current notes:

- `WEB SCAN` prints plain SSID text.
- `WEB SCAN array%()` writes SSIDs separated by CRLF into the supplied
  longstring-compatible integer array.
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

Luckfox adds a native REST convenience surface for BASIC programs:

```basic
Option Explicit
Dim response%(4096)
Dim status%

WEB REST CLEAR HEADERS
WEB REST HEADER "Accept", "application/json"
WEB REST GET "https://example.com/", response%(), status%, 20

Print "status="; status%
Print "bytes="; LLen(response%())
Print LGetStr$(response%(), 1, 200)
```

`WEB REST GET` and `WEB REST POST` are backed by libcurl and OpenSSL from the
Luckfox Linux image. TLS certificate validation stays enabled. The backend uses
`SSL_CERT_FILE` when set, then tries the Python `certifi` bundle that exists on
the current image, then falls back to the system CA bundle. If no usable CA
bundle can validate the server, the REST command fails instead of silently
disabling certificate validation.

The POST form is:

```basic
WEB REST POST url$, body$, response%() [, status%] [, contentType$] [, timeout%]
```

The body argument is a normal MMBasic string. The response argument must be a
longstring-compatible integer array large enough for the response body. The
default POST content type is `application/json`.

PicoMite/WebMite documents outbound plain TCP client commands:

| BASIC surface | Purpose |
| --- | --- |
| `WEB OPEN TCP CLIENT domain$, port` | Open a TCP client connection. |
| `WEB TCP CLIENT REQUEST query$, inbuf [, timeout]` | Send request text and read response. |
| `WEB CLOSE TCP CLIENT` | Close the TCP client. |
| `WEB OPEN TCP STREAM address$, port` | Open stream client receiver path. |
| `WEB TCP CLIENT STREAM query$, buff%(), r%, w%` | Stream receive/send helper. |

Plain TCP client compatibility is still separate work. `WEB REST` is intended
for the common REST/API case first; the WebMite raw TCP/TLS client command set
still needs a Linux socket backend if program compatibility requires it.

The helper path remains available through `SYSTEM` for cases that need a custom
Linux command pipeline:

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
