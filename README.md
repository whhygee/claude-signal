# claude-signal

Menu bar traffic light for your Claude Code sessions.

- 🔴 **Red** — at least one session is waiting on you (permission prompt or idle)
- 🟡 **Yellow** — all sessions are working
- 🟢 **Green** — results ready
- ○ Gray — no active sessions

One aggregate dot in the macOS menu bar; the worst state across all sessions
wins. The number next to it is the session count. Click for a per-session
breakdown.

## Install

```sh
brew tap whhygee/claude-signal https://github.com/whhygee/claude-signal
brew install claude-signal

claude-signal init                 # wire up Claude Code hooks
brew services start claude-signal  # run the menu bar app at login
```

New Claude Code sessions report their state from then on. Sessions that were
already running pick it up on their next restart.

### From source

```sh
make install     # swift build -c release, binary into bin/
bin/claude-signal init
bin/claude-signal
```

## How it works

```
Claude Code hooks ──▶ claude-signal hook ──▶ ~/.claude/session-status/<id>.json ──▶ menu bar app
```

`claude-signal init` installs command hooks into `~/.claude/settings.json`:

| Hook event         | State        |
|--------------------|--------------|
| `UserPromptSubmit` | `running`    |
| `Notification`     | `waiting`    |
| `Stop`             | `done`       |
| `SessionStart`     | `done`       |
| `SessionEnd`       | removes file |

Hooks are async, so they add no latency to your sessions. `init` is
idempotent — re-run it after moving the binary and it replaces its own
entries, leaving your other hooks untouched.

Each state file records the session's `claude` PID (found by walking the
process tree), so the app prunes sessions the moment their process dies —
crashed sessions never leave stale dots.

## Layout

```
Sources/
  SignalCore/      Session model + SessionStore (shared)
  claude-signal/   CLI entry, hook + init commands, menu bar app (AppKit)
```

## License

MIT
