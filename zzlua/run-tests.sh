#!/bin/bash

if [ -n "$1" ]; then
  # user passed the names of the desired test cases on the command line
  TESTS=""
  for t in "$@"; do
    TESTPATH=""
    for f in "tests/$t.lua" "$t"; do
      if [ -e "$f" ]; then
        TESTPATH="$f"
        break
      fi
    done
    if [ -z "$TESTPATH" ]; then
      echo "Unidentified test: $t, skipping."
    else
      TESTS+=" $f"
    fi
  done
else
  TESTS="$(find tests -type f -name '*.lua' | sort)"
fi

for f in $TESTS; do
  echo -n "$f: "
  ./zzlua "$f" && echo "PASS"
done
