.DEFAULT_GOAL = zzlua

LUAJIT_VER = 2.0.3
LUAJIT_TGZ = LuaJIT-$(LUAJIT_VER).tar.gz
LUAJIT_URL = http://luajit.org/download/$(LUAJIT_TGZ)
LUAJIT_DIR = LuaJIT-$(LUAJIT_VER)
LUAJIT_SRC = $(LUAJIT_DIR)/src
LUAJIT_LIB = $(LUAJIT_SRC)/libluajit.a
LUAJIT_BIN = $(LUAJIT_SRC)/luajit

$(LUAJIT_TGZ):
	wget -O $@ $(LUAJIT_URL)

$(LUAJIT_DIR): $(LUAJIT_TGZ)
	tar xvzf $^
	touch $@

$(LUAJIT_BIN) $(LUAJIT_LIB): $(LUAJIT_DIR)
	$(MAKE) -C $^

CC = gcc
CFLAGS = -I$(LUAJIT_SRC)
LDFLAGS = -Wl,-E -lm -ldl

# zzlua: C core
ZZ_SRC = $(wildcard *.c)
ZZ_OBJ = $(patsubst %.c,%.o,$(ZZ_SRC))
$(ZZ_OBJ): $(LUAJIT_LIB)

# zzlua: Lua libraries
ZZLIB_SRC = $(wildcard lib/*.lua)
ZZLIB_OBJ = $(patsubst %.lua,%.lo,$(ZZLIB_SRC))
$(ZZLIB_OBJ): $(LUAJIT_BIN)

# Lua libs are precompiled into object files
# and then linked into the zzlua executable
lib/%.lo : lib/%.lua
	LUA_PATH=$(LUAJIT_SRC)/?.lua $(LUAJIT_BIN) -bt o -g $< $@

zzlua: $(ZZ_OBJ) $(ZZLIB_OBJ) $(LUAJIT_LIB)
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

.PHONY: test
test: zzlua
	@./run-tests.sh

.PHONY: clean
clean:
	rm -f *.o lib/*.o
	$(MAKE) -C $(LUAJIT_DIR) clean
