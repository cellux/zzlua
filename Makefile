.PHONY: app
app:
	@./build.sh build

.PHONY: test
test: app
	@./run-tests.sh

.PHONY: clean
clean:
	@./build.sh clean

.PHONY: distclean
distclean:
	@./build.sh distclean
