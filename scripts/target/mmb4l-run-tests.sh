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

With no test files, this runs the PicoCalc core test set. Use --upstream-all
to run the upstream tests/run_tests.bas entry point.
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

PICOCALC_CORE_TESTS="
tst_call.bas
tst_csub_as_data.bas
tst_data.bas
tst_error_handling.bas
tst_eval.bas
tst_fundamentals.bas
tst_inc.bas
tst_json.bas
tst_labels.bas
tst_math.bas
tst_memory.bas
tst_peek.bas
tst_poke.bas
tst_setenv.bas
tst_simple_maths_fns.bas
tst_sort.bas
tst_static.bas
tst_subfun.bas
tst_variables.bas
"

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

cd "$TEST_DIR"

for test_file in $tests; do
  [ -n "$test_file" ] || continue
  if [ ! -f "$test_file" ]; then
    echo "Missing test file under $TEST_DIR: $test_file" >&2
    exit 1
  fi
  echo "Running $test_file"
  if [ -n "$test_args" ]; then
    "$MMBASIC" "$test_file" $test_args </dev/null
  else
    "$MMBASIC" "$test_file" </dev/null
  fi
done
