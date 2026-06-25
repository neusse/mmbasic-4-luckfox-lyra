#!/usr/bin/env python3
"""Scan BASIC files for likely MMB4L/PicoCalc compatibility issues."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence


BASIC_EXTENSIONS = {".bas", ".inc"}

FALLBACK_COMMANDS = {
    "ARC",
    "ARRAY",
    "AUTOSAVE",
    "BEEP",
    "BLIT",
    "BOX",
    "CALL",
    "CASE",
    "CASE ELSE",
    "CHDIR",
    "CIRCLE",
    "CLEAR",
    "CLOSE",
    "CLS",
    "COLOR",
    "COLOUR",
    "CONSOLE",
    "CONST",
    "CONTINUE",
    "COPY",
    "CSUB",
    "CURSOR",
    "DATA",
    "DEFINEFONT",
    "DEVICE",
    "DIM",
    "DO",
    "DRIVE",
    "EDIT",
    "ELSE",
    "ELSE IF",
    "ELSEIF",
    "END",
    "END CSUB",
    "END DEFINEFONT",
    "END FUNCTION",
    "END IF",
    "END SELECT",
    "END SUB",
    "ENDIF",
    "ERASE",
    "ERROR",
    "EXECUTE",
    "EXIT",
    "EXIT DO",
    "EXIT FOR",
    "EXIT FUNCTION",
    "EXIT SUB",
    "FILES",
    "FLASH",
    "FONT",
    "FOR",
    "FRAMEBUFFER",
    "FUNCTION",
    "GAMEPAD",
    "GOSUB",
    "GOTO",
    "GRAPHICS",
    "GUI",
    "IF",
    "IMAGE",
    "INC",
    "INPUT",
    "IRETURN",
    "KILL",
    "LET",
    "LINE",
    "LINE INPUT",
    "LIST",
    "LOAD",
    "LOCAL",
    "LONGSTRING",
    "LOOP",
    "MATH",
    "MEMORY",
    "MID$(",
    "MKDIR",
    "MMDEBUG",
    "MODE",
    "NEW",
    "NEXT",
    "ON",
    "OPEN",
    "OPTION",
    "PAGE",
    "PAUSE",
    "PIN(",
    "PIXEL",
    "PLAY",
    "POKE",
    "POLYGON",
    "PRINT",
    "PULSE",
    "QUIT",
    "RANDOMIZE",
    "RBOX",
    "READ",
    "REM",
    "RENAME",
    "RESTORE",
    "RETURN",
    "RMDIR",
    "RUN",
    "SEEK",
    "SELECT CASE",
    "SETENV",
    "SETPIN",
    "SETTICK",
    "SETTITLE",
    "SORT",
    "SPRITE",
    "STATIC",
    "SUB",
    "SYSTEM",
    "TEXT",
    "TIMER",
    "TRACE",
    "TRIANGLE",
    "TROFF",
    "TRON",
    "WEB",
    "WEND",
    "WHILE",
    "XMODEM",
}

FALLBACK_FUNCTIONS = {
    "ABS",
    "ASC",
    "ATN",
    "BIN$",
    "BOUND",
    "CHR$",
    "COS",
    "CWD$",
    "DATE$",
    "DAY$",
    "DIR$",
    "EOF",
    "EPOCH",
    "EXP",
    "FIELD$",
    "FORMAT$",
    "HEX$",
    "INKEY$",
    "INPUT$",
    "INSTR",
    "INT",
    "JSON$",
    "LCASE$",
    "LEFT$",
    "LEN",
    "LINSTR",
    "LOC",
    "LOF",
    "LOG",
    "MID$",
    "MM.CMDLINE$",
    "MM.DEVICE$",
    "MM.HRES",
    "MM.INFO",
    "MM.INFO$",
    "MM.VER",
    "MM.VRES",
    "OCT$",
    "PEEK",
    "PIXEL",
    "RGB",
    "RIGHT$",
    "RND",
    "SGN",
    "SIN",
    "SPACE$",
    "SQR",
    "STR$",
    "STRING$",
    "TAB",
    "TIMER",
    "UCASE$",
    "VAL",
}

COMMAND_SUGGESTIONS = {
    "LOCATE": (
        "MMB4L does not implement LOCATE. For console text use CURSOR x,y; "
        "for PicoCalc graphics use TEXT x,y,string$,..."
    ),
    "STOP": "MMB4L does not implement STOP. Replace STOP with END.",
}

NOOP_COMMAND_WARNINGS = {
    "BEEP": (
        "Command BEEP is accepted as a compatibility no-op; audio is not currently supported",
        "BEEP will run without error, but no audio will be generated.",
    ),
    "DRIVE": (
        "Command DRIVE is accepted as a compatibility no-op; Linux has no A:/B: drives",
        "Use Linux paths and CHDIR; DRIVE will run without error, but does not change the current directory or mount.",
    ),
}

FUNCTION_SUGGESTIONS = {
    "LOC(": "Use LOC(file-number) for file position; LOCATE is not a function.",
}


@dataclass(frozen=True)
class Issue:
    severity: str
    line: int
    column: int
    kind: str
    symbol: str
    message: str
    suggestion: str = ""


@dataclass
class FileResult:
    path: str
    issues: list[Issue] = field(default_factory=list)

    @property
    def error_count(self) -> int:
        return sum(1 for issue in self.issues if issue.severity == "error")

    @property
    def warning_count(self) -> int:
        return sum(1 for issue in self.issues if issue.severity == "warning")

    @property
    def status(self) -> str:
        if self.error_count:
            return "FAIL"
        if self.warning_count:
            return "WARN"
        return "PASS"


def normalize_symbol(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().upper())


def strip_strings_and_comments(line: str) -> str:
    result: list[str] = []
    in_string = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '"':
            in_string = not in_string
            result.append(" ")
            i += 1
            continue
        if in_string:
            result.append(" ")
            i += 1
            continue
        if ch == "'":
            break
        if _starts_rem_comment(line, i):
            break
        result.append(ch)
        i += 1
    return "".join(result)


def _starts_rem_comment(line: str, index: int) -> bool:
    if line[index : index + 3].upper() != "REM":
        return False
    before = line[index - 1] if index > 0 else " "
    after = line[index + 3] if index + 3 < len(line) else " "
    return not _is_name_char(before) and not _is_name_char(after)


def _is_name_char(ch: str) -> bool:
    return ch.isalnum() or ch in "_.$%!"


def split_statements(line: str) -> list[tuple[str, int, bool]]:
    statements: list[tuple[str, int, bool]] = []
    start = 0
    in_string = False
    for idx, ch in enumerate(line):
        if ch == '"':
            in_string = not in_string
        elif ch == ":" and not in_string:
            statements.append((line[start:idx], start + 1, True))
            start = idx + 1
    statements.append((line[start:], start + 1, False))
    return statements


def guarded_statement_ranges(clean: str) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    guard_next = False
    for raw_statement, base_col, _ in split_statements(clean):
        statement = strip_line_number(raw_statement)
        stripped = statement.strip()
        start = base_col - 1
        end = start + len(raw_statement)
        if guard_next:
            ranges.append((start, end))
            guard_next = False
        if re.fullmatch(r"ON\s+ERROR\s+SKIP", stripped, flags=re.IGNORECASE):
            guard_next = True
    return ranges


def line_continues(clean: str) -> bool:
    return bool(re.search(r"_\s*$", clean))


def is_in_ranges(offset: int, ranges: Sequence[tuple[int, int]]) -> bool:
    return any(start <= offset < end for start, end in ranges)


def strip_line_number(statement: str) -> str:
    return re.sub(r"^\s*\d+\s+", "", statement, count=1)


def is_label_only(statement: str, supported_commands: set[str]) -> bool:
    token = statement.strip()
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.$%]*", token):
        return False
    return normalize_symbol(token) not in supported_commands


def command_at_start(statement: str, supported_commands: set[str]) -> str | None:
    normalized = normalize_symbol(statement)
    for command in sorted(supported_commands, key=len, reverse=True):
        command_name = command[:-1] if command.endswith("(") else command
        if not command_name:
            continue
        if normalized == command_name:
            return command
        if normalized.startswith(command_name):
            next_char = normalized[len(command_name)]
            if not _is_name_char(next_char):
                return command
    return None


def first_name(statement: str) -> tuple[str, int] | None:
    match = re.search(r"[A-Za-z_][A-Za-z0-9_.$%]*", statement)
    if not match:
        return None
    return match.group(0), match.start() + 1


def looks_like_assignment(statement: str) -> bool:
    match = re.match(r"\s*[A-Za-z_][A-Za-z0-9_.$%!]*(?:\s*\([^)]*\))?\s*=", statement)
    return bool(match)


def nested_command_tails(statement: str) -> list[tuple[str, int]]:
    tails: list[tuple[str, int]] = []
    for match in re.finditer(r"\b(?:THEN|ELSE)\b", statement, flags=re.IGNORECASE):
        tail = statement[match.end() :]
        stripped = tail.lstrip()
        if not stripped:
            continue
        offset = match.end() + (len(tail) - len(stripped)) + 1
        if re.match(r"\d+\b", stripped):
            continue
        tails.append((stripped, offset))
    return tails


def is_block_if_start(clean: str) -> bool:
    statement = strip_line_number(clean).strip()
    if not re.match(r"IF\b", statement, flags=re.IGNORECASE):
        return False
    return bool(re.search(r"\bTHEN\s*$", statement, flags=re.IGNORECASE))


def is_block_if_end(clean: str) -> bool:
    statement = strip_line_number(clean).strip()
    return bool(re.match(r"END\s*IF\b|ENDIF\b", statement, flags=re.IGNORECASE))


def conditional_line_depths(clean_lines: Sequence[str]) -> list[int]:
    depths: list[int] = []
    depth = 0
    for line in clean_lines:
        if is_block_if_end(line):
            depth = max(0, depth - 1)
        depths.append(depth)
        if is_block_if_start(line):
            depth += 1
    return depths


def is_command_position(clean: str, offset: int) -> bool:
    prefix = clean[:offset]
    last_colon = prefix.rfind(":")
    if last_colon != -1:
        prefix = prefix[last_colon + 1 :]
    stripped = prefix.rstrip()
    return not stripped or bool(re.search(r"\b(?:THEN|ELSE)\s*$", stripped, flags=re.IGNORECASE))


def is_declaration_context(clean: str, offset: int) -> bool:
    prefix = clean[:offset]
    return bool(re.search(r"\b(?:DIM|LOCAL|STATIC|FUNCTION|SUB)\b", prefix, flags=re.IGNORECASE))


def declared_array_names_in_line(line: str) -> set[str]:
    names: set[str] = set()
    for match in re.finditer(r"\b(?:DIM|LOCAL|STATIC)\b(.+)", line, flags=re.IGNORECASE):
        declaration = match.group(1)
        for name in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_.$%!]*)\s*\(", declaration):
            names.add(normalize_symbol(name.group(1)))
    return names


def arrays_covered_by_complete_conditional(clean_lines: Sequence[str]) -> set[str]:
    covered: set[str] = set()
    stack: list[dict[str, object]] = []

    for line in clean_lines:
        statement = strip_line_number(line).strip()

        if re.match(r"ELSE\s*IF\b|ELSEIF\b|ELSE\b", statement, flags=re.IGNORECASE):
            if stack:
                block = stack[-1]
                branches = block["branches"]
                assert isinstance(branches, list)
                current = block["current"]
                assert isinstance(current, set)
                branches.append(set(current))
                block["current"] = set()
                if re.match(r"ELSE\b", statement, flags=re.IGNORECASE):
                    block["has_else"] = True
            continue

        if is_block_if_end(line):
            if stack:
                block = stack.pop()
                branches = block["branches"]
                assert isinstance(branches, list)
                current = block["current"]
                assert isinstance(current, set)
                branches.append(set(current))
                if block["has_else"] and branches:
                    guaranteed = set.intersection(*branches) if branches else set()
                    covered.update(guaranteed)
                    if stack:
                        parent_current = stack[-1]["current"]
                        assert isinstance(parent_current, set)
                        parent_current.update(guaranteed)
            continue

        names = declared_array_names_in_line(line)
        if names and stack:
            current = stack[-1]["current"]
            assert isinstance(current, set)
            current.update(names)

        if is_block_if_start(line):
            stack.append({"branches": [], "current": set(), "has_else": False})

    return covered


def declared_arrays_with_scope(clean_lines: Sequence[str], depths: Sequence[int]) -> tuple[set[str], set[str]]:
    declarations: dict[str, set[str]] = {}

    def add_array(name: str, scope: str) -> None:
        declarations.setdefault(normalize_symbol(name), set()).add(scope)

    for idx, line in enumerate(clean_lines):
        scope = "conditional" if depths[idx] > 0 else "unconditional"
        for name in declared_array_names_in_line(line):
            add_array(name, scope)
        for match in re.finditer(
            r"\b(?:FUNCTION|SUB)\s+[A-Za-z_][A-Za-z0-9_.$%!]*\s*\((.*)\)",
            line,
            flags=re.IGNORECASE,
        ):
            parameters = match.group(1)
            for name in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_.$%!]*)\s*\(\s*\)", parameters):
                add_array(name.group(1), "unconditional")
    arrays = set(declarations)
    conditional_only = {name for name, scopes in declarations.items() if scopes == {"conditional"}}
    conditional_only -= arrays_covered_by_complete_conditional(clean_lines)
    return arrays, conditional_only


def declared_arrays(clean_lines: Sequence[str]) -> set[str]:
    arrays, _ = declared_arrays_with_scope(clean_lines, [0] * len(clean_lines))
    return arrays


def declared_functions(clean_lines: Sequence[str]) -> set[str]:
    functions: set[str] = set()
    for line in clean_lines:
        for match in re.finditer(r"\bFUNCTION\s+([A-Za-z_][A-Za-z0-9_.$%!]*)\s*\(", line, flags=re.IGNORECASE):
            functions.add(normalize_symbol(match.group(1)))
        for match in re.finditer(r"\bDEF\s+FN\s*([A-Za-z_][A-Za-z0-9_.$%!]*)\s*\(", line, flags=re.IGNORECASE):
            functions.add(normalize_symbol("FN" + match.group(1)))
        for match in re.finditer(r"\bDEF\s+(FN[A-Za-z_][A-Za-z0-9_.$%!]*)\s*\(", line, flags=re.IGNORECASE):
            functions.add(normalize_symbol(match.group(1)))
    return functions


def declared_subcommands(clean_lines: Sequence[str]) -> set[str]:
    subcommands: set[str] = set()
    for line in clean_lines:
        for match in re.finditer(r"\b(?:SUB|CSUB)\s+([A-Za-z_][A-Za-z0-9_.$%!]*)\b", line, flags=re.IGNORECASE):
            subcommands.add(normalize_symbol(match.group(1)))
    return subcommands


def starts_opaque_block(clean: str) -> bool:
    statement = strip_line_number(clean).lstrip()
    return bool(re.match(r"(?i)^(CSUB|DEFINEFONT)\b", statement))


def ends_opaque_block(clean: str) -> bool:
    statement = strip_line_number(clean).lstrip()
    return bool(re.match(r"(?i)^END\s+(CSUB|DEFINEFONT)\b", statement))


def scan_text(
    path: str,
    source: str,
    supported_commands: Iterable[str],
    supported_functions: Iterable[str],
) -> FileResult:
    commands = {normalize_symbol(command) for command in supported_commands}
    functions = {normalize_symbol(fn).removesuffix("(") for fn in supported_functions}
    clean_lines = [strip_strings_and_comments(line) for line in source.splitlines()]
    depths = conditional_line_depths(clean_lines)
    arrays, conditional_only_arrays = declared_arrays_with_scope(clean_lines, depths)
    user_functions = declared_functions(clean_lines)
    user_subcommands = declared_subcommands(clean_lines)
    command_set = commands | user_subcommands
    function_set = functions | user_functions | user_subcommands
    result = FileResult(path)
    in_opaque_block = False
    warned_conditional_arrays: set[str] = set()
    continued_from_previous = False

    for line_no, clean in enumerate(clean_lines, start=1):
        if in_opaque_block:
            if ends_opaque_block(clean):
                in_opaque_block = False
            continued_from_previous = line_continues(clean)
            continue
        guarded_ranges = guarded_statement_ranges(clean)
        if not continued_from_previous:
            scan_line_for_commands(result, line_no, clean, command_set, guarded_ranges)
        scan_line_for_functions(
            result,
            line_no,
            clean,
            function_set,
            arrays,
            guarded_ranges,
            conditional_only_arrays,
            warned_conditional_arrays,
        )
        if starts_opaque_block(clean):
            in_opaque_block = True
        continued_from_previous = line_continues(clean)

    return result


def scan_line_for_commands(
    result: FileResult,
    line_no: int,
    clean: str,
    commands: set[str],
    guarded_ranges: Sequence[tuple[int, int]] = (),
) -> None:
    for raw_statement, base_col, ended_with_colon in split_statements(clean):
        if is_in_ranges(base_col - 1, guarded_ranges):
            continue
        statement = strip_line_number(raw_statement)
        stripped = statement.lstrip()
        if not stripped or (ended_with_colon and is_label_only(stripped, commands)):
            continue
        column = base_col + (len(statement) - len(stripped))
        if stripped.startswith("?"):
            continue
        command = command_at_start(stripped, commands)
        if command:
            _add_noop_warning(result, line_no, column, command)
            for tail, tail_col in nested_command_tails(stripped):
                if not command_at_start(tail, commands) and not looks_like_assignment(tail):
                    name = first_name(tail)
                    if name:
                        _add_unknown_command(result, line_no, column + tail_col - 1, name[0])
            continue
        if looks_like_assignment(stripped):
            continue
        name = first_name(stripped)
        if name:
            _add_unknown_command(result, line_no, column + name[1] - 1, name[0])


def scan_line_for_functions(
    result: FileResult,
    line_no: int,
    clean: str,
    functions: set[str],
    arrays: set[str],
    guarded_ranges: Sequence[tuple[int, int]] = (),
    conditional_only_arrays: set[str] | None = None,
    warned_conditional_arrays: set[str] | None = None,
) -> None:
    conditional_only_arrays = conditional_only_arrays or set()
    warned_conditional_arrays = warned_conditional_arrays if warned_conditional_arrays is not None else set()
    for match in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_.$%!]*)\s*\(", clean):
        if is_in_ranges(match.start(1), guarded_ranges):
            continue
        symbol = normalize_symbol(match.group(1))
        if symbol in arrays:
            if (
                symbol in conditional_only_arrays
                and symbol not in warned_conditional_arrays
                and not is_declaration_context(clean, match.start(1))
            ):
                warned_conditional_arrays.add(symbol)
                result.issues.append(
                    Issue(
                        severity="warning",
                        line=line_no,
                        column=match.start(1) + 1,
                        kind="variable",
                        symbol=symbol,
                        message=(
                            f"Array {symbol}() is declared only inside conditional blocks; "
                            "it may be undeclared on this platform"
                        ),
                        suggestion="Declare it before the conditional block, or add an MMB4L/Linux branch that always declares it.",
                    )
                )
            continue
        if symbol in functions:
            continue
        if symbol in {"IF", "FOR", "WHILE", "UNTIL"}:
            continue
        if is_command_position(clean, match.start(1)):
            continue
        suggestion = FUNCTION_SUGGESTIONS.get(symbol + "(", "")
        result.issues.append(
            Issue(
                severity="warning",
                line=line_no,
                column=match.start(1) + 1,
                kind="function",
                symbol=symbol,
                message=f"Function or array call {symbol}( is not in the supported function list",
                suggestion=suggestion,
            )
        )


def _add_unknown_command(result: FileResult, line_no: int, column: int, symbol: str) -> None:
    normalized = normalize_symbol(symbol)
    result.issues.append(
        Issue(
            severity="error",
            line=line_no,
            column=column,
            kind="command",
            symbol=normalized,
            message=f"Command {normalized} is not in the supported command list",
            suggestion=COMMAND_SUGGESTIONS.get(normalized, ""),
        )
    )


def _add_noop_warning(result: FileResult, line_no: int, column: int, symbol: str) -> None:
    normalized = normalize_symbol(symbol)
    warning = NOOP_COMMAND_WARNINGS.get(normalized)
    if not warning:
        return
    result.issues.append(
        Issue(
            severity="warning",
            line=line_no,
            column=column,
            kind="command",
            symbol=normalized,
            message=warning[0],
            suggestion=warning[1],
        )
    )


def scan_file(
    path: Path,
    root: Path,
    supported_commands: Iterable[str],
    supported_functions: Iterable[str],
) -> FileResult:
    source = path.read_text(encoding="utf-8", errors="replace")
    try:
        display_path = str(path.relative_to(root))
    except ValueError:
        display_path = str(path)
    return scan_text(display_path, source, supported_commands, supported_functions)


def iter_basic_files(root: Path) -> Iterable[Path]:
    if root.is_file():
        if root.suffix.lower() in BASIC_EXTENSIONS:
            yield root
        return
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.suffix.lower() in BASIC_EXTENSIONS:
            yield path


def load_tokens_from_mmbasic(mmbasic: str, section: str) -> set[str]:
    command = f"LIST {section}\nEND\n"
    with tempfile.NamedTemporaryFile("w", suffix=".bas", delete=False, encoding="utf-8") as handle:
        handle.write(command)
        temp_name = handle.name
    try:
        proc = subprocess.run(
            [mmbasic, temp_name],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=20,
        )
    finally:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
    if proc.returncode != 0:
        raise RuntimeError(proc.stdout.strip() or f"{mmbasic} exited with {proc.returncode}")
    return parse_list_output(proc.stdout, section)


def parse_list_output(output: str, section: str) -> set[str]:
    tokens: set[str] = set()
    title = section.lower()
    capture = False
    for raw_line in output.splitlines():
        line = raw_line.strip().replace("\r", "")
        if not line:
            continue
        lowered = line.lower()
        if lowered.startswith("commandline read:") or lowered.startswith("mmbasic for linux"):
            continue
        if title in lowered and len(line) < 40:
            capture = True
            continue
        if not capture and re.search(r"\b[A-Za-z][A-Za-z0-9.$%!]*(?:\(|\$)?\b", line):
            capture = True
        if capture:
            for token in re.findall(r"[A-Za-z][A-Za-z0-9.$%!]*(?:\()?", line):
                upper = normalize_symbol(token)
                if upper not in {"COMMANDS", "FUNCTIONS"}:
                    tokens.add(upper)
    return tokens


def load_supported_tokens(mmbasic: str | None) -> tuple[set[str], set[str], str]:
    if mmbasic:
        try:
            commands = load_tokens_from_mmbasic(mmbasic, "COMMANDS")
            functions = load_tokens_from_mmbasic(mmbasic, "FUNCTIONS")
            if commands and functions:
                return commands, functions, f"{mmbasic} LIST COMMANDS/FUNCTIONS"
        except Exception as exc:  # noqa: BLE001 - CLI falls back and reports source.
            print(f"warning: could not read token lists from {mmbasic}: {exc}", file=sys.stderr)
    return set(FALLBACK_COMMANDS), set(FALLBACK_FUNCTIONS), "built-in fallback token list"


def print_report(
    results: Sequence[FileResult],
    token_source: str,
    displayed_results: Sequence[FileResult] | None = None,
) -> None:
    if displayed_results is None:
        displayed_results = results
    pass_count = sum(1 for result in results if result.status == "PASS")
    warn_count = sum(1 for result in results if result.status == "WARN")
    fail_count = sum(1 for result in results if result.status == "FAIL")
    total = len(results)

    print(f"Token source: {token_source}")
    print(f"Scanned: {total} BASIC file(s)")
    if len(displayed_results) != total:
        print(f"Displayed: {len(displayed_results)} BASIC file(s)")
    print()
    for result in displayed_results:
        print(f"{result.status} {result.path}")
        for issue in result.issues:
            print(f"  {issue.severity.upper()} line {issue.line}, col {issue.column}: {issue.message}")
            if issue.suggestion:
                print(f"    suggestion: {issue.suggestion}")
    print()
    print("Summary:")
    _print_count("  Compatible", pass_count, total)
    _print_count("  Warnings", warn_count, total)
    _print_count("  Failed", fail_count, total)
    print(f"  Total: {total}")


def _print_count(label: str, count: int, total: int) -> None:
    percent = 0 if total == 0 else int(count * 100 / total)
    print(f"{label}: {count}/{total} ({percent}%)")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", help="BASIC file or directory to scan")
    parser.add_argument(
        "--mmbasic",
        default=os.environ.get("MMBASIC", "mmbasic"),
        help="mmbasic executable used for LIST COMMANDS/FUNCTIONS; use '' for fallback only",
    )
    parser.add_argument("--quiet-pass", action="store_true", help="only print files with warnings or errors")
    args = parser.parse_args(argv)

    mmbasic = args.mmbasic or None
    commands, functions, token_source = load_supported_tokens(mmbasic)

    all_results: list[FileResult] = []
    for raw_path in args.paths:
        root = Path(raw_path)
        for basic_file in iter_basic_files(root):
            result = scan_file(basic_file, root if root.is_dir() else root.parent, commands, functions)
            all_results.append(result)

    displayed_results = [result for result in all_results if not args.quiet_pass or result.status != "PASS"]
    print_report(all_results, token_source, displayed_results)
    return 1 if any(result.error_count for result in all_results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
