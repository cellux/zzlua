.DEFAULT_GOAL = zzlua

CURL = curl -k -L

### statically linked dependencies ###

# LuaJIT

LUAJIT_VER = 2.0.3
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

NANOMSG_VER = 0.4-beta
NANOMSG_TGZ = nanomsg-$(NANOMSG_VER).tar.gz
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

### main ###

CC = gcc
CFLAGS = -I./lib -I$(LUAJIT_SRC) -I$(NANOMSG_SRC) -I$(CMP_DIR)
LDFLAGS = -Wl,-E -lm -ldl

# zzlua: low-level support for Lua libraries
ZZ_LIB_C_SRC = $(wildcard lib/*.c)
ZZ_LIB_C_OBJ = $(patsubst %.c,%.o,$(ZZ_LIB_C_SRC))
lib/buffer.o: lib/buffer.h $(CMP_OBJ)

# zzlua: Lua libraries
ZZ_LIB_LUA_SRC = $(wildcard lib/*.lua)
ZZ_LIB_LUA_OBJ = $(patsubst %.lua,%.lo,$(ZZ_LIB_LUA_SRC))

# Lua libs are precompiled into object files
# and then linked into the zzlua executable
lib/%.lo : lib/%.lua $(LUAJIT_BIN)
	LUA_PATH=$(LUAJIT_SRC)/?.lua $(LUAJIT_BIN) -bt o -g $< $@

zzlua.o: $(LUAJIT_LIB)

zzlua: zzlua.o $(ZZ_LIB_C_OBJ) $(ZZ_LIB_LUA_OBJ) $(LUAJIT_LIB) $(NANOMSG_LIB) $(CMP_OBJ)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

.PHONY: test
test: zzlua
	@./run-tests.sh

.PHONY: clean
clean:
	rm -f zzlua *.o lib/*.o lib/*.lo
	rm -f $(CMP_OBJ)

.PHONY: distclean
distclean: clean
	rm -rf deps
