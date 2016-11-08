.DEFAULT_GOAL = zzlua

CURL = curl -k -L

### statically linked dependencies ###

# LuaJIT

LUAJIT_VER := 2.0.4
LUAJIT_TGZ := LuaJIT-$(LUAJIT_VER).tar.gz
LUAJIT_URL := http://luajit.org/download/$(LUAJIT_TGZ)
LUAJIT_DIR := deps/LuaJIT-$(LUAJIT_VER)
LUAJIT_SRC := $(LUAJIT_DIR)/src
LUAJIT_LIB := $(LUAJIT_SRC)/libluajit.a
LUAJIT_BIN := $(LUAJIT_SRC)/luajit

deps/$(LUAJIT_TGZ):
	mkdir -p deps
	$(CURL) -o $@ $(LUAJIT_URL)

$(LUAJIT_DIR)/.extracted: deps/$(LUAJIT_TGZ)
	cd deps && tar xvzf $(LUAJIT_TGZ)
	touch $@

$(LUAJIT_BIN) $(LUAJIT_LIB): $(LUAJIT_DIR)/.extracted
	$(MAKE) -C $(LUAJIT_DIR)

# nanomsg

NANOMSG_VER := 1.0.0
NANOMSG_TGZ := nanomsg-$(NANOMSG_VER).tar.gz
NANOMSG_URL := https://github.com/nanomsg/nanomsg/archive/$(NANOMSG_VER).tar.gz
NANOMSG_DIR := deps/nanomsg-$(NANOMSG_VER)
NANOMSG_LIB := $(NANOMSG_DIR)/libnanomsg.a
NANOMSG_SRC := $(NANOMSG_DIR)/src

deps/$(NANOMSG_TGZ):
	mkdir -p deps
	$(CURL) -o $@ $(NANOMSG_URL)

$(NANOMSG_DIR)/.extracted: deps/$(NANOMSG_TGZ)
	cd deps && tar xvzf $(NANOMSG_TGZ)
# to make #include <nanomsg/nn.h> (and friends) work
	ln -sf . $(NANOMSG_DIR)/src/nanomsg
	touch $@

$(NANOMSG_LIB): $(NANOMSG_DIR)/.extracted
	cd $(NANOMSG_DIR) && cmake -D NN_STATIC_LIB=1 .
	cd $(NANOMSG_DIR) && cmake --build .
	cd $(NANOMSG_DIR) && ctest -G Debug .

# cmp

CMP_VER := 10
CMP_TGZ := cmp-$(CMP_VER).tar.gz
CMP_URL := https://github.com/camgunz/cmp/archive/v$(CMP_VER).tar.gz
CMP_DIR := deps/cmp-$(CMP_VER)
CMP_OBJ := $(CMP_DIR)/cmp.o

deps/$(CMP_TGZ):
	mkdir -p deps
	$(CURL) -o $@ $(CMP_URL)

$(CMP_DIR)/.extracted: deps/$(CMP_TGZ)
	cd deps && tar xvzf $(CMP_TGZ)
	touch $@

$(CMP_OBJ): $(CMP_DIR)/.extracted
	cd $(CMP_DIR) && gcc -c cmp.c

### main ###

CC := gcc
CFLAGS := -Wall -iquote ./lib -iquote $(LUAJIT_SRC) -iquote $(NANOMSG_SRC) -iquote $(CMP_DIR)
LDFLAGS := -Wl,-E -lm -ldl -lpthread -lanl -ljack -lfluidsynth

# Lua libraries
ZZ_LIB_LUA_SRC := $(sort $(shell find lib app/lib -name '*.lua'))
ZZ_LIB_LUA_OBJ := $(patsubst %.lua,%.lo,$(ZZ_LIB_LUA_SRC))

# Lua libs are precompiled into object files
# and then linked into the zzlua executable
%.lo: %.lua $(LUAJIT_BIN)
	LUA_PATH=$(LUAJIT_SRC)/?.lua $(LUAJIT_BIN) -b -t o -n $(shell echo $< | sed -r -e 's#.*lib/(.+)\.lua#\1#' -e 's#/#.#g') -g $< $@

# low-level support for Lua libraries
ZZ_LIB_C_SRC := $(sort $(shell find lib app/lib -name '*.c'))
ZZ_LIB_C_OBJ := $(patsubst %.c,%.o,$(ZZ_LIB_C_SRC))

# header dependencies
lib/buffer.o: lib/buffer.h
lib/msgpack.o: lib/msgpack.h

zzlua.o: $(LUAJIT_LIB) $(NANOMSG_LIB) $(CMP_OBJ)

# zzlua + libs + support
ZZ_OBJ := zzlua.o $(ZZ_LIB_LUA_OBJ) $(ZZ_LIB_C_OBJ)

# static libraries and object files to be searched for missing externs
ZZ_LIB := $(LUAJIT_LIB) $(CMP_OBJ)

# static libraries and object files to be linked in as a whole
ZZ_LIB_WHOLE := $(NANOMSG_LIB)

zzlua: $(ZZ_OBJ) $(ZZ_LIB) $(ZZ_LIB_WHOLE)
	$(CC) $(CFLAGS) $(ZZ_OBJ) $(ZZ_LIB) -Wl,--whole-archive $(ZZ_LIB_WHOLE) -Wl,--no-whole-archive $(LDFLAGS) -o $@

.PHONY: test
test: zzlua
	@./run-tests.sh

.PHONY: clean
clean:
	rm -f zzlua
	find lib app/lib -name '*.o' -delete
	find lib app/lib -name '*.lo' -delete

.PHONY: distclean
distclean: clean
	rm -rf deps
