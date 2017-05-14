# zzlua shall have libraries under ext, too
ZZ_LIBS+=" $(find_libs ext)"
LDFLAGS+=" -lSDL2 -lfluidsynth -ljack"
