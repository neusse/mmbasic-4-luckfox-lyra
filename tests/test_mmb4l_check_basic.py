import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from mmb4l_check_basic import scan_file, scan_text


SUPPORTED_COMMANDS = {
    "BEEP",
    "CHDIR",
    "CLS",
    "COLOR",
    "CSUB",
    "DIM",
    "DO",
    "DRIVE",
    "ELSE",
    "END",
    "END CSUB",
    "END FUNCTION",
    "END SUB",
    "ENDIF",
    "FOR",
    "FUNCTION",
    "IF",
    "LOCAL",
    "LOOP",
    "ON",
    "MODE",
    "NEXT",
    "PAUSE",
    "PRINT",
    "RANDOMIZE",
    "RETURN",
    "SUB",
    "TEXT",
}

SUPPORTED_FUNCTIONS = {
    "CHR$",
    "BOUND",
    "INKEY$",
    "INT",
    "MM.HRES",
    "MM.VRES",
    "RGB",
    "RND",
    "SPRITE",
    "TIMER",
}


class BasicCompatibilityScannerTest(unittest.TestCase):
    def test_ignores_locate_in_comments_and_strings(self):
        source = """
        ' LOCATE 1, 1
        REM LOCATE 2, 2
        PRINT "LOCATE 3, 3"
        """

        result = scan_text("comments.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_flags_executable_unsupported_command_with_suggestion(self):
        source = """
        MODE 1
        LOCATE 10, 20
        PRINT "X"
        """

        result = scan_text("bad.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual(1, len(result.issues))
        issue = result.issues[0]
        self.assertEqual("error", issue.severity)
        self.assertEqual(3, issue.line)
        self.assertEqual("LOCATE", issue.symbol)
        self.assertIn("TEXT", issue.suggestion)

    def test_allows_print_at_positioning_when_print_is_supported(self):
        source = """
        PRINT @(10, 20) "HELLO"
        """

        result = scan_text("print-at.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_allows_nested_if_line_number_branches(self):
        source = """
        DIM COST(20), VOL(20), HZ(20)
        670 IF COST(2) > 135 THEN IF VOL(2) > 3000 + VOL1 THEN 720 ELSE 690
        1890 IF STK = 1 THEN 1910 ELSE PRINT "Want to change your mind";
        2150 IF D - DB < 500 THEN RETURN ELSE IF HZ(15) = 1 THEN 2180 ELSE TM = 1
        """

        result = scan_text("nested-if.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_allows_continued_expression_lines(self):
        source = """
        DIM z(1), x(1), y(1)
        e = (SPRITE(D, z(0) + 1, z(1) + 40) < 15) + _
            (x(0) < 0 OR x(0) > 799 OR y(0) < 0 OR y(0) > 599) * 2 + _
            (p <= np) * 3
        """

        result = scan_text("gravity.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_flags_single_word_unsupported_command_after_line_number(self):
        source = """
        1010 PRINT "done"
        1030 STOP
        """

        result = scan_text("craps.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual(1, len(result.issues))
        issue = result.issues[0]
        self.assertEqual("error", issue.severity)
        self.assertEqual(3, issue.line)
        self.assertEqual("STOP", issue.symbol)
        self.assertIn("END", issue.suggestion)

    def test_warns_that_beep_is_noop(self):
        source = """
        BEEP
        PRINT "done"
        """

        result = scan_text("beep.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual(0, result.error_count)
        self.assertEqual(1, result.warning_count)
        issue = result.issues[0]
        self.assertEqual("warning", issue.severity)
        self.assertEqual("BEEP", issue.symbol)
        self.assertIn("audio is not currently supported", issue.message)
        self.assertIn("no audio will be generated", issue.suggestion)

    def test_warns_that_drive_is_noop(self):
        source = """
        DRIVE "B:"
        CHDIR "mmbasic"
        """

        result = scan_text("menu.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual(0, result.error_count)
        self.assertEqual(1, result.warning_count)
        issue = result.issues[0]
        self.assertEqual("warning", issue.severity)
        self.assertEqual("DRIVE", issue.symbol)
        self.assertIn("Linux has no A:/B: drives", issue.message)
        self.assertIn("Use Linux paths and CHDIR", issue.suggestion)

    def test_allows_colon_labels(self):
        source = """
        start_label:
        PRINT "ok"
        done_label: RETURN
        """

        result = scan_text("labels.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_allows_user_defined_functions(self):
        source = """
        FUNCTION ToPixelY(line) AS INTEGER
          ToPixelY = line * 8
        END FUNCTION
        PRINT @(0, ToPixelY(10)) "OK"
        """

        result = scan_text("user-function.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_allows_array_parameters_in_subprograms(self):
        source = """
        FUNCTION ctrl.poll_multiple$(drivers$(), mask%, duration%, key%)
          FOR i% = BOUND(drivers$(), 0) TO BOUND(drivers$(), 1)
            ctrl.poll_multiple$ = drivers$(i%)
          NEXT
        END FUNCTION
        """

        result = scan_text("array-params.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_ignores_optional_call_guarded_by_on_error_skip(self):
        source = """
        ON ERROR SKIP : sound.term()
        ON ERROR SKIP : twm.enable_cursor(1)
        PRINT "done"
        """

        result = scan_text("optional-lib.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_reports_unknown_substyle_call_once(self):
        source = """
        IF hit% THEN expl_player() : done% = 1
        """

        result = scan_text("unknown-call.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual(1, len(result.issues))
        self.assertEqual("error", result.issues[0].severity)
        self.assertEqual("EXPL_PLAYER", result.issues[0].symbol)

    def test_warns_for_array_declared_only_inside_conditional_block(self):
        source = """
        IF MM.DEVICE$ = "PicoMiteVGA" THEN
          DIM CONTROLLERS$(1) = ("keys_cursor_ext", "nes_a")
        ELSE
          PRINT "unsupported"
        ENDIF

        FUNCTION ctrl.poll_multiple$(drivers$(), mask%, duration%, key%)
        END FUNCTION

        FUNCTION poll_ctrl%()
          ctrl$ = ctrl.poll_multiple$(CONTROLLERS$(), 1, 0, poll_ctrl%)
        END FUNCTION
        """

        result = scan_text("conditional-array.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual(0, result.error_count)
        self.assertEqual(1, result.warning_count)
        issue = result.issues[0]
        self.assertEqual("warning", issue.severity)
        self.assertEqual("CONTROLLERS$", issue.symbol)
        self.assertIn("declared only inside conditional blocks", issue.message)

    def test_allows_array_declared_in_every_conditional_branch(self):
        source = """
        SUB msgbox.beep(valid%)
          IF valid% THEN
            LOCAL notes!(3) = (987.77, 1567.98, 1975.53, 30.87)
          ELSE
            LOCAL notes!(4) = (1046.50, 987.77, 739.99, 698.46, 30.87)
          ENDIF
          FOR i% = BOUND(notes!(), 0) TO BOUND(notes!(), 1)
            PRINT notes!(i%)
          NEXT
        END SUB
        """

        result = scan_text("branch-covered-array.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_allows_csub_calls_and_ignores_csub_payload(self):
        source = """
        DIM INTEGER c(10), d(10), ct
        bubblerow c(), d(), ct
        CSUB bubblerow INTEGER, INTEGER, INTEGER
        00000000
        B5F0681B 001A0014 68123290
        E361A2 BDF0B01D
        END CSUB
        """

        result = scan_text("csub.bas", source, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual([], result.issues)

    def test_scan_file_reports_relative_path_and_counts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "demo.bas"
            target.write_text("LOCATE 1, 1\n", encoding="utf-8")

            result = scan_file(target, root, SUPPORTED_COMMANDS, SUPPORTED_FUNCTIONS)

        self.assertEqual("demo.bas", result.path)
        self.assertEqual(1, result.error_count)
        self.assertEqual(0, result.warning_count)


if __name__ == "__main__":
    unittest.main()
