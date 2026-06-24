#!/bin/sh
set -eu

MMBASIC=${MMBASIC:-/usr/local/bin/mmbasic}
SHARE_DIR=${MMB4L_SHARE_DIR:-/usr/local/share/mmb4l}
TEST_DIR=${MMB4L_TEST_DIR:-"$SHARE_DIR/tests"}

usage() {
  cat <<'USAGE'
Usage:
  mmb4l-run-tests --smoke
  mmb4l-run-tests --upstream-all [-- mmbasic test args]
  mmb4l-run-tests [run_tests.bas | tst_math.bas ...] [-- mmbasic test args]

Environment:
  MMBASIC          Path to mmbasic. Default: /usr/local/bin/mmbasic
  MMB4L_SHARE_DIR  Installed share directory. Default: /usr/local/share/mmb4l
  MMB4L_TEST_DIR   Installed test directory. Default: $MMB4L_SHARE_DIR/tests
  MMB4L_TEST_TARGET Target profile for patched upstream tests.
                    Default: picocalc-luckfox-lyra

With no test files, this runs the PicoCalc core test set. Use --upstream-all
to run the upstream tests/run_tests.bas entry point. The upstream-all path is
broader and slower than the PicoCalc core set.
USAGE
}

require_file() {
  if [ ! -e "$1" ]; then
    echo "Missing required file or directory: $1" >&2
    exit 1
  fi
}

run_smoke() {
  require_file "$MMBASIC"
  tmp=${TMPDIR:-/tmp}/mmb4l-smoke-$$.bas
  trap 'rm -f "$tmp"' EXIT HUP INT TERM
  cat >"$tmp" <<'BASIC'
PRINT "hello from installed mmbasic"
PRINT 6 * 7
END
BASIC
  "$MMBASIC" --version
  "$MMBASIC" "$tmp"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--smoke" ]; then
  shift
  if [ "$#" -ne 0 ]; then
    echo "--smoke does not accept additional arguments" >&2
    exit 2
  fi
  run_smoke
  exit 0
fi

require_file "$MMBASIC"
require_file "$TEST_DIR"
require_file "$SHARE_DIR/sptools/src/sptest/sptest.bas"

export MMB4L_TEST_TARGET=${MMB4L_TEST_TARGET:-picocalc-luckfox-lyra}

PICOCALC_CORE_TESTS="
tst_call.bas
tst_csub_as_data.bas
tst_data.bas
tst_error_handling.bas
tst_eval.bas
tst_file_fns.bas
tst_fundamentals.bas
tst_inc.bas
tst_json.bas
tst_labels.bas
tst_longstring.bas
tst_math.bas
tst_memory.bas
tst_mminfo.bas
tst_options.bas
tst_peek.bas
tst_poke.bas
tst_setenv.bas
tst_simple_maths_fns.bas
tst_sort.bas
tst_static.bas
tst_strings.bas
tst_subfun.bas
tst_system.bas
tst_time_fns.bas
tst_variables.bas
"

echo "Test target: $MMB4L_TEST_TARGET"

if [ -t 0 ]; then
  :
else
  echo "Notice: running from a non-interactive shell; console cursor/terminal-size checks are skipped by patched tests."
  echo "Run this from the PicoCalc console for the full console/framebuffer coverage."
fi

test_args=
if [ "${1:-}" = "--upstream-all" ]; then
  shift
  tests=run_tests.bas
  if [ "${1:-}" = "--" ]; then
    shift
    test_args=$*
  elif [ "$#" -gt 0 ]; then
    echo "--upstream-all only accepts extra test arguments after --" >&2
    exit 2
  fi
elif [ "$#" -gt 0 ]; then
  tests=
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--" ]; then
      shift
      test_args=$*
      break
    fi
    tests="${tests}${tests:+
}$1"
    shift
  done
else
  tests=$PICOCALC_CORE_TESTS
fi

case "
$tests
" in
*"
tst_mminfo.bas
"*|*"
run_tests.bas
"*)
  echo "Skip reason: tst_mminfo.test_drive is PicoMite-only; MMB4L has no A:/B: drive state."
  echo "Skip reason: tst_mminfo.test_font_address is not meaningful on MMB4L; font addresses are not public stable values."
  if [ "${MMB4L_TEST_CURSOR:-}" != "1" ]; then
    echo "Skip reason: tst_mminfo.test_hpos/test_vpos require MMB4L_TEST_CURSOR=1 from an interactive PicoCalc console."
  fi
  if [ "${MMB4L_TEST_DIRECTFB:-}" != "1" ]; then
    echo "Skip reason: DirectFB PicoMiteVGA simulation checks require MMB4L_TEST_DIRECTFB=1."
  fi
  ;;
esac

case "
$tests
" in
*"
tst_options.bas
"*|*"
run_tests.bas
"*)
  echo "Skip reason: tst_options.test_option_simulate requires a 640+ wide simulated display; PicoCalc framebuffer is 320 wide."
  ;;
esac

case "
$tests
" in
*"
tst_strings.bas
"*|*"
run_tests.bas
"*)
  echo "Skip reason: tst_strings OPTION ESCAPE tests are PicoMite-only in the upstream suite."
  ;;
esac

cd "$TEST_DIR"

run_count=0
fail_count=0
pass_count=0
skip_count=0
failed_list=
skipped_list=

print_summary_line() {
  label=$1
  count=$2
  total=$3
  if [ "$total" -eq 0 ]; then
    percent=0
  else
    percent=$((count * 100 / total))
  fi
  echo "$label: $count/$total (${percent}%)"
}

for test_file in $tests; do
  [ -n "$test_file" ] || continue
  if [ ! -f "$test_file" ]; then
    echo "Missing test file under $TEST_DIR: $test_file" >&2
    exit 1
  fi
  run_count=$((run_count + 1))
  echo "Running $test_file"
  output_file=${TMPDIR:-/tmp}/mmb4l-test-$$.out
  output_pipe=${TMPDIR:-/tmp}/mmb4l-test-$$.pipe
  rm -f "$output_pipe"
  mkfifo "$output_pipe"
  tee "$output_file" <"$output_pipe" &
  tee_pid=$!
  set +e
  if [ -n "$test_args" ]; then
    "$MMBASIC" "$test_file" $test_args >"$output_pipe" 2>&1 </dev/null
    status=$?
  else
    "$MMBASIC" "$test_file" >"$output_pipe" 2>&1 </dev/null
    status=$?
  fi
  set -e
  wait "$tee_pid"
  rm -f "$output_pipe"
  if [ "$status" -ne 0 ]; then
    echo "FAIL: $test_file exited with status $status"
    fail_count=$((fail_count + 1))
    failed_list="${failed_list}${failed_list:+
}  FAIL: $test_file - exited with status $status"
    rm -f "$output_file"
    continue
  fi
  if grep -q "FAIL (" "$output_file"; then
    echo "FAIL: $test_file reported BASIC assertion failures"
    fail_count=$((fail_count + 1))
    failed_list="${failed_list}${failed_list:+
}  FAIL: $test_file - reported BASIC assertion failures"
    rm -f "$output_file"
    continue
  fi
  if grep -q "NO ASSERTIONS" "$output_file"; then
    echo "NOTICE: $test_file reported NO ASSERTIONS for one or more subtests; see skip reasons above."
    skipped_file=${TMPDIR:-/tmp}/mmb4l-test-$$.skips
    grep "NO ASSERTIONS" "$output_file" | sed 's/\r//g' >"$skipped_file"
    while IFS= read -r skipped_line; do
      skipped_name=$(printf '%s\n' "$skipped_line" | sed 's/^[[:space:]]*//; s/:.*//')
      case "$skipped_name" in
      *"NO ASSERTIONS"*|/*)
        continue
        ;;
      esac
      skip_count=$((skip_count + 1))
      skipped_list="${skipped_list}${skipped_list:+
}  SKIP: $test_file - $skipped_name"
    done <"$skipped_file"
    rm -f "$skipped_file"
  fi
  rm -f "$output_file"
  pass_count=$((pass_count + 1))
  echo "PASS: $test_file"
done

total_count=$((pass_count + fail_count + skip_count))

echo "Summary:"
print_summary_line "  Success" "$pass_count" "$total_count"
print_summary_line "  Failed" "$fail_count" "$total_count"
print_summary_line "  Skipped" "$skip_count" "$total_count"
echo "  Total: $total_count"

if [ -n "$failed_list" ]; then
  echo "Failed:"
  printf '%s\n' "$failed_list"
fi

if [ -n "$skipped_list" ]; then
  echo "Skipped:"
  printf '%s\n' "$skipped_list"
fi

if [ "$fail_count" -ne 0 ]; then
  echo "FAIL: $fail_count of $run_count test file(s) failed"
  exit 1
fi

echo "PASS: $run_count test file(s)"
