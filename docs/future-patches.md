# Future Patches

This file tracks candidate patches that have been researched but intentionally
deferred.

## Regex Support For `INSTR` And `LINSTR`

Status: deferred.

Candidate patch name:

```text
0019-add-regex-instr-linstr.patch
```

Reference:

- TheBackShed discussion: https://www.thebackshed.com/forum/ViewTopic.php?FID=16&TID=16027

Target compatibility:

- Follow the PicoMite/WebMite behavior described in the thread.
- Keep existing literal substring behavior unchanged when no match-size variable
  is supplied.
- Enable regex mode only when the optional `size` variable argument is present.

Proposed BASIC syntax:

```basic
pos% = INSTR(text$, pattern$, size)
pos% = INSTR(start%, text$, pattern$, size)
pos% = LINSTR(longstring%(), pattern$, size)
pos% = LINSTR(longstring%(), pattern$, start%, size)
```

Expected behavior:

- Return value remains the 1-based start position of the match.
- Return `0` when no match is found.
- `size` is a numeric variable populated with the matched text length.
- `pattern$` is treated as a regex only when `size` is supplied.
- Without `size`, `INSTR` and `LINSTR` continue to do plain substring matching.

Implementation notes:

- Current `INSTR` implementation is in `src/core/Functions.c`.
- Current `LINSTR` implementation is in `src/functions/fun_linstr.c`.
- The Luckfox Buildroot sysroot has libc/POSIX regex support through
  `<regex.h>` / `regcomp()` / `regexec()`.
- Prefer using POSIX regex from libc instead of vendoring a new regex engine.
- Preserve MMBasic string semantics and 1-based return positions.
- For `LINSTR`, match against the long-string byte buffer without copying more
  than necessary.

Tests to add:

- Existing literal `INSTR` behavior still passes with two and three arguments.
- Existing literal `LINSTR` behavior still passes with existing forms.
- Regex `INSTR("abc123def", "[0-9]+", size)` returns `4` and sets `size = 3`.
- Regex `INSTR(5, "abc123def456", "[0-9]+", size)` returns `10` and sets
  `size = 3`.
- Regex no-match returns `0` and sets `size = 0`.
- Regex `LINSTR` returns the correct 1-based position and match length.
- Invalid regex reports a useful BASIC error instead of crashing.

Open decisions:

- Confirm whether `size` must be an integer variable or may be float/integer.
  The forum examples describe it as `size`, but PicoMite examples often use
  default float variables unless suffixed.
- Confirm case-sensitivity expectations. POSIX regex is case-sensitive by
  default; do not add case-insensitive behavior unless PicoMite documents it.
- Confirm whether regex should support only POSIX extended syntax or basic POSIX
  syntax. Extended syntax is probably closer to user expectations, but this
  should be verified before implementation.
