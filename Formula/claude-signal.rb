class ClaudeSignal < Formula
  desc "Menu bar traffic light for Claude Code sessions"
  homepage "https://github.com/whhygee/claude-signal"
  url "https://github.com/whhygee/claude-signal/archive/refs/tags/v0.0.3.tar.gz"
  sha256 "fba5499bf0cf44ffde4806715524107cf1a945d1443e77800fbcfbb661263019"
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
