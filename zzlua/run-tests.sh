#!/bin/bash

for f in $(find tests -type f -name '*.lua'); do
  echo -n "$f: "
  #LUA_PATH="./lib/?.lua" ./zzlua "$f" && echo "PASS"
  ./zzlua "$f" && echo "PASS"
done
