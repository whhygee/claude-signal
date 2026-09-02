class ClaudeSignal < Formula
  desc "Menu bar traffic light for Claude Code sessions"
  homepage "https://github.com/whhygee/claude-signal"
  url "https://github.com/whhygee/claude-signal/archive/refs/tags/v0.0.3.tar.gz"
  sha256 "16b805c3c2580a4584a5b0376ebf79e4c8f036bfc77e89e3a3bec00a87f6bea3"
  license "MIT"

  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/claude-signal"
  end

  service do
    run [opt_bin/"claude-signal", "menubar"]
    keep_alive successful_exit: false
    run_type :immediate
  end

  def caveats
    <<~EOS
      Wire up the Claude Code hooks once:
        claude-signal init

      Then either create a Spotlight-launchable app that also starts at login:
        claude-signal install-app
      or run it as a plain background service:
        brew services start claude-signal
    EOS
  end

  test do
    assert_match "claude-signal", shell_output("#{bin}/claude-signal --help")
  end
end
