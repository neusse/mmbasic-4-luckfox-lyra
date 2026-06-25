# BASIC Compatibility Checker

`mmb4l-check-basic` scans BASIC source files for likely compatibility problems
with the installed Luckfox/PicoCalc MMBasic build.

It is intended for support cases such as:

- "This BASIC program works on another MMBasic, but not here."
- "Which files on this SD card use unsupported commands?"
- "What substitutions should I try before reporting a bug?"

## Install Location

The PicoCalc installer places the checker at:

```sh
/usr/local/bin/mmb4l-check-basic
```

It also creates this symlink:

```sh
/usr/bin/mmb4l-check-basic
```

## Usage

Scan one file:

```sh
mmb4l-check-basic /home/neusse/matrix3.bas
```

Scan a directory recursively:

```sh
mmb4l-check-basic /mnt/sdcard/pico2w/mmbasic
```

Only show files with warnings or failures:

```sh
mmb4l-check-basic --quiet-pass /mnt/sdcard
```

Use a different interpreter binary:

```sh
MMBASIC=/usr/local/bin/ommbasic mmb4l-check-basic /home/neusse
```

## How It Works

By default the checker asks the installed interpreter for its supported
language surface:

```basic
LIST COMMANDS
LIST FUNCTIONS
```

It then scans `.bas`, `.BAS`, `.inc`, and `.INC` files. The scanner ignores
quoted strings and comments, handles line numbers and colon-separated
statements, and reports unsupported statement-start commands as failures.

Function-like calls that are not in the installed function list are reported as
warnings because they might be user functions or arrays.

The checker also catches a limited class of `OPTION EXPLICIT` runtime problems:
arrays declared only inside conditional blocks are reported when later used as
though they are always declared. This is useful for platform-selection code
where no branch may run on Luckfox/Linux.

Known compatibility no-ops are also reported as warnings. For example, `BEEP`
is accepted so old games can continue running, but the checker warns that audio
is not currently supported and no sound will be generated. `DRIVE` is also
accepted for old PicoMite-style menus, but Linux paths and `CHDIR` remain in
control; `DRIVE "A:"` and `DRIVE "B:"` do not select a mount.

## Result Levels

- `PASS`: no issues found.
- `WARN`: possible compatibility issue; review before assuming the file is bad.
- `FAIL`: likely unsupported command syntax for this MMBasic build.

Example:

```text
FAIL matrix3.bas
  ERROR line 26, col 7: Command LOCATE is not in the supported command list
    suggestion: MMB4L does not implement LOCATE. For console text use CURSOR x,y; for PicoCalc graphics use TEXT x,y,string$,...
```

## Current Limits

This is a compatibility scanner, not a complete MMBasic parser. It does not run
programs, so it cannot validate runtime behavior, hardware access, missing data
files, infinite loops, or program-specific logic.

A future interpreter-level `mmbasic --check file.bas` mode would make this more
authoritative. The checker is designed so it can call that mode when it exists.
