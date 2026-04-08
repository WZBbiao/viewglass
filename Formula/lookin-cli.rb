class LookinCli < Formula
  desc "Programmable CLI for Lookin iOS view hierarchy inspector"
  homepage "https://lookin.work"
  # Stable: pinned to a specific archive snapshot for reproducibility.
  # Update the URL and sha256 when cutting a new release tag.
  url "https://github.com/WZBbiao/Lookin/archive/refs/heads/codex/lookin-cli.tar.gz"
  version "0.1.0"
  license "MIT"

  # Head: tracks the latest development branch
  head "https://github.com/WZBbiao/Lookin.git", branch: "codex/lookin-cli"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/lookin-cli"
  end

  test do
    assert_match "lookin-cli", shell_output("#{bin}/lookin-cli --help")
  end
end
