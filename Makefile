ZZTOOLS = zzpatch zzseq

.PHONY: all
all: zzlua $(ZZTOOLS)

.PHONY: zzlua
zzlua:
	$(MAKE) -C $@

.PHONY: zztools
zztools: $(ZZTOOLS)

.PHONY: $(ZZTOOLS)
$(ZZTOOLS): zzlua
	$(MAKE) -C $@
