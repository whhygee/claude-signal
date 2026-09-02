BIN := bin
AGENT := com.whygee.claude-signal

.PHONY: build install restart clean

build:
	swift build -c release

install: build
	mkdir -p $(BIN)
	cp .build/release/claude-signal $(BIN)/

restart: install
	launchctl kickstart -k gui/$$(id -u)/$(AGENT)

clean:
	rm -rf .build $(BIN)
