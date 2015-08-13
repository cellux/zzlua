## zzlua

A LuaJIT interpreter with a bunch of generally useful libraries pre-packaged into the binary.

Might be used as a well-equipped script interpreter or as the starting point of a single-binary app.

Currently Linux only.

## Internal dependencies

* [LuaJIT](http://luajit.org/)
* [nanomsg](http://nanomsg.org/)
* [cmp](https://github.com/camgunz/cmp)
* [inspect.lua](https://github.com/kikito/inspect.lua)

These are either automatically downloaded upon compilation or bundled with the source.

## External dependencies

* [Jack](http://jackaudio.org/)
* [PCRE](http://www.pcre.org/)

## Core features

* coroutine-based scheduler (sched)
* asynchronous execution of synchronous C calls via a thread pool (async)
* message-based communication between Lua code and C threads (nanomsg, msgpack)
* OS signals are converted into events and injected into the event queue (signal)
* non-blocking timers (time)
* epoll-based support for non-blocking Unix/TCP/UDP sockets (socket)
* non-blocking file operations (file)
* access to various system calls (sys)
* access to the process environment (env)

Basically it's like node.js, implemented in LuaJIT with a bit of C support.

## Additional features and library bindings

* Perl-compatible regular expressions (re)
* a very simple parser based on regular expressions (parser)
* command line argument processing (argparser)
* assertions (assert)
* Jack audio support (jack)

## Compilation

```bash
git clone https://github.com/cellux/zzlua
cd zzlua
make
make test
```
