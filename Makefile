JACK_CFLAGS := $(shell pkg-config --cflags jack)
JACK_LIBS = $(shell pkg-config --libs jack)

LUAJIT_CFLAGS := $(shell pkg-config --cflags luajit)
LUAJIT_LIBS := $(shell pkg-config --libs luajit)

ZMQ_CFLAGS := $(shell pkg-config --cflags libzmq)
ZMQ_LIBS := $(shell pkg-config --libs libzmq)

CFLAGS := $(ZMQ_CFLAGS) $(JACK_CFLAGS) $(LUAJIT_CFLAGS)
LDFLAGS := $(ZMQ_LIBS) $(JACK_LIBS) $(LUAJIT_LIBS)

showtime: showtime.c
	$(CC) $(CFLAGS) $^ $(LDFLAGS) -o $@

clean:
	rm -f showtime
