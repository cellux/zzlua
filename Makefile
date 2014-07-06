JACK_CFLAGS := $(shell pkg-config --cflags jack)
JACK_LIBS = $(shell pkg-config --libs jack)

ZMQ_CFLAGS := $(shell pkg-config --cflags libzmq)
ZMQ_LIBS := $(shell pkg-config --libs libzmq)

CFLAGS := -std=c++11 $(ZMQ_CFLAGS) $(JACK_CFLAGS) $(LUAJIT_CFLAGS)
LDFLAGS := $(ZMQ_LIBS) $(JACK_LIBS) $(LUAJIT_LIBS)

showtime: showtime.cc
	$(CXX) $(CFLAGS) $^ $(LDFLAGS) -o $@

clean:
	rm -f showtime
