.DEFAULT_GOAL = zzlua

CURL = curl -k -L

### statically linked dependencies ###

# LuaJIT

LUAJIT_VER = 2.0.4
LUAJIT_TGZ = LuaJIT-$(LUAJIT_VER).tar.gz
LUAJIT_URL = http://luajit.org/download/$(LUAJIT_TGZ)
LUAJIT_DIR = deps/LuaJIT-$(LUAJIT_VER)
LUAJIT_SRC = $(LUAJIT_DIR)/src
LUAJIT_LIB = $(LUAJIT_SRC)/libluajit.a
LUAJIT_BIN = $(LUAJIT_SRC)/luajit

deps/$(LUAJIT_TGZ):
	mkdir -p deps
	$(CURL) -o $@ $(LUAJIT_URL)

$(LUAJIT_DIR)/.stamp: deps/$(LUAJIT_TGZ)
	cd deps && tar xvzf $(LUAJIT_TGZ)
	touch $@

$(LUAJIT_BIN) $(LUAJIT_LIB): $(LUAJIT_DIR)/.stamp
	$(MAKE) -C $(LUAJIT_DIR)

# nanomsg

NANOMSG_VER = 0.5-beta
NANOMSG_TGZ = nanomsg-$(NANOMSG_VER).tar.gz
#NANOMSG_URL = https://github.com/nanomsg/nanomsg/releases/download/$(NANOMSG_VER)/nanomsg-$(NANOMSG_VER).tar.gz
NANOMSG_URL = http://download.nanomsg.org/$(NANOMSG_TGZ)
NANOMSG_DIR = deps/nanomsg-$(NANOMSG_VER)
NANOMSG_LIB = $(NANOMSG_DIR)/.libs/libnanomsg.a
NANOMSG_SRC = $(NANOMSG_DIR)/src

deps/$(NANOMSG_TGZ):
	mkdir -p deps
	$(CURL) -o $@ $(NANOMSG_URL)

$(NANOMSG_DIR)/.stamp: deps/$(NANOMSG_TGZ)
	cd deps && tar xvzf $(NANOMSG_TGZ)
	touch $@

$(NANOMSG_DIR)/Makefile: $(NANOMSG_DIR)/.stamp
	cd $(NANOMSG_DIR) && ./configure

$(NANOMSG_LIB): $(NANOMSG_DIR)/Makefile
	$(MAKE) -C $(NANOMSG_DIR)
	ln -s . $(NANOMSG_SRC)/nanomsg

# cmp

CMP_VER = 4
CMP_TGZ = cmp-$(CMP_VER).tar.gz
CMP_URL = https://github.com/camgunz/cmp/archive/v$(CMP_VER).tar.gz
CMP_DIR = deps/cmp-$(CMP_VER)
CMP_OBJ = $(CMP_DIR)/cmp.o

deps/$(CMP_TGZ):
	mkdir -p deps
	$(CURL) -o $@ $(CMP_URL)

$(CMP_DIR)/.stamp: deps/$(CMP_TGZ)
	cd deps && tar xvzf $(CMP_TGZ)
	touch $@

$(CMP_OBJ): $(CMP_DIR)/.stamp
	cd $(CMP_DIR) && gcc -c cmp.c

# GLEW

GLEW_VER = 1.13.0
GLEW_TGZ = glew-$(GLEW_VER).tgz
GLEW_URL = https://sourceforge.net/projects/glew/files/glew/$(GLEW_VER)/$(GLEW_TGZ)/download
GLEW_DIR = deps/glew-$(GLEW_VER)
GLEW_LIB = $(GLEW_DIR)/lib/libGLEW.a

deps/$(GLEW_TGZ):
	mkdir -p deps
	$(CURL) -o $@ $(GLEW_URL)

$(GLEW_DIR)/.stamp: deps/$(GLEW_TGZ)
	cd deps && tar xvzf $(GLEW_TGZ)
	touch $@

$(GLEW_LIB): $(GLEW_DIR)/.stamp
	$(MAKE) -C $(GLEW_DIR) glew.lib

### main ###

CC = gcc
CFLAGS = -Wall -iquote ./lib -iquote $(LUAJIT_SRC) -iquote $(NANOMSG_SRC) -iquote $(CMP_DIR)
LDFLAGS = -Wl,-E -lm -ldl -lpthread -lanl -ljack -lGL

# Lua libraries
ZZ_LIB_LUA_SRC = $(wildcard lib/*.lua)
ZZ_LIB_LUA_OBJ = $(patsubst %.lua,%.lo,$(ZZ_LIB_LUA_SRC))

# Lua libs are precompiled into object files
# and then linked into the zzlua executable
lib/%.lo: lib/%.lua $(LUAJIT_BIN)
	LUA_PATH=$(LUAJIT_SRC)/?.lua $(LUAJIT_BIN) -bt o -g $< $@

# low-level support for Lua libraries
ZZ_LIB_C_SRC = $(wildcard lib/*.c)
ZZ_LIB_C_OBJ = $(patsubst %.c,%.o,$(ZZ_LIB_C_SRC))

# header dependencies
lib/buffer.o: lib/buffer.h
lib/msgpack.o: lib/msgpack.h

zzlua.o: $(LUAJIT_LIB) $(NANOMSG_LIB) $(CMP_OBJ) $(GLEW_LIB)

# zzlua + libs + support
ZZ_OBJ = zzlua.o $(ZZ_LIB_LUA_OBJ) $(ZZ_LIB_C_OBJ)

# static libraries and object files to be searched for missing externs
ZZ_LIB = $(LUAJIT_LIB) $(CMP_OBJ)

# static libraries and object files to be linked in as a whole
ZZ_LIB_WHOLE = $(NANOMSG_LIB) $(GLEW_LIB)

zzlua: $(ZZ_OBJ) $(ZZ_LIB) $(ZZ_LIB_WHOLE)
	$(CC) $(CFLAGS) $(ZZ_OBJ) $(ZZ_LIB) -Wl,--whole-archive $(ZZ_LIB_WHOLE) -Wl,--no-whole-archive $(LDFLAGS) -o $@

.PHONY: test
test: zzlua
	@./run-tests.sh

.PHONY: clean
clean:
	rm -f zzlua *.o lib/*.o lib/*.lo

.PHONY: distclean
distclean: clean
	rm -rf deps
