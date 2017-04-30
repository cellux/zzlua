#!/bin/bash

TESTS=""

add_test() {
  local t="$1"
  if [ -d "$t" ]; then
    # if it's a directory, then all *.lua files below will be included
    for f in $(find "$t" -type f -name '*.lua' | sort); do
      add_test $f
    done
  else
    # otherwise, it should be the name of a test case under
    # tests or the full path to a *.lua file
    local testpath=""
    for f in "tests/$t.lua" "$t"; do
      if [ -e "$f" ]; then
        testpath="$f"
        break
      fi
    done
    if [ -z "$testpath" ]; then
      echo "Unidentified test: $t, skipping."
    else
      TESTS+=" $f"
    fi
  fi
}

if [ -n "$1" ]; then
  # user passed the test cases on the command line
  for t in "$@"; do
    add_test "$t"
  done
else
  # run everything under tests
  add_test tests
fi

for f in $TESTS; do
  echo -n "$f: "
  output="$(./zzlua "$f" 2>&1)"
  # non-empty output means it did not pass
  # it either failed or was skipped for some reason
  [ -n "$output" ] && echo "$output" || echo "PASS"
done
