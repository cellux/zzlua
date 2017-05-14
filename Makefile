APP ?= zzlua

$(APP):
	@./build.sh build $(APP)

.PHONY: test
test: $(APP)
	@./run-tests.sh

.PHONY: clean
clean:
	@./build.sh clean $(APP)

.PHONY: distclean
distclean:
	@./build.sh distclean $(APP)
