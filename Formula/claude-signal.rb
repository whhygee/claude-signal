class ClaudeSignal < Formula
  desc "Menu bar traffic light for Claude Code sessions"
  homepage "https://github.com/whhygee/claude-signal"
  url "https://github.com/whhygee/claude-signal/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "11b876e3656538c4b570ba66c1689c0bdc73d2757bbc2fc91f7a77afffad14ec"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["15.0", :build]

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
