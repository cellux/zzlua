## zzlua

A LuaJIT-based script interpreter with a bunch of useful libraries built into the executable.

Currently Linux only.

## Compilation

First install the [ZZ core framework](https://github.com/cellux/zz).

Once you have the `zz` executable on PATH:

```
zz get github.com/cellux/zzlua
```

This command will download this repository and all dependencies to
directories under $ZZPATH, build the `zzlua` executable and symlink it
to `$ZZPATH/bin/zzlua`.
