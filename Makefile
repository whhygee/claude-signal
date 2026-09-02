BIN := bin
AGENT := com.whygee.claude-signal

.PHONY: build install restart clean

build:
	swift build -c release

# install(1) unlinks the target first: copying over a running Mach-O in place
# invalidates the kernel's cached code signature and every exec gets SIGKILL.
install: build
	mkdir -p $(BIN)
	install -m 755 .build/release/claude-signal $(BIN)/claude-signal

# Rebuild and refresh the ~/Applications bundle + LaunchAgent.
app: install
	$(BIN)/claude-signal install-app

restart: install
	launchctl kickstart -k gui/$$(id -u)/$(AGENT)

clean:
	rm -rf .build $(BIN)
