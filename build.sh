#!/bin/bash

set -eu

log() {
  echo "$@"
}

run() {
  echo "[$PWD] $@"
  "$@"
}

cd $(dirname ${BASH_SOURCE[0]})

GOAL="${1:-build}"
APP="${2:-zzmake}"

case $GOAL in
  clean)
    # remove binary
    run rm -f $APP
    # remove assets package
    run rm -f assets.zip
    # remove object files
    run rm -f main.o main.lo
    run find lib ext apps/$APP/lib -name '*.o' -delete
    run find lib ext apps/$APP/lib -name '*.lo' -delete
    exit 0
    ;;
  distclean)
    $0 clean $APP
    # remove static dependencies
    run rm -rf deps
    exit 0
    ;;
  build)
    # default goal -> fall through
    ;;
  *)
    echo "Unknown goal: $GOAL"
    exit 1
    ;;
esac

# default goal: build

CC=gcc

# dependency versions
source config.sh

# all dependencies are downloaded and extracted into a directory under deps/

download() {
  local url="$1"
  local target="$2"
  if [ ! -e "deps/$target" ]; then
    run curl -skL -o "deps/$target" "$url"
  fi
}

extract() {
  local tgz="$1"
  local dir="$2"
  if [ ! -e "deps/$dir/.extracted" ]; then
    run tar xzf "deps/$tgz" -C deps
    if [ ! -d "deps/$dir" ]; then
      echo "Failed to extract: deps/$dir does not exist."
      exit 1
    fi
    run touch "deps/$dir/.extracted"
  fi
}

# LuaJIT

LUAJIT_TGZ="LuaJIT-$LUAJIT_VER.tar.gz"
LUAJIT_URL="http://luajit.org/download/$LUAJIT_TGZ"
LUAJIT_DIR="LuaJIT-${LUAJIT_VER}"
LUAJIT_ROOT="deps/$LUAJIT_DIR"
LUAJIT_SRC="$LUAJIT_ROOT/src"
LUAJIT_LIB="$LUAJIT_SRC/libluajit.a"
LUAJIT_BIN="$LUAJIT_SRC/luajit"

mkdir -p deps

download $LUAJIT_URL $LUAJIT_TGZ
extract $LUAJIT_TGZ $LUAJIT_DIR

if [ ! -e $LUAJIT_LIB ]; then
  run sed -i -re 's/^#(XCFLAGS\+= -DLUAJIT_ENABLE_LUA52COMPAT).*/\1/' $LUAJIT_ROOT/src/Makefile
  run make -C $LUAJIT_ROOT
fi

# nanomsg

NANOMSG_TGZ="nanomsg-$NANOMSG_VER.tar.gz"
NANOMSG_URL="https://github.com/nanomsg/nanomsg/archive/$NANOMSG_VER.tar.gz"
NANOMSG_DIR="nanomsg-$NANOMSG_VER"
NANOMSG_ROOT="deps/$NANOMSG_DIR"
NANOMSG_LIB="$NANOMSG_ROOT/libnanomsg.a"
NANOMSG_SRC="$NANOMSG_ROOT/src"

download $NANOMSG_URL $NANOMSG_TGZ
extract $NANOMSG_TGZ $NANOMSG_DIR

if [ ! -e $NANOMSG_LIB ]; then
  run ln -sfvT . $NANOMSG_ROOT/src/nanomsg
  (cd $NANOMSG_ROOT && run cmake -D NN_STATIC_LIB=1 .)
  (cd $NANOMSG_ROOT && run cmake --build .)
  (cd $NANOMSG_ROOT && run ctest -G Debug .)
fi

# CMP

CMP_TGZ="cmp-$CMP_VER.tar.gz"
CMP_URL="https://github.com/camgunz/cmp/archive/v$CMP_VER.tar.gz"
CMP_DIR="cmp-$CMP_VER"
CMP_ROOT="deps/$CMP_DIR"
CMP_SRC="$CMP_ROOT"
CMP_OBJ="$CMP_SRC/cmp.o"

download $CMP_URL $CMP_TGZ
extract $CMP_TGZ $CMP_DIR

if [ ! -e $CMP_OBJ ]; then
  (cd $CMP_SRC && run $CC -c cmp.c)
fi

# app

CFLAGS="-Wall -iquote ./lib -iquote ./ext -iquote $LUAJIT_SRC -iquote $NANOMSG_SRC -iquote $CMP_SRC"
LDFLAGS="-Wl,-E -lm -ldl -lpthread -lanl"

find_libs() {
  find "$@" -name '*.lua' | sed -r -e 's#.*(lib|ext)/(.+)\.lua#\2#' -e 's#/#.#g'
}

# ZZ_LIBS: the list of base libraries to be built into all binaries
ZZ_LIBS="$(find_libs lib)"

# APP_LIBS: the list of app libraries to be built into the binary
APP_LIBS="app"

# let the app's config script extend/update the variables above
if [ -e apps/$APP/config.sh ]; then
  . apps/$APP/config.sh
fi

ZZ_LIB_OBJ=()
ZZ_CLIB_OBJ=()

usorted() {
  for x in "$@"; do echo "$x"; done | sort -u
}

CHANGED=0

relink() {
  CHANGED=$((CHANGED+1))
}

need_to_relink() {
  [ $CHANGED -gt 0 ]
}

for lib_name in $(usorted $ZZ_LIBS $APP_LIBS) main; do
  lib_relpath=${lib_name//.//}.lua
  lib_abspath=
  for libloc in lib ext apps/$APP/lib .; do
    if [ -e $libloc/$lib_relpath ]; then
        lib_abspath=$libloc/$lib_relpath
        break
    fi
  done
  if [ -z "$lib_abspath" ]; then
    echo "Library not found: $lib_name"
    exit 1
  fi
  lib_obj=${lib_abspath%.lua}.lo
  if [ $lib_abspath -nt $lib_obj ]; then
    # compile the Lua library into bytecode wrapped into a linkable object file
    #
    # -b: save (or list) bytecode
    # -t o: output shall be an object file
    # -n $lib_name: name of the symbol table entry
    # -g: keep debug info
    # $lib_abspath: input file
    # $lib_obj: output file
	  LUA_PATH="$LUAJIT_SRC/?.lua" run $LUAJIT_BIN -b -t o -n $lib_name -g $lib_abspath $lib_obj
    relink
  fi
  ZZ_LIB_OBJ+=($lib_obj)
  # if there is C support for this library, compile it too
  clib_abspath=${lib_abspath%.lua}.c
  if [ -e $clib_abspath ]; then
    clib_obj=${clib_abspath%.c}.o
    clib_h=${clib_abspath%.c}.h
    if [ $clib_abspath -nt $clib_obj ] || [ -e $clib_h -a $clib_h -nt $clib_obj ]; then
      run $CC $CFLAGS -c $clib_abspath -o $clib_obj
      relink
    fi
    ZZ_CLIB_OBJ+=($clib_obj)
  fi
done

# package assets

assets_zip="$PWD/assets.zip"

add_to_zip() {
  local zip="$1"
  local dir="$2"
  if [ -d "$dir" ]; then
    ( cd "$dir" && zip -r "$zip" . )
  fi
}

assets_changed() {
  local dir="$1"
  [ -d "$dir" ] && [ -n "$(find "$dir" -newer "$assets_zip")" ]
}

if [ ! -e "$assets_zip" ] || assets_changed apps/$APP/assets; then
  echo "Packing assets:"
  rm -f "$assets_zip"
  add_to_zip "$assets_zip" apps/$APP/assets
  relink
fi

# create app binary

if [ ! -e $APP ] || need_to_relink; then
  run $CC $CFLAGS \
    ${ZZ_LIB_OBJ[@]} ${ZZ_CLIB_OBJ[@]} \
    -Wl,--whole-archive \
    $LUAJIT_LIB $CMP_OBJ $NANOMSG_LIB \
    -Wl,--no-whole-archive \
    $LDFLAGS -o $APP
  echo -n "Attaching assets: "
  cat "$assets_zip" >> $APP
  echo "done."
fi
