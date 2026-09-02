class ClaudeSignal < Formula
  desc "Menu bar traffic light for Claude Code sessions"
  homepage "https://github.com/whhygee/claude-signal"
  url "https://github.com/whhygee/claude-signal/archive/refs/tags/v0.0.2.tar.gz"
  sha256 "9a20e417294d3013b8190413934287a1e6e1d57f83d05c3070691caa444fc0ab"
  license "MIT"

  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/claude-signal"
  end

  service do
    run [opt_bin/"claude-signal", "menubar"]
    keep_alive true
    run_type :immediate
  end

  def caveats
    <<~EOS
      Wire up the Claude Code hooks once:
        claude-signal init

      Then run the menu bar app at login:
        brew services start claude-signal
    EOS
  end

  test do
    assert_match "claude-signal", shell_output("#{bin}/claude-signal --help")
  end
end
