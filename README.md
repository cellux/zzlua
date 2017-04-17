## appbase

A LuaJIT-based app engine with a bunch of generally useful libraries pre-packaged into the binary.

Might be used as a well-equipped script interpreter or as the starting point of a single-binary app.

Currently Linux only.

> Warning: this is alpha-quality software. It has not yet been used in production.

> If you are interested in LuaJIT and/or event-driven architectures, the code might be interesting to read.

## Internal dependencies

* [LuaJIT](http://luajit.org/)
* [nanomsg](http://nanomsg.org/)
* [cmp](https://github.com/camgunz/cmp)
* [inspect.lua](https://github.com/kikito/inspect.lua)

These are either automatically downloaded upon compilation or bundled with the source.

## External dependencies

* [Jack](http://jackaudio.org/)
* [PCRE](http://www.pcre.org/)
* [SDL 2.0](http://libsdl.org/)

These are needed only if the corresponding library is `require`d by some Lua code.

## Compilation

```bash
git clone https://github.com/cellux/appbase
cd appbase
make
make test
```

## Core features

* coroutine-based scheduler (sched)
* asynchronous execution of synchronous C calls via a thread pool (async)
* message-based communication between Lua code and C threads (nanomsg, msgpack)
* OS signals are converted into events and injected into the event queue (signal)
* non-blocking timers (time)
* epoll-based support for non-blocking Unix/TCP/UDP sockets (socket)
* non-blocking file operations (file)
* process management (process)
* access to environment variables (env)

Basically it's like node.js, implemented in LuaJIT and a little bit of C.

## Additional features and library bindings

* Perl-compatible regular expressions (re)
* a very simple parser based on regular expressions (parser)
* command line argument processing (argparser)
* assertions (assert)
* Jack audio support (jack)

## Planned features

In decreasing order of priority:

* SDL2 bindings
* OpenGL bindings
* a user interface library (based on SDL2)
* SQLite bindings
* async DNS resolver
* HTTP library (for implementing HTTP clients and servers)
* crypto bindings (hashing, encryption, decryption, PKI)
* TLS/SSL support for sockets
* JSON support
* LLVM bindings
* a JIT compiler for a very simple, statically typed language with LISP syntax (based on LLVM)
* XML support
* CSV support
* UTF-8 support
* zlib support
* SMTP library (for sending and receiving Internet mail)
* MIME support
* IMAP library
* POP3 library
* FTP library
* web browser integration (WebKit or CEF, for embedding HTML views into user interfaces)

## Goals

* Learn as much as possible about the stuff that's under the hood in all of the world's software
* Create a platform which I can use to write the programs I want to write, and which I can extend/modify when the problems I face cannot be solved in the higher layers
* Express myself

## Philosophy

* Small is beautiful
* Reinventing the wheel is a good way to learn
* Standing on the shoulders of giants is a good idea
* Perfection results from finding optimal trade-offs

## Inspiration

* [LuaJIT](http://luajit.org/)
* [OpenResty](http://openresty.org/)
* [Luvit](https://luvit.io/)
* [Raspberry Pi](https://www.raspberrypi.org/)
* [Scheme](http://www.schemers.org/Documents/Standards/R5RS/)
* [Leonard and Sylvia Ritter](http://www.duangle.com/)
* [William A. Adams](https://williamaadams.wordpress.com/)
