#!/bin/sh
set -eu

MMBASIC=${MMBASIC:-/usr/local/bin/mmbasic}
SHARE_DIR=${MMB4L_SHARE_DIR:-/usr/local/share/mmb4l}
TEST_DIR=${MMB4L_TEST_DIR:-"$SHARE_DIR/tests"}
TEST_TIMEOUT=${MMB4L_TEST_TIMEOUT:-60}

usage() {
  cat <<'USAGE'
Usage:
  mmb4l-run-tests --smoke
  mmb4l-run-tests [--all] [-- mmbasic test args]
  mmb4l-run-tests --core [-- mmbasic test args]
  mmb4l-run-tests --upstream-entrypoint [-- mmbasic test args]
  mmb4l-run-tests [run_tests.bas | tst_math.bas ...] [-- mmbasic test args]

Environment:
  MMBASIC          Path to mmbasic. Default: /usr/local/bin/mmbasic
  MMB4L_SHARE_DIR  Installed share directory. Default: /usr/local/share/mmb4l
  MMB4L_TEST_DIR   Installed test directory. Default: $MMB4L_SHARE_DIR/tests
  MMB4L_TEST_TARGET Target profile for patched upstream tests.
                    Default: picocalc-luckfox-lyra
  MMB4L_TEST_TIMEOUT Per BASIC test timeout in seconds. Default: 60.
                    Set to 0 to disable the timeout.

With no test files, this runs all installed target tests: upstream tst*.bas
files plus project PicoCalc tst*.bas files. Use --core for the smaller legacy
core subset, or --upstream-entrypoint to run the upstream tests/run_tests.bas
entry point directly.
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
mode=all
if [ "${1:-}" = "--all" ]; then
  shift
  mode=all
  if [ "${1:-}" = "--" ]; then
    shift
    test_args=$*
  elif [ "$#" -gt 0 ]; then
    echo "--all only accepts extra test arguments after --" >&2
    exit 2
  fi
elif [ "${1:-}" = "--upstream-all" ]; then
  echo "Notice: --upstream-all is deprecated; running the full installed target suite. Use --upstream-entrypoint for upstream run_tests.bas only."
  shift
  mode=all
  if [ "${1:-}" = "--" ]; then
    shift
    test_args=$*
  elif [ "$#" -gt 0 ]; then
    echo "--upstream-all only accepts extra test arguments after --" >&2
    exit 2
  fi
elif [ "${1:-}" = "--core" ]; then
  shift
  mode=core
  if [ "${1:-}" = "--" ]; then
    shift
    test_args=$*
  elif [ "$#" -gt 0 ]; then
    echo "--core only accepts extra test arguments after --" >&2
    exit 2
  fi
elif [ "${1:-}" = "--upstream-entrypoint" ]; then
  shift
  mode=upstream_entrypoint
  tests=run_tests.bas
  if [ "${1:-}" = "--" ]; then
    shift
    test_args=$*
  elif [ "$#" -gt 0 ]; then
    echo "--upstream-entrypoint only accepts extra test arguments after --" >&2
    exit 2
  fi
elif [ "$#" -gt 0 ]; then
  mode=explicit
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
  mode=all
fi

if [ "$mode" = "core" ]; then
  tests=$PICOCALC_CORE_TESTS
elif [ "$mode" = "all" ]; then
  cd "$TEST_DIR"
  tests=$(find . -type f -name 'tst*.bas' | sed 's#^\./##' | sort)
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
    echo "Skip reason: legacy SDL/DirectFB PicoMiteVGA simulation checks require MMB4L_TEST_DIRECTFB=1."
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

pass_count=0
fail_count=0
skip_count=0
run_count=0
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

add_pass() {
  pass_count=$((pass_count + 1))
}

add_fail() {
  subject=$1
  reason=$2
  fail_count=$((fail_count + 1))
  failed_list="${failed_list}${failed_list:+
}  FAIL: $subject - $reason"
}

add_skip() {
  subject=$1
  reason=$2
  entry="  SKIP: $subject - $reason"
  case "
$skipped_list
" in
*"
$entry
"*)
    return
    ;;
  esac
  skip_count=$((skip_count + 1))
  skipped_list="${skipped_list}${skipped_list:+
}$entry"
}

run_basic_test() {
  test_file=$1
  if [ "$TEST_TIMEOUT" = "0" ] || ! command -v timeout >/dev/null 2>&1; then
    if [ -n "$test_args" ]; then
      "$MMBASIC" "$test_file" $test_args
    else
      "$MMBASIC" "$test_file"
    fi
    return $?
  fi

  if [ -n "$test_args" ]; then
    timeout -k 5 "$TEST_TIMEOUT" "$MMBASIC" "$test_file" $test_args
  else
    timeout -k 5 "$TEST_TIMEOUT" "$MMBASIC" "$test_file"
  fi
}

is_timeout_status() {
  status=$1
  case "$status" in
  124|137|143)
    [ "$TEST_TIMEOUT" != "0" ] && command -v timeout >/dev/null 2>&1
    ;;
  *)
    return 1
    ;;
  esac
}

check_device_access() {
  device=$1
  name="system:$device"
  if [ ! -e "$device" ]; then
    echo "FAIL: $name missing"
    add_fail "$name" "missing"
  elif [ ! -r "$device" ] || [ ! -w "$device" ]; then
    echo "FAIL: $name is not readable and writable by this user"
    add_fail "$name" "not readable and writable by this user"
  else
    echo "PASS: $name"
    add_pass
  fi
}

check_input_access() {
  device=$1
  name="system:$device"
  if [ ! -e "$device" ]; then
    echo "FAIL: $name missing"
    add_fail "$name" "missing"
  elif [ ! -r "$device" ]; then
    echo "FAIL: $name is not readable by this user"
    add_fail "$name" "not readable by this user"
  else
    echo "PASS: $name"
    add_pass
  fi
}

check_graphics_backend() {
  name='system:picocalc-graphics-backend'
  test_file='picocalc/tst_picocalc_graphics_backend.bas'
  if [ ! -f "$test_file" ]; then
    echo "FAIL: $name missing $TEST_DIR/$test_file"
    add_fail "$name" "missing $TEST_DIR/$test_file"
    return 1
  fi

  output_file=${TMPDIR:-/tmp}/mmb4l-backend-$$.out
  set +e
  run_basic_test "$test_file" >"$output_file" 2>&1
  status=$?
  set -e
  cat "$output_file"
  rm -f "$output_file"

  if [ "$status" -ne 0 ]; then
    echo "FAIL: $name"
    echo "PicoCalc graphics backend is not FBDEV; refusing to run framebuffer tests."
    add_fail "$name" "backend test failed"
    return 1
  fi

  echo "PASS: $name"
  add_pass
  return 0
}

check_installed_picocalc_tests() {
  name='system:picocalc-tests-installed'
  count=$(find picocalc -type f -name 'tst*.bas' 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    echo "PASS: $name ($count)"
    add_pass
  else
    echo "FAIL: $name none found under $TEST_DIR/picocalc"
    add_fail "$name" "none found under $TEST_DIR/picocalc"
  fi
}

if [ "$mode" = "all" ]; then
  echo "Running target health checks"
  check_device_access /dev/fb0
  check_device_access /dev/tty0
  check_input_access /dev/input/event0
  backend_ok=1
  check_graphics_backend || backend_ok=0
  check_installed_picocalc_tests

  filtered_tests=
  for test_file in $tests; do
    case "$test_file" in
    picocalc/tst_picocalc_graphics_backend.bas)
      continue
      ;;
    picocalc/tst_picocalc_fbdev_*.bas|picocalc/tst_picocalc_gfx_framebuffer_*.bas)
      if [ "$backend_ok" -ne 1 ]; then
        add_skip "$test_file" "PicoCalc graphics backend is not FBDEV"
        continue
      fi
      ;;
    esac
    filtered_tests="${filtered_tests}${filtered_tests:+
}$test_file"
  done
  tests=$filtered_tests
fi

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
  run_basic_test "$test_file" >"$output_pipe" 2>&1 </dev/null
  status=$?
  set -e
  wait "$tee_pid"
  rm -f "$output_pipe"
  if [ "$status" -ne 0 ]; then
    if is_timeout_status "$status"; then
      echo "FAIL: $test_file timed out after ${TEST_TIMEOUT}s"
      add_fail "$test_file" "timed out after ${TEST_TIMEOUT}s"
    else
      echo "FAIL: $test_file exited with status $status"
      add_fail "$test_file" "exited with status $status"
    fi
    rm -f "$output_file"
    continue
  fi
  if grep -q "FAIL (" "$output_file"; then
    echo "FAIL: $test_file reported BASIC assertion failures"
    add_fail "$test_file" "reported BASIC assertion failures"
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
      add_skip "$test_file" "$skipped_name"
    done <"$skipped_file"
    rm -f "$skipped_file"
  fi
  rm -f "$output_file"
  add_pass
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
