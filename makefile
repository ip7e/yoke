# makefile is used to make :make command in vim work out of the box
.PHONY: build test format swift-test yoke

build:
	./build-debug.sh

test:
	./run-tests.sh

swift-test:
	./run-swift-test.sh

format:
	./format.sh

lint:
	./lint.sh

yoke:
	pkill -x AeroSpace 2>/dev/null; pkill -f YokeApp 2>/dev/null; sleep 0.3
	swift run YokeApp
