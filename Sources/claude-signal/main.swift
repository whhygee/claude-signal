// claude-signal: menu bar traffic light for Claude Code sessions.
//
//   claude-signal                 run the menu bar app
//   claude-signal hook <state>    record a session state (called by Claude Code hooks)
//   claude-signal init            install the hooks into ~/.claude/settings.json
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case nil, "menubar":
    MenuBarCommand.run()
case "hook":
    HookCommand.run(arguments: Array(arguments.dropFirst()))
case "init":
    InitCommand.run()
case "-h", "--help", "help":
    print(
        """
        claude-signal — menu bar traffic light for Claude Code sessions

        USAGE:
          claude-signal                 Run the menu bar app (red = a session waits on
                                        you, yellow = working, green = results ready)
          claude-signal init            Install session hooks into ~/.claude/settings.json
          claude-signal hook <state>    Record a session state; called by Claude Code
                                        hooks (state: waiting | running | done | end)
        """
    )
default:
    FileHandle.standardError.write(Data("claude-signal: unknown command '\(arguments[0])' (see --help)\n".utf8))
    exit(64) // EX_USAGE
}
